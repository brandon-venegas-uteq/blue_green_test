FROM node:18-alpine

WORKDIR /app

COPY package*.json ./

# 'npm ci' es mejor para producción, 'npm install' está bien para dev
RUN npm install

COPY . .

EXPOSE 3000

# Cambia 'server.js' por tu archivo de entrada
CMD ["node", "index.js"]