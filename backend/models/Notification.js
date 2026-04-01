const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema({
  title: { type: String, required: true },
  message: String,
  type: { type: String, enum: ['warning', 'info', 'alert'], default: 'info' },
  priority: { type: String, enum: ['low', 'medium', 'high'], default: 'medium' },
  targetUserId: { type: mongoose.Schema.Types.ObjectId, ref: 'Employee' },
  targetBranchId: { type: mongoose.Schema.Types.ObjectId, ref: 'Branch' },
  isRead: { type: Boolean, default: false },
  relatedEntity: {
    pondId: { type: mongoose.Schema.Types.ObjectId, ref: 'Pond' },
    batchId: { type: mongoose.Schema.Types.ObjectId, ref: 'FishBatch' },
    productId: { type: mongoose.Schema.Types.ObjectId, ref: 'Product' },
    taskId: { type: mongoose.Schema.Types.ObjectId, ref: 'Task' }
  },
  createdAt: { type: Date, default: Date.now },
  sentAt: Date
});

module.exports = mongoose.model('Notification', notificationSchema);