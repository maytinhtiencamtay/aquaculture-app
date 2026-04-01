const express = require('express');
const Report = require('../models/Report');

const router = express.Router();

// GET all reports
router.get('/', async (req, res) => {
  const reports = await Report.find().populate('generatedBy');
  res.json(reports);
});

// POST create report
router.post('/', async (req, res) => {
  const report = new Report(req.body);
  await report.save();
  res.status(201).json(report);
});

// PUT update report
router.put('/:id', async (req, res) => {
  const report = await Report.findByIdAndUpdate(req.params.id, req.body, { new: true });
  res.json(report);
});

// DELETE report
router.delete('/:id', async (req, res) => {
  await Report.findByIdAndDelete(req.params.id);
  res.json({ message: 'Report deleted' });
});

module.exports = router;