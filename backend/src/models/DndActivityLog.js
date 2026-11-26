const mongoose = require('mongoose');

const dndActivityLogSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    date: {
      type: Date,
      default: Date.now,
      index: true,
    },
    profileName: {
      type: String,
      default: 'Do Not Disturb',
      trim: true,
    },
    durationMinutes: {
      type: Number,
      default: 0,
      min: 0,
    },
    plannedMinutes: {
      type: Number,
      default: 60,
      min: 0,
    },
    appUsageMinutes: {
      type: Number,
      default: 0,
      min: 0,
    },
    completedWithoutEarlyExit: {
      type: Boolean,
      default: true,
    },
    silencedCount: {
      type: Number,
      default: 0,
      min: 0,
    },
    letThroughCount: {
      type: Number,
      default: 0,
      min: 0,
    },
    focusStabilityRating: {
      type: Number,
      default: 4,
      min: 1,
      max: 5,
    },
    source: {
      type: String,
      enum: ['auto_toggle', 'manual_log', 'app_usage'],
      default: 'manual_log',
    },
    notes: {
      type: String,
      default: '',
      trim: true,
    },
  },
  {
    timestamps: true,
  }
);

dndActivityLogSchema.methods.toJSON = function () {
  const obj = this.toObject();
  delete obj.__v;
  return obj;
};

module.exports = mongoose.model('DndActivityLog', dndActivityLogSchema);
