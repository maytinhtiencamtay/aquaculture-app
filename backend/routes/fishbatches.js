const express = require('express');
const FishBatch = require('../models/FishBatch');

const router = express.Router();

// GET all fish batches
router.get('/', async (req, res) => {
  const batches = await FishBatch.find().populate('pondId speciesId');
  res.json(batches);
});

// POST create fish batch
router.post('/', async (req, res) => {
  const batch = new FishBatch(req.body);
  await batch.save();
  res.status(201).json(batch);
});

// PUT update fish batch
router.put('/:id', async (req, res) => {
  const batch = await FishBatch.findByIdAndUpdate(req.params.id, req.body, { new: true });
  res.json(batch);
});

// DELETE fish batch
router.delete('/:id', async (req, res) => {
  await FishBatch.findByIdAndDelete(req.params.id);
  res.json({ message: 'Fish batch deleted' });
});

module.exports = router;