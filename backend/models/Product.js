const mongoose = require('mongoose');

const productSchema = new mongoose.Schema({
  sku: { type: String, default: '' },
  name: { type: String, required: true },
  category: { type: String, default: 'feed' },
  brand: { type: String, default: '' },
  origin: { type: String, default: '' },
  unit: { type: String, default: 'kg' },
  description: { type: String, default: '' },
  price: { type: Number, default: 0 },
  costPrice: { type: Number, default: 0 },
  stock: { type: Number, default: 0 },
  minStock: { type: Number, default: 0 },
  maxStock: { type: Number, default: 0 },
  supplierId: { type: String, default: '' },
  location: { type: String, default: '' },
  expiryDate: Date,
  note: { type: String, default: '' },
  isActive: { type: Boolean, default: true },
  createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('Product', productSchema);