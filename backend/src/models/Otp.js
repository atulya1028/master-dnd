const mongoose = require('mongoose');

const otpSchema = new mongoose.Schema(
  {
    // Can be a phone number (+1234567890) or an email address (user@example.com)
    identifier: {
      type: String,
      required: true,
      index: true,
    },
    phone: {
      type: String,
      index: true,
    },
    email: {
      type: String,
      index: true,
    },
    otp: {
      type: String,
      required: true,
    },
    expiresAt: {
      type: Date,
      required: true,
      index: { expires: '5m' }, // Auto delete after expiry
    },
    verified: {
      type: Boolean,
      default: false,
    },
    attempts: {
      type: Number,
      default: 0,
    },
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model('Otp', otpSchema);
