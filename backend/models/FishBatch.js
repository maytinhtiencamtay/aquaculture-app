const mongoose = require('mongoose');

const fishBatchSchema = new mongoose.Schema({
  pondId: { type: mongoose.Schema.Types.ObjectId, ref: 'Pond', required: true },
  speciesId: { type: mongoose.Schema.Types.ObjectId, ref: 'Species', required: true },
  stockingDate: { type: Date, required: true },
  initialQuantity: { type: Number, required: true },
  initialSize: Number, // cm
  initialWeight: Number, // kg
  status: { type: String, enum: ['active', 'transferred', 'harvested'], default: 'active' },
  createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('FishBatch', fishBatchSchema);