/**
 * In-memory fallback repository used when MongoDB is offline during local dev.
 * Persists data for the lifetime of the server process so authentication,
 * OTP verification, profile creation, and dashboard updates work out of the box.
 */

const users = new Map();
const otps = new Map();
const profiles = new Map();
const rules = new Map();
const activityLogs = new Map();

// Helper to generate simulated ObjectIDs
const genId = () => Math.random().toString(36).substring(2, 11) + Date.now().toString(36);

// Default DND profiles to seed for any new user
const getDefaultProfiles = (userId) => [
  {
    _id: genId(),
    userId,
    name: 'Sleep',
    icon: 'moon',
    meta: 'Priority only, 10 PM to 6:30 AM',
    active: true,
    mode: 'priorityOnly',
    autoReply: true,
    hideNotifications: false,
    callWhitelist: 'Starred',
    messageWhitelist: 'VIP only',
    repeatCallersWindowMin: 15,
    autoReplyMessage: 'I am sleeping and will reply in the morning.',
    customTag: '',
  },
  {
    _id: genId(),
    userId,
    name: 'Work',
    icon: 'briefcase',
    meta: 'Starred calls, Mon to Fri 9 to 6',
    active: false,
    mode: 'priorityOnly',
    autoReply: false,
    hideNotifications: false,
    callWhitelist: 'Starred',
    messageWhitelist: 'Work Team',
    repeatCallersWindowMin: 15,
    autoReplyMessage: 'In a focus block. Will follow up soon.',
    customTag: '',
  },
  {
    _id: genId(),
    userId,
    name: 'Meeting',
    icon: 'users',
    meta: 'Total silence during calendar events',
    active: false,
    mode: 'totalSilence',
    autoReply: true,
    hideNotifications: true,
    callWhitelist: 'None',
    messageWhitelist: 'None',
    repeatCallersWindowMin: 0,
    autoReplyMessage: 'Currently in a meeting. Will reach back once free.',
    customTag: '',
  },
  {
    _id: genId(),
    userId,
    name: 'Driving',
    icon: 'car',
    meta: 'Alarms only, Bluetooth: Car',
    active: false,
    mode: 'alarmsOnly',
    autoReply: true,
    hideNotifications: false,
    callWhitelist: 'Starred',
    messageWhitelist: 'None',
    repeatCallersWindowMin: 15,
    autoReplyMessage: 'Driving right now. Will reply when parked safely.',
    customTag: '',
  },
  {
    _id: genId(),
    userId,
    name: 'Study',
    icon: 'book',
    meta: 'Total silence, Tue and Thu 4 to 7 PM',
    active: false,
    mode: 'totalSilence',
    autoReply: false,
    hideNotifications: true,
    callWhitelist: 'None',
    messageWhitelist: 'None',
    repeatCallersWindowMin: 0,
    autoReplyMessage: 'In a study session. Will respond after.',
    customTag: '',
  },
];

const getDefaultRules = (userId) => [
  {
    _id: genId(),
    userId,
    title: 'Sleep schedule',
    subtitle: 'Starts 10:00 PM, every night',
    triggerType: 'schedule',
    days: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    targetProfileName: 'Sleep',
    customCondition: '',
    active: true,
  },
  {
    _id: genId(),
    userId,
    title: 'Work hours',
    subtitle: 'Mon to Fri, 9:00 AM to 6:00 PM',
    triggerType: 'schedule',
    days: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
    targetProfileName: 'Work',
    customCondition: '',
    active: true,
  },
  {
    _id: genId(),
    userId,
    title: 'Calendar meetings',
    subtitle: 'When marked "Busy" on Work Calendar',
    triggerType: 'calendar',
    days: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
    targetProfileName: 'Meeting',
    customCondition: '',
    active: true,
  },
];

module.exports = {
  users,
  otps,
  profiles,
  rules,
  activityLogs,
  genId,
  getDefaultProfiles,
  getDefaultRules,
};
