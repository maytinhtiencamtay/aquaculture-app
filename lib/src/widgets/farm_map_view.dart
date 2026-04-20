import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/pond.dart';
import '../models/fish_batch.dart';
import '../models/species.dart';
import '../models/sensor_reading.dart';
import '../models/employee.dart';
import '../models/disease_log.dart';
import '../models/treatment_log.dart';
import '../models/feeding_schedule.dart';
import '../models/equipment.dart';
import '../models/daily_log.dart';
import '../models/water_change_log.dart';
import '../models/size_measurement.dart';
import '../providers/data_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

// ═════════════════════════════════════════════════════════════════════════════
// FARM MAP VIEW – Interactive 2D layout of branches → zones → ponds
// ═════════════════════════════════════════════════════════════════════════════

final _currFmt = NumberFormat('#,###', 'vi');
String _smartQty(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// Evaluate water quality for a pond against its species requirements
_WaterQuality _evaluateWater(Pond pond, DataProvider dp) {
  final batches = dp.batchesForPond(pond.id).where((b) => b.status == 'active');
  Species? sp;
  for (final b in batches) {
    sp = dp.speciesById(b.speciesId);
    if (sp != null) break;
  }

  int warnings = 0;
  int dangers = 0;
  final issues = <String>[];

  if (pond.currentPh != null) {
    final ph = pond.currentPh!;
    final optPh = sp?.requiredPh ?? 7.0;
    if ((ph - optPh).abs() > 1.5) { dangers++; issues.add('pH $ph'); }
    else if ((ph - optPh).abs() > 0.8) { warnings++; issues.add('pH $ph'); }
  }
  if (pond.currentDo != null) {
    final doVal = pond.currentDo!;
    final minDo = sp?.requiredDo ?? 4.0;
    if (doVal < minDo * 0.6) { dangers++; issues.add('DO ${doVal.toStringAsFixed(1)}'); }
    else if (doVal < minDo) { warnings++; issues.add('DO ${doVal.toStringAsFixed(1)}'); }
  }
  if (pond.currentNh3 != null) {
    final nh3 = pond.currentNh3!;
    final maxNh3 = sp?.maxNh3 ?? 0.1;
    if (nh3 > maxNh3 * 2) { dangers++; issues.add('NH₃ ${nh3.toStringAsFixed(3)}'); }
    else if (nh3 > maxNh3) { warnings++; issues.add('NH₃ ${nh3.toStringAsFixed(3)}'); }
  }
  if (pond.currentTemp != null && sp != null) {
    final t = pond.currentTemp!;
    if (t < sp.minTemp || t > sp.maxTemp) { dangers++; issues.add('${t.toStringAsFixed(1)}°C'); }
    else if ((t - sp.requiredTemp).abs() > 3) { warnings++; issues.add('${t.toStringAsFixed(1)}°C'); }
  }

  if (dangers > 0) return _WaterQuality.danger(issues);
  if (warnings > 0) return _WaterQuality.warning(issues);
  return _WaterQuality.good([]);
}

enum _WQLevel { good, warning, danger }

class _WaterQuality {
  final _WQLevel level;
  final List<String> issues;
  const _WaterQuality._(this.level, this.issues);
  factory _WaterQuality.good(List<String> i) => _WaterQuality._(_WQLevel.good, i);
  factory _WaterQuality.warning(List<String> i) => _WaterQuality._(_WQLevel.warning, i);
  factory _WaterQuality.danger(List<String> i) => _WaterQuality._(_WQLevel.danger, i);

  Color get color {
    switch (level) {
      case _WQLevel.good: return AppColors.success;
      case _WQLevel.warning: return AppColors.warning;
      case _WQLevel.danger: return AppColors.error;
    }
  }

  IconData get icon {
    switch (level) {
      case _WQLevel.good: return Icons.check_circle_rounded;
      case _WQLevel.warning: return Icons.warning_rounded;
      case _WQLevel.danger: return Icons.error_rounded;
    }
  }

  String get label {
    switch (level) {
      case _WQLevel.good: return 'Tốt';
      case _WQLevel.warning: return 'Cảnh báo';
      case _WQLevel.danger: return 'Nguy hiểm';
    }
  }
}

class FarmMapView extends StatefulWidget {
  final DataProvider dp;
  const FarmMapView({super.key, required this.dp});
  @override
  State<FarmMapView> createState() => _FarmMapViewState();
}

class _FarmMapViewState extends State<FarmMapView> {
  String? _selectedBranchId;
  String? _selectedZoneId;
  bool _isArrangeMode = false;
  String _statusFilter = 'all'; // all, active, inactive, maintenance
  // Local position overrides while dragging (before save)
  final Map<String, Offset> _dragOffsets = {};

  DataProvider get dp => widget.dp;

  @override
  void didUpdateWidget(FarmMapView old) {
    super.didUpdateWidget(old);
    // Auto-select first branch if none selected
    if (_selectedBranchId == null && dp.branches.isNotEmpty) {
      _selectedBranchId = dp.branches.first.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<DataProvider>();
    if (dp.branches.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_rounded, size: 64, color: AppColors.textHint),
            SizedBox(height: 12),
            Text('Chưa có dữ liệu chi nhánh', style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
          ],
        ),
      );
    }

    _selectedBranchId ??= dp.branches.first.id;

    // Initialize zone synchronously to avoid blank frame
    if (_selectedZoneId == null) {
      final zones = dp.zonesForBranch(_selectedBranchId!);
      if (zones.isNotEmpty) {
        _selectedZoneId = '__all__';
      }
    }

    return Column(
      children: [
        _buildBranchSelector(),
        if (_selectedBranchId != null) _buildBranchStats(),
        const SizedBox(height: 4),
        if (_selectedBranchId != null) _buildZoneTabs(),
        const SizedBox(height: 4),
        if (_selectedZoneId != null && _selectedZoneId!.isNotEmpty) _buildStatusFilter(),
        const SizedBox(height: 4),
        Expanded(child: _buildMapArea()),
      ],
    );
  }

  Widget _buildBranchSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ...dp.branches.map((b) {
              final sel = b.id == _selectedBranchId;
              final zoneCount = dp.zonesForBranch(b.id).length;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: sel ? AppColors.primary : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() {
                      _selectedBranchId = b.id;
                      _selectedZoneId = '__all__';
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          Icon(Icons.business_rounded, size: 18, color: sel ? Colors.white : AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Text(b.name, style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: sel ? Colors.white : AppColors.textPrimary,
                            fontSize: 14,
                          )),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: sel ? Colors.white.withAlpha(40) : AppColors.primary.withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('$zoneCount khu', style: TextStyle(fontSize: 11, color: sel ? Colors.white70 : AppColors.primary)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(width: 16),
            // Legend
            _LegendDot(AppColors.success, 'Đang nuôi'),
            const SizedBox(width: 8),
            _LegendDot(AppColors.textHint, 'Trống'),
            const SizedBox(width: 8),
            _LegendDot(AppColors.warning, 'Bảo trì'),
          ],
        ),
      ),
    );
  }

  /// Branch-level stats bar (all ponds in the selected branch)
  Widget _buildBranchStats() {
    if (_selectedBranchId == null) return const SizedBox.shrink();
    final zones = dp.zonesForBranch(_selectedBranchId!);
    final ponds = zones.expand((z) => dp.pondsForZone(z.id)).toList();
    final active = ponds.where((p) => p.status == 'active').length;
    final empty = ponds.where((p) => p.status == 'inactive').length;
    final maint = ponds.where((p) => p.status == 'maintenance').length;
    final totalArea = ponds.fold<double>(0, (s, p) => s + p.area);
    int totalFish = 0;
    int alertCount = 0;
    for (final p in ponds) {
      final batches = dp.batchesForPond(p.id).where((b) => b.status == 'active');
      totalFish += batches.fold<int>(0, (s, b) => s + b.quantityInPond(p.id));
      if (p.status == 'active') {
        final wq = _evaluateWater(p, dp);
        if (wq.level != _WQLevel.good) alertCount++;
      }
      final overdue = dp.tasksForPond(p.id).where((t) => t.status == 'pending' && t.isOverdue).length;
      if (overdue > 0) alertCount++;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _StatChip(Icons.water_rounded, '${ponds.length}', 'Ao nuôi', AppColors.primary),
          const SizedBox(width: 6),
          _StatChip(Icons.play_circle_filled_rounded, '$active', 'Đang nuôi', AppColors.success),
          const SizedBox(width: 6),
          _StatChip(Icons.pause_circle_rounded, '$empty', 'Trống', AppColors.textHint),
          const SizedBox(width: 6),
          _StatChip(Icons.build_circle_rounded, '$maint', 'Bảo trì', AppColors.warning),
          const SizedBox(width: 6),
          _StatChip(Icons.set_meal_rounded, _currFmt.format(totalFish), 'Cá', AppColors.info),
          const SizedBox(width: 6),
          _StatChip(Icons.straighten_rounded, '${totalArea.toStringAsFixed(0)}m²', 'Diện tích', AppColors.secondary),
          if (alertCount > 0) ...[
            const SizedBox(width: 6),
            _StatChip(Icons.notification_important_rounded, '$alertCount', 'Cảnh báo', AppColors.error),
          ],
          const SizedBox(width: 12),
          ActionChip(
            avatar: const Icon(Icons.restaurant_menu_rounded, size: 18, color: AppColors.success),
            label: const Text('Dự trù thức ăn', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            backgroundColor: AppColors.success.withAlpha(20),
            side: BorderSide(color: AppColors.success.withAlpha(60)),
            onPressed: () => _showFeedPlanningDialog(),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneTabs() {
    final zones = dp.zonesForBranch(_selectedBranchId!);
    if (zones.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Chi nhánh chưa có phân khu', style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    if (_selectedZoneId == null || (_selectedZoneId != '__all__' && !zones.any((zn) => zn.id == _selectedZoneId))) {
      _selectedZoneId = '__all__';
    }
    // Total ponds in this branch
    final totalPondCount = zones.fold<int>(0, (sum, z) => sum + dp.pondsForZone(z.id).length);
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: zones.length + 1, // +1 for "Tất cả"
        itemBuilder: (_, i) {
          // First item: "Tất cả"
          if (i == 0) {
            final sel = _selectedZoneId == '__all__';
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _selectedZoneId = '__all__'),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.secondary : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? AppColors.secondary : AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.grid_view_rounded, size: 16, color: sel ? Colors.white : AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text('Tất cả ($totalPondCount ao)', style: TextStyle(
                        fontSize: 13,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                        color: sel ? Colors.white : AppColors.textPrimary,
                      )),
                    ],
                  ),
                ),
              ),
            );
          }
          final zn = zones[i - 1];
          final sel = zn.id == _selectedZoneId;
          final pondCount = dp.pondsForZone(zn.id).length;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedZoneId = zn.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: sel ? AppColors.secondary : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? AppColors.secondary : AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(_zoneIcon(zn.type), size: 16, color: sel ? Colors.white : AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text('${zn.name} ($pondCount ao)', style: TextStyle(
                      fontSize: 13,
                      fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                      color: sel ? Colors.white : AppColors.textPrimary,
                    )),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _zoneIcon(String type) {
    switch (type) {
      case 'farming': return Icons.grass_rounded;
      case 'treatment': return Icons.science_rounded;
      case 'logistics': return Icons.local_shipping_rounded;
      default: return Icons.grid_view;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STATUS FILTER
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildStatusFilter() {
    const filters = [
      ('all', 'Tất cả', Icons.grid_view_rounded),
      ('active', 'Đang nuôi', Icons.play_circle_rounded),
      ('inactive', 'Trống', Icons.pause_circle_rounded),
      ('maintenance', 'Bảo trì', Icons.build_circle_rounded),
      ('transfer', 'Cần chuyển ao', Icons.swap_horiz_rounded),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 34,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: filters.map((f) {
            final sel = _statusFilter == f.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Material(
                color: sel ? AppColors.primary.withAlpha(20) : Colors.transparent,
                borderRadius: BorderRadius.circular(17),
                child: InkWell(
                  borderRadius: BorderRadius.circular(17),
                  onTap: () => setState(() => _statusFilter = f.$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: sel ? AppColors.primary : AppColors.border, width: sel ? 1.5 : 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(f.$3, size: 14, color: sel ? AppColors.primary : AppColors.textHint),
                        const SizedBox(width: 4),
                        Text(f.$2, style: TextStyle(
                          fontSize: 12,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                          color: sel ? AppColors.primary : AppColors.textSecondary,
                        )),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMapArea() {
    if (_selectedZoneId == null) return const SizedBox.shrink();

    // "Tất cả" mode: show all ponds from all zones grouped by zone
    if (_selectedZoneId == '__all__') {
      return _buildAllZonesMap();
    }

    final allPonds = dp.pondsForZone(_selectedZoneId!);
    final ponds = _statusFilter == 'all'
        ? allPonds
        : _statusFilter == 'transfer'
            ? allPonds.where((p) => dp.tasks.any((t) => t.type == 'transfer' && t.status == 'pending' && t.pondId == p.id)).toList()
            : allPonds.where((p) => p.status == _statusFilter).toList();
    final zone = dp.zoneById(_selectedZoneId!);

    if (allPonds.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.water_rounded, size: 64, color: AppColors.textHint.withAlpha(80)),
            const SizedBox(height: 12),
            const Text('Phân khu chưa có ao', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    if (ponds.isEmpty) {
      final filterLabels = {'active': 'Đang nuôi', 'inactive': 'Trống', 'maintenance': 'Bảo trì'};
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_list_off_rounded, size: 48, color: AppColors.textHint.withAlpha(80)),
            const SizedBox(height: 8),
            Text('Không có ao "${filterLabels[_statusFilter] ?? _statusFilter}"', style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9), // Green grass background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Grid background pattern
            CustomPaint(
              size: Size.infinite,
              painter: _GridPainter(),
            ),
            // Water channel decoration (horizontal)
            Positioned(
              top: 50,
              left: 0,
              right: 0,
              child: Container(
                height: 12,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF81D4FA).withAlpha(60),
                      const Color(0xFF4FC3F7).withAlpha(100),
                      const Color(0xFF81D4FA).withAlpha(60),
                    ],
                  ),
                ),
              ),
            ),
            // Ponds area
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 70, 16, 16),
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  final w = constraints.maxWidth;
                  final h = constraints.maxHeight;
                  final cols = w > 800 ? 5 : (w > 500 ? 4 : (w > 350 ? 3 : 2));
                  final spacing = 14.0;
                  final cellW = (w - spacing * (cols - 1)) / cols;
                  final cellH = cellW * 1.05;

                  if (_isArrangeMode) {
                    // === FREE POSITION MODE (drag-and-drop) ===
                    return Stack(
                      clipBehavior: Clip.none,
                      children: ponds.asMap().entries.map((entry) {
                        final i = entry.key;
                        final p = entry.value;

                        // Use drag offset > saved mapX/mapY > auto-grid position
                        final autoX = (i % cols) * (cellW + spacing);
                        final autoY = (i ~/ cols) * (cellH + spacing);
                        final savedX = p.mapX ?? autoX;
                        final savedY = p.mapY ?? autoY;
                        final offset = _dragOffsets[p.id] ?? Offset(savedX, savedY);

                        // Clamp within bounds
                        final clampedX = offset.dx.clamp(0.0, (w - cellW).clamp(0.0, double.infinity));
                        final clampedY = offset.dy.clamp(0.0, (h - cellH).clamp(0.0, double.infinity));

                        return Positioned(
                          left: clampedX,
                          top: clampedY,
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              setState(() {
                                final prev = _dragOffsets[p.id] ?? Offset(savedX, savedY);
                                _dragOffsets[p.id] = Offset(
                                  (prev.dx + details.delta.dx).clamp(0.0, (w - cellW).clamp(0.0, double.infinity)),
                                  (prev.dy + details.delta.dy).clamp(0.0, (h - cellH).clamp(0.0, double.infinity)),
                                );
                              });
                            },
                            child: SizedBox(
                              width: cellW,
                              height: cellH,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  _PondCell(
                                    pond: p,
                                    dp: dp,
                                    onTap: () {}, // Disable tap in arrange mode
                                  ),
                                  // Drag handle overlay
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withAlpha(20),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppColors.primary.withAlpha(120),
                                          width: 2,
                                          strokeAlign: BorderSide.strokeAlignOutside,
                                        ),
                                      ),
                                      child: const Center(
                                        child: Icon(Icons.open_with_rounded, color: Colors.white, size: 30),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  }

                  // === NORMAL MODE (grid wrap) ===
                  // If all ponds have saved positions, show them in free layout
                  final hasPositions = ponds.any((p) => p.mapX != null && p.mapY != null);

                  if (hasPositions) {
                    return Stack(
                      clipBehavior: Clip.none,
                      children: ponds.asMap().entries.map((entry) {
                        final i = entry.key;
                        final p = entry.value;
                        final autoX = (i % cols) * (cellW + spacing);
                        final autoY = (i ~/ cols) * (cellH + spacing);
                        final posX = (p.mapX ?? autoX).clamp(0.0, (w - cellW).clamp(0.0, double.infinity));
                        final posY = (p.mapY ?? autoY).clamp(0.0, (h - cellH).clamp(0.0, double.infinity));

                        return Positioned(
                          left: posX,
                          top: posY,
                          child: SizedBox(
                            width: cellW,
                            height: cellH,
                            child: _PondCell(
                              pond: p,
                              dp: dp,
                              onTap: () => _showPondActions(p),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  }

                  // Default: Wrap grid layout
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: ponds.map((p) {
                      return SizedBox(
                        width: cellW,
                        height: cellH,
                        child: _PondCell(
                          pond: p,
                          dp: dp,
                          onTap: () => _showPondActions(p),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),

            // Zone label + arrange toggle (on top of everything)
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_zoneIcon(zone?.type ?? ''), size: 16, color: AppColors.secondary),
                        const SizedBox(width: 6),
                        Text(zone?.name ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(width: 8),
                        Text('${ponds.length} ao', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Arrange mode toggle
                  Material(
                    color: _isArrangeMode ? AppColors.primary : Colors.white.withAlpha(200),
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        if (_isArrangeMode) {
                          _saveAllPositions(ponds);
                        }
                        setState(() {
                          _isArrangeMode = !_isArrangeMode;
                          if (!_isArrangeMode) _dragOffsets.clear();
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isArrangeMode ? Icons.check_rounded : Icons.open_with_rounded,
                              size: 16,
                              color: _isArrangeMode ? Colors.white : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isArrangeMode ? 'Lưu vị trí' : 'Sắp xếp',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _isArrangeMode ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Arrange mode hint bar
            if (_isArrangeMode)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.primary.withAlpha(0),
                        AppColors.primary.withAlpha(30),
                      ],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline, size: 16, color: AppColors.primary.withAlpha(180)),
                      const SizedBox(width: 8),
                      Text(
                        'Kéo ao đến vị trí mong muốn, sau đó nhấn "Lưu vị trí"',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.primary.withAlpha(200),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Build a scrollable view showing ALL zones' ponds when "Tất cả" is selected
  Widget _buildAllZonesMap() {
    final zones = dp.zonesForBranch(_selectedBranchId!);
    if (zones.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.water_rounded, size: 64, color: AppColors.textHint.withAlpha(80)),
            const SizedBox(height: 12),
            const Text('Chi nhánh chưa có phân khu', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: zones.length,
      itemBuilder: (ctx, zoneIndex) {
        final zone = zones[zoneIndex];
        final allPonds = dp.pondsForZone(zone.id);
        final ponds = _statusFilter == 'all'
            ? allPonds
            : _statusFilter == 'transfer'
                ? allPonds.where((p) => dp.tasks.any((t) => t.type == 'transfer' && t.status == 'pending' && t.pondId == p.id)).toList()
                : allPonds.where((p) => p.status == _statusFilter).toList();

        return Container(
          margin: EdgeInsets.only(bottom: zoneIndex < zones.length - 1 ? 12 : 0),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Zone header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_zoneIcon(zone.type), size: 16, color: AppColors.secondary),
                          const SizedBox(width: 6),
                          Text(zone.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          const SizedBox(width: 8),
                          Text('${allPonds.length} ao', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Ponds grid
              if (ponds.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    allPonds.isEmpty ? 'Chưa có ao' : 'Không có ao phù hợp bộ lọc',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: LayoutBuilder(
                    builder: (ctx, constraints) {
                      final w = constraints.maxWidth;
                      final cols = w > 800 ? 5 : (w > 500 ? 4 : (w > 350 ? 3 : 2));
                      const spacing = 14.0;
                      final cellW = (w - spacing * (cols - 1)) / cols;
                      final cellH = cellW * 1.05;

                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: ponds.map((p) {
                          return SizedBox(
                            width: cellW,
                            height: cellH,
                            child: _PondCell(
                              pond: p,
                              dp: dp,
                              onTap: () => _showPondActions(p),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveAllPositions(List<Pond> ponds) async {
    for (final p in ponds) {
      final offset = _dragOffsets[p.id];
      if (offset != null) {
        await dp.update('ponds', p.id, {
          ...p.toJson(),
          'mapX': offset.dx,
          'mapY': offset.dy,
        });
      }
    }
    if (_dragOffsets.isNotEmpty) {
      _showSnack('Đã lưu vị trí ${_dragOffsets.length} ao');
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // POND ACTION BOTTOM SHEET
  // ═════════════════════════════════════════════════════════════════════════

  void _showPondActions(Pond pond) {
    final batches = dp.batchesForPond(pond.id);
    final activeBatches = batches.where((b) => b.status == 'active').toList();
    final pendingTasks = dp.tasksForPond(pond.id).where((t) => t.status == 'pending').toList();
    final overdueTasks = pendingTasks.where((t) => t.isOverdue).toList();
    final wq = _evaluateWater(pond, dp);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.78,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (ctx, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(ctx).copyWith(
              dragDevices: {
                ui.PointerDeviceKind.touch,
                ui.PointerDeviceKind.mouse,
                ui.PointerDeviceKind.trackpad,
              },
            ),
            child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.all(20),
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),

              // ── Pond header ──
              Row(
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: _pondStatusColor(pond.status),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.water_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pond.code, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                        Text('${pond.typeLabel} • ${pond.area}m² • ${pond.volume}m³ • sâu ${pond.depth}m',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                  _StatusBadge(pond.statusLabel, _pondStatusColor(pond.status)),
                ],
              ),
              const SizedBox(height: 16),

              // ── Water quality card ──
              Builder(builder: (_) {
                // Find species for threshold display
                Species? sp;
                for (final b in activeBatches) {
                  sp = dp.speciesById(b.speciesId);
                  if (sp != null) break;
                }
                final measurer = pond.measuredBy.isNotEmpty
                    ? dp.employees.where((e) => e.id == pond.measuredBy).firstOrNull
                    : null;
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: wq.color.withAlpha(10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: wq.color.withAlpha(40)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(wq.icon, size: 18, color: wq.color),
                          const SizedBox(width: 6),
                          Text('Chất lượng nước: ${wq.label}', style: TextStyle(fontWeight: FontWeight.w700, color: wq.color, fontSize: 14)),
                          if (wq.issues.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Flexible(child: Text(wq.issues.join(' • '), style: TextStyle(fontSize: 11, color: wq.color.withAlpha(180)), overflow: TextOverflow.ellipsis)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Measured info row
                      Row(
                        children: [
                          if (measurer != null) ...[
                            Icon(Icons.person_outline, size: 13, color: AppColors.textHint),
                            const SizedBox(width: 3),
                            Text('Người đo: ${measurer.name}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            const SizedBox(width: 12),
                          ],
                          if (pond.updatedAt != null) ...[
                            Icon(Icons.access_time, size: 13, color: AppColors.textHint),
                            const SizedBox(width: 3),
                            Text(DateFormat('dd/MM/yyyy HH:mm').format(pond.updatedAt!),
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _WaterParam('pH', pond.currentPh?.toStringAsFixed(1) ?? '—', Icons.opacity),
                          _WaterParam('DO', pond.currentDo != null ? pond.currentDo!.toStringAsFixed(1) : '—', Icons.air),
                          _WaterParam('NH₃', pond.currentNh3 != null ? pond.currentNh3!.toStringAsFixed(2) : '—', Icons.science),
                          _WaterParam('Nhiệt', pond.currentTemp != null ? '${pond.currentTemp!.toStringAsFixed(1)}°' : '—', Icons.thermostat),
                          _WaterParam('Kiềm', pond.currentAlkalinity != null ? pond.currentAlkalinity!.toStringAsFixed(0) : '—', Icons.waves),
                        ],
                      ),
                      // Species thresholds reference
                      if (sp != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.pets, size: 13, color: AppColors.textHint),
                              const SizedBox(width: 4),
                              Text('${sp.name}: ', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                              Flexible(
                                child: Text(
                                  'pH ${sp.requiredPh} • DO ≥${sp.requiredDo} • NH₃ <${sp.maxNh3} • ${sp.minTemp}–${sp.maxTemp}°C',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),

              // ── Active batches with detailed info ──
              if (activeBatches.isNotEmpty) ...[
                const Text('Lô cá đang nuôi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ...activeBatches.map((b) {
                  final sp = dp.speciesById(b.speciesId);
                  final days = b.daysOfCulture;
                  final growthDays = sp?.growthDays ?? 180;
                  final progress = (days / growthDays).clamp(0.0, 1.0);
                  final daysLeft = growthDays - days;
                  final survivalPct = b.survivalRate;
                  final fcrVal = b.fcr;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border.withAlpha(60)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Species + quantity
                        Row(
                          children: [
                            const Icon(Icons.set_meal_rounded, color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(sp?.name ?? 'Loài #${b.speciesId}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withAlpha(15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('${_currFmt.format(b.quantityInPond(pond.id))} con', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.primary)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Stats grid
                        Row(
                          children: [
                            _BatchStat('Ngày nuôi', '$days', daysLeft > 0 ? 'còn $daysLeft ngày' : 'Sẵn sàng TH'),
                            _BatchStat('Kích cỡ', '${(b.currentWeight > 0 ? b.currentWeight : b.initialWeight).toStringAsFixed(0)}g', '${(b.currentSize > 0 ? b.currentSize : b.initialSize).toStringAsFixed(1)}cm'),
                            _BatchStat('Sống sót', '${survivalPct.toStringAsFixed(1)}%', 'hao ${b.mortalityQuantity}'),
                            if (fcrVal > 0) _BatchStat('FCR', fcrVal.toStringAsFixed(2), '${b.feedConsumed.toStringAsFixed(0)}kg TA'),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Growth progress bar
                        Row(
                          children: [
                            const Text('Tiến trình: ', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 8,
                                  backgroundColor: AppColors.border.withAlpha(40),
                                  valueColor: AlwaysStoppedAnimation(
                                    progress >= 1.0 ? AppColors.success : (progress > 0.7 ? AppColors.secondary : AppColors.primary),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text('${(progress * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        if (b.expectedHarvestDate != null) ...[
                          const SizedBox(height: 4),
                          Text('Thu hoạch dự kiến: ${DateFormat('dd/MM/yyyy').format(b.expectedHarvestDate!)}',
                              style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                        ],
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 4),
              ],

              // ── Alerts section ──
              if (overdueTasks.isNotEmpty || wq.level == _WQLevel.danger) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withAlpha(10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.error.withAlpha(30)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.notification_important_rounded, size: 16, color: AppColors.error),
                          const SizedBox(width: 6),
                          const Text('Cảnh báo', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.error, fontSize: 13)),
                        ],
                      ),
                      if (wq.level == _WQLevel.danger) ...[
                        const SizedBox(height: 6),
                        Text('• Chất lượng nước nguy hiểm: ${wq.issues.join(', ')}',
                            style: const TextStyle(fontSize: 12, color: AppColors.error)),
                      ],
                      ...overdueTasks.map((t) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('• Quá hạn: ${t.title}', style: const TextStyle(fontSize: 12, color: AppColors.error)),
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // ── Pending tasks ──
              if (pendingTasks.isNotEmpty) ...[
                Text('Công việc chờ (${pendingTasks.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ...pendingTasks.take(5).map((t) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: (t.isOverdue ? AppColors.error : AppColors.warning).withAlpha(10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(t.isOverdue ? Icons.warning_rounded : Icons.schedule, size: 16,
                          color: t.isOverdue ? AppColors.error : AppColors.warning),
                      const SizedBox(width: 8),
                      Expanded(child: Text(t.title, style: const TextStyle(fontSize: 13))),
                      if (t.isOverdue)
                        Text('Quá hạn', style: TextStyle(fontSize: 10, color: AppColors.error, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )),
                const SizedBox(height: 8),
              ],

              // ── Tiến độ bảo trì ──
              Builder(builder: (_) {
                final activeLog = dp.activeMaintenanceForPond(pond.id);
                if (activeLog == null) return const SizedBox.shrink();
                final items = List<Map<String, dynamic>>.from(activeLog['items'] ?? []);
                final doneItems = items.where((it) => it['status'] == 'done').length;
                final prog = items.isNotEmpty ? doneItems / items.length : 0.0;
                final materials = List<Map<String, dynamic>>.from(activeLog['materials'] ?? []);
                final startDate = activeLog['startedAt'] != null ? DateTime.tryParse(activeLog['startedAt']) : null;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withAlpha(12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warning.withAlpha(40)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.engineering_rounded, size: 18, color: AppColors.warning),
                          const SizedBox(width: 8),
                          const Text('Đang bảo trì', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.warning)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: prog >= 1.0 ? AppColors.success : AppColors.warning,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('${(prog * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: prog,
                          minHeight: 8,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation(prog >= 1.0 ? AppColors.success : AppColors.warning),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('$doneItems / ${items.length} hạng mục${startDate != null ? " • Từ ${startDate.day}/${startDate.month}" : ""}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      ...items.map((it) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Row(
                          children: [
                            Icon(
                              it['status'] == 'done' ? Icons.check_circle : Icons.circle_outlined,
                              size: 16,
                              color: it['status'] == 'done' ? AppColors.success : AppColors.textHint,
                            ),
                            const SizedBox(width: 6),
                            Expanded(child: Text(it['name'] ?? '', style: TextStyle(
                              fontSize: 13,
                              decoration: it['status'] == 'done' ? TextDecoration.lineThrough : null,
                              color: it['status'] == 'done' ? AppColors.textHint : AppColors.textPrimary,
                            ))),
                          ],
                        ),
                      )),
                      if (materials.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text('Vật tư: ${materials.length} loại', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ],
                  ),
                );
              }),

              // ═══ ACTION BUTTONS ═══
              const Text('Thao tác', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),

              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _ActionButton(
                    icon: Icons.set_meal_rounded,
                    label: 'Thả cá',
                    color: AppColors.primary,
                    onTap: () { Navigator.pop(ctx); _showStockFishDialog(pond); },
                  ),
                  _ActionButton(
                    icon: Icons.undo_rounded,
                    label: 'Rút cá',
                    color: const Color(0xFFE65100),
                    enabled: activeBatches.isNotEmpty,
                    onTap: () { Navigator.pop(ctx); _showWithdrawFishDialog(pond, activeBatches); },
                  ),
                  _ActionButton(
                    icon: Icons.swap_horiz_rounded,
                    label: 'Chuyển cá',
                    color: AppColors.info,
                    enabled: activeBatches.isNotEmpty,
                    onTap: () { Navigator.pop(ctx); _showTransferDialog(pond, activeBatches); },
                  ),
                  _ActionButton(
                    icon: Icons.restaurant_rounded,
                    label: 'Cho ăn',
                    color: AppColors.success,
                    enabled: activeBatches.isNotEmpty,
                    onTap: () { Navigator.pop(ctx); _showFeedDialog(pond, activeBatches); },
                  ),
                  _ActionButton(
                    icon: Icons.science_rounded,
                    label: 'Đo nước',
                    color: const Color(0xFF7C4DFF),
                    onTap: () { Navigator.pop(ctx); _showMeasureWaterDialog(pond); },
                  ),
                  _ActionButton(
                    icon: Icons.heart_broken_rounded,
                    label: 'Hao hụt',
                    color: AppColors.error,
                    enabled: activeBatches.isNotEmpty,
                    onTap: () { Navigator.pop(ctx); _showMortalityDialog(pond, activeBatches); },
                  ),
                  _ActionButton(
                    icon: Icons.shopping_bag_rounded,
                    label: 'Xuất bán',
                    color: AppColors.secondary,
                    enabled: activeBatches.isNotEmpty,
                    onTap: () { Navigator.pop(ctx); _showSellDialog(pond, activeBatches); },
                  ),
                  _ActionButton(
                    icon: Icons.build_rounded,
                    label: pond.status == 'maintenance' ? 'Tiến độ BT' : 'Bảo trì',
                    color: AppColors.warning,
                    onTap: () { Navigator.pop(ctx); _showMaintenanceDialog(pond); },
                  ),
                  _ActionButton(
                    icon: Icons.straighten_rounded,
                    label: 'Đo kích thước',
                    color: const Color(0xFF6366F1),
                    enabled: activeBatches.isNotEmpty,
                    onTap: () { Navigator.pop(ctx); _showSizeMeasurementDialog(pond, activeBatches); },
                  ),
                  _ActionButton(
                    icon: Icons.history_rounded,
                    label: 'LS cho ăn',
                    color: const Color(0xFF43A047),
                    onTap: () { Navigator.pop(ctx); _showFeedingHistoryDialog(pond); },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(),
              const Text('Vận hành', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _ActionButton(
                    icon: Icons.coronavirus_rounded,
                    label: 'Ghi bệnh',
                    color: const Color(0xFFE53935),
                    onTap: () { Navigator.pop(ctx); _showQuickDiseaseDialog(pond, activeBatches); },
                  ),
                  _ActionButton(
                    icon: Icons.medical_services_rounded,
                    label: 'Điều trị',
                    color: const Color(0xFF5C6BC0),
                    onTap: () { Navigator.pop(ctx); _showQuickTreatmentDialog(pond); },
                  ),
                  _ActionButton(
                    icon: Icons.water_drop_rounded,
                    label: 'Thay nước',
                    color: const Color(0xFF0097A7),
                    onTap: () { Navigator.pop(ctx); _showQuickWaterChangeDialog(pond); },
                  ),
                  _ActionButton(
                    icon: Icons.edit_note_rounded,
                    label: 'Nhật ký',
                    color: const Color(0xFF6D4C41),
                    onTap: () { Navigator.pop(ctx); _showQuickDailyLogDialog(pond); },
                  ),
                  _ActionButton(
                    icon: Icons.timeline_rounded,
                    label: 'Lịch sử',
                    color: AppColors.primary,
                    onTap: () { Navigator.pop(ctx); _showPondHistoryDialog(pond); },
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // POND FULL HISTORY TIMELINE
  // ═════════════════════════════════════════════════════════════════════════

  void _showPondHistoryDialog(Pond pond) {
    final dateFmt = DateFormat('dd/MM/yyyy');
    final timeFmt = DateFormat('HH:mm');
    final events = _buildOperationsSummaryData(pond);
    if (events.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có lịch sử thao tác nào cho ao này')),
      );
      return;
    }
    _showFullPondHistory(pond.code, events, dateFmt, timeFmt);
  }

  List<_PondTimelineEvent> _buildOperationsSummaryData(Pond pond) {
    final dateFmt = DateFormat('dd/MM/yyyy');
    final timeFmt = DateFormat('HH:mm');
    final currFmt = NumberFormat('#,###', 'vi');

    // Collect ALL events into a unified timeline
    final events = <_PondTimelineEvent>[];

    // 1. Thả cá
    for (final b in dp.fishBatches.where((b) => b.pondId == pond.id)) {
      final sp = dp.speciesById(b.speciesId);
      events.add(_PondTimelineEvent(
        date: b.createdAt,
        icon: Icons.set_meal_rounded,
        color: AppColors.primary,
        title: 'Thả cá: ${b.name}',
        subtitle: '${sp?.name ?? ''} · ${currFmt.format(b.initialQuantity)} con · ${b.initialWeight}g/con',
      ));
    }

    // 2. Đo nước (from sensorReadings history)
    for (final r in dp.sensorReadings.where((r) => r.pondId == pond.id)) {
      final params = <String>[];
      if (r.pH != null) params.add('pH: ${r.pH!.toStringAsFixed(1)}');
      if (r.oxygen != null) params.add('DO: ${r.oxygen!.toStringAsFixed(1)}');
      if (r.temperature != null) params.add('${r.temperature!.toStringAsFixed(1)}°C');
      if (r.nh3 != null) params.add('NH₃: ${r.nh3!.toStringAsFixed(2)}');
      if (r.alkalinity != null) params.add('Kiềm: ${r.alkalinity!.toStringAsFixed(0)}');
      events.add(_PondTimelineEvent(
        date: r.timestamp,
        icon: Icons.science_rounded,
        color: const Color(0xFF7C4DFF),
        title: 'Đo nước',
        subtitle: params.join(' · '),
      ));
    }
    // Fallback: show latest from pond if no sensor readings
    if (dp.sensorReadings.where((r) => r.pondId == pond.id).isEmpty &&
        pond.updatedAt != null && (pond.currentPh != null || pond.currentDo != null || pond.currentTemp != null)) {
      final params = <String>[];
      if (pond.currentPh != null) params.add('pH: ${pond.currentPh!.toStringAsFixed(1)}');
      if (pond.currentDo != null) params.add('DO: ${pond.currentDo!.toStringAsFixed(1)}');
      if (pond.currentTemp != null) params.add('${pond.currentTemp!.toStringAsFixed(1)}°C');
      if (pond.currentNh3 != null) params.add('NH₃: ${pond.currentNh3!.toStringAsFixed(2)}');
      if (pond.currentAlkalinity != null) params.add('Kiềm: ${pond.currentAlkalinity!.toStringAsFixed(0)}');
      events.add(_PondTimelineEvent(
        date: pond.updatedAt!,
        icon: Icons.science_rounded,
        color: const Color(0xFF7C4DFF),
        title: 'Đo nước',
        subtitle: params.join(' · '),
      ));
    }

    // 3. Cho ăn
    for (final log in dp.feedingLogs.where((l) => l['pondId'] == pond.id)) {
      final date = DateTime.tryParse(log['date'] as String? ?? '');
      if (date == null) continue;
      final qty = (log['quantity'] as num?)?.toDouble() ?? 0;
      final unit = log['unit'] as String? ?? 'kg';
      final pName = log['productName'] as String? ?? 'Thức ăn';
      events.add(_PondTimelineEvent(
        date: date,
        icon: Icons.restaurant_rounded,
        color: AppColors.success,
        title: 'Cho ăn: $pName',
        subtitle: '${qty.toStringAsFixed(1)} $unit',
      ));
    }

    // 4. Dịch bệnh
    for (final d in dp.diseaseLogs.where((d) => d.pondId == pond.id)) {
      final statusLabel = {'detected': 'Phát hiện', 'treating': 'Đang trị', 'resolved': 'Đã khỏi', 'recurring': 'Tái phát'}[d.status] ?? d.status;
      events.add(_PondTimelineEvent(
        date: d.detectedDate,
        icon: Icons.coronavirus_rounded,
        color: d.status == 'resolved' ? AppColors.success : AppColors.error,
        title: 'Bệnh: ${d.diseaseName}',
        subtitle: '$statusLabel${d.affectedQuantity > 0 ? ' · ${d.affectedQuantity} con' : ''}${d.symptoms.isNotEmpty ? '\n${d.symptoms}' : ''}',
      ));
    }

    // 5. Thay nước
    for (final w in dp.waterChangeLogs.where((w) => w.pondId == pond.id)) {
      final reasonLabel = {'routine': 'Định kỳ', 'emergency': 'Khẩn cấp', 'treatment': 'Xử lý', 'pre_stocking': 'Trước thả giống'}[w.reason] ?? w.reason;
      events.add(_PondTimelineEvent(
        date: w.date,
        icon: Icons.water_drop_rounded,
        color: AppColors.info,
        title: 'Thay nước ${w.percentChanged.toStringAsFixed(0)}%',
        subtitle: '$reasonLabel${w.volumeChanged > 0 ? ' · ${w.volumeChanged.toStringAsFixed(1)} m³' : ''}${w.incomingPh != null ? ' · pH ${w.incomingPh}' : ''}${w.incomingTemp != null ? ' · ${w.incomingTemp}°C' : ''}',
      ));
    }

    // 6. Điều trị
    for (final t in dp.treatmentLogs.where((t) => t.pondId == pond.id)) {
      final statusLabel = {'in_progress': 'Đang trị', 'completed': 'Hoàn tất', 'cancelled': 'Huỷ'}[t.status] ?? t.status;
      final methodLabel = {'bath': 'Tắm', 'feed_mix': 'Trộn TĂ', 'splash': 'Tát', 'inject': 'Tiêm'}[t.method] ?? t.method;
      events.add(_PondTimelineEvent(
        date: t.startDate,
        icon: Icons.medical_services_rounded,
        color: const Color(0xFF5C6BC0),
        title: 'Điều trị: ${t.medicineName}',
        subtitle: '$statusLabel · $methodLabel · ${t.dosage} ${t.dosageUnit} · ${t.durationDays} ngày${t.isWithdrawalActive ? '\n⚠ Cách ly đến ${t.safeHarvestDate != null ? dateFmt.format(t.safeHarvestDate!) : '?'}' : ''}',
      ));
    }

    // 7. Bảo trì
    for (final log in dp.maintenanceLogs.where((l) => l['pondId'] == pond.id)) {
      final date = DateTime.tryParse(log['startedAt'] as String? ?? log['createdAt'] as String? ?? '');
      if (date == null) continue;
      final status = log['status'] as String? ?? '';
      final statusLabel = {'in_progress': 'Đang làm', 'completed': 'Hoàn tất', 'cancelled': 'Huỷ'}[status] ?? status;
      events.add(_PondTimelineEvent(
        date: date,
        icon: Icons.build_rounded,
        color: AppColors.warning,
        title: 'Bảo trì ao',
        subtitle: statusLabel,
      ));
    }

    // 8. Hao hụt
    for (final log in dp.mortalityLogs.where((l) => l['pondId'] == pond.id)) {
      final date = DateTime.tryParse(log['date'] as String? ?? '');
      if (date == null) continue;
      final qty = (log['quantity'] as num?)?.toInt() ?? 0;
      final cause = log['cause'] as String? ?? 'Không rõ';
      events.add(_PondTimelineEvent(
        date: date,
        icon: Icons.heart_broken_rounded,
        color: AppColors.error,
        title: 'Hao hụt: $qty con',
        subtitle: cause,
      ));
    }

    // 9. Xuất bán
    for (final so in dp.saleOrders) {
      // Match by pondId (primary) or by fishBatchId matching pond's batches
      bool relevant = so.pondId == pond.id;
      if (!relevant) {
        for (final b in dp.fishBatches.where((b) => b.pondId == pond.id)) {
          if (so.fishBatchId == b.id || so.items.any((it) => it['fishBatchId'] == b.id)) {
            relevant = true;
            break;
          }
        }
      }
      if (!relevant) continue;
      final customer = dp.customers.where((c) => c.id == so.customerId).firstOrNull;
      final totalQty = so.items.fold<int>(0, (s, it) => s + ((it['qty'] as num?)?.toInt() ?? (it['quantity'] as num?)?.toInt() ?? 0));
      events.add(_PondTimelineEvent(
        date: so.createdAt,
        icon: Icons.shopping_bag_rounded,
        color: AppColors.secondary,
        title: 'Xuất bán${totalQty > 0 ? ': $totalQty con' : ''}',
        subtitle: '${customer?.name ?? 'Khách lẻ'} · ${currFmt.format(so.totalAmount)}đ',
      ));
    }

    // 10. Chuyển cá (transfers referencing this pond)
    for (final t in dp.tasks.where((t) => t.type == 'transfer' && t.pondId == pond.id)) {
      events.add(_PondTimelineEvent(
        date: t.dueDate,
        icon: Icons.swap_horiz_rounded,
        color: AppColors.info,
        title: 'Chuyển cá',
        subtitle: t.title,
      ));
    }

    // 11. Nhật ký
    for (final d in dp.dailyLogs.where((d) => d.pondId == pond.id)) {
      final weatherLbl = {'sunny': '☀️', 'cloudy': '☁️', 'rainy': '🌧️', 'stormy': '⛈️'}[d.weather] ?? '';
      final shiftLabel = {'morning': 'Sáng', 'afternoon': 'Chiều', 'night': 'Tối'}[d.shift] ?? d.shift;
      final parts = <String>[shiftLabel, weatherLbl];
      if (d.activities.isNotEmpty) parts.add(d.activities);
      if (d.incidentNote.isNotEmpty) parts.add('⚠ ${d.incidentNote}');
      events.add(_PondTimelineEvent(
        date: d.date,
        icon: Icons.edit_note_rounded,
        color: const Color(0xFF6D4C41),
        title: 'Nhật ký',
        subtitle: parts.join(' · '),
      ));
    }

    // 12. Đo kích thước
    final pondBatchIds = dp.fishBatches.where((b) => b.pondId == pond.id).map((b) => b.id).toSet();
    for (final m in dp.sizeMeasurements.where((m) => m.pondId == pond.id || (m.pondId.isEmpty && pondBatchIds.contains(m.fishBatchId)))) {
      final batch = dp.fishBatches.where((b) => b.id == m.fishBatchId).firstOrNull;
      final batchName = batch?.name ?? 'Lô #${m.fishBatchId.substring(0, 6)}';
      final parts = <String>[];
      if (m.avgWeight > 0) parts.add('${m.avgWeight}g');
      if (m.avgLength > 0) parts.add('${m.avgLength}cm');
      if (m.sampleCount > 0) parts.add('mẫu: ${m.sampleCount} con');
      if (m.measuredBy.isNotEmpty) parts.add(m.measuredBy);
      events.add(_PondTimelineEvent(
        date: m.date,
        icon: Icons.straighten_rounded,
        color: const Color(0xFF6366F1),
        title: 'Đo kích thước: $batchName',
        subtitle: parts.join(' · '),
      ));
    }

    // Sort descending
    events.sort((a, b) => b.date.compareTo(a.date));

    return events;
  }

  /// Build timeline item widgets from a list of events
  List<Widget> _buildTimelineItems(List<_PondTimelineEvent> events, DateFormat dateFmt, DateFormat timeFmt) {
    return events.asMap().entries.map((entry) {
      final i = entry.key;
      final e = entry.value;
      final isFirst = i == 0;
      final isLast = i == events.length - 1;
      return IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 28,
            child: Column(children: [
              if (!isFirst) Container(width: 2, height: 6, color: AppColors.border),
              Container(
                width: 20, height: 20,
                decoration: BoxDecoration(
                  color: e.color.withAlpha(25),
                  shape: BoxShape.circle,
                  border: Border.all(color: e.color, width: 2),
                ),
                child: Icon(e.icon, size: 10, color: e.color),
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: AppColors.border)),
            ]),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: e.color.withAlpha(8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: e.color.withAlpha(30)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: e.color)),
                if (e.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(e.subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 3, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 3),
                Text('${dateFmt.format(e.date)} ${timeFmt.format(e.date)}', style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
              ]),
            ),
          ),
        ]),
      );
    }).toList();
  }

  /// Show full pond history in a dialog with scroll
  void _showFullPondHistory(String pondName, List<_PondTimelineEvent> events, DateFormat dateFmt, DateFormat timeFmt) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: AppSizes.dialogWidth(context, 520), maxHeight: AppSizes.dialogMaxHeightR(context)),
          child: Column(children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(children: [
                const Icon(Icons.timeline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'Lịch sử ao $pondName (${events.length})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                )),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                  tooltip: 'Đóng',
                ),
              ]),
            ),
            // Scrollable timeline content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildTimelineItems(events, dateFmt, timeFmt),
                ),
              ),
            ),
            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Đóng'),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // QUICK OPERATION DIALOGS (from pond detail)
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> _showQuickDiseaseDialog(Pond pond, List<FishBatch> batches) async {
    final nameC = TextEditingController();
    final sympC = TextEditingController();
    String severity = 'moderate';
    String batchId = batches.isNotEmpty ? batches.first.id : '';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Ghi nhận bệnh'),
          content: SizedBox(
            width: AppSizes.dialogWidth(context, 400),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Tên bệnh *', prefixIcon: Icon(Icons.coronavirus))),
              const SizedBox(height: 10),
              TextField(controller: sympC, decoration: const InputDecoration(labelText: 'Triệu chứng'), maxLines: 2),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: DropdownButtonFormField<String>(
                  value: severity,
                  decoration: const InputDecoration(labelText: 'Mức độ'),
                  items: const [
                    DropdownMenuItem(value: 'mild', child: Text('Nhẹ')),
                    DropdownMenuItem(value: 'moderate', child: Text('Trung bình')),
                    DropdownMenuItem(value: 'severe', child: Text('Nghiêm trọng')),
                  ],
                  onChanged: (v) => setSt(() => severity = v ?? 'moderate'),
                )),
                const SizedBox(width: 8),
                if (batches.isNotEmpty) Expanded(child: DropdownButtonFormField<String>(
                  value: batchId,
                  decoration: const InputDecoration(labelText: 'Lô cá'),
                  items: batches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                  onChanged: (v) => setSt(() => batchId = v ?? ''),
                )),
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ghi nhận')),
          ],
        ),
      ),
    );
    if (ok == true && nameC.text.isNotEmpty) {
      await dp.create('diseaselogs', {
        'pondId': pond.id, 'fishBatchId': batchId,
        'diseaseName': nameC.text, 'symptoms': sympC.text,
        'severity': severity, 'status': 'detected',
        'detectedDate': DateTime.now().toIso8601String(),
      });
      _showSnack('Đã ghi nhận bệnh');
    }
  }

  Future<void> _showQuickTreatmentDialog(Pond pond) async {
    final durC = TextEditingController(text: '3');
    final wdC = TextEditingController(text: '0');
    final noteC = TextEditingController();
    String method = 'bath';
    String diseaseLogId = '';
    final pondDiseases = dp.diseaseLogs.where((d) => d.pondId == pond.id && d.status != 'resolved').toList();
    // Medicine line items from inventory
    final medicineProducts = dp.products.where((p) => p.category == 'medicine' || p.category == 'chemical').toList();
    final lineItems = <Map<String, dynamic>>[];
    // Auto-add first medicine line
    if (medicineProducts.isNotEmpty) {
      final first = medicineProducts.first;
      lineItems.add({
        'productId': first.id,
        'productName': first.name,
        'qty': 0.0,
        'unitPrice': first.costPrice > 0 ? first.costPrice : first.price,
        'unit': first.unit,
      });
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) {
          final usedProductIds = lineItems.map((i) => i['productId'] as String).toSet();
          double total = 0;
          bool hasOverStock = false;
          bool hasZeroQty = false;
          for (final item in lineItems) {
            final qty = ((item['qty'] as num?) ?? 0).toDouble();
            total += qty * ((item['unitPrice'] as num?) ?? 0).toDouble();
            final prod = dp.productById(item['productId'] as String? ?? '');
            if (prod != null && qty > prod.stock) hasOverStock = true;
            if (qty <= 0) hasZeroQty = true;
          }
          final canSubmit = lineItems.isNotEmpty && !hasOverStock && !hasZeroQty;

          return AlertDialog(
            title: const Text('Thêm điều trị'),
            content: SizedBox(
              width: AppSizes.dialogWidth(context, 480),
              child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (pondDiseases.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: diseaseLogId.isEmpty ? null : diseaseLogId,
                    decoration: const InputDecoration(labelText: 'Bệnh liên quan', prefixIcon: Icon(Icons.coronavirus)),
                    items: pondDiseases.map((d) => DropdownMenuItem(value: d.id, child: Text(d.diseaseName))).toList(),
                    onChanged: (v) => ss(() => diseaseLogId = v ?? ''),
                  ),
                if (pondDiseases.isNotEmpty) const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: DropdownButtonFormField<String>(
                    value: method,
                    decoration: const InputDecoration(labelText: 'Cách dùng', prefixIcon: Icon(Icons.medical_services)),
                    items: const [
                      DropdownMenuItem(value: 'bath', child: Text('Tắm')),
                      DropdownMenuItem(value: 'feed_mix', child: Text('Trộn TĂ')),
                      DropdownMenuItem(value: 'splash', child: Text('Tát')),
                    ],
                    onChanged: (v) => ss(() => method = v ?? 'bath'),
                  )),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(controller: durC, decoration: const InputDecoration(labelText: 'Ngày điều trị'), keyboardType: TextInputType.number)),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: wdC, decoration: const InputDecoration(labelText: 'Ngày cách ly'), keyboardType: TextInputType.number)),
                ]),
                const SizedBox(height: 16),
                // ── Thuốc / Hóa chất từ kho ──
                Row(children: [
                  const Icon(Icons.inventory_2, size: 18, color: AppColors.primary),
                  const SizedBox(width: 6),
                  const Text('Thuốc / Hóa chất xuất kho', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: medicineProducts.isEmpty ? null : () => ss(() {
                      final available = medicineProducts.where((p) => !usedProductIds.contains(p.id)).toList();
                      final first = available.isNotEmpty ? available.first : (medicineProducts.isNotEmpty ? medicineProducts.first : null);
                      if (first != null) {
                        lineItems.add({
                          'productId': first.id,
                          'productName': first.name,
                          'qty': 0.0,
                          'unitPrice': first.costPrice > 0 ? first.costPrice : first.price,
                          'unit': first.unit,
                        });
                      }
                    }),
                    icon: const Icon(Icons.add_circle, size: 18),
                    label: const Text('Thêm dòng'),
                  ),
                ]),
                if (medicineProducts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Chưa có thuốc/hóa chất trong kho. Vui lòng thêm sản phẩm loại "Thuốc" hoặc "Hóa chất" trước.',
                      style: TextStyle(color: AppColors.warning, fontSize: 12)),
                  ),
                ...lineItems.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  final currentPid = item['productId'] as String? ?? '';
                  final prod = dp.productById(currentPid);
                  final qty = ((item['qty'] as num?) ?? 0).toDouble();
                  final stock = prod?.stock ?? 0;
                  final overStock = prod != null && qty > stock;
                  final zeroQty = qty <= 0;
                  final availableProducts = medicineProducts.where((p) => p.id == currentPid || !usedProductIds.contains(p.id)).toList();

                  return Container(
                    key: ValueKey('treat_line_$idx'),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: overStock ? AppColors.error.withAlpha(10) : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                      border: overStock ? Border.all(color: AppColors.error.withAlpha(80)) : null,
                    ),
                    child: Column(children: [
                      Row(children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('treat_prod_${idx}_$currentPid'),
                            initialValue: currentPid,
                            decoration: const InputDecoration(labelText: 'Thuốc / Hóa chất', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                            items: availableProducts.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.name} (tồn: ${_smartQty(p.stock)})', overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (v) => ss(() {
                              final p = dp.productById(v!);
                              item['productId'] = v;
                              item['productName'] = p?.name ?? '';
                              item['unitPrice'] = p != null ? (p.costPrice > 0 ? p.costPrice : p.price) : 0;
                              item['unit'] = p?.unit ?? 'kg';
                            }),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(icon: const Icon(Icons.delete, color: AppColors.error, size: 20), onPressed: () => ss(() => lineItems.removeAt(idx))),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: TextFormField(
                          key: ValueKey('treat_qty_${idx}_$currentPid'),
                          initialValue: qty > 0 ? qty.toStringAsFixed(1) : '',
                          decoration: InputDecoration(
                            labelText: 'SL xuất (${item['unit'] ?? ''})',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            helperText: prod != null ? 'Tồn: ${_smartQty(stock)}' : null,
                            helperStyle: TextStyle(fontSize: 11, color: overStock ? AppColors.error : null),
                            errorText: overStock ? 'Vượt tồn kho!' : (zeroQty && prod != null ? 'Nhập SL > 0' : null),
                            errorStyle: const TextStyle(fontSize: 11),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (v) => ss(() => item['qty'] = double.tryParse(v) ?? 0),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: TextFormField(
                          key: ValueKey('treat_price_${idx}_$currentPid'),
                          initialValue: ((item['unitPrice'] as num?) ?? 0) > 0 ? (item['unitPrice'] as num).toString() : '',
                          decoration: const InputDecoration(labelText: 'Đơn giá (vốn)', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                          keyboardType: TextInputType.number,
                          onChanged: (v) => ss(() => item['unitPrice'] = double.tryParse(v) ?? 0),
                        )),
                      ]),
                    ]),
                  );
                }),
                if (hasOverStock)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: Row(children: [
                      const Icon(Icons.warning_rounded, size: 16, color: AppColors.warning),
                      const SizedBox(width: 6),
                      const Expanded(child: Text('Có sản phẩm xuất vượt tồn kho', style: TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.w600))),
                    ]),
                  ),
                if (lineItems.isNotEmpty) ...[
                  const Divider(),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    const Text('Tổng giá trị: ', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('${_currFmt.format(total.round())}đ', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.warning)),
                  ]),
                ],
                const SizedBox(height: 8),
                TextField(controller: noteC, decoration: const InputDecoration(labelText: 'Ghi chú', prefixIcon: Icon(Icons.note)), maxLines: 2),
              ])),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
              FilledButton.icon(
                onPressed: canSubmit ? () => Navigator.pop(ctx, true) : null,
                icon: const Icon(Icons.medical_services),
                label: const Text('Thêm điều trị'),
              ),
            ],
          );
        },
      ),
    );
    if (ok == true && lineItems.isNotEmpty) {
      final dur = int.tryParse(durC.text) ?? 3;
      final wd = int.tryParse(wdC.text) ?? 0;
      final start = DateTime.now();
      final end = start.add(Duration(days: dur));
      final safe = end.add(Duration(days: wd));

      // Build medicine names for treatment log
      final medicineNames = lineItems.map((i) => i['productName'] as String).join(', ');

      // 1. Create treatment log
      await dp.create('treatmentlogs', {
        'pondId': pond.id, 'diseaseLogId': diseaseLogId,
        'medicineName': medicineNames,
        'dosage': 0, 'dosageUnit': 'ml/m3',
        'method': method, 'durationDays': dur, 'withdrawalDays': wd,
        'startDate': start.toIso8601String(),
        'endDate': end.toIso8601String(),
        'safeHarvestDate': wd > 0 ? safe.toIso8601String() : null,
        'cost': lineItems.fold<double>(0, (s, i) => s + ((i['qty'] as num?) ?? 0).toDouble() * ((i['unitPrice'] as num?) ?? 0).toDouble()),
        'status': 'in_progress',
        'note': noteC.text,
      });

      // 2. Create stock issue for medicine/chemical
      final existingCodes = dp.stockIssues.map((si) => si.code).toList();
      int maxNum = 0;
      for (final c in existingCodes) {
        final m = RegExp(r'XK-(\d+)').firstMatch(c);
        if (m != null) {
          final n = int.tryParse(m.group(1)!) ?? 0;
          if (n > maxNum) maxNum = n;
        }
      }
      final issueCode = 'XK-${(maxNum + 1).toString().padLeft(3, '0')}';

      double total = 0;
      for (final item in lineItems) {
        total += ((item['qty'] as num?) ?? 0) * ((item['unitPrice'] as num?) ?? 0);
      }

      final batches = dp.fishBatches.where((b) => b.pondIds.contains(pond.id)).toList();
      final batchId = batches.isNotEmpty ? batches.map((b) => b.id).join(',') : '';

      // Determine branch from pond's zone
      String branchId = '';
      if (pond.zoneId != null) {
        final zone = dp.zones.where((z) => z.id == pond.zoneId).firstOrNull;
        branchId = zone?.branchId ?? '';
      }

      await dp.create('stockissues', {
        'code': issueCode,
        'date': DateTime.now().toIso8601String(),
        'type': 'treatment',
        'pondId': pond.id,
        'fishBatchId': batchId,
        'branchId': branchId,
        'items': lineItems,
        'totalAmount': total,
        'status': 'approved',
        'note': 'Điều trị Ao ${pond.code} — $medicineNames${noteC.text.isNotEmpty ? ' — ${noteC.text}' : ''}',
        'createdBy': '',
        'issuedTo': '',
      });

      // 3. Update disease status
      if (diseaseLogId.isNotEmpty) {
        await dp.update('diseaselogs', diseaseLogId, {'status': 'treating'});
      }

      await dp.reload('stockissues');
      await dp.reload('products');
      _showSnack('Đã thêm điều trị & tạo phiếu xuất kho $issueCode');
    }
  }

  Future<void> _showQuickWaterChangeDialog(Pond pond) async {
    final pctC = TextEditingController(text: '30');
    final volC = TextEditingController();
    String reason = 'routine';
    String source = 'well';
    DateTime selectedDate = DateTime.now();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Ghi nhận thay nước'),
          content: SizedBox(
            width: AppSizes.dialogWidth(context, 380),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(context: ctx, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                  if (d != null) {
                    final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(selectedDate));
                    setSt(() => selectedDate = DateTime(d.year, d.month, d.day, t?.hour ?? selectedDate.hour, t?.minute ?? selectedDate.minute));
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Ngày giờ ghi nhận', prefixIcon: Icon(Icons.calendar_today)),
                  child: Text(DateFormat('dd/MM/yyyy HH:mm').format(selectedDate)),
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(controller: pctC, decoration: const InputDecoration(labelText: '% thay', suffixText: '%'), keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: volC, decoration: const InputDecoration(labelText: 'Thể tích (m³)'), keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: DropdownButtonFormField<String>(
                  value: reason,
                  decoration: const InputDecoration(labelText: 'Lý do'),
                  items: const [
                    DropdownMenuItem(value: 'routine', child: Text('Định kỳ')),
                    DropdownMenuItem(value: 'emergency', child: Text('Khẩn cấp')),
                    DropdownMenuItem(value: 'treatment', child: Text('Xử lý bệnh')),
                  ],
                  onChanged: (v) => setSt(() => reason = v ?? 'routine'),
                )),
                const SizedBox(width: 8),
                Expanded(child: DropdownButtonFormField<String>(
                  value: source,
                  decoration: const InputDecoration(labelText: 'Nguồn nước'),
                  items: const [
                    DropdownMenuItem(value: 'well', child: Text('Giếng')),
                    DropdownMenuItem(value: 'river', child: Text('Sông')),
                    DropdownMenuItem(value: 'reservoir', child: Text('Hồ chứa')),
                  ],
                  onChanged: (v) => setSt(() => source = v ?? 'well'),
                )),
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ghi nhận')),
          ],
        ),
      ),
    );
    if (ok == true) {
      await dp.create('waterchangelogs', {
        'pondId': pond.id,
        'date': selectedDate.toIso8601String(),
        'percentChanged': double.tryParse(pctC.text) ?? 30,
        'volumeChanged': double.tryParse(volC.text) ?? 0,
        'reason': reason, 'waterSource': source,
      });
      _showSnack('Đã ghi nhận thay nước');
    }
  }

  Future<void> _showQuickDailyLogDialog(Pond pond) async {
    final actC = TextEditingController();
    final feedC = TextEditingController();
    final healthC = TextEditingController();
    final incidentC = TextEditingController();
    String shift = 'morning';
    String weather = 'sunny';
    DateTime selectedDate = DateTime.now();
    final now = TimeOfDay.now();
    if (now.hour >= 17) shift = 'night';
    else if (now.hour >= 12) shift = 'afternoon';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Ghi nhật ký'),
          content: SizedBox(
            width: AppSizes.dialogWidth(context, 400),
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(context: ctx, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                  if (d != null) {
                    final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(selectedDate));
                    setSt(() => selectedDate = DateTime(d.year, d.month, d.day, t?.hour ?? selectedDate.hour, t?.minute ?? selectedDate.minute));
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Ngày giờ ghi nhận', prefixIcon: Icon(Icons.calendar_today)),
                  child: Text(DateFormat('dd/MM/yyyy HH:mm').format(selectedDate)),
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: DropdownButtonFormField<String>(
                  value: shift,
                  decoration: const InputDecoration(labelText: 'Ca'),
                  items: const [
                    DropdownMenuItem(value: 'morning', child: Text('Sáng')),
                    DropdownMenuItem(value: 'afternoon', child: Text('Chiều')),
                    DropdownMenuItem(value: 'night', child: Text('Tối')),
                  ],
                  onChanged: (v) => setSt(() => shift = v ?? 'morning'),
                )),
                const SizedBox(width: 8),
                Expanded(child: DropdownButtonFormField<String>(
                  value: weather,
                  decoration: const InputDecoration(labelText: 'Thời tiết'),
                  items: const [
                    DropdownMenuItem(value: 'sunny', child: Text('☀️ Nắng')),
                    DropdownMenuItem(value: 'cloudy', child: Text('☁️ Mây')),
                    DropdownMenuItem(value: 'rainy', child: Text('🌧️ Mưa')),
                    DropdownMenuItem(value: 'stormy', child: Text('⛈️ Bão')),
                  ],
                  onChanged: (v) => setSt(() => weather = v ?? 'sunny'),
                )),
              ]),
              const SizedBox(height: 10),
              TextField(controller: actC, decoration: const InputDecoration(labelText: 'Hoạt động chính'), maxLines: 2),
              const SizedBox(height: 10),
              TextField(controller: feedC, decoration: const InputDecoration(labelText: 'Ghi chú cho ăn')),
              const SizedBox(height: 10),
              TextField(controller: healthC, decoration: const InputDecoration(labelText: 'Sức khỏe cá')),
              const SizedBox(height: 10),
              TextField(controller: incidentC, decoration: const InputDecoration(labelText: 'Sự cố (nếu có)')),
            ])),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ghi nhận')),
          ],
        ),
      ),
    );
    if (ok == true) {
      await dp.create('dailylogs', {
        'pondId': pond.id, 'date': selectedDate.toIso8601String(),
        'shift': shift, 'weather': weather,
        'activities': actC.text, 'feedingNote': feedC.text,
        'healthNote': healthC.text, 'incidentNote': incidentC.text,
      });
      _showSnack('Đã ghi nhật ký');
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // ACTION DIALOGS
  // ═════════════════════════════════════════════════════════════════════════

  // 1) THẢ CÁ
  Future<void> _showStockFishDialog(Pond pond) async {
    // Lọc lô cá active còn cá chưa phân bổ hết
    final availBatches = dp.fishBatches.where((b) => b.status == 'active' && b.unallocatedQuantity > 0).toList();

    if (availBatches.isEmpty) {
      _showSnack('Không có lô cá nào còn cá chưa phân bổ. Hãy tạo lô cá trước.');
      return;
    }

    FishBatch? selectedBatch = availBatches.first;
    final qtyC = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, ss) {
          final sp = selectedBatch != null ? dp.speciesById(selectedBatch!.speciesId) : null;
          final avail = selectedBatch?.unallocatedQuantity ?? 0;
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.set_meal_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Thả cá vào ${pond.code}'),
              ],
            ),
            content: SizedBox(
              width: AppSizes.dialogWidth(context, 500),
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedBatch?.id,
                    decoration: const InputDecoration(labelText: 'Chọn lô cá', prefixIcon: Icon(Icons.inventory_2)),
                    items: availBatches.map((b) {
                      final sName = dp.speciesById(b.speciesId)?.name ?? '';
                      final label = b.name.isNotEmpty ? '${b.name} ($sName)' : sName;
                      return DropdownMenuItem(value: b.id, child: Text('$label — còn ${b.unallocatedQuantity} con'));
                    }).toList(),
                    onChanged: (v) => ss(() {
                      selectedBatch = availBatches.where((b) => b.id == v).firstOrNull;
                      qtyC.text = '';
                    }),
                  ),
                  const SizedBox(height: 16),
                  if (selectedBatch != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(8)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Loài: ${sp?.name ?? '—'}', style: const TextStyle(fontSize: 13)),
                        Text('Tổng lô: ${selectedBatch!.initialQuantity} con • Đã phân bổ: ${selectedBatch!.allocatedQuantity} con', style: const TextStyle(fontSize: 13)),
                        Text('Kích cỡ: ${selectedBatch!.initialSize} cm • TL: ${selectedBatch!.initialWeight} g', style: const TextStyle(fontSize: 13)),
                        if (selectedBatch!.pondAllocations.isNotEmpty)
                          Text('Đang nuôi tại: ${selectedBatch!.pondIds.map((id) => dp.pondById(id)?.code ?? '?').join(', ')}', style: const TextStyle(fontSize: 13, color: AppColors.primary)),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: qtyC,
                      decoration: InputDecoration(
                        labelText: 'Số lượng thả (tối đa $avail con)',
                        prefixIcon: const Icon(Icons.format_list_numbered),
                        helperText: 'Còn $avail con chưa phân bổ',
                        errorText: () {
                          final v = int.tryParse(qtyC.text);
                          if (qtyC.text.isNotEmpty && (v == null || v <= 0)) return 'Số lượng không hợp lệ';
                          if (v != null && v > avail) return 'Vượt quá số cá chưa phân bổ ($avail con)!';
                          return null;
                        }(),
                        errorStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => ss(() {}),
                    ),
                    if (qtyC.text.isNotEmpty && (int.tryParse(qtyC.text) ?? 0) > avail)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(children: [
                          Icon(Icons.warning_rounded, size: 18, color: Colors.red.shade700),
                          const SizedBox(width: 6),
                          Expanded(child: Text(
                            'Lô cá chỉ còn $avail con chưa phân bổ. Không thể thả ${qtyC.text} con!',
                            style: TextStyle(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.w600),
                          )),
                        ]),
                      ),
                  ],
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Huỷ')),
              FilledButton.icon(
                onPressed: () {
                  final v = int.tryParse(qtyC.text) ?? 0;
                  if (v <= 0 || v > avail) return;
                  Navigator.pop(dCtx, true);
                },
                icon: const Icon(Icons.check),
                label: const Text('Thả cá'),
              ),
            ],
          );
        },
      ),
    );

    if (ok == true && selectedBatch != null && qtyC.text.isNotEmpty) {
      final qty = int.tryParse(qtyC.text) ?? 0;
      final batch = selectedBatch!;
      final avail = batch.unallocatedQuantity;
      if (qty <= 0) {
        _showSnack('Số lượng phải lớn hơn 0');
        return;
      }
      if (qty > avail) {
        _showSnack('Số lượng vượt quá số cá chưa phân bổ ($avail con)');
        return;
      }
      // Thêm allocation vào lô cá
      final newAllocs = List<Map<String, dynamic>>.from(batch.pondAllocations);
      final existIdx = newAllocs.indexWhere((a) => a['pondId'] == pond.id);
      if (existIdx >= 0) {
        newAllocs[existIdx] = {'pondId': pond.id, 'quantity': ((newAllocs[existIdx]['quantity'] as num?)?.toInt() ?? 0) + qty};
      } else {
        newAllocs.add({'pondId': pond.id, 'quantity': qty});
      }
      await dp.update('fishbatches', batch.id, {
        ...batch.toJson(),
        'pondAllocations': newAllocs,
        'pondId': newAllocs.first['pondId'],
      });
      // Kích hoạt ao
      if (pond.status == 'inactive') {
        await dp.update('ponds', pond.id, {...pond.toJson(), 'status': 'active'});
      }
      _showSnack('Đã thả ${qty} con vào ${pond.code}');
    }
  }

  // 1b) RÚT CÁ / HUỶ THẢ
  Future<void> _showWithdrawFishDialog(Pond pond, List<FishBatch> batches) async {
    // Chỉ hiện lô cá đang có cá trong ao này
    final batchesInPond = batches.where((b) => b.quantityInPond(pond.id) > 0).toList();
    if (batchesInPond.isEmpty) {
      _showSnack('Không có lô cá nào trong ao ${pond.code}');
      return;
    }

    FishBatch? selectedBatch = batchesInPond.first;
    final qtyC = TextEditingController();
    String withdrawType = 'partial'; // 'partial' or 'all'

    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, ss) {
          final qtyInPond = selectedBatch?.quantityInPond(pond.id) ?? 0;
          final sp = selectedBatch != null ? dp.speciesById(selectedBatch!.speciesId) : null;
          return AlertDialog(
            title: Row(children: [
              const Icon(Icons.undo_rounded, color: Color(0xFFE65100)),
              const SizedBox(width: 8),
              Expanded(child: Text('Rút cá khỏi ${pond.code}')),
            ]),
            content: SizedBox(
              width: AppSizes.dialogWidth(context, 500),
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Chọn lô cá
                  DropdownButtonFormField<String>(
                    initialValue: selectedBatch?.id,
                    decoration: const InputDecoration(labelText: 'Chọn lô cá', prefixIcon: Icon(Icons.inventory_2)),
                    items: batchesInPond.map((b) {
                      final sName = dp.speciesById(b.speciesId)?.name ?? '';
                      final label = b.name.isNotEmpty ? '${b.name} ($sName)' : sName;
                      return DropdownMenuItem(value: b.id, child: Text('$label — ${b.quantityInPond(pond.id)} con trong ao'));
                    }).toList(),
                    onChanged: (v) => ss(() {
                      selectedBatch = batchesInPond.where((b) => b.id == v).firstOrNull;
                      qtyC.text = '';
                      withdrawType = 'partial';
                    }),
                  ),
                  const SizedBox(height: 16),
                  if (selectedBatch != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFE65100).withAlpha(12), borderRadius: BorderRadius.circular(8)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Loài: ${sp?.name ?? '—'}', style: const TextStyle(fontSize: 13)),
                        Text('Số cá trong ao ${pond.code}: $qtyInPond con', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        Text('Tổng lô: ${selectedBatch!.currentQuantity} con (ban đầu: ${selectedBatch!.initialQuantity})', style: const TextStyle(fontSize: 13)),
                        if (selectedBatch!.pondAllocations.length > 1)
                          Text('Đang phân bổ ở: ${selectedBatch!.pondIds.map((id) => dp.pondById(id)?.code ?? '?').join(', ')}',
                              style: const TextStyle(fontSize: 13, color: AppColors.info)),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    // Loại rút
                    Row(children: [
                      Expanded(child: RadioListTile<String>(
                        title: const Text('Rút một phần', style: TextStyle(fontSize: 13)),
                        value: 'partial',
                        groupValue: withdrawType,
                        onChanged: (v) => ss(() { withdrawType = v!; qtyC.text = ''; }),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      )),
                      Expanded(child: RadioListTile<String>(
                        title: const Text('Rút toàn bộ', style: TextStyle(fontSize: 13)),
                        value: 'all',
                        groupValue: withdrawType,
                        onChanged: (v) => ss(() { withdrawType = v!; qtyC.text = qtyInPond.toString(); }),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      )),
                    ]),
                    if (withdrawType == 'partial') ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: qtyC,
                        decoration: InputDecoration(
                          labelText: 'Số lượng rút (tối đa $qtyInPond con)',
                          prefixIcon: const Icon(Icons.format_list_numbered),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.warning.withAlpha(15), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.warning.withAlpha(40))),
                      child: const Row(children: [
                        Icon(Icons.info_outline, size: 18, color: AppColors.warning),
                        SizedBox(width: 8),
                        Expanded(child: Text('Cá rút khỏi ao sẽ trở về trạng thái chưa phân bổ trong lô. Bạn có thể thả lại vào ao khác.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                      ]),
                    ),
                  ],
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Huỷ')),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dCtx, true),
                icon: const Icon(Icons.undo_rounded),
                label: const Text('Rút cá'),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE65100)),
              ),
            ],
          );
        },
      ),
    );

    if (ok == true && selectedBatch != null) {
      final batch = selectedBatch!;
      final qtyInPond = batch.quantityInPond(pond.id);
      final withdrawQty = withdrawType == 'all' ? qtyInPond : (int.tryParse(qtyC.text) ?? 0);

      if (withdrawQty <= 0) {
        _showSnack('Số lượng phải lớn hơn 0');
        return;
      }
      if (withdrawQty > qtyInPond) {
        _showSnack('Số lượng vượt quá số cá trong ao ($qtyInPond con)');
        return;
      }

      // Xác nhận
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Row(children: [Icon(Icons.warning_rounded, color: AppColors.warning), SizedBox(width: 8), Text('Xác nhận rút cá')]),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Rút $withdrawQty con khỏi ao ${pond.code}?'),
            Text('Lô: ${batch.name.isNotEmpty ? batch.name : dp.speciesById(batch.speciesId)?.name ?? '?'}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            const Text('• Cá sẽ trở về trạng thái chưa phân bổ', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            if (withdrawQty == qtyInPond)
              const Text('• Ao sẽ trở về trạng thái Trống nếu không còn lô cá khác', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Huỷ')),
            FilledButton(onPressed: () => Navigator.pop(c, true), style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE65100)), child: const Text('Xác nhận rút')),
          ],
        ),
      );
      if (confirmed != true) return;

      // Cập nhật pondAllocations
      final newAllocs = List<Map<String, dynamic>>.from(batch.pondAllocations);
      final idx = newAllocs.indexWhere((a) => a['pondId'] == pond.id);
      if (idx >= 0) {
        final remaining = ((newAllocs[idx]['quantity'] as num?)?.toInt() ?? 0) - withdrawQty;
        if (remaining <= 0) {
          newAllocs.removeAt(idx);
        } else {
          newAllocs[idx] = {'pondId': pond.id, 'quantity': remaining};
        }
      }

      await dp.update('fishbatches', batch.id, {
        ...batch.toJson(),
        'pondAllocations': newAllocs,
        'pondId': newAllocs.isNotEmpty ? newAllocs.first['pondId'] : '',
      });

      // Nếu rút hết cá trong ao → kiểm tra có lô khác không, nếu không thì chuyển ao thành inactive
      if (withdrawQty == qtyInPond) {
        final otherBatchesInPond = dp.batchesForPond(pond.id).where((b) => b.id != batch.id && b.status == 'active');
        if (otherBatchesInPond.isEmpty) {
          await dp.update('ponds', pond.id, {...pond.toJson(), 'status': 'inactive'});
        }
      }

      _showSnack('Đã rút $withdrawQty con khỏi ${pond.code}. Cá trở về chưa phân bổ.');
    }
  }

  // 2) CHUYỂN CÁ
  Future<void> _showTransferDialog(Pond fromPond, List<FishBatch> batches) async {
    FishBatch? selectedBatch = batches.first;
    String? targetPondId;
    final qtyC = TextEditingController();
    final noteC = TextEditingController();
    DateTime selectedDate = DateTime.now();
    final otherPonds = dp.ponds.where((p) => p.id != fromPond.id).toList();

    if (otherPonds.isEmpty) {
      _showSnack('Không có ao khác để chuyển');
      return;
    }
    targetPondId = otherPonds.first.id;

    // Scheduling options
    bool isScheduled = false;
    DateTime scheduledDate = DateTime.now().add(const Duration(hours: 2));
    TimeOfDay scheduledTime = TimeOfDay(hour: scheduledDate.hour, minute: 0);
    int reminderHours = 1; // báo trước bao nhiêu giờ

    final ok = await showDialog<String>( // returns 'now' or 'schedule'
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, ss) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.swap_horiz_rounded, color: AppColors.info),
              const SizedBox(width: 8),
              Text('Chuyển cá từ ${fromPond.code}'),
            ],
          ),
          content: SizedBox(
            width: AppSizes.dialogWidth(context, 520),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                initialValue: selectedBatch?.id,
                decoration: const InputDecoration(labelText: 'Chọn lô cá', prefixIcon: Icon(Icons.set_meal)),
                items: batches.map((b) {
                  final sp = dp.speciesById(b.speciesId);
                  final label = b.name.isNotEmpty ? '${b.name} (${sp?.name ?? '?'})' : (sp?.name ?? '?');
                  return DropdownMenuItem(value: b.id, child: Text('$label (${b.quantityInPond(fromPond.id)} con)'));
                }).toList(),
                onChanged: (v) => ss(() => selectedBatch = batches.firstWhere((b) => b.id == v)),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: targetPondId,
                decoration: const InputDecoration(labelText: 'Ao đích', prefixIcon: Icon(Icons.water)),
                items: otherPonds.map((p) => DropdownMenuItem(value: p.id, child: Text(p.code))).toList(),
                onChanged: (v) => ss(() => targetPondId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyC,
                decoration: InputDecoration(
                  labelText: 'Số lượng chuyển',
                  prefixIcon: const Icon(Icons.format_list_numbered),
                  helperText: 'Tối đa: ${selectedBatch?.quantityInPond(fromPond.id) ?? 0} con trong ao',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteC,
                decoration: const InputDecoration(labelText: 'Ghi chú / Lý do', prefixIcon: Icon(Icons.note)),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              // Ngày chuyển
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(context: dCtx, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                  if (d != null) {
                    final t = await showTimePicker(context: dCtx, initialTime: TimeOfDay.fromDateTime(selectedDate));
                    ss(() => selectedDate = DateTime(d.year, d.month, d.day, t?.hour ?? selectedDate.hour, t?.minute ?? selectedDate.minute));
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Ngày giờ chuyển', prefixIcon: Icon(Icons.calendar_today)),
                  child: Text(DateFormat('dd/MM/yyyy HH:mm').format(selectedDate)),
                ),
              ),
              const SizedBox(height: 16),

              // ── Hẹn giờ chuyển ──
              SwitchListTile(
                title: const Text('Hẹn ngày giờ chuyển', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Tạo lịch chuyển cá & nhắc nhở trước', style: TextStyle(fontSize: 11)),
                secondary: Icon(Icons.schedule_rounded, color: isScheduled ? AppColors.info : AppColors.textHint),
                value: isScheduled,
                onChanged: (v) => ss(() => isScheduled = v),
                contentPadding: EdgeInsets.zero,
              ),

              if (isScheduled) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.info.withAlpha(10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.info.withAlpha(40)),
                  ),
                  child: Column(children: [
                    // Chọn ngày
                    InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: dCtx,
                          initialDate: scheduledDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (d != null) ss(() => scheduledDate = DateTime(d.year, d.month, d.day, scheduledTime.hour, scheduledTime.minute));
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Ngày chuyển',
                          prefixIcon: Icon(Icons.calendar_today),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                        child: Text(DateFormat('dd/MM/yyyy').format(scheduledDate)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Chọn giờ
                    InkWell(
                      onTap: () async {
                        final t = await showTimePicker(context: dCtx, initialTime: scheduledTime);
                        if (t != null) ss(() {
                          scheduledTime = t;
                          scheduledDate = DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day, t.hour, t.minute);
                        });
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Giờ chuyển',
                          prefixIcon: Icon(Icons.access_time),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                        child: Text('${scheduledTime.hour.toString().padLeft(2, '0')}:${scheduledTime.minute.toString().padLeft(2, '0')}'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Nhắc trước bao nhiêu giờ
                    DropdownButtonFormField<int>(
                      value: reminderHours,
                      decoration: const InputDecoration(
                        labelText: 'Báo trước',
                        prefixIcon: Icon(Icons.notifications_active),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('Không nhắc')),
                        DropdownMenuItem(value: 1, child: Text('1 giờ trước')),
                        DropdownMenuItem(value: 2, child: Text('2 giờ trước')),
                        DropdownMenuItem(value: 3, child: Text('3 giờ trước')),
                        DropdownMenuItem(value: 6, child: Text('6 giờ trước')),
                        DropdownMenuItem(value: 12, child: Text('12 giờ trước')),
                        DropdownMenuItem(value: 24, child: Text('1 ngày trước')),
                        DropdownMenuItem(value: 48, child: Text('2 ngày trước')),
                      ],
                      onChanged: (v) => ss(() => reminderHours = v ?? 1),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.warning.withAlpha(15), borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.info_outline, size: 14, color: AppColors.warning),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      'Cá sẽ chưa chuyển ngay. Hệ thống sẽ tạo lịch nhắc nhở${reminderHours > 0 ? ' trước $reminderHours giờ' : ''} và công việc chờ xử lý.',
                      style: const TextStyle(fontSize: 11, color: AppColors.warning),
                    )),
                  ]),
                ),
              ],
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Huỷ')),
            if (isScheduled)
              FilledButton.icon(
                onPressed: () => Navigator.pop(dCtx, 'schedule'),
                icon: const Icon(Icons.schedule),
                label: const Text('Hẹn chuyển'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.info),
              )
            else
              FilledButton.icon(
                onPressed: () => Navigator.pop(dCtx, 'now'),
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Chuyển ngay'),
              ),
          ],
        ),
      ),
    );

    if (ok == null || selectedBatch == null || targetPondId == null || qtyC.text.isEmpty) return;

    final transferQty = int.tryParse(qtyC.text) ?? 0;
    final batch = selectedBatch!;
    final qtyInPond = batch.quantityInPond(fromPond.id);
    if (transferQty <= 0 || transferQty > qtyInPond) {
      _showSnack('Số lượng không hợp lệ (tối đa $qtyInPond con)');
      return;
    }

    final targetPond = dp.pondById(targetPondId!);
    final targetCode = targetPond?.code ?? '';
    final spName = dp.speciesById(batch.speciesId)?.name ?? '?';

    if (ok == 'schedule') {
      // ── Hẹn chuyển: tạo task + notification ──
      final schedDt = DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day, scheduledTime.hour, scheduledTime.minute);

      // Tạo task chuyển cá
      await dp.create('tasks', {
        'title': 'Chuyển $transferQty $spName: ${fromPond.code} → $targetCode',
        'type': 'transfer',
        'pondId': fromPond.id,
        'assignedTo': '',
        'dueDate': schedDt.toIso8601String(),
        'status': 'pending',
        'note': '${noteC.text.isNotEmpty ? '${noteC.text}\n' : ''}'
            'Lô: ${batch.name.isNotEmpty ? batch.name : spName}\n'
            'Từ: ${fromPond.code} → $targetCode\n'
            'SL: $transferQty con\n'
            'Báo trước: ${reminderHours}h\n'
            'fishBatchId:${batch.id}|fromPondId:${fromPond.id}|toPondId:$targetPondId|qty:$transferQty|reminderHours:$reminderHours',
      });

      // Tạo notification nhắc nhở ngay
      if (reminderHours > 0) {
        final reminderAt = schedDt.subtract(Duration(hours: reminderHours));
        await dp.create('notifications', {
          'title': 'Nhắc chuyển cá',
          'message': 'Lịch chuyển $transferQty $spName từ ${fromPond.code} → $targetCode lúc ${DateFormat('HH:mm dd/MM').format(schedDt)} (còn ${reminderHours}h)',
          'type': 'info',
          'priority': 'high',
          'read': false,
          'pondId': fromPond.id,
          'scheduledAt': schedDt.toIso8601String(),
          'reminderAt': reminderAt.toIso8601String(),
          'transferData': {
            'fishBatchId': batch.id,
            'fromPondId': fromPond.id,
            'toPondId': targetPondId,
            'quantity': transferQty,
          },
        });
      }

      _showSnack('Đã hẹn chuyển $transferQty con lúc ${DateFormat('HH:mm dd/MM/yyyy').format(schedDt)}${reminderHours > 0 ? ' (nhắc trước ${reminderHours}h)' : ''}');
    } else {
      // ── Chuyển ngay (logic cũ) ──
      final newAllocs = List<Map<String, dynamic>>.from(batch.pondAllocations);
      final srcIdx = newAllocs.indexWhere((a) => a['pondId'] == fromPond.id);
      if (srcIdx >= 0) {
        final remaining = ((newAllocs[srcIdx]['quantity'] as num?)?.toInt() ?? 0) - transferQty;
        if (remaining <= 0) {
          newAllocs.removeAt(srcIdx);
        } else {
          newAllocs[srcIdx] = {'pondId': fromPond.id, 'quantity': remaining};
        }
      }
      final dstIdx = newAllocs.indexWhere((a) => a['pondId'] == targetPondId);
      if (dstIdx >= 0) {
        newAllocs[dstIdx] = {'pondId': targetPondId, 'quantity': ((newAllocs[dstIdx]['quantity'] as num?)?.toInt() ?? 0) + transferQty};
      } else {
        newAllocs.add({'pondId': targetPondId, 'quantity': transferQty});
      }

      await dp.update('fishbatches', batch.id, {
        ...batch.toJson(),
        'pondAllocations': newAllocs,
        'pondId': newAllocs.isNotEmpty ? newAllocs.first['pondId'] : batch.pondId,
      });

      // Create transfer record
      await dp.create('transfers', {
        'fromPondId': fromPond.id,
        'toPondId': targetPondId,
        'fishBatchId': batch.id,
        'qty': transferQty,
        'date': selectedDate.toIso8601String(),
        'reason': noteC.text.isNotEmpty ? noteC.text : 'Chuyển cá',
      });

      if (targetPond != null && targetPond.status == 'inactive') {
        await dp.update('ponds', targetPond.id, {...targetPond.toJson(), 'status': 'active'});
      }

      // Deactivate source pond if no more fish
      final srcHasFish = newAllocs.any((a) => a['pondId'] == fromPond.id && (a['quantity'] as num? ?? 0) > 0);
      if (!srcHasFish) {
        final otherBatchesInSrc = dp.batchesForPond(fromPond.id).where((b) => b.id != batch.id && b.status == 'active');
        if (otherBatchesInSrc.isEmpty) {
          await dp.update('ponds', fromPond.id, {...fromPond.toJson(), 'status': 'inactive'});
        }
      }

      _showSnack('Đã chuyển $transferQty con sang $targetCode');
    }
  }

  // 3) CHO ĂN
  Future<void> _showFeedDialog(Pond pond, List<FishBatch> batches) async {
    final noteC = TextEditingController();
    String? issuedTo;
    DateTime selectedDate = DateTime.now();

    // Determine branch from pond's zone
    String branchId = '';
    if (pond.zoneId != null) {
      final zone = dp.zones.where((z) => z.id == pond.zoneId).firstOrNull;
      branchId = zone?.branchId ?? '';
    }

    // Pre-populate line items with feed products
    final feedProducts = dp.products.where((p) =>
        p.category.toLowerCase() == 'feed' ||
        p.category.toLowerCase().contains('thức ăn')).toList();

    // Get default feed ratio from species (use first batch's species as default)
    final defaultRatio = batches.isNotEmpty
        ? dp.speciesById(batches.first.speciesId)?.feedRatio ?? 3.0
        : 3.0;
    double feedRatio = defaultRatio;

    // Calculate suggested feed amount PER POND using actual fish count & current weight
    double _calcSuggested(double ratio) {
      double total = 0;
      for (final b in batches) {
        final qtyInPond = b.quantityInPond(pond.id);
        final weight = b.currentWeight > 0 ? b.currentWeight : b.initialWeight;
        total += qtyInPond * weight * ratio / 100 / 1000;
      }
      return total;
    }
    double suggestedKg = _calcSuggested(feedRatio);

    final lineItems = <Map<String, dynamic>>[
      if (feedProducts.isNotEmpty) {
        'productId': feedProducts.first.id,
        'productName': feedProducts.first.name,
        'qty': double.parse(suggestedKg.toStringAsFixed(1)),
        'unitPrice': feedProducts.first.costPrice > 0 ? feedProducts.first.costPrice : feedProducts.first.price,
        'unit': feedProducts.first.unit,
      },
    ];

    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, ss) {
          double total = 0;
          bool hasOverStock = false;
          bool hasZeroQty = false;
          for (final item in lineItems) {
            final qty = ((item['qty'] as num?) ?? 0).toDouble();
            final price = ((item['unitPrice'] as num?) ?? 0).toDouble();
            total += qty * price;
            final prod = dp.productById(item['productId'] as String? ?? '');
            if (prod != null && qty > prod.stock) hasOverStock = true;
            if (qty <= 0) hasZeroQty = true;
          }
          final canSubmit = lineItems.isNotEmpty && !hasZeroQty;

          final usedProductIds = lineItems.map((e) => e['productId'] as String?).whereType<String>().toSet();

          return AlertDialog(
            title: Row(children: [
              const Icon(Icons.restaurant_rounded, color: AppColors.success),
              const SizedBox(width: 8),
              Text('Tạo phiếu cho ăn – ${pond.code}'),
            ]),
            content: SizedBox(
              width: AppSizes.dialogWidth(context, 540),
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Ngày phiếu
                  InkWell(
                    onTap: () async {
                      final d = await showDatePicker(context: dCtx, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                      if (d != null) {
                        final t = await showTimePicker(context: dCtx, initialTime: TimeOfDay.fromDateTime(selectedDate));
                        ss(() => selectedDate = DateTime(d.year, d.month, d.day, t?.hour ?? selectedDate.hour, t?.minute ?? selectedDate.minute));
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Ngày giờ cho ăn', prefixIcon: Icon(Icons.calendar_today)),
                      child: Text(DateFormat('dd/MM/yyyy HH:mm').format(selectedDate)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Batch summary — per-pond actual fish count
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withAlpha(15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.success.withAlpha(40)),
                    ),
                    child: Column(children: [
                      ...batches.map((b) {
                        final sp = dp.speciesById(b.speciesId);
                        final qtyInPond = b.quantityInPond(pond.id);
                        final weight = b.currentWeight > 0 ? b.currentWeight : b.initialWeight;
                        final biomass = qtyInPond * weight / 1000;
                        // Find last measurement for this batch
                        final batchMeasures = dp.sizeMeasurements
                            .where((m) => m.fishBatchId == b.id)
                            .toList()
                          ..sort((a, c) => c.date.compareTo(a.date));
                        final lastMeasure = batchMeasures.isNotEmpty ? batchMeasures.first : null;
                        final fromMeasure = b.currentWeight > 0 && lastMeasure != null;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              const Icon(Icons.set_meal, size: 16, color: AppColors.success),
                              const SizedBox(width: 8),
                              Text(sp?.name ?? '?', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              const Spacer(),
                              Text('$qtyInPond con trong ao', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ]),
                            Padding(
                              padding: const EdgeInsets.only(left: 24, top: 2),
                              child: Text('TL: ${weight.toStringAsFixed(0)}g/con • Sinh khối: ${biomass.toStringAsFixed(1)} kg',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 24, top: 1),
                              child: Row(children: [
                                Icon(fromMeasure ? Icons.straighten : Icons.info_outline,
                                  size: 11, color: fromMeasure ? AppColors.primary : AppColors.warning),
                                const SizedBox(width: 4),
                                Text(
                                  fromMeasure
                                    ? '📏 Đo ngày ${lastMeasure!.date.day}/${lastMeasure.date.month}/${lastMeasure.date.year}'
                                    : '⚠ Dùng trọng lượng ban đầu',
                                  style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic,
                                    color: fromMeasure ? AppColors.primary : AppColors.warning),
                                ),
                              ]),
                            ),
                          ]),
                        );
                      }),
                      const Divider(height: 12),
                      // Feed ratio slider
                      Row(children: [
                        const Icon(Icons.tune, size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text('Hệ số cho ăn: ${feedRatio.toStringAsFixed(1)}% thân', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ]),
                      Slider(
                        value: feedRatio.clamp(0.5, 10.0),
                        min: 0.5, max: 10.0, divisions: 19,
                        label: '${feedRatio.toStringAsFixed(1)}%',
                        onChanged: (v) => ss(() {
                          feedRatio = v;
                          suggestedKg = _calcSuggested(v);
                          // Auto-update first line item qty
                          if (lineItems.isNotEmpty) {
                            lineItems[0]['qty'] = double.parse(suggestedKg.toStringAsFixed(1));
                          }
                        }),
                      ),
                      Row(children: [
                        const Icon(Icons.lightbulb_outline, size: 14, color: AppColors.warning),
                        const SizedBox(width: 6),
                        Text('Đề xuất: ${suggestedKg.toStringAsFixed(1)} kg/ngày', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warning)),
                        const Spacer(),
                        Text('(mặc định loài: ${defaultRatio.toStringAsFixed(1)}%)',
                          style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
                      ]),
                      // Show measurement data source for each batch
                      ...batches.map((b) {
                        final ms = dp.sizeMeasurements
                            .where((m) => m.fishBatchId == b.id && (m.pondId == pond.id || m.pondId == null))
                            .toList()
                          ..sort((a, bb) => bb.date.compareTo(a.date));
                        final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
                        if (ms.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(children: [
                              Icon(Icons.info_outline, size: 13, color: Colors.orange.shade300),
                              const SizedBox(width: 6),
                              Expanded(child: Text('${b.name}: Chưa đo — dùng trọng lượng ban đầu (${b.initialWeight.toStringAsFixed(0)}g)',
                                style: TextStyle(fontSize: 11, color: Colors.orange.shade400, fontStyle: FontStyle.italic))),
                            ]),
                          );
                        }
                        final last = ms.first;
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(children: [
                            const Icon(Icons.straighten, size: 13, color: AppColors.success),
                            const SizedBox(width: 6),
                            Expanded(child: Text('${b.name}: Đo ${dateFmt.format(last.date)} — ${last.avgWeight.toStringAsFixed(0)}g/con',
                              style: const TextStyle(fontSize: 11, color: AppColors.success, fontStyle: FontStyle.italic))),
                          ]),
                        );
                      }),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  // Nhân viên cho ăn
                  if (dp.employees.isNotEmpty)
                    DropdownButtonFormField<String?>(
                      key: const ValueKey('feed_issuedTo'),
                      initialValue: issuedTo,
                      decoration: const InputDecoration(labelText: 'Nhân viên cho ăn', prefixIcon: Icon(Icons.person_outline)),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('-- Chọn nhân viên --')),
                        ...dp.employees.map((e) => DropdownMenuItem<String?>(value: e.id, child: Text(e.name))),
                      ],
                      onChanged: (v) => ss(() => issuedTo = v),
                    ),
                  const SizedBox(height: 12),
                  TextField(controller: noteC, decoration: const InputDecoration(labelText: 'Ghi chú', prefixIcon: Icon(Icons.note)), maxLines: 2),
                  const SizedBox(height: 16),
                  // Line items header
                  Row(children: [
                    const Text('Chi tiết thức ăn xuất kho', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => ss(() {
                        final available = dp.products.where((p) => !usedProductIds.contains(p.id)).toList();
                        final first = available.isNotEmpty ? available.first : (dp.products.isNotEmpty ? dp.products.first : null);
                        lineItems.add({
                          'productId': first?.id ?? '',
                          'productName': first?.name ?? '',
                          'qty': 0,
                          'unitPrice': first != null ? (first.costPrice > 0 ? first.costPrice : first.price) : 0,
                          'unit': first?.unit ?? 'kg',
                        });
                      }),
                      icon: const Icon(Icons.add_circle, size: 18),
                      label: const Text('Thêm dòng'),
                    ),
                  ]),
                  ...lineItems.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    final prod = dp.productById(item['productId'] as String? ?? '');
                    final qty = ((item['qty'] as num?) ?? 0).toDouble();
                    final stock = prod?.stock ?? 0;
                    final overStock = prod != null && qty > stock;
                    final zeroQty = qty <= 0;
                    final currentPid = item['productId'] as String?;
                    final availableProducts = dp.products.where((p) => p.id == currentPid || !usedProductIds.contains(p.id)).toList();

                    return Container(
                      key: ValueKey('feed_line_$idx'),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: overStock ? AppColors.error.withAlpha(10) : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                        border: overStock ? Border.all(color: AppColors.error.withAlpha(80)) : null,
                      ),
                      child: Column(children: [
                        Row(children: [
                          Expanded(
                            child: Autocomplete<String>(
                              key: ValueKey('feed_prod_${idx}_$currentPid'),
                              initialValue: TextEditingValue(text: currentPid != null ? '${dp.productById(currentPid)?.name ?? ''} (tồn: ${_smartQty(dp.productById(currentPid)?.stock ?? 0)})' : ''),
                              optionsBuilder: (textEditingValue) {
                                final query = textEditingValue.text.toLowerCase();
                                return availableProducts
                                    .where((p) => query.isEmpty || p.name.toLowerCase().contains(query))
                                    .map((p) => p.id);
                              },
                              displayStringForOption: (id) {
                                final p = dp.productById(id);
                                return p != null ? '${p.name} (tồn: ${_smartQty(p.stock)})' : id;
                              },
                              fieldViewBuilder: (ctx, textC, focusNode, onFieldSubmitted) {
                                return TextFormField(
                                  controller: textC,
                                  focusNode: focusNode,
                                  decoration: const InputDecoration(labelText: 'Sản phẩm (gõ để tìm)', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8), prefixIcon: Icon(Icons.search, size: 18)),
                                  style: const TextStyle(fontSize: 13),
                                );
                              },
                              onSelected: (v) => ss(() {
                                final p = dp.productById(v);
                                item['productId'] = v;
                                item['productName'] = p?.name ?? '';
                                item['unitPrice'] = p != null ? (p.costPrice > 0 ? p.costPrice : p.price) : 0;
                                item['unit'] = p?.unit ?? 'kg';
                              }),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(icon: const Icon(Icons.delete, color: AppColors.error, size: 20), onPressed: () => ss(() => lineItems.removeAt(idx))),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(child: TextFormField(
                            key: ValueKey('feed_qty_${idx}_$currentPid'),
                            initialValue: qty > 0 ? qty.toStringAsFixed(1) : '',
                            decoration: InputDecoration(
                              labelText: 'SL xuất (${item['unit'] ?? 'kg'})',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              helperText: prod != null ? 'Tồn: ${_smartQty(stock)}' : null,
                              helperStyle: TextStyle(fontSize: 11, color: overStock ? AppColors.error : null),
                              errorText: overStock ? 'Vượt tồn kho!' : (zeroQty && prod != null ? 'Nhập SL > 0' : null),
                              errorStyle: const TextStyle(fontSize: 11),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => ss(() => item['qty'] = double.tryParse(v) ?? 0),
                          )),
                          const SizedBox(width: 8),
                          Expanded(child: TextFormField(
                            key: ValueKey('feed_price_${idx}_$currentPid'),
                            initialValue: ((item['unitPrice'] as num?) ?? 0) > 0 ? (item['unitPrice'] as num).toString() : '',
                            decoration: const InputDecoration(labelText: 'Đơn giá (vốn)', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => ss(() => item['unitPrice'] = double.tryParse(v) ?? 0),
                          )),
                        ]),
                      ]),
                    );
                  }),
                  if (hasOverStock)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 4),
                      child: Row(children: [
                        const Icon(Icons.warning_rounded, size: 16, color: AppColors.warning),
                        const SizedBox(width: 6),
                        const Expanded(child: Text('Có sản phẩm xuất vượt tồn kho', style: TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.w600))),
                      ]),
                    ),
                  const Divider(),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    const Text('Tổng giá trị: ', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('${_currFmt.format(total.round())}đ', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.warning)),
                  ]),
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Huỷ')),
              FilledButton.icon(
                onPressed: canSubmit ? () => Navigator.pop(dCtx, true) : null,
                icon: const Icon(Icons.outbox_rounded),
                label: const Text('Tạo phiếu xuất'),
              ),
            ],
          );
        },
      ),
    );

    if (ok == true) {
      // Auto-generate stock issue code
      final existingCodes = dp.stockIssues.map((si) => si.code).toList();
      int maxNum = 0;
      for (final c in existingCodes) {
        final m = RegExp(r'XK-(\d+)').firstMatch(c);
        if (m != null) {
          final n = int.tryParse(m.group(1)!) ?? 0;
          if (n > maxNum) maxNum = n;
        }
      }
      final issueCode = 'XK-${(maxNum + 1).toString().padLeft(3, '0')}';

      double total = 0;
      for (final item in lineItems) {
        total += ((item['qty'] as num?) ?? 0) * ((item['unitPrice'] as num?) ?? 0);
      }
      final batchId = batches.isNotEmpty ? batches.map((b) => b.id).join(',') : '';

      await dp.create('stockissues', {
        'code': issueCode,
        'date': selectedDate.toIso8601String(),
        'type': 'feeding',
        'pondId': pond.id,
        'fishBatchId': batchId,
        'branchId': branchId,
        'items': lineItems,
        'totalAmount': total,
        'status': 'draft',
        'note': () {
          final parts = <String>['Cho cá ăn Ao ${pond.code}'];
          for (final b in batches) {
            final sp = dp.speciesById(b.speciesId);
            final qtyInPond = b.quantityInPond(pond.id);
            final weight = b.currentWeight > 0 ? b.currentWeight : b.initialWeight;
            final size = b.currentSize > 0 ? b.currentSize : b.initialSize;
            parts.add('${sp?.name ?? "?"}: SL $qtyInPond con, TL: ${weight.toStringAsFixed(0)}g, KT: ${size.toStringAsFixed(1)}cm');
          }
          if (noteC.text.isNotEmpty) parts.add(noteC.text);
          return parts.join(', ');
        }(),
        'createdBy': '',
        'issuedTo': issuedTo ?? '',
      });
      _showSnack('Đã tạo phiếu xuất kho $issueCode. Chờ duyệt để xuất kho cho ăn.');
    }
  }

  // 3.5) HAO HỤT CÁ
  static const _mortalityCauses = [
    'Bệnh (vi khuẩn)',
    'Bệnh (ký sinh trùng)',
    'Bệnh (virus)',
    'Bệnh (nấm)',
    'Chất lượng nước kém',
    'Thiếu oxy',
    'Thời tiết bất thường',
    'Stress vận chuyển',
    'Cá ăn nhau',
    'Ngộ độc (hóa chất/thuốc)',
    'Tảo nở hoa',
    'Thoát ra ngoài',
    'Không rõ nguyên nhân',
    'Khác',
  ];

  Future<void> _showMortalityDialog(Pond pond, List<FishBatch> batches) async {
    final qtyC = TextEditingController();
    final noteC = TextEditingController();
    String? selectedBatchId = batches.length == 1 ? batches.first.id : null;
    String cause = _mortalityCauses.last;
    DateTime selectedDate = DateTime.now();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, ss) {
          final selBatch = batches.where((b) => b.id == selectedBatchId).firstOrNull;
          final maxQty = selBatch?.quantityInPond(pond.id) ?? 0;

          return AlertDialog(
            title: Row(children: [
              const Icon(Icons.heart_broken_rounded, color: AppColors.error),
              const SizedBox(width: 8),
              Text('Ghi nhận hao hụt – ${pond.code}'),
            ]),
            content: SizedBox(
              width: AppSizes.dialogWidth(context, 480),
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Ngày ghi nhận
                  InkWell(
                    onTap: () async {
                      final d = await showDatePicker(context: dCtx, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                      if (d != null) {
                        final t = await showTimePicker(context: dCtx, initialTime: TimeOfDay.fromDateTime(selectedDate));
                        ss(() => selectedDate = DateTime(d.year, d.month, d.day, t?.hour ?? selectedDate.hour, t?.minute ?? selectedDate.minute));
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Ngày giờ ghi nhận', prefixIcon: Icon(Icons.calendar_today)),
                      child: Text(DateFormat('dd/MM/yyyy HH:mm').format(selectedDate)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Chọn lô cá
                  if (batches.length > 1)
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Lô cá', prefixIcon: Icon(Icons.set_meal)),
                      items: batches.map((b) {
                        final sp = dp.speciesById(b.speciesId);
                        final qtyInPond = b.quantityInPond(pond.id);
                        return DropdownMenuItem(value: b.id, child: Text('${sp?.name ?? '?'} ($qtyInPond con)', overflow: TextOverflow.ellipsis));
                      }).toList(),
                      onChanged: (v) => ss(() => selectedBatchId = v),
                    )
                  else if (selBatch != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primary.withAlpha(40)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.set_meal, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(dp.speciesById(selBatch.speciesId)?.name ?? '?', style: const TextStyle(fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text('${selBatch.quantityInPond(pond.id)} con trong ao', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Nguyên nhân
                  DropdownButtonFormField<String>(
                    value: cause,
                    decoration: const InputDecoration(labelText: 'Nguyên nhân hao hụt', prefixIcon: Icon(Icons.bug_report)),
                    items: _mortalityCauses.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => ss(() => cause = v ?? cause),
                  ),
                  const SizedBox(height: 12),

                  // Số lượng
                  TextField(
                    controller: qtyC,
                    decoration: InputDecoration(
                      labelText: 'Số lượng hao hụt (con)',
                      prefixIcon: const Icon(Icons.numbers),
                      helperText: maxQty > 0 ? 'Tối đa: $maxQty con trong ao ${pond.code}' : null,
                      helperStyle: const TextStyle(fontSize: 11),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),

                  // Ghi chú
                  TextField(
                    controller: noteC,
                    decoration: const InputDecoration(labelText: 'Ghi chú / triệu chứng', prefixIcon: Icon(Icons.note)),
                    maxLines: 2,
                  ),

                  // Cảnh báo 
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withAlpha(15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(children: [
                      Icon(Icons.info_outline, size: 14, color: AppColors.warning),
                      SizedBox(width: 8),
                      Expanded(child: Text('Số lượng cá trong ao và lô sẽ tự động giảm sau khi ghi nhận.', style: TextStyle(fontSize: 11, color: AppColors.warning))),
                    ]),
                  ),
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Huỷ')),
              FilledButton.icon(
                onPressed: () {
                  if (selectedBatchId == null) {
                    ScaffoldMessenger.of(dCtx).showSnackBar(const SnackBar(content: Text('Chọn lô cá'), backgroundColor: Colors.red));
                    return;
                  }
                  final qty = int.tryParse(qtyC.text) ?? 0;
                  if (qty <= 0) {
                    ScaffoldMessenger.of(dCtx).showSnackBar(const SnackBar(content: Text('Số lượng phải > 0'), backgroundColor: Colors.red));
                    return;
                  }
                  // Validate max quantity
                  final selBatch = batches.where((b) => b.id == selectedBatchId).firstOrNull;
                  if (selBatch != null) {
                    final maxInPond = selBatch.quantityInPond(pond.id);
                    if (qty > maxInPond) {
                      ScaffoldMessenger.of(dCtx).showSnackBar(SnackBar(content: Text('Tối đa $maxInPond con trong ao ${pond.code}'), backgroundColor: Colors.red));
                      return;
                    }
                  }
                  Navigator.pop(dCtx, true);
                },
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                icon: const Icon(Icons.heart_broken),
                label: const Text('Ghi nhận hao hụt'),
              ),
            ],
          );
        },
      ),
    );

    if (ok == true && selectedBatchId != null) {
      final mortQty = int.tryParse(qtyC.text) ?? 0;
      if (mortQty <= 0) return;
      await dp.createMortalityLog({
        'fishBatchId': selectedBatchId,
        'pondId': pond.id,
        'quantity': mortQty,
        'cause': cause,
        'note': noteC.text.isNotEmpty ? '${pond.code}: ${noteC.text}' : 'Hao hụt ${pond.code}',
        'date': selectedDate.toIso8601String(),
      });
      _showSnack('Đã ghi nhận hao hụt $mortQty con tại ao ${pond.code}');
    }
  }

  // 4) ĐO THÔNG SỐ NƯỚC
  Future<void> _showMeasureWaterDialog(Pond pond) async {
    final phC = TextEditingController(text: pond.currentPh?.toString() ?? '');
    final doC = TextEditingController(text: pond.currentDo?.toString() ?? '');
    final nh3C = TextEditingController(text: pond.currentNh3?.toString() ?? '');
    final tempC = TextEditingController(text: pond.currentTemp?.toString() ?? '');
    final alkC = TextEditingController(text: pond.currentAlkalinity?.toString() ?? '');
    final noteC = TextEditingController();

    // Find species for threshold hints
    final batches = dp.batchesForPond(pond.id).where((b) => b.status == 'active').toList();
    Species? species;
    for (final b in batches) {
      species = dp.speciesById(b.speciesId);
      if (species != null) break;
    }

    // Employee list for picker
    final emps = dp.employees;
    String? selectedEmpId = pond.measuredBy.isNotEmpty ? pond.measuredBy : null;
    DateTime selectedDate = DateTime.now();

    // History records for this pond
    final history = dp.sensorReadings
        .where((r) => r.pondId == pond.id)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Tab tracking
    int tabIndex = 0;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (sCtx, setSt) {
          // Build species threshold hint for each param
          String phHint = '6.5 – 8.5';
          String doHint = '≥ 4 mg/L';
          String nh3Hint = '< 0.1 mg/L';
          String tempHint = '26 – 32°C';
          if (species != null) {
            final sp = species;
            phHint = 'Tối ưu: ${sp.requiredPh}';
            doHint = '≥ ${sp.requiredDo} mg/L';
            nh3Hint = '< ${sp.maxNh3} mg/L';
            tempHint = '${sp.minTemp} – ${sp.maxTemp}°C';
          }

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.science_rounded, color: Color(0xFF7C4DFF)),
                const SizedBox(width: 8),
                Expanded(child: Text('Đo nước – ${pond.code}')),
              ],
            ),
            content: SizedBox(
              width: AppSizes.dialogWidth(context, 600),
              height: 500,
              child: Column(
                children: [
                  // Species info banner
                  if (species != null)
                    Builder(builder: (_) {
                      final sp = species!;
                      return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C4DFF).withAlpha(15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF7C4DFF).withAlpha(40)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.pets, size: 16, color: Color(0xFF7C4DFF)),
                          const SizedBox(width: 6),
                          Text('Loài: ${sp.name}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF7C4DFF))),
                          const Spacer(),
                          Text('pH ${sp.requiredPh} • DO ≥${sp.requiredDo} • NH₃ <${sp.maxNh3} • ${sp.minTemp}–${sp.maxTemp}°C',
                            style: TextStyle(fontSize: 11, color: const Color(0xFF7C4DFF).withAlpha(180))),
                        ],
                      ),
                    );
                    }),

                  // Tab bar
                  Row(
                    children: [
                      _TabBtn('Đo mới', Icons.add_circle_outline, tabIndex == 0, () => setSt(() => tabIndex = 0)),
                      const SizedBox(width: 8),
                      _TabBtn('Lịch sử (${history.length})', Icons.history, tabIndex == 1, () => setSt(() => tabIndex = 1)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Tab content
                  Expanded(
                    child: tabIndex == 0
                      ? SingleChildScrollView(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            // Ngày đo
                            InkWell(
                              onTap: () async {
                                final d = await showDatePicker(context: dCtx, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                                if (d != null) {
                                  final t = await showTimePicker(context: dCtx, initialTime: TimeOfDay.fromDateTime(selectedDate));
                                  setSt(() => selectedDate = DateTime(d.year, d.month, d.day, t?.hour ?? selectedDate.hour, t?.minute ?? selectedDate.minute));
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: InputDecorator(
                                decoration: const InputDecoration(labelText: 'Ngày giờ đo', prefixIcon: Icon(Icons.calendar_today)),
                                child: Text(DateFormat('dd/MM/yyyy HH:mm').format(selectedDate)),
                              ),
                            ),
                            const SizedBox(height: 14),
                            // Employee picker
                            DropdownButtonFormField<String>(
                              value: selectedEmpId,
                              decoration: const InputDecoration(
                                labelText: 'Người đo *',
                                prefixIcon: Icon(Icons.person),
                                border: OutlineInputBorder(),
                              ),
                              items: emps.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
                              onChanged: (v) => setSt(() => selectedEmpId = v),
                            ),
                            const SizedBox(height: 14),

                            // Water params in 2-column grid
                            Row(children: [
                              Expanded(child: TextField(
                                controller: phC,
                                decoration: InputDecoration(
                                  labelText: 'pH',
                                  prefixIcon: const Icon(Icons.opacity),
                                  helperText: phHint,
                                  helperStyle: TextStyle(color: _paramColor(phC.text, 'pH', species), fontWeight: FontWeight.w600),
                                  border: const OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setSt(() {}),
                              )),
                              const SizedBox(width: 10),
                              Expanded(child: TextField(
                                controller: doC,
                                decoration: InputDecoration(
                                  labelText: 'DO (mg/L)',
                                  prefixIcon: const Icon(Icons.air),
                                  helperText: doHint,
                                  helperStyle: TextStyle(color: _paramColor(doC.text, 'DO', species), fontWeight: FontWeight.w600),
                                  border: const OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setSt(() {}),
                              )),
                            ]),
                            const SizedBox(height: 14),
                            Row(children: [
                              Expanded(child: TextField(
                                controller: nh3C,
                                decoration: InputDecoration(
                                  labelText: 'NH₃ (mg/L)',
                                  prefixIcon: const Icon(Icons.science),
                                  helperText: nh3Hint,
                                  helperStyle: TextStyle(color: _paramColor(nh3C.text, 'NH3', species), fontWeight: FontWeight.w600),
                                  border: const OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setSt(() {}),
                              )),
                              const SizedBox(width: 10),
                              Expanded(child: TextField(
                                controller: tempC,
                                decoration: InputDecoration(
                                  labelText: 'Nhiệt độ (°C)',
                                  prefixIcon: const Icon(Icons.thermostat),
                                  helperText: tempHint,
                                  helperStyle: TextStyle(color: _paramColor(tempC.text, 'temp', species), fontWeight: FontWeight.w600),
                                  border: const OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setSt(() {}),
                              )),
                            ]),
                            const SizedBox(height: 14),
                            Row(children: [
                              Expanded(child: TextField(
                                controller: alkC,
                                decoration: const InputDecoration(
                                  labelText: 'Độ kiềm (mg/L)',
                                  prefixIcon: Icon(Icons.waves),
                                  helperText: '60 – 180 mg/L',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                              )),
                              const SizedBox(width: 10),
                              Expanded(child: TextField(
                                controller: noteC,
                                decoration: const InputDecoration(
                                  labelText: 'Ghi chú',
                                  prefixIcon: Icon(Icons.note),
                                  border: OutlineInputBorder(),
                                ),
                              )),
                            ]),
                          ]),
                        )
                      : _buildMeasurementHistory(history, emps),
                  ),
                ],
              ),
            ),
            actions: tabIndex == 0
              ? [
                  TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Huỷ')),
                  FilledButton.icon(
                    onPressed: selectedEmpId == null ? null : () => Navigator.pop(dCtx, true),
                    icon: const Icon(Icons.check),
                    label: const Text('Lưu'),
                  ),
                ]
              : [TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Đóng'))],
          );
        },
      ),
    );

    if (ok == true) {
      final updatedData = Map<String, dynamic>.from(pond.toJson());
      final phVal = double.tryParse(phC.text);
      final doVal = double.tryParse(doC.text);
      final nh3Val = double.tryParse(nh3C.text);
      final tempVal = double.tryParse(tempC.text);
      final alkVal = double.tryParse(alkC.text);
      if (phVal != null) updatedData['currentPh'] = phVal;
      if (doVal != null) updatedData['currentDo'] = doVal;
      if (nh3Val != null) updatedData['currentNh3'] = nh3Val;
      if (tempVal != null) updatedData['currentTemp'] = tempVal;
      if (alkVal != null) updatedData['currentAlkalinity'] = alkVal;
      updatedData['measuredBy'] = selectedEmpId ?? '';
      await dp.update('ponds', pond.id, updatedData);

      // Save sensor reading history
      final auth = context.read<AuthProvider>();
      await dp.create('sensorreadings', {
        'pondId': pond.id,
        'storeId': auth.user?.storeId ?? '',
        'pH': double.tryParse(phC.text),
        'oxygen': double.tryParse(doC.text),
        'nh3': double.tryParse(nh3C.text),
        'temperature': double.tryParse(tempC.text),
        'alkalinity': double.tryParse(alkC.text),
        'measuredBy': selectedEmpId ?? '',
        'note': noteC.text.trim(),
        'timestamp': selectedDate.toIso8601String(),
      });

      // Create water_check task record
      final empName = emps.where((e) => e.id == selectedEmpId).map((e) => e.name).firstOrNull ?? '';
      await dp.create('tasks', {
        'title': 'Đo nước ${pond.code} – pH:${phC.text} DO:${doC.text} NH₃:${nh3C.text} T:${tempC.text}°C',
        'type': 'water_check',
        'assignedTo': selectedEmpId ?? '',
        'pondId': pond.id,
        'dueDate': selectedDate.toIso8601String(),
        'status': 'done',
        'note': 'Người đo: $empName${noteC.text.isNotEmpty ? ' • ${noteC.text}' : ''}',
      });
      _showSnack('Đã cập nhật thông số nước ${pond.code}');
    }
  }

  /// Realtime color feedback for water param input
  Color _paramColor(String text, String param, Species? sp) {
    final val = double.tryParse(text);
    if (val == null || sp == null) return AppColors.textHint;
    switch (param) {
      case 'pH':
        final diff = (val - sp.requiredPh).abs();
        return diff > 1.5 ? AppColors.error : diff > 0.8 ? AppColors.warning : AppColors.success;
      case 'DO':
        return val < sp.requiredDo * 0.6 ? AppColors.error : val < sp.requiredDo ? AppColors.warning : AppColors.success;
      case 'NH3':
        return val > sp.maxNh3 * 2 ? AppColors.error : val > sp.maxNh3 ? AppColors.warning : AppColors.success;
      case 'temp':
        if (val < sp.minTemp || val > sp.maxTemp) return AppColors.error;
        return (val - sp.requiredTemp).abs() > 3 ? AppColors.warning : AppColors.success;
      default:
        return AppColors.textHint;
    }
  }

  /// Build measurement history list
  Widget _buildMeasurementHistory(List<SensorReading> history, List<Employee> emps) {
    if (history.isEmpty) {
      return const Center(child: Text('Chưa có lịch sử đo nước', style: TextStyle(color: AppColors.textHint)));
    }
    return ListView.separated(
      itemCount: history.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final r = history[i];
        final emp = emps.where((e) => e.id == r.measuredBy).firstOrNull;
        return ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withAlpha(20),
            child: const Icon(Icons.science, size: 18, color: AppColors.primary),
          ),
          title: Row(
            children: [
              if (r.pH != null) _HistChip('pH', r.pH!.toStringAsFixed(1), Icons.opacity),
              if (r.oxygen != null) _HistChip('DO', r.oxygen!.toStringAsFixed(1), Icons.air),
              if (r.nh3 != null) _HistChip('NH₃', r.nh3!.toStringAsFixed(2), Icons.science),
              if (r.temperature != null) _HistChip('T', '${r.temperature!.toStringAsFixed(0)}°', Icons.thermostat),
              if (r.alkalinity != null) _HistChip('Kiềm', r.alkalinity!.toStringAsFixed(0), Icons.waves),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(Icons.person_outline, size: 13, color: AppColors.textHint),
                const SizedBox(width: 3),
                Text(emp?.name ?? 'Không rõ', style: const TextStyle(fontSize: 12)),
                const Spacer(),
                Icon(Icons.access_time, size: 13, color: AppColors.textHint),
                const SizedBox(width: 3),
                Text(DateFormat('dd/MM/yyyy HH:mm').format(r.timestamp),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        );
      },
    );
  }

  // 5) XUẤT BÁN
  Future<void> _showSellDialog(Pond pond, List<FishBatch> batches) async {
    FishBatch? selectedBatch = batches.first;
    String? customerId = dp.customers.isNotEmpty ? dp.customers.first.id : null;
    String customerName = dp.customers.isNotEmpty ? dp.customers.first.name : '';
    final custTextC = TextEditingController(text: customerName);
    final qtyC = TextEditingController();
    final priceC = TextEditingController();
    final noteC = TextEditingController();

    // Helper: lấy size info cho batch đang chọn
    String _sizeInfo(FishBatch b) {
      final w = b.currentWeight > 0 ? b.currentWeight : b.initialWeight; // gram
      final s = b.currentSize > 0 ? b.currentSize : b.initialSize;       // cm
      if (w <= 0 && s <= 0) return 'Chưa có dữ liệu size';
      final parts = <String>[];
      if (w > 0) parts.add('${w.toStringAsFixed(0)}g');
      if (s > 0) parts.add('${s.toStringAsFixed(1)}cm');
      return parts.join(' – ');
    }

    // Số ngày nuôi trong ao
    int _pondDays(FishBatch b) {
      return DateTime.now().difference(b.stockingDate).inDays;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, ss) {
          final batch = selectedBatch;
          final weightG = batch != null ? (batch.currentWeight > 0 ? batch.currentWeight : batch.initialWeight) : 0.0;
          final qtyInPond = batch?.quantityInPond(pond.id) ?? 0;
          return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.shopping_bag_rounded, color: AppColors.secondary),
              const SizedBox(width: 8),
              Expanded(child: Text('Xuất bán từ ${pond.code}', overflow: TextOverflow.ellipsis)),
            ],
          ),
          content: SizedBox(
            width: AppSizes.dialogWidth(context, 500),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                initialValue: selectedBatch?.id,
                decoration: const InputDecoration(labelText: 'Lô cá', prefixIcon: Icon(Icons.set_meal)),
                items: batches.map((b) {
                  final sp = dp.speciesById(b.speciesId);
                  final label = b.name.isNotEmpty ? '${b.name} (${sp?.name ?? '?'})' : (sp?.name ?? '?');
                  return DropdownMenuItem(value: b.id, child: Text('$label (${b.quantityInPond(pond.id)} con)'));
                }).toList(),
                onChanged: (v) => ss(() => selectedBatch = batches.firstWhere((b) => b.id == v)),
              ),
              // ── Thông tin size cá & ngày nuôi ──
              if (batch != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.info.withAlpha(15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.info.withAlpha(40)),
                  ),
                  child: Column(children: [
                    Row(children: [
                      const Icon(Icons.straighten, size: 15, color: AppColors.info),
                      const SizedBox(width: 6),
                      Text('Size: ${_sizeInfo(batch)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('${weightG > 0 ? (weightG / 1000).toStringAsFixed(2) : '?'} kg/con', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.calendar_today, size: 15, color: AppColors.info),
                      const SizedBox(width: 6),
                      Text('Ngày nuôi: ${_pondDays(batch)} ngày', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('Thả: ${DateFormat('dd/MM/yyyy').format(batch.stockingDate)}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ]),
                  ]),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: qtyC,
                decoration: InputDecoration(
                  labelText: 'Số lượng bán (con)',
                  prefixIcon: const Icon(Icons.format_list_numbered),
                  helperText: 'Tối đa: ${_currFmt.format(qtyInPond)} con trong ao',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(controller: priceC, decoration: const InputDecoration(labelText: 'Đơn giá (VNĐ/con)', prefixIcon: Icon(Icons.attach_money)), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              // Khách hàng: Autocomplete tìm kiếm, chưa có thì thêm mới
              Autocomplete<String>(
                initialValue: custTextC.value,
                optionsBuilder: (textEditingValue) {
                  final query = textEditingValue.text.toLowerCase();
                  if (query.isEmpty) return dp.customers.map((c) => c.name);
                  return dp.customers
                      .where((c) => c.name.toLowerCase().contains(query))
                      .map((c) => c.name);
                },
                fieldViewBuilder: (ctx2, controller, focusNode, onSubmitted) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Khách hàng',
                      prefixIcon: Icon(Icons.person),
                      hintText: 'Tìm hoặc nhập tên KH mới',
                    ),
                    onChanged: (v) => ss(() {
                      custTextC.text = v;
                      // Match existing customer
                      final match = dp.customers.where((c) => c.name.toLowerCase() == v.toLowerCase().trim()).firstOrNull;
                      customerId = match?.id;
                      customerName = v;
                    }),
                  );
                },
                onSelected: (name) => ss(() {
                  final match = dp.customers.firstWhere((c) => c.name == name);
                  customerId = match.id;
                  customerName = name;
                  custTextC.text = name;
                }),
              ),
              const SizedBox(height: 12),
              TextField(controller: noteC, decoration: const InputDecoration(labelText: 'Ghi chú', prefixIcon: Icon(Icons.note)), maxLines: 2),
            ]),
          ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Huỷ')),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dCtx, true),
              icon: const Icon(Icons.sell),
              label: const Text('Xuất bán'),
            ),
          ],
        );
        },
      ),
    );

    if (ok == true && selectedBatch != null && qtyC.text.isNotEmpty) {
      final sellQty = int.tryParse(qtyC.text) ?? 0;
      final batch = selectedBatch!;
      final qtyInPond = batch.quantityInPond(pond.id);
      if (sellQty <= 0 || sellQty > qtyInPond) {
        _showSnack('Số lượng không hợp lệ (tối đa $qtyInPond con)');
        return;
      }

      // Handle customer: create new if not matched existing
      String? finalCustomerId = customerId;
      if (finalCustomerId == null) {
        final newName = customerName.trim().isNotEmpty ? customerName.trim() : custTextC.text.trim();
        if (newName.isEmpty) {
          _showSnack('Vui lòng nhập tên khách hàng');
          return;
        }
        // Check one more time if name matches existing
        final match = dp.customers.where((c) => c.name.toLowerCase() == newName.toLowerCase()).firstOrNull;
        if (match != null) {
          finalCustomerId = match.id;
        } else {
          // Auto-create customer
          final countBefore = dp.customers.length;
          final ok2 = await dp.create('customers', {
            'name': newName,
            'phone': '',
            'email': '',
            'address': '',
            'debt': 0,
          });
          if (ok2 && dp.customers.length > countBefore) {
            finalCustomerId = dp.customers.last.id;
          } else {
            _showSnack('Không thể tạo khách hàng');
            return;
          }
        }
      }

      final unitPrice = double.tryParse(priceC.text) ?? 0;
      // Tính theo con: totalAmount = số lượng × đơn giá/con
      final totalAmount = sellQty * unitPrice;
      final speciesName = dp.speciesById(batch.speciesId)?.name ?? 'Cá';

      // Create sale order (backend handles fishBatch deduction + stock issue + payment voucher via _onSaleCompleted)
      await dp.create('saleorders', {
        'customerId': finalCustomerId,
        'date': DateTime.now().toIso8601String(),
        'pondId': pond.id,
        'fishBatchId': batch.id,
        'items': [{'speciesId': batch.speciesId, 'fishBatchId': batch.id, 'productName': speciesName, 'qty': sellQty, 'unitPrice': unitPrice}],
        'totalAmount': totalAmount,
        'status': 'completed',
        'note': noteC.text.trim(),
      });

      // Reload data to get backend-updated fishBatch and products
      await Future.wait([dp.reload('fishbatches'), dp.reload('products'), dp.reload('stockissues'), dp.reload('saleorders'), dp.reload('ponds'), dp.reload('paymentvouchers')]);

      _showSnack('Xuất bán $sellQty con – ${_currFmt.format(totalAmount)}đ');
    }
  }

  // ═══ LỊCH SỬ CHO ĂN THEO AO / LÔ ═══
  void _showFeedingHistoryDialog(Pond pond) {
    final dateFmt = DateFormat('dd/MM/yyyy');
    final timeFmt = DateFormat('HH:mm');

    // Lấy tất cả phiếu xuất kho cho ăn liên quan đến ao này
    final feedIssues = dp.stockIssues
        .where((si) => si.type == 'feeding' && si.pondId == pond.id)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    // Lấy feeding logs
    final feedLogs = dp.feedingLogs
        .where((l) => l['pondId'] == pond.id)
        .toList()
      ..sort((a, b) {
        final da = DateTime.tryParse(a['date'] as String? ?? '') ?? DateTime(2000);
        final db = DateTime.tryParse(b['date'] as String? ?? '') ?? DateTime(2000);
        return db.compareTo(da);
      });

    // Lấy batch IDs liên quan
    final activeBatches = dp.batchesForPond(pond.id);
    final batchMap = <String, String>{};
    for (final b in activeBatches) {
      final sp = dp.speciesById(b.speciesId);
      batchMap[b.id] = b.name.isNotEmpty ? b.name : (sp?.name ?? 'Lô #${b.id.substring(0, 6)}');
    }

    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.history_rounded, color: AppColors.success),
          const SizedBox(width: 8),
          Expanded(child: Text('Lịch sử cho ăn – ${pond.code}', overflow: TextOverflow.ellipsis)),
        ]),
        content: SizedBox(
          width: AppSizes.dialogWidth(context, 600),
          height: MediaQuery.of(context).size.height * 0.7,
          child: feedIssues.isEmpty && feedLogs.isEmpty
              ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.restaurant_rounded, size: 48, color: AppColors.textHint),
                  SizedBox(height: 8),
                  Text('Chưa có lịch sử cho ăn', style: TextStyle(color: AppColors.textHint)),
                ]))
              : ListView.builder(
                  itemCount: feedIssues.length,
                  itemBuilder: (_, i) {
                    final si = feedIssues[i];
                    final batchName = si.fishBatchId.isNotEmpty
                        ? (si.fishBatchId.contains(',')
                            ? si.fishBatchId.split(',').map((id) => batchMap[id] ?? id.substring(0, 6)).join(', ')
                            : batchMap[si.fishBatchId] ?? si.fishBatchId)
                        : 'Tất cả lô';
                    final itemsStr = si.items.map((it) => '${it['productName'] ?? 'SP'} × ${it['qty']} ${it['unit'] ?? 'kg'}').join(', ');
                    final total = si.totalAmount;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: si.status == 'approved' ? AppColors.success.withAlpha(20) : AppColors.warning.withAlpha(20),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.restaurant_rounded, size: 18, color: si.status == 'approved' ? AppColors.success : AppColors.warning),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(si.code, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              Text(batchName, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ])),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text('${dateFmt.format(si.date)} ${timeFmt.format(si.date)}', style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                              Text(_statusLabel(si.status), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: si.status == 'approved' ? AppColors.success : AppColors.warning)),
                            ]),
                          ]),
                          const SizedBox(height: 8),
                          // Chi tiết sản phẩm
                          ...si.items.map((it) => Padding(
                            padding: const EdgeInsets.only(left: 44, bottom: 2),
                            child: Row(children: [
                              Expanded(child: Text('${it['productName'] ?? 'SP'}', style: const TextStyle(fontSize: 12))),
                              Text('${it['qty']} ${it['unit'] ?? 'kg'}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ]),
                          )),
                          if (total > 0)
                            Padding(
                              padding: const EdgeInsets.only(left: 44, top: 4),
                              child: Text('Giá trị: ${_currFmt.format(total.round())}đ', style: const TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600)),
                            ),
                          // Nhân viên
                          if (si.issuedTo.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(left: 44, top: 2),
                              child: Text('NV: ${dp.employeeById(si.issuedTo)?.name ?? si.issuedTo}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ),
                          ],
                        ]),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Đóng')),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved': return 'Đã duyệt';
      case 'draft': return 'Chờ duyệt';
      case 'confirmed': return 'Đã xác nhận';
      case 'cancelled': return 'Đã huỷ';
      default: return status;
    }
  }

  // 6) BẢO TRÌ
  static const _maintenanceCategories = <String, List<String>>{
    'Vệ sinh': ['Vét bùn đáy ao', 'Rửa bạt HDPE', 'Dọn rong rêu', 'Vệ sinh cống thoát', 'Vệ sinh ống cấp nước'],
    'Sửa chữa': ['Vá bạt rách', 'Sửa bờ ao', 'Sửa cống cấp/thoát', 'Thay van nước', 'Sửa hệ thống sục khí'],
    'Xử lý nước': ['Khử trùng ao', 'Xử lý phèn', 'Bón vôi', 'Cấp nước mới', 'Xả nước cũ'],
    'Thiết bị': ['Kiểm tra quạt nước', 'Kiểm tra máy sục khí', 'Kiểm tra máy bơm', 'Thay thiết bị hỏng'],
    'Khác': ['Kiểm tra bờ ao', 'Phơi đáy ao', 'Lắp lưới chắn', 'Đo thông số nước'],
  };

  Future<void> _showMaintenanceDialog(Pond pond) async {
    // If pond is already in maintenance, show progress dialog
    if (pond.status == 'maintenance') {
      final activeLog = dp.activeMaintenanceForPond(pond.id);
      if (activeLog != null) {
        _showMaintenanceProgressDialog(pond, activeLog);
      } else {
        // No active log, just toggle off
        await dp.update('ponds', pond.id, {...pond.toJson(), 'status': 'inactive'});
        _showSnack('${pond.code} đã kết thúc bảo trì');
      }
      return;
    }

    // Show start maintenance dialog
    final selectedItems = <Map<String, String>>[];
    final selectedMaterials = <Map<String, dynamic>>[];
    final noteCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final chemicals = dp.products.where((p) => ['chemical', 'medicine', 'tool', 'accessory'].contains(p.category)).toList();

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.build_rounded, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(child: Text('Bảo trì ${pond.code}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
              ],
            ),
            content: SizedBox(
              width: AppSizes.dialogWidth(context, 520),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── SECTION 1: Maintenance checklist ──
                    const Text('📋 Hạng mục bảo trì', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ..._maintenanceCategories.entries.map((cat) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 4),
                            child: Text(cat.key, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                          ),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: cat.value.map((item) {
                              final isSelected = selectedItems.any((s) => s['name'] == item);
                              return FilterChip(
                                label: Text(item, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : AppColors.textPrimary)),
                                selected: isSelected,
                                onSelected: (v) {
                                  setSt(() {
                                    if (v) {
                                      selectedItems.add({'name': item, 'category': cat.key});
                                    } else {
                                      selectedItems.removeWhere((s) => s['name'] == item);
                                    }
                                  });
                                },
                                selectedColor: AppColors.primary,
                                checkmarkColor: Colors.white,
                                backgroundColor: Colors.grey.shade100,
                              );
                            }).toList(),
                          ),
                        ],
                      );
                    }),

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),

                    // ── SECTION 2: Materials ──
                    const Text('🧪 Vật tư bảo trì', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    if (selectedMaterials.isNotEmpty) ...[
                      ...selectedMaterials.asMap().entries.map((entry) {
                        final m = entry.value;
                        final prod = dp.products.firstWhere((p) => p.id == m['productId'], orElse: () => dp.products.first);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text('${prod.name} (tồn: ${prod.stock} ${prod.unit})', style: const TextStyle(fontSize: 13)),
                              ),
                              SizedBox(
                                width: 80,
                                child: TextFormField(
                                  initialValue: '${m['quantity']}',
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), labelText: 'SL'),
                                  onChanged: (v) => selectedMaterials[entry.key]['quantity'] = double.tryParse(v) ?? 0,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle, color: AppColors.error, size: 22),
                                onPressed: () => setSt(() => selectedMaterials.removeAt(entry.key)),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 6),
                    ],
                    if (chemicals.isNotEmpty)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Thêm vật tư', style: TextStyle(fontSize: 13)),
                        onPressed: () async {
                          final available = chemicals.where((p) => !selectedMaterials.any((m) => m['productId'] == p.id)).toList();
                          if (available.isEmpty) return;
                          final prod = await showDialog<dynamic>(
                            context: ctx,
                            builder: (c) => SimpleDialog(
                              title: const Text('Chọn vật tư'),
                              children: available.map((p) => SimpleDialogOption(
                                onPressed: () => Navigator.pop(c, p),
                                child: Text('${p.name} (${p.category == "chemical" ? "Hoá chất" : p.category == "medicine" ? "Thuốc" : p.category == "tool" ? "Dụng cụ" : "Phụ kiện"}) – tồn: ${p.stock} ${p.unit}'),
                              )).toList(),
                            ),
                          );
                          if (prod != null) {
                            setSt(() => selectedMaterials.add({'productId': prod.id, 'quantity': 1.0}));
                          }
                        },
                      ),

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),

                    // ── SECTION 3: Note ──
                    const Text('📝 Ghi chú', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: noteCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Ghi chú thêm về đợt bảo trì...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
              FilledButton.icon(
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: Text('Bắt đầu bảo trì (${selectedItems.length} hạng mục)'),
                onPressed: selectedItems.isEmpty ? null : () => Navigator.pop(ctx, true),
              ),
            ],
          );
        },
      ),
    );

    if (result != true) return;

    final log = await dp.startMaintenance({
      'pondId': pond.id,
      'items': selectedItems,
      'materials': selectedMaterials,
      'note': noteCtrl.text,
    });

    noteCtrl.dispose();

    if (log != null) {
      _showSnack('${pond.code} đã chuyển sang bảo trì – ${selectedItems.length} hạng mục');
    } else {
      _showSnack('Lỗi khi tạo bảo trì');
    }
  }

  // ── Maintenance progress dialog ──
  Future<void> _showMaintenanceProgressDialog(Pond pond, Map<String, dynamic> log) async {
    final items = List<Map<String, dynamic>>.from(log['items'] ?? []);
    final materials = List<Map<String, dynamic>>.from(log['materials'] ?? []);
    final startDate = log['startedAt'] != null ? DateTime.tryParse(log['startedAt']) : null;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final currentDone = items.where((it) => it['status'] == 'done').length;
          final currentProgress = items.isNotEmpty ? currentDone / items.length : 0.0;

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.engineering_rounded, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(child: Text('Tiến độ bảo trì ${pond.code}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
              ],
            ),
            content: SizedBox(
              width: AppSizes.dialogWidth(context, 480),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Progress bar ──
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: currentProgress,
                              minHeight: 12,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation(
                                currentProgress >= 1.0 ? AppColors.success : AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text('${(currentProgress * 100).toInt()}%',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$currentDone / ${items.length} hạng mục', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        if (startDate != null)
                          Text('Bắt đầu: ${startDate.day}/${startDate.month}/${startDate.year}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),

                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('📋 Chi tiết hạng mục', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        const Spacer(),
                        if (items.any((it) => it['status'] != 'done'))
                          TextButton.icon(
                            icon: const Icon(Icons.done_all_rounded, size: 18),
                            label: const Text('Tick tất cả', style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                            onPressed: () async {
                              for (int i = 0; i < items.length; i++) {
                                if (items[i]['status'] != 'done') {
                                  await dp.updateMaintenanceItem(log['_id'], i, {'status': 'done'});
                                }
                              }
                              setSt(() {
                                for (int i = 0; i < items.length; i++) {
                                  items[i] = {...items[i], 'status': 'done', 'completedAt': DateTime.now().toIso8601String()};
                                }
                              });
                            },
                          )
                        else
                          TextButton.icon(
                            icon: const Icon(Icons.remove_done_rounded, size: 18),
                            label: const Text('Bỏ tất cả', style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                            onPressed: () async {
                              for (int i = 0; i < items.length; i++) {
                                await dp.updateMaintenanceItem(log['_id'], i, {'status': 'pending'});
                              }
                              setSt(() {
                                for (int i = 0; i < items.length; i++) {
                                  items[i] = {...items[i], 'status': 'pending', 'completedAt': null};
                                }
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // ── Item checklist ──
                    ...items.asMap().entries.map((entry) {
                      final i = entry.key;
                      final item = entry.value;
                      final isDone = item['status'] == 'done';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        color: isDone ? AppColors.success.withAlpha(15) : null,
                        child: ListTile(
                          dense: true,
                          leading: Checkbox(
                            value: isDone,
                            activeColor: AppColors.success,
                            onChanged: (v) async {
                              final newStatus = v == true ? 'done' : 'pending';
                              final ok = await dp.updateMaintenanceItem(log['_id'], i, {'status': newStatus});
                              if (ok) {
                                setSt(() {
                                  items[i] = {...items[i], 'status': newStatus, 'completedAt': v == true ? DateTime.now().toIso8601String() : null};
                                });
                              }
                            },
                          ),
                          title: Text(
                            item['name'] ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              decoration: isDone ? TextDecoration.lineThrough : null,
                              color: isDone ? AppColors.textHint : AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            item['category'] ?? '',
                            style: TextStyle(fontSize: 11, color: isDone ? AppColors.textHint : AppColors.textSecondary),
                          ),
                          trailing: isDone
                            ? const Icon(Icons.check_circle, color: AppColors.success, size: 22)
                            : const Icon(Icons.radio_button_unchecked, color: AppColors.textHint, size: 22),
                        ),
                      );
                    }),

                    // ── Materials used ──
                    if (materials.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('🧪 Vật tư đã sử dụng', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      ...materials.map((m) {
                        final prod = dp.products.where((p) => p.id == m['productId']).toList();
                        final name = prod.isNotEmpty ? prod.first.name : 'Không tìm thấy';
                        final unit = prod.isNotEmpty ? prod.first.unit : '';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.inventory_2_outlined, size: 16, color: AppColors.textSecondary),
                              const SizedBox(width: 8),
                              Expanded(child: Text(name, style: const TextStyle(fontSize: 13))),
                              Text('${m['quantity']} $unit', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        );
                      }),
                    ],

                    // ── Note ──
                    if ((log['note'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('📝 ${log['note']}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
              if (items.every((it) => it['status'] == 'done'))
                FilledButton.icon(
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: const Text('Hoàn thành bảo trì'),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                  onPressed: () async {
                    await dp.finishMaintenance(log['_id'], {'status': 'completed'});
                    if (ctx.mounted) Navigator.pop(ctx);
                    _showSnack('${pond.code} đã hoàn thành bảo trì');
                  },
                )
              else
                OutlinedButton.icon(
                  icon: const Icon(Icons.cancel_outlined, size: 20, color: AppColors.error),
                  label: const Text('Huỷ bảo trì', style: TextStyle(color: AppColors.error)),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: ctx,
                      builder: (c) => AlertDialog(
                        title: const Text('Huỷ bảo trì?'),
                        content: const Text('Các hạng mục chưa hoàn thành sẽ bị huỷ.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Không')),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Huỷ bảo trì'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await dp.finishMaintenance(log['_id'], {'status': 'cancelled'});
                      if (ctx.mounted) Navigator.pop(ctx);
                      _showSnack('${pond.code} đã huỷ bảo trì');
                    }
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  // ══════ ĐO KÍCH THƯỚC CÁ ══════
  Future<void> _showSizeMeasurementDialog(Pond pond, List<FishBatch> batches) async {
    final dp = context.read<DataProvider>();
    final auth = context.read<AuthProvider>();
    FishBatch? selBatch = batches.length == 1 ? batches.first : null;
    final weightC = TextEditingController();
    final lengthC = TextEditingController();
    final sampleC = TextEditingController(text: '30');
    final remainC = TextEditingController();
    final noteC = TextEditingController();
    DateTime selDate = DateTime.now();
    String measuredBy = auth.user?.displayName ?? '';

    // Pre-fill remaining qty if batch selected
    if (selBatch != null) {
      remainC.text = '${selBatch.quantityInPond(pond.id)}';
    }

    // Measurement history for this pond
    final history = dp.sizeMeasurements
        .where((m) => m.pondId == pond.id || (m.pondId.isEmpty && batches.any((b) => b.id == m.fishBatchId)))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final dateFmt = DateFormat('dd/MM/yyyy');
    final timeFmt = DateFormat('HH:mm');

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final sp = selBatch != null ? dp.speciesById(selBatch!.speciesId) : null;
          final qtyInPond = selBatch?.quantityInPond(pond.id) ?? 0;
          return AlertDialog(
            title: Row(children: [
              const Icon(Icons.straighten_rounded, color: Color(0xFF6366F1), size: 22),
              const SizedBox(width: 8),
              Text('Đo kích thước – ${pond.code}'),
            ]),
            content: SizedBox(
              width: AppSizes.dialogWidth(context, 480),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Batch selector ──
                    if (batches.length > 1)
                      DropdownButtonFormField<FishBatch>(
                        value: selBatch,
                        decoration: const InputDecoration(labelText: 'Lô cá', border: OutlineInputBorder()),
                        items: batches.map((b) {
                          final sp2 = dp.speciesById(b.speciesId);
                          return DropdownMenuItem(value: b, child: Text('${b.name} (${sp2?.name ?? ""}) – ${b.quantityInPond(pond.id)} con'));
                        }).toList(),
                        onChanged: (v) => setSt(() {
                          selBatch = v;
                          if (v != null) remainC.text = '${v.quantityInPond(pond.id)}';
                        }),
                      ),
                    if (batches.length > 1) const SizedBox(height: 12),

                    // ── Batch info ──
                    if (selBatch != null) Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withAlpha(12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF6366F1).withAlpha(30)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${sp?.name ?? selBatch!.name}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          const SizedBox(height: 4),
                          Row(children: [
                            _infoChip('Trong ao', '$qtyInPond con'),
                            const SizedBox(width: 12),
                            _infoChip('TL hiện tại', '${selBatch!.currentWeight}g'),
                            const SizedBox(width: 12),
                            _infoChip('Dài hiện tại', '${selBatch!.currentSize}cm'),
                          ]),
                          const SizedBox(height: 4),
                          Row(children: [
                            _infoChip('Ngày nuôi', '${selBatch!.daysOfCulture} ngày'),
                            const SizedBox(width: 12),
                            _infoChip('TL ban đầu', '${selBatch!.initialWeight}g'),
                          ]),
                        ],
                      ),
                    ),
                    if (selBatch != null) const SizedBox(height: 14),

                    // ── Date & measurer ──
                    Row(children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final d = await showDatePicker(context: ctx, initialDate: selDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                            if (d != null) setSt(() => selDate = d);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Ngày đo', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today, size: 18)),
                            child: Text(dateFmt.format(selDate)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          initialValue: measuredBy,
                          decoration: const InputDecoration(labelText: 'Người đo', border: OutlineInputBorder()),
                          onChanged: (v) => measuredBy = v,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),

                    // ── Weight & Length ──
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: weightC,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Trọng lượng TB (g)',
                            border: OutlineInputBorder(),
                            hintText: 'VD: 120',
                            suffixText: 'g',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: lengthC,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Chiều dài TB (cm)',
                            border: OutlineInputBorder(),
                            hintText: 'VD: 18',
                            suffixText: 'cm',
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),

                    // ── Sample count & remaining qty ──
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: sampleC,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Số cá đo mẫu',
                            border: OutlineInputBorder(),
                            hintText: 'VD: 30',
                            suffixText: 'con',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: remainC,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Số cá còn lại (ước)',
                            border: OutlineInputBorder(),
                            suffixText: 'con',
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),

                    // ── Note ──
                    TextField(
                      controller: noteC,
                      decoration: const InputDecoration(labelText: 'Ghi chú', border: OutlineInputBorder()),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),

                    // ── Growth chart from history ──
                    if (history.isNotEmpty) ...[
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text('📈 Lịch sử đo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      ...history.take(5).map((m) {
                        final batch = dp.fishBatches.firstWhere((b) => b.id == m.fishBatchId, orElse: () => batches.first);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(children: [
                            Container(
                              width: 8, height: 8,
                              decoration: const BoxDecoration(color: Color(0xFF6366F1), shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Text(dateFmt.format(m.date), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 10),
                            Text('${m.avgWeight}g', style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 6),
                            Text('×', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                            const SizedBox(width: 6),
                            Text('${m.avgLength}cm', style: const TextStyle(fontSize: 12, color: AppColors.secondary, fontWeight: FontWeight.w600)),
                            const Spacer(),
                            Text(m.measuredBy, style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                          ]),
                        );
                      }),
                      if (history.length > 5)
                        Text('... và ${history.length - 5} lần đo khác', style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
              FilledButton.icon(
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('Lưu kết quả đo'),
                onPressed: () async {
                  final w = double.tryParse(weightC.text) ?? 0;
                  final l = double.tryParse(lengthC.text) ?? 0;
                  if (selBatch == null || (w <= 0 && l <= 0)) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Chọn lô cá và nhập trọng lượng hoặc chiều dài')));
                    return;
                  }
                  await dp.create('sizemeasurements', {
                    'fishBatchId': selBatch!.id,
                    'pondId': pond.id,
                    'storeId': auth.user?.storeId ?? '',
                    'date': selDate.toIso8601String(),
                    'avgWeight': w,
                    'avgLength': l,
                    'sampleCount': int.tryParse(sampleC.text) ?? 0,
                    'remainingQty': int.tryParse(remainC.text) ?? 0,
                    'measuredBy': measuredBy,
                    'note': noteC.text.trim(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _showSnack('Đã lưu kết quả đo – ${pond.code}: ${w}g / ${l}cm');
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _infoChip(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // DỰ TRÙ THỨC ĂN – Feed planning overview for entire branch
  // ═══════════════════════════════════════════════════════════════════════
  void _showFeedPlanningDialog() {
    final branchId = _selectedBranchId;
    if (branchId == null) return;
    final branch = dp.branches.where((b) => b.id == branchId).firstOrNull;
    final zones = dp.zonesForBranch(branchId);
    final allPonds = zones.expand((z) => dp.pondsForZone(z.id)).toList();
    final activePonds = allPonds.where((p) => p.status == 'active').toList();
    final today = DateTime.now();
    final dateFmt = DateFormat('dd/MM/yyyy');

    // Build rows data
    final rows = <_FeedPlanRow>[];
    double grandTotalKg = 0;
    double grandTotalCost = 0;

    for (final pond in activePonds) {
      final batches = dp.batchesForPond(pond.id).where((b) => b.status == 'active').toList();
      if (batches.isEmpty) continue;

      for (final batch in batches) {
        final species = dp.speciesById(batch.speciesId);
        final qtyInPond = batch.quantityInPond(pond.id);
        if (qtyInPond <= 0) continue;

        final weight = batch.currentWeight > 0 ? batch.currentWeight : batch.initialWeight;
        final size = batch.currentSize > 0 ? batch.currentSize : batch.initialSize;
        final feedRatio = species?.feedRatio ?? 1.5;
        final biomassKg = qtyInPond * weight / 1000;
        final feedKgPerDay = biomassKg * feedRatio / 100;

        // Last measurement
        final measures = dp.sizeMeasurements
            .where((m) => m.fishBatchId == batch.id)
            .toList()
          ..sort((a, c) => c.date.compareTo(a.date));
        final lastMeasure = measures.isNotEmpty ? measures.first : null;

        // Days since stocking
        final daysSinceStock = today.difference(batch.stockingDate).inDays;

        // Find suitable feed product + cost
        final feedProducts = dp.products.where((p) => p.category == 'feed').toList();
        double costPerKg = feedProducts.isNotEmpty ? feedProducts.first.price : 0;

        final row = _FeedPlanRow(
          pondCode: pond.code,
          zoneName: zones.where((z) => z.id == pond.zoneId).map((z) => z.name).firstOrNull ?? '',
          speciesName: species?.name ?? '?',
          quantity: qtyInPond,
          weightG: weight,
          sizeCm: size,
          biomassKg: biomassKg,
          feedRatio: feedRatio,
          feedKgPerDay: feedKgPerDay,
          costPerDay: feedKgPerDay * costPerKg,
          lastMeasureDate: lastMeasure?.date,
          stockingDate: batch.stockingDate,
          daysSinceStock: daysSinceStock,
          feedConsumed: batch.feedConsumed,
        );
        rows.add(row);
        grandTotalKg += feedKgPerDay;
        grandTotalCost += row.costPerDay;
      }
    }

    // Sort by zone then pond
    rows.sort((a, b) {
      final z = a.zoneName.compareTo(b.zoneName);
      return z != 0 ? z : a.pondCode.compareTo(b.pondCode);
    });

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 1100,
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                decoration: BoxDecoration(
                  color: AppColors.success.withAlpha(15),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.restaurant_menu_rounded, color: AppColors.success, size: 28),
                        const SizedBox(width: 10),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Dự trù thức ăn – ${branch?.name ?? ''}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Text('Ngày ${dateFmt.format(today)} • ${activePonds.length} ao đang nuôi', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        )),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Summary cards
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _feedSummaryCard(Icons.set_meal_rounded, '${rows.fold<int>(0, (s, r) => s + r.quantity)}', 'Tổng cá (con)', AppColors.info),
                        _feedSummaryCard(Icons.monitor_weight_rounded, '${rows.fold<double>(0, (s, r) => s + r.biomassKg).toStringAsFixed(1)} kg', 'Sinh khối', AppColors.primary),
                        _feedSummaryCard(Icons.restaurant_rounded, '${grandTotalKg.toStringAsFixed(1)} kg/ngày', 'Thức ăn cần', AppColors.success),
                        _feedSummaryCard(Icons.payments_rounded, '${_currFmt.format(grandTotalCost.round())}đ/ngày', 'Chi phí ước tính', AppColors.warning),
                        _feedSummaryCard(Icons.calendar_month_rounded, '${_currFmt.format((grandTotalCost * 30).round())}đ/tháng', 'Ước tính/tháng', AppColors.error),
                      ],
                    ),
                  ],
                ),
              ),
              // Table
              Flexible(
                child: rows.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: Text('Không có ao nào đang nuôi cá', style: TextStyle(color: AppColors.textSecondary)),
                    )
                  : Scrollbar(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(AppColors.primary.withAlpha(15)),
                            headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textPrimary),
                            dataTextStyle: const TextStyle(fontSize: 12),
                            columnSpacing: 16,
                            horizontalMargin: 12,
                            columns: const [
                              DataColumn(label: Text('Khu')),
                              DataColumn(label: Text('Ao')),
                              DataColumn(label: Text('Loài')),
                              DataColumn(label: Text('SL (con)'), numeric: true),
                              DataColumn(label: Text('TL (g)'), numeric: true),
                              DataColumn(label: Text('KT (cm)'), numeric: true),
                              DataColumn(label: Text('Sinh khối\n(kg)'), numeric: true),
                              DataColumn(label: Text('Hệ số\ncho ăn'), numeric: true),
                              DataColumn(label: Text('TĂ/ngày\n(kg)'), numeric: true),
                              DataColumn(label: Text('Chi phí\n/ngày'), numeric: true),
                              DataColumn(label: Text('Ngày thả')),
                              DataColumn(label: Text('Số ngày\nnuôi'), numeric: true),
                              DataColumn(label: Text('TĂ đã\ndùng (kg)'), numeric: true),
                              DataColumn(label: Text('Đo gần\nnhất')),
                            ],
                            rows: [
                              ...rows.map((r) => DataRow(cells: [
                                DataCell(Text(r.zoneName, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))),
                                DataCell(Text(r.pondCode, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary))),
                                DataCell(Text(r.speciesName)),
                                DataCell(Text(_currFmt.format(r.quantity))),
                                DataCell(Text(r.weightG.toStringAsFixed(0))),
                                DataCell(Text(r.sizeCm.toStringAsFixed(1))),
                                DataCell(Text(r.biomassKg.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w500))),
                                DataCell(Text('${r.feedRatio}%')),
                                DataCell(Text(r.feedKgPerDay.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.success))),
                                DataCell(Text('${_currFmt.format(r.costPerDay.round())}đ', style: const TextStyle(fontSize: 11))),
                                DataCell(Text(dateFmt.format(r.stockingDate), style: const TextStyle(fontSize: 11))),
                                DataCell(Text('${r.daysSinceStock}', style: TextStyle(
                                  color: r.daysSinceStock > 150 ? AppColors.warning : AppColors.textSecondary,
                                  fontWeight: r.daysSinceStock > 150 ? FontWeight.w600 : FontWeight.normal,
                                ))),
                                DataCell(Text(r.feedConsumed.toStringAsFixed(1), style: const TextStyle(fontSize: 11))),
                                DataCell(r.lastMeasureDate != null
                                  ? Text(dateFmt.format(r.lastMeasureDate!), style: const TextStyle(fontSize: 11))
                                  : const Text('Chưa đo', style: TextStyle(fontSize: 11, color: AppColors.warning, fontStyle: FontStyle.italic)),
                                ),
                              ])),
                              // Totals row
                              DataRow(
                                color: WidgetStateProperty.all(AppColors.success.withAlpha(18)),
                                cells: [
                                  const DataCell(Text('')),
                                  const DataCell(Text('TỔNG CỘNG', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                  DataCell(Text('${rows.map((r) => r.speciesName).toSet().length} loài', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11))),
                                  DataCell(Text(_currFmt.format(rows.fold<int>(0, (s, r) => s + r.quantity)), style: const TextStyle(fontWeight: FontWeight.bold))),
                                  const DataCell(Text('')),
                                  const DataCell(Text('')),
                                  DataCell(Text(rows.fold<double>(0, (s, r) => s + r.biomassKg).toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold))),
                                  const DataCell(Text('')),
                                  DataCell(Text(grandTotalKg.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success, fontSize: 13))),
                                  DataCell(Text('${_currFmt.format(grandTotalCost.round())}đ', style: const TextStyle(fontWeight: FontWeight.bold))),
                                  const DataCell(Text('')),
                                  const DataCell(Text('')),
                                  DataCell(Text(rows.fold<double>(0, (s, r) => s + r.feedConsumed).toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold))),
                                  const DataCell(Text('')),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _feedSummaryCard(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(50)),
        boxShadow: [BoxShadow(color: color.withAlpha(15), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ]),
      ]),
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Color _pondStatusColor(String status) {
    switch (status) {
      case 'active': return AppColors.success;
      case 'inactive': return AppColors.textHint;
      case 'maintenance': return AppColors.warning;
      case 'treatment': return AppColors.info;
      default: return AppColors.textSecondary;
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// POND CELL – Interactive pond tile in the map grid (ENHANCED)
// ═════════════════════════════════════════════════════════════════════════════

class _PondCell extends StatefulWidget {
  final Pond pond;
  final DataProvider dp;
  final VoidCallback onTap;
  const _PondCell({required this.pond, required this.dp, required this.onTap});
  @override
  State<_PondCell> createState() => _PondCellState();
}

class _PondCellState extends State<_PondCell> with SingleTickerProviderStateMixin {
  late final AnimationController _hoverCtrl;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _hoverCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
  }

  @override
  void dispose() {
    _hoverCtrl.dispose();
    super.dispose();
  }

  Color get _bgColor {
    switch (widget.pond.status) {
      case 'active': return const Color(0xFF4DB6AC);
      case 'maintenance': return const Color(0xFFFFB74D);
      case 'treatment': return const Color(0xFF7986CB);
      default: return const Color(0xFFB0BEC5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pond = widget.pond;
    final dp = widget.dp;
    final batches = dp.batchesForPond(pond.id).where((b) => b.status == 'active').toList();
    final hasFish = batches.isNotEmpty;
    final totalFish = batches.fold<int>(0, (s, b) => s + b.quantityInPond(pond.id));
    final wq = pond.status == 'active' ? _evaluateWater(pond, dp) : null;
    final overdueTasks = dp.tasksForPond(pond.id).where((t) => t.status == 'pending' && t.isOverdue).length;

    // Growth progress for first active batch
    double? growthProgress;
    int? daysOfCulture;
    String? speciesName;
    String? speciesImageUrl;
    DateTime? stockingDate;
    if (hasFish) {
      final b = batches.first;
      final sp = dp.speciesById(b.speciesId);
      speciesName = sp?.name;
      speciesImageUrl = (sp?.imageUrl.isNotEmpty == true) ? sp!.imageUrl : null;
      daysOfCulture = b.daysOfCulture;
      stockingDate = b.stockingDate;
      final growthDays = sp?.growthDays ?? 180;
      growthProgress = (daysOfCulture / growthDays).clamp(0.0, 1.0);
    }

    // Scheduled transfer date
    final scheduledTransfer = dp.tasksForPond(pond.id).where((t) => t.type == 'transfer' && t.status == 'pending').toList();
    final nextTransferDate = scheduledTransfer.isNotEmpty ? scheduledTransfer.first.dueDate : null;

    // Operation indicators
    final activeDiseases = dp.diseaseLogs.where((d) => d.pondId == pond.id && (d.status == 'detected' || d.status == 'treating')).length;
    final activeWithdrawal = dp.treatmentLogs.where((t) => t.pondId == pond.id && t.isWithdrawalActive).length;
    final maintenanceDueEquip = dp.equipmentList.where((e) => e.pondId == pond.id && e.isMaintenanceDue).length;

    final alertCount = (wq != null && wq.level != _WQLevel.good ? 1 : 0) + (overdueTasks > 0 ? 1 : 0) + (activeDiseases > 0 ? 1 : 0) + (activeWithdrawal > 0 ? 1 : 0) + (maintenanceDueEquip > 0 ? 1 : 0);

    return MouseRegion(
      onEnter: (_) => setState(() { _hovering = true; _hoverCtrl.forward(); }),
      onExit: (_) => setState(() { _hovering = false; _hoverCtrl.reverse(); }),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          listenable: _hoverCtrl,
          builder: (ctx, child) => Transform.scale(
            scale: 1.0 + _hoverCtrl.value * 0.06,
            child: child,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: _bgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _hovering ? Colors.white : Colors.white.withAlpha(30),
                width: _hovering ? 3 : 1.2,
              ),
              boxShadow: [
                if (_hovering) ...[                  BoxShadow(
                    color: Colors.white.withAlpha(50),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: _bgColor.withAlpha(120),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ] else
                  BoxShadow(
                    color: _bgColor.withAlpha(40),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
              ],
            ),
            child: Stack(
              children: [
                // Species image background
                if (speciesImageUrl != null)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Image.network(
                        speciesImageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                // Dark overlay for readability when image exists
                if (speciesImageUrl != null)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(13),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _bgColor.withAlpha(180),
                            _bgColor.withAlpha(210),
                            _bgColor.withAlpha(240),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Main content
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header: Code + status ──
                      Row(
                        children: [
                          Expanded(
                            child: Text(pond.code,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 0.3, shadows: [Shadow(color: Colors.black26, blurRadius: 2)]),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          if (wq != null && wq.level != _WQLevel.good)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(wq.icon, size: 16, color: wq.color),
                            ),
                          if (activeDiseases > 0)
                            Padding(
                              padding: const EdgeInsets.only(right: 3),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(color: AppColors.error.withAlpha(180), borderRadius: BorderRadius.circular(4)),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.coronavirus, size: 11, color: Colors.white),
                                  const SizedBox(width: 2),
                                  Text('$activeDiseases', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700)),
                                ]),
                              ),
                            ),
                          if (activeWithdrawal > 0)
                            Padding(
                              padding: const EdgeInsets.only(right: 3),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(color: Colors.orange.withAlpha(200), borderRadius: BorderRadius.circular(4)),
                                child: const Icon(Icons.block, size: 12, color: Colors.white),
                              ),
                            ),
                          if (maintenanceDueEquip > 0)
                            Padding(
                              padding: const EdgeInsets.only(right: 3),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(color: AppColors.warning.withAlpha(200), borderRadius: BorderRadius.circular(4)),
                                child: const Icon(Icons.build_circle, size: 12, color: Colors.white),
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(30),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              pond.status == 'active' ? (hasFish ? '🐟' : 'Trống')
                                : pond.status == 'maintenance' ? '🔧' : '⏸',
                              style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // ── Sub-header: Type + Area ──
                      Text('${pond.typeLabel} • ${pond.area}m²',
                        style: TextStyle(color: Colors.white.withAlpha(220), fontSize: 13, fontWeight: FontWeight.w600, shadows: const [Shadow(color: Colors.black12, blurRadius: 1)]),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),

                      const SizedBox(height: 8),

                      // ── Fish info ──
                      if (hasFish) ...[
                        // Species name
                        if (speciesName != null)
                          Text(speciesName,
                            style: TextStyle(color: Colors.white.withAlpha(240), fontSize: 16, fontWeight: FontWeight.w700, shadows: const [Shadow(color: Colors.black12, blurRadius: 1)]),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        const SizedBox(height: 5),
                        // Fish count + days
                        Row(
                          children: [
                            Icon(Icons.set_meal_rounded, color: Colors.white.withAlpha(230), size: 18),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(_currFmt.format(totalFish),
                                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800, shadows: [Shadow(color: Colors.black26, blurRadius: 2)]),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(' con', style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 13)),
                            const Spacer(),
                            if (daysOfCulture != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(30),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text('${daysOfCulture}d',
                                  style: TextStyle(color: Colors.white.withAlpha(220), fontSize: 13, fontWeight: FontWeight.w700),
                                ),
                              ),
                          ],
                        ),
                        // Growth progress
                        if (growthProgress != null) ...[
                          const SizedBox(height: 3),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: growthProgress,
                              minHeight: 4,
                              backgroundColor: Colors.white.withAlpha(25),
                              valueColor: AlwaysStoppedAnimation(
                                growthProgress >= 0.9 ? const Color(0xFF69F0AE)
                                  : growthProgress >= 0.6 ? const Color(0xFFFFD54F)
                                  : Colors.white.withAlpha(200),
                              ),
                            ),
                          ),
                        ],

                        // Stocking date + Transfer date
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            if (stockingDate != null) ...[
                              Icon(Icons.calendar_today_rounded, size: 12, color: Colors.white.withAlpha(180)),
                              const SizedBox(width: 3),
                              Text('${stockingDate.day}/${stockingDate.month}',
                                style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                            if (nextTransferDate != null) ...[
                              const Spacer(),
                              Icon(Icons.swap_horiz_rounded, size: 14, color: const Color(0xFFFFD54F)),
                              const SizedBox(width: 3),
                              Text('${nextTransferDate.day}/${nextTransferDate.month}',
                                style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 12, fontWeight: FontWeight.w700)),
                            ],
                          ],
                        ),
                      ] else ...[
                        // Empty pond
                        Center(
                          child: Text(pond.statusLabel,
                            style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 13, fontWeight: FontWeight.w500, fontStyle: FontStyle.italic),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],

                      // ── Water params (bottom) ──
                      const Spacer(),
                      if (pond.currentPh != null || pond.currentDo != null || pond.currentTemp != null) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (pond.currentTemp != null)
                              _MiniParam('🌡', '${pond.currentTemp!.toStringAsFixed(0)}°'),
                            if (pond.currentPh != null)
                              _MiniParam('pH', pond.currentPh!.toStringAsFixed(1)),
                            if (pond.currentDo != null)
                              _MiniParam('DO', pond.currentDo!.toStringAsFixed(1)),
                            if (pond.currentNh3 != null)
                              _MiniParam('NH₃', pond.currentNh3!.toStringAsFixed(1)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Alert badge
                if (alertCount > 0)
                  Positioned(
                    top: -4, right: -4,
                    child: Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [BoxShadow(color: AppColors.error.withAlpha(150), blurRadius: 8, spreadRadius: 1)],
                      ),
                      child: Center(
                        child: Text('$alertCount', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),

                // Hover overlay
                if (_hovering)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Icon(Icons.touch_app_rounded, color: Colors.white, size: 26),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// HELPER WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

class _TabBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _TabBtn(this.label, this.icon, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withAlpha(20) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: selected ? AppColors.primary : AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              )),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _HistChip(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.textSecondary),
          const SizedBox(width: 3),
          Text('$label $value', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _MiniParam extends StatelessWidget {
  final String label;
  final String value;
  const _MiniParam(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withAlpha(160), fontSize: 12, fontWeight: FontWeight.w600)),
        Text(value, style: TextStyle(color: Colors.white.withAlpha(230), fontSize: 14, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatChip(this.icon, this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: color)),
              ],
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textHint), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _PondTimelineEvent {
  final DateTime date;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _PondTimelineEvent({
    required this.date,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
}

class _MeasureBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _MeasureBadge(this.icon, this.text, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}

class _GrowthPoint {
  final DateTime date;
  final double weight;
  const _GrowthPoint(this.date, this.weight);
}

class _GrowthChartPainter extends CustomPainter {
  final List<_GrowthPoint> points;
  _GrowthChartPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final minW = points.map((p) => p.weight).reduce((a, b) => a < b ? a : b);
    final maxW = points.map((p) => p.weight).reduce((a, b) => a > b ? a : b);
    final rangeW = maxW - minW;
    final yPad = rangeW < 1 ? 1.0 : rangeW * 0.1;

    final paint = Paint()
      ..color = const Color(0xFF6366F1)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = const Color(0xFF6366F1).withAlpha(25)
      ..style = PaintingStyle.fill;

    final dotPaint = Paint()
      ..color = const Color(0xFF6366F1)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();
    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);

    for (var i = 0; i < points.length; i++) {
      final x = points.length == 1 ? size.width / 2 : i / (points.length - 1) * size.width;
      final y = rangeW < 1
          ? size.height / 2
          : size.height - ((points[i].weight - minW + yPad) / (rangeW + yPad * 2) * size.height);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }

      canvas.drawCircle(Offset(x, y), 3, dotPaint);

      // Draw weight label
      textPainter.text = TextSpan(
        text: '${points[i].weight.toStringAsFixed(0)}g',
        style: const TextStyle(fontSize: 9, color: Color(0xFF6366F1), fontWeight: FontWeight.w600),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, y - 14));
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _BatchStat extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  const _BatchStat(this.label, this.value, this.sub);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          Text(sub, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4CAF50).withAlpha(6)
      ..strokeWidth = 0.3;
    const step = 60.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot(this.color, this.label);
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge(this.label, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _WaterParam extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _WaterParam(this.label, this.value, this.icon);
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppColors.info),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;
  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    final effectiveColor = enabled ? color : AppColors.textHint;
    return Material(
      color: effectiveColor.withAlpha(enabled ? 15 : 8),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? onTap : null,
        child: Container(
          width: 100,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: effectiveColor.withAlpha(enabled ? 25 : 10),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: effectiveColor, size: 22),
              ),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: effectiveColor,
              ), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class AnimatedBuilder extends AnimatedWidget {
  final TransitionBuilder builder;
  final Widget? child;
  const AnimatedBuilder({super.key, required super.listenable, required this.builder, this.child});
  Animation<double> get animation => listenable as Animation<double>;
  @override
  Widget build(BuildContext context) => builder(context, child);
}

class _FeedPlanRow {
  final String pondCode;
  final String zoneName;
  final String speciesName;
  final int quantity;
  final double weightG;
  final double sizeCm;
  final double biomassKg;
  final double feedRatio;
  final double feedKgPerDay;
  final double costPerDay;
  final DateTime? lastMeasureDate;
  final DateTime stockingDate;
  final int daysSinceStock;
  final double feedConsumed;

  const _FeedPlanRow({
    required this.pondCode,
    required this.zoneName,
    required this.speciesName,
    required this.quantity,
    required this.weightG,
    required this.sizeCm,
    required this.biomassKg,
    required this.feedRatio,
    required this.feedKgPerDay,
    required this.costPerDay,
    this.lastMeasureDate,
    required this.stockingDate,
    required this.daysSinceStock,
    required this.feedConsumed,
  });
}
