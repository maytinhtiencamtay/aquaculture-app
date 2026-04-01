const express = require('express');
const SizeMeasurement = require('../models/SizeMeasurement');

const router = express.Router();

// GET all size measurements
router.get('/', async (req, res) => {
  const measurements = await SizeMeasurement.find().populate('fishBatchId measuredBy');
  res.json(measurements);
});

// POST create size measurement
router.post('/', async (req, res) => {
  const measurement = new SizeMeasurement(req.body);
  await measurement.save();
  res.status(201).json(measurement);
});

// PUT update size measurement
router.put('/:id', async (req, res) => {
  const measurement = await SizeMeasurement.findByIdAndUpdate(req.params.id, req.body, { new: true });
  res.json(measurement);
});

// DELETE size measurement
router.delete('/:id', async (req, res) => {
  await SizeMeasurement.findByIdAndDelete(req.params.id);
  res.json({ message: 'Size measurement deleted' });
});

module.exports = router;