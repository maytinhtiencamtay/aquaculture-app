const express = require('express');
const Task = require('../models/Task');

const router = express.Router();

// GET all tasks
router.get('/', async (req, res) => {
  const tasks = await Task.find().populate('assignedTo assignedBy pondId fishBatchId');
  res.json(tasks);
});

// POST create task
router.post('/', async (req, res) => {
  const task = new Task(req.body);
  await task.save();
  res.status(201).json(task);
});

// PUT update task
router.put('/:id', async (req, res) => {
  const task = await Task.findByIdAndUpdate(req.params.id, req.body, { new: true });
  res.json(task);
});

// DELETE task
router.delete('/:id', async (req, res) => {
  await Task.findByIdAndDelete(req.params.id);
  res.json({ message: 'Task deleted' });
});

module.exports = router;