#!/bin/bash
set -e # Termina el script si hay un error

# --- Configuración ---
# El script recibe el tag de la imagen (el SHA) como primer argumento
NEW_TAG=$1
if [ -z "$NEW_TAG" ]; then
  echo "Error: No se proporcionó ningún tag de imagen."
  exit 1
fi

# El GITHUB_REPOSITORY lo pasamos como variable de entorno desde la Action
IMAGE_NAME="ghcr.io/$(echo $GITHUB_REPOSITORY | tr '[:upper:]' '[:lower:]')"
NEW_IMAGE="$IMAGE_NAME:$NEW_TAG"

APP_DIR="/home/deployer/app"
ENV_FILE="$APP_DIR/.env"
NGINX_CONF_DIR="/etc/nginx"

# --- 1. Leer el estado actual ---
# Asegura que el archivo .env exista
if [ ! -f "$ENV_FILE" ]; then
  echo "CURRENT_PRODUCTION=green" > "$ENV_FILE"
fi

# Carga la variable CURRENT_PRODUCTION
source "$ENV_FILE"

# --- 2. Determinar slots ---
if [ "$CURRENT_PRODUCTION" == "blue" ]; then
  INACTIVE_SLOT="green"
  INACTIVE_PORT="3001"
  INACTIVE_CONF="$NGINX_CONF_DIR/green.conf"
else
  INACTIVE_SLOT="blue"
  INACTIVE_PORT="3000"
  INACTIVE_CONF="$NGINX_CONF_DIR/blue.conf"
fi

echo "Desplegando en el slot inactivo: $INACTIVE_SLOT"

# --- 3. Desplegar en slot inactivo ---
echo "Haciendo pull de la nueva imagen: $NEW_IMAGE"
# echo ${{ secrets.GHCR_TOKEN }} | docker login ghcr.io -u $GITHUB_ACTOR --password-stdin
docker pull "$NEW_IMAGE"

echo "Deteniendo y eliminando contenedor $INACTIVE_SLOT (si existe)"
docker stop "$INACTIVE_SLOT" || true
docker rm "$INACTIVE_SLOT" || true

echo "Iniciando nuevo contenedor $INACTIVE_SLOT en el puerto $INACTIVE_PORT"
docker run -d --name "$INACTIVE_SLOT" \
  -p "$INACTIVE_PORT:3000" \
  -e "APP_COLOR=$INACTIVE_SLOT" \
  --restart unless-stopped \
  "$NEW_IMAGE"

# (Opcional) Esperar y hacer un health check
echo "Esperando 10s para que el contenedor inicie..."
sleep 10


# --- 4. Cambiar el tráfico de Nginx ---
echo "Cambiando el tráfico de Nginx a $INACTIVE_SLOT"
sudo ln -snf "$INACTIVE_CONF" "$NGINX_CONF_DIR/current_upstream.conf"
sudo systemctl reload nginx

# --- 5. Actualizar el estado ---
echo "Actualizando estado. Nuevo slot de producción: $INACTIVE_SLOT"
echo "CURRENT_PRODUCTION=$INACTIVE_SLOT" > "$ENV_FILE"

echo "¡Despliegue Blue/Green completado!"