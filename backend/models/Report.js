const mongoose = require('mongoose');

const reportSchema = new mongoose.Schema({
  type: { type: String, enum: ['stock', 'growth', 'cost', 'sales'], required: true },
  dateRange: {
    start: Date,
    end: Date
  },
  data: mongoose.Schema.Types.Mixed, // JSON data for the report
  generatedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'Employee' },
  createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('Report', reportSchema);