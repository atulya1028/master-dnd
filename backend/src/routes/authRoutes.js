const express = require('express');
const router = express.Router();
const rateLimit = require('express-rate-limit');
const { sendOtpHandler, verifyOtpHandler } = require('../controllers/authController');

// Rate limiter for OTP requests: max 10 requests per 1 hour (reset every 1 hour)
const OTP_MAX_REQUESTS = parseInt(process.env.OTP_RATE_LIMIT || '10', 10);
const OTP_WINDOW_MS = parseInt(process.env.OTP_RATE_WINDOW_MINUTES || '60', 10) * 60 * 1000;

const otpLimiter = rateLimit({
  windowMs: OTP_WINDOW_MS, // 1 hour (60 minutes)
  max: OTP_MAX_REQUESTS,   // Max 10 OTP requests per hour
  standardHeaders: true,
  legacyHeaders: false,
  validate: { xForwardedForHeader: false, default: false },
  keyGenerator: (req) => {
    // Rate limit per target email address (falls back to client IP)
    const rawTarget = req.body && (req.body.email || req.body.identifier || req.body.phone);
    if (rawTarget && typeof rawTarget === 'string' && rawTarget.trim().length > 0) {
      return `otp_limit_${rawTarget.trim().toLowerCase()}`;
    }
    return req.ip || '127.0.0.1';
  },
  handler: (req, res) => {
    const resetTime = req.rateLimit && req.rateLimit.resetTime;
    const diffMs = resetTime ? Math.max(0, resetTime.getTime() - Date.now()) : OTP_WINDOW_MS;
    const diffMinutes = Math.max(1, Math.ceil(diffMs / (60 * 1000)));

    return res.status(429).json({
      success: false,
      message: `Too many OTP requests. Limit is ${OTP_MAX_REQUESTS} requests per hour. Please try again in ${diffMinutes} minute${diffMinutes > 1 ? 's' : ''}.`,
      limit: OTP_MAX_REQUESTS,
      windowMinutes: Math.round(OTP_WINDOW_MS / 60000),
      retryAfterMinutes: diffMinutes,
    });
  },
});

router.post('/send-otp', otpLimiter, sendOtpHandler);
router.post('/resend-otp', otpLimiter, sendOtpHandler);
router.post('/verify-otp', verifyOtpHandler);

module.exports = router;
