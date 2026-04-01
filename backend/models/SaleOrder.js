const mongoose = require('mongoose');

const saleOrderSchema = new mongoose.Schema({
  customerId: { type: mongoose.Schema.Types.ObjectId, ref: 'Customer', required: true },
  date: { type: Date, default: Date.now },
  pondId: { type: mongoose.Schema.Types.ObjectId, ref: 'Pond' },
  fishBatchId: { type: mongoose.Schema.Types.ObjectId, ref: 'FishBatch' },
  totalAmount: Number,
  status: { type: String, enum: ['pending', 'shipped', 'delivered'], default: 'pending' },
  items: [{
    product: String, // e.g., 'Tilapia 1kg'
    quantity: Number,
    price: Number,
    transportFee: Number
  }]
});

module.exports = mongoose.model('SaleOrder', saleOrderSchema);