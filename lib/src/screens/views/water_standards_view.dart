import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../providers/data_provider.dart';
import '../../models/water_standard.dart';
import '../../theme/app_theme.dart';

// ═════════════════════════════════════════════════════════════════════════════
// WATER STANDARDS VIEW – extracted from main_screen.dart
// ═════════════════════════════════════════════════════════════════════════════

class WaterStandardsView extends StatefulWidget {
  final DataProvider dp;
  const WaterStandardsView({super.key, required this.dp});
  @override
  State<WaterStandardsView> createState() => _WaterStandardsViewState();
}

class _WaterStandardsViewState extends State<WaterStandardsView> {
  DataProvider get dp => widget.dp;

  static const _paramIcons = <String, IconData>{
    'ph': Icons.science_outlined,
    'do': Icons.bubble_chart_outlined,
    'temp': Icons.thermostat_outlined,
    'nh3': Icons.warning_amber_rounded,
    'alkalinity': Icons.opacity_outlined,
    'no2': Icons.coronavirus_outlined,
    'salinity': Icons.waves_outlined,
  };

  static const _paramColors = <String, Color>{
    'ph': Color(0xFF6C63FF),
    'do': Color(0xFF00BFA6),
    'temp': Color(0xFFFF7043),
    'nh3': Color(0xFFEF5350),
    'alkalinity': Color(0xFF42A5F5),
    'no2': Color(0xFFAB47BC),
    'salinity': Color(0xFF26C6DA),
  };

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  Future<void> _showEditDialog(WaterStandard ws) async {
    final safeMinC = TextEditingController(text: ws.safeMin.toString());
    final safeMaxC = TextEditingController(text: ws.safeMax.toString());
    final optMinC = TextEditingController(text: ws.optimalMin.toString());
    final optMaxC = TextEditingController(text: ws.optimalMax.toString());
    final noteC = TextEditingController(text: ws.note);
    bool isActive = ws.isActive;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, ss) => AlertDialog(
          title: Row(children: [
            Icon(_paramIcons[ws.paramKey] ?? Icons.water_drop, color: _paramColors[ws.paramKey] ?? AppColors.primary),
            const SizedBox(width: 8),
            Expanded(child: Text('Cài đặt ${ws.name}', overflow: TextOverflow.ellipsis)),
          ]),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Kích hoạt', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(isActive ? 'Đang theo dõi' : 'Đã tắt'),
                  value: isActive,
                  activeTrackColor: AppColors.success.withAlpha(80),
                  thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.success : null),
                  onChanged: (v) => ss(() => isActive = v),
                ),
                const Divider(),
                const SizedBox(height: 8),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.warning.withAlpha(20), borderRadius: BorderRadius.circular(6)),
                    child: const Text('Mức an toàn', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.warning)),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: TextField(controller: safeMinC, decoration: InputDecoration(labelText: 'Tối thiểu', suffixText: ws.unit, isDense: true), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: safeMaxC, decoration: InputDecoration(labelText: 'Tối đa', suffixText: ws.unit, isDense: true), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.success.withAlpha(20), borderRadius: BorderRadius.circular(6)),
                    child: const Text('Mức tối ưu', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.success)),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: TextField(controller: optMinC, decoration: InputDecoration(labelText: 'Tối thiểu', suffixText: ws.unit, isDense: true), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: optMaxC, decoration: InputDecoration(labelText: 'Tối đa', suffixText: ws.unit, isDense: true), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                ]),
                const SizedBox(height: 16),
                TextField(controller: noteC, decoration: const InputDecoration(labelText: 'Ghi chú', prefixIcon: Icon(Icons.note_outlined)), maxLines: 2),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Huỷ')),
            FilledButton.icon(
              onPressed: () {
                final sMin = double.tryParse(safeMinC.text);
                final sMax = double.tryParse(safeMaxC.text);
                final oMin = double.tryParse(optMinC.text);
                final oMax = double.tryParse(optMaxC.text);
                if (sMin == null || sMax == null || oMin == null || oMax == null) {
                  ScaffoldMessenger.of(dCtx).showSnackBar(const SnackBar(content: Text('Vui lòng nhập đúng số')));
                  return;
                }
                if (sMin > sMax || oMin > oMax) {
                  ScaffoldMessenger.of(dCtx).showSnackBar(const SnackBar(content: Text('Giá trị tối thiểu phải <= tối đa')));
                  return;
                }
                if (oMin < sMin || oMax > sMax) {
                  ScaffoldMessenger.of(dCtx).showSnackBar(const SnackBar(content: Text('Mức tối ưu phải nằm trong mức an toàn')));
                  return;
                }
                Navigator.pop(dCtx, true);
              },
              icon: const Icon(Icons.check),
              label: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      final data = {
        'name': ws.name,
        'paramKey': ws.paramKey,
        'unit': ws.unit,
        'safeMin': double.tryParse(safeMinC.text) ?? ws.safeMin,
        'safeMax': double.tryParse(safeMaxC.text) ?? ws.safeMax,
        'optimalMin': double.tryParse(optMinC.text) ?? ws.optimalMin,
        'optimalMax': double.tryParse(optMaxC.text) ?? ws.optimalMax,
        'isActive': isActive,
        'note': noteC.text.trim(),
      };
      final success = await dp.update('waterstandards', ws.id, data);
      if (success) {
        _showSnack('Đã cập nhật ${ws.name}');
      }
    }
  }

  Future<void> _showAddDialog() async {
    final nameC = TextEditingController();
    final keyC = TextEditingController();
    final unitC = TextEditingController();
    final safeMinC = TextEditingController(text: '0');
    final safeMaxC = TextEditingController();
    final optMinC = TextEditingController(text: '0');
    final optMaxC = TextEditingController();
    final noteC = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.add_circle_outline, color: AppColors.primary),
          SizedBox(width: 8),
          Text('Thêm thông số nước'),
        ]),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Tên thông số *', hintText: 'VD: Phospho', prefixIcon: Icon(Icons.label_outlined))),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: keyC, decoration: const InputDecoration(labelText: 'Mã (key) *', hintText: 'VD: phospho', isDense: true))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: unitC, decoration: const InputDecoration(labelText: 'Đơn vị', hintText: 'VD: mg/L', isDense: true))),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.warning.withAlpha(20), borderRadius: BorderRadius.circular(6)),
                  child: const Text('Mức an toàn', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.warning)),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: safeMinC, decoration: const InputDecoration(labelText: 'Min', isDense: true), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: safeMaxC, decoration: const InputDecoration(labelText: 'Max', isDense: true), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.success.withAlpha(20), borderRadius: BorderRadius.circular(6)),
                  child: const Text('Mức tối ưu', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.success)),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: optMinC, decoration: const InputDecoration(labelText: 'Min', isDense: true), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: optMaxC, decoration: const InputDecoration(labelText: 'Max', isDense: true), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
              ]),
              const SizedBox(height: 12),
              TextField(controller: noteC, decoration: const InputDecoration(labelText: 'Ghi chú', prefixIcon: Icon(Icons.note_outlined))),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Huỷ')),
          FilledButton.icon(
            onPressed: () {
              if (nameC.text.trim().isEmpty || keyC.text.trim().isEmpty) {
                ScaffoldMessenger.of(dCtx).showSnackBar(const SnackBar(content: Text('Vui lòng nhập tên và mã')));
                return;
              }
              final sMax = double.tryParse(safeMaxC.text);
              final oMax = double.tryParse(optMaxC.text);
              if (sMax == null || oMax == null) {
                ScaffoldMessenger.of(dCtx).showSnackBar(const SnackBar(content: Text('Vui lòng nhập giá trị tối đa')));
                return;
              }
              Navigator.pop(dCtx, true);
            },
            icon: const Icon(Icons.check),
            label: const Text('Thêm'),
          ),
        ],
      ),
    );

    if (ok == true) {
      final data = {
        'name': nameC.text.trim(),
        'paramKey': keyC.text.trim().toLowerCase(),
        'unit': unitC.text.trim(),
        'safeMin': double.tryParse(safeMinC.text) ?? 0,
        'safeMax': double.tryParse(safeMaxC.text) ?? 0,
        'optimalMin': double.tryParse(optMinC.text) ?? 0,
        'optimalMax': double.tryParse(optMaxC.text) ?? 0,
        'isActive': true,
        'note': noteC.text.trim(),
      };
      final success = await dp.create('waterstandards', data);
      if (success) {
        _showSnack('Đã thêm ${nameC.text.trim()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final standards = dp.waterStandards;
    final activeCount = standards.where((w) => w.isActive).length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(children: [
            const Icon(Icons.water_drop_rounded, color: AppColors.primary, size: 24),
            const SizedBox(width: 8),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$activeCount/${standards.length} thông số đang theo dõi', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            )),
            FilledButton.icon(
              onPressed: _showAddDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Thêm'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                textStyle: const TextStyle(fontSize: 13),
              ),
            ),
          ]),
        ),
        const Divider(height: 1),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.info.withAlpha(15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.info.withAlpha(40)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: AppColors.info),
              SizedBox(width: 8),
              Expanded(child: Text(
                'Thiết lập ngưỡng an toàn & tối ưu cho các thông số nước. Giá trị ngoài mức an toàn sẽ kích hoạt cảnh báo.',
                style: TextStyle(fontSize: 12, color: AppColors.info),
              )),
            ],
          ),
        ),
        Expanded(
          child: standards.isEmpty
              ? const Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.water_drop_outlined, size: 48, color: AppColors.textHint),
                    SizedBox(height: 8),
                    Text('Chưa có thông số nào', style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: standards.length,
                  itemBuilder: (_, i) {
                    final ws = standards[i];
                    final color = _paramColors[ws.paramKey] ?? AppColors.primary;
                    final icon = _paramIcons[ws.paramKey] ?? Icons.water_drop;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.borderRadius)),
                      elevation: ws.isActive ? 1 : 0,
                      color: ws.isActive ? null : AppColors.surfaceVariant,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _showEditDialog(ws),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: color.withAlpha(ws.isActive ? 25 : 10),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(icon, color: ws.isActive ? color : AppColors.textHint, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Text(ws.name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: ws.isActive ? AppColors.textPrimary : AppColors.textHint)),
                                      if (ws.unit.isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
                                          child: Text(ws.unit, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                        ),
                                      ],
                                    ]),
                                    if (!ws.isActive)
                                      const Text('Đã tắt', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
                                  ],
                                )),
                                Icon(Icons.edit_outlined, size: 18, color: AppColors.textHint),
                              ]),
                              if (ws.isActive) ...[
                                const SizedBox(height: 12),
                                _RangeBar(
                                  label: 'An toàn',
                                  min: ws.safeMin,
                                  max: ws.safeMax,
                                  color: AppColors.warning,
                                  unit: ws.unit,
                                ),
                                const SizedBox(height: 6),
                                _RangeBar(
                                  label: 'Tối ưu',
                                  min: ws.optimalMin,
                                  max: ws.optimalMax,
                                  color: AppColors.success,
                                  unit: ws.unit,
                                ),
                              ],
                              if (ws.note.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(ws.note, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _RangeBar extends StatelessWidget {
  final String label;
  final double min;
  final double max;
  final Color color;
  final String unit;
  const _RangeBar({required this.label, required this.min, required this.max, required this.color, required this.unit});

  @override
  Widget build(BuildContext context) {
    final fmt = max >= 100 ? NumberFormat('#,##0', 'vi') : NumberFormat('#,##0.##', 'vi');
    return Row(children: [
      SizedBox(
        width: 60,
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ),
      Expanded(
        child: Container(
          height: 8,
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: 1.0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color.withAlpha(80), color]),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Text('${fmt.format(min)} – ${fmt.format(max)}${unit.isNotEmpty ? ' $unit' : ''}',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    ]);
  }
}
