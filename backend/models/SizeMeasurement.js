const mongoose = require('mongoose');

const sizeMeasurementSchema = new mongoose.Schema({
  fishBatchId: { type: mongoose.Schema.Types.ObjectId, ref: 'FishBatch', required: true },
  date: { type: Date, default: Date.now },
  avgWeight: Number, // kg
  avgLength: Number, // cm
  remainingQuantity: Number,
  measuredBy: { type: mongoose.Schema.Types.ObjectId, ref: 'Employee' }
});

module.exports = mongoose.model('SizeMeasurement', sizeMeasurementSchema);