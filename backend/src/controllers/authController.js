const User = require('../models/User');
const Otp = require('../models/Otp');
const DndProfile = require('../models/DndProfile');
const DndRule = require('../models/DndRule');
const { generateOtp } = require('../utils/otpHelper');
const { sendOtpEmail } = require('../utils/mailer');
const { generateToken } = require('../utils/token');
const { getIsConnected } = require('../config/db');
const devStore = require('../utils/devStore');
const {
  DEFAULT_DURATIONS,
  DEFAULT_CONTACT_CATEGORIES,
  DEFAULT_WHITELIST_OPTIONS,
  serializeUser,
} = require('../utils/serializers');

/**
 * Validates email format
 */
const isValidEmail = (email) => {
  return typeof email === 'string' && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim());
};

/**
 * POST /api/auth/send-otp
 * Dedicated Email OTP handler
 */
const sendOtpHandler = async (req, res) => {
  try {
    const rawTarget = req.body.email || req.body.identifier || req.body.phone;

    if (!rawTarget || typeof rawTarget !== 'string' || !isValidEmail(rawTarget)) {
      return res.status(400).json({
        success: false,
        message: 'Please provide a valid email address (e.g. name@example.com).',
      });
    }

    const identifier = rawTarget.trim().toLowerCase();

    // Optional email whitelist enforcement
    if (process.env.ALLOWED_EMAILS && process.env.ALLOWED_EMAILS.trim().length > 0) {
      const allowedList = process.env.ALLOWED_EMAILS
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .filter((e) => e.length > 0);
      if (allowedList.length > 0 && !allowedList.includes(identifier)) {
        return res.status(403).json({
          success: false,
          message: 'Access restricted: This email is not authorized to sign in.',
        });
      }
    }

    const isProduction = process.env.NODE_ENV === 'production';
    const reviewerEmail = (process.env.REVIEWER_EMAIL || '').trim().toLowerCase();
    const reviewerOtp = (process.env.REVIEWER_OTP || '').trim();
    const isReviewerAccount = Boolean(reviewerEmail && reviewerOtp && identifier === reviewerEmail);

    // In production, ALWAYS enforce real OTP unless an explicit REVIEWER_EMAIL + REVIEWER_OTP
    // pair is configured in environment variables for Play Store review.
    const useRealOtp = isProduction || process.env.REAL_OTP === 'true' || !process.env.FIXED_DEV_OTP;
    const otpCode = isReviewerAccount
      ? reviewerOtp
      : (useRealOtp ? generateOtp() : process.env.FIXED_DEV_OTP);
    const expiresAt = new Date(Date.now() + (isReviewerAccount ? 30 * 24 * 60 : 5) * 60 * 1000);

    // Always store in memory for ultra-fast, 100% resilient verification
    devStore.otps.set(identifier, {
      identifier,
      email: identifier,
      otp: otpCode,
      expiresAt,
      verified: false,
      attempts: 0,
    });

    // Also persist to MongoDB if connected
    if (getIsConnected()) {
      try {
        await Otp.deleteMany({ identifier });
        await Otp.create({
          identifier,
          email: identifier,
          otp: otpCode,
          expiresAt,
          verified: false,
          attempts: 0,
        });
      } catch (dbErr) {
        console.warn('[sendOtpHandler] MongoDB OTP persistence warning:', dbErr.message);
      }
    }

    // Deliver real email via SMTP in background so HTTP response returns instantly (<50ms)
    sendOtpEmail(identifier, otpCode).catch((err) => {
      console.error('[sendOtpEmail Background Error]:', err);
    });

    return res.status(200).json({
      success: true,
      message: `OTP sent successfully to ${identifier}.`,
      identifier,
      email: identifier,
      channel: 'email',
      expiresInSeconds: 300,
      delivered: true,
    });
  } catch (error) {
    console.error('[sendOtpHandler] Error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to send verification code. Please try again.',
      error: error.message,
    });
  }
};

/**
 * POST /api/auth/verify-otp
 * Dedicated Email OTP verification
 */
const verifyOtpHandler = async (req, res) => {
  try {
    const rawTarget = req.body.email || req.body.identifier || req.body.phone;
    const { otp } = req.body;

    if (!rawTarget || !otp) {
      return res.status(400).json({
        success: false,
        message: 'A valid email address and 6-digit OTP code are required.',
      });
    }

    const identifier = rawTarget.trim().toLowerCase();

    // Optional email whitelist enforcement
    if (process.env.ALLOWED_EMAILS && process.env.ALLOWED_EMAILS.trim().length > 0) {
      const allowedList = process.env.ALLOWED_EMAILS
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .filter((e) => e.length > 0);
      if (allowedList.length > 0 && !allowedList.includes(identifier)) {
        return res.status(403).json({
          success: false,
          message: 'Access restricted: This email is not authorized to sign in.',
        });
      }
    }
    const trimmedOtp = otp.toString().trim();
    const reviewerEmail = (process.env.REVIEWER_EMAIL || '').trim().toLowerCase();
    const reviewerOtp = (process.env.REVIEWER_OTP || '').trim();
    const isReviewerMatch = Boolean(
      reviewerEmail && reviewerOtp && identifier === reviewerEmail && trimmedOtp === reviewerOtp
    );

    let record = null;
    if (!isReviewerMatch) {
      if (getIsConnected()) {
        try {
          record = await Otp.findOne({
            $or: [{ identifier }, { email: identifier }],
          }).sort({ createdAt: -1 });
        } catch (dbErr) {
          console.warn('[verifyOtpHandler] MongoDB OTP lookup warning:', dbErr.message);
        }
      }
      if (!record) {
        record = devStore.otps.get(identifier);
      }

      // Check if OTP was requested
      if (!record) {
        return res.status(400).json({
          success: false,
          message: 'No active OTP request found. Please request a new code.',
        });
      }

      // Check if expired
      if (new Date() > new Date(record.expiresAt)) {
        return res.status(400).json({
          success: false,
          message: 'This OTP code has expired. Please tap Resend Code.',
        });
      }

      // Check attempt lockout
      if (record.attempts >= 5) {
        return res.status(429).json({
          success: false,
          message: 'Too many incorrect attempts. Please request a new code.',
        });
      }

      // Strictly enforce real OTP verification
      const isMatch = record.otp === trimmedOtp;

      if (!isMatch) {
        record.attempts = (record.attempts || 0) + 1;
        if (getIsConnected() && typeof record.save === 'function') {
          try {
            await record.save();
          } catch (_) {}
        }
        return res.status(400).json({
          success: false,
          message: 'Invalid verification code. Please check and try again.',
          attemptsLeft: 5 - record.attempts,
        });
      }

      // Mark OTP as verified
      record.verified = true;
      if (getIsConnected() && typeof record.save === 'function') {
        try {
          await record.save();
        } catch (_) {}
      }
    }

    // Find or create User by email
    let user = null;
    let isNewUser = false;

    if (getIsConnected()) {
      try {
        user = await User.findOne({ email: identifier });

        if (!user) {
          user = await User.create({
            phone: '',
            email: identifier,
            name: '',
            avatar: identifier.charAt(0).toUpperCase() || 'A',
            isProfileComplete: false,
            dndEnabled: false,
            hasSeededDefaults: true,
            customDurations: DEFAULT_DURATIONS,
            customContactCategories: DEFAULT_CONTACT_CATEGORIES,
            customWhitelistOptions: DEFAULT_WHITELIST_OPTIONS,
          });
          isNewUser = true;

          // Seed initial default DND profiles for this user
          const defaultProfiles = devStore.getDefaultProfiles(user._id);
          for (const p of defaultProfiles) {
            const { _id, ...rest } = p;
            try {
              await DndProfile.create(rest);
            } catch (_) {}
          }

          // Seed default rules
          const defaultRules = devStore.getDefaultRules(user._id);
          for (const r of defaultRules) {
            const { _id, ...rest } = r;
            try {
              await DndRule.create(rest);
            } catch (_) {}
          }
        }
      } catch (dbErr) {
        console.warn('[verifyOtpHandler] MongoDB User lookup/create failed, falling back:', dbErr.message);
        user = null;
      }
    }

    if (!user) {
      // In-memory fallback
      for (const u of devStore.users.values()) {
        if (u.email === identifier) {
          user = u;
          break;
        }
      }

      if (!user) {
        const id = devStore.genId();
        user = {
          id,
          _id: id,
          phone: '',
          email: identifier,
          name: '',
          avatar: identifier.charAt(0).toUpperCase() || 'A',
          isProfileComplete: false,
          dndEnabled: false,
          hasSeededDefaults: true,
          customDurations: [...DEFAULT_DURATIONS],
          customContactCategories: [...DEFAULT_CONTACT_CATEGORIES],
          customWhitelistOptions: [...DEFAULT_WHITELIST_OPTIONS],
          totalAppUsageMinutes: 0,
          emergencyContacts: [],
        };
        isNewUser = true;

        const defP = devStore.getDefaultProfiles(id);
        for (const p of defP) {
          devStore.profiles.set(p._id, p);
        }
        const defR = devStore.getDefaultRules(id);
        for (const r of defR) {
          devStore.rules.set(r._id, r);
        }
      }
    }

    // Mirror user in memory store for zero-latency subsequent operations
    const strUserId = (user._id || user.id).toString();
    devStore.users.set(strUserId, user);
    devStore.users.set(identifier, user);

    const token = generateToken({
      userId: user._id.toString(),
      email: user.email,
    });

    return res.status(200).json({
      success: true,
      message: isNewUser ? 'Account created successfully' : 'Login successful',
      token,
      isNewUser,
      isProfileComplete: Boolean(user.isProfileComplete),
      user: serializeUser(user),
    });
  } catch (error) {
    console.error('[verifyOtpHandler] Error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to verify OTP code.',
      error: error.message,
    });
  }
};

module.exports = {
  sendOtpHandler,
  verifyOtpHandler,
};
