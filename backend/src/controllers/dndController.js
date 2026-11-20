const User = require('../models/User');
const DndProfile = require('../models/DndProfile');
const DndRule = require('../models/DndRule');
const { getIsConnected } = require('../config/db');
const devStore = require('../utils/devStore');

/**
 * GET /api/dnd/profiles
 */
const getProfilesHandler = async (req, res) => {
  try {
    const userId = req.user._id.toString();
    let profiles = [];

    if (getIsConnected()) {
      profiles = await DndProfile.find({ userId }).sort({ createdAt: 1 });
      // If none found, reseed defaults
      if (profiles.length === 0) {
        const defs = devStore.getDefaultProfiles(userId);
        for (const p of defs) {
          const { _id, ...rest } = p;
          await DndProfile.create(rest);
        }
        profiles = await DndProfile.find({ userId }).sort({ createdAt: 1 });
      }
    } else {
      for (const p of devStore.profiles.values()) {
        if (p.userId === userId) profiles.push(p);
      }
      if (profiles.length === 0) {
        const defs = devStore.getDefaultProfiles(userId);
        for (const p of defs) {
          devStore.profiles.set(p._id, p);
          profiles.push(p);
        }
      }
    }

    return res.status(200).json({
      success: true,
      count: profiles.length,
      profiles: profiles.map((p) => ({
        id: p._id,
        name: p.name,
        icon: p.icon,
        meta: p.meta,
        active: Boolean(p.active),
        mode: p.mode,
        autoReply: Boolean(p.autoReply),
        hideNotifications: Boolean(p.hideNotifications),
        callWhitelist: p.callWhitelist,
        messageWhitelist: p.messageWhitelist,
        repeatCallersWindowMin: p.repeatCallersWindowMin,
      })),
    });
  } catch (error) {
    console.error('[getProfilesHandler] Error:', error);
    return res.status(500).json({ success: false, message: 'Failed to fetch profiles' });
  }
};

/**
 * POST /api/dnd/profiles
 */
const createProfileHandler = async (req, res) => {
  try {
    const userId = req.user._id.toString();
    const {
      name,
      icon = 'moon',
      meta = 'Custom profile',
      mode = 'priorityOnly',
      autoReply = true,
      hideNotifications = false,
      callWhitelist = 'Starred',
      messageWhitelist = 'VIP only',
    } = req.body;

    if (!name) {
      return res.status(400).json({ success: false, message: 'Profile name is required' });
    }

    let newProfile = null;
    if (getIsConnected()) {
      newProfile = await DndProfile.create({
        userId,
        name,
        icon,
        meta,
        active: false,
        mode,
        autoReply,
        hideNotifications,
        callWhitelist,
        messageWhitelist,
      });
    } else {
      const id = devStore.genId();
      newProfile = {
        _id: id,
        userId,
        name,
        icon,
        meta,
        active: false,
        mode,
        autoReply,
        hideNotifications,
        callWhitelist,
        messageWhitelist,
      };
      devStore.profiles.set(id, newProfile);
    }

    return res.status(201).json({
      success: true,
      message: 'Profile created successfully',
      profile: {
        id: newProfile._id,
        name: newProfile.name,
        icon: newProfile.icon,
        meta: newProfile.meta,
        active: false,
        mode: newProfile.mode,
        autoReply: newProfile.autoReply,
        hideNotifications: newProfile.hideNotifications,
      },
    });
  } catch (error) {
    console.error('[createProfileHandler] Error:', error);
    return res.status(500).json({ success: false, message: 'Failed to create profile' });
  }
};

/**
 * PUT /api/dnd/profiles/:id
 */
const updateProfileHandler = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user._id.toString();
    const { name, icon, meta, active, mode, autoReply, hideNotifications, callWhitelist, messageWhitelist } =
      req.body;

    let updated = null;

    if (getIsConnected()) {
      // If setting this profile to active: true, deactivate others
      if (active === true) {
        await DndProfile.updateMany({ userId }, { active: false });
      }

      updated = await DndProfile.findOneAndUpdate(
        { _id: id, userId },
        {
          $set: {
            ...(name !== undefined && { name }),
            ...(icon !== undefined && { icon }),
            ...(meta !== undefined && { meta }),
            ...(active !== undefined && { active }),
            ...(mode !== undefined && { mode }),
            ...(autoReply !== undefined && { autoReply }),
            ...(hideNotifications !== undefined && { hideNotifications }),
            ...(callWhitelist !== undefined && { callWhitelist }),
            ...(messageWhitelist !== undefined && { messageWhitelist }),
          },
        },
        { new: true }
      );
    } else {
      const profile = devStore.profiles.get(id);
      if (profile && profile.userId === userId) {
        if (active === true) {
          for (const p of devStore.profiles.values()) {
            if (p.userId === userId) p.active = false;
          }
        }
        if (name !== undefined) profile.name = name;
        if (icon !== undefined) profile.icon = icon;
        if (meta !== undefined) profile.meta = meta;
        if (active !== undefined) profile.active = active;
        if (mode !== undefined) profile.mode = mode;
        if (autoReply !== undefined) profile.autoReply = autoReply;
        if (hideNotifications !== undefined) profile.hideNotifications = hideNotifications;
        if (callWhitelist !== undefined) profile.callWhitelist = callWhitelist;
        if (messageWhitelist !== undefined) profile.messageWhitelist = messageWhitelist;

        devStore.profiles.set(id, profile);
        updated = profile;
      }
    }

    if (!updated) {
      return res.status(404).json({ success: false, message: 'Profile not found' });
    }

    return res.status(200).json({
      success: true,
      message: 'Profile updated',
      profile: {
        id: updated._id,
        name: updated.name,
        icon: updated.icon,
        meta: updated.meta,
        active: Boolean(updated.active),
        mode: updated.mode,
        autoReply: Boolean(updated.autoReply),
        hideNotifications: Boolean(updated.hideNotifications),
      },
    });
  } catch (error) {
    console.error('[updateProfileHandler] Error:', error);
    return res.status(500).json({ success: false, message: 'Failed to update profile' });
  }
};

/**
 * DELETE /api/dnd/profiles/:id
 */
const deleteProfileHandler = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user._id.toString();

    if (getIsConnected()) {
      await DndProfile.findOneAndDelete({ _id: id, userId });
    } else {
      const p = devStore.profiles.get(id);
      if (p && p.userId === userId) {
        devStore.profiles.delete(id);
      }
    }

    return res.status(200).json({ success: true, message: 'Profile deleted' });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'Failed to delete profile' });
  }
};

/**
 * POST /api/dnd/toggle
 * Toggle the Master DND power button state
 */
const toggleMasterDndHandler = async (req, res) => {
  try {
    const userId = req.user._id.toString();
    const { enabled } = req.body;

    let targetState = enabled;

    if (getIsConnected()) {
      const user = await User.findById(userId);
      if (!user) return res.status(404).json({ success: false, message: 'User not found' });
      if (targetState === undefined) targetState = !user.dndEnabled;
      user.dndEnabled = targetState;
      await user.save();
    } else {
      const user = devStore.users.get(userId);
      if (!user) return res.status(404).json({ success: false, message: 'User not found' });
      if (targetState === undefined) targetState = !user.dndEnabled;
      user.dndEnabled = targetState;
      devStore.users.set(userId, user);
    }

    return res.status(200).json({
      success: true,
      dndEnabled: Boolean(targetState),
      message: targetState ? 'Master DND is now armed' : 'Master DND turned off',
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'Failed to toggle DND' });
  }
};

/**
 * GET /api/dnd/rules
 */
const getRulesHandler = async (req, res) => {
  try {
    const userId = req.user._id.toString();
    let rules = [];

    if (getIsConnected()) {
      rules = await DndRule.find({ userId }).sort({ createdAt: 1 });
      if (rules.length === 0) {
        const defs = devStore.getDefaultRules(userId);
        for (const r of defs) {
          const { _id, ...rest } = r;
          await DndRule.create(rest);
        }
        rules = await DndRule.find({ userId }).sort({ createdAt: 1 });
      }
    } else {
      for (const r of devStore.rules.values()) {
        if (r.userId === userId) rules.push(r);
      }
      if (rules.length === 0) {
        const defs = devStore.getDefaultRules(userId);
        for (const r of defs) {
          devStore.rules.set(r._id, r);
          rules.push(r);
        }
      }
    }

    return res.status(200).json({
      success: true,
      rules: rules.map((r) => ({
        id: r._id,
        title: r.title,
        subtitle: r.subtitle,
        triggerType: r.triggerType,
        active: Boolean(r.active),
      })),
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'Failed to fetch rules' });
  }
};

/**
 * POST /api/dnd/rules
 */
const createRuleHandler = async (req, res) => {
  try {
    const userId = req.user._id.toString();
    const { title, subtitle = '', triggerType = 'schedule', active = true } = req.body;

    if (!title || !title.trim()) {
      return res.status(400).json({ success: false, message: 'Rule title is required' });
    }

    let newRule = null;
    if (getIsConnected()) {
      newRule = await DndRule.create({
        userId,
        title: title.trim(),
        subtitle: subtitle.trim(),
        triggerType,
        active: Boolean(active),
      });
    } else {
      const id = devStore.genId();
      newRule = {
        _id: id,
        userId,
        title: title.trim(),
        subtitle: subtitle.trim(),
        triggerType,
        active: Boolean(active),
      };
      devStore.rules.set(id, newRule);
    }

    return res.status(201).json({
      success: true,
      message: 'Rule created successfully',
      rule: {
        id: newRule._id,
        title: newRule.title,
        subtitle: newRule.subtitle,
        triggerType: newRule.triggerType,
        active: Boolean(newRule.active),
      },
    });
  } catch (error) {
    console.error('[createRuleHandler] Error:', error);
    return res.status(500).json({ success: false, message: 'Failed to create rule' });
  }
};

/**
 * PUT /api/dnd/rules/:id
 */
const updateRuleHandler = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user._id.toString();
    const { title, subtitle, triggerType, active } = req.body;

    let updated = null;
    if (getIsConnected()) {
      updated = await DndRule.findOneAndUpdate(
        { _id: id, userId },
        {
          $set: {
            ...(title !== undefined && { title: title.trim() }),
            ...(subtitle !== undefined && { subtitle: subtitle.trim() }),
            ...(triggerType !== undefined && { triggerType }),
            ...(active !== undefined && { active: Boolean(active) }),
          },
        },
        { new: true }
      );
    } else {
      const rule = devStore.rules.get(id);
      if (rule && rule.userId === userId) {
        if (title !== undefined) rule.title = title.trim();
        if (subtitle !== undefined) rule.subtitle = subtitle.trim();
        if (triggerType !== undefined) rule.triggerType = triggerType;
        if (active !== undefined) rule.active = Boolean(active);
        devStore.rules.set(id, rule);
        updated = rule;
      }
    }

    if (!updated) {
      return res.status(404).json({ success: false, message: 'Rule not found' });
    }

    return res.status(200).json({
      success: true,
      message: 'Rule updated successfully',
      rule: {
        id: updated._id,
        title: updated.title,
        subtitle: updated.subtitle,
        triggerType: updated.triggerType,
        active: Boolean(updated.active),
      },
    });
  } catch (error) {
    console.error('[updateRuleHandler] Error:', error);
    return res.status(500).json({ success: false, message: 'Failed to update rule' });
  }
};

/**
 * DELETE /api/dnd/rules/:id
 */
const deleteRuleHandler = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user._id.toString();

    if (getIsConnected()) {
      await DndRule.findOneAndDelete({ _id: id, userId });
    } else {
      const rule = devStore.rules.get(id);
      if (rule && rule.userId === userId) {
        devStore.rules.delete(id);
      }
    }

    return res.status(200).json({ success: true, message: 'Rule deleted successfully' });
  } catch (error) {
    console.error('[deleteRuleHandler] Error:', error);
    return res.status(500).json({ success: false, message: 'Failed to delete rule' });
  }
};

/**
 * GET /api/dnd/insights
 */
const getInsightsHandler = async (req, res) => {
  try {
    const range = req.query.range || '0';

    // Return insights customized per selected range
    if (range === '1') {
      // Last week
      return res.status(200).json({
        success: true,
        range: 'last_week',
        stats: {
          silencedTonight: 14,
          letThroughTonight: 1,
          weeklyTotalSilenced: 96,
          avgQuietHours: '7h 48m',
          focusHours: 36,
          blockedTotal: 96,
        },
        letThroughContacts: [
          { initial: 'D', name: 'Dr. Rao', detail: 'Call at 10:45 PM, repeat caller' },
          { initial: 'S', name: 'Sarah Work', detail: 'Message at 11:30 PM, VIP contact' },
        ],
        breakdown: [
          { day: 'Mon', silenced: 16, allowed: 1, hours: 5.2 },
          { day: 'Tue', silenced: 13, allowed: 0, hours: 4.8 },
          { day: 'Wed', silenced: 18, allowed: 2, hours: 6.0 },
          { day: 'Thu', silenced: 14, allowed: 1, hours: 5.5 },
          { day: 'Fri', silenced: 10, allowed: 3, hours: 4.0 },
          { day: 'Sat', silenced: 12, allowed: 1, hours: 5.0 },
          { day: 'Sun', silenced: 13, allowed: 0, hours: 5.5 },
        ],
        profiles: [
          { name: 'Sleep', hours: 22, fraction: 1.0 },
          { name: 'Work', hours: 10, fraction: 0.45 },
          { name: 'Meeting', hours: 3, fraction: 0.14 },
          { name: 'Driving', hours: 1, fraction: 0.05 },
        ],
      });
    }

    if (range === '2') {
      // Month
      return res.status(200).json({
        success: true,
        range: 'month',
        stats: {
          silencedTonight: 12,
          letThroughTonight: 2,
          weeklyTotalSilenced: 348,
          avgQuietHours: '7h 26m',
          focusHours: 138,
          blockedTotal: 348,
        },
        letThroughContacts: [
          { initial: 'M', name: 'Mom', detail: 'Call at 11:12 PM, VIP contact' },
          { initial: 'D', name: 'Dr. Rao', detail: 'Call at 11:19 PM, repeat caller' },
          { initial: 'E', name: 'Emergency Hotline', detail: 'Call at 2:10 AM, bypassed' },
        ],
        breakdown: [
          { day: 'Week 1', silenced: 84, allowed: 6, hours: 31.0 },
          { day: 'Week 2', silenced: 96, allowed: 8, hours: 36.0 },
          { day: 'Week 3', silenced: 78, allowed: 4, hours: 32.5 },
          { day: 'Week 4', silenced: 90, allowed: 7, hours: 38.5 },
        ],
        profiles: [
          { name: 'Sleep', hours: 82, fraction: 1.0 },
          { name: 'Work', hours: 38, fraction: 0.46 },
          { name: 'Meeting', hours: 12, fraction: 0.15 },
          { name: 'Driving', hours: 6, fraction: 0.07 },
        ],
      });
    }

    // Default: This week (range 0)
    return res.status(200).json({
      success: true,
      range: 'this_week',
      stats: {
        silencedTonight: 12,
        letThroughTonight: 2,
        weeklyTotalSilenced: 84,
        avgQuietHours: '7h 14m',
        focusHours: 31,
        blockedTotal: 84,
      },
      letThroughContacts: [
        { initial: 'M', name: 'Mom', detail: 'Call at 11:12 PM, VIP contact' },
        { initial: 'D', name: 'Dr. Rao', detail: 'Call at 11:19 PM, repeat caller' },
      ],
      breakdown: [
        { day: 'Mon', silenced: 14, allowed: 1, hours: 4.5 },
        { day: 'Tue', silenced: 11, allowed: 3, hours: 5.0 },
        { day: 'Wed', silenced: 15, allowed: 0, hours: 3.8 },
        { day: 'Thu', silenced: 12, allowed: 2, hours: 5.6 },
        { day: 'Fri', silenced: 9, allowed: 4, hours: 4.4 },
        { day: 'Sat', silenced: 16, allowed: 1, hours: 4.2 },
        { day: 'Sun', silenced: 12, allowed: 2, hours: 3.5 },
      ],
      profiles: [
        { name: 'Sleep', hours: 18, fraction: 1.0 },
        { name: 'Work', hours: 9, fraction: 0.5 },
        { name: 'Meeting', hours: 3, fraction: 3 / 18 },
        { name: 'Driving', hours: 1, fraction: 1 / 18 },
      ],
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'Failed to fetch insights' });
  }
};

module.exports = {
  getProfilesHandler,
  createProfileHandler,
  updateProfileHandler,
  deleteProfileHandler,
  toggleMasterDndHandler,
  getRulesHandler,
  createRuleHandler,
  updateRuleHandler,
  deleteRuleHandler,
  getInsightsHandler,
};
