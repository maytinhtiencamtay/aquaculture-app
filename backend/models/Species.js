const mongoose = require('mongoose');

const speciesSchema = new mongoose.Schema({
  name: { type: String, required: true },
  description: String,
  imageUrl: { type: String, default: '' },
  requiredTemp: { type: Number, default: 28 },
  minTemp: { type: Number, default: 20 },
  maxTemp: { type: Number, default: 35 },
  requiredPh: { type: Number, default: 7 },
  requiredDo: { type: Number, default: 4 },
  maxNh3: { type: Number, default: 0.1 },
  feedRatio: { type: Number, default: 1.5 },
  harvestableWeight: { type: Number, default: 500 },
  growthDays: { type: Number, default: 180 },
  densityPerM2: { type: Number, default: 5 },
  createdAt: { type: Date, default: Date.now },
  updatedAt: Date,
});

module.exports = mongoose.model('Species', speciesSchema);