const express = require('express');
const Branch = require('../models/Branch');

const router = express.Router();

// GET all branches
router.get('/', async (req, res) => {
  const branches = await Branch.find();
  res.json(branches);
});

// POST create branch
router.post('/', async (req, res) => {
  const branch = new Branch(req.body);
  await branch.save();
  res.status(201).json(branch);
});

// PUT update branch
router.put('/:id', async (req, res) => {
  const branch = await Branch.findByIdAndUpdate(req.params.id, req.body, { new: true });
  res.json(branch);
});

// DELETE branch
router.delete('/:id', async (req, res) => {
  await Branch.findByIdAndDelete(req.params.id);
  res.json({ message: 'Branch deleted' });
});

module.exports = router;