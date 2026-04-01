const mongoose = require('mongoose');

const purchaseOrderSchema = new mongoose.Schema({
  date: { type: Date, default: Date.now },
  supplierId: { type: mongoose.Schema.Types.ObjectId, ref: 'Supplier' }, // Assuming Supplier model
  branchId: { type: mongoose.Schema.Types.ObjectId, ref: 'Branch', required: true },
  total: Number,
  status: { type: String, enum: ['pending', 'approved', 'received'], default: 'pending' },
  items: [{
    productId: { type: mongoose.Schema.Types.ObjectId, ref: 'Product' },
    quantity: Number,
    unitPrice: Number,
    expiryDate: Date
  }]
});

module.exports = mongoose.model('PurchaseOrder', purchaseOrderSchema);