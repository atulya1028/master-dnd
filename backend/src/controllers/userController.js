const User = require('../models/User');
const DndProfile = require('../models/DndProfile');
const DndRule = require('../models/DndRule');
const { getIsConnected } = require('../config/db');
const devStore = require('../utils/devStore');

/**
 * GET /api/user/profile
 */
const getProfileHandler = async (req, res) => {
  try {
    const user = req.user;
    return res.status(200).json({
      success: true,
      user: {
        id: user._id,
        phone: user.phone,
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
    const userId = req.user._id.toString();

    let updatedUser = null;

    if (getIsConnected()) {
      const user = await User.findById(userId);
      if (!user) {
        return res.status(404).json({ success: false, message: 'User not found' });
      }

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

      // Mark profile complete if name is provided
      if (user.name && user.name.length > 0) {
        user.isProfileComplete = true;
      }

      updatedUser = await user.save();
    } else {
      // DevStore fallback
      const user = devStore.users.get(userId);
      if (!user) {
        return res.status(404).json({ success: false, message: 'User not found' });
      }

      if (name !== undefined) user.name = name.trim();
      if (email !== undefined) user.email = email.trim().toLowerCase();
      if (avatar !== undefined) user.avatar = avatar;
      if (bio !== undefined) user.bio = bio;
      if (emergencyContacts !== undefined) user.emergencyContacts = emergencyContacts;
      if (notificationPreferences !== undefined) {
        user.notificationPreferences = {
          ...(user.notificationPreferences || {}),
          ...notificationPreferences,
        };
      }

      if (user.name && user.name.length > 0) {
        user.isProfileComplete = true;
      }
      user.updatedAt = new Date().toISOString();
      devStore.users.set(userId, user);
      updatedUser = user;
    }

    return res.status(200).json({
      success: true,
      message: 'Profile updated successfully',
      isProfileComplete: Boolean(updatedUser.isProfileComplete),
      user: {
        id: updatedUser._id,
        phone: updatedUser.phone,
        name: updatedUser.name,
        email: updatedUser.email,
        avatar: updatedUser.avatar,
        bio: updatedUser.bio,
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
      message: 'Failed to update profile.',
      error: error.message,
    });
  }
};

/**
 * DELETE /api/user/account
 */
const deleteAccountHandler = async (req, res) => {
  try {
    const userId = req.user._id.toString();

    if (getIsConnected()) {
      await User.findByIdAndDelete(userId);
      await DndProfile.deleteMany({ userId });
      await DndRule.deleteMany({ userId });
    } else {
      devStore.users.delete(userId);
      for (const [id, p] of devStore.profiles.entries()) {
        if (p.userId === userId) devStore.profiles.delete(id);
      }
      for (const [id, r] of devStore.rules.entries()) {
        if (r.userId === userId) devStore.rules.delete(id);
      }
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
