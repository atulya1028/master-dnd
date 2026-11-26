const DEFAULT_DURATIONS = [30, 60];
const DEFAULT_CONTACT_CATEGORIES = [
  'VIP Contact',
  'Family',
  'Doctor / Emergency',
  'Repeat Caller',
  'Work Priority',
];
const DEFAULT_WHITELIST_OPTIONS = [
  'Starred',
  'Contacts only',
  'VIP only',
  'Everyone',
  'No one',
];

const serializeUser = (user) => {
  if (!user) return null;
  const contacts = Array.isArray(user.emergencyContacts)
    ? user.emergencyContacts.map((c) => ({
        id: (c._id || c.id || '').toString(),
        name: c.name || '',
        phone: c.phone || '',
        relationship: c.relationship || 'VIP Contact',
        isVip: c.isVip !== false,
      }))
    : [];

  return {
    id: (user._id || user.id || '').toString(),
    phone: user.phone || '',
    name: user.name || '',
    email: user.email || '',
    avatar: user.avatar || (user.name ? user.name[0].toUpperCase() : 'A'),
    bio: user.bio || '',
    isProfileComplete: Boolean(user.isProfileComplete),
    dndEnabled: Boolean(user.dndEnabled),
    activeSessionStart: user.activeSessionStart || null,
    activeSessionPlannedMinutes: user.activeSessionPlannedMinutes || 60,
    activeSessionEndTime: user.activeSessionEndTime || null,
    activeProfileName: user.activeProfileName || '',
    customDurations:
      Array.isArray(user.customDurations) && user.customDurations.length > 0
        ? user.customDurations
        : DEFAULT_DURATIONS,
    customContactCategories:
      Array.isArray(user.customContactCategories) && user.customContactCategories.length > 0
        ? user.customContactCategories
        : DEFAULT_CONTACT_CATEGORIES,
    customWhitelistOptions:
      Array.isArray(user.customWhitelistOptions) && user.customWhitelistOptions.length > 0
        ? user.customWhitelistOptions
        : DEFAULT_WHITELIST_OPTIONS,
    totalAppUsageMinutes: Number(user.totalAppUsageMinutes || 0),
    emergencyContacts: contacts,
    notificationPreferences: user.notificationPreferences || {
      allowDndAccess: true,
      allowContacts: true,
      allowNotifications: true,
    },
  };
};

const serializeProfile = (p) => ({
  id: (p._id || p.id || '').toString(),
  name: p.name,
  icon: p.icon || 'moon',
  meta: p.meta || '',
  active: Boolean(p.active),
  mode: p.mode || 'priorityOnly',
  autoReply: Boolean(p.autoReply),
  hideNotifications: Boolean(p.hideNotifications),
  callWhitelist: p.callWhitelist || 'Starred',
  messageWhitelist: p.messageWhitelist || 'VIP only',
  repeatCallersWindowMin:
    typeof p.repeatCallersWindowMin === 'number' ? p.repeatCallersWindowMin : 15,
  autoReplyMessage:
    p.autoReplyMessage || 'I am currently in Do Not Disturb mode and will respond shortly.',
  customTag: p.customTag || '',
});

const serializeRule = (r) => ({
  id: (r._id || r.id || '').toString(),
  title: r.title,
  subtitle: r.subtitle || '',
  triggerType: r.triggerType || 'schedule',
  days:
    Array.isArray(r.days) && r.days.length > 0
      ? r.days
      : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
  targetProfileName: r.targetProfileName || '',
  customCondition: r.customCondition || '',
  active: Boolean(r.active),
});

const serializeActivityLog = (l) => ({
  id: (l._id || l.id || '').toString(),
  date: l.date || l.createdAt || new Date(),
  profileName: l.profileName || 'Do Not Disturb',
  durationMinutes: Number(l.durationMinutes || 0),
  plannedMinutes: Number(l.plannedMinutes || 60),
  appUsageMinutes: Number(l.appUsageMinutes || 0),
  completedWithoutEarlyExit: l.completedWithoutEarlyExit !== false,
  silencedCount: Number(l.silencedCount || 0),
  letThroughCount: Number(l.letThroughCount || 0),
  focusStabilityRating: Number(l.focusStabilityRating || 4),
  source: l.source || 'manual_log',
  notes: l.notes || '',
});

module.exports = {
  DEFAULT_DURATIONS,
  DEFAULT_CONTACT_CATEGORIES,
  DEFAULT_WHITELIST_OPTIONS,
  serializeUser,
  serializeProfile,
  serializeRule,
  serializeActivityLog,
};
