import 'package:flutter/material.dart';

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
          const Spacer(),
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
            ['Tổng quan', 'Quản lý cửa hàng', 'Quản lý License'][_selectedIndex],
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
                _kpiCard('Nhân viên', '${_data!['totalEmployees'] ?? 0}', Icons.people, AppColors.kpiSuccess),
                _kpiCard('Ao nuôi', '${_data!['totalPonds'] ?? 0}', Icons.water, AppColors.kpiWarning),
                _kpiCard('Lô cá', '${_data!['totalBatches'] ?? 0}', Icons.set_meal, AppColors.kpiPurple),
                _kpiCard('License hoạt động', '${_data!['activeLicenses'] ?? 0}', Icons.vpn_key, AppColors.kpiSuccess),
                _kpiCard('License hết hạn', '${_data!['expiredLicenses'] ?? 0}', Icons.warning, AppColors.kpiDanger),
              ],
            ),
            const SizedBox(height: 32),
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
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                            child: const Icon(Icons.store, color: AppColors.primary, size: 20),
                          ),
                          title: Text(s['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(s['ownerEmail'] ?? '', style: const TextStyle(fontSize: 12)),
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

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _stores;
    final q = _search.toLowerCase();
    return _stores.where((s) =>
        (s['name'] ?? '').toString().toLowerCase().contains(q) ||
        (s['ownerEmail'] ?? '').toString().toLowerCase().contains(q) ||
        (s['ownerPhone'] ?? '').toString().toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Search bar
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
          const SizedBox(height: 16),
          // Stores table
          Expanded(
            child: Card(
              child: _filtered.isEmpty
                  ? const Center(child: Text('Không có cửa hàng nào'))
                  : ListView.separated(
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final s = _filtered[i];
                        return _StoreListItem(
                          store: s,
                          onToggleStatus: () => _toggleStatus(s),
                          onViewDetail: () => _showDetail(s['_id']),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetail(String storeId) async {
    final detail = await widget.adminService.getStoreDetail(storeId);
    if (detail == null || !mounted) return;

    showDialog(
      context: context,
      builder: (_) => _StoreDetailDialog(store: detail),
    );
  }
}

class _StoreListItem extends StatelessWidget {
  final Map<String, dynamic> store;
  final VoidCallback onToggleStatus;
  final VoidCallback onViewDetail;

  const _StoreListItem({required this.store, required this.onToggleStatus, required this.onViewDetail});

  @override
  Widget build(BuildContext context) {
    final isActive = store['status'] == 'active';
    final license = store['license'] as Map<String, dynamic>?;

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
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          spacing: 16,
          children: [
            Text('${store['ownerEmail'] ?? ''}', style: const TextStyle(fontSize: 12)),
            Text('NV: ${store['employeeCount'] ?? 0}', style: const TextStyle(fontSize: 12)),
            Text('Ao: ${store['pondCount'] ?? 0}', style: const TextStyle(fontSize: 12)),
            if (license != null)
              Text('${license['plan']} → ${_formatDate(license['expiresAt'])}', style: const TextStyle(fontSize: 12, color: AppColors.info)),
          ],
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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

  String _formatDate(dynamic d) {
    if (d == null) return '';
    final dt = DateTime.tryParse(d.toString());
    if (dt == null) return '';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _StoreDetailDialog extends StatelessWidget {
  final Map<String, dynamic> store;
  const _StoreDetailDialog({required this.store});

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
