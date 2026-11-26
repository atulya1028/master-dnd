const mongoose = require('mongoose');

const emergencyContactSchema = new mongoose.Schema({
  name: { type: String, required: true },
  phone: { type: String, default: '' },
  relationship: { type: String, default: 'VIP Contact' },
  isVip: { type: Boolean, default: true },
});

const userSchema = new mongoose.Schema(
  {
    phone: {
      type: String,
      default: '',
      trim: true,
    },
    email: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      lowercase: true,
      index: true,
    },
    name: {
      type: String,
      default: '',
      trim: true,
    },
    avatar: {
      type: String,
      default: 'A',
    },
    bio: {
      type: String,
      default: '',
    },
    isProfileComplete: {
      type: Boolean,
      default: false,
    },
    dndEnabled: {
      type: Boolean,
      default: false,
    },
    activeSessionStart: {
      type: Date,
      default: null,
    },
    activeSessionPlannedMinutes: {
      type: Number,
      default: 60,
    },
    activeSessionEndTime: {
      type: Date,
      default: null,
    },
    activeProfileName: {
      type: String,
      default: '',
    },
    customDurations: {
      type: [Number],
      default: [30, 60],
    },
    customContactCategories: {
      type: [String],
      default: ['VIP Contact', 'Family', 'Doctor / Emergency', 'Repeat Caller', 'Work Priority'],
    },
    customWhitelistOptions: {
      type: [String],
      default: ['Starred', 'Contacts only', 'VIP only', 'Everyone', 'No one'],
    },
    totalAppUsageMinutes: {
      type: Number,
      default: 0,
    },
    hasSeededDefaults: {
      type: Boolean,
      default: false,
    },
    emergencyContacts: [emergencyContactSchema],
    notificationPreferences: {
      allowDndAccess: { type: Boolean, default: true },
      allowContacts: { type: Boolean, default: true },
      allowNotifications: { type: Boolean, default: true },
    },
  },
  {
    timestamps: true,
  }
);

userSchema.methods.toJSON = function () {
  const obj = this.toObject();
  delete obj.__v;
  return obj;
};

module.exports = mongoose.model('User', userSchema);
