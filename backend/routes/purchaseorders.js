const express = require('express');
const PurchaseOrder = require('../models/PurchaseOrder');

const router = express.Router();

// GET all purchase orders
router.get('/', async (req, res) => {
  const orders = await PurchaseOrder.find().populate('supplierId branchId items.productId');
  res.json(orders);
});

// POST create purchase order
router.post('/', async (req, res) => {
  const order = new PurchaseOrder(req.body);
  await order.save();
  res.status(201).json(order);
});

// PUT update purchase order
router.put('/:id', async (req, res) => {
  const order = await PurchaseOrder.findByIdAndUpdate(req.params.id, req.body, { new: true });
  res.json(order);
});

// DELETE purchase order
router.delete('/:id', async (req, res) => {
  await PurchaseOrder.findByIdAndDelete(req.params.id);
  res.json({ message: 'Purchase order deleted' });
});

module.exports = router;