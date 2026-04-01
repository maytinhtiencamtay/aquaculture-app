import 'package:flutter/material.dart';

import '../models/pond.dart';

class PondDetailScreen extends StatelessWidget {
  const PondDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pond = ModalRoute.of(context)!.settings.arguments as Pond;

    return Scaffold(
      appBar: AppBar(
        title: Text('Ao ${pond.code}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.pushNamed(context, '/pond-form', arguments: pond),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: pond.status == 'active' ? Colors.green : Colors.grey,
                    child: const Icon(Icons.water, size: 32, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(pond.code, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Chip(label: Text(pond.statusLabel)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Info section
          Text('Thông tin ao', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _InfoRow(icon: Icons.category, label: 'Loại ao', value: pond.typeLabel),
                const Divider(height: 1),
                _InfoRow(icon: Icons.square_foot, label: 'Diện tích', value: '${pond.area} m²'),
                const Divider(height: 1),
                _InfoRow(icon: Icons.water, label: 'Thể tích', value: '${pond.volume} m³'),
                const Divider(height: 1),
                _InfoRow(icon: Icons.calendar_today, label: 'Ngày tạo', value: '${pond.createdAt.day}/${pond.createdAt.month}/${pond.createdAt.year}'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Water parameters
          Text('Thông số nước', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _ParamCard(label: 'pH', value: pond.currentPh?.toStringAsFixed(1) ?? '--', icon: Icons.science, color: Colors.blue)),
              const SizedBox(width: 8),
              Expanded(child: _ParamCard(label: 'DO (mg/L)', value: pond.currentDo?.toStringAsFixed(1) ?? '--', icon: Icons.air, color: Colors.green)),
              const SizedBox(width: 8),
              Expanded(child: _ParamCard(label: 'NH3', value: pond.currentNh3?.toStringAsFixed(3) ?? '--', icon: Icons.warning_amber, color: Colors.orange)),
            ],
          ),
          const SizedBox(height: 24),

          // Quick actions
          Text('Thao tác nhanh', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(avatar: const Icon(Icons.edit_note), label: const Text('Cập nhật thông số'), onPressed: () {}),
              ActionChip(avatar: const Icon(Icons.swap_horiz), label: const Text('Chuyển ao'), onPressed: () {}),
              ActionChip(avatar: const Icon(Icons.shopping_cart), label: const Text('Thu hoạch'), onPressed: () {}),
              ActionChip(avatar: const Icon(Icons.assignment_add), label: const Text('Giao việc'), onPressed: () {}),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.teal),
      title: Text(label),
      trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class _ParamCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ParamCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
