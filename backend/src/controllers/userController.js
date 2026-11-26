const mongoose = require('mongoose');
const User = require('../models/User');
const DndProfile = require('../models/DndProfile');
const DndRule = require('../models/DndRule');
const DndActivityLog = require('../models/DndActivityLog');
const { getIsConnected } = require('../config/db');
const devStore = require('../utils/devStore');
const { serializeUser } = require('../utils/serializers');

const isValidObjectId = (val) => Boolean(val && mongoose.Types.ObjectId.isValid(val));

/**
 * GET /api/user/profile
 */
const getProfileHandler = async (req, res) => {
  try {
    return res.status(200).json({
      success: true,
      user: serializeUser(req.user),
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
    const {
      name,
      email,
      phone,
      avatar,
      bio,
      emergencyContacts,
      notificationPreferences,
      customDurations,
      customContactCategories,
      customWhitelistOptions,
    } = req.body;
    const userId = (req.user._id || req.user.id).toString();

    let updatedUser = null;

    const applyUpdates = (target) => {
      if (name !== undefined) target.name = name.trim();
      if (email !== undefined && email.trim().length > 0) {
        target.email = email.trim().toLowerCase();
      }
      if (phone !== undefined) target.phone = phone.trim();
      if (avatar !== undefined) target.avatar = avatar;
      if (bio !== undefined) target.bio = bio;
      if (emergencyContacts !== undefined) target.emergencyContacts = emergencyContacts;
      if (notificationPreferences !== undefined) {
        target.notificationPreferences = {
          ...(target.notificationPreferences || {}),
          ...notificationPreferences,
        };
      }
      if (Array.isArray(customDurations) && customDurations.length > 0) {
        target.customDurations = [...new Set(customDurations.map((n) => Number(n)).filter((n) => n > 0))].sort(
          (a, b) => a - b
        );
      }
      if (Array.isArray(customContactCategories) && customContactCategories.length > 0) {
        target.customContactCategories = [
          ...new Set(customContactCategories.map((s) => String(s).trim()).filter(Boolean)),
        ];
      }
      if (Array.isArray(customWhitelistOptions) && customWhitelistOptions.length > 0) {
        target.customWhitelistOptions = [
          ...new Set(customWhitelistOptions.map((s) => String(s).trim()).filter(Boolean)),
        ];
      }
      if (target.name && target.name.length > 0) {
        target.isProfileComplete = true;
      }
    };

    if (getIsConnected() && isValidObjectId(userId)) {
      try {
        const user = await User.findById(userId);
        if (user) {
          applyUpdates(user);
          updatedUser = await user.save();
        }
      } catch (dbErr) {
        console.warn('[updateProfileHandler] MongoDB update warning:', dbErr.message);
      }
    }

    let devUser = devStore.users.get(userId) || req.user;
    if (devUser) {
      applyUpdates(devUser);
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
      user: serializeUser(updatedUser),
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
 * PUT /api/user/preferences
 * Persist user-entered custom durations, contact categories, whitelist options, and permissions
 */
const updatePreferencesHandler = async (req, res) => {
  try {
    const userId = (req.user._id || req.user.id).toString();
    const {
      addDurationMinutes,
      removeDurationMinutes,
      customDurations,
      addContactCategory,
      customContactCategories,
      addWhitelistOption,
      customWhitelistOptions,
      notificationPreferences,
      activeSessionPlannedMinutes,
      activeSessionEndTime,
      activeProfileName,
    } = req.body;

    const applyPrefUpdates = (target) => {
      if (Array.isArray(customDurations)) {
        target.customDurations = [...new Set(customDurations.map(Number).filter((n) => n > 0))].sort(
          (a, b) => a - b
        );
      }
      if (addDurationMinutes !== undefined) {
        const val = Number(addDurationMinutes);
        if (val > 0 && val <= 1440) {
          const existing = Array.isArray(target.customDurations) && target.customDurations.length > 0
            ? [...target.customDurations]
            : [30, 60];
          if (!existing.includes(val)) existing.push(val);
          target.customDurations = existing.sort((a, b) => a - b);
        }
      }
      if (removeDurationMinutes !== undefined) {
        const val = Number(removeDurationMinutes);
        const existing = Array.isArray(target.customDurations) ? target.customDurations : [30, 60];
        const filtered = existing.filter((d) => d !== val);
        if (filtered.length > 0) target.customDurations = filtered;
      }

      if (Array.isArray(customContactCategories)) {
        target.customContactCategories = [
          ...new Set(customContactCategories.map((s) => String(s).trim()).filter(Boolean)),
        ];
      }
      if (addContactCategory && String(addContactCategory).trim()) {
        const cat = String(addContactCategory).trim();
        const existing =
          Array.isArray(target.customContactCategories) && target.customContactCategories.length > 0
            ? [...target.customContactCategories]
            : ['VIP Contact', 'Family', 'Doctor / Emergency', 'Repeat Caller', 'Work Priority'];
        if (!existing.includes(cat)) existing.push(cat);
        target.customContactCategories = existing;
      }

      if (Array.isArray(customWhitelistOptions)) {
        target.customWhitelistOptions = [
          ...new Set(customWhitelistOptions.map((s) => String(s).trim()).filter(Boolean)),
        ];
      }
      if (addWhitelistOption && String(addWhitelistOption).trim()) {
        const opt = String(addWhitelistOption).trim();
        const existing =
          Array.isArray(target.customWhitelistOptions) && target.customWhitelistOptions.length > 0
            ? [...target.customWhitelistOptions]
            : ['Starred', 'Contacts only', 'VIP only', 'Everyone', 'No one'];
        if (!existing.includes(opt)) existing.push(opt);
        target.customWhitelistOptions = existing;
      }

      if (notificationPreferences !== undefined) {
        target.notificationPreferences = {
          ...(target.notificationPreferences || {}),
          ...notificationPreferences,
        };
      }
      if (activeSessionPlannedMinutes !== undefined) {
        target.activeSessionPlannedMinutes = Number(activeSessionPlannedMinutes) || 60;
      }
      if (activeSessionEndTime !== undefined) {
        target.activeSessionEndTime = activeSessionEndTime ? new Date(activeSessionEndTime) : null;
      }
      if (activeProfileName !== undefined) {
        target.activeProfileName = String(activeProfileName);
      }
    };

    let updatedUser = null;
    if (getIsConnected() && isValidObjectId(userId)) {
      try {
        const user = await User.findById(userId);
        if (user) {
          applyPrefUpdates(user);
          updatedUser = await user.save();
        }
      } catch (dbErr) {
        console.warn('[updatePreferencesHandler] MongoDB warning:', dbErr.message);
      }
    }

    const devUser = devStore.users.get(userId) || req.user;
    if (devUser) {
      applyPrefUpdates(devUser);
      devStore.users.set(userId, devUser);
      if (!updatedUser) updatedUser = devUser;
    }

    return res.status(200).json({
      success: true,
      message: 'Preferences saved',
      user: serializeUser(updatedUser),
    });
  } catch (error) {
    console.error('[updatePreferencesHandler] Error:', error);
    return res.status(500).json({ success: false, message: 'Failed to update preferences' });
  }
};

/**
 * GET /api/user/contacts
 */
const getContactsHandler = async (req, res) => {
  try {
    const serialized = serializeUser(req.user);
    return res.status(200).json({
      success: true,
      contacts: serialized.emergencyContacts || [],
      categories: serialized.customContactCategories || [],
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'Failed to fetch contacts' });
  }
};

/**
 * POST /api/user/contacts
 */
const addContactHandler = async (req, res) => {
  try {
    const userId = (req.user._id || req.user.id).toString();
    const { name, phone = '', relationship = 'VIP Contact', isVip = true } = req.body;

    if (!name || !String(name).trim()) {
      return res.status(400).json({ success: false, message: 'Contact name is required' });
    }

    const cleanName = String(name).trim();
    const cleanPhone = String(phone).trim();
    const cleanCategory = String(relationship || 'VIP Contact').trim();

    let savedUser = null;
    let addedContact = null;

    if (getIsConnected() && isValidObjectId(userId)) {
      try {
        const user = await User.findById(userId);
        if (user) {
          user.emergencyContacts.push({
            name: cleanName,
            phone: cleanPhone,
            relationship: cleanCategory,
            isVip: Boolean(isVip),
          });
          if (cleanCategory && !user.customContactCategories.includes(cleanCategory)) {
            user.customContactCategories.push(cleanCategory);
          }
          savedUser = await user.save();
          const last = savedUser.emergencyContacts[savedUser.emergencyContacts.length - 1];
          addedContact = {
            id: last._id.toString(),
            name: last.name,
            phone: last.phone,
            relationship: last.relationship,
            isVip: last.isVip,
          };
        }
      } catch (dbErr) {
        console.warn('[addContactHandler] MongoDB warning:', dbErr.message);
      }
    }

    const devUser = devStore.users.get(userId) || req.user;
    if (devUser && !savedUser) {
      if (!Array.isArray(devUser.emergencyContacts)) devUser.emergencyContacts = [];
      const contactObj = {
        _id: devStore.genId(),
        name: cleanName,
        phone: cleanPhone,
        relationship: cleanCategory,
        isVip: Boolean(isVip),
      };
      devUser.emergencyContacts.push(contactObj);
      if (!Array.isArray(devUser.customContactCategories)) {
        devUser.customContactCategories = ['VIP Contact', 'Family', 'Doctor / Emergency', 'Repeat Caller', 'Work Priority'];
      }
      if (cleanCategory && !devUser.customContactCategories.includes(cleanCategory)) {
        devUser.customContactCategories.push(cleanCategory);
      }
      devStore.users.set(userId, devUser);
      savedUser = devUser;
      addedContact = {
        id: contactObj._id,
        name: contactObj.name,
        phone: contactObj.phone,
        relationship: contactObj.relationship,
        isVip: contactObj.isVip,
      };
    } else if (devUser && savedUser) {
      devStore.users.set(userId, savedUser);
    }

    const serialized = serializeUser(savedUser);
    return res.status(201).json({
      success: true,
      message: 'Allowed contact saved to database',
      contact: addedContact,
      contacts: serialized.emergencyContacts,
      categories: serialized.customContactCategories,
    });
  } catch (error) {
    console.error('[addContactHandler] Error:', error);
    return res.status(500).json({ success: false, message: 'Failed to save contact' });
  }
};

/**
 * DELETE /api/user/contacts/:contactId
 */
const deleteContactHandler = async (req, res) => {
  try {
    const userId = (req.user._id || req.user.id).toString();
    const { contactId } = req.params;
    let savedUser = null;

    if (getIsConnected() && isValidObjectId(userId)) {
      try {
        const user = await User.findById(userId);
        if (user) {
          user.emergencyContacts = user.emergencyContacts.filter(
            (c) => (c._id || c.id || '').toString() !== contactId
          );
          savedUser = await user.save();
        }
      } catch (dbErr) {
        console.warn('[deleteContactHandler] MongoDB warning:', dbErr.message);
      }
    }

    const devUser = devStore.users.get(userId) || req.user;
    if (devUser && !savedUser) {
      devUser.emergencyContacts = (devUser.emergencyContacts || []).filter(
        (c) => (c._id || c.id || '').toString() !== contactId
      );
      devStore.users.set(userId, devUser);
      savedUser = devUser;
    } else if (devUser && savedUser) {
      devStore.users.set(userId, savedUser);
    }

    const serialized = serializeUser(savedUser || req.user);
    return res.status(200).json({
      success: true,
      message: 'Allowed contact removed',
      contacts: serialized.emergencyContacts,
    });
  } catch (error) {
    console.error('[deleteContactHandler] Error:', error);
    return res.status(500).json({ success: false, message: 'Failed to delete contact' });
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
        await DndActivityLog.deleteMany({ userId });
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
    for (const [id, l] of devStore.activityLogs.entries()) {
      if (l.userId === userId) devStore.activityLogs.delete(id);
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
  updatePreferencesHandler,
  getContactsHandler,
  addContactHandler,
  deleteContactHandler,
  deleteAccountHandler,
};
