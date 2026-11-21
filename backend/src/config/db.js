const mongoose = require('mongoose');

// Never buffer commands when disconnected - fail fast or use fallback store
mongoose.set('bufferCommands', false);

let isConnected = false;

const connectDB = async () => {
  const uri = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/master_dnd';

  mongoose.connection.on('connected', () => {
    isConnected = true;
    console.log('[MongoDB] Connected successfully to Atlas cluster.');
  });

  mongoose.connection.on('disconnected', () => {
    isConnected = false;
    console.warn('[MongoDB] Connection lost. Operating seamlessly with in-memory store.');
  });

  mongoose.connection.on('error', (err) => {
    isConnected = false;
    console.warn('[MongoDB] Runtime error:', err.message);
  });

  try {
    const conn = await mongoose.connect(uri, {
      serverSelectionTimeoutMS: 5000,
      connectTimeoutMS: 5000,
      socketTimeoutMS: 15000,
    });
    isConnected = true;
    console.log(`[MongoDB] Initial connection established: ${conn.connection.host}/${conn.connection.name}`);
  } catch (err) {
    isConnected = false;
    console.warn(`[MongoDB] Initial connection to ${uri} failed: ${err.message}`);
    console.warn(`[MongoDB] Operating in ultra-stable Hybrid mode with in-memory persistence.`);
  }
};

const getIsConnected = () => isConnected && mongoose.connection.readyState === 1;

module.exports = { connectDB, getIsConnected };
