const mongoose = require('mongoose');

const transferSchema = new mongoose.Schema({
  fromPondId: { type: mongoose.Schema.Types.ObjectId, ref: 'Pond', required: true },
  toPondId: { type: mongoose.Schema.Types.ObjectId, ref: 'Pond', required: true },
  fishBatchId: { type: mongoose.Schema.Types.ObjectId, ref: 'FishBatch', required: true },
  date: { type: Date, default: Date.now },
  quantity: Number,
  weight: Number, // kg
  reason: String
});

module.exports = mongoose.model('Transfer', transferSchema);