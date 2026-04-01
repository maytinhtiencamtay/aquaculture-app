const express = require('express');
const Zone = require('../models/Zone');

const router = express.Router();

// GET all zones
router.get('/', async (req, res) => {
  const zones = await Zone.find().populate('branchId');
  res.json(zones);
});

// POST create zone
router.post('/', async (req, res) => {
  const zone = new Zone(req.body);
  await zone.save();
  res.status(201).json(zone);
});

// PUT update zone
router.put('/:id', async (req, res) => {
  const zone = await Zone.findByIdAndUpdate(req.params.id, req.body, { new: true });
  res.json(zone);
});

// DELETE zone
router.delete('/:id', async (req, res) => {
  await Zone.findByIdAndDelete(req.params.id);
  res.json({ message: 'Zone deleted' });
});

module.exports = router;