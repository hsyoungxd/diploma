// gateway.js
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { createProxyMiddleware } = require('http-proxy-middleware');

const app = express();
app.use(cors());
app.use(express.json());

app.use((req, res, next) => {
  console.log(`[GATEWAY] Incoming request: ${req.method} ${req.originalUrl}`);
  next();
});

// Proxy config
app.use('/api/auth', createProxyMiddleware({
  target: 'http://localhost:4001',
  changeOrigin: true,
  pathRewrite: { '^/api/auth': '' },
}));

app.use('/api/users', createProxyMiddleware({
  target: 'http://localhost:4002',
  changeOrigin: true,
  pathRewrite: { '^/api/users': '' },
}));

app.use('/api/transactions', createProxyMiddleware({
  target: 'http://localhost:4003',
  changeOrigin: true,
  pathRewrite: { '^/api/transactions': '' },
}));

const PORT = 4000;
app.listen(PORT, () => {
  console.log(`Gateway запущен на порту ${PORT}`);
});
