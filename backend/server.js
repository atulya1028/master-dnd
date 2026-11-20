require('dotenv').config();
const http = require('http');
const app = require('./src/app');
const { connectDB } = require('./src/config/db');

const PORT = process.env.PORT || 5001;

const startServer = async () => {
  // Connect to database
  await connectDB();

  const server = http.createServer(app);

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
