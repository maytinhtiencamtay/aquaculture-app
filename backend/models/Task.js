const mongoose = require('mongoose');

const taskSchema = new mongoose.Schema({
  title: { type: String, required: true },
  description: String,
  type: { type: String, enum: ['feeding', 'water_change', 'measurement', 'treatment', 'harvesting'], required: true },
  priority: { type: String, enum: ['low', 'medium', 'high'], default: 'medium' },
  assignedTo: { type: mongoose.Schema.Types.ObjectId, ref: 'Employee', required: true },
  assignedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'Employee' },
  pondId: { type: mongoose.Schema.Types.ObjectId, ref: 'Pond' },
  fishBatchId: { type: mongoose.Schema.Types.ObjectId, ref: 'FishBatch' },
  dueDate: Date,
  status: { type: String, enum: ['pending', 'in_progress', 'completed', 'overdue'], default: 'pending' },
  checklist: [String],
  completedItems: [String],
  attachments: [String], // URLs or paths
  notes: String,
  createdAt: { type: Date, default: Date.now },
  completedAt: Date
});

module.exports = mongoose.model('Task', taskSchema);