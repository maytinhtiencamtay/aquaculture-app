const mongoose = require('mongoose');

const pondSchema = new mongoose.Schema({
  code: { type: String, required: true, unique: true },
  zoneId: { type: mongoose.Schema.Types.ObjectId, ref: 'Zone', required: true },
  area: Number, // m2
  volume: Number, // m3
  depth: Number, // m
  type: { type: String, enum: ['earth', 'hdpe', 'glass', 'cage'], default: 'earth' },
  status: { type: String, enum: ['active', 'inactive', 'maintenance', 'treatment'], default: 'inactive' },
  currentPh: Number,
  currentDo: Number,
  currentNh3: Number,
  currentTemp: Number,
  currentAlkalinity: Number,
  measuredBy: String, // employeeId
  mapX: Number,
  mapY: Number,
  createdAt: { type: Date, default: Date.now },
  updatedAt: Date,
});

module.exports = mongoose.model('Pond', pondSchema);