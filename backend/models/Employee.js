const mongoose = require('mongoose');

const employeeSchema = new mongoose.Schema({
  name: { type: String, required: true },
  email: { type: String, unique: true, sparse: true },
  password: String,
  role: { type: String, required: true },
  phone: String,
  branchId: { type: mongoose.Schema.Types.ObjectId, ref: 'Branch' },
  shift: String,
  hasAccount: { type: Boolean, default: false },
  permissions: { type: [String], default: [] },
  createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('Employee', employeeSchema);