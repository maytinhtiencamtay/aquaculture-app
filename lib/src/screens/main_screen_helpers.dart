import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

// ═════════════════════════════════════════════════════════════════════════════
// SHARED HELPERS – extracted from main_screen.dart
// ═════════════════════════════════════════════════════════════════════════════

final currencyFmt = NumberFormat('#,###', 'vi');

Color statusColor(String status) {
  switch (status) {
    case 'active': return AppColors.success;
    case 'inactive': return AppColors.textHint;
    case 'maintenance': return AppColors.warning;
    case 'treatment': return AppColors.info;
    case 'pending': return AppColors.warning;
    case 'completed': case 'done': return AppColors.success;
    case 'cancelled': return AppColors.error;
    case 'harvested': return AppColors.secondary;
    case 'transferred': return AppColors.info;
    default: return AppColors.textSecondary;
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onAdd;
  const SectionHeader({super.key, required this.title, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.xl, AppSpace.xl, AppSpace.md),
      child: Row(
        children: [
          Text(title, style: AppText.title.copyWith(fontSize: 18)),
          const Spacer(),
          if (onAdd != null)
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: AppSizes.iconSm),
              label: const Text('Thêm'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.sm),
                textStyle: AppText.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const StatusChip(this.label, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: AppText.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const EmptyState({super.key, required this.icon, required this.message});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: AppColors.textHint),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: AppColors.textSecondary, fontSize: 15)),
        ],
      ),
    );
  }
}

class MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const MiniStat(this.label, this.value, this.color, {super.key});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(30)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: TextStyle(fontSize: 11, color: color.withAlpha(180))),
          ],
        ),
      ),
    );
  }
}

class DropdownFilter extends StatelessWidget {
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;
  const DropdownFilter({super.key, required this.value, required this.items, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final active = value != items.keys.first;
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: active ? AppColors.primary.withAlpha(20) : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? AppColors.primary : AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          icon: Icon(Icons.arrow_drop_down, size: 18, color: active ? AppColors.primary : AppColors.textHint),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: active ? AppColors.primary : AppColors.textSecondary),
          items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }
}
