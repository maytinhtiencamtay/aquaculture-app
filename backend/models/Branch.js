const mongoose = require('mongoose');

const branchSchema = new mongoose.Schema({
  name: { type: String, required: true },
  address: String,
  contact: String,
  manager: String,
  createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('Branch', branchSchema);