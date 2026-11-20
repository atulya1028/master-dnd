const express = require('express');
const router = express.Router();
const rateLimit = require('express-rate-limit');
const { sendOtpHandler, verifyOtpHandler } = require('../controllers/authController');

// Rate limiter for OTP requests: max 15 requests per 10 minutes per IP
const otpLimiter = rateLimit({
  windowMs: 10 * 60 * 1000,
  max: 15,
  message: {
    success: false,
    message: 'Too many OTP requests from this connection. Please try again after 10 minutes.',
  },
  standardHeaders: true,
  legacyHeaders: false,
});

router.post('/send-otp', otpLimiter, sendOtpHandler);
router.post('/resend-otp', otpLimiter, sendOtpHandler);
router.post('/verify-otp', verifyOtpHandler);

module.exports = router;
