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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
        ),
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: [BoxShadow(color: const Color(0xFF217346).withAlpha(30), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Center(
        child: Text(
          'X',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.55,
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

// ─── Filter Bar Container ───────────────────────────────────────────────────

/// Standard horizontal scroll filter bar with consistent padding.
class AppFilterBar extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  const AppFilterBar({super.key, required this.children, this.padding});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _insertGaps(children),
        ),
      ),
    );
  }

  /// Insert uniform 8px gaps between children.
  static List<Widget> _insertGaps(List<Widget> children) {
    if (children.isEmpty) return children;
    final result = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      result.add(children[i]);
      if (i < children.length - 1) result.add(const SizedBox(width: 8));
    }
    return result;
  }
}

// ─── Search Box ─────────────────────────────────────────────────────────────

/// Reusable pill-shaped search TextField with clear button.
class AppSearchBox extends StatefulWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final double width;

  const AppSearchBox({
    super.key,
    this.hint = 'Tìm kiếm...',
    required this.onChanged,
    this.width = 200,
  });

  @override
  State<AppSearchBox> createState() => _AppSearchBoxState();
}

class _AppSearchBoxState extends State<AppSearchBox> {
  final _ctrl = TextEditingController();
  bool _hasText = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _onClear() {
    _ctrl.clear();
    widget.onChanged('');
    setState(() => _hasText = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: widget.width,
      height: 34,
      child: TextField(
        controller: _ctrl,
        onChanged: (v) {
          widget.onChanged(v);
          if (v.isNotEmpty != _hasText) setState(() => _hasText = v.isNotEmpty);
        },
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: TextStyle(fontSize: 12, color: isDark ? AppColors.textHintDark : AppColors.textHint),
          prefixIcon: const Icon(Icons.search_rounded, size: 18),
          prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 20),
          suffixIcon: _hasText
              ? GestureDetector(
                  onTap: _onClear,
                  child: Icon(Icons.close_rounded, size: 16, color: isDark ? AppColors.textHintDark : AppColors.textHint),
                )
              : null,
          suffixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 20),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          filled: true,
          fillColor: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: isDark ? AppColors.borderDark : AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: isDark ? AppColors.borderDark : AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
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
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color.withAlpha(60), blurRadius: 3)],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

// ─── Toggle Chip ────────────────────────────────────────────────────────────

/// Animated boolean toggle chip (on/off). For warning-style toggles (low stock, expiry).
class AppToggleChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;
  final Color activeColor;

  const AppToggleChip({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
    this.activeColor = AppColors.error,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? activeColor.withAlpha(15) : (isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? activeColor : (isDark ? AppColors.borderDark : AppColors.border)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon!, size: 15, color: active ? activeColor : AppColors.textHint),
              const SizedBox(width: 5),
            ],
            Text(label, style: TextStyle(
              color: active ? activeColor : AppColors.textSecondary,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              fontSize: 12,
            )),
          ],
        ),
      ),
    );
  }
}

// ─── Radio Filter Chip ──────────────────────────────────────────────────────

/// Radio-style chip: one value selected from a group. Solid primary bg when active.
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 34,
        padding: EdgeInsets.symmetric(horizontal: icon != null ? 10 : 14),
        decoration: BoxDecoration(
          color: active ? c.withAlpha(20) : (isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? c.withAlpha(80) : (isDark ? AppColors.borderDark : AppColors.border)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: active ? c : AppColors.textHint),
              const SizedBox(width: 5),
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
    return SizedBox(
      height: 34,
      child: ActionChip(
        avatar: const Icon(Icons.clear_rounded, size: 14),
        label: const Text('Xóa lọc', style: TextStyle(fontSize: 12)),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        visualDensity: VisualDensity.compact,
        onPressed: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

// ─── Dropdown Filter ────────────────────────────────────────────────────────

/// Dropdown filter taking a generic List of DropdownMenuItems.
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
            ? AppColors.primary.withAlpha(15)
            : (isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hasValue ? AppColors.primary.withAlpha(60) : (isDark ? AppColors.borderDark : AppColors.border)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint, style: const TextStyle(fontSize: 12)),
          icon: Icon(Icons.arrow_drop_down, size: 18, color: hasValue ? AppColors.primary : AppColors.textHint),
          isDense: true,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: hasValue ? AppColors.primary : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary)),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Dropdown filter from a Map<String, String> — convenience for common pattern.
class AppDropMapFilter extends StatelessWidget {
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  const AppDropMapFilter({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = value != items.keys.first;
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: active
            ? AppColors.primary.withAlpha(15)
            : (isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? AppColors.primary.withAlpha(60) : (isDark ? AppColors.borderDark : AppColors.border)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          icon: Icon(Icons.arrow_drop_down, size: 18, color: active ? AppColors.primary : AppColors.textHint),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: active ? AppColors.primary : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)),
          items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }
}

/// Chip-like filter that triggers a callback (for bottom sheet pickers etc.)
class AppTapFilter extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const AppTapFilter({super.key, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withAlpha(15)
              : (isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? AppColors.primary.withAlpha(60) : (isDark ? AppColors.borderDark : AppColors.border)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: active ? AppColors.primary : AppColors.textSecondary)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 16, color: active ? AppColors.primary : AppColors.textHint),
          ],
        ),
      ),
    );
  }
}

/// Inline filter label showing count/text before filter controls.
class AppFilterLabel extends StatelessWidget {
  final String text;
  const AppFilterLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary));
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.textHint.withAlpha(8),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: iconSize, color: AppColors.textHint.withAlpha(100)),
          ),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(fontSize: 14, color: AppColors.textHint), textAlign: TextAlign.center),
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
          color: color.withAlpha(10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null)
              Container(
                padding: const EdgeInsets.all(4),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
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
          Container(
            width: 3,
            height: 20,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
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
