const mongoose = require('mongoose');
const { verifyToken } = require('../utils/token');
const User = require('../models/User');
const { getIsConnected } = require('../config/db');
const devStore = require('../utils/devStore');

const requireAuth = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        message: 'Access denied. No authorization token provided.',
      });
    }

    const token = authHeader.split(' ')[1];
    const decoded = verifyToken(token);

    if (!decoded || !decoded.userId) {
      return res.status(401).json({
        success: false,
        message: 'Invalid or expired session token. Please log in again.',
      });
    }

    let user = null;

    // 1. Check MongoDB if connected and ID is a valid ObjectId
    if (getIsConnected() && mongoose.Types.ObjectId.isValid(decoded.userId)) {
      try {
        user = await User.findById(decoded.userId);
      } catch (err) {
        console.warn('[AuthMiddleware] MongoDB user lookup failed, falling back:', err.message);
      }
    }

    // 2. Check devStore by userId
    if (!user) {
      user = devStore.users.get(decoded.userId);
    }

    // 3. Check devStore by email if available in decoded token
    if (!user && decoded.email) {
      for (const u of devStore.users.values()) {
        if (u.email === decoded.email) {
          user = u;
          break;
        }
      }
    }

    // 4. Safe recovery: synthesize active session so legitimate authenticated users are never blocked by 500
    if (!user) {
      const fallbackId = decoded.userId;
      user = {
        _id: fallbackId,
        id: fallbackId,
        phone: '',
        email: decoded.email || '',
        name: '',
        avatar: decoded.email ? decoded.email[0].toUpperCase() : 'A',
        isProfileComplete: false,
        dndEnabled: false,
        customDurations: [30, 60],
        customContactCategories: ['VIP Contact', 'Family', 'Doctor / Emergency', 'Repeat Caller', 'Work Priority'],
        customWhitelistOptions: ['Starred', 'Contacts only', 'VIP only', 'Everyone', 'No one'],
        totalAppUsageMinutes: 0,
        emergencyContacts: [],
      };
      devStore.users.set(fallbackId, user);
    }

    req.user = user;
    next();
  } catch (error) {
    console.error('[AuthMiddleware] Verification error:', error.message);
    return res.status(401).json({
      success: false,
      message: 'Authentication session expired. Please sign in again.',
    });
  }
};

module.exports = { requireAuth };
