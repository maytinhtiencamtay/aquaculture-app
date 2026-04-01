const express = require('express');
const SaleOrder = require('../models/SaleOrder');

const router = express.Router();

// GET all sale orders
router.get('/', async (req, res) => {
  const orders = await SaleOrder.find().populate('customerId pondId fishBatchId');
  res.json(orders);
});

// POST create sale order
router.post('/', async (req, res) => {
  const order = new SaleOrder(req.body);
  await order.save();
  res.status(201).json(order);
});

// PUT update sale order
router.put('/:id', async (req, res) => {
  const order = await SaleOrder.findByIdAndUpdate(req.params.id, req.body, { new: true });
  res.json(order);
});

// DELETE sale order
router.delete('/:id', async (req, res) => {
  await SaleOrder.findByIdAndDelete(req.params.id);
  res.json({ message: 'Sale order deleted' });
});

module.exports = router;