const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

const hello = 'Hello from CI/CD Demo App - SPSI - xyz 12121212121212';

// Health check endpoint untuk Kubernetes probes
app.get('/health', (_req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    pod: process.env.POD_NAME || 'unknown',
    namespace: process.env.POD_NAMESPACE || 'unknown'
  });
});

// Readiness endpoint - bisa ditambahkan logic cek koneksi DB, dll
app.get('/ready', (_req, res) => {
  res.status(200).json({ status: 'ready' });
});

// Info endpoint
app.get('/info', (_req, res) => {
  res.json({
    app: 'demo-apps',
    version: 'v1.0.0',
    nodeEnv: process.env.NODE_ENV || 'development',
    pod: process.env.POD_NAME || 'unknown',
    namespace: process.env.POD_NAMESPACE || 'unknown'
  });
});

app.get('/', (req, res) => {
  res.send(`
    <html>
      <head>
        <meta http-equiv="refresh" content="5">
        <title>CI/CD Demo</title>
        <style>
          body { font-family: Arial, sans-serif; margin: 40px; }
          .info { background: #f0f0f0; padding: 20px; border-radius: 8px; }
        </style>
      </head>
      <body>
        <h1>${hello}</h1>
        <div class="info">
          <p><strong>Pod:</strong> ${process.env.POD_NAME || 'unknown'}</p>
          <p><strong>Namespace:</strong> ${process.env.POD_NAMESPACE || 'unknown'}</p>
          <p><strong>Node Env:</strong> ${process.env.NODE_ENV || 'development'}</p>
        </div>
        <p>Page reloads every 5 seconds.</p>
        <p><a href="/health">Health Check</a> | <a href="/info">App Info</a></p>
      </body>
    </html>
  `);
});

// Graceful shutdown handling
const server = app.listen(port, () => console.log(`App running on port ${port}`));

process.on('SIGTERM', () => {
  console.log('SIGTERM signal received: closing HTTP server');
  server.close(() => {
    console.log('HTTP server closed');
  });
});

process.on('SIGINT', () => {
  console.log('SIGINT signal received: closing HTTP server');
  server.close(() => {
    console.log('HTTP server closed');
  });
});
