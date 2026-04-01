const express = require('express');
const Employee = require('../models/Employee');

const router = express.Router();

// GET all employees
router.get('/', async (req, res) => {
  const employees = await Employee.find().populate('branchId');
  res.json(employees);
});

// POST create employee
router.post('/', async (req, res) => {
  const employee = new Employee(req.body);
  await employee.save();
  res.status(201).json(employee);
});

// PUT update employee
router.put('/:id', async (req, res) => {
  const employee = await Employee.findByIdAndUpdate(req.params.id, req.body, { new: true });
  res.json(employee);
});

// DELETE employee
router.delete('/:id', async (req, res) => {
  await Employee.findByIdAndDelete(req.params.id);
  res.json({ message: 'Employee deleted' });
});

module.exports = router;