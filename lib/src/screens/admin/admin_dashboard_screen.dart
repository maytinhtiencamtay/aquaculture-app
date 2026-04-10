import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../routes.dart';
import '../../services/admin_service.dart';
import '../../theme/app_theme.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _adminService = AdminService();
  Map<String, dynamic>? _data;
  bool _loading = true;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final cached = await _adminService.getCachedAdmin();
    if (cached == null && mounted) {
      Navigator.of(context).pushReplacementNamed(Routes.adminLogin);
      return;
    }
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _loading = true);
    final data = await _adminService.getDashboard();
    if (mounted) setState(() { _data = data; _loading = false; });
  }

  Future<void> _logout() async {
    await _adminService.logout();
    if (mounted) Navigator.of(context).pushReplacementNamed(Routes.adminLogin);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: Row(
        children: [
          // Sidebar
          _buildSidebar(isWide),
          // Content
          Expanded(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: [
                      _buildOverviewTab(),
                      _StoresTab(adminService: _adminService),
                      _LicensesTab(adminService: _adminService),
                      _ActivityLogTab(adminService: _adminService),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(bool isWide) {
    return Container(
      width: isWide ? 240 : 72,
      color: const Color(0xFF0F172A),
      child: Column(
        children: [
          const SizedBox(height: 24),
          if (isWide)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.water, color: AppColors.primaryLight, size: 28),
                  SizedBox(width: 10),
                  Text('AQUA Admin', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          else
            const Icon(Icons.water, color: AppColors.primaryLight, size: 28),
          const SizedBox(height: 32),
          _sidebarItem(0, Icons.dashboard_outlined, 'Tổng quan', isWide),
          _sidebarItem(1, Icons.store_outlined, 'Cửa hàng', isWide),
          _sidebarItem(2, Icons.vpn_key_outlined, 'License', isWide),
          _sidebarItem(3, Icons.history_outlined, 'Nhật ký', isWide),
          const Spacer(),
          _sidebarItem(-2, Icons.lock_outline, 'Đổi mật khẩu', isWide, onTap: _showChangePasswordDialog),
          _sidebarItem(-1, Icons.logout, 'Đăng xuất', isWide, onTap: _logout),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _sidebarItem(int index, IconData icon, String label, bool isWide, {VoidCallback? onTap}) {
    final selected = _selectedIndex == index && index >= 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () => setState(() => _selectedIndex = index),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: isWide ? 20 : 0, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? Colors.white.withValues(alpha: 0.1) : null,
            border: selected ? const Border(left: BorderSide(color: AppColors.primaryLight, width: 3)) : null,
          ),
          child: isWide
              ? Row(children: [
                  Icon(icon, color: selected ? AppColors.primaryLight : Colors.white60, size: 22),
                  const SizedBox(width: 12),
                  Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white60, fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
                ])
              : Center(child: Icon(icon, color: selected ? AppColors.primaryLight : Colors.white60, size: 24)),
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool loading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.lock_outline, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Đổi mật khẩu Admin', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Mật khẩu hiện tại', prefixIcon: Icon(Icons.lock)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Mật khẩu mới', prefixIcon: Icon(Icons.lock_open)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Xác nhận mật khẩu mới', prefixIcon: Icon(Icons.lock_open)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            FilledButton(
              onPressed: loading ? null : () async {
                if (newCtrl.text != confirmCtrl.text) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Mật khẩu xác nhận không khớp'), backgroundColor: AppColors.error));
                  return;
                }
                if (newCtrl.text.length < 6) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Mật khẩu mới phải có ít nhất 6 ký tự'), backgroundColor: AppColors.error));
                  return;
                }
                setDState(() => loading = true);
                final error = await _adminService.changePassword(currentPassword: currentCtrl.text, newPassword: newCtrl.text);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(error ?? 'Đổi mật khẩu thành công!'),
                    backgroundColor: error != null ? AppColors.error : AppColors.success,
                  ));
                }
              },
              child: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Đổi mật khẩu'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Text(
            ['Tổng quan', 'Quản lý cửa hàng', 'Quản lý License', 'Nhật ký hoạt động'][_selectedIndex],
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const Spacer(),
          if (_selectedIndex == 0)
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadDashboard, tooltip: 'Làm mới'),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_data == null) return const Center(child: Text('Không thể tải dữ liệu'));

    final recentStores = (_data!['recentStores'] as List?) ?? [];
    final expiringLicenses = (_data!['expiringLicenses'] as List?) ?? [];
    final monthStats = (_data!['monthStats'] as List?) ?? [];
    final planDist = (_data!['planDistribution'] as Map<String, dynamic>?) ?? {};

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Cards
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _kpiCard('Cửa hàng', '${_data!['totalStores'] ?? 0}', Icons.store, AppColors.kpiPrimary),
                _kpiCard('Dùng thử', '${_data!['trialStores'] ?? 0}', Icons.card_giftcard, AppColors.orange),
                _kpiCard('Tạm ngưng', '${_data!['suspendedStores'] ?? 0}', Icons.block, AppColors.kpiDanger),
                _kpiCard('Nhân viên', '${_data!['totalEmployees'] ?? 0}', Icons.people, AppColors.kpiSuccess),
                _kpiCard('Ao nuôi', '${_data!['totalPonds'] ?? 0}', Icons.water, AppColors.kpiWarning),
                _kpiCard('License HĐ', '${_data!['activeLicenses'] ?? 0}', Icons.vpn_key, AppColors.kpiSuccess),
                _kpiCard('Hết hạn', '${_data!['expiredLicenses'] ?? 0}', Icons.warning, AppColors.kpiDanger),
              ],
            ),

            // Expiring licenses warning
            if (expiringLicenses.isNotEmpty) ...[
              const SizedBox(height: 24),
              Card(
                color: AppColors.orange.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: AppColors.orange.withValues(alpha: 0.3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: AppColors.orange),
                          const SizedBox(width: 8),
                          Text('License sắp hết hạn (${expiringLicenses.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.orange)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...expiringLicenses.map((l) {
                        final m = l as Map<String, dynamic>;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(child: Text('${m['storeName']} (${m['ownerEmail']})', style: const TextStyle(fontSize: 13))),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                child: Text('Còn ${m['daysLeft']} ngày', style: const TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 28,
                                child: OutlinedButton(
                                  onPressed: () {
                                    setState(() => _selectedIndex = 1);
                                  },
                                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10), textStyle: const TextStyle(fontSize: 11)),
                                  child: const Text('Gia hạn'),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Charts row
            if (monthStats.isNotEmpty || planDist.isNotEmpty)
              LayoutBuilder(builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 700;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    // Registration trend
                    if (monthStats.isNotEmpty)
                      SizedBox(
                        width: isNarrow ? constraints.maxWidth : (constraints.maxWidth - 16) / 2,
                        height: 240,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Đăng ký theo tháng', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 16),
                                Expanded(child: _buildBarChart(monthStats)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    // Plan distribution
                    if (planDist.isNotEmpty)
                      SizedBox(
                        width: isNarrow ? constraints.maxWidth : (constraints.maxWidth - 16) / 2,
                        height: 240,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Phân bố gói dịch vụ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Expanded(child: _buildPieChart(planDist)),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              }),

            const SizedBox(height: 24),
            // Recent stores
            const Text('Cửa hàng đăng ký gần đây', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Card(
              child: recentStores.isEmpty
                  ? const Padding(padding: EdgeInsets.all(24), child: Text('Chưa có cửa hàng nào'))
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: recentStores.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final s = recentStores[i] as Map<String, dynamic>;
                        final plan = s['licensePlan'] as String?;
                        final expiresAt = s['licenseExpiresAt'] != null ? DateTime.tryParse(s['licenseExpiresAt'].toString()) : null;
                        final isExpired = expiresAt != null && expiresAt.isBefore(DateTime.now());
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                            child: const Icon(Icons.store, color: AppColors.primary, size: 20),
                          ),
                          title: Row(
                            children: [
                              Flexible(child: Text(s['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
                              if (plan == 'trial') ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(color: AppColors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                  child: const Text('Dùng thử', style: TextStyle(fontSize: 10, color: AppColors.orange, fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            '${s['ownerEmail'] ?? ''}${expiresAt != null ? ' • HH: ${DateFormat('dd/MM/yyyy').format(expiresAt)}' : ''}',
                            style: TextStyle(fontSize: 12, color: isExpired ? AppColors.error : null),
                          ),
                          trailing: _statusBadge(s['status'] ?? 'active'),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(List monthStats) {
    final maxVal = monthStats.fold<double>(0, (prev, e) => (e['count'] as num).toDouble() > prev ? (e['count'] as num).toDouble() : prev);
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal < 1 ? 5 : maxVal + 1,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem('${rod.toY.toInt()}', const TextStyle(color: Colors.white, fontSize: 12));
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= monthStats.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text((monthStats[idx] as Map)['month'] ?? '', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)))),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxVal < 5 ? 1 : null),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(monthStats.length, (i) {
          return BarChartGroupData(x: i, barRods: [
            BarChartRodData(toY: (monthStats[i] as Map)['count']?.toDouble() ?? 0, color: AppColors.primary, width: 22, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
          ]);
        }),
      ),
    );
  }

  Widget _buildPieChart(Map<String, dynamic> planDist) {
    final entries = <MapEntry<String, int>>[];
    final colors = {'trial': AppColors.textSecondary, 'basic': AppColors.info, 'pro': const Color(0xFF7C3AED), 'enterprise': AppColors.orange};
    final labels = {'trial': 'Trial', 'basic': 'Basic', 'pro': 'Pro', 'enterprise': 'Enterprise'};
    for (final entry in planDist.entries) {
      final v = entry.value is int ? entry.value as int : 0;
      if (v > 0) entries.add(MapEntry(entry.key, v));
    }
    if (entries.isEmpty) return const Center(child: Text('Chưa có dữ liệu'));
    final total = entries.fold<int>(0, (s, e) => s + e.value);

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 30,
              sections: entries.map((e) {
                return PieChartSectionData(
                  value: e.value.toDouble(),
                  color: colors[e.key] ?? AppColors.textSecondary,
                  title: '${(e.value / total * 100).toStringAsFixed(0)}%',
                  titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                  radius: 50,
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: entries.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 12, height: 12, decoration: BoxDecoration(color: colors[e.key], borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 6),
                Text('${labels[e.key] ?? e.key}: ${e.value}', style: const TextStyle(fontSize: 12)),
              ],
            ),
          )).toList(),
        ),
      ],
    );
  }

  Widget _kpiCard(String title, String value, IconData icon, Color color) {
    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 12),
              Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final isActive = status == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (isActive ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isActive ? 'Hoạt động' : 'Tạm ngưng',
        style: TextStyle(color: isActive ? AppColors.success : AppColors.error, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Stores Tab
// ══════════════════════════════════════════════════════════════

class _StoresTab extends StatefulWidget {
  final AdminService adminService;
  const _StoresTab({required this.adminService});

  @override
  State<_StoresTab> createState() => _StoresTabState();
}

class _StoresTabState extends State<_StoresTab> {
  List<Map<String, dynamic>> _stores = [];
  bool _loading = true;
  String _search = '';
  String _filterStatus = 'all'; // all, active, suspended, expired
  String _filterPlan = 'all'; // all, trial, basic, pro, enterprise
  String _sortBy = 'newest'; // newest, name, expiring

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _stores = await widget.adminService.getStores();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggleStatus(Map<String, dynamic> store) async {
    final newStatus = store['status'] == 'active' ? 'suspended' : 'active';
    final ok = await widget.adminService.updateStoreStatus(store['_id'], newStatus);
    if (ok) _load();
  }

  Future<void> _resetPassword(Map<String, dynamic> store) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(children: [Icon(Icons.lock_reset, color: AppColors.orange), SizedBox(width: 8), Text('Reset mật khẩu', style: TextStyle(fontSize: 16))]),
        content: Text('Reset mật khẩu owner của "${store['name']}" thành "123456"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.orange),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final result = await widget.adminService.resetStorePassword(store['_id']);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.error ?? result.message ?? 'Đã reset mật khẩu'),
        backgroundColor: result.error != null ? AppColors.error : AppColors.success,
      ));
    }
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _stores.toList();

    // Status filter
    if (_filterStatus == 'active') {
      list = list.where((s) => s['status'] == 'active').toList();
    } else if (_filterStatus == 'suspended') {
      list = list.where((s) => s['status'] == 'suspended').toList();
    } else if (_filterStatus == 'expired') {
      list = list.where((s) {
        final lic = s['license'] as Map<String, dynamic>?;
        if (lic == null || lic['expiresAt'] == null) return false;
        return DateTime.tryParse(lic['expiresAt'].toString())?.isBefore(DateTime.now()) == true;
      }).toList();
    }

    // Plan filter
    if (_filterPlan != 'all') {
      list = list.where((s) {
        final lic = s['license'] as Map<String, dynamic>?;
        return lic?['plan'] == _filterPlan;
      }).toList();
    }

    // Search
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((s) =>
          (s['name'] ?? '').toString().toLowerCase().contains(q) ||
          (s['ownerEmail'] ?? '').toString().toLowerCase().contains(q) ||
          (s['ownerPhone'] ?? '').toString().toLowerCase().contains(q) ||
          (s['username'] ?? '').toString().toLowerCase().contains(q)).toList();
    }

    // Sort
    if (_sortBy == 'name') {
      list.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
    } else if (_sortBy == 'expiring') {
      list.sort((a, b) {
        final aExp = (a['license'] as Map?)?['expiresAt']?.toString() ?? '9999';
        final bExp = (b['license'] as Map?)?['expiresAt']?.toString() ?? '9999';
        return aExp.compareTo(bExp);
      });
    }
    // default: newest (already sorted from API)

    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final filtered = _filtered;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Search bar + actions
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm cửa hàng...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Làm mới'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text('Trạng thái: ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(width: 4),
                _filterChip('Tất cả', _filterStatus == 'all', () => setState(() => _filterStatus = 'all')),
                _filterChip('Hoạt động', _filterStatus == 'active', () => setState(() => _filterStatus = 'active')),
                _filterChip('Tạm ngưng', _filterStatus == 'suspended', () => setState(() => _filterStatus = 'suspended')),
                _filterChip('Hết hạn', _filterStatus == 'expired', () => setState(() => _filterStatus = 'expired')),
                const SizedBox(width: 16),
                const Text('Gói: ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(width: 4),
                _filterChip('Tất cả', _filterPlan == 'all', () => setState(() => _filterPlan = 'all')),
                _filterChip('Trial', _filterPlan == 'trial', () => setState(() => _filterPlan = 'trial')),
                _filterChip('Basic', _filterPlan == 'basic', () => setState(() => _filterPlan = 'basic')),
                _filterChip('Pro', _filterPlan == 'pro', () => setState(() => _filterPlan = 'pro')),
                _filterChip('Enterprise', _filterPlan == 'enterprise', () => setState(() => _filterPlan = 'enterprise')),
                const SizedBox(width: 16),
                const Text('Sắp xếp: ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(width: 4),
                _filterChip('Mới nhất', _sortBy == 'newest', () => setState(() => _sortBy = 'newest')),
                _filterChip('Tên', _sortBy == 'name', () => setState(() => _sortBy = 'name')),
                _filterChip('Sắp hết hạn', _sortBy == 'expiring', () => setState(() => _sortBy = 'expiring')),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Count
          Align(
            alignment: Alignment.centerLeft,
            child: Text('${filtered.length} / ${_stores.length} cửa hàng', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
          const SizedBox(height: 8),
          // Stores table
          Expanded(
            child: Card(
              child: filtered.isEmpty
                  ? const Center(child: Text('Không có cửa hàng nào'))
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final s = filtered[i];
                        return _StoreListItem(
                          store: s,
                          onToggleStatus: () => _toggleStatus(s),
                          onViewDetail: () => _showDetail(s['_id']),
                          onEditLicense: () => _showEditLicense(s),
                          onResetPassword: () => _resetPassword(s),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 11, color: selected ? Colors.white : AppColors.textPrimary)),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary,
        checkmarkColor: Colors.white,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  void _showDetail(String storeId) async {
    final detail = await widget.adminService.getStoreDetail(storeId);
    if (detail == null || !mounted) return;

    showDialog(
      context: context,
      builder: (_) => _StoreDetailDialog(
        store: detail,
        onToggleStatus: () async {
          final store = _stores.firstWhere((s) => s['_id'] == storeId, orElse: () => {});
          if (store.isNotEmpty) await _toggleStatus(store);
          if (mounted) Navigator.of(context).pop();
        },
        onEditLicense: () {
          Navigator.of(context).pop();
          final store = _stores.firstWhere((s) => s['_id'] == storeId, orElse: () => {});
          if (store.isNotEmpty) _showEditLicense(store);
        },
        onResetPassword: () async {
          Navigator.of(context).pop();
          final store = _stores.firstWhere((s) => s['_id'] == storeId, orElse: () => {});
          if (store.isNotEmpty) await _resetPassword(store);
        },
      ),
    );
  }

  void _showEditLicense(Map<String, dynamic> store) {
    final license = store['license'] as Map<String, dynamic>?;
    final currentExpiry = license?['expiresAt'] != null ? DateTime.tryParse(license!['expiresAt'].toString()) : null;
    final currentPlan = license?['plan'] as String? ?? 'trial';

    DateTime selectedDate = currentExpiry ?? DateTime.now().add(const Duration(days: 30));
    String selectedPlan = currentPlan;
    final addDaysCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.edit_calendar, color: AppColors.info),
              const SizedBox(width: 8),
              Expanded(child: Text('Chỉnh ngày sử dụng — ${store['name']}', style: const TextStyle(fontSize: 16))),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (currentExpiry != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Hiện tại: $currentPlan — HH ${DateFormat('dd/MM/yyyy').format(currentExpiry)}'
                          '${currentExpiry.isBefore(DateTime.now()) ? ' (ĐÃ HẾT HẠN)' : ' (còn ${currentExpiry.difference(DateTime.now()).inDays} ngày)'}',
                      style: TextStyle(
                        fontSize: 13,
                        color: currentExpiry.isBefore(DateTime.now()) ? AppColors.error : AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Gói dịch vụ', isDense: true),
                  value: selectedPlan,
                  items: const [
                    DropdownMenuItem(value: 'trial', child: Text('Trial (Dùng thử)')),
                    DropdownMenuItem(value: 'basic', child: Text('Basic (Cơ bản)')),
                    DropdownMenuItem(value: 'pro', child: Text('Pro (Chuyên nghiệp)')),
                    DropdownMenuItem(value: 'enterprise', child: Text('Enterprise (Doanh nghiệp)')),
                  ],
                  onChanged: (v) => setDState(() => selectedPlan = v ?? 'trial'),
                ),
                const SizedBox(height: 16),
                const Text('Chọn ngày hết hạn:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null) setDState(() => selectedDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Text(DateFormat('dd/MM/yyyy').format(selectedDate), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        const Icon(Icons.edit, size: 16, color: AppColors.textHint),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Hoặc thêm ngày:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final d in [7, 15, 30, 90, 365])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          label: Text('+${d}d', style: const TextStyle(fontSize: 12)),
                          onPressed: () async {
                            final result = await widget.adminService.updateStoreLicense(
                              storeId: store['_id'],
                              addDays: d,
                              plan: selectedPlan,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (result.error == null) {
                              _load();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text('Đã thêm $d ngày cho ${store['name']}'),
                                  backgroundColor: AppColors.success,
                                ));
                              }
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            FilledButton(
              onPressed: () async {
                final result = await widget.adminService.updateStoreLicense(
                  storeId: store['_id'],
                  expiresAt: selectedDate.toIso8601String(),
                  plan: selectedPlan,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (result.error == null) {
                  _load();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Đã cập nhật license cho ${store['name']}'),
                      backgroundColor: AppColors.success,
                    ));
                  }
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(result.error ?? 'Lỗi'),
                    backgroundColor: AppColors.error,
                  ));
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreListItem extends StatelessWidget {
  final Map<String, dynamic> store;
  final VoidCallback onToggleStatus;
  final VoidCallback onViewDetail;
  final VoidCallback? onEditLicense;
  final VoidCallback? onResetPassword;

  const _StoreListItem({required this.store, required this.onToggleStatus, required this.onViewDetail, this.onEditLicense, this.onResetPassword});

  @override
  Widget build(BuildContext context) {
    final isActive = store['status'] == 'active';
    final license = store['license'] as Map<String, dynamic>?;
    final lastActivity = store['lastActivity'] != null ? DateTime.tryParse(store['lastActivity'].toString()) : null;
    final daysSince = store['daysSinceActivity'] as int?;
    final plan = license?['plan'] as String?;
    final expiresAt = license?['expiresAt'] != null ? DateTime.tryParse(license!['expiresAt'].toString()) : null;
    final isExpired = expiresAt != null && expiresAt.isBefore(DateTime.now());
    final daysLeft = expiresAt != null ? expiresAt.difference(DateTime.now()).inDays : null;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
        child: const Icon(Icons.store, color: AppColors.primary),
      ),
      title: Row(
        children: [
          Flexible(child: Text(store['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: (isActive ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              isActive ? 'Hoạt động' : 'Tạm ngưng',
              style: TextStyle(color: isActive ? AppColors.success : AppColors.error, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          if (plan == 'trial') ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppColors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: const Text('Dùng thử', style: TextStyle(fontSize: 10, color: AppColors.orange, fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            Text('${store['ownerEmail'] ?? ''}', style: const TextStyle(fontSize: 12)),
            if (store['username'] != null && store['username'].toString().isNotEmpty)
              Text('@${store['username']}', style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500)),
            Text('NV: ${store['employeeCount'] ?? 0}', style: const TextStyle(fontSize: 12)),
            Text('Ao: ${store['pondCount'] ?? 0}', style: const TextStyle(fontSize: 12)),
            if (license != null)
              Text(
                '${plan ?? ''} → ${daysLeft != null ? (isExpired ? 'Hết hạn' : 'Còn $daysLeft ngày') : ''}',
                style: TextStyle(fontSize: 12, color: isExpired ? AppColors.error : AppColors.info, fontWeight: FontWeight.w500),
              ),
            if (daysSince != null)
              Text(
                daysSince == 0 ? 'HĐ: Hôm nay' : 'HĐ: ${daysSince}d trước',
                style: TextStyle(fontSize: 12, color: daysSince > 7 ? AppColors.textHint : AppColors.success, fontWeight: FontWeight.w500),
              )
            else
              const Text('HĐ: Chưa có', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
          ],
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.lock_reset, size: 20, color: AppColors.orange),
            onPressed: onResetPassword,
            tooltip: 'Reset mật khẩu',
          ),
          IconButton(
            icon: const Icon(Icons.edit_calendar, size: 20, color: AppColors.info),
            onPressed: onEditLicense,
            tooltip: 'Chỉnh ngày sử dụng',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, size: 20),
            onPressed: onViewDetail,
            tooltip: 'Chi tiết',
          ),
          IconButton(
            icon: Icon(isActive ? Icons.block : Icons.check_circle_outline, size: 20, color: isActive ? AppColors.error : AppColors.success),
            onPressed: onToggleStatus,
            tooltip: isActive ? 'Tạm ngưng' : 'Kích hoạt',
          ),
        ],
      ),
    );
  }
}

class _StoreDetailDialog extends StatelessWidget {
  final Map<String, dynamic> store;
  final VoidCallback? onToggleStatus;
  final VoidCallback? onEditLicense;
  final VoidCallback? onResetPassword;
  const _StoreDetailDialog({required this.store, this.onToggleStatus, this.onEditLicense, this.onResetPassword});

  @override
  Widget build(BuildContext context) {
    final employees = (store['employees'] as List?) ?? [];
    final branches = (store['branches'] as List?) ?? [];
    final licenses = (store['licenses'] as List?) ?? [];

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.store, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(store['name'] ?? '', style: const TextStyle(fontSize: 18))),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _infoRow('Chủ cửa hàng', store['ownerName'] ?? ''),
              _infoRow('Email', store['ownerEmail'] ?? ''),
              _infoRow('Địa chỉ', store['address'] ?? ''),
              _infoRow('Liên hệ', store['contact'] ?? ''),
              _infoRow('Trạng thái', store['status'] == 'active' ? 'Hoạt động' : 'Tạm ngưng'),
              _infoRow('Số ao', '${store['pondCount'] ?? 0}'),
              _infoRow('Số khu', '${store['zoneCount'] ?? 0}'),
              _infoRow('Số lô cá', '${store['batchCount'] ?? 0}'),
              const Divider(height: 24),
              Text('Chi nhánh (${branches.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
              ...branches.map((b) => Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4),
                    child: Text('• ${b['name']} – ${b['address'] ?? ''}', style: const TextStyle(fontSize: 13)),
                  )),
              const Divider(height: 24),
              Text('Nhân viên (${employees.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
              ...employees.map((e) => Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4),
                    child: Text('• ${e['name']} (${e['role']}) – ${e['email'] ?? e['phone'] ?? ''}', style: const TextStyle(fontSize: 13)),
                  )),
              if (licenses.isNotEmpty) ...[
                const Divider(height: 24),
                Text('License (${licenses.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                ...licenses.map((l) => Padding(
                      padding: const EdgeInsets.only(left: 8, top: 4),
                      child: Text('• ${l['key']} [${l['plan']}] – ${l['status']}', style: const TextStyle(fontSize: 13)),
                    )),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (onResetPassword != null)
          TextButton.icon(
            onPressed: onResetPassword,
            icon: const Icon(Icons.lock_reset, size: 16, color: AppColors.orange),
            label: const Text('Reset MK', style: TextStyle(color: AppColors.orange)),
          ),
        if (onEditLicense != null)
          TextButton.icon(
            onPressed: onEditLicense,
            icon: const Icon(Icons.edit_calendar, size: 16, color: AppColors.info),
            label: const Text('Gia hạn', style: TextStyle(color: AppColors.info)),
          ),
        if (onToggleStatus != null)
          TextButton.icon(
            onPressed: onToggleStatus,
            icon: Icon(
              store['status'] == 'active' ? Icons.block : Icons.check_circle_outline,
              size: 16,
              color: store['status'] == 'active' ? AppColors.error : AppColors.success,
            ),
            label: Text(
              store['status'] == 'active' ? 'Tạm ngưng' : 'Kích hoạt',
              style: TextStyle(color: store['status'] == 'active' ? AppColors.error : AppColors.success),
            ),
          ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Đóng')),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text('$label:', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Licenses Tab
// ══════════════════════════════════════════════════════════════

class _LicensesTab extends StatefulWidget {
  final AdminService adminService;
  const _LicensesTab({required this.adminService});

  @override
  State<_LicensesTab> createState() => _LicensesTabState();
}

class _LicensesTabState extends State<_LicensesTab> {
  List<Map<String, dynamic>> _licenses = [];
  List<Map<String, dynamic>> _stores = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([widget.adminService.getLicenses(), widget.adminService.getStores()]);
    if (mounted) {
      setState(() {
        _licenses = results[0];
        _stores = results[1];
        _loading = false;
      });
    }
  }

  void _showCreateDialog() {
    String? selectedStoreId;
    String selectedPlan = 'basic';
    final daysCtrl = TextEditingController(text: '30');
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: const Text('Tạo License mới'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Cửa hàng'),
                  value: selectedStoreId,
                  items: _stores.map((s) => DropdownMenuItem(value: s['_id'] as String, child: Text(s['name'] ?? ''))).toList(),
                  onChanged: (v) => setDState(() => selectedStoreId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Gói dịch vụ'),
                  value: selectedPlan,
                  items: const [
                    DropdownMenuItem(value: 'trial', child: Text('Trial (Dùng thử)')),
                    DropdownMenuItem(value: 'basic', child: Text('Basic (Cơ bản)')),
                    DropdownMenuItem(value: 'pro', child: Text('Pro (Chuyên nghiệp)')),
                    DropdownMenuItem(value: 'enterprise', child: Text('Enterprise (Doanh nghiệp)')),
                  ],
                  onChanged: (v) => setDState(() => selectedPlan = v ?? 'basic'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: daysCtrl,
                  decoration: const InputDecoration(labelText: 'Số ngày', suffixText: 'ngày'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(labelText: 'Ghi chú'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            FilledButton(
              onPressed: () async {
                if (selectedStoreId == null) return;
                final days = int.tryParse(daysCtrl.text) ?? 0;
                if (days <= 0) return;
                final result = await widget.adminService.createLicense(
                  storeId: selectedStoreId!,
                  plan: selectedPlan,
                  durationDays: days,
                  note: noteCtrl.text.isEmpty ? null : noteCtrl.text,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (result.license != null) {
                  _load();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Đã tạo license: ${result.license!['key']}'),
                      backgroundColor: AppColors.success,
                    ));
                  }
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(result.error ?? 'Lỗi'),
                    backgroundColor: AppColors.error,
                  ));
                }
              },
              child: const Text('Tạo'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              Text('Tổng: ${_licenses.length} license', style: const TextStyle(color: AppColors.textSecondary)),
              const Spacer(),
              FilledButton.icon(
                onPressed: _showCreateDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Tạo License'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Làm mới'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: _licenses.isEmpty
                  ? const Center(child: Text('Chưa có license nào'))
                  : ListView.separated(
                      itemCount: _licenses.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final l = _licenses[i];
                        final expired = l['expiresAt'] != null && DateTime.tryParse(l['expiresAt'])?.isBefore(DateTime.now()) == true;
                        final statusText = l['status'] == 'active'
                            ? (expired ? 'Hết hạn' : 'Hoạt động')
                            : l['status'] == 'replaced'
                                ? 'Đã thay thế'
                                : l['status'] ?? '';
                        final statusColor = l['status'] == 'active' && !expired
                            ? AppColors.success
                            : l['status'] == 'replaced'
                                ? AppColors.textSecondary
                                : AppColors.error;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: Icon(Icons.vpn_key, color: statusColor),
                          title: Row(
                            children: [
                              SelectableText(l['key'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'monospace', fontSize: 14)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: _planColor(l['plan']).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                                child: Text(l['plan'] ?? '', style: TextStyle(color: _planColor(l['plan']), fontSize: 11, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Wrap(
                              spacing: 16,
                              children: [
                                Text(l['storeName'] ?? '', style: const TextStyle(fontSize: 12)),
                                Text('${l['durationDays'] ?? 0} ngày', style: const TextStyle(fontSize: 12)),
                                Text('HH: ${_formatDate(l['expiresAt'])}', style: const TextStyle(fontSize: 12)),
                                Text(statusText, style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          trailing: l['status'] == 'active'
                              ? IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text('Xác nhận xóa'),
                                        content: Text('Xóa license ${l['key']}?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
                                          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa')),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await widget.adminService.deleteLicense(l['_id']);
                                      _load();
                                    }
                                  },
                                  tooltip: 'Xóa',
                                )
                              : null,
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Color _planColor(dynamic plan) {
    switch (plan) {
      case 'trial': return AppColors.textSecondary;
      case 'basic': return AppColors.info;
      case 'pro': return AppColors.purple;
      case 'enterprise': return AppColors.orange;
      default: return AppColors.textSecondary;
    }
  }

  String _formatDate(dynamic d) {
    if (d == null) return '';
    final dt = DateTime.tryParse(d.toString());
    if (dt == null) return '';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ══════════════════════════════════════════════════════════════
// Activity Log Tab
// ══════════════════════════════════════════════════════════════

class _ActivityLogTab extends StatefulWidget {
  final AdminService adminService;
  const _ActivityLogTab({required this.adminService});

  @override
  State<_ActivityLogTab> createState() => _ActivityLogTabState();
}

class _ActivityLogTabState extends State<_ActivityLogTab> {
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _logs = await widget.adminService.getAdminLogs();
    if (mounted) setState(() => _loading = false);
  }

  IconData _actionIcon(String action) {
    switch (action) {
      case 'activate_store': return Icons.check_circle;
      case 'suspend_store': return Icons.block;
      case 'update_license': return Icons.edit_calendar;
      case 'create_license': return Icons.add_circle;
      case 'delete_license': return Icons.delete;
      case 'reset_store_password': return Icons.lock_reset;
      case 'change_password': return Icons.lock;
      case 'export_stores': return Icons.download;
      default: return Icons.info_outline;
    }
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'activate_store': return AppColors.success;
      case 'suspend_store': return AppColors.error;
      case 'update_license': return AppColors.info;
      case 'create_license': return AppColors.success;
      case 'delete_license': return AppColors.error;
      case 'reset_store_password': return AppColors.orange;
      case 'change_password': return AppColors.primary;
      case 'export_stores': return AppColors.textSecondary;
      default: return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              Text('${_logs.length} hoạt động gần đây', style: const TextStyle(color: AppColors.textSecondary)),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Làm mới'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: _logs.isEmpty
                  ? const Center(child: Text('Chưa có hoạt động nào'))
                  : ListView.separated(
                      itemCount: _logs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final log = _logs[i];
                        final action = log['action'] as String? ?? '';
                        final createdAt = log['createdAt'] != null ? DateTime.tryParse(log['createdAt'].toString()) : null;
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: _actionColor(action).withValues(alpha: 0.1),
                            child: Icon(_actionIcon(action), color: _actionColor(action), size: 18),
                          ),
                          title: Text(
                            log['description'] ?? action,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            '${log['adminEmail'] ?? ''}${createdAt != null ? ' • ${DateFormat('dd/MM/yyyy HH:mm').format(createdAt)}' : ''}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                          dense: true,
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
