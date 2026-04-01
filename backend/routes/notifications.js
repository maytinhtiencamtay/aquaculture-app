const express = require('express');
const Notification = require('../models/Notification');

const router = express.Router();

// GET all notifications
router.get('/', async (req, res) => {
  const notifications = await Notification.find().populate('targetUserId targetBranchId relatedEntity.pondId relatedEntity.batchId relatedEntity.productId relatedEntity.taskId');
  res.json(notifications);
});

// POST create notification
router.post('/', async (req, res) => {
  const notification = new Notification(req.body);
  await notification.save();
  res.status(201).json(notification);
});

// PUT update notification
router.put('/:id', async (req, res) => {
  const notification = await Notification.findByIdAndUpdate(req.params.id, req.body, { new: true });
  res.json(notification);
});

// DELETE notification
router.delete('/:id', async (req, res) => {
  await Notification.findByIdAndDelete(req.params.id);
  res.json({ message: 'Notification deleted' });
});

module.exports = router;