import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/data_provider.dart';
import '../../theme/app_theme.dart';

// ═════════════════════════════════════════════════════════════════════════════
// 0 – DASHBOARD VIEW (extracted from main_screen.dart for build perf)
// ═════════════════════════════════════════════════════════════════════════════

class DashboardView extends StatelessWidget {
  final DataProvider dp;
  final VoidCallback onAddPond;
  final VoidCallback onAddBatch;
  final VoidCallback onMeasureWater;
  final VoidCallback onAddSale;
  const DashboardView({super.key, required this.dp, required this.onAddPond, required this.onAddBatch, required this.onMeasureWater, required this.onAddSale});

  // ── helpers ──
  static final _cFmt = NumberFormat('#,###', 'vi');
  static final _dateFmt = DateFormat('dd/MM');

  double _totalRevenue30d() {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    return dp.saleOrders.where((o) => o.status != 'cancelled' && o.date.isAfter(cutoff)).fold(0.0, (s, o) => s + o.totalAmount);
  }

  double _totalExpense30d() {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    return dp.purchaseOrders.where((o) => o.status != 'cancelled' && o.date.isAfter(cutoff)).fold(0.0, (s, o) => s + o.total);
  }

  // Group revenue/expense by last N days
  Map<String, double> _revenueByDay(int days) {
    final now = DateTime.now();
    final map = <String, double>{};
    for (var i = days - 1; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      map[_dateFmt.format(d)] = 0;
    }
    final cutoff = now.subtract(Duration(days: days));
    for (final o in dp.saleOrders) {
      if (o.status == 'cancelled' || o.date.isBefore(cutoff)) continue;
      final key = _dateFmt.format(o.date);
      map[key] = (map[key] ?? 0) + o.totalAmount;
    }
    return map;
  }

  Map<String, double> _expenseByDay(int days) {
    final now = DateTime.now();
    final map = <String, double>{};
    for (var i = days - 1; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      map[_dateFmt.format(d)] = 0;
    }
    final cutoff = now.subtract(Duration(days: days));
    for (final o in dp.purchaseOrders) {
      if (o.status == 'cancelled' || o.date.isBefore(cutoff)) continue;
      final key = _dateFmt.format(o.date);
      map[key] = (map[key] ?? 0) + o.total;
    }
    return map;
  }

  // Pond status distribution
  Map<String, int> _pondStatusDist() {
    final m = <String, int>{};
    for (final p in dp.ponds) {
      m[p.status] = (m[p.status] ?? 0) + 1;
    }
    return m;
  }

  // Species distribution for active batches
  Map<String, int> _speciesDist() {
    final m = <String, int>{};
    for (final b in dp.fishBatches.where((b) => b.status == 'active')) {
      final sp = dp.speciesById(b.speciesId);
      final name = sp?.name ?? 'Khác';
      m[name] = (m[name] ?? 0) + 1;
    }
    return m;
  }

  // Task status distribution
  Map<String, int> _taskStatusDist() {
    final m = <String, int>{'pending': 0, 'done': 0, 'cancelled': 0, 'overdue': 0};
    for (final t in dp.tasks) {
      if (t.isOverdue) {
        m['overdue'] = (m['overdue'] ?? 0) + 1;
      } else {
        m[t.status] = (m[t.status] ?? 0) + 1;
      }
    }
    m.removeWhere((_, v) => v == 0);
    return m;
  }

  // Product inventory by category
  Map<String, double> _inventoryByCategory() {
    final m = <String, double>{};
    for (final p in dp.products) {
      final cat = _categoryLabel(p.category);
      m[cat] = (m[cat] ?? 0) + p.stockValue;
    }
    // Sort descending
    final sorted = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted.take(6));
  }

  static String _categoryLabel(String cat) {
    switch (cat) {
      case 'feed': return 'Thức ăn';
      case 'seed': return 'Giống';
      case 'chemical': return 'Hóa chất';
      case 'medicine': return 'Thuốc';
      case 'accessory': return 'Phụ kiện';
      case 'tool': return 'Dụng cụ';
      default: return 'Khác';
    }
  }

  // Mortality rate for active batches
  List<_BatchMortality> _batchMortalities() {
    return dp.fishBatches
        .where((b) => b.status == 'active' && b.initialQuantity > 0)
        .map((b) => _BatchMortality(b.name, b.mortalityRate, b.survivalRate))
        .toList()
      ..sort((a, b) => b.mortalityRate.compareTo(a.mortalityRate));
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 860;
    final revenue30 = _totalRevenue30d();
    final expense30 = _totalExpense30d();
    final profit30 = revenue30 - expense30;

    return RefreshIndicator(
      onRefresh: () => dp.loadAll(),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Row 1: KPI Grid (6 cards) ──
          LayoutBuilder(builder: (_, constraints) {
            final cols = wide ? 6 : 3;
            const spacing = 12.0;
            final w = (constraints.maxWidth - spacing * (cols - 1)) / cols;
            final cards = <Widget>[
              _MiniKpi(icon: Icons.water_rounded, label: 'Ao hoạt động', value: '${dp.activePonds}/${dp.ponds.length}', color: AppColors.kpiPrimary),
              _MiniKpi(icon: Icons.set_meal_rounded, label: 'Lô cá', value: '${dp.activeBatches}/${dp.fishBatches.length}', color: AppColors.kpiSuccess),
              _MiniKpi(icon: Icons.trending_up_rounded, label: 'Doanh thu 30d', value: '${_cFmt.format(revenue30)}đ', color: AppColors.primary),
              _MiniKpi(icon: Icons.trending_down_rounded, label: 'Chi phí 30d', value: '${_cFmt.format(expense30)}đ', color: AppColors.kpiDanger),
              _MiniKpi(icon: Icons.account_balance_wallet_rounded, label: 'Lợi nhuận 30d', value: '${profit30 >= 0 ? "+" : ""}${_cFmt.format(profit30)}đ', color: profit30 >= 0 ? AppColors.success : AppColors.error),
              _MiniKpi(icon: Icons.task_alt_rounded, label: 'Việc chờ/quá hạn', value: '${dp.pendingTasks}/${dp.overdueTasks}', color: AppColors.kpiWarning),
            ];
            return Wrap(
              spacing: spacing, runSpacing: spacing,
              children: cards.map((c) => SizedBox(width: w, height: 100, child: c)).toList(),
            );
          }),
          const SizedBox(height: 20),

          // ── Row 2: Revenue/Expense Line Chart + Pond Pie ──
          if (wide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: _buildRevenueChart()),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: _buildPondPieChart()),
            ])
          else ...[
            _buildRevenueChart(),
            const SizedBox(height: 16),
            _buildPondPieChart(),
          ],
          const SizedBox(height: 16),

          // ── Row 3: Species Bar + Task Donut ──
          if (wide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _buildSpeciesBarChart()),
              const SizedBox(width: 16),
              Expanded(child: _buildTaskDonutChart()),
            ])
          else ...[
            _buildSpeciesBarChart(),
            const SizedBox(height: 16),
            _buildTaskDonutChart(),
          ],
          const SizedBox(height: 16),

          // ── Row 4: Inventory bar + Batch mortality/survival ──
          if (wide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _buildInventoryChart()),
              const SizedBox(width: 16),
              Expanded(child: _buildBatchSurvivalChart()),
            ])
          else ...[
            _buildInventoryChart(),
            const SizedBox(height: 16),
            _buildBatchSurvivalChart(),
          ],
          const SizedBox(height: 16),

          // ── Row 5: Quick actions + Recent sales + Alerts ──
          if (wide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _buildQuickActions(context)),
              const SizedBox(width: 16),
              Expanded(child: _buildRecentSales()),
              const SizedBox(width: 16),
              Expanded(child: _buildAlerts()),
            ])
          else ...[
            _buildQuickActions(context),
            const SizedBox(height: 16),
            _buildRecentSales(),
            const SizedBox(height: 16),
            _buildAlerts(),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // CHART BUILDERS
  // ════════════════════════════════════════════════════════════════════════════

  /// Revenue vs Expense line chart (last 14 days)
  Widget _buildRevenueChart() {
    final revMap = _revenueByDay(14);
    final expMap = _expenseByDay(14);
    final labels = revMap.keys.toList();
    final revSpots = <FlSpot>[];
    final expSpots = <FlSpot>[];
    for (var i = 0; i < labels.length; i++) {
      revSpots.add(FlSpot(i.toDouble(), (revMap[labels[i]] ?? 0) / 1000000));
      expSpots.add(FlSpot(i.toDouble(), (expMap[labels[i]] ?? 0) / 1000000));
    }
    final maxY = [...revSpots, ...expSpots].fold<double>(0, (m, s) => s.y > m ? s.y : m);
    return _ChartCard(
      title: 'Doanh thu & Chi phí (14 ngày)',
      icon: Icons.show_chart_rounded,
      height: 280,
      legend: [_LegendDot('Doanh thu', AppColors.primary), _LegendDot('Chi phí', AppColors.error)],
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: (maxY / 4).clamp(1, double.infinity),
            getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border.withAlpha(80), strokeWidth: 0.5)),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: 2,
              getTitlesWidget: (v, _) {
                final idx = v.toInt();
                if (idx < 0 || idx >= labels.length) return const SizedBox.shrink();
                return Padding(padding: const EdgeInsets.only(top: 6), child: Text(labels[idx], style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)));
              })),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 44,
              getTitlesWidget: (v, _) => Text('${v.toStringAsFixed(0)}tr', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)))),
          ),
          minY: 0,
          maxY: maxY < 1 ? 1 : maxY * 1.15,
          lineBarsData: [
            LineChartBarData(
              spots: revSpots, isCurved: true, preventCurveOverShooting: true,
              color: AppColors.primary, barWidth: 2.5, dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: AppColors.primary.withAlpha(25)),
            ),
            LineChartBarData(
              spots: expSpots, isCurved: true, preventCurveOverShooting: true,
              color: AppColors.error, barWidth: 2.5, dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: AppColors.error.withAlpha(25)),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((s) {
                final isRev = s.barIndex == 0;
                return LineTooltipItem('${isRev ? "DT" : "CP"}: ${_cFmt.format(s.y * 1000000)}đ',
                  TextStyle(color: isRev ? AppColors.primary : AppColors.error, fontSize: 11, fontWeight: FontWeight.w600));
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  /// Pond status pie chart
  Widget _buildPondPieChart() {
    final dist = _pondStatusDist();
    if (dist.isEmpty) return _ChartCard(title: 'Trạng thái ao', icon: Icons.pie_chart_rounded, height: 280, child: const Center(child: Text('Chưa có dữ liệu')));
    final colors = {'active': AppColors.success, 'inactive': AppColors.textHint, 'maintenance': AppColors.warning, 'treatment': AppColors.info};
    final statusLabels = {'active': 'Đang nuôi', 'inactive': 'Trống', 'maintenance': 'Bảo trì', 'treatment': 'Xử lý'};
    final entries = dist.entries.toList();
    final total = entries.fold<int>(0, (s, e) => s + e.value);
    return _ChartCard(
      title: 'Trạng thái ao (${dp.ponds.length})',
      icon: Icons.pie_chart_rounded,
      height: 280,
      child: Row(children: [
        Expanded(
          child: PieChart(PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 36,
            sections: entries.map((e) {
              final pct = (e.value / total * 100).toStringAsFixed(0);
              return PieChartSectionData(
                value: e.value.toDouble(), title: '$pct%',
                color: colors[e.key] ?? AppColors.textHint,
                radius: 50, titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
              );
            }).toList(),
          )),
        ),
        const SizedBox(width: 8),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: entries.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: colors[e.key] ?? AppColors.textHint, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('${statusLabels[e.key] ?? e.key} (${e.value})', style: const TextStyle(fontSize: 12)),
            ]),
          )).toList(),
        ),
      ]),
    );
  }

  /// Species distribution bar chart
  Widget _buildSpeciesBarChart() {
    final dist = _speciesDist();
    if (dist.isEmpty) return _ChartCard(title: 'Phân bổ giống', icon: Icons.bar_chart_rounded, height: 260, child: const Center(child: Text('Chưa có lô cá hoạt động')));
    final entries = dist.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final barColors = [AppColors.primary, AppColors.secondary, AppColors.info, AppColors.purple, AppColors.orange, AppColors.pink, AppColors.success];
    return _ChartCard(
      title: 'Giống cá đang nuôi (${dp.activeBatches} lô)',
      icon: Icons.bar_chart_rounded,
      height: 260,
      child: BarChart(BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (entries.first.value * 1.3).ceilToDouble(),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, gi, rod, ri) => BarTooltipItem('${entries[gi].key}\n${rod.toY.toInt()} lô',
              const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30,
            getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)))),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36,
            getTitlesWidget: (v, _) {
              final idx = v.toInt();
              if (idx < 0 || idx >= entries.length) return const SizedBox.shrink();
              final name = entries[idx].key;
              return Padding(padding: const EdgeInsets.only(top: 6),
                child: Text(name.length > 8 ? '${name.substring(0, 7)}…' : name, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary), textAlign: TextAlign.center));
            })),
        ),
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border.withAlpha(60), strokeWidth: 0.5)),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(entries.length, (i) => BarChartGroupData(x: i, barRods: [
          BarChartRodData(toY: entries[i].value.toDouble(), color: barColors[i % barColors.length], width: 22,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6))),
        ])),
      )),
    );
  }

  /// Task status donut chart
  Widget _buildTaskDonutChart() {
    final dist = _taskStatusDist();
    if (dist.isEmpty || dp.tasks.isEmpty) return _ChartCard(title: 'Công việc', icon: Icons.donut_large_rounded, height: 260, child: const Center(child: Text('Chưa có công việc')));
    final colors = {'pending': AppColors.warning, 'done': AppColors.success, 'cancelled': AppColors.textHint, 'overdue': AppColors.error};
    final labels = {'pending': 'Đang chờ', 'done': 'Hoàn thành', 'cancelled': 'Đã huỷ', 'overdue': 'Quá hạn'};
    final entries = dist.entries.toList();
    final total = entries.fold<int>(0, (s, e) => s + e.value);
    return _ChartCard(
      title: 'Công việc (${dp.tasks.length})',
      icon: Icons.donut_large_rounded,
      height: 260,
      child: Row(children: [
        Expanded(
          child: PieChart(PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 30,
            sections: entries.map((e) {
              final pct = (e.value / total * 100).toStringAsFixed(0);
              return PieChartSectionData(
                value: e.value.toDouble(), title: '$pct%',
                color: colors[e.key] ?? AppColors.textHint,
                radius: 45, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
              );
            }).toList(),
          )),
        ),
        const SizedBox(width: 8),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: entries.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: colors[e.key] ?? AppColors.textHint, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('${labels[e.key] ?? e.key} (${e.value})', style: const TextStyle(fontSize: 12)),
            ]),
          )).toList(),
        ),
      ]),
    );
  }

  /// Inventory value by category horizontal bar
  Widget _buildInventoryChart() {
    final dist = _inventoryByCategory();
    if (dist.isEmpty) return _ChartCard(title: 'Giá trị kho', icon: Icons.inventory_2_rounded, height: 260, child: const Center(child: Text('Chưa có sản phẩm')));
    final entries = dist.entries.toList();
    final maxVal = entries.first.value;
    final barColors = [AppColors.primary, AppColors.secondary, AppColors.warning, AppColors.info, AppColors.purple, AppColors.orange];
    return _ChartCard(
      title: 'Giá trị kho theo danh mục',
      icon: Icons.inventory_2_rounded,
      height: 260,
      child: BarChart(BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal < 1 ? 1 : maxVal * 1.2,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, gi, rod, ri) => BarTooltipItem('${entries[gi].key}\n${_cFmt.format(rod.toY)}đ',
              const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 50,
            getTitlesWidget: (v, _) {
              if (v >= 1000000) return Text('${(v / 1000000).toStringAsFixed(0)}tr', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary));
              if (v >= 1000) return Text('${(v / 1000).toStringAsFixed(0)}k', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary));
              return Text('${v.toInt()}', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary));
            })),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36,
            getTitlesWidget: (v, _) {
              final idx = v.toInt();
              if (idx < 0 || idx >= entries.length) return const SizedBox.shrink();
              return Padding(padding: const EdgeInsets.only(top: 6), child: Text(entries[idx].key, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)));
            })),
        ),
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border.withAlpha(60), strokeWidth: 0.5)),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(entries.length, (i) => BarChartGroupData(x: i, barRods: [
          BarChartRodData(toY: entries[i].value, color: barColors[i % barColors.length], width: 24,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6))),
        ])),
      )),
    );
  }

  /// Batch survival/mortality chart
  Widget _buildBatchSurvivalChart() {
    final batches = _batchMortalities().take(8).toList();
    if (batches.isEmpty) return _ChartCard(title: 'Tỷ lệ sống lô cá', icon: Icons.monitor_heart_rounded, height: 260, child: const Center(child: Text('Chưa có lô cá hoạt động')));
    return _ChartCard(
      title: 'Tỷ lệ sống / hao hụt',
      icon: Icons.monitor_heart_rounded,
      height: 260,
      legend: [_LegendDot('Sống', AppColors.success), _LegendDot('Hao hụt', AppColors.error)],
      child: BarChart(BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 105,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, gi, rod, ri) {
              final b = batches[gi];
              return BarTooltipItem('${b.name}\nSống: ${b.survivalRate.toStringAsFixed(1)}%\nHao hụt: ${b.mortalityRate.toStringAsFixed(1)}%',
                const TextStyle(color: Colors.white, fontSize: 11));
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36,
            getTitlesWidget: (v, _) => Text('${v.toInt()}%', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)))),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 38,
            getTitlesWidget: (v, _) {
              final idx = v.toInt();
              if (idx < 0 || idx >= batches.length) return const SizedBox.shrink();
              final n = batches[idx].name;
              return Padding(padding: const EdgeInsets.only(top: 6),
                child: Text(n.length > 8 ? '${n.substring(0, 7)}…' : n, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary), textAlign: TextAlign.center));
            })),
        ),
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border.withAlpha(60), strokeWidth: 0.5)),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(batches.length, (i) => BarChartGroupData(x: i, barRods: [
          BarChartRodData(
            toY: 100,
            rodStackItems: [
              BarChartRodStackItem(0, batches[i].survivalRate.clamp(0, 100), AppColors.success),
              BarChartRodStackItem(batches[i].survivalRate.clamp(0, 100), 100, AppColors.error.withAlpha(160)),
            ],
            width: 18, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            color: Colors.transparent,
          ),
        ])),
      )),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // CARD-LEVEL WIDGETS
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildQuickActions(BuildContext context) {
    return _ChartCard(
      title: 'Thao tác nhanh',
      icon: Icons.flash_on_rounded,
      height: null,
      child: Wrap(
        spacing: 10, runSpacing: 10,
        children: [
          _QuickBtn(Icons.add_circle_outline, 'Thêm ao', AppColors.primary, onAddPond),
          _QuickBtn(Icons.set_meal, 'Nhập giống', AppColors.secondary, onAddBatch),
          _QuickBtn(Icons.science, 'Đo nước', AppColors.info, onMeasureWater),
          _QuickBtn(Icons.shopping_bag, 'Tạo đơn bán', AppColors.success, onAddSale),
        ],
      ),
    );
  }

  Widget _buildRecentSales() {
    final orders = dp.saleOrders.toList()..sort((a, b) => b.date.compareTo(a.date));
    final recent = orders.take(5).toList();
    return _ChartCard(
      title: 'Đơn bán gần đây',
      icon: Icons.receipt_long_rounded,
      height: null,
      child: recent.isEmpty
          ? const Padding(padding: EdgeInsets.all(12), child: Text('Chưa có đơn bán', style: TextStyle(color: AppColors.textSecondary)))
          : Column(children: recent.map((o) {
              final cust = dp.customerById(o.customerId);
              final statusColor = o.status == 'completed' ? AppColors.success : o.status == 'cancelled' ? AppColors.error : AppColors.warning;
              final statusLabel = o.status == 'completed' ? 'Hoàn thành' : o.status == 'cancelled' ? 'Đã huỷ' : 'Chờ';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: statusColor.withAlpha(20), borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.receipt_rounded, size: 16, color: statusColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cust?.name ?? 'Khách lẻ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis),
                      Text('${_dateFmt.format(o.date)} • ${_cFmt.format(o.totalAmount)}đ', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  )),
                  _StatusChip(statusLabel, statusColor),
                ]),
              );
            }).toList()),
    );
  }

  Widget _buildAlerts() {
    return _ChartCard(
      title: 'Cảnh báo',
      icon: Icons.notifications_active_rounded,
      iconColor: AppColors.error,
      height: null,
      child: Column(
        children: [
          if (dp.overdueTasks > 0)
            _AlertTile(icon: Icons.timer_off_rounded, color: AppColors.error, title: '${dp.overdueTasks} công việc quá hạn', subtitle: 'Cần xử lý ngay'),
          if (dp.lowStockCount > 0)
            _AlertTile(icon: Icons.inventory_rounded, color: AppColors.warning, title: '${dp.lowStockCount} sản phẩm sắp hết', subtitle: 'Cần nhập thêm hàng'),
          if (dp.totalDebt > 0)
            _AlertTile(icon: Icons.account_balance_wallet_rounded, color: AppColors.info,
              title: 'Công nợ: ${_cFmt.format(dp.totalDebt)}đ', subtitle: '${dp.customers.where((c) => c.debt > 0).length} khách hàng'),
          if (dp.totalSupplierDebt > 0)
            _AlertTile(icon: Icons.store_rounded, color: AppColors.purple,
              title: 'Nợ NCC: ${_cFmt.format(dp.totalSupplierDebt)}đ', subtitle: 'Nhà cung cấp'),
          if (dp.overdueTasks == 0 && dp.lowStockCount == 0 && dp.totalDebt == 0 && dp.totalSupplierDebt == 0)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Row(children: [
                Icon(Icons.check_circle, color: AppColors.success, size: 18),
                SizedBox(width: 8),
                Text('Hệ thống hoạt động bình thường', style: TextStyle(color: AppColors.success, fontSize: 13)),
              ]),
            ),
        ],
      ),
    );
  }
}

// ── Dashboard helper classes ──

class _BatchMortality {
  final String name;
  final double mortalityRate;
  final double survivalRate;
  const _BatchMortality(this.name, this.mortalityRate, this.survivalRate);
}

class _LegendDot {
  final String label;
  final Color color;
  const _LegendDot(this.label, this.color);
}

class _MiniKpi extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _MiniKpi({required this.icon, required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.black, 0.15)!],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: color.withAlpha(50), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Stack(
        children: [
          // Decorative circle pattern
          Positioned(
            right: -12,
            top: -12,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(12),
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(8),
              ),
            ),
          ),
          // Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const Spacer(),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.5), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 1),
              Text(label, style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 10.5, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip(this.label, this.color);
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
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: AppText.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? iconColor;
  final double? height;
  final Widget child;
  final List<_LegendDot>? legend;
  const _ChartCard({required this.title, required this.icon, this.iconColor, required this.height, required this.child, this.legend});
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withAlpha(20)),
      ),
      child: Container(
        height: height,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: (iconColor ?? AppColors.primary).withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: iconColor ?? AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
              if (legend != null) ...legend!.map((l) => Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: l.color, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text(l.label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                ]),
              )),
            ]),
            const SizedBox(height: 14),
            if (height != null)
              Expanded(child: child)
            else
              child,
          ],
        ),
      ),
    );
  }
}

class _QuickBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickBtn(this.icon, this.label, this.color, this.onTap);
  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withAlpha(15),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _AlertTile({required this.icon, required this.color, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
