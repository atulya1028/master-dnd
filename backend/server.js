require('dotenv').config();
const http = require('http');
const { execSync } = require('child_process');
const app = require('./src/app');
const { connectDB } = require('./src/config/db');

const PORT = process.env.PORT || 5001;

const startServer = async () => {
  // Connect to database
  await connectDB();

  const server = http.createServer(app);

  server.on('error', (err) => {
    if (err.code === 'EADDRINUSE') {
      console.warn(`[Port Conflict] Port ${PORT} is busy. Automatically reclaiming port...`);
      try {
        if (process.platform === 'win32') {
          execSync(`for /f "tokens=5" %a in ('netstat -aon ^| findstr :${PORT}') do taskkill /f /pid %a`, { stdio: 'ignore' });
        } else {
          execSync(`lsof -ti :${PORT} | xargs kill -9 2>/dev/null || true`, { stdio: 'ignore' });
        }
        console.log(`[Port Conflict] Port ${PORT} cleared! Resuming server...`);
        setTimeout(() => {
          server.close();
          server.listen(PORT, '0.0.0.0');
        }, 800);
      } catch (_) {
        console.error(`[Error] Could not automatically free port ${PORT}. Run: lsof -ti :${PORT} | xargs kill -9`);
        process.exit(1);
      }
    } else {
      console.error('[Server Error]', err);
      process.exit(1);
    }
  });

  server.listen(PORT, '0.0.0.0', () => {
    console.log(`====================================================`);
    console.log(` Master DND Backend Server is running!`);
    console.log(` URL: http://localhost:${PORT}`);
    console.log(` Health check: http://localhost:${PORT}/api/health`);
    console.log(` Environment: ${process.env.NODE_ENV || 'development'}`);
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
