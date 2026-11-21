require('dotenv').config();
const http = require('http');
const os = require('os');
const { execSync } = require('child_process');
const app = require('./src/app');
const { connectDB } = require('./src/config/db');

const PORT = parseInt(process.env.PORT || '5001', 10);

const cleanPort = (port) => {
  try {
    if (process.platform === 'win32') {
      execSync(`for /f "tokens=5" %a in ('netstat -aon ^| findstr :${port}') do taskkill /f /pid %a`, { stdio: 'ignore' });
    } else {
      execSync(`lsof -ti :${port} | xargs kill -9 2>/dev/null || true`, { stdio: 'ignore' });
    }
  } catch (_) {}
};

const getLocalIps = () => {
  const interfaces = os.networkInterfaces();
  const addresses = [];
  for (const name of Object.keys(interfaces)) {
    for (const net of interfaces[name] || []) {
      if (net.family === 'IPv4' && !net.internal) {
        addresses.push(net.address);
      }
    }
  }
  return addresses;
};

const startServer = async () => {
  // Free any orphan process on PORT before binding
  cleanPort(PORT);

  // Connect to database (with automatic hybrid fallback if Atlas unreachable)
  await connectDB();

  const server = http.createServer(app);

  server.on('error', (err) => {
    if (err.code === 'EADDRINUSE') {
      console.warn(`[Port Conflict] Port ${PORT} busy. Force freeing port...`);
      cleanPort(PORT);
      setTimeout(() => {
        try { server.close(); } catch (_) {}
        server.listen(PORT, '0.0.0.0');
      }, 500);
    } else {
      console.error('[Server Error]', err);
      process.exit(1);
    }
  });

  server.listen(PORT, '0.0.0.0', () => {
    const localIps = getLocalIps();
    console.log(`====================================================`);
    console.log(` Master DND Backend Server is running!`);
    console.log(` Local:    http://localhost:${PORT}`);
    for (const ip of localIps) {
      console.log(` Network:  http://${ip}:${PORT}`);
    }
    console.log(` Health:   http://localhost:${PORT}/api/health`);
    console.log(` Status:   Rock-solid stability across all devices`);
    console.log(`====================================================`);
  });

  const shutdown = () => {
    console.log('\nShutting down server gracefully...');
    server.close(() => {
      console.log('HTTP server closed.');
      process.exit(0);
    });
  };

  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
};

startServer();
