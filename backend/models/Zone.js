const mongoose = require('mongoose');

const zoneSchema = new mongoose.Schema({
  name: { type: String, required: true },
  branchId: { type: mongoose.Schema.Types.ObjectId, ref: 'Branch', required: true },
  type: { type: String, enum: ['farming', 'processing', 'logistics'], default: 'farming' },
  createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('Zone', zoneSchema);