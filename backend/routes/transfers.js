const express = require('express');
const Transfer = require('../models/Transfer');

const router = express.Router();

// GET all transfers
router.get('/', async (req, res) => {
  const transfers = await Transfer.find().populate('fromPondId toPondId fishBatchId');
  res.json(transfers);
});

// POST create transfer
router.post('/', async (req, res) => {
  const transfer = new Transfer(req.body);
  await transfer.save();
  res.status(201).json(transfer);
});

// PUT update transfer
router.put('/:id', async (req, res) => {
  const transfer = await Transfer.findByIdAndUpdate(req.params.id, req.body, { new: true });
  res.json(transfer);
});

// DELETE transfer
router.delete('/:id', async (req, res) => {
  await Transfer.findByIdAndDelete(req.params.id);
  res.json({ message: 'Transfer deleted' });
});

module.exports = router;