import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// EXCEL ICON – Microsoft Excel brand icon
// ═══════════════════════════════════════════════════════════════════════════════

/// Excel-branded icon: green rounded square with white bold "X".
class ExcelIcon extends StatelessWidget {
  final double size;
  const ExcelIcon({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF217346),
        borderRadius: BorderRadius.circular(size * 0.18),
      ),
      child: Center(
        child: Text(
          'X',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.58,
            fontWeight: FontWeight.w900,
            height: 1,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED UI WIDGETS – Extracted from duplicate patterns across pages
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Search Box ─────────────────────────────────────────────────────────────

/// Reusable pill-shaped search TextField with clear button.
class AppSearchBox extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final double width;

  const AppSearchBox({
    super.key,
    this.hint = 'Tìm kiếm...',
    required this.onChanged,
    this.controller,
    this.width = 200,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: width,
      height: 36,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13, color: isDark ? AppColors.textHintDark : AppColors.textHint),
          prefixIcon: const Icon(Icons.search, size: 18),
          suffixIcon: controller != null && controller!.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () {
                    controller!.clear();
                    onChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}

// ─── Status Chip ────────────────────────────────────────────────────────────

/// Pill badge showing a status label with color-coded background.
class AppStatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const AppStatusChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

// ─── Filter Chip / Toggle Chip ──────────────────────────────────────────────

/// Animated pill toggle for filter states.
class AppFilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? activeColor;

  const AppFilterChip({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = activeColor ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: icon != null ? 10 : 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? c.withAlpha(20) : (Theme.of(context).brightness == Brightness.dark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? c.withAlpha(80) : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: active ? c : AppColors.textHint),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? c : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Clear filter chip — resets all filters.
class AppClearFilterChip extends StatelessWidget {
  final VoidCallback onTap;
  const AppClearFilterChip({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: const Text('Xóa lọc', style: TextStyle(fontSize: 11)),
      avatar: const Icon(Icons.clear_rounded, size: 14),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
    );
  }
}

// ─── Dropdown Filter ────────────────────────────────────────────────────────

/// Dropdown chip for selecting a filter value from a list.
class AppDropFilter<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String hint;

  const AppDropFilter({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint = 'Tất cả',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasValue = value != null;
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: hasValue
            ? AppColors.primary.withAlpha(20)
            : (isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant),
        borderRadius: BorderRadius.circular(20),
        border: hasValue ? Border.all(color: AppColors.primary.withAlpha(60)) : null,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint, style: const TextStyle(fontSize: 12)),
          icon: const Icon(Icons.arrow_drop_down, size: 18),
          isDense: true,
          style: TextStyle(fontSize: 12, color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ─── Empty State ────────────────────────────────────────────────────────────

/// Centered icon + message placeholder when list is empty.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final double iconSize;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.iconSize = 56,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: AppColors.textHint.withAlpha(120)),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(fontSize: 14, color: AppColors.textHint)),
        ],
      ),
    );
  }
}

// ─── Mini Stat ──────────────────────────────────────────────────────────────

/// Compact stat card with bold value, label, and color accent.
class AppMiniStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final IconData? icon;

  const AppMiniStat({
    super.key,
    required this.value,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null)
              Icon(icon, size: 16, color: color),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ─── Section Header ─────────────────────────────────────────────────────────

/// Page section header with title text and optional add button.
class AppSectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onAdd;
  final String addLabel;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.onAdd,
    this.addLabel = 'Thêm',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const Spacer(),
          if (onAdd != null)
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(addLabel),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}
