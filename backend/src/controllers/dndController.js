const mongoose = require('mongoose');
const User = require('../models/User');
const DndProfile = require('../models/DndProfile');
const DndRule = require('../models/DndRule');
const DndActivityLog = require('../models/DndActivityLog');
const { getIsConnected } = require('../config/db');
const devStore = require('../utils/devStore');
const {
  serializeUser,
  serializeProfile,
  serializeRule,
  serializeActivityLog,
} = require('../utils/serializers');

const isValidObjectId = (val) => Boolean(val && mongoose.Types.ObjectId.isValid(val));

const DAY_NAMES = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

const dayKey = (d) => {
  const dt = new Date(d);
  return `${dt.getFullYear()}-${String(dt.getMonth() + 1).padStart(2, '0')}-${String(
    dt.getDate()
  ).padStart(2, '0')}`;
};

const formatAvgHours = (avgMinutes) => {
  if (!avgMinutes || avgMinutes <= 0) return '0h 0m';
  const hrs = Math.floor(avgMinutes / 60);
  const mins = Math.round(avgMinutes % 60);
  return `${hrs}h ${mins}m`;
};

async function markDefaultsSeeded(userId) {
  if (getIsConnected() && isValidObjectId(userId)) {
    try {
      await User.findByIdAndUpdate(userId, { $set: { hasSeededDefaults: true } });
    } catch (_) {}
  }
  const devUser = devStore.users.get(userId);
  if (devUser) {
    devUser.hasSeededDefaults = true;
    devStore.users.set(userId, devUser);
  }
}

async function fetchUserProfiles(userId, reqUser) {
  let profiles = [];
  const alreadySeeded = Boolean(reqUser && reqUser.hasSeededDefaults);

  if (getIsConnected() && isValidObjectId(userId)) {
    try {
      profiles = await DndProfile.find({ userId }).sort({ createdAt: 1 });
      if (profiles.length === 0 && !alreadySeeded) {
        const defs = devStore.getDefaultProfiles(userId);
        for (const p of defs) {
          const { _id, ...rest } = p;
          try {
            await DndProfile.create(rest);
          } catch (_) {}
        }
        await markDefaultsSeeded(userId);
        profiles = await DndProfile.find({ userId }).sort({ createdAt: 1 });
      }
      return profiles;
    } catch (dbErr) {
      console.warn('[fetchUserProfiles] MongoDB query failed, falling back:', dbErr.message);
    }
  }

  for (const p of devStore.profiles.values()) {
    if (String(p.userId) === userId) profiles.push(p);
  }
  if (profiles.length === 0 && !alreadySeeded) {
    const defs = devStore.getDefaultProfiles(userId);
    for (const p of defs) {
      devStore.profiles.set(p._id, p);
      profiles.push(p);
    }
    await markDefaultsSeeded(userId);
  }
  return profiles;
}

async function fetchUserRules(userId, reqUser) {
  let rules = [];
  const alreadySeeded = Boolean(reqUser && reqUser.hasSeededDefaults);

  if (getIsConnected() && isValidObjectId(userId)) {
    try {
      rules = await DndRule.find({ userId }).sort({ createdAt: 1 });
      if (rules.length === 0 && !alreadySeeded) {
        const defs = devStore.getDefaultRules(userId);
        for (const r of defs) {
          const { _id, ...rest } = r;
          try {
            await DndRule.create(rest);
          } catch (_) {}
        }
        await markDefaultsSeeded(userId);
        rules = await DndRule.find({ userId }).sort({ createdAt: 1 });
      }
      return rules;
    } catch (dbErr) {
      console.warn('[fetchUserRules] MongoDB query failed, falling back:', dbErr.message);
    }
  }

  for (const r of devStore.rules.values()) {
    if (String(r.userId) === userId) rules.push(r);
  }
  if (rules.length === 0 && !alreadySeeded) {
    const defs = devStore.getDefaultRules(userId);
    for (const r of defs) {
      devStore.rules.set(r._id, r);
      rules.push(r);
    }
    await markDefaultsSeeded(userId);
  }
  return rules;
}

async function fetchUserLogs(userId) {
  if (getIsConnected() && isValidObjectId(userId)) {
    try {
      const logs = await DndActivityLog.find({ userId }).sort({ date: -1, createdAt: -1 });
      return logs;
    } catch (dbErr) {
      console.warn('[fetchUserLogs] MongoDB query warning:', dbErr.message);
    }
  }

  const list = [];
  for (const l of devStore.activityLogs.values()) {
    if (String(l.userId) === userId) list.push(l);
  }
  return list.sort((a, b) => new Date(b.date) - new Date(a.date));
}

async function persistActivityLog(userId, payload) {
  let saved = null;
  if (getIsConnected() && isValidObjectId(userId)) {
    try {
      saved = await DndActivityLog.create({ userId, ...payload });
    } catch (dbErr) {
      console.warn('[persistActivityLog] MongoDB create warning:', dbErr.message);
    }
  }
  if (!saved) {
    const id = devStore.genId();
    saved = {
      _id: id,
      userId,
      ...payload,
      createdAt: new Date().toISOString(),
    };
    devStore.activityLogs.set(id, saved);
  } else {
    devStore.activityLogs.set(saved._id.toString(), saved);
  }
  return saved;
}

/**
 * GET /api/dnd/profiles
 */
const getProfilesHandler = async (req, res) => {
  try {
    const userId = (req.user._id || req.user.id).toString();
    const profiles = await fetchUserProfiles(userId, req.user);
    return res.status(200).json({
      success: true,
      count: profiles.length,
      profiles: profiles.map(serializeProfile),
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
    const userId = (req.user._id || req.user.id).toString();
    const {
      name,
      icon = 'moon',
      meta = 'Custom profile',
      mode = 'priorityOnly',
      autoReply = true,
      hideNotifications = false,
      callWhitelist = 'Starred',
      messageWhitelist = 'VIP only',
      repeatCallersWindowMin = 15,
      autoReplyMessage = 'I am currently in Do Not Disturb mode and will respond shortly.',
      customTag = '',
    } = req.body;

    if (!name || !name.trim()) {
      return res.status(400).json({ success: false, message: 'Profile name is required' });
    }

    let newProfile = null;
    if (getIsConnected() && isValidObjectId(userId)) {
      try {
        newProfile = await DndProfile.create({
          userId,
          name: name.trim(),
          icon,
          meta,
          active: false,
          mode,
          autoReply,
          hideNotifications,
          callWhitelist,
          messageWhitelist,
          repeatCallersWindowMin: Number(repeatCallersWindowMin) || 0,
          autoReplyMessage,
          customTag,
        });
      } catch (dbErr) {
        console.warn('[createProfileHandler] MongoDB create warning:', dbErr.message);
      }
    }

    if (!newProfile) {
      const id = devStore.genId();
      newProfile = {
        _id: id,
        userId,
        name: name.trim(),
        icon,
        meta,
        active: false,
        mode,
        autoReply,
        hideNotifications,
        callWhitelist,
        messageWhitelist,
        repeatCallersWindowMin: Number(repeatCallersWindowMin) || 0,
        autoReplyMessage,
        customTag,
      };
      devStore.profiles.set(id, newProfile);
    } else {
      devStore.profiles.set(newProfile._id.toString(), newProfile);
    }

    return res.status(201).json({
      success: true,
      message: 'Profile created successfully',
      profile: serializeProfile(newProfile),
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
    const userId = (req.user._id || req.user.id).toString();
    const {
      name,
      icon,
      meta,
      active,
      mode,
      autoReply,
      hideNotifications,
      callWhitelist,
      messageWhitelist,
      repeatCallersWindowMin,
      autoReplyMessage,
      customTag,
    } = req.body;

    let updated = null;

    if (getIsConnected() && isValidObjectId(id) && isValidObjectId(userId)) {
      try {
        if (active === true) {
          await DndProfile.updateMany({ userId }, { active: false });
        }

        updated = await DndProfile.findOneAndUpdate(
          { _id: id, userId },
          {
            $set: {
              ...(name !== undefined && { name: name.trim() }),
              ...(icon !== undefined && { icon }),
              ...(meta !== undefined && { meta }),
              ...(active !== undefined && { active }),
              ...(mode !== undefined && { mode }),
              ...(autoReply !== undefined && { autoReply }),
              ...(hideNotifications !== undefined && { hideNotifications }),
              ...(callWhitelist !== undefined && { callWhitelist }),
              ...(messageWhitelist !== undefined && { messageWhitelist }),
              ...(repeatCallersWindowMin !== undefined && {
                repeatCallersWindowMin: Number(repeatCallersWindowMin) || 0,
              }),
              ...(autoReplyMessage !== undefined && { autoReplyMessage }),
              ...(customTag !== undefined && { customTag }),
            },
          },
          { new: true }
        );
      } catch (dbErr) {
        console.warn('[updateProfileHandler] MongoDB update warning:', dbErr.message);
      }
    }

    const profile = devStore.profiles.get(id);
    if (profile && String(profile.userId) === userId) {
      if (active === true) {
        for (const p of devStore.profiles.values()) {
          if (String(p.userId) === userId) p.active = false;
        }
      }
      if (name !== undefined) profile.name = name.trim();
      if (icon !== undefined) profile.icon = icon;
      if (meta !== undefined) profile.meta = meta;
      if (active !== undefined) profile.active = active;
      if (mode !== undefined) profile.mode = mode;
      if (autoReply !== undefined) profile.autoReply = autoReply;
      if (hideNotifications !== undefined) profile.hideNotifications = hideNotifications;
      if (callWhitelist !== undefined) profile.callWhitelist = callWhitelist;
      if (messageWhitelist !== undefined) profile.messageWhitelist = messageWhitelist;
      if (repeatCallersWindowMin !== undefined) {
        profile.repeatCallersWindowMin = Number(repeatCallersWindowMin) || 0;
      }
      if (autoReplyMessage !== undefined) profile.autoReplyMessage = autoReplyMessage;
      if (customTag !== undefined) profile.customTag = customTag;

      devStore.profiles.set(id, profile);
      if (!updated) updated = profile;
    }

    if (!updated) {
      return res.status(404).json({ success: false, message: 'Profile not found' });
    }

    return res.status(200).json({
      success: true,
      message: 'Profile updated',
      profile: serializeProfile(updated),
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
    const userId = (req.user._id || req.user.id).toString();

    if (getIsConnected() && isValidObjectId(id) && isValidObjectId(userId)) {
      try {
        await DndProfile.findOneAndDelete({ _id: id, userId });
      } catch (dbErr) {
        console.warn('[deleteProfileHandler] MongoDB delete warning:', dbErr.message);
      }
    }

    devStore.profiles.delete(id);
    await markDefaultsSeeded(userId);

    return res.status(200).json({ success: true, message: 'Profile deleted' });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'Failed to delete profile' });
  }
};

/**
 * POST /api/dnd/toggle
 * Toggle the Master DND power button state & automatically record session stability logs
 */
const toggleMasterDndHandler = async (req, res) => {
  try {
    const userId = (req.user._id || req.user.id).toString();
    const { enabled, durationMinutes, endTime, profileName } = req.body;

    let targetState = enabled;
    let savedUser = null;
    let recordedLog = null;

    const applyToggleToUser = async (userObj) => {
      if (targetState === undefined) targetState = !userObj.dndEnabled;
      const now = new Date();

      if (targetState === true) {
        userObj.dndEnabled = true;
        userObj.activeSessionStart = now;
        userObj.activeSessionPlannedMinutes = Number(durationMinutes) || userObj.activeSessionPlannedMinutes || 60;
        userObj.activeSessionEndTime = endTime
          ? new Date(endTime)
          : new Date(now.getTime() + userObj.activeSessionPlannedMinutes * 60000);
        if (profileName) {
          userObj.activeProfileName = String(profileName).trim();
        }
      } else {
        const startedAt = userObj.activeSessionStart ? new Date(userObj.activeSessionStart) : null;
        const plannedMin = Number(userObj.activeSessionPlannedMinutes) || 60;
        if (startedAt && !Number.isNaN(startedAt.getTime())) {
          const elapsedMin = Math.max(1, Math.round((now.getTime() - startedAt.getTime()) / 60000));
          const completedWithoutEarlyExit = elapsedMin >= Math.max(1, Math.round(plannedMin * 0.8));
          const logPayload = {
            date: now,
            profileName: profileName || userObj.activeProfileName || 'Do Not Disturb',
            durationMinutes: elapsedMin,
            plannedMinutes: plannedMin,
            appUsageMinutes: 0,
            completedWithoutEarlyExit,
            silencedCount: 0,
            letThroughCount: Array.isArray(userObj.emergencyContacts)
              ? userObj.emergencyContacts.length
              : 0,
            focusStabilityRating: completedWithoutEarlyExit ? 5 : 3,
            source: 'auto_toggle',
            notes: completedWithoutEarlyExit
              ? 'Completed quiet session as planned'
              : 'Ended quiet session early',
          };
          recordedLog = await persistActivityLog(userId, logPayload);
        }
        userObj.dndEnabled = false;
        userObj.activeSessionStart = null;
        userObj.activeSessionEndTime = null;
      }
    };

    if (getIsConnected() && isValidObjectId(userId)) {
      try {
        const user = await User.findById(userId);
        if (user) {
          await applyToggleToUser(user);
          savedUser = await user.save();
        }
      } catch (dbErr) {
        console.warn('[toggleMasterDndHandler] MongoDB toggle warning:', dbErr.message);
      }
    }

    const devUser = devStore.users.get(userId) || req.user;
    if (devUser && !savedUser) {
      await applyToggleToUser(devUser);
      devStore.users.set(userId, devUser);
      savedUser = devUser;
    } else if (devUser && savedUser) {
      devStore.users.set(userId, savedUser);
    }

    return res.status(200).json({
      success: true,
      dndEnabled: Boolean(targetState),
      message: targetState ? 'Master DND is now armed' : 'Master DND turned off',
      user: serializeUser(savedUser || req.user),
      sessionLog: recordedLog ? serializeActivityLog(recordedLog) : null,
    });
  } catch (error) {
    console.error('[toggleMasterDndHandler] Error:', error);
    return res.status(500).json({ success: false, message: 'Failed to toggle DND' });
  }
};

/**
 * GET /api/dnd/rules
 */
const getRulesHandler = async (req, res) => {
  try {
    const userId = (req.user._id || req.user.id).toString();
    const rules = await fetchUserRules(userId, req.user);
    return res.status(200).json({
      success: true,
      rules: rules.map(serializeRule),
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
    const userId = (req.user._id || req.user.id).toString();
    const {
      title,
      subtitle = '',
      triggerType = 'schedule',
      days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
      targetProfileName = '',
      customCondition = '',
      active = true,
    } = req.body;

    if (!title || !title.trim()) {
      return res.status(400).json({ success: false, message: 'Rule title is required' });
    }

    const cleanDays = Array.isArray(days) && days.length > 0
      ? days.map((d) => String(d).trim()).filter(Boolean)
      : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    let newRule = null;
    if (getIsConnected() && isValidObjectId(userId)) {
      try {
        newRule = await DndRule.create({
          userId,
          title: title.trim(),
          subtitle: subtitle.trim(),
          triggerType,
          days: cleanDays,
          targetProfileName: String(targetProfileName || '').trim(),
          customCondition: String(customCondition || '').trim(),
          active: Boolean(active),
        });
      } catch (dbErr) {
        console.warn('[createRuleHandler] MongoDB create warning:', dbErr.message);
      }
    }

    if (!newRule) {
      const id = devStore.genId();
      newRule = {
        _id: id,
        userId,
        title: title.trim(),
        subtitle: subtitle.trim(),
        triggerType,
        days: cleanDays,
        targetProfileName: String(targetProfileName || '').trim(),
        customCondition: String(customCondition || '').trim(),
        active: Boolean(active),
      };
      devStore.rules.set(id, newRule);
    } else {
      devStore.rules.set(newRule._id.toString(), newRule);
    }

    return res.status(201).json({
      success: true,
      message: 'Rule created successfully',
      rule: serializeRule(newRule),
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
    const userId = (req.user._id || req.user.id).toString();
    const { title, subtitle, triggerType, days, targetProfileName, customCondition, active } = req.body;

    let updated = null;
    if (getIsConnected() && isValidObjectId(id) && isValidObjectId(userId)) {
      try {
        updated = await DndRule.findOneAndUpdate(
          { _id: id, userId },
          {
            $set: {
              ...(title !== undefined && { title: title.trim() }),
              ...(subtitle !== undefined && { subtitle: subtitle.trim() }),
              ...(triggerType !== undefined && { triggerType }),
              ...(Array.isArray(days) && { days }),
              ...(targetProfileName !== undefined && { targetProfileName: String(targetProfileName).trim() }),
              ...(customCondition !== undefined && { customCondition: String(customCondition).trim() }),
              ...(active !== undefined && { active: Boolean(active) }),
            },
          },
          { new: true }
        );
      } catch (dbErr) {
        console.warn('[updateRuleHandler] MongoDB update warning:', dbErr.message);
      }
    }

    const rule = devStore.rules.get(id);
    if (rule && String(rule.userId) === userId) {
      if (title !== undefined) rule.title = title.trim();
      if (subtitle !== undefined) rule.subtitle = subtitle.trim();
      if (triggerType !== undefined) rule.triggerType = triggerType;
      if (Array.isArray(days)) rule.days = days;
      if (targetProfileName !== undefined) rule.targetProfileName = String(targetProfileName).trim();
      if (customCondition !== undefined) rule.customCondition = String(customCondition).trim();
      if (active !== undefined) rule.active = Boolean(active);
      devStore.rules.set(id, rule);
      if (!updated) updated = rule;
    }

    if (!updated) {
      return res.status(404).json({ success: false, message: 'Rule not found' });
    }

    return res.status(200).json({
      success: true,
      message: 'Rule updated successfully',
      rule: serializeRule(updated),
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
    const userId = (req.user._id || req.user.id).toString();

    if (getIsConnected() && isValidObjectId(id) && isValidObjectId(userId)) {
      try {
        await DndRule.findOneAndDelete({ _id: id, userId });
      } catch (dbErr) {
        console.warn('[deleteRuleHandler] MongoDB delete warning:', dbErr.message);
      }
    }

    devStore.rules.delete(id);
    await markDefaultsSeeded(userId);

    return res.status(200).json({ success: true, message: 'Rule deleted successfully' });
  } catch (error) {
    console.error('[deleteRuleHandler] Error:', error);
    return res.status(500).json({ success: false, message: 'Failed to delete rule' });
  }
};

/**
 * GET /api/dnd/logs
 */
const getLogsHandler = async (req, res) => {
  try {
    const userId = (req.user._id || req.user.id).toString();
    const logs = await fetchUserLogs(userId);
    return res.status(200).json({
      success: true,
      logs: logs.map(serializeActivityLog),
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'Failed to fetch activity logs' });
  }
};

/**
 * POST /api/dnd/logs
 * Manual session / distraction / stability check-in saved to MongoDB
 */
const createLogHandler = async (req, res) => {
  try {
    const userId = (req.user._id || req.user.id).toString();
    const {
      date,
      profileName = 'Do Not Disturb',
      durationMinutes = 30,
      plannedMinutes,
      appUsageMinutes = 0,
      completedWithoutEarlyExit = true,
      silencedCount = 0,
      letThroughCount = 0,
      focusStabilityRating = 4,
      notes = '',
    } = req.body;

    const cleanDuration = Math.max(0, Number(durationMinutes) || 0);
    const cleanPlanned = Math.max(1, Number(plannedMinutes) || cleanDuration || 30);
    const cleanRating = Math.min(5, Math.max(1, Number(focusStabilityRating) || 4));

    const saved = await persistActivityLog(userId, {
      date: date ? new Date(date) : new Date(),
      profileName: String(profileName || 'Do Not Disturb').trim(),
      durationMinutes: cleanDuration,
      plannedMinutes: cleanPlanned,
      appUsageMinutes: Math.max(0, Number(appUsageMinutes) || 0),
      completedWithoutEarlyExit: Boolean(completedWithoutEarlyExit),
      silencedCount: Math.max(0, Number(silencedCount) || 0),
      letThroughCount: Math.max(0, Number(letThroughCount) || 0),
      focusStabilityRating: cleanRating,
      source: 'manual_log',
      notes: String(notes || '').trim(),
    });

    return res.status(201).json({
      success: true,
      message: 'Activity log saved to database',
      log: serializeActivityLog(saved),
    });
  } catch (error) {
    console.error('[createLogHandler] Error:', error);
    return res.status(500).json({ success: false, message: 'Failed to save activity log' });
  }
};

/**
 * DELETE /api/dnd/logs/:id
 */
const deleteLogHandler = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = (req.user._id || req.user.id).toString();

    if (getIsConnected() && isValidObjectId(id) && isValidObjectId(userId)) {
      try {
        await DndActivityLog.findOneAndDelete({ _id: id, userId });
      } catch (dbErr) {
        console.warn('[deleteLogHandler] MongoDB delete warning:', dbErr.message);
      }
    }
    devStore.activityLogs.delete(id);
    return res.status(200).json({ success: true, message: 'Activity log deleted' });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'Failed to delete log' });
  }
};

/**
 * POST /api/dnd/usage-ping
 * Tracks incremental app usage minutes for stability over time
 */
const usagePingHandler = async (req, res) => {
  try {
    const userId = (req.user._id || req.user.id).toString();
    const minutes = Math.min(30, Math.max(1, Number(req.body.minutes) || 1));

    let updatedTotal = Number(req.user.totalAppUsageMinutes || 0) + minutes;

    if (getIsConnected() && isValidObjectId(userId)) {
      try {
        const user = await User.findByIdAndUpdate(
          userId,
          { $inc: { totalAppUsageMinutes: minutes } },
          { new: true }
        );
        if (user) updatedTotal = user.totalAppUsageMinutes;

        const todayStart = new Date();
        todayStart.setHours(0, 0, 0, 0);
        const todayEnd = new Date();
        todayEnd.setHours(23, 59, 59, 999);

        const existingUsage = await DndActivityLog.findOne({
          userId,
          source: 'app_usage',
          date: { $gte: todayStart, $lte: todayEnd },
        });
        if (existingUsage) {
          existingUsage.appUsageMinutes += minutes;
          await existingUsage.save();
        } else {
          await DndActivityLog.create({
            userId,
            date: new Date(),
            profileName: req.user.activeProfileName || 'App Usage',
            durationMinutes: 0,
            plannedMinutes: 0,
            appUsageMinutes: minutes,
            completedWithoutEarlyExit: true,
            silencedCount: 0,
            letThroughCount: 0,
            focusStabilityRating: 4,
            source: 'app_usage',
            notes: 'Active app usage time',
          });
        }
      } catch (dbErr) {
        console.warn('[usagePingHandler] MongoDB warning:', dbErr.message);
      }
    } else {
      const devUser = devStore.users.get(userId) || req.user;
      if (devUser) {
        devUser.totalAppUsageMinutes = Number(devUser.totalAppUsageMinutes || 0) + minutes;
        updatedTotal = devUser.totalAppUsageMinutes;
        devStore.users.set(userId, devUser);
      }
      const todayStr = dayKey(new Date());
      let todayLog = null;
      for (const l of devStore.activityLogs.values()) {
        if (String(l.userId) === userId && l.source === 'app_usage' && dayKey(l.date) === todayStr) {
          todayLog = l;
          break;
        }
      }
      if (todayLog) {
        todayLog.appUsageMinutes = Number(todayLog.appUsageMinutes || 0) + minutes;
        devStore.activityLogs.set(todayLog._id, todayLog);
      } else {
        await persistActivityLog(userId, {
          date: new Date(),
          profileName: 'App Usage',
          durationMinutes: 0,
          plannedMinutes: 0,
          appUsageMinutes: minutes,
          completedWithoutEarlyExit: true,
          silencedCount: 0,
          letThroughCount: 0,
          focusStabilityRating: 4,
          source: 'app_usage',
          notes: 'Active app usage time',
        });
      }
    }

    return res.status(200).json({
      success: true,
      totalAppUsageMinutes: updatedTotal,
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'Failed to record usage ping' });
  }
};

/**
 * GET /api/dnd/insights?range=0|1|2
 * Dynamically computed from DndActivityLog, DndProfile, and User.emergencyContacts
 */
const getInsightsHandler = async (req, res) => {
  try {
    const userId = (req.user._id || req.user.id).toString();
    const range = String(req.query.range || '0');

    const [allLogs, profiles] = await Promise.all([
      fetchUserLogs(userId),
      fetchUserProfiles(userId, req.user),
    ]);

    const now = new Date();
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const todayEnd = new Date(todayStart.getTime() + 86400000 - 1);

    let startDate;
    let endDate;
    let rangeName = 'this_week';

    if (range === '1') {
      rangeName = 'last_week';
      endDate = new Date(todayStart.getTime() - 7 * 86400000 + 86400000 - 1);
      startDate = new Date(todayStart.getTime() - 13 * 86400000);
    } else if (range === '2') {
      rangeName = 'month';
      endDate = todayEnd;
      startDate = new Date(todayStart.getTime() - 27 * 86400000);
    } else {
      rangeName = 'this_week';
      endDate = todayEnd;
      startDate = new Date(todayStart.getTime() - 6 * 86400000);
    }

    const inRange = allLogs.filter((l) => {
      const dt = new Date(l.date || l.createdAt);
      return dt >= startDate && dt <= endDate;
    });

    const todayLogs = allLogs.filter((l) => {
      const dt = new Date(l.date || l.createdAt);
      return dt >= todayStart && dt <= todayEnd;
    });

    const silencedTonight = todayLogs.reduce((sum, l) => sum + Number(l.silencedCount || 0), 0);
    const contacts = Array.isArray(req.user.emergencyContacts) ? req.user.emergencyContacts : [];
    const letThroughTonight =
      todayLogs.reduce((sum, l) => sum + Number(l.letThroughCount || 0), 0) || contacts.length;

    const totalSilenced = inRange.reduce((sum, l) => sum + Number(l.silencedCount || 0), 0);
    const totalMinutes = inRange.reduce((sum, l) => sum + Number(l.durationMinutes || 0), 0);
    const focusHours = Math.round((totalMinutes / 60) * 10) / 10;

    // Build daily or weekly breakdown
    const breakdown = [];
    if (range === '2') {
      for (let w = 0; w < 4; w++) {
        const wStart = new Date(startDate.getTime() + w * 7 * 86400000);
        const wEnd = new Date(wStart.getTime() + 7 * 86400000 - 1);
        const bucket = inRange.filter((l) => {
          const dt = new Date(l.date || l.createdAt);
          return dt >= wStart && dt <= wEnd;
        });
        const mins = bucket.reduce((s, l) => s + Number(l.durationMinutes || 0), 0);
        breakdown.push({
          day: `Week ${w + 1}`,
          silenced: bucket.reduce((s, l) => s + Number(l.silencedCount || 0), 0),
          allowed: bucket.reduce((s, l) => s + Number(l.letThroughCount || 0), 0),
          hours: Math.round((mins / 60) * 10) / 10,
        });
      }
    } else {
      for (let d = 0; d < 7; d++) {
        const dayDate = new Date(startDate.getTime() + d * 86400000);
        const key = dayKey(dayDate);
        const bucket = inRange.filter((l) => dayKey(l.date || l.createdAt) === key);
        const mins = bucket.reduce((s, l) => s + Number(l.durationMinutes || 0), 0);
        breakdown.push({
          day: DAY_NAMES[dayDate.getDay()],
          silenced: bucket.reduce((s, l) => s + Number(l.silencedCount || 0), 0),
          allowed: bucket.reduce((s, l) => s + Number(l.letThroughCount || 0), 0),
          hours: Math.round((mins / 60) * 10) / 10,
        });
      }
    }

    const activeDayCount = new Set(
      inRange.filter((l) => Number(l.durationMinutes || 0) > 0).map((l) => dayKey(l.date || l.createdAt))
    ).size;
    const avgQuietMinutes = activeDayCount > 0 ? totalMinutes / activeDayCount : 0;

    // Profile breakdown across user's real profiles + logs
    const profileHoursMap = new Map();
    for (const p of profiles) {
      profileHoursMap.set(p.name, 0);
    }
    for (const l of inRange) {
      if (Number(l.durationMinutes || 0) > 0) {
        const pname = l.profileName || 'Do Not Disturb';
        profileHoursMap.set(pname, (profileHoursMap.get(pname) || 0) + Number(l.durationMinutes || 0));
      }
    }

    const rawProfiles = [...profileHoursMap.entries()]
      .map(([name, mins]) => ({
        name,
        hours: Math.round((mins / 60) * 10) / 10,
        minutes: mins,
      }))
      .sort((a, b) => b.minutes - a.minutes);

    const maxProfMins = rawProfiles.reduce((m, p) => (p.minutes > m ? p.minutes : m), 0);
    const profileStats = rawProfiles.map((p) => ({
      name: p.name,
      hours: Math.round(p.hours),
      exactHours: p.hours,
      fraction: maxProfMins > 0 ? p.minutes / maxProfMins : 0,
    }));

    const letThroughContacts = contacts.map((c) => ({
      id: (c._id || c.id || '').toString(),
      initial: c.name ? c.name[0].toUpperCase() : 'U',
      name: c.name || 'Contact',
      detail: c.phone ? `${c.relationship || 'VIP Contact'} • ${c.phone}` : (c.relationship || 'VIP Contact'),
      phone: c.phone || '',
    }));

    return res.status(200).json({
      success: true,
      range: rangeName,
      hasData: inRange.some((l) => Number(l.durationMinutes || 0) > 0 || Number(l.silencedCount || 0) > 0),
      stats: {
        silencedTonight,
        letThroughTonight,
        weeklyTotalSilenced: totalSilenced,
        avgQuietHours: formatAvgHours(avgQuietMinutes),
        focusHours: Math.round(focusHours),
        exactFocusHours: focusHours,
        blockedTotal: totalSilenced,
      },
      letThroughContacts,
      breakdown,
      profiles: profileStats,
    });
  } catch (error) {
    console.error('[getInsightsHandler] Error:', error);
    return res.status(500).json({ success: false, message: 'Failed to fetch insights' });
  }
};

/**
 * Compute stability metrics for an arbitrary set of logs & period length
 */
function computeStabilityMetrics(logs, periodDays) {
  const sessionLogs = logs.filter((l) => l.source !== 'app_usage' && Number(l.durationMinutes || 0) > 0);
  const allUsageMinutes = logs.reduce((s, l) => s + Number(l.appUsageMinutes || 0), 0);
  const totalQuietMinutes = sessionLogs.reduce((s, l) => s + Number(l.durationMinutes || 0), 0);
  const totalSilenced = sessionLogs.reduce((s, l) => s + Number(l.silencedCount || 0), 0);
  const totalLetThrough = sessionLogs.reduce((s, l) => s + Number(l.letThroughCount || 0), 0);

  if (sessionLogs.length === 0 && allUsageMinutes === 0) {
    return {
      hasData: false,
      overallStabilityScore: 0,
      adherenceScore: 0,
      consistencyScore: 0,
      shieldScore: 0,
      focusRatingScore: 0,
      totalSessions: 0,
      completedSessions: 0,
      earlyExitSessions: 0,
      totalQuietMinutes: 0,
      totalAppUsageMinutes: 0,
      avgSessionMinutes: 0,
      activeDaysCount: 0,
      totalSilenced: 0,
      totalLetThrough: 0,
    };
  }

  const completedSessions = sessionLogs.filter((l) => l.completedWithoutEarlyExit !== false).length;
  const earlyExitSessions = sessionLogs.length - completedSessions;

  // 1. Adherence Score (0-100): completed sessions vs planned duration
  let adherenceScore = 0;
  if (sessionLogs.length > 0) {
    const ratioSum = sessionLogs.reduce((sum, l) => {
      const planned = Number(l.plannedMinutes) || Number(l.durationMinutes) || 30;
      const actual = Number(l.durationMinutes) || 0;
      const ratio = Math.min(1, actual / Math.max(1, planned));
      const bonus = l.completedWithoutEarlyExit !== false ? 1 : 0.75;
      return sum + ratio * bonus;
    }, 0);
    adherenceScore = Math.round((ratioSum / sessionLogs.length) * 100);
  } else if (allUsageMinutes > 0) {
    adherenceScore = 50;
  }

  // 2. Consistency Score (0-100): active days within window
  const activeDaysSet = new Set(logs.map((l) => dayKey(l.date || l.createdAt)));
  const activeDaysCount = activeDaysSet.size;
  const effectiveWindow = Math.max(1, Math.min(periodDays, 30));
  const consistencyScore = Math.min(100, Math.round((activeDaysCount / effectiveWindow) * 100));

  // 3. Shield Score (0-100): ratio of silenced interruptions vs total interruptions
  const totalInterruptions = totalSilenced + totalLetThrough;
  const shieldScore =
    totalInterruptions > 0
      ? Math.round((totalSilenced / totalInterruptions) * 100)
      : sessionLogs.length > 0
      ? 85
      : 0;

  // 4. Focus Rating Score (0-100): average user-reported stability rating (1..5 -> 20..100)
  let focusRatingScore = 0;
  if (sessionLogs.length > 0) {
    const avgRating =
      sessionLogs.reduce((s, l) => s + Number(l.focusStabilityRating || 4), 0) / sessionLogs.length;
    focusRatingScore = Math.round((avgRating / 5) * 100);
  } else if (allUsageMinutes > 0) {
    focusRatingScore = 70;
  }

  const overallStabilityScore = Math.round(
    adherenceScore * 0.35 +
      consistencyScore * 0.25 +
      shieldScore * 0.15 +
      focusRatingScore * 0.25
  );

  return {
    hasData: true,
    overallStabilityScore,
    adherenceScore,
    consistencyScore,
    shieldScore,
    focusRatingScore,
    totalSessions: sessionLogs.length,
    completedSessions,
    earlyExitSessions,
    totalQuietMinutes,
    totalAppUsageMinutes: allUsageMinutes,
    avgSessionMinutes: sessionLogs.length > 0 ? Math.round(totalQuietMinutes / sessionLogs.length) : 0,
    activeDaysCount,
    totalSilenced,
    totalLetThrough,
  };
}

function computeStreaks(allLogs) {
  const activeDates = [...new Set(allLogs.map((l) => dayKey(l.date || l.createdAt)))].sort();
  if (activeDates.length === 0) return { currentStreakDays: 0, longestStreakDays: 0 };

  let longest = 1;
  let running = 1;
  for (let i = 1; i < activeDates.length; i++) {
    const prev = new Date(`${activeDates[i - 1]}T00:00:00`);
    const curr = new Date(`${activeDates[i]}T00:00:00`);
    const diffDays = Math.round((curr - prev) / 86400000);
    if (diffDays === 1) {
      running += 1;
      if (running > longest) longest = running;
    } else if (diffDays > 1) {
      running = 1;
    }
  }

  const today = dayKey(new Date());
  const yesterday = dayKey(new Date(Date.now() - 86400000));
  const lastDate = activeDates[activeDates.length - 1];
  let current = 0;
  if (lastDate === today || lastDate === yesterday) {
    current = 1;
    for (let i = activeDates.length - 2; i >= 0; i--) {
      const nextDt = new Date(`${activeDates[i + 1]}T00:00:00`);
      const prevDt = new Date(`${activeDates[i]}T00:00:00`);
      if (Math.round((nextDt - prevDt) / 86400000) === 1) {
        current += 1;
      } else {
        break;
      }
    }
  }

  return { currentStreakDays: current, longestStreakDays: longest };
}

/**
 * GET /api/dnd/stability-report?range=0|1|2|3
 * Comprehensive Data Analysis & Overall Stability Report over time user uses the app
 */
const getStabilityReportHandler = async (req, res) => {
  try {
    const userId = (req.user._id || req.user.id).toString();
    const range = String(req.query.range || '0');

    const [allLogs, profiles, rules] = await Promise.all([
      fetchUserLogs(userId),
      fetchUserProfiles(userId, req.user),
      fetchUserRules(userId, req.user),
    ]);

    const now = new Date();
    const todayEnd = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999);
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    let periodDays = 7;
    let rangeKey = '7d';
    if (range === '1') {
      periodDays = 30;
      rangeKey = '30d';
    } else if (range === '2') {
      periodDays = 90;
      rangeKey = '90d';
    } else if (range === '3') {
      rangeKey = 'all';
      const oldest = allLogs.length > 0 ? new Date(allLogs[allLogs.length - 1].date) : todayStart;
      periodDays = Math.max(7, Math.ceil((todayEnd - oldest) / 86400000));
    }

    const startDate = new Date(todayStart.getTime() - (periodDays - 1) * 86400000);
    const prevStartDate = new Date(startDate.getTime() - periodDays * 86400000);
    const prevEndDate = new Date(startDate.getTime() - 1);

    const periodLogs = allLogs.filter((l) => {
      const dt = new Date(l.date || l.createdAt);
      return dt >= startDate && dt <= todayEnd;
    });
    const prevLogs = allLogs.filter((l) => {
      const dt = new Date(l.date || l.createdAt);
      return dt >= prevStartDate && dt <= prevEndDate;
    });

    const currentMetrics = computeStabilityMetrics(periodLogs, periodDays);
    const prevMetrics = computeStabilityMetrics(prevLogs, periodDays);
    const streaks = computeStreaks(allLogs);

    const stabilityDelta =
      currentMetrics.hasData && prevMetrics.hasData
        ? currentMetrics.overallStabilityScore - prevMetrics.overallStabilityScore
        : 0;

    const score = currentMetrics.overallStabilityScore;
    const stabilityGrade = !currentMetrics.hasData
      ? 'No Data'
      : score >= 85
      ? 'Optimal'
      : score >= 70
      ? 'Strong'
      : score >= 50
      ? 'Steady'
      : 'Building';

    // Build time-series trend buckets
    const trend = [];
    const bucketCount = range === '0' ? 7 : range === '1' ? 6 : range === '2' ? 6 : 6;
    const bucketSpanDays = Math.max(1, Math.ceil(periodDays / bucketCount));

    for (let i = 0; i < bucketCount; i++) {
      const bStart = new Date(startDate.getTime() + i * bucketSpanDays * 86400000);
      const bEnd =
        i === bucketCount - 1
          ? todayEnd
          : new Date(bStart.getTime() + bucketSpanDays * 86400000 - 1);
      const bLogs = periodLogs.filter((l) => {
        const dt = new Date(l.date || l.createdAt);
        return dt >= bStart && dt <= bEnd;
      });
      const bMetrics = computeStabilityMetrics(bLogs, bucketSpanDays);
      const label =
        bucketSpanDays === 1
          ? DAY_NAMES[bStart.getDay()]
          : `${bStart.getMonth() + 1}/${bStart.getDate()}`;

      trend.push({
        label,
        stabilityScore: bMetrics.overallStabilityScore,
        quietHours: Math.round((bMetrics.totalQuietMinutes / 60) * 10) / 10,
        appUsageMinutes: bMetrics.totalAppUsageMinutes,
        silenced: bMetrics.totalSilenced,
        allowed: bMetrics.totalLetThrough,
        adherenceRate: bMetrics.adherenceScore,
        sessions: bMetrics.totalSessions,
      });
    }

    // Per-profile stability analysis
    const sessionLogs = periodLogs.filter((l) => l.source !== 'app_usage' && Number(l.durationMinutes || 0) > 0);
    const byProfile = new Map();
    for (const l of sessionLogs) {
      const pname = l.profileName || 'Do Not Disturb';
      if (!byProfile.has(pname)) byProfile.set(pname, []);
      byProfile.get(pname).push(l);
    }

    const profileStability = [...byProfile.entries()]
      .map(([name, pLogs]) => {
        const m = computeStabilityMetrics(pLogs, periodDays);
        return {
          name,
          sessions: m.totalSessions,
          totalHours: Math.round((m.totalQuietMinutes / 60) * 10) / 10,
          avgStabilityScore: m.overallStabilityScore,
          adherenceRate: m.adherenceScore,
        };
      })
      .sort((a, b) => b.totalHours - a.totalHours);

    // Dynamic data-driven recommendations
    const recommendations = [];
    if (!currentMetrics.hasData) {
      recommendations.push({
        title: 'Start your first quiet session',
        detail:
          'Turn on Master DND from Home or log a focus session here to begin tracking your stability trend.',
        tone: 'info',
      });
    } else {
      if (currentMetrics.adherenceScore < 70 && currentMetrics.earlyExitSessions > 0) {
        recommendations.push({
          title: 'Reduce early DND exits',
          detail: `${currentMetrics.earlyExitSessions} of ${currentMetrics.totalSessions} sessions ended early. Try shorter custom durations (e.g. 25–45 min) for higher completion stability.`,
          tone: 'warning',
        });
      } else if (currentMetrics.adherenceScore >= 85) {
        recommendations.push({
          title: 'High session adherence',
          detail: `You completed ${currentMetrics.completedSessions} of ${currentMetrics.totalSessions} sessions without breaking focus early (${currentMetrics.adherenceScore}% adherence).`,
          tone: 'positive',
        });
      }

      if (profileStability.length > 0) {
        const best = [...profileStability].sort((a, b) => b.avgStabilityScore - a.avgStabilityScore)[0];
        recommendations.push({
          title: `Strongest profile: ${best.name}`,
          detail: `${best.name} holds ${best.avgStabilityScore}% stability across ${best.sessions} session${best.sessions === 1 ? '' : 's'} (${best.totalHours} h).`,
          tone: 'positive',
        });
      }

      if (streaks.currentStreakDays >= 3) {
        recommendations.push({
          title: `${streaks.currentStreakDays}-day stability streak`,
          detail: 'Consistent daily quiet blocks reinforce long-term focus stability.',
          tone: 'positive',
        });
      } else {
        recommendations.push({
          title: 'Build daily consistency',
          detail: `Active on ${currentMetrics.activeDaysCount} day${currentMetrics.activeDaysCount === 1 ? '' : 's'} in this period. Activate an automated schedule rule to build a multi-day streak.`,
          tone: 'info',
        });
      }
    }

    const totalAppUsageMinutesAllTime = Math.max(
      Number(req.user.totalAppUsageMinutes || 0),
      allLogs.reduce((s, l) => s + Number(l.appUsageMinutes || 0), 0)
    );

    return res.status(200).json({
      success: true,
      range: rangeKey,
      hasData: currentMetrics.hasData,
      overallStabilityScore: currentMetrics.overallStabilityScore,
      stabilityGrade,
      stabilityDelta,
      pillars: {
        adherenceScore: currentMetrics.adherenceScore,
        consistencyScore: currentMetrics.consistencyScore,
        shieldScore: currentMetrics.shieldScore,
        focusRatingScore: currentMetrics.focusRatingScore,
      },
      summary: {
        totalSessions: currentMetrics.totalSessions,
        completedSessions: currentMetrics.completedSessions,
        earlyExitSessions: currentMetrics.earlyExitSessions,
        totalQuietMinutes: currentMetrics.totalQuietMinutes,
        totalAppUsageMinutes:
          range === '3' ? totalAppUsageMinutesAllTime : currentMetrics.totalAppUsageMinutes || totalAppUsageMinutesAllTime,
        avgSessionMinutes: currentMetrics.avgSessionMinutes,
        currentStreakDays: streaks.currentStreakDays,
        longestStreakDays: streaks.longestStreakDays,
        activeDaysCount: currentMetrics.activeDaysCount,
        periodDays,
        totalSilenced: currentMetrics.totalSilenced,
        totalLetThrough: currentMetrics.totalLetThrough,
        activeRulesCount: rules.filter((r) => r.active).length,
        activeProfilesCount: profiles.filter((p) => p.active).length,
        vipContactsCount: Array.isArray(req.user.emergencyContacts)
          ? req.user.emergencyContacts.length
          : 0,
      },
      trend,
      profileStability,
      recentLogs: allLogs.filter((l) => l.source !== 'app_usage').slice(0, 20).map(serializeActivityLog),
      recommendations,
    });
  } catch (error) {
    console.error('[getStabilityReportHandler] Error:', error);
    return res.status(500).json({ success: false, message: 'Failed to generate stability report' });
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
  getLogsHandler,
  createLogHandler,
  deleteLogHandler,
  usagePingHandler,
  getInsightsHandler,
  getStabilityReportHandler,
};
