const mongoose = require('mongoose');

let isConnected = false;

const connectDB = async () => {
  const uri = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/master_dnd';
  
  try {
    const conn = await mongoose.connect(uri, {
      serverSelectionTimeoutMS: 3000, // Quick timeout for local development fallback
    });
    isConnected = true;
    console.log(`[MongoDB] Connected successfully: ${conn.connection.host}/${conn.connection.name}`);
  } catch (err) {
    isConnected = false;
    console.warn(`[MongoDB] Warning: Could not connect to MongoDB at ${uri}.`);
    console.warn(`[MongoDB] Error: ${err.message}`);
    console.warn(`[MongoDB] The server will run in Hybrid/Dev mode. (To use MongoDB, make sure mongod is running or set MONGODB_URI in .env to a MongoDB Atlas cluster URI).`);
  }
};

const getIsConnected = () => isConnected;

module.exports = { connectDB, getIsConnected };
