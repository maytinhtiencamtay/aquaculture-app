const express = require('express');
const OtherCost = require('../models/OtherCost');

const router = express.Router();

// GET all other costs
router.get('/', async (req, res) => {
  const costs = await OtherCost.find().populate('pondId fishBatchId branchId');
  res.json(costs);
});

// POST create other cost
router.post('/', async (req, res) => {
  const cost = new OtherCost(req.body);
  await cost.save();
  res.status(201).json(cost);
});

// PUT update other cost
router.put('/:id', async (req, res) => {
  const cost = await OtherCost.findByIdAndUpdate(req.params.id, req.body, { new: true });
  res.json(cost);
});

// DELETE other cost
router.delete('/:id', async (req, res) => {
  await OtherCost.findByIdAndDelete(req.params.id);
  res.json({ message: 'Other cost deleted' });
});

module.exports = router;