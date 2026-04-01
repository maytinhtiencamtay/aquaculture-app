const mongoose = require('mongoose');

const customerSchema = new mongoose.Schema({
  name: { type: String, required: true },
  type: { type: String, enum: ['retail', 'wholesale'], default: 'retail' },
  company: { type: String, default: '' },
  phone: { type: String, default: '' },
  email: { type: String, default: '' },
  address: String,
  contact: String,
  note: { type: String, default: '' },
  debt: { type: Number, default: 0 },
  createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('Customer', customerSchema);