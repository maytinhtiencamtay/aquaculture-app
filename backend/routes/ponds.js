const express = require('express');
const Pond = require('../models/Pond');

const router = express.Router();

// GET all ponds
router.get('/', async (req, res) => {
  const ponds = await Pond.find().populate('zoneId');
  res.json(ponds);
});

// POST create pond
router.post('/', async (req, res) => {
  const pond = new Pond(req.body);
  await pond.save();
  res.status(201).json(pond);
});

// PUT update pond
router.put('/:id', async (req, res) => {
  const pond = await Pond.findByIdAndUpdate(req.params.id, req.body, { new: true });
  res.json(pond);
});

// DELETE pond
router.delete('/:id', async (req, res) => {
  await Pond.findByIdAndDelete(req.params.id);
  res.json({ message: 'Pond deleted' });
});

module.exports = router;