const User = require('../models/User');
const Otp = require('../models/Otp');
const DndProfile = require('../models/DndProfile');
const DndRule = require('../models/DndRule');
const { generateOtp, sendSmsOtp } = require('../utils/otpHelper');
const { sendOtpEmail } = require('../utils/mailer');
const { generateToken } = require('../utils/token');
const { getIsConnected } = require('../config/db');
const devStore = require('../utils/devStore');

/**
 * Normalizes phone numbers to standard format (digits only or leading +)
 */
const normalizePhone = (phone) => {
  if (!phone) return '';
  const clean = phone.replace(/[^\d+]/g, '');
  return clean.startsWith('+') ? clean : `+${clean}`;
};

/**
 * Validates email format
 */
const isValidEmail = (email) => {
  return typeof email === 'string' && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim());
};

/**
 * POST /api/auth/send-otp
 * Supports both Phone numbers (+1234567890) and Email addresses (user@example.com)
 */
const sendOtpHandler = async (req, res) => {
  try {
    const rawTarget = req.body.email || req.body.phone || req.body.identifier;

    if (!rawTarget || typeof rawTarget !== 'string') {
      return res.status(400).json({
        success: false,
        message: 'A valid phone number or email address is required.',
      });
    }

    const isEmail = rawTarget.includes('@');
    let identifier = '';
    let channel = 'sms';

    if (isEmail) {
      if (!isValidEmail(rawTarget)) {
        return res.status(400).json({
          success: false,
          message: 'Please provide a valid email address (e.g. name@example.com).',
        });
      }
      identifier = rawTarget.trim().toLowerCase();
      channel = 'email';
    } else {
      const phone = normalizePhone(rawTarget);
      if (phone.length < 8 || phone.length > 16) {
        return res.status(400).json({
          success: false,
          message: 'Please provide a valid phone number (e.g. +1234567890).',
        });
      }
      identifier = phone;
      channel = 'sms';
    }

    // Default development test OTP: 123456 or dynamically generated 6-digit code
    const isDev = process.env.NODE_ENV !== 'production';
    const otpCode = isDev && process.env.FIXED_DEV_OTP ? process.env.FIXED_DEV_OTP : generateOtp();
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000); // 5 minutes

    if (getIsConnected()) {
      // Remove any pending OTPs for this identifier
      await Otp.deleteMany({ identifier });
      await Otp.create({
        identifier,
        phone: !isEmail ? identifier : undefined,
        email: isEmail ? identifier : undefined,
        otp: otpCode,
        expiresAt,
        verified: false,
        attempts: 0,
      });
    } else {
      devStore.otps.set(identifier, {
        identifier,
        phone: !isEmail ? identifier : undefined,
        email: isEmail ? identifier : undefined,
        otp: otpCode,
        expiresAt,
        verified: false,
        attempts: 0,
      });
    }

    // Delivery dispatch
    let deliveryResult = { success: true };
    if (channel === 'email') {
      deliveryResult = await sendOtpEmail(identifier, otpCode);
    } else {
      deliveryResult = await sendSmsOtp(identifier, otpCode);
    }

    return res.status(200).json({
      success: true,
      message: `OTP sent successfully to ${identifier}.`,
      identifier,
      phone: !isEmail ? identifier : undefined,
      email: isEmail ? identifier : undefined,
      channel,
      expiresInSeconds: 300,
      delivered: deliveryResult.delivered ?? true,
      // For effortless dev/testing:
      testOtp: isDev ? otpCode : undefined,
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
 */
const verifyOtpHandler = async (req, res) => {
  try {
    const rawTarget = req.body.email || req.body.phone || req.body.identifier;
    const { otp } = req.body;

    if (!rawTarget || !otp) {
      return res.status(400).json({
        success: false,
        message: 'Phone number or email address, and OTP code are required.',
      });
    }

    const isEmail = rawTarget.includes('@');
    const identifier = isEmail ? rawTarget.trim().toLowerCase() : normalizePhone(rawTarget);
    const trimmedOtp = otp.toString().trim();

    let record = null;
    if (getIsConnected()) {
      record = await Otp.findOne({
        $or: [{ identifier }, { phone: identifier }, { email: identifier }],
      }).sort({ createdAt: -1 });
    } else {
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

    // In dev mode, allow master bypass "123456" for convenience if configured, or check exact OTP
    const isDev = process.env.NODE_ENV !== 'production';
    const isMatch = record.otp === trimmedOtp || (isDev && trimmedOtp === '123456');

    if (!isMatch) {
      record.attempts = (record.attempts || 0) + 1;
      if (getIsConnected()) {
        await record.save();
      }
      return res.status(400).json({
        success: false,
        message: 'Invalid verification code. Please check and try again.',
        attemptsLeft: 5 - record.attempts,
      });
    }

    // Mark OTP as verified
    record.verified = true;
    if (getIsConnected()) {
      await record.save();
    }

    // Find or create User
    let user = null;
    let isNewUser = false;

    if (getIsConnected()) {
      user = await User.findOne({
        $or: isEmail ? [{ email: identifier }] : [{ phone: identifier }],
      });

      if (!user) {
        user = await User.create({
          phone: isEmail ? '' : identifier,
          email: isEmail ? identifier : '',
          name: '',
          avatar: 'A',
          isProfileComplete: false,
          dndEnabled: false,
        });
        isNewUser = true;

        // Seed initial default DND profiles for this user
        const defaultProfiles = devStore.getDefaultProfiles(user._id);
        for (const p of defaultProfiles) {
          const { _id, ...rest } = p;
          await DndProfile.create(rest);
        }

        // Seed default rules
        const defaultRules = devStore.getDefaultRules(user._id);
        for (const r of defaultRules) {
          const { _id, ...rest } = r;
          await DndRule.create(rest);
        }
      }
    } else {
      // In-memory fallback
      for (const u of devStore.users.values()) {
        if ((isEmail && u.email === identifier) || (!isEmail && u.phone === identifier)) {
          user = u;
          break;
        }
      }

      if (!user) {
        const id = devStore.genId();
        user = {
          _id: id,
          phone: isEmail ? '' : identifier,
          email: isEmail ? identifier : '',
          name: '',
          avatar: 'A',
          isProfileComplete: false,
          dndEnabled: false,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
        };
        devStore.users.set(id, user);
        isNewUser = true;

        // Seed default profiles
        const defP = devStore.getDefaultProfiles(id);
        for (const p of defP) {
          devStore.profiles.set(p._id, p);
        }
        // Seed default rules
        const defR = devStore.getDefaultRules(id);
        for (const r of defR) {
          devStore.rules.set(r._id, r);
        }
      }
    }

    const token = generateToken({
      userId: user._id.toString(),
      phone: user.phone,
      email: user.email,
    });

    return res.status(200).json({
      success: true,
      message: isNewUser ? 'Account created successfully' : 'Login successful',
      token,
      isNewUser,
      isProfileComplete: Boolean(user.isProfileComplete),
      user: {
        id: user._id,
        phone: user.phone,
        email: user.email,
        name: user.name,
        avatar: user.avatar,
        isProfileComplete: Boolean(user.isProfileComplete),
        dndEnabled: Boolean(user.dndEnabled),
      },
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
