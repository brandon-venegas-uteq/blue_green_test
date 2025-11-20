const express = require('express')
const app = express()
const port = 3000


const APP_COLOR = process.env.APP_COLOR || 'unknown';

app.get('/', (req, res) => {
  res.json({
    status: 'ok',
    color: APP_COLOR,
    message: `Sirviendo desde el slot: ${APP_COLOR}`
  });
})



app.listen(port, () => {
  console.log(`Example app listening on port ${port}`)
})
