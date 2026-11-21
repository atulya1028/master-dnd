const mongoose = require('mongoose');
const User = require('../models/User');
const DndProfile = require('../models/DndProfile');
const DndRule = require('../models/DndRule');
const { getIsConnected } = require('../config/db');
const devStore = require('../utils/devStore');

const isValidObjectId = (val) => Boolean(val && mongoose.Types.ObjectId.isValid(val));

/**
 * GET /api/user/profile
 */
const getProfileHandler = async (req, res) => {
  try {
    const user = req.user;
    return res.status(200).json({
      success: true,
      user: {
        id: user._id || user.id,
        phone: user.phone || '',
        name: user.name || '',
        email: user.email || '',
        avatar: user.avatar || (user.name ? user.name[0].toUpperCase() : 'A'),
        bio: user.bio || '',
        isProfileComplete: Boolean(user.isProfileComplete),
        dndEnabled: Boolean(user.dndEnabled),
        emergencyContacts: user.emergencyContacts || [],
        notificationPreferences: user.notificationPreferences || {
          allowDndAccess: true,
          allowContacts: true,
          allowNotifications: true,
        },
      },
    });
  } catch (error) {
    console.error('[getProfileHandler] Error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to retrieve user profile.',
      error: error.message,
    });
  }
};

/**
 * PUT /api/user/profile
 * Setup or edit user profile
 */
const updateProfileHandler = async (req, res) => {
  try {
    const { name, email, avatar, bio, emergencyContacts, notificationPreferences } = req.body;
    const userId = (req.user._id || req.user.id).toString();

    let updatedUser = null;

    if (getIsConnected() && isValidObjectId(userId)) {
      try {
        const user = await User.findById(userId);
        if (user) {
          if (name !== undefined) user.name = name.trim();
          if (email !== undefined) user.email = email.trim().toLowerCase();
          if (avatar !== undefined) user.avatar = avatar;
          if (bio !== undefined) user.bio = bio;
          if (emergencyContacts !== undefined) user.emergencyContacts = emergencyContacts;
          if (notificationPreferences !== undefined) {
            user.notificationPreferences = {
              ...user.notificationPreferences,
              ...notificationPreferences,
            };
          }
          if (user.name && user.name.length > 0) {
            user.isProfileComplete = true;
          }
          updatedUser = await user.save();
        }
      } catch (dbErr) {
        console.warn('[updateProfileHandler] MongoDB update warning:', dbErr.message);
      }
    }

    // In-memory update / fallback
    let devUser = devStore.users.get(userId);
    if (!devUser && req.user) {
      devUser = req.user;
    }
    if (devUser) {
      if (name !== undefined) devUser.name = name.trim();
      if (email !== undefined) devUser.email = email.trim().toLowerCase();
      if (avatar !== undefined) devUser.avatar = avatar;
      if (bio !== undefined) devUser.bio = bio;
      if (emergencyContacts !== undefined) devUser.emergencyContacts = emergencyContacts;
      if (notificationPreferences !== undefined) {
        devUser.notificationPreferences = {
          ...(devUser.notificationPreferences || {}),
          ...notificationPreferences,
        };
      }
      if (devUser.name && devUser.name.length > 0) {
        devUser.isProfileComplete = true;
      }
      devUser.updatedAt = new Date().toISOString();
      devStore.users.set(userId, devUser);
      if (!updatedUser) updatedUser = devUser;
    }

    if (!updatedUser) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    return res.status(200).json({
      success: true,
      message: 'Profile updated successfully',
      isProfileComplete: Boolean(updatedUser.isProfileComplete),
      user: {
        id: updatedUser._id || updatedUser.id,
        phone: updatedUser.phone || '',
        name: updatedUser.name || '',
        email: updatedUser.email || '',
        avatar: updatedUser.avatar || 'A',
        bio: updatedUser.bio || '',
        isProfileComplete: Boolean(updatedUser.isProfileComplete),
        dndEnabled: Boolean(updatedUser.dndEnabled),
        emergencyContacts: updatedUser.emergencyContacts || [],
        notificationPreferences: updatedUser.notificationPreferences,
      },
    });
  } catch (error) {
    console.error('[updateProfileHandler] Error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to update user profile.',
      error: error.message,
    });
  }
};

/**
 * DELETE /api/user/account
 */
const deleteAccountHandler = async (req, res) => {
  try {
    const userId = (req.user._id || req.user.id).toString();

    if (getIsConnected() && isValidObjectId(userId)) {
      try {
        await User.findByIdAndDelete(userId);
        await DndProfile.deleteMany({ userId });
        await DndRule.deleteMany({ userId });
      } catch (dbErr) {
        console.warn('[deleteAccountHandler] MongoDB delete warning:', dbErr.message);
      }
    }

    devStore.users.delete(userId);
    for (const [id, p] of devStore.profiles.entries()) {
      if (p.userId === userId) devStore.profiles.delete(id);
    }
    for (const [id, r] of devStore.rules.entries()) {
      if (r.userId === userId) devStore.rules.delete(id);
    }

    return res.status(200).json({
      success: true,
      message: 'Account and associated data deleted successfully.',
    });
  } catch (error) {
    console.error('[deleteAccountHandler] Error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to delete account.',
      error: error.message,
    });
  }
};

module.exports = {
  getProfileHandler,
  updateProfileHandler,
  deleteAccountHandler,
};
