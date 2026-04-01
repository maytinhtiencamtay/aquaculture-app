const express = require('express');
const Species = require('../models/Species');

const router = express.Router();

// GET all species
router.get('/', async (req, res) => {
  const species = await Species.find();
  res.json(species);
});

// POST create species
router.post('/', async (req, res) => {
  const species = new Species(req.body);
  await species.save();
  res.status(201).json(species);
});

// PUT update species
router.put('/:id', async (req, res) => {
  const species = await Species.findByIdAndUpdate(req.params.id, req.body, { new: true });
  res.json(species);
});

// DELETE species
router.delete('/:id', async (req, res) => {
  await Species.findByIdAndDelete(req.params.id);
  res.json({ message: 'Species deleted' });
});

module.exports = router;