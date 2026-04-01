const mongoose = require('mongoose');

const otherCostSchema = new mongoose.Schema({
  pondId: { type: mongoose.Schema.Types.ObjectId, ref: 'Pond' },
  fishBatchId: { type: mongoose.Schema.Types.ObjectId, ref: 'FishBatch' },
  branchId: { type: mongoose.Schema.Types.ObjectId, ref: 'Branch' },
  date: { type: Date, default: Date.now },
  type: { type: String, enum: ['transport', 'maintenance', 'labor', 'other'], required: true },
  amount: Number,
  note: String
});

module.exports = mongoose.model('OtherCost', otherCostSchema);