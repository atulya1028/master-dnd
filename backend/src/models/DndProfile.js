const mongoose = require('mongoose');

const dndProfileSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    name: {
      type: String,
      required: true,
      trim: true,
    },
    icon: {
      type: String,
      default: 'moon',
    },
    meta: {
      type: String,
      default: '',
    },
    active: {
      type: Boolean,
      default: false,
    },
    mode: {
      type: String,
      default: 'priorityOnly',
    },
    autoReply: {
      type: Boolean,
      default: true,
    },
    hideNotifications: {
      type: Boolean,
      default: false,
    },
    callWhitelist: {
      type: String,
      default: 'Starred',
    },
    messageWhitelist: {
      type: String,
      default: 'VIP only',
    },
    repeatCallersWindowMin: {
      type: Number,
      default: 15,
    },
  },
  {
    timestamps: true,
  }
);

dndProfileSchema.methods.toJSON = function () {
  const obj = this.toObject();
  delete obj.__v;
  return obj;
};

module.exports = mongoose.model('DndProfile', dndProfileSchema);
