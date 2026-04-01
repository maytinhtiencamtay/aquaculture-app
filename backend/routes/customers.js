const express = require('express');
const Customer = require('../models/Customer');

const router = express.Router();

// GET all customers
router.get('/', async (req, res) => {
  const customers = await Customer.find();
  res.json(customers);
});

// POST create customer
router.post('/', async (req, res) => {
  const customer = new Customer(req.body);
  await customer.save();
  res.status(201).json(customer);
});

// PUT update customer
router.put('/:id', async (req, res) => {
  const customer = await Customer.findByIdAndUpdate(req.params.id, req.body, { new: true });
  res.json(customer);
});

// DELETE customer
router.delete('/:id', async (req, res) => {
  await Customer.findByIdAndDelete(req.params.id);
  res.json({ message: 'Customer deleted' });
});

module.exports = router;