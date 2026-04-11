import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:html' as html;
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../models/branch.dart';
import '../models/zone.dart';
import '../models/pond.dart';
import '../models/species.dart';
import '../models/fish_batch.dart';
import '../models/employee.dart';
import '../models/task.dart';
import '../models/customer.dart';
import '../models/sale_order.dart';
import '../models/size_measurement.dart';
import '../models/product.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/farm_map_view.dart';
import '../widgets/warehouse_view.dart';
import '../widgets/payment_voucher_view.dart';
import '../widgets/report_view.dart';
import '../widgets/skeleton_loading.dart';
import '../services/notification_service.dart';
import '../services/export_service.dart';
import 'views/customer_view.dart';
import 'views/water_standards_view.dart';
import 'views/notification_page.dart';
import 'views/aqua_operations_view.dart';
import 'views/dashboard_view.dart';
import '../widgets/paginated_list_view.dart';

// ════════════════════════════════════════════════════════════════════════════════
// MAIN SCREEN – Responsive shell with gradient sidebar / bottom nav
// ════════════════════════════════════════════════════════════════════════════════

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  String? _subModuleKey; // null = show main view, non-null = show sub-module inline
  late final AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  // All nav items with required permission key
  static const _allNavItems = <_NavItem>[
    _NavItem(Icons.dashboard_rounded, 'Tổng quan', 'dashboard'),
    _NavItem(Icons.map_rounded, 'Sơ đồ trại', 'farm_map'),
    _NavItem(Icons.biotech_rounded, 'Vận hành', 'operations'),
    _NavItem(Icons.task_alt_rounded, 'Công việc', 'tasks'),
    _NavItem(Icons.bar_chart_rounded, 'Báo cáo', 'reports'),
    _NavItem(Icons.inventory_2_rounded, 'Kho', 'warehouse'),
    _NavItem(Icons.receipt_long_rounded, 'Thu chi', 'reports'),
    _NavItem(Icons.settings_rounded, 'Cài đặt', 'settings'),
  ];

  /// Filtered nav items based on user role permissions
  List<_NavItem> _getVisibleNavItems(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null || user.isOwner) return _allNavItems;
    return _allNavItems.where((item) => user.hasPermission(item.permission)).toList();
  }

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);
    _fadeCtrl.forward();
    _restoreFromUrlHash();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dp = context.read<DataProvider>();
      // Ensure token is set BEFORE loading data
      final auth = context.read<AuthProvider>();
      if (auth.user != null) {
        dp.setToken(auth.user!.token);
      }
      // Auto-logout on 401 (expired token)
      dp.onUnauthorized = () async {
        if (!mounted) return;
        dp.onUnauthorized = null; // fire only once
        await auth.signOut();
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
      };
      dp.loadAll().then((_) {
        // Start periodic notification checks + midnight overdue refresh after data loaded
        NotificationService.startPeriodicCheck(dp);
        NotificationService.startMidnightRefresh(dp);
      });
    });
  }

  /// Restore navigation state from browser URL hash (e.g. #dashboard/pond).
  void _restoreFromUrlHash() {
    final hash = html.window.location.hash.replaceFirst('#', '');
    if (hash.isEmpty) return;
    final parts = hash.split('/');
    final base = parts[0];
    final idx = _allNavItems.indexWhere((n) => n.permission == base);
    if (idx >= 0) {
      _currentIndex = idx;
      if (parts.length > 1) _subModuleKey = parts[1];
    }
  }

  @override
  void dispose() {
    NotificationService.stop();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _onNav(int idx) {
    if (idx == _currentIndex && _subModuleKey == null) return;
    _fadeCtrl.reverse().then((_) {
      setState(() { _currentIndex = idx; _subModuleKey = null; });
      _updateUrlHash(null);
      _fadeCtrl.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 860;
    final dp = context.watch<DataProvider>();
    final navItems = _getVisibleNavItems(context);
    // Clamp index if role changed and nav items reduced
    if (navItems.isEmpty) {
      return const Scaffold(body: Center(child: Text('Không có quyền truy cập')));
    }
    if (_currentIndex >= navItems.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      body: Row(
        children: [
          if (wide) _buildSidebar(navItems),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(dp, wide, navItems),
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: dp.loading
                        ? _buildSkeleton(navItems)
                        : _buildBody(dp, navItems),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      drawer: wide ? null : _buildDrawer(navItems),
      bottomNavigationBar: wide
          ? null
          : _buildBottomNav(navItems),
    );
  }

  // ── Gradient Sidebar (desktop) ──
  Widget _buildSidebar(List<_NavItem> navItems) {
    return Container(
      width: AppSizes.sidebarWidth,
      decoration: const BoxDecoration(gradient: AppColors.gradientSidebar),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: AppSpace.xl),
            // Logo / Brand – refined with double-ring indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.sm),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF67E8F9), Color(0xFF0891B2)]),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: const Color(0xFF0891B2).withAlpha(60), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: const Icon(Icons.water_drop_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AQUA', style: AppText.headline.copyWith(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 2)),
                        Text('Manager Pro', style: AppText.caption.copyWith(color: Colors.white60, fontSize: 11, letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            // Divider line
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(height: 1, decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.white.withAlpha(0), Colors.white.withAlpha(30), Colors.white.withAlpha(0)]),
              )),
            ),
            const SizedBox(height: AppSpace.lg),
            // Nav items
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: navItems.length,
                itemBuilder: (_, i) {
                  final item = navItems[i];
                  final selected = i == _currentIndex;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                        hoverColor: Colors.white.withAlpha(12),
                        splashColor: Colors.white.withAlpha(20),
                        onTap: () => _onNav(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            color: selected ? Colors.white.withAlpha(20) : Colors.transparent,
                            borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                          ),
                          child: Row(
                            children: [
                              // Active indicator bar
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                width: 3,
                                height: selected ? 22 : 0,
                                margin: const EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                  color: selected ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              // Icon with glow
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: selected ? BoxDecoration(
                                  color: Colors.white.withAlpha(15),
                                  borderRadius: BorderRadius.circular(8),
                                ) : null,
                                child: Icon(item.icon, color: selected ? Colors.white : Colors.white54, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(item.label,
                                  style: TextStyle(
                                    color: selected ? Colors.white : Colors.white54,
                                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                    fontSize: 14,
                                    letterSpacing: selected ? 0.2 : 0,
                                  )),
                              ),
                              // Selected dot indicator
                              if (selected)
                                Container(
                                  width: 6, height: 6,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(color: AppColors.primaryLight.withAlpha(80), blurRadius: 6)],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Version badge
            Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withAlpha(15)),
                ),
                child: Text('v1.2.0', style: TextStyle(color: Colors.white.withAlpha(80), fontSize: 11)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top bar ──
  Widget _buildTopBar(DataProvider dp, bool wide, List<_NavItem> navItems) {
    // Greeting based on hour
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Chào buổi sáng' : hour < 18 ? 'Chào buổi chiều' : 'Chào buổi tối';
    final auth = context.read<AuthProvider>();
    final userName = auth.user?.displayName ?? '';

    return Container(
      padding: EdgeInsets.only(
        left: wide ? AppSpace.xxl : AppSpace.sm,
        right: AppSpace.lg,
        top: MediaQuery.of(context).padding.top + AppSpace.sm,
        bottom: AppSpace.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          if (!wide)
            IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          if (!wide) const SizedBox(width: AppSpace.xs),
          // Page title + greeting
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(navItems[_currentIndex].label, style: AppText.headline),
                if (wide && userName.isNotEmpty)
                  Text('$greeting, $userName', style: AppText.caption.copyWith(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          // Global search pill
          Container(
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
              tooltip: 'Tìm kiếm',
              onPressed: () => _showSearchDialog(dp),
            ),
          ),
          const SizedBox(width: 4),
          // Export
          Container(
            decoration: BoxDecoration(
              color: AppColors.success.withAlpha(8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: const ExcelIcon(size: 20),
              tooltip: 'Xuất dữ liệu',
              onPressed: () => _showExportDialog(dp),
            ),
          ),
          const SizedBox(width: 4),
          // Notification badge – animated
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: dp.unreadNotifications > 0 ? AppColors.error.withAlpha(8) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  icon: Icon(
                    dp.unreadNotifications > 0 ? Icons.notifications_active_rounded : Icons.notifications_outlined,
                    color: dp.unreadNotifications > 0 ? AppColors.error : AppColors.textSecondary,
                    size: 21,
                  ),
                  tooltip: 'Thông báo',
                  onPressed: () => _navigateToSubModule(context, 'notifications', dp),
                ),
              ),
              if (dp.unreadNotifications > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: AppColors.error.withAlpha(60), blurRadius: 6)],
                      ),
                      child: Text('${dp.unreadNotifications}',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 6),
          // Avatar with gradient ring
          GestureDetector(
            onTap: () => _showProfilePage(dp),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
              ),
              child: CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.surface,
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Drawer (mobile) ──
  Widget _buildDrawer(List<_NavItem> navItems) {
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(gradient: AppColors.gradientSidebar),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF67E8F9), Color(0xFF0891B2)]),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: const Color(0xFF0891B2).withAlpha(60), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: const Icon(Icons.water_drop_rounded, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AQUA', style: AppText.headline.copyWith(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 2)),
                        Text('Manager Pro', style: AppText.caption.copyWith(color: Colors.white60, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(height: 1, decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.white.withAlpha(0), Colors.white.withAlpha(30), Colors.white.withAlpha(0)]),
                )),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  itemCount: navItems.length,
                  itemBuilder: (_, i) {
                    final item = navItems[i];
                    final sel = i == _currentIndex;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        leading: Icon(item.icon, color: sel ? Colors.white : Colors.white60, size: 22),
                        title: Text(item.label, style: TextStyle(color: sel ? Colors.white : Colors.white70, fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
                        selected: sel,
                        selectedTileColor: Colors.white.withAlpha(20),
                        onTap: () {
                          _onNav(i);
                          Navigator.pop(context);
                        },
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withAlpha(15)),
                  ),
                  child: Text('v1.2.0', style: TextStyle(color: Colors.white.withAlpha(80), fontSize: 11)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Bottom Nav (mobile) ──
  Widget _buildBottomNav(List<_NavItem> navItems) {
    // Show up to 5 items; if more than 5, show first 4 + "More" overflow
    if (navItems.length <= 5) {
      return NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onNav,
        destinations: navItems
            .map((e) => NavigationDestination(icon: Icon(e.icon), label: e.label))
            .toList(),
      );
    }
    // More than 5 items: first 4 + "Thêm" menu item
    final shown = navItems.take(4).toList();
    final overflow = navItems.skip(4).toList();
    final isOverflowSelected = _currentIndex >= 4;
    return NavigationBar(
      selectedIndex: isOverflowSelected ? 4 : _currentIndex,
      onDestinationSelected: (idx) {
        if (idx < 4) {
          _onNav(idx);
        } else {
          // Show overflow menu
          _showBottomNavOverflow(overflow);
        }
      },
      destinations: [
        ...shown.map((e) => NavigationDestination(icon: Icon(e.icon), label: e.label)),
        NavigationDestination(
          icon: Icon(
            isOverflowSelected
                ? (navItems[_currentIndex].icon)
                : Icons.more_horiz_rounded,
            color: isOverflowSelected ? AppColors.primary : null,
          ),
          label: isOverflowSelected ? navItems[_currentIndex].label : 'Thêm',
        ),
      ],
    );
  }

  void _showBottomNavOverflow(List<_NavItem> overflow) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 8),
            ...overflow.asMap().entries.map((e) {
              final realIndex = 4 + e.key;
              final item = e.value;
              final sel = _currentIndex == realIndex;
              return ListTile(
                leading: Icon(item.icon, color: sel ? AppColors.primary : AppColors.textSecondary),
                title: Text(item.label, style: TextStyle(
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                  color: sel ? AppColors.primary : AppColors.textPrimary,
                )),
                selected: sel,
                selectedTileColor: AppColors.primary.withAlpha(15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _onNav(realIndex);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _navigateToSubModule(BuildContext ctx, String key, DataProvider dp) {
    if (_fadeCtrl.isAnimating) {
      // If already animating, just set the state directly
      setState(() => _subModuleKey = key);
      _updateUrlHash(null);
      return;
    }
    _fadeCtrl.reverse().then((_) {
      if (!mounted) return;
      setState(() => _subModuleKey = key);
      _updateUrlHash(null);
      _fadeCtrl.forward();
    });
  }

  /// Navigate from notification tap — handles both main nav tabs and sub-modules
  void _navigateFromNotification(String key, DataProvider dp) {
    // Map of keys that are main nav tabs (not sub-modules)
    final navItems = _getVisibleNavItems(context);
    final mainTabPermissions = {for (var i = 0; i < navItems.length; i++) navItems[i].permission: i};

    void doNavigate() {
      if (!mounted) return;
      if (mainTabPermissions.containsKey(key)) {
        setState(() {
          _currentIndex = mainTabPermissions[key]!;
          _subModuleKey = null;
        });
        _updateUrlHash(navItems);
      } else {
        setState(() => _subModuleKey = key);
        _updateUrlHash(null);
      }
      _fadeCtrl.forward();
    }

    if (_fadeCtrl.isAnimating) {
      doNavigate();
    } else {
      _fadeCtrl.reverse().then((_) => doNavigate());
    }
  }

  /// Sync browser URL hash with the current view.
  void _updateUrlHash(List<_NavItem>? navItems) {
    final items = navItems ?? _getVisibleNavItems(context);
    final base = items[_currentIndex].permission;
    final hash = _subModuleKey != null ? '$base/$_subModuleKey' : base;
    html.window.history.replaceState(null, '', '#$hash');
  }

  /// Returns (title, widget) for the current sub-module, or null if key is invalid.
  (String, Widget)? _buildSubModuleContent(DataProvider dp) {
    switch (_subModuleKey) {
      case 'pond':
        return ('Ao nuôi', _PondView(
          dp: dp,
          onCreate: () => _showPondDialog(dp),
          onEdit: (p) => _showPondDialog(dp, p),
          onDelete: (p) => _confirmDelete(dp, 'ponds', p.id, p.code),
        ));
      case 'batch':
        return ('Lô cá', _BatchView(
          dp: dp,
          onCreate: () => _showBatchDialog(dp),
          onCreateSpecies: () => _showSpeciesDialog(dp),
          onViewSpecies: () => _navigateToSubModule(context, 'species', dp),
          onEdit: (b) => _showBatchDialog(dp, b),
          onDelete: (b) => _confirmDelete(dp, 'fishbatches', b.id, 'Lô #${b.id}'),
          onEditSpecies: (s) => _showSpeciesDialog(dp, s),
          onDeleteSpecies: (s) => _confirmDelete(dp, 'species', s.id, s.name),
          onHarvest: (b) => _showHarvestDialog(dp, b),
          onFeeding: () => _showFeedingLogDialog(dp),
          onMortality: () => _showMortalityLogDialog(dp),
        ));
      case 'staff':
        return ('Nhân sự', _StaffView(
          dp: dp,
          onCreate: () => _showStaffDialog(dp),
          onEdit: (e) => _showStaffDialog(dp, e),
          onDelete: (e) => _confirmDelete(dp, 'employees', e.id, e.name),
          onCreateAccount: (e) => _showCreateAccountDialog(dp, e),
          onEditPermissions: (e) => _showPermissionsDialog(dp, e),
        ));
      case 'sale':
        return ('Bán hàng', _SaleView(
          dp: dp,
          onCreate: () => _showSaleDialog(dp),
          onEdit: (s) => _showSaleDialog(dp, s),
          onDelete: (s) => _confirmDelete(dp, 'saleorders', s.id, 'Đơn #${s.id}'),
        ));
      case 'branch':
        return ('Chi nhánh', _BranchView(
          dp: dp,
          onCreate: () => _showBranchDialog(dp),
          onCreateZone: () => _showZoneDialog(dp),
          onEdit: (b) => _showBranchDialog(dp, b),
          onDelete: (b) => _confirmDelete(dp, 'branches', b.id, b.name),
          onEditZone: (z) => _showZoneDialog(dp, z),
          onDeleteZone: (z) => _confirmDelete(dp, 'zones', z.id, z.name),
          onCreatePond: (zoneId) => _showPondDialog(dp, null, zoneId),
          onEditPond: (p) => _showPondDialog(dp, p),
          onDeletePond: (p) => _confirmDelete(dp, 'ponds', p.id, p.code),
        ));
      case 'customer':
        return ('Khách hàng', CustomerView(
          dp: dp,
          onCreate: () => _showCustomerDialog(dp),
          onEdit: (c) => _showCustomerDialog(dp, c),
          onDelete: (c) => _confirmDelete(dp, 'customers', c.id, c.name),
        ));
      case 'products':
        return ('Hàng hóa', _ProductView(
          dp: dp,
          onCreate: () => _showProductDialog(dp),
          onEdit: (p) => _showProductDialog(dp, p),
          onDelete: (p) => _confirmDelete(dp, 'products', p.id, p.name),
        ));
      case 'notifications':
        return ('Thông báo', NotificationPage(
          dp: dp,
          onNavigate: (key) => _navigateFromNotification(key, dp),
        ));
      case 'species':
        return ('Loài cá', _SpeciesListView(
          dp: dp,
          onCreate: () => _showSpeciesDialog(dp),
          onEdit: (s) => _showSpeciesDialog(dp, s),
          onDelete: (s) => _confirmDelete(dp, 'species', s.id, s.name),
        ));
      case 'waterstandards':
        return ('Thông số nước tiêu chuẩn', WaterStandardsView(dp: dp));
      case 'data':
        return ('Quản lý dữ liệu', _DataManagementPage(dp: dp));
      default:
        return null;
    }
  }

  Widget _buildSkeleton(List<_NavItem> navItems) {
    final perm = navItems[_currentIndex].permission;
    switch (perm) {
      case 'dashboard':
        return const SkeletonDashboard();
      case 'warehouse':
      case 'reports':
        return const SkeletonTabPage();
      default:
        return const SkeletonListPage();
    }
  }

  Widget _buildBody(DataProvider dp, List<_NavItem> navItems) {
    // If a sub-module is active, render it inline with a back header
    if (_subModuleKey != null) {
      final sub = _buildSubModuleContent(dp);
      if (sub != null) {
        final (title, child) = sub;
        // Find parent nav label
        final parentLabel = navItems[_currentIndex].label;
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.xs),
              decoration: BoxDecoration(
                gradient: AppColors.gradientPrimary,
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () {
                      _fadeCtrl.reverse().then((_) {
                        setState(() => _subModuleKey = null);
                        _updateUrlHash(navItems);
                        _fadeCtrl.forward();
                      });
                    },
                  ),
                  // Breadcrumb: Parent > Current
                  GestureDetector(
                    onTap: () {
                      _fadeCtrl.reverse().then((_) {
                        setState(() => _subModuleKey = null);
                        _updateUrlHash(navItems);
                        _fadeCtrl.forward();
                      });
                    },
                    child: Text(parentLabel, style: AppText.body.copyWith(color: Colors.white70)),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 18),
                  ),
                  Text(title, style: AppText.title.copyWith(color: Colors.white)),
                ],
              ),
            ),
            Expanded(child: child),
          ],
        );
      }
    }

    final perm = navItems[_currentIndex].permission;
    switch (perm) {
      case 'dashboard': return DashboardView(
        dp: dp,
        onAddPond: () => _showPondDialog(dp),
        onAddBatch: () => _showBatchDialog(dp),
        onMeasureWater: () => _navigateToSubModule(context, 'branch', dp),
        onAddSale: () => _showSaleDialog(dp),
      );
      case 'farm_map': return FarmMapView(dp: dp);
      case 'tasks': return _TaskView(
        dp: dp,
        onCreate: () => _showTaskDialog(dp),
        onEdit: (t) => _showTaskDialog(dp, t),
        onDelete: (t) => _confirmDelete(dp, 'tasks', t.id, t.title),
      );
      case 'reports':
        // If it's 'Báo cáo' or 'Thu chi' — distinguish by label
        if (navItems[_currentIndex].label == 'Thu chi') return PaymentVoucherView(dp: dp);
        return ReportView(dp: dp);
      case 'operations': return AquaOperationsView(dp: dp);
      case 'warehouse': return WarehouseView(dp: dp);
      case 'settings': return _SettingsView(
        dp: dp,
        onNavigate: (key) => _navigateToSubModule(context, key, dp),
        onProfile: () => _showProfilePage(dp),
        onHelp: () => _showHelpPage(),
      );
      default: return const SizedBox.shrink();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SNACKBAR HELPER
  // ═══════════════════════════════════════════════════════════════════════════

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: isError ? 3 : 2),
    ));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DELETE CONFIRMATION
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _confirmDelete(DataProvider dp, String resource, String id, String itemName) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Xác nhận xoá'),
        content: Text('Bạn có chắc muốn xoá "$itemName"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Huỷ')),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await dp.remove(resource, id);
      _showSnack('Đã xoá "$itemName"');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GLOBAL SEARCH
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _showSearchDialog(DataProvider dp) async {
    final queryC = TextEditingController();
    await showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, ss) => AlertDialog(
          title: const Text('Tìm kiếm toàn hệ thống'),
          content: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: AppSizes.dialogMaxWidth, maxHeight: AppSizes.dialogMaxHeight),
            child: Column(
              children: [
                TextField(
                  controller: queryC,
                  decoration: InputDecoration(
                    hintText: 'Nhập từ khoá...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send_rounded),
                      onPressed: () async {
                        if (queryC.text.trim().isEmpty) return;
                        await dp.search(queryC.text.trim());
                        ss(() {});
                      },
                    ),
                  ),
                  onSubmitted: (v) async {
                    if (v.trim().isEmpty) return;
                    await dp.search(v.trim());
                    ss(() {});
                  },
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: dp.searchResults.isEmpty
                      ? const Center(child: Text('Nhập từ khoá để tìm kiếm', style: TextStyle(color: AppColors.textHint)))
                      : ListView.builder(
                          itemCount: dp.searchResults.length,
                          itemBuilder: (_, i) {
                            final r = dp.searchResults[i];
                            return ListTile(
                              leading: Icon(_searchIcon(r['type'] as String? ?? ''), color: AppColors.primary),
                              title: Text(r['title']?.toString() ?? ''),
                              subtitle: Text(r['type']?.toString() ?? '', style: const TextStyle(fontSize: 12)),
                              dense: true,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                dp.clearSearch();
                Navigator.pop(dCtx);
              },
              child: const Text('Đóng'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _searchIcon(String type) {
    switch (type) {
      case 'pond': return Icons.water_rounded;
      case 'batch': return Icons.set_meal_rounded;
      case 'employee': return Icons.person_rounded;
      case 'customer': return Icons.person_pin_rounded;
      case 'supplier': return Icons.local_shipping_rounded;
      case 'product': return Icons.category_rounded;
      case 'task': return Icons.task_alt_rounded;
      case 'saleOrder': return Icons.point_of_sale_rounded;
      case 'purchaseOrder': return Icons.shopping_cart_rounded;
      default: return Icons.search_rounded;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EXPORT DATA
  // ═══════════════════════════════════════════════════════════════════════════

  static const _exportOptions = <MapEntry<String, String>>[
    MapEntry('ponds', 'Ao nuôi'),
    MapEntry('fishbatches', 'Lô cá'),
    MapEntry('employees', 'Nhân sự'),
    MapEntry('products', 'Hàng hóa'),
    MapEntry('tasks', 'Công việc'),
    MapEntry('customers', 'Khách hàng'),
    MapEntry('suppliers', 'Nhà cung cấp'),
    MapEntry('saleorders', 'Đơn bán'),
    MapEntry('purchaseorders', 'Đơn mua'),
    MapEntry('stockreceipts', 'Phiếu nhập kho'),
    MapEntry('stockissues', 'Phiếu xuất kho'),
    MapEntry('paymentvouchers', 'Phiếu thu chi'),
    MapEntry('sensorreadings', 'Chỉ số môi trường'),
    MapEntry('species', 'Loài cá'),
  ];

  Future<void> _showExportDialog(DataProvider dp) async {
    await showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Row(children: [
          ExcelIcon(size: 24),
          SizedBox(width: 10),
          Text('Xuất dữ liệu'),
        ]),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quick export all as Excel
              Card(
                color: AppColors.primary.withAlpha(15),
                child: ListTile(
                  leading: const ExcelIcon(size: 28),
                  title: const Text('Xuất tất cả (Excel)', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Tất cả dữ liệu vào 1 file .xlsx'),
                  onTap: () {
                    Navigator.pop(dCtx);
                    _doExportAllExcel(dp);
                  },
                ),
              ),
              const SizedBox(height: 12),
              const Text('Xuất từng danh mục:', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _exportOptions.length,
                  itemBuilder: (_, i) {
                    final opt = _exportOptions[i];
                    return ListTile(
                      dense: true,
                      leading: const ExcelIcon(size: 20),
                      title: Text(opt.value),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton.icon(
                            icon: const ExcelIcon(size: 16),
                            label: const Text('Excel'),
                            onPressed: () {
                              Navigator.pop(dCtx);
                              _doExportExcel(dp, opt.key, opt.value);
                            },
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.text_snippet_outlined, size: 16),
                            label: const Text('CSV'),
                            onPressed: () {
                              Navigator.pop(dCtx);
                              _doExportCsv(dp, opt.key, opt.value);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Đóng')),
        ],
      ),
    );
  }

  void _doExportAllExcel(DataProvider dp) {
    final fmt = DateFormat('dd/MM/yyyy');
    final sheets = <ExcelSheetData>[
      ExcelSheetData(name: 'Ao nuôi', headers: ['Mã ao', 'Khu', 'Diện tích(m²)', 'Thể tích(m³)', 'Loại', 'pH', 'DO', 'Nhiệt độ', 'NH3', 'Trạng thái'],
          rows: dp.ponds.map((p) {
            final z = dp.zones.where((z) => z.id == p.zoneId).firstOrNull;
            return [p.code, z?.name ?? '', p.area, p.volume, p.typeLabel, p.currentPh ?? '', p.currentDo ?? '', p.currentTemp ?? '', p.currentNh3 ?? '', p.statusLabel];
          }).toList()),
      ExcelSheetData(name: 'Lô cá', headers: ['Tên', 'Ao', 'Loài', 'Ngày thả', 'SL ban đầu', 'SL hiện tại', 'Trọng lượng(g)', 'Hao hụt', 'Thức ăn(kg)', 'Trạng thái'],
          rows: dp.fishBatches.map((b) {
            final pond = dp.ponds.where((p) => p.id == b.pondId).firstOrNull;
            final sp = dp.species.where((s) => s.id == b.speciesId).firstOrNull;
            return [b.name, pond?.code ?? '', sp?.name ?? '', fmt.format(b.stockingDate), b.initialQuantity, b.currentQuantity, b.currentWeight, b.mortalityQuantity, b.feedConsumed, b.statusLabel];
          }).toList()),
      ExcelSheetData(name: 'Nhân sự', headers: ['Họ tên', 'Email', 'SĐT', 'Vai trò', 'Ca làm'],
          rows: dp.employees.map((e) => [e.name, e.email, e.phone, e.role, e.shift]).toList()),
      ExcelSheetData(name: 'Hàng hóa', headers: ['Mã SKU', 'Tên', 'Danh mục', 'Đơn vị', 'Giá bán', 'Giá vốn', 'Tồn kho', 'Giá trị kho'],
          rows: dp.products.map((p) => [p.sku, p.name, p.categoryLabel, p.unit, p.price, p.costPrice, p.stock, p.stockValue]).toList()),
      ExcelSheetData(name: 'Công việc', headers: ['Tiêu đề', 'Loại', 'Giao cho', 'Hạn', 'Trạng thái', 'Ghi chú'],
          rows: dp.tasks.map((t) {
            final emp = dp.employees.where((e) => e.id == t.assignedTo).firstOrNull;
            return [t.title, t.typeLabel, emp?.name ?? '', fmt.format(t.dueDate), t.statusLabel, t.note];
          }).toList()),
      ExcelSheetData(name: 'Khách hàng', headers: ['Tên', 'Loại', 'Công ty', 'SĐT', 'Công nợ'],
          rows: dp.customers.map((c) => [c.name, c.typeLabel, c.company, c.phone, c.debt]).toList()),
      ExcelSheetData(name: 'Đơn bán', headers: ['Mã', 'Khách hàng', 'Ngày', 'Tổng tiền', 'Trạng thái'],
          rows: dp.saleOrders.map((o) {
            final cust = dp.customers.where((c) => c.id == o.customerId).firstOrNull;
            return [o.id.substring(0, 8), cust?.name ?? '', fmt.format(o.date), o.totalAmount, o.statusLabel];
          }).toList()),
      ExcelSheetData(name: 'Phiếu thu chi', headers: ['Mã', 'Loại', 'Số tiền', 'Đối tác', 'Ngày', 'Trạng thái'],
          rows: dp.paymentVouchers.map((v) => [v.code, v.typeLabel, v.amount, v.contactName, fmt.format(v.date), v.statusLabel]).toList()),
    ];
    ExportService.exportMultiSheetAndNotify(context: context, sheets: sheets, filePrefix: 'aqua_data', label: 'Toàn bộ dữ liệu');
  }

  void _doExportExcel(DataProvider dp, String resource, String label) {
    final fmt = DateFormat('dd/MM/yyyy');
    List<String> headers;
    List<List<dynamic>> rows;
    switch (resource) {
      case 'ponds':
        headers = ['Mã ao', 'Khu', 'Diện tích(m²)', 'Thể tích(m³)', 'Loại', 'pH', 'DO', 'Nhiệt độ', 'NH3', 'Trạng thái'];
        rows = dp.ponds.map((p) {
          final z = dp.zones.where((z) => z.id == p.zoneId).firstOrNull;
          return [p.code, z?.name ?? '', p.area, p.volume, p.typeLabel, p.currentPh ?? '', p.currentDo ?? '', p.currentTemp ?? '', p.currentNh3 ?? '', p.statusLabel];
        }).toList();
      case 'fishbatches':
        headers = ['Tên', 'Ao', 'Loài', 'Ngày thả', 'SL ban đầu', 'SL hiện tại', 'Trọng lượng(g)', 'Hao hụt', 'Thức ăn(kg)', 'Trạng thái'];
        rows = dp.fishBatches.map((b) {
          final pond = dp.ponds.where((p) => p.id == b.pondId).firstOrNull;
          final sp = dp.species.where((s) => s.id == b.speciesId).firstOrNull;
          return [b.name, pond?.code ?? '', sp?.name ?? '', fmt.format(b.stockingDate), b.initialQuantity, b.currentQuantity, b.currentWeight, b.mortalityQuantity, b.feedConsumed, b.statusLabel];
        }).toList();
      case 'employees':
        headers = ['Họ tên', 'Email', 'SĐT', 'Vai trò', 'Ca làm'];
        rows = dp.employees.map((e) => [e.name, e.email, e.phone, e.role, e.shift]).toList();
      case 'products':
        headers = ['Mã SKU', 'Tên', 'Danh mục', 'Thương hiệu', 'Đơn vị', 'Giá bán', 'Giá vốn', 'Tồn kho', 'Tồn tối thiểu', 'Giá trị kho'];
        rows = dp.products.map((p) => [p.sku, p.name, p.categoryLabel, p.brand, p.unit, p.price, p.costPrice, p.stock, p.minStock, p.stockValue]).toList();
      case 'tasks':
        headers = ['Tiêu đề', 'Loại', 'Giao cho', 'Hạn', 'Trạng thái', 'Ghi chú'];
        rows = dp.tasks.map((t) {
          final emp = dp.employees.where((e) => e.id == t.assignedTo).firstOrNull;
          return [t.title, t.typeLabel, emp?.name ?? '', fmt.format(t.dueDate), t.statusLabel, t.note];
        }).toList();
      case 'customers':
        headers = ['Tên', 'Loại', 'Công ty', 'SĐT', 'Email', 'Địa chỉ', 'Công nợ'];
        rows = dp.customers.map((c) => [c.name, c.typeLabel, c.company, c.phone, c.email, c.address, c.debt]).toList();
      case 'suppliers':
        headers = ['Tên', 'SĐT', 'Email', 'Địa chỉ', 'Mã thuế'];
        rows = dp.suppliers.map((s) => [s.name, s.phone, s.email, s.address, s.taxCode]).toList();
      case 'saleorders':
        headers = ['Mã', 'Khách hàng', 'Ngày', 'Tổng tiền', 'Trạng thái'];
        rows = dp.saleOrders.map((o) {
          final cust = dp.customers.where((c) => c.id == o.customerId).firstOrNull;
          return [o.id.substring(0, 8), cust?.name ?? '', fmt.format(o.date), o.totalAmount, o.statusLabel];
        }).toList();
      case 'purchaseorders':
        headers = ['Mã', 'NCC', 'Ngày', 'Tổng tiền', 'Trạng thái', 'Ghi chú'];
        rows = dp.purchaseOrders.map((po) {
          final supp = dp.suppliers.where((s) => s.id == po.supplierId).firstOrNull;
          return [po.code.isNotEmpty ? po.code : 'PO#${po.id.substring(0, 6)}', supp?.name ?? po.supplier, fmt.format(po.date), po.total, po.statusLabel, po.note];
        }).toList();
      case 'stockreceipts':
        headers = ['Mã', 'Ngày', 'Loại', 'Tổng tiền', 'Trạng thái'];
        rows = dp.stockReceipts.map((r) => [r.code.isNotEmpty ? r.code : 'NK#${r.id.substring(0, 6)}', fmt.format(r.date), r.typeLabel, r.totalAmount, r.statusLabel]).toList();
      case 'stockissues':
        headers = ['Mã', 'Ngày', 'Loại', 'Tổng tiền', 'Trạng thái'];
        rows = dp.stockIssues.map((i) => [i.code.isNotEmpty ? i.code : 'XK#${i.id.substring(0, 6)}', fmt.format(i.date), i.typeLabel, i.totalAmount, i.statusLabel]).toList();
      case 'paymentvouchers':
        headers = ['Mã', 'Loại', 'Danh mục', 'Số tiền', 'Đối tác', 'Ngày', 'Trạng thái'];
        rows = dp.paymentVouchers.map((v) => [v.code, v.typeLabel, v.categoryLabel, v.amount, v.contactName, fmt.format(v.date), v.statusLabel]).toList();
      case 'species':
        headers = ['Tên', 'Mô tả', 'Nhiệt độ', 'pH', 'DO', 'NH3 max', 'Tỷ lệ thức ăn', 'Trọng lượng thu hoạch(g)', 'Ngày nuôi', 'Mật độ/m²'];
        rows = dp.species.map((s) => [s.name, s.description, '${s.minTemp}-${s.maxTemp}°C', s.requiredPh, s.requiredDo, s.maxNh3, s.feedRatio, s.harvestableWeight, s.growthDays, s.densityPerM2]).toList();
      case 'sensorreadings':
        headers = ['Ao', 'Thời gian', 'Nhiệt độ', 'pH', 'DO', 'NH3', 'Kiềm', 'Người đo'];
        rows = dp.sensorReadings.map((r) => [r.pondCode.isNotEmpty ? r.pondCode : r.pondId, fmt.format(r.timestamp), r.temperature ?? '', r.pH ?? '', r.oxygen ?? '', r.nh3 ?? '', r.alkalinity ?? '', r.measuredBy]).toList();
      default:
        headers = ['Dữ liệu'];
        rows = [];
    }
    ExportService.exportExcelAndNotify(context: context, sheetName: label, headers: headers, rows: rows, filePrefix: resource);
  }

  Future<void> _doExportCsv(DataProvider dp, String resource, String label) async {
    final csv = await dp.exportCsv(resource);
    if (csv != null && csv.isNotEmpty) {
      final blob = html.Blob([csv], 'text/csv;charset=utf-8');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', '${resource}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv')
        ..click();
      html.Url.revokeObjectUrl(url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xuất $label (CSV)'), backgroundColor: AppColors.success),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không có dữ liệu để xuất'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PROFILE PAGE
  // ═══════════════════════════════════════════════════════════════════════════

  void _showProfilePage(DataProvider dp) {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _ProfilePage(dp: dp, user: user),
    ));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELP PAGE
  // ═══════════════════════════════════════════════════════════════════════════

  void _showHelpPage() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => const _HelpPage(),
    ));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HARVEST DIALOG
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _showHarvestDialog(DataProvider dp, [FishBatch? batch]) async {
    String? batchId = batch?.id;
    final qtyC = TextEditingController();
    final weightC = TextEditingController();
    final priceC = TextEditingController();
    final noteC = TextEditingController();
    String? buyerCustomerId;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, ss) => AlertDialog(
          title: const Text('Thu hoạch'),
          content: SizedBox(
            width: AppSizes.dialogMaxWidth,
            child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (batch == null)
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Lô cá', prefixIcon: Icon(Icons.set_meal)),
                  items: dp.fishBatches.where((b) => b.status == 'active').map((b) {
                    final sName = dp.speciesById(b.speciesId)?.name ?? b.speciesId;
                    final label = b.name.isNotEmpty ? '${b.name} ($sName)' : sName;
                    final ponds = b.pondIds.map((id) => dp.pondById(id)?.code ?? '?').join(', ');
                    return DropdownMenuItem(value: b.id, child: Text('$label - Ao $ponds', overflow: TextOverflow.ellipsis));
                  }).toList(),
                  onChanged: (v) => ss(() => batchId = v),
                ),
              if (batch == null) const SizedBox(height: 12),
              TextField(controller: qtyC, decoration: const InputDecoration(labelText: 'Số lượng (con)', prefixIcon: Icon(Icons.numbers)), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
              const SizedBox(height: 12),
              TextField(controller: weightC, decoration: const InputDecoration(labelText: 'Tổng trọng lượng (kg)', prefixIcon: Icon(Icons.monitor_weight)), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]),
              const SizedBox(height: 12),
              TextField(controller: priceC, decoration: const InputDecoration(labelText: 'Đơn giá (VNĐ/kg)', prefixIcon: Icon(Icons.attach_money)), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Khách mua (tuỳ chọn)', prefixIcon: Icon(Icons.person_pin)),
                items: [
                  const DropdownMenuItem(value: null, child: Text('-- Không chọn --')),
                  ...dp.customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                ],
                onChanged: (v) => ss(() => buyerCustomerId = v),
              ),
              const SizedBox(height: 12),
              TextField(controller: noteC, decoration: const InputDecoration(labelText: 'Ghi chú'), maxLines: 2),
            ]),
          ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Huỷ')),
            FilledButton(onPressed: () {
              if (batchId == null) {
                ScaffoldMessenger.of(dCtx).showSnackBar(const SnackBar(content: Text('Vui lòng chọn lô cá'), backgroundColor: Colors.red));
                return;
              }
              final qty = int.tryParse(qtyC.text) ?? 0;
              if (qty <= 0) {
                ScaffoldMessenger.of(dCtx).showSnackBar(const SnackBar(content: Text('Số lượng phải > 0'), backgroundColor: Colors.red));
                return;
              }
              Navigator.pop(dCtx, true);
            }, child: const Text('Thu hoạch')),
          ],
        ),
      ),
    );
    if (ok == true && batchId != null) {
      await dp.createHarvest({
        'fishBatchId': batchId,
        'harvestQuantity': int.tryParse(qtyC.text) ?? 0,
        'harvestWeight': double.tryParse(weightC.text) ?? 0,
        'pricePerKg': double.tryParse(priceC.text) ?? 0,
        if (buyerCustomerId != null) 'buyerName': dp.customerById(buyerCustomerId!)?.name ?? '',
        'note': noteC.text,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thu hoạch thành công!'), backgroundColor: AppColors.success),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FEEDING LOG DIALOG
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _showFeedingLogDialog(DataProvider dp) async {
    String? batchId;
    String? pondId;
    String? issuedTo;
    final noteC = TextEditingController();
    final activeBatches = dp.fishBatches.where((b) => b.status == 'active').toList();
    double feedRatio = 3.0; // default, will update when batch selected

    // Pre-populate line items
    final feedProducts = dp.products.where((p) =>
        p.category.toLowerCase().contains('thức ăn') || p.category.toLowerCase() == 'feed').toList();
    final lineItems = <Map<String, dynamic>>[];

    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, ss) {
          final selBatch = activeBatches.where((b) => b.id == batchId).firstOrNull;
          final batchPonds = selBatch != null
              ? selBatch.pondIds.map((id) => dp.pondById(id)).whereType<Pond>().toList()
              : <Pond>[];

          // Calculate suggested feed amount PER POND
          double suggestedKg = 0;
          int qtyInPond = 0;
          double pondBiomass = 0;
          if (selBatch != null && pondId != null) {
            qtyInPond = selBatch.quantityInPond(pondId!);
            final weight = selBatch.currentWeight > 0 ? selBatch.currentWeight : selBatch.initialWeight;
            pondBiomass = qtyInPond * weight / 1000;
            suggestedKg = pondBiomass * feedRatio / 100;
          }

          double total = 0;
          bool hasOverStock = false;
          bool hasZeroQty = false;
          for (final item in lineItems) {
            final qty = ((item['qty'] as num?) ?? 0).toDouble();
            final inputQty = ((item['inputQty'] as num?) ?? qty).toDouble();
            final price = ((item['unitPrice'] as num?) ?? 0).toDouble();
            final prod = dp.productById(item['productId'] as String? ?? '');
            final hasConv = prod != null && prod.hasConversion;
            final rawQty = hasConv ? inputQty / prod!.conversionRatio : qty;
            total += rawQty * price; // cost based on raw qty × raw price
            if (prod != null && rawQty > prod.stock) hasOverStock = true;
            if (hasConv ? inputQty <= 0 : qty <= 0) hasZeroQty = true;
          }
          final canSubmit = batchId != null && pondId != null && lineItems.isNotEmpty && !hasZeroQty;
          final usedProductIds = lineItems.map((e) => e['productId'] as String?).whereType<String>().toSet();

          return AlertDialog(
            title: Row(children: [
              const Icon(Icons.restaurant_rounded, color: Colors.teal),
              const SizedBox(width: 8),
              const Text('Tạo phiếu cho ăn'),
            ]),
            content: SizedBox(
              width: 540,
              child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Lô cá', prefixIcon: Icon(Icons.set_meal)),
                  items: activeBatches.map((b) {
                    final sName = dp.speciesById(b.speciesId)?.name ?? b.speciesId;
                    final label = b.name.isNotEmpty ? '${b.name} ($sName)' : sName;
                    final ponds = b.pondIds.map((id) => dp.pondById(id)?.code ?? '?').join(', ');
                    return DropdownMenuItem(value: b.id, child: Text('$label - Ao $ponds', overflow: TextOverflow.ellipsis));
                  }).toList(),
                  onChanged: (v) => ss(() {
                    batchId = v;
                    final b = activeBatches.where((b) => b.id == v).firstOrNull;
                    pondId = b != null && b.pondIds.isNotEmpty ? b.pondIds.first : null;
                    // Set default feed ratio from species
                    if (b != null) {
                      final sp = dp.speciesById(b.speciesId);
                      feedRatio = sp?.feedRatio ?? 3.0;
                    }
                    // Auto-add first feed product if no line items
                    if (lineItems.isEmpty && feedProducts.isNotEmpty) {
                      lineItems.add({
                        'productId': feedProducts.first.id,
                        'productName': feedProducts.first.name,
                        'qty': 0,
                        'unitPrice': feedProducts.first.costPrice > 0 ? feedProducts.first.costPrice : feedProducts.first.price,
                        'unit': feedProducts.first.unit,
                      });
                    }
                  }),
                ),
                if (batchPonds.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey('feed_pond_$batchId'),
                    initialValue: pondId,
                    decoration: const InputDecoration(labelText: 'Ao nuôi', prefixIcon: Icon(Icons.water)),
                    items: batchPonds.map((p) {
                      final qty = selBatch?.quantityInPond(p.id) ?? 0;
                      return DropdownMenuItem(value: p.id, child: Text('${p.code} ($qty con)'));
                    }).toList(),
                    onChanged: (v) => ss(() => pondId = v),
                  ),
                ],
                if (selBatch != null && pondId != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.withAlpha(15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.teal.withAlpha(40)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.set_meal, size: 14, color: Colors.teal),
                        const SizedBox(width: 6),
                        Text('$qtyInPond con trong ao • Sinh khối: ${pondBiomass.toStringAsFixed(1)} kg',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.tune, size: 14, color: Colors.teal),
                        const SizedBox(width: 6),
                        Text('Hệ số cho ăn: ${feedRatio.toStringAsFixed(1)}% thân',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ]),
                      Slider(
                        value: feedRatio.clamp(0.5, 10.0),
                        min: 0.5, max: 10.0, divisions: 19,
                        label: '${feedRatio.toStringAsFixed(1)}%',
                        activeColor: Colors.teal,
                        onChanged: (v) => ss(() {
                          feedRatio = v;
                          // Auto-update first line item qty
                          if (lineItems.isNotEmpty) {
                            final wt = selBatch!.currentWeight > 0 ? selBatch.currentWeight : selBatch.initialWeight;
                            final sugKg = selBatch.quantityInPond(pondId!) * wt / 1000 * v / 100;
                            final firstProd = dp.productById(lineItems[0]['productId'] as String? ?? '');
                            if (firstProd != null && firstProd.hasConversion) {
                              // sugKg is in processed unit (kg), store as inputQty
                              lineItems[0]['inputQty'] = double.parse(sugKg.toStringAsFixed(1));
                              lineItems[0]['qty'] = sugKg / firstProd.conversionRatio;
                            } else {
                              lineItems[0]['qty'] = double.parse(sugKg.toStringAsFixed(1));
                            }
                          }
                        }),
                      ),
                      Row(children: [
                        const Icon(Icons.lightbulb_outline, size: 14, color: Colors.amber),
                        const SizedBox(width: 6),
                        Text('Đề xuất: ${suggestedKg.toStringAsFixed(1)} kg/ngày',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.amber)),
                      ]),
                      // Show measurement data source
                      if (selBatch != null) ...[
                        const SizedBox(height: 4),
                        Builder(builder: (_) {
                          final ms = dp.sizeMeasurements
                              .where((m) => m.fishBatchId == selBatch.id)
                              .toList()
                            ..sort((a, b) => b.date.compareTo(a.date));
                          if (ms.isEmpty) {
                            return Row(children: [
                              Icon(Icons.info_outline, size: 13, color: Colors.orange.shade300),
                              const SizedBox(width: 6),
                              Expanded(child: Text('Dữ liệu trọng lượng từ lúc thả (${selBatch.initialWeight.toStringAsFixed(0)}g). Đo kích thước để cập nhật.',
                                style: TextStyle(fontSize: 11, color: Colors.orange.shade400, fontStyle: FontStyle.italic))),
                            ]);
                          }
                          final last = ms.first;
                          final fmt = DateFormat('dd/MM/yyyy HH:mm');
                          return Row(children: [
                            const Icon(Icons.straighten, size: 13, color: AppColors.success),
                            const SizedBox(width: 6),
                            Expanded(child: Text('Đo lần cuối: ${fmt.format(last.date)} — ${last.avgWeight.toStringAsFixed(0)}g/con',
                              style: const TextStyle(fontSize: 11, color: AppColors.success, fontStyle: FontStyle.italic))),
                          ]);
                        }),
                      ],
                    ]),
                  ),
                ],
                const SizedBox(height: 12),
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
                // Line items
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
                  final inputQty = ((item['inputQty'] as num?) ?? qty).toDouble(); // user-entered (processed units for conversion products)
                  final stock = prod?.stock ?? 0;
                  final hasConv = prod != null && prod.hasConversion;
                  // For conversion products, raw consumption = inputQty / ratio
                  final rawQty = hasConv ? inputQty / prod!.conversionRatio : qty;
                  final overStock = prod != null && rawQty > stock;
                  final zeroQty = hasConv ? inputQty <= 0 : qty <= 0;
                  final currentPid = item['productId'] as String?;
                  final availableProducts = dp.products.where((p) => p.id == currentPid || !usedProductIds.contains(p.id)).toList();

                  return Container(
                    key: ValueKey('feed_line_$idx'),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: overStock ? Colors.red.withAlpha(10) : Colors.grey.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                      border: overStock ? Border.all(color: Colors.red.withAlpha(80)) : null,
                    ),
                    child: Column(children: [
                      Row(children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('feed_prod_${idx}_$currentPid'),
                            initialValue: currentPid,
                            decoration: const InputDecoration(labelText: 'Sản phẩm', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
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
                        IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => ss(() => lineItems.removeAt(idx))),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: TextFormField(
                          key: ValueKey('feed_qty_${idx}_$currentPid'),
                          initialValue: hasConv
                              ? (inputQty > 0 ? inputQty.toStringAsFixed(1) : '')
                              : (qty > 0 ? qty.toStringAsFixed(1) : ''),
                          decoration: InputDecoration(
                            labelText: hasConv
                                ? 'SL cho ăn (${prod!.processedUnit.isNotEmpty ? prod.processedUnit : prod.unit})'
                                : 'SL xuất (${item['unit'] ?? 'kg'})',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            helperText: prod != null
                                ? hasConv
                                    ? 'Tồn: ${_smartQty(stock)} ${prod.unit} (≈ ${_smartQty(prod.processedStock)} ${prod.processedUnit.isNotEmpty ? prod.processedUnit : prod.unit})'
                                    : 'Tồn: ${_smartQty(stock)}'
                                : null,
                            helperStyle: TextStyle(fontSize: 11, color: overStock ? Colors.red : null),
                            errorText: overStock ? 'Vượt tồn kho!' : (zeroQty && prod != null ? 'Nhập SL > 0' : null),
                            errorStyle: const TextStyle(fontSize: 11),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (v) => ss(() {
                            final val = double.tryParse(v) ?? 0;
                            if (hasConv) {
                              item['inputQty'] = val;
                              item['qty'] = val / prod!.conversionRatio; // raw qty for stock deduction
                            } else {
                              item['qty'] = val;
                            }
                          }),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: TextFormField(
                          key: ValueKey('feed_price_${idx}_$currentPid'),
                          initialValue: ((item['unitPrice'] as num?) ?? 0) > 0 ? (item['unitPrice'] as num).toString() : '',
                          decoration: const InputDecoration(labelText: 'Đơn giá (vốn)', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                          keyboardType: TextInputType.number,
                          onChanged: (v) => ss(() => item['unitPrice'] = double.tryParse(v) ?? 0),
                        )),
                      ]),
                      // Show conversion info (processed → raw consumption)
                      if (hasConv && inputQty > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(children: [
                            Icon(Icons.sync_alt, size: 14, color: Colors.indigo.shade400),
                            const SizedBox(width: 6),
                            Expanded(child: Text(
                              'Cho ăn ${_smartQty(inputQty)} ${prod!.processedUnit.isNotEmpty ? prod.processedUnit : prod.unit} → Tiêu hao ${rawQty.toStringAsFixed(2)} ${prod.unit} nguyên liệu',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.indigo.shade600),
                            )),
                          ]),
                        ),
                    ]),
                  );
                }),
                if (hasOverStock)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: Row(children: [
                      const Icon(Icons.warning_rounded, size: 16, color: Colors.amber),
                      const SizedBox(width: 6),
                      const Expanded(child: Text('Có sản phẩm xuất vượt tồn kho', style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w600))),
                    ]),
                  ),
                const Divider(),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  const Text('Tổng giá trị: ', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text('${_currencyFmt.format(total.round())}đ', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.deepOrange)),
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
    if (ok == true && batchId != null && pondId != null && lineItems.isNotEmpty) {
      final selBatch = activeBatches.where((b) => b.id == batchId).firstOrNull;
      final selPond = dp.pondById(pondId!);

      // Determine branch from pond's zone
      String bId = '';
      if (selPond?.zoneId != null) {
        final zone = dp.zones.where((z) => z.id == selPond!.zoneId).firstOrNull;
        bId = zone?.branchId ?? '';
      }

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
      final cleanItems = <Map<String, dynamic>>[];
      for (final item in lineItems) {
        total += ((item['qty'] as num?) ?? 0) * ((item['unitPrice'] as num?) ?? 0);
        // Remove inputQty (UI-only field) before sending to backend
        final clean = Map<String, dynamic>.from(item)..remove('inputQty');
        cleanItems.add(clean);
      }

      await dp.create('stockissues', {
        'code': issueCode,
        'date': DateTime.now().toIso8601String(),
        'type': 'feeding',
        'pondId': pondId,
        'fishBatchId': batchId,
        'branchId': bId,
        'items': cleanItems,
        'totalAmount': total,
        'status': 'draft',
        'note': 'Cho ăn ao ${selPond?.code ?? ''} – Lô ${selBatch?.name ?? batchId}${noteC.text.isNotEmpty ? ' • ${noteC.text}' : ''}',
        'createdBy': '',
        'issuedTo': issuedTo ?? '',
      });
      _showSnack('Đã tạo phiếu xuất kho cho ăn $issueCode. Chờ duyệt để xuất kho.');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MORTALITY LOG DIALOG
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _showMortalityLogDialog(DataProvider dp) async {
    String? batchId;
    String? pondId;
    final qtyC = TextEditingController();
    final causeC = TextEditingController();
    final noteC = TextEditingController();
    final activeBatches = dp.fishBatches.where((b) => b.status == 'active').toList();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, ss) {
          final selBatch = activeBatches.where((b) => b.id == batchId).firstOrNull;
          final batchPonds = selBatch != null
              ? selBatch.pondIds.map((id) => dp.pondById(id)).whereType<Pond>().toList()
              : <Pond>[];
          final maxQty = selBatch != null && pondId != null ? selBatch.quantityInPond(pondId!) : selBatch?.currentQuantity ?? 0;
          return AlertDialog(
            title: const Text('Ghi nhận hao hụt / bệnh'),
            content: SizedBox(
              width: AppSizes.dialogMaxWidth,
              child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Lô cá', prefixIcon: Icon(Icons.set_meal)),
                  items: activeBatches.map((b) {
                    final sName = dp.speciesById(b.speciesId)?.name ?? b.speciesId;
                    final label = b.name.isNotEmpty ? '${b.name} ($sName)' : sName;
                    final ponds = b.pondIds.map((id) => dp.pondById(id)?.code ?? '?').join(', ');
                    return DropdownMenuItem(value: b.id, child: Text('$label - Ao $ponds', overflow: TextOverflow.ellipsis));
                  }).toList(),
                  onChanged: (v) => ss(() {
                    batchId = v;
                    final b = activeBatches.where((b) => b.id == v).firstOrNull;
                    pondId = b != null && b.pondIds.isNotEmpty ? b.pondIds.first : null;
                  }),
                ),
                if (batchPonds.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey('mort_pond_$batchId'),
                    initialValue: pondId,
                    decoration: const InputDecoration(labelText: 'Ao nuôi', prefixIcon: Icon(Icons.water)),
                    items: batchPonds.map((p) {
                      final qty = selBatch?.quantityInPond(p.id) ?? 0;
                      return DropdownMenuItem(value: p.id, child: Text('${p.code} ($qty con)'));
                    }).toList(),
                    onChanged: (v) => ss(() => pondId = v),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: qtyC,
                  decoration: InputDecoration(
                    labelText: 'Số lượng chết',
                    prefixIcon: const Icon(Icons.numbers),
                    helperText: maxQty > 0 ? 'Tối đa: $maxQty con trong ao' : null,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 12),
                TextField(controller: causeC, decoration: const InputDecoration(labelText: 'Nguyên nhân', prefixIcon: Icon(Icons.bug_report))),
                const SizedBox(height: 12),
                TextField(controller: noteC, decoration: const InputDecoration(labelText: 'Ghi chú'), maxLines: 2),
              ]),
            ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Huỷ')),
              FilledButton(
                onPressed: () {
                  if (batchId == null) {
                    ScaffoldMessenger.of(dCtx).showSnackBar(const SnackBar(content: Text('Vui lòng chọn lô cá'), backgroundColor: Colors.red));
                    return;
                  }
                  final qty = int.tryParse(qtyC.text) ?? 0;
                  if (qty <= 0) {
                    ScaffoldMessenger.of(dCtx).showSnackBar(const SnackBar(content: Text('Số lượng phải > 0'), backgroundColor: Colors.red));
                    return;
                  }
                  Navigator.pop(dCtx, true);
                },
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                child: const Text('Ghi nhận'),
              ),
            ],
          );
        },
      ),
    );
    if (ok == true && batchId != null && qtyC.text.isNotEmpty) {
      final mortQty = int.tryParse(qtyC.text) ?? 0;
      await dp.createMortalityLog({
        'fishBatchId': batchId,
        'pondId': pondId ?? '',
        'quantity': mortQty,
        'cause': causeC.text,
        'note': noteC.text,
      });
      // Cập nhật pondAllocations: giảm số cá trong ao bị hao hụt
      if (pondId != null) {
        final batch = dp.fishBatches.where((b) => b.id == batchId).firstOrNull;
        if (batch != null && batch.pondAllocations.isNotEmpty) {
          final newAllocs = List<Map<String, dynamic>>.from(batch.pondAllocations);
          final idx = newAllocs.indexWhere((a) => a['pondId'] == pondId);
          if (idx >= 0) {
            final remaining = ((newAllocs[idx]['quantity'] as num?)?.toInt() ?? 0) - mortQty;
            if (remaining <= 0) {
              newAllocs.removeAt(idx);
            } else {
              newAllocs[idx] = {'pondId': pondId, 'quantity': remaining};
            }
            await dp.update('fishbatches', batch.id, {
              ...batch.toJson(),
              'pondAllocations': newAllocs,
            });
          }
        }
      }
      _showSnack('Đã ghi nhận hao hụt');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ADD / EDIT DIALOGS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _showBranchDialog(DataProvider dp, [Branch? existing]) async {
    final isEdit = existing != null;
    final nameC = TextEditingController(text: existing?.name ?? '');
    final addrC = TextEditingController(text: existing?.address ?? '');
    final contactC = TextEditingController(text: existing?.contact ?? '');
    final mgrC = TextEditingController(text: existing?.manager ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text(isEdit ? 'Sửa chi nhánh' : 'Thêm chi nhánh'),
        content: SizedBox(
          width: AppSizes.dialogMaxWidth,
          child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Tên chi nhánh')),
            const SizedBox(height: 12),
            TextField(controller: addrC, decoration: const InputDecoration(labelText: 'Địa chỉ')),
            const SizedBox(height: 12),
            TextField(controller: contactC, decoration: const InputDecoration(labelText: 'Liên hệ')),
            const SizedBox(height: 12),
            TextField(controller: mgrC, decoration: const InputDecoration(labelText: 'Quản lý')),
          ]),
        ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(dCtx, true), child: Text(isEdit ? 'Cập nhật' : 'Thêm')),
        ],
      ),
    );
    if (ok == true && nameC.text.isNotEmpty) {
      final data = {'name': nameC.text, 'address': addrC.text, 'contact': contactC.text, 'manager': mgrC.text};
      if (isEdit) {
        await dp.update('branches', existing.id, data);
      } else {
        await dp.create('branches', data);
      }
      _showSnack(isEdit ? 'Đã cập nhật chi nhánh' : 'Đã thêm chi nhánh');
    }
  }

  Future<void> _showPondDialog(DataProvider dp, [Pond? existing, String? presetZoneId]) async {
    final isEdit = existing != null;
    final codeC = TextEditingController(text: existing?.code ?? '');
    final areaC = TextEditingController(text: existing != null ? existing.area.toString() : '');
    final volC = TextEditingController(text: existing != null ? existing.volume.toString() : '');
    final depthC = TextEditingController(text: existing != null && existing.depth > 0 ? existing.depth.toString() : '');
    String type = existing?.type ?? 'earth';
    String? zoneId = existing?.zoneId ?? presetZoneId ?? (dp.zones.isNotEmpty ? dp.zones.first.id : null);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, ss) => AlertDialog(
          title: Text(isEdit ? 'Sửa ao nuôi' : 'Thêm ao nuôi'),
          content: SizedBox(
            width: AppSizes.dialogMaxWidth,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: codeC, decoration: const InputDecoration(labelText: 'Mã ao', prefixIcon: Icon(Icons.label))),
                const SizedBox(height: 16),
                if (dp.zones.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: zoneId,
                    decoration: const InputDecoration(labelText: 'Phân khu', prefixIcon: Icon(Icons.grid_view)),
                    items: dp.zones.map((z) => DropdownMenuItem(value: z.id, child: Text(z.name))).toList(),
                    onChanged: (v) => ss(() => zoneId = v),
                  ),
                const SizedBox(height: 16),
                _PondTypeAutocomplete(
                  initialValue: type,
                  onChanged: (v) => ss(() => type = v),
                ),
                const SizedBox(height: 20),
                const Align(alignment: Alignment.centerLeft, child: Text('Kích thước', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: areaC, decoration: const InputDecoration(labelText: 'Diện tích (m²)'), keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: volC, decoration: const InputDecoration(labelText: 'Thể tích (m³)'), keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: depthC, decoration: const InputDecoration(labelText: 'Độ sâu (m)'), keyboardType: TextInputType.number)),
                ]),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Huỷ')),
            FilledButton(onPressed: () => Navigator.pop(dCtx, true), child: Text(isEdit ? 'Cập nhật' : 'Thêm')),
          ],
        ),
      ),
    );
    if (ok == true && codeC.text.isNotEmpty) {
      final area = double.tryParse(areaC.text) ?? 0;
      final volume = double.tryParse(volC.text) ?? 0;
      final depth = double.tryParse(depthC.text) ?? 0;
      if (area < 0 || volume < 0 || depth < 0) {
        _showSnack('Diện tích, thể tích, độ sâu không được âm');
        return;
      }
      final data = {
        'code': codeC.text,
        'zoneId': zoneId,
        'area': area,
        'volume': volume,
        'depth': depth,
        'type': type,
        'status': existing?.status ?? 'inactive',
        'currentTemp': existing?.currentTemp,
        'currentPh': existing?.currentPh,
        'currentDo': existing?.currentDo,
        'currentNh3': existing?.currentNh3,
        'currentAlkalinity': existing?.currentAlkalinity,
        'measuredBy': existing?.measuredBy ?? '',
      };
      if (isEdit) {
        await dp.update('ponds', existing.id, data);
      } else {
        await dp.create('ponds', data);
      }
      _showSnack(isEdit ? 'Đã cập nhật ao' : 'Đã thêm ao');
    }
  }

  Future<void> _showZoneDialog(DataProvider dp, [Zone? existing]) async {
    final isEdit = existing != null;
    final nameC = TextEditingController(text: existing?.name ?? '');
    String type = existing?.type ?? 'farming';
    String? branchId = (existing?.branchId.isNotEmpty == true && dp.branches.any((b) => b.id == existing!.branchId)) ? existing!.branchId : (dp.branches.isNotEmpty ? dp.branches.first.id : null);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, ss) => AlertDialog(
          title: Text(isEdit ? 'Sửa phân khu' : 'Thêm phân khu'),
          content: SizedBox(
            width: AppSizes.dialogMaxWidth,
            child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Tên phân khu')),
              const SizedBox(height: 12),
              if (dp.branches.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: branchId,
                  decoration: const InputDecoration(labelText: 'Chi nhánh'),
                  items: dp.branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                  onChanged: (v) => ss(() => branchId = v),
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Loại khu'),
                items: const [
                  DropdownMenuItem(value: 'farming', child: Text('Nuôi')),
                  DropdownMenuItem(value: 'treatment', child: Text('Xử lý')),
                  DropdownMenuItem(value: 'logistics', child: Text('Hậu cần')),
                ],
                onChanged: (v) => ss(() => type = v!),
              ),
            ]),
          ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Huỷ')),
            FilledButton(onPressed: () => Navigator.pop(dCtx, true), child: Text(isEdit ? 'Cập nhật' : 'Thêm')),
          ],
        ),
      ),
    );
    if (ok == true && nameC.text.isNotEmpty) {
      final data = {'name': nameC.text, 'branchId': branchId ?? '', 'type': type};
      if (isEdit) {
        await dp.update('zones', existing.id, data);
      } else {
        await dp.create('zones', data);
      }
      _showSnack(isEdit ? 'Đã cập nhật phân khu' : 'Đã thêm phân khu');
    }
  }

  Future<void> _showSpeciesDialog(DataProvider dp, [Species? existing]) async {
    final isEdit = existing != null;
    final nameC = TextEditingController(text: existing?.name ?? '');
    final descC = TextEditingController(text: existing?.description ?? '');
    final imageUrlC = TextEditingController(text: existing?.imageUrl ?? '');
    final tempC = TextEditingController(text: existing != null ? existing.requiredTemp.toString() : '28');
    final minTempC = TextEditingController(text: existing != null ? existing.minTemp.toString() : '20');
    final maxTempC = TextEditingController(text: existing != null ? existing.maxTemp.toString() : '35');
    final phC = TextEditingController(text: existing != null ? existing.requiredPh.toString() : '7');
    final doC = TextEditingController(text: existing != null ? existing.requiredDo.toString() : '4');
    final nh3C = TextEditingController(text: existing != null ? existing.maxNh3.toString() : '0.1');
    final feedC = TextEditingController(text: existing != null ? existing.feedRatio.toString() : '1.5');
    final harvestWC = TextEditingController(text: existing != null ? existing.harvestableWeight.toString() : '500');
    final growthDC = TextEditingController(text: existing != null ? existing.growthDays.toString() : '180');
    final densityC = TextEditingController(text: existing != null ? existing.densityPerM2.toString() : '5');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text(isEdit ? 'Sửa loài cá' : 'Thêm loài cá'),
        content: SizedBox(
          width: AppSizes.dialogMaxWidth,
          child: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (ctx, setDialogState) => Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Tên loài', prefixIcon: Icon(Icons.pets))),
            const SizedBox(height: 12),
            TextField(controller: descC, decoration: const InputDecoration(labelText: 'Mô tả', prefixIcon: Icon(Icons.description)), maxLines: 2),
            const SizedBox(height: 16),
            // ── Hình ảnh loài cá ──
            const Align(alignment: Alignment.centerLeft, child: Text('Hình ảnh đại diện', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
            const SizedBox(height: 8),
            TextField(
              controller: imageUrlC,
              decoration: const InputDecoration(
                labelText: 'URL hình ảnh',
                prefixIcon: Icon(Icons.image),
                hintText: 'https://example.com/fish.jpg',
              ),
              onChanged: (_) => setDialogState(() {}),
            ),
            const SizedBox(height: 8),
            if (imageUrlC.text.trim().isNotEmpty)
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.network(
                  imageUrlC.text.trim(),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_rounded, size: 32, color: AppColors.textHint),
                        SizedBox(height: 4),
                        Text('Không tải được ảnh', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
                      ],
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 80,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_photo_alternate_rounded, size: 28, color: AppColors.textHint),
                      SizedBox(height: 4),
                      Text('Dán URL ảnh loài cá ở trên', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            const Align(alignment: Alignment.centerLeft, child: Text('Yêu cầu môi trường', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: tempC, decoration: const InputDecoration(labelText: 'Nhiệt tối ưu (°C)'), keyboardType: TextInputType.number)),
              const SizedBox(width: 6),
              Expanded(child: TextField(controller: minTempC, decoration: const InputDecoration(labelText: 'Min (°C)'), keyboardType: TextInputType.number)),
              const SizedBox(width: 6),
              Expanded(child: TextField(controller: maxTempC, decoration: const InputDecoration(labelText: 'Max (°C)'), keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: phC, decoration: const InputDecoration(labelText: 'pH'), keyboardType: TextInputType.number)),
              const SizedBox(width: 6),
              Expanded(child: TextField(controller: doC, decoration: const InputDecoration(labelText: 'DO min (mg/L)'), keyboardType: TextInputType.number)),
              const SizedBox(width: 6),
              Expanded(child: TextField(controller: nh3C, decoration: const InputDecoration(labelText: 'NH3 max (mg/L)'), keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 16),
            const Align(alignment: Alignment.centerLeft, child: Text('Thông số nuôi', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: feedC, decoration: const InputDecoration(labelText: 'Tỷ lệ ăn (%)'), keyboardType: TextInputType.number)),
              const SizedBox(width: 6),
              Expanded(child: TextField(controller: densityC, decoration: const InputDecoration(labelText: 'Mật độ (con/m²)'), keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: harvestWC, decoration: const InputDecoration(labelText: 'Cỡ thu hoạch (g)'), keyboardType: TextInputType.number)),
              const SizedBox(width: 6),
              Expanded(child: TextField(controller: growthDC, decoration: const InputDecoration(labelText: 'Số ngày nuôi'), keyboardType: TextInputType.number)),
            ]),
          ]),
        ),
        ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(dCtx, true), child: Text(isEdit ? 'Cập nhật' : 'Thêm')),
        ],
      ),
    );
    if (ok == true && nameC.text.isNotEmpty) {
      final data = {
        'name': nameC.text,
        'description': descC.text,
        'imageUrl': imageUrlC.text.trim(),
        'requiredTemp': double.tryParse(tempC.text) ?? 28,
        'minTemp': double.tryParse(minTempC.text) ?? 20,
        'maxTemp': double.tryParse(maxTempC.text) ?? 35,
        'requiredPh': double.tryParse(phC.text) ?? 7,
        'requiredDo': double.tryParse(doC.text) ?? 4,
        'maxNh3': double.tryParse(nh3C.text) ?? 0.1,
        'feedRatio': double.tryParse(feedC.text) ?? 1.5,
        'harvestableWeight': double.tryParse(harvestWC.text) ?? 500,
        'growthDays': int.tryParse(growthDC.text) ?? 180,
        'densityPerM2': double.tryParse(densityC.text) ?? 5,
      };
      if (isEdit) {
        await dp.update('species', existing.id, data);
      } else {
        await dp.create('species', data);
      }
      _showSnack(isEdit ? 'Đã cập nhật loài' : 'Đã thêm loài');
    }
  }

  Future<void> _showBatchDialog(DataProvider dp, [FishBatch? existing]) async {
    final isEdit = existing != null;
    final nameC = TextEditingController(text: existing?.name ?? '');
    final qtyC = TextEditingController(text: existing != null ? existing.initialQuantity.toString() : '');
    final sizeC = TextEditingController(text: existing != null ? existing.initialSize.toString() : '');
    final weightC = TextEditingController(text: existing != null ? existing.initialWeight.toString() : '');
    final priceC = TextEditingController(text: existing != null && existing.importPrice > 0 ? existing.importPrice.toString() : '');
    final curQtyC = TextEditingController(text: existing != null ? existing.currentQuantity.toString() : '');
    final curSizeC = TextEditingController(text: existing != null ? existing.currentSize.toString() : '');
    final curWeightC = TextEditingController(text: existing != null ? existing.currentWeight.toString() : '');
    final mortalityC = TextEditingController(text: existing != null ? existing.mortalityQuantity.toString() : '0');
    final feedC = TextEditingController(text: existing != null ? existing.feedConsumed.toString() : '0');
    final noteC = TextEditingController(text: existing?.note ?? '');
    final sourceC = TextEditingController(text: existing?.source ?? '');

    String? branchId = existing?.branchId.isNotEmpty == true && dp.branches.any((b) => b.id == existing!.branchId)
        ? existing!.branchId
        : (dp.branches.isNotEmpty ? dp.branches.first.id : null);
    String? speciesId = existing?.speciesId != null && dp.species.any((s) => s.id == existing!.speciesId)
        ? existing!.speciesId
        : (dp.species.isNotEmpty ? dp.species.first.id : null);
    DateTime stockingDate = existing?.stockingDate ?? DateTime.now();
    DateTime? expectedHarvestDate = existing?.expectedHarvestDate;
    String? createdBy = existing?.createdBy.isNotEmpty == true && dp.employees.any((e) => e.id == existing!.createdBy)
        ? existing!.createdBy
        : (dp.employees.isNotEmpty ? dp.employees.first.id : null);
    String? inspectedBy = existing?.inspectedBy.isNotEmpty == true ? existing!.inspectedBy : null;

    // Pond allocations: [{pondId, quantity, controller}]
    List<Map<String, dynamic>> allocs = [];
    if (existing != null && existing.pondAllocations.isNotEmpty) {
      for (final a in existing.pondAllocations) {
        allocs.add({'pondId': a['pondId'], 'controller': TextEditingController(text: (a['quantity'] ?? 0).toString())});
      }
    } else if (existing != null && existing.pondId.isNotEmpty) {
      allocs.add({'pondId': existing.pondId, 'controller': TextEditingController(text: existing.currentQuantity.toString())});
    }

    // Filter ponds by selected branch
    List<Pond> pondsForBranch(String? bId) {
      if (bId == null) return dp.ponds;
      final zoneIds = dp.zones.where((z) => z.branchId == bId).map((z) => z.id).toSet();
      return dp.ponds.where((p) => p.zoneId != null && zoneIds.contains(p.zoneId)).toList();
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, ss) {
          final availPonds = pondsForBranch(branchId);
          final totalAlloc = allocs.fold<int>(0, (s, a) => s + (int.tryParse((a['controller'] as TextEditingController).text) ?? 0));
          final initQty = int.tryParse(qtyC.text) ?? 0;
          final canAdd = speciesId != null && (isEdit || initQty > 0);

          return AlertDialog(
            title: Text(isEdit ? 'Sửa lô cá' : 'Thêm lô cá'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppSizes.dialogMaxWidth, maxHeight: AppSizes.dialogMaxHeight),
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Warning when missing species
                  if (dp.species.isEmpty)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Row(children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 24),
                        const SizedBox(width: 10),
                        const Expanded(child: Text(
                          'Bạn chưa có loài cá/tôm nào. Vui lòng vào Danh mục → Loài cá để thêm trước khi tạo lô.',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        )),
                      ]),
                    ),
                  if (dp.ponds.isEmpty)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Row(children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 24),
                        const SizedBox(width: 10),
                        const Expanded(child: Text(
                          'Bạn chưa có ao nuôi nào. Vui lòng vào Ao nuôi → Thêm ao trước.',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        )),
                      ]),
                    ),
                  // === Tên lô ===
                  TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Tên lô cá', prefixIcon: Icon(Icons.label))),
                  const SizedBox(height: 12),
                  // === Chi nhánh ===
                  if (dp.branches.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: branchId,
                      decoration: const InputDecoration(labelText: 'Chi nhánh', prefixIcon: Icon(Icons.business)),
                      items: dp.branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                      onChanged: (v) => ss(() { branchId = v; allocs.clear(); }),
                    ),
                  const SizedBox(height: 12),
                  // === Loài cá ===
                  if (dp.species.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: speciesId,
                      decoration: const InputDecoration(labelText: 'Loài cá', prefixIcon: Icon(Icons.pets)),
                      items: dp.species.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                      onChanged: (v) => ss(() {
                        speciesId = v;
                        final sp = dp.species.where((s) => s.id == v).firstOrNull;
                        if (sp != null && sp.growthDays > 0) {
                          expectedHarvestDate = stockingDate.add(Duration(days: sp.growthDays));
                        }
                      }),
                    ),
                  const SizedBox(height: 12),
                  // === Ngày nhập & Nguồn giống ===
                  Row(children: [
                    Expanded(child: InkWell(
                      onTap: () async {
                        final d = await showDatePicker(context: dCtx, initialDate: stockingDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                        if (d != null) ss(() {
                          stockingDate = d;
                          final sp = dp.species.where((s) => s.id == speciesId).firstOrNull;
                          if (sp != null && sp.growthDays > 0) expectedHarvestDate = d.add(Duration(days: sp.growthDays));
                        });
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Ngày nhập', prefixIcon: Icon(Icons.calendar_today)),
                        child: Text(DateFormat('dd/MM/yyyy').format(stockingDate)),
                      ),
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: sourceC, decoration: const InputDecoration(labelText: 'Nguồn giống', prefixIcon: Icon(Icons.source)))),
                  ]),
                  const SizedBox(height: 16),
                  // === Thông số ban đầu ===
                  const Align(alignment: Alignment.centerLeft, child: Text('Thông số ban đầu', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: TextField(controller: qtyC, decoration: const InputDecoration(labelText: 'Số lượng (con)'), keyboardType: TextInputType.number, onChanged: (_) => ss(() {}))),
                    const SizedBox(width: 6),
                    Expanded(child: TextField(controller: sizeC, decoration: const InputDecoration(labelText: 'Kích cỡ (cm)'), keyboardType: TextInputType.number)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: TextField(controller: weightC, decoration: const InputDecoration(labelText: 'Trọng lượng (g)'), keyboardType: TextInputType.number)),
                    const SizedBox(width: 6),
                    Expanded(child: TextField(controller: priceC, decoration: const InputDecoration(labelText: 'Giá nhập (VNĐ/con)'), keyboardType: TextInputType.number)),
                  ]),
                  // === Thông số hiện tại (chỉ khi sửa) ===
                  if (isEdit) ...[
                    const SizedBox(height: 16),
                    const Align(alignment: Alignment.centerLeft, child: Text('Thông số hiện tại', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: TextField(controller: curQtyC, decoration: const InputDecoration(labelText: 'SL hiện tại'), keyboardType: TextInputType.number)),
                      const SizedBox(width: 6),
                      Expanded(child: TextField(controller: curSizeC, decoration: const InputDecoration(labelText: 'Cỡ TB (cm)'), keyboardType: TextInputType.number)),
                      const SizedBox(width: 6),
                      Expanded(child: TextField(controller: curWeightC, decoration: const InputDecoration(labelText: 'TL TB (g)'), keyboardType: TextInputType.number)),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: TextField(controller: mortalityC, decoration: const InputDecoration(labelText: 'Hao hụt (con)'), keyboardType: TextInputType.number)),
                      const SizedBox(width: 6),
                      Expanded(child: TextField(controller: feedC, decoration: const InputDecoration(labelText: 'Tổng thức ăn (kg)'), keyboardType: TextInputType.number)),
                    ]),
                  ],
                  // === Phân bổ ao nuôi ===
                  const SizedBox(height: 16),
                  Row(children: [
                    const Expanded(child: Text('Phân bổ ao nuôi', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                    if (initQty > 0)
                      Text('$totalAlloc / $initQty con', style: TextStyle(fontSize: 12, color: totalAlloc > initQty ? Colors.red : Colors.grey[600])),
                  ]),
                  const SizedBox(height: 8),
                  ...List.generate(allocs.length, (i) {
                    final a = allocs[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        Expanded(flex: 3, child: DropdownButtonFormField<String>(
                          value: availPonds.any((p) => p.id == a['pondId']) ? a['pondId'] as String? : null,
                          decoration: const InputDecoration(labelText: 'Ao', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                          items: availPonds.map((p) => DropdownMenuItem(value: p.id, child: Text(p.code))).toList(),
                          onChanged: (v) => ss(() => allocs[i]['pondId'] = v),
                        )),
                        const SizedBox(width: 6),
                        Expanded(flex: 2, child: TextField(
                          controller: a['controller'] as TextEditingController,
                          decoration: const InputDecoration(labelText: 'Số lượng', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => ss(() {}),
                        )),
                        IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20), onPressed: () => ss(() { (allocs[i]['controller'] as TextEditingController).dispose(); allocs.removeAt(i); })),
                      ]),
                    );
                  }),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Thêm ao'),
                    onPressed: () => ss(() => allocs.add({'pondId': availPonds.isNotEmpty ? availPonds.first.id : null, 'controller': TextEditingController(text: '0')})),
                  ),
                  // === Dự kiến thu hoạch ===
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final d = await showDatePicker(context: dCtx, initialDate: expectedHarvestDate ?? DateTime.now().add(const Duration(days: 180)), firstDate: DateTime(2020), lastDate: DateTime(2030));
                      if (d != null) ss(() => expectedHarvestDate = d);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Dự kiến thu hoạch', prefixIcon: Icon(Icons.event)),
                      child: Text(expectedHarvestDate != null ? DateFormat('dd/MM/yyyy').format(expectedHarvestDate!) : 'Chưa chọn'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: noteC, decoration: const InputDecoration(labelText: 'Ghi chú', prefixIcon: Icon(Icons.note)), maxLines: 2),
                  const SizedBox(height: 12),
                  if (dp.employees.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      initialValue: createdBy,
                      decoration: const InputDecoration(labelText: 'Người tạo lô', prefixIcon: Icon(Icons.person)),
                      items: dp.employees.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
                      onChanged: (v) => ss(() => createdBy = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: inspectedBy,
                      decoration: const InputDecoration(labelText: 'NV kiểm định cá', prefixIcon: Icon(Icons.verified_user)),
                      items: [const DropdownMenuItem<String>(value: null, child: Text('-- Chưa chọn --')), ...dp.employees.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name)))],
                      onChanged: (v) => ss(() => inspectedBy = v),
                    ),
                  ],
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Huỷ')),
              FilledButton(onPressed: canAdd ? () => Navigator.pop(dCtx, true) : null, child: Text(isEdit ? 'Cập nhật' : 'Thêm')),
            ],
          );
        },
      ),
    );
    if (ok == true && speciesId != null) {
      final initQtyVal = int.tryParse(qtyC.text) ?? 0;
      if (initQtyVal <= 0 && !isEdit) {
        _showSnack('Số lượng ban đầu phải > 0');
        return;
      }
      final pondAllocs = allocs.where((a) => a['pondId'] != null).map((a) => {'pondId': a['pondId'], 'quantity': int.tryParse((a['controller'] as TextEditingController).text) ?? 0}).toList();
      final firstPondId = pondAllocs.isNotEmpty ? pondAllocs.first['pondId'] as String : '';
      final data = {
        'name': nameC.text.trim(),
        'branchId': branchId ?? '',
        'pondId': firstPondId,
        'speciesId': speciesId,
        'pondAllocations': pondAllocs,
        'stockingDate': stockingDate.toIso8601String(),
        'initialQuantity': int.tryParse(qtyC.text) ?? 0,
        'initialSize': double.tryParse(sizeC.text) ?? 0,
        'initialWeight': double.tryParse(weightC.text) ?? 0,
        'importPrice': double.tryParse(priceC.text) ?? 0,
        'currentQuantity': isEdit ? (int.tryParse(curQtyC.text) ?? existing.currentQuantity) : (int.tryParse(qtyC.text) ?? 0),
        'currentSize': double.tryParse(curSizeC.text) ?? 0,
        'currentWeight': double.tryParse(curWeightC.text) ?? 0,
        'mortalityQuantity': int.tryParse(mortalityC.text) ?? 0,
        'feedConsumed': double.tryParse(feedC.text) ?? 0,
        'expectedHarvestDate': expectedHarvestDate?.toIso8601String(),
        'status': existing?.status ?? 'active',
        'source': sourceC.text,
        'note': noteC.text,
        'createdBy': createdBy ?? '',
        'inspectedBy': inspectedBy ?? '',
      };
      if (isEdit) {
        await dp.update('fishbatches', existing.id, data);
      } else {
        final created = await dp.create('fishbatches', data);
        if (!created) {
          for (final c in allocs) { (c['controller'] as TextEditingController).dispose(); }
          _showSnack('Thêm lô cá thất bại. Vui lòng thử lại.');
          return;
        }
      }
      // Tự kích hoạt ao khi thả cá (dùng update trực tiếp API, không cascade reload fishbatches lại)
      for (final a in pondAllocs) {
        final pid = a['pondId'] as String;
        final pond = dp.ponds.where((p) => p.id == pid).firstOrNull;
        if (pond != null && pond.status != 'active') {
          await dp.update('ponds', pid, {...pond.toJson(), 'status': 'active'});
        }
      }
      // Reload fishbatches lần cuối để đảm bảo dữ liệu đồng bộ
      await dp.reload('fishbatches');
      for (final c in allocs) { (c['controller'] as TextEditingController).dispose(); }
      _showSnack(isEdit ? 'Đã cập nhật lô cá' : 'Đã thêm lô cá');
    } else {
      for (final c in allocs) { (c['controller'] as TextEditingController).dispose(); }
    }
  }

  Future<void> _showStaffDialog(DataProvider dp, [Employee? existing]) async {
    final isEdit = existing != null;
    final nameC = TextEditingController(text: existing?.name ?? '');
    final emailC = TextEditingController(text: existing?.email ?? '');
    final phoneC = TextEditingController(text: existing?.phone ?? '');
    String role = existing?.role ?? 'worker';
    List<String> shifts = existing?.shift.isNotEmpty == true
        ? existing!.shift.split(', ').toList()
        : ['Sáng'];
    String? branchId = (existing?.branchId.isNotEmpty == true && dp.branches.any((b) => b.id == existing!.branchId)) ? existing!.branchId : (dp.branches.isNotEmpty ? dp.branches.first.id : null);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, ss) => AlertDialog(
          title: Text(isEdit ? 'Sửa nhân viên' : 'Thêm nhân viên'),
          content: SizedBox(
            width: AppSizes.dialogMaxWidth,
            child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Họ tên *', prefixIcon: Icon(Icons.person))),
              const SizedBox(height: 12),
              TextField(controller: emailC, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              TextField(controller: phoneC, decoration: const InputDecoration(labelText: 'SĐT', prefixIcon: Icon(Icons.phone_outlined)),
                keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              Autocomplete<String>(
                initialValue: TextEditingValue(text: Employee.roleToLabel(role)),
                optionsBuilder: (textEditingValue) {
                  final allOptions = <String>[
                    ...Employee.defaultRoles.values,
                    ...dp.employees.map((e) => Employee.roleToLabel(e.role)).where((r) => !Employee.defaultRoles.values.contains(r)).toSet(),
                  ];
                  if (textEditingValue.text.isEmpty) return allOptions;
                  return allOptions.where((o) => o.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                },
                onSelected: (v) => ss(() => role = Employee.labelToRole(v)),
                fieldViewBuilder: (ctx, controller, focusNode, onSubmitted) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Vai trò',
                      prefixIcon: Icon(Icons.badge_outlined),
                      hintText: 'Chọn hoặc nhập vai trò mới',
                    ),
                    onChanged: (v) => role = Employee.labelToRole(v),
                  );
                },
              ),
              const SizedBox(height: 16),
              const Align(alignment: Alignment.centerLeft, child: Text('Ca làm', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ('Sáng', '6:00 – 14:00', Icons.wb_sunny_outlined),
                  ('Chiều', '14:00 – 22:00', Icons.wb_twilight_outlined),
                  ('Tối', '22:00 – 6:00', Icons.nightlight_outlined),
                ].map((s) {
                  final selected = shifts.contains(s.$1);
                  return FilterChip(
                    selected: selected,
                    label: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(s.$3, size: 16, color: selected ? Colors.white : AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text('${s.$1} (${s.$2})'),
                    ]),
                    selectedColor: AppColors.primary,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      color: selected ? Colors.white : AppColors.textPrimary,
                    ),
                    onSelected: (v) => ss(() {
                      if (v) { shifts.add(s.$1); } else { shifts.remove(s.$1); }
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              if (dp.branches.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: branchId,
                  decoration: const InputDecoration(labelText: 'Chi nhánh'),
                  items: dp.branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                  onChanged: (v) => ss(() => branchId = v),
                ),
            ]),
          ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Huỷ')),
            FilledButton(onPressed: () => Navigator.pop(dCtx, true), child: Text(isEdit ? 'Cập nhật' : 'Thêm')),
          ],
        ),
      ),
    );
    if (ok == true && nameC.text.trim().isNotEmpty) {
      final data = {
        'name': nameC.text.trim(),
        'email': emailC.text.trim(),
        'phone': phoneC.text.trim(),
        'role': role,
        'shift': shifts.join(', '),
        'branchId': branchId ?? '',
      };
      if (isEdit) {
        await dp.update('employees', existing.id, data);
      } else {
        await dp.create('employees', data);
      }
      _showSnack(isEdit ? 'Đã cập nhật nhân viên' : 'Đã thêm nhân viên');
    }
  }

  Future<void> _showCreateAccountDialog(DataProvider dp, Employee emp) async {
    final emailC = TextEditingController(text: emp.email);
    final phoneC = TextEditingController(text: emp.phone);
    final passwordC = TextEditingController();
    final confirmC = TextEditingController();
    String role = emp.role.isEmpty ? 'worker' : emp.role;
    List<String> permissions = List<String>.from(AppPermissions.forRole(role));
    bool obscurePass = true;
    bool obscureConfirm = true;
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, ss) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.person_add_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              const Text('Tạo tài khoản'),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSizes.dialogMaxWidth),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.primary.withAlpha(20),
                          child: Text(emp.name.isNotEmpty ? emp.name[0].toUpperCase() : '?',
                            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                        ),
                        const SizedBox(width: 12),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(emp.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(emp.roleLabel, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailC,
                    decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined, size: 20)),
                    validator: (v) {
                      if ((v == null || v.trim().isEmpty) && phoneC.text.trim().isEmpty) return 'Nhập email hoặc SĐT';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneC,
                    decoration: const InputDecoration(labelText: 'Số điện thoại', prefixIcon: Icon(Icons.phone_outlined, size: 20)),
                    validator: (v) {
                      if ((v == null || v.trim().isEmpty) && emailC.text.trim().isEmpty) return 'Nhập email hoặc SĐT';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passwordC,
                    obscureText: obscurePass,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu',
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                        onPressed: () => ss(() => obscurePass = !obscurePass),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu';
                      if (v.length < 6) return 'Mật khẩu ít nhất 6 ký tự';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmC,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Xác nhận mật khẩu',
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                        onPressed: () => ss(() => obscureConfirm = !obscureConfirm),
                      ),
                    ),
                    validator: (v) {
                      if (v != passwordC.text) return 'Mật khẩu không khớp';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Autocomplete<String>(
                    initialValue: TextEditingValue(text: Employee.roleToLabel(role)),
                    optionsBuilder: (textEditingValue) {
                      final allOptions = <String>[
                        ...Employee.defaultRoles.values,
                        ...dp.employees.map((e) => Employee.roleToLabel(e.role)).where((r) => !Employee.defaultRoles.values.contains(r)).toSet(),
                      ];
                      if (textEditingValue.text.isEmpty) return allOptions;
                      return allOptions.where((o) => o.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                    },
                    onSelected: (v) {
                      ss(() {
                        role = Employee.labelToRole(v);
                        permissions = List<String>.from(AppPermissions.forRole(role));
                      });
                    },
                    fieldViewBuilder: (ctx, controller, focusNode, onSubmitted) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Vai trò',
                          prefixIcon: Icon(Icons.badge_outlined, size: 20),
                          hintText: 'Chọn hoặc nhập vai trò mới',
                        ),
                        onChanged: (v) {
                          role = Employee.labelToRole(v);
                          permissions = List<String>.from(AppPermissions.forRole(role));
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Phân quyền', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      Row(children: [
                        TextButton(
                          onPressed: () => ss(() {
                            final allPerms = AppPermissions.allGranular.where((p) => !p.startsWith('accounts')).toList();
                            permissions = List<String>.from(allPerms);
                          }),
                          child: const Text('Chọn tất cả', style: TextStyle(fontSize: 12)),
                        ),
                        TextButton(
                          onPressed: () => ss(() => permissions.clear()),
                          child: const Text('Bỏ tất cả', style: TextStyle(fontSize: 12, color: AppColors.error)),
                        ),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Header row
                  Row(children: [
                    const SizedBox(width: 110, child: Text('Chức năng', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                    ...AppPermissions.actions.map((a) => Expanded(
                      child: Center(child: Text(AppPermissions.actionLabels[a] ?? a, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                    )),
                  ]),
                  const Divider(height: 8),
                  ...AppPermissions.all.where((m) => m != 'accounts').map((module) {
                    final isCrud = AppPermissions.crudModules.contains(module);
                    return Row(children: [
                      SizedBox(width: 110, child: Text(AppPermissions.labels[module] ?? module, style: const TextStyle(fontSize: 13))),
                      ...AppPermissions.actions.map((action) {
                        if (!isCrud && action != AppPermissions.view) {
                          return const Expanded(child: SizedBox.shrink());
                        }
                        final key = AppPermissions.key(module, action);
                        return Expanded(
                          child: Checkbox(
                            value: permissions.contains(key),
                            onChanged: (v) => ss(() {
                              if (v == true) {
                                permissions.add(key);
                                if (action != AppPermissions.view) {
                                  final viewKey = AppPermissions.key(module, AppPermissions.view);
                                  if (!permissions.contains(viewKey)) permissions.add(viewKey);
                                }
                              } else {
                                permissions.remove(key);
                                if (action == AppPermissions.view) {
                                  for (final a in AppPermissions.actions) {
                                    permissions.remove(AppPermissions.key(module, a));
                                  }
                                }
                              }
                            }),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                        );
                      }),
                    ]);
                  }),
                ]),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Huỷ')),
            FilledButton(onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(dCtx, true);
            }, child: const Text('Tạo tài khoản')),
          ],
        ),
      ),
    );

    if (ok == true) {
      final authService = AuthService();
      final result = await authService.createStoreUser(
        employeeId: emp.id,
        email: emailC.text.trim(),
        phone: phoneC.text.trim(),
        password: passwordC.text,
        role: role,
        permissions: permissions,
      );
      if (!mounted) return;
      if (result.success) {
        await dp.loadAll();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text('Đã tạo tài khoản cho ${emp.name}'),
            ]),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(result.error ?? 'Tạo tài khoản thất bại')),
            ]),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _showPermissionsDialog(DataProvider dp, Employee emp) async {
    String role = emp.role;
    List<String> permissions = List<String>.from(emp.permissions.isNotEmpty ? emp.permissions : AppPermissions.forRole(role));

    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, ss) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.security_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              const Expanded(child: Text('Phân quyền')),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSizes.dialogMaxWidth),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primary.withAlpha(20),
                      child: Text(emp.name.isNotEmpty ? emp.name[0].toUpperCase() : '?',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(emp.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(emp.email.isNotEmpty ? emp.email : emp.phone,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success.withAlpha(20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Có tài khoản', style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                Autocomplete<String>(
                  initialValue: TextEditingValue(text: Employee.roleToLabel(role)),
                  optionsBuilder: (textEditingValue) {
                    final allOptions = <String>[
                      ...Employee.defaultRoles.values,
                      ...dp.employees.map((e) => Employee.roleToLabel(e.role)).where((r) => !Employee.defaultRoles.values.contains(r)).toSet(),
                    ];
                    if (textEditingValue.text.isEmpty) return allOptions;
                    return allOptions.where((o) => o.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                  },
                  onSelected: (v) {
                    ss(() {
                      role = Employee.labelToRole(v);
                      permissions = List<String>.from(AppPermissions.forRole(role));
                    });
                  },
                  fieldViewBuilder: (ctx, controller, focusNode, onSubmitted) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Vai trò',
                        prefixIcon: Icon(Icons.badge_outlined, size: 20),
                        hintText: 'Chọn hoặc nhập vai trò mới',
                      ),
                      onChanged: (v) {
                        ss(() {
                          role = Employee.labelToRole(v);
                          permissions = List<String>.from(AppPermissions.forRole(role));
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Quyền truy cập', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    Row(children: [
                      TextButton(
                        onPressed: () => ss(() {
                          final allPerms = AppPermissions.allGranular.where((p) => !p.startsWith('accounts')).toList();
                          permissions = List<String>.from(allPerms);
                        }),
                        child: const Text('Chọn tất cả', style: TextStyle(fontSize: 12)),
                      ),
                      TextButton(
                        onPressed: () => ss(() => permissions.clear()),
                        child: const Text('Bỏ tất cả', style: TextStyle(fontSize: 12, color: AppColors.error)),
                      ),
                    ]),
                  ],
                ),
                const SizedBox(height: 4),
                // Header row
                Row(children: [
                  const SizedBox(width: 110, child: Text('Chức năng', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                  ...AppPermissions.actions.map((a) => Expanded(
                    child: Center(child: Text(AppPermissions.actionLabels[a] ?? a, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                  )),
                ]),
                const Divider(height: 8),
                ...AppPermissions.all.where((m) => m != 'accounts').map((module) {
                  final isCrud = AppPermissions.crudModules.contains(module);
                  return Row(children: [
                    SizedBox(width: 110, child: Text(AppPermissions.labels[module] ?? module, style: const TextStyle(fontSize: 13))),
                    ...AppPermissions.actions.map((action) {
                      if (!isCrud && action != AppPermissions.view) {
                        return const Expanded(child: SizedBox.shrink());
                      }
                      final key = AppPermissions.key(module, action);
                      return Expanded(
                        child: Checkbox(
                          value: permissions.contains(key),
                          onChanged: (v) => ss(() {
                            if (v == true) {
                              permissions.add(key);
                              // Auto-add view when adding other actions
                              if (action != AppPermissions.view) {
                                final viewKey = AppPermissions.key(module, AppPermissions.view);
                                if (!permissions.contains(viewKey)) permissions.add(viewKey);
                              }
                            } else {
                              permissions.remove(key);
                              // Auto-remove create/edit/delete when removing view
                              if (action == AppPermissions.view) {
                                for (final a in AppPermissions.actions) {
                                  permissions.remove(AppPermissions.key(module, a));
                                }
                              }
                            }
                          }),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      );
                    }),
                  ]);
                }),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final pwC = TextEditingController();
                        final cfC = TextEditingController();
                        final fk = GlobalKey<FormState>();
                        final pwOk = await showDialog<bool>(
                          context: dCtx,
                          builder: (ctx2) => AlertDialog(
                            title: const Text('Đổi mật khẩu'),
                            content: SizedBox(
                              width: 400,
                              child: Form(
                              key: fk,
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                TextFormField(controller: pwC, obscureText: true,
                                  decoration: const InputDecoration(labelText: 'Mật khẩu mới', prefixIcon: Icon(Icons.lock_outline, size: 20)),
                                  validator: (v) => (v == null || v.length < 6) ? 'Ít nhất 6 ký tự' : null),
                                const SizedBox(height: 12),
                                TextFormField(controller: cfC, obscureText: true,
                                  decoration: const InputDecoration(labelText: 'Xác nhận', prefixIcon: Icon(Icons.lock_outline, size: 20)),
                                  validator: (v) => v != pwC.text ? 'Không khớp' : null),
                              ]),
                            ),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx2, false), child: const Text('Huỷ')),
                              FilledButton(onPressed: () {
                                if (fk.currentState!.validate()) Navigator.pop(ctx2, true);
                              }, child: const Text('Đổi')),
                            ],
                          ),
                        );
                        if (pwOk == true) {
                          final authService = AuthService();
                          final r = await authService.resetStoreUserPassword(employeeId: emp.id, newPassword: pwC.text);
                          if (dCtx.mounted) {
                            ScaffoldMessenger.of(dCtx).showSnackBar(SnackBar(
                              content: Text(r.success ? 'Đã đổi mật khẩu' : (r.error ?? 'Lỗi')),
                              backgroundColor: r.success ? AppColors.success : AppColors.error,
                            ));
                          }
                        }
                      },
                      icon: const Icon(Icons.lock_reset_rounded, size: 18),
                      label: const Text('Đổi MK', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final delOk = await showDialog<bool>(
                          context: dCtx,
                          builder: (ctx2) => AlertDialog(
                            title: const Text('Xoá tài khoản'),
                            content: Text('Xoá tài khoản đăng nhập của "${emp.name}"? Nhân viên vẫn tồn tại nhưng không thể đăng nhập.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx2, false), child: const Text('Huỷ')),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx2, true),
                                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                                child: const Text('Xoá'),
                              ),
                            ],
                          ),
                        );
                        if (delOk == true) {
                          final authService = AuthService();
                          final r = await authService.removeStoreUser(employeeId: emp.id);
                          if (!dCtx.mounted) return;
                          if (r.success) {
                            await dp.loadAll();
                            if (!dCtx.mounted) return;
                          }
                          ScaffoldMessenger.of(dCtx).showSnackBar(SnackBar(
                            content: Text(r.success ? 'Đã xoá tài khoản' : (r.error ?? 'Lỗi')),
                            backgroundColor: r.success ? AppColors.success : AppColors.error,
                          ));
                          if (r.success) Navigator.pop(dCtx, false);
                        }
                      },
                      icon: const Icon(Icons.person_remove_rounded, size: 18, color: AppColors.error),
                      label: const Text('Xoá TK', style: TextStyle(fontSize: 13, color: AppColors.error)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error)),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Huỷ')),
            FilledButton(onPressed: () => Navigator.pop(dCtx, true), child: const Text('Lưu quyền')),
          ],
        ),
      ),
    );

    if (ok == true) {
      final authService = AuthService();
      final result = await authService.updatePermissions(employeeId: emp.id, role: role, permissions: permissions);
      if (!mounted) return;
      if (result.success) {
        await dp.loadAll();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text('Đã cập nhật quyền'),
            ]),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(result.error ?? 'Cập nhật thất bại')),
            ]),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _showTaskDialog(DataProvider dp, [Task? existing]) async {
    final isEdit = existing != null;
    final titleC = TextEditingController(text: existing?.title ?? '');
    final noteC = TextEditingController(text: existing?.note ?? '');
    String type = existing?.type ?? 'feeding';
    String? assignedTo = existing?.assignedTo != null && dp.employees.any((e) => e.id == existing!.assignedTo)
        ? existing!.assignedTo
        : (dp.employees.isNotEmpty ? dp.employees.first.id : null);
    String? pondId = existing?.pondId != null && dp.ponds.any((p) => p.id == existing!.pondId)
        ? existing!.pondId
        : (dp.ponds.isNotEmpty ? dp.ponds.first.id : null);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, ss) => AlertDialog(
          title: Text(isEdit ? 'Sửa công việc' : 'Thêm công việc'),
          content: SizedBox(
            width: AppSizes.dialogMaxWidth,
            child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: titleC, decoration: const InputDecoration(labelText: 'Tiêu đề')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Loại'),
                items: const [
                  DropdownMenuItem(value: 'feeding', child: Text('Cho ăn')),
                  DropdownMenuItem(value: 'water_check', child: Text('Đo nước')),
                  DropdownMenuItem(value: 'water_change', child: Text('Thay nước')),
                  DropdownMenuItem(value: 'harvest', child: Text('Thu hoạch')),
                  DropdownMenuItem(value: 'treatment', child: Text('Xử lý')),
                  DropdownMenuItem(value: 'other', child: Text('Khác')),
                ],
                onChanged: (v) => ss(() => type = v!),
              ),
              const SizedBox(height: 12),
              if (dp.employees.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: assignedTo,
                  decoration: const InputDecoration(labelText: 'Giao cho'),
                  items: dp.employees.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
                  onChanged: (v) => ss(() => assignedTo = v),
                ),
              const SizedBox(height: 12),
              if (dp.ponds.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: pondId,
                  decoration: const InputDecoration(labelText: 'Ao'),
                  items: dp.ponds.map((p) => DropdownMenuItem(value: p.id, child: Text(p.code))).toList(),
                  onChanged: (v) => ss(() => pondId = v),
                ),
              const SizedBox(height: 12),
              TextField(controller: noteC, decoration: const InputDecoration(labelText: 'Ghi chú'), maxLines: 2),
            ]),
          ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Huỷ')),
            FilledButton(onPressed: () => Navigator.pop(dCtx, true), child: Text(isEdit ? 'Cập nhật' : 'Thêm')),
          ],
        ),
      ),
    );
    if (ok == true && titleC.text.isNotEmpty) {
      final data = {
        'title': titleC.text,
        'type': type,
        'assignedTo': assignedTo ?? '',
        'pondId': pondId ?? '',
        'dueDate': existing?.dueDate.toIso8601String() ?? DateTime.now().add(const Duration(days: 1)).toIso8601String(),
        'status': existing?.status ?? 'pending',
        'note': noteC.text,
      };
      if (isEdit) {
        await dp.update('tasks', existing.id, data);
      } else {
        await dp.create('tasks', data);
      }
      _showSnack(isEdit ? 'Đã cập nhật công việc' : 'Đã thêm công việc');
    }
  }

  Future<void> _showCustomerDialog(DataProvider dp, [Customer? existing]) async {
    final isEdit = existing != null;
    final nameC = TextEditingController(text: existing?.name ?? '');
    final companyC = TextEditingController(text: existing?.company ?? '');
    final phoneC = TextEditingController(text: existing?.phone ?? '');
    final emailC = TextEditingController(text: existing?.email ?? '');
    final addrC = TextEditingController(text: existing?.address ?? '');
    final contactC = TextEditingController(text: existing?.contact ?? '');
    final noteC = TextEditingController(text: existing?.note ?? '');
    String type = existing?.type ?? 'retail';
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, ss) => AlertDialog(
          title: Row(children: [
            Icon(isEdit ? Icons.edit : Icons.person_add_rounded, color: AppColors.primary, size: 22),
            const SizedBox(width: 8),
            Text(isEdit ? 'Sửa khách hàng' : 'Thêm khách hàng'),
          ]),
          content: SizedBox(
            width: AppSizes.dialogMaxWidth,
            child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Tên khách hàng *', prefixIcon: Icon(Icons.person))),
              const SizedBox(height: 12),
              TextField(controller: companyC, decoration: const InputDecoration(labelText: 'Công ty / Tổ chức', prefixIcon: Icon(Icons.business))),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Loại khách hàng', prefixIcon: Icon(Icons.category_outlined)),
                items: const [
                  DropdownMenuItem(value: 'retail', child: Text('Khách lẻ')),
                  DropdownMenuItem(value: 'wholesale', child: Text('Đại lý / Sỉ')),
                ],
                onChanged: (v) => ss(() => type = v!),
              ),
              const SizedBox(height: 12),
              TextField(controller: phoneC, decoration: const InputDecoration(labelText: 'Số điện thoại', prefixIcon: Icon(Icons.phone_outlined)),
                keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              TextField(controller: emailC, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              TextField(controller: addrC, decoration: const InputDecoration(labelText: 'Địa chỉ', prefixIcon: Icon(Icons.location_on_outlined))),
              const SizedBox(height: 12),
              TextField(controller: contactC, decoration: const InputDecoration(labelText: 'Người liên hệ', prefixIcon: Icon(Icons.contact_phone_outlined))),
              const SizedBox(height: 12),
              TextField(controller: noteC, decoration: const InputDecoration(labelText: 'Ghi chú', prefixIcon: Icon(Icons.note_alt_outlined)),
                maxLines: 2),
            ]),
          ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Huỷ')),
            FilledButton(onPressed: () => Navigator.pop(dCtx, true), child: Text(isEdit ? 'Cập nhật' : 'Thêm')),
          ],
        ),
      ),
    );
    if (ok == true && nameC.text.isNotEmpty) {
      final data = {
        'name': nameC.text.trim(),
        'type': type,
        'company': companyC.text.trim(),
        'phone': phoneC.text.trim(),
        'email': emailC.text.trim(),
        'address': addrC.text.trim(),
        'contact': contactC.text.trim(),
        'note': noteC.text.trim(),
        'debt': existing?.debt ?? 0,
      };
      if (isEdit) {
        await dp.update('customers', existing.id, data);
      } else {
        await dp.create('customers', data);
      }
      _showSnack(isEdit ? 'Đã cập nhật khách hàng' : 'Đã thêm khách hàng');
    }
  }

  Future<void> _showSaleDialog(DataProvider dp, [SaleOrder? existing]) async {
    final isEdit = existing != null;
    String? customerId = existing?.customerId != null && dp.customers.any((c) => c.id == existing!.customerId)
        ? existing!.customerId
        : (dp.customers.isNotEmpty ? dp.customers.first.id : null);
    String? pondId = existing?.pondId != null && dp.ponds.any((p) => p.id == existing!.pondId)
        ? existing!.pondId
        : (dp.ponds.isNotEmpty ? dp.ponds.first.id : null);
    String status = existing?.status ?? 'pending';
    // Line items: each {productId, productName, quantity, price, amount}
    final List<Map<String, dynamic>> items = existing != null && existing.items.isNotEmpty
        ? existing.items.map((i) => Map<String, dynamic>.from(i)).toList()
        : [];

    double calcTotal() => items.fold(0.0, (s, i) => s + ((i['amount'] as num?)?.toDouble() ?? 0));

    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, ss) {
          void addItem() {
            if (dp.products.isEmpty) return;
            final p = dp.products.first;
            ss(() {
              items.add({'productId': p.id, 'productName': p.name, 'quantity': 1.0, 'price': p.price, 'amount': p.price});
            });
          }
          void removeItem(int idx) => ss(() => items.removeAt(idx));
          void recalcItem(int idx) {
            final item = items[idx];
            final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
            final price = (item['price'] as num?)?.toDouble() ?? 0;
            item['amount'] = qty * price;
          }

          final total = calcTotal();
          return AlertDialog(
            title: Row(children: [
              const Icon(Icons.point_of_sale_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(isEdit ? 'Sửa đơn bán' : 'Thêm đơn bán'),
            ]),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppSizes.dialogMaxWidth, maxHeight: AppSizes.dialogMaxHeight),
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Customer
                  if (dp.customers.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: customerId,
                      decoration: const InputDecoration(labelText: 'Khách hàng', prefixIcon: Icon(Icons.person)),
                      items: dp.customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (v) => ss(() => customerId = v),
                    ),
                  const SizedBox(height: 12),
                  // Pond
                  if (dp.ponds.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: pondId,
                      decoration: const InputDecoration(labelText: 'Ao', prefixIcon: Icon(Icons.water)),
                      items: dp.ponds.map((p) => DropdownMenuItem(value: p.id, child: Text(p.code, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (v) => ss(() => pondId = v),
                    ),
                  const SizedBox(height: 12),
                  // Status
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Trạng thái', prefixIcon: Icon(Icons.flag)),
                    items: const [
                      DropdownMenuItem(value: 'pending', child: Text('Chờ xử lý')),
                      DropdownMenuItem(value: 'completed', child: Text('Hoàn thành')),
                      DropdownMenuItem(value: 'cancelled', child: Text('Đã huỷ')),
                    ],
                    onChanged: (v) => ss(() => status = v!),
                  ),
                  const SizedBox(height: 16),
                  // Line items header
                  Row(
                    children: [
                      const Icon(Icons.list_alt_rounded, size: 18, color: AppColors.primary),
                      const SizedBox(width: 6),
                      const Text('Sản phẩm', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: dp.products.isEmpty ? null : addItem,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Thêm dòng', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  if (items.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(child: Text('Chưa có sản phẩm. Nhấn "Thêm dòng" để thêm.', style: TextStyle(color: AppColors.textHint, fontSize: 12))),
                    ),
                  // Line items list
                  ...items.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    final qtyC = TextEditingController(text: (item['quantity'] as num?)?.toString() ?? '1');
                    final priceC = TextEditingController(text: (item['price'] as num?)?.toString() ?? '0');
                    return Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Row(children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: item['productId'] as String?,
                                decoration: const InputDecoration(labelText: 'Sản phẩm', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                                isExpanded: true,
                                items: dp.products.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)))).toList(),
                                onChanged: (v) {
                                  final prod = dp.productById(v!);
                                  ss(() {
                                    item['productId'] = v;
                                    item['productName'] = prod?.name ?? '';
                                    item['price'] = prod?.price ?? 0;
                                    recalcItem(idx);
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18, color: AppColors.error),
                              onPressed: () => removeItem(idx),
                              tooltip: 'Xoá dòng',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            ),
                          ]),
                          const SizedBox(height: 6),
                          Row(children: [
                            Expanded(
                              child: TextField(
                                controller: qtyC,
                                decoration: const InputDecoration(labelText: 'SL', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                                onChanged: (v) => ss(() { item['quantity'] = double.tryParse(v) ?? 0; recalcItem(idx); }),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: priceC,
                                decoration: const InputDecoration(labelText: 'Đơn giá', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                                onChanged: (v) => ss(() { item['price'] = double.tryParse(v) ?? 0; recalcItem(idx); }),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 90,
                              child: Text('${_currencyFmt.format(item['amount'] ?? 0)}đ',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13), textAlign: TextAlign.right),
                            ),
                          ]),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  // Total
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tổng cộng:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        Text('${_currencyFmt.format(total)}đ', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.primary)),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Huỷ')),
              FilledButton.icon(
                onPressed: () {
                  if (customerId == null) {
                    ScaffoldMessenger.of(dCtx).showSnackBar(const SnackBar(content: Text('Vui lòng chọn khách hàng'), backgroundColor: Colors.red));
                    return;
                  }
                  if (items.isEmpty) {
                    ScaffoldMessenger.of(dCtx).showSnackBar(const SnackBar(content: Text('Đơn hàng phải có ít nhất 1 sản phẩm'), backgroundColor: Colors.red));
                    return;
                  }
                  final hasInvalidItem = items.any((i) => i['productId'] == null || i['productId'] == '' || ((i['quantity'] as num?)?.toDouble() ?? 0) <= 0);
                  if (hasInvalidItem) {
                    ScaffoldMessenger.of(dCtx).showSnackBar(const SnackBar(content: Text('Vui lòng chọn sản phẩm và nhập số lượng > 0'), backgroundColor: Colors.red));
                    return;
                  }
                  Navigator.pop(dCtx, true);
                },
                icon: const Icon(Icons.check),
                label: Text(isEdit ? 'Cập nhật' : 'Thêm'),
              ),
            ],
          );
        },
      ),
    );
    if (ok == true && customerId != null) {
      // Validate items have positive quantities
      for (final item in items) {
        final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
        if (qty <= 0) {
          _showSnack('Số lượng sản phẩm phải > 0');
          return;
        }
      }
      if (items.isEmpty) {
        _showSnack('Đơn hàng phải có ít nhất 1 sản phẩm');
        return;
      }
      final data = {
        'customerId': customerId,
        'date': existing?.date.toIso8601String() ?? DateTime.now().toIso8601String(),
        'pondId': pondId ?? '',
        'fishBatchId': existing?.fishBatchId ?? '',
        'items': items,
        'totalAmount': calcTotal(),
        'status': status,
      };
      if (isEdit) {
        await dp.update('saleorders', existing.id, data);
      } else {
        await dp.create('saleorders', data);
      }
      _showSnack(isEdit ? 'Đã cập nhật đơn bán' : 'Đã thêm đơn bán');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRODUCT DIALOG
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _showProductDialog(DataProvider dp, [Product? existing]) async {
    final isEdit = existing != null;
    final skuC = TextEditingController(text: existing?.sku ?? '');
    final nameC = TextEditingController(text: existing?.name ?? '');
    final unitC = TextEditingController(text: existing?.unit ?? 'kg');
    final priceC = TextEditingController(text: existing != null ? existing.price.toString() : '');
    final stockC = TextEditingController(text: existing != null ? existing.stock.toString() : '');
    final minC = TextEditingController(text: existing != null ? existing.minStock.toString() : '');
    final convRatioC = TextEditingController(text: existing != null && existing.conversionRatio > 0 ? existing.conversionRatio.toString() : '');
    final procUnitC = TextEditingController(text: existing?.processedUnit ?? '');
    String category = existing?.category ?? 'feed';

    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, ss) => AlertDialog(
          title: Row(children: [
            const Icon(Icons.category_rounded, color: AppColors.secondary),
            const SizedBox(width: 8),
            Text(isEdit ? 'Sửa sản phẩm' : 'Thêm sản phẩm'),
          ]),
          content: SizedBox(
            width: AppSizes.dialogMaxWidth,
            child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: skuC, decoration: const InputDecoration(labelText: 'Mã SP (SKU)', prefixIcon: Icon(Icons.qr_code))),
              const SizedBox(height: 12),
              TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Tên sản phẩm', prefixIcon: Icon(Icons.label))),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Loại', prefixIcon: Icon(Icons.category)),
                items: const [
                  DropdownMenuItem(value: 'feed', child: Text('Thức ăn')),
                  DropdownMenuItem(value: 'seed', child: Text('Giống')),
                  DropdownMenuItem(value: 'chemical', child: Text('Vi sinh/Hoá chất')),
                  DropdownMenuItem(value: 'medicine', child: Text('Thuốc')),
                  DropdownMenuItem(value: 'accessory', child: Text('Phụ kiện')),
                ],
                onChanged: (v) => ss(() => category = v!),
              ),
              const SizedBox(height: 12),
              TextField(controller: unitC, decoration: const InputDecoration(labelText: 'Đơn vị', prefixIcon: Icon(Icons.straighten))),
              const SizedBox(height: 12),
              TextField(controller: priceC, decoration: const InputDecoration(labelText: 'Giá', prefixIcon: Icon(Icons.attach_money)), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]),
              const SizedBox(height: 12),
              TextField(controller: stockC, decoration: const InputDecoration(labelText: 'Tồn kho hiện tại', prefixIcon: Icon(Icons.inventory)), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]),
              const SizedBox(height: 12),
              TextField(controller: minC, decoration: const InputDecoration(labelText: 'Mức tối thiểu', prefixIcon: Icon(Icons.low_priority)), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]),
              const SizedBox(height: 16),
              const Align(alignment: Alignment.centerLeft, child: Text('Quy đổi nguyên liệu → thành phẩm', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
              const SizedBox(height: 4),
              const Text('VD: 1 gói ART ấp ra 3kg ART ủ → hệ số = 3', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: convRatioC, decoration: const InputDecoration(labelText: 'Hệ số quy đổi', prefixIcon: Icon(Icons.sync_alt), hintText: 'VD: 3'), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))])),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: procUnitC, decoration: const InputDecoration(labelText: 'ĐV thành phẩm', prefixIcon: Icon(Icons.straighten), hintText: 'VD: kg'))),
              ]),
            ]),
          ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Huỷ')),
            FilledButton.icon(
              onPressed: () {
                if (nameC.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dCtx).showSnackBar(const SnackBar(content: Text('Vui lòng nhập tên sản phẩm'), backgroundColor: Colors.red));
                  return;
                }
                Navigator.pop(dCtx, true);
              },
              icon: const Icon(Icons.check),
              label: Text(isEdit ? 'Cập nhật' : 'Thêm'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && nameC.text.trim().isNotEmpty) {
      final data = {
        'sku': skuC.text.trim(),
        'name': nameC.text.trim(),
        'category': category,
        'unit': unitC.text.trim().isNotEmpty ? unitC.text.trim() : 'kg',
        'price': double.tryParse(priceC.text) ?? 0,
        'stock': double.tryParse(stockC.text) ?? 0,
        'minStock': double.tryParse(minC.text) ?? 0,
        'conversionRatio': double.tryParse(convRatioC.text) ?? 0,
        'processedUnit': procUnitC.text.trim(),
      };
      if (isEdit) {
        await dp.update('products', existing.id, data);
      } else {
        await dp.create('products', data);
      }
      _showSnack(isEdit ? 'Đã cập nhật hàng hóa' : 'Đã thêm hàng hóa');
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// NAV ITEM
// ═════════════════════════════════════════════════════════════════════════════

class _NavItem {
  final IconData icon;
  final String label;
  final String permission;
  const _NavItem(this.icon, this.label, this.permission);
}

// ═════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

final _currencyFmt = NumberFormat('#,###', 'vi');
String _smartQty(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

class _GradientKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  const _GradientKpiCard({required this.title, required this.value, required this.icon, required this.color, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.xl),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg),
        boxShadow: [
          BoxShadow(color: color.withAlpha(50), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpace.sm),
                decoration: BoxDecoration(color: Colors.white.withAlpha(35), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: Colors.white, size: AppSizes.iconMd),
              ),
              const Spacer(),
              if (subtitle != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white.withAlpha(25), borderRadius: BorderRadius.circular(8)),
                  child: Text(subtitle!, style: AppText.tiny.copyWith(color: Colors.white70)),
                ),
            ],
          ),
          const Spacer(),
          Text(value, style: AppText.display.copyWith(color: Colors.white)),
          const SizedBox(height: AppSpace.xs),
          Text(title, style: AppText.body.copyWith(color: Colors.white.withAlpha(200))),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onAdd;
  const _SectionHeader({required this.title, this.onAdd});

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

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: AppText.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});
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

Color _statusColor(String status) {
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

// ═════════════════════════════════════════════════════════════════════════════
// 1 – BRANCH
// ═════════════════════════════════════════════════════════════════════════════

class _BranchView extends StatefulWidget {
  final DataProvider dp;
  final VoidCallback onCreate;
  final VoidCallback onCreateZone;
  final Function(Branch) onEdit;
  final Function(Branch) onDelete;
  final Function(Zone) onEditZone;
  final Function(Zone) onDeleteZone;
  final Function(String zoneId) onCreatePond;
  final Function(Pond) onEditPond;
  final Function(Pond) onDeletePond;
  const _BranchView({required this.dp, required this.onCreate, required this.onCreateZone, required this.onEdit, required this.onDelete, required this.onEditZone, required this.onDeleteZone, required this.onCreatePond, required this.onEditPond, required this.onDeletePond});
  @override
  State<_BranchView> createState() => _BranchViewState();
}

class _BranchViewState extends State<_BranchView> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DataProvider>();
    var branches = dp.branches.toList();
    if (_searchQuery.isNotEmpty) {
      branches = branches.where((b) => b.name.toLowerCase().contains(_searchQuery.toLowerCase()) || b.address.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    final hasFilter = _searchQuery.isNotEmpty;

    return Column(
      children: [
        _SectionHeader(title: 'Chi nhánh (${branches.length}) • ${dp.ponds.length} ao', onAdd: widget.onCreate),
        // ── Filter row ──
        AppFilterBar(
          children: [
            AppSearchBox(hint: 'Tìm chi nhánh...', onChanged: (v) => setState(() => _searchQuery = v)),
            OutlinedButton.icon(
              onPressed: widget.onCreateZone,
              icon: const Icon(Icons.add_circle_outline, size: 16),
              label: Text('Phân khu (${dp.zones.length})', style: const TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                foregroundColor: AppColors.secondary,
                side: BorderSide(color: AppColors.secondary.withAlpha(60)),
              ),
            ),
            if (hasFilter)
              AppClearFilterChip(onTap: () => setState(() => _searchQuery = '')),
          ],
        ),
        const SizedBox(height: 8),
        if (branches.isEmpty)
          const Expanded(child: _EmptyState(icon: Icons.business_rounded, message: 'Không tìm thấy chi nhánh'))
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: branches.length,
              itemBuilder: (_, i) {
                final b = branches[i];
                final zoneCount = dp.zonesForBranch(b.id).length;
                final branchPondCount = dp.zonesForBranch(b.id).fold<int>(0, (sum, z) => sum + dp.pondsForZone(z.id).length);
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.kpiPrimary,
                        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                      ),
                      child: const Icon(Icons.business_rounded, color: Colors.white, size: 22),
                    ),
                    title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(b.address.isNotEmpty ? b.address : 'Chưa có địa chỉ',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: AppColors.primary.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                          child: Text('$zoneCount khu • $branchPondCount ao', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 4),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 20),
                          onSelected: (v) {
                            if (v == 'edit') widget.onEdit(b);
                            if (v == 'delete') widget.onDelete(b);
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit, size: 20), title: Text('Sửa'), dense: true, contentPadding: EdgeInsets.zero)),
                            const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, color: AppColors.error, size: 20), title: Text('Xoá', style: TextStyle(color: AppColors.error)), dense: true, contentPadding: EdgeInsets.zero)),
                          ],
                        ),
                      ],
                    ),
                    children: dp.zonesForBranch(b.id).map((z) {
                      final zonePonds = dp.pondsForZone(z.id);
                      return ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 24),
                        leading: Icon(_zoneIcon(z.type), color: AppColors.secondary, size: 20),
                        title: Text(z.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text('${z.typeLabel} • ${zonePonds.length} ao', style: const TextStyle(fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => widget.onCreatePond(z.id),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withAlpha(20),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add, size: 14, color: AppColors.primary),
                                    SizedBox(width: 2),
                                    Text('Thêm ao', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, size: 18),
                              onSelected: (v) {
                                if (v == 'edit') widget.onEditZone(z);
                                if (v == 'delete') widget.onDeleteZone(z);
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit, size: 20), title: Text('Sửa'), dense: true, contentPadding: EdgeInsets.zero)),
                                const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, color: AppColors.error, size: 20), title: Text('Xoá', style: TextStyle(color: AppColors.error)), dense: true, contentPadding: EdgeInsets.zero)),
                              ],
                            ),
                          ],
                        ),
                        children: [
                          if (zonePonds.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 40, vertical: 8),
                              child: Text('Chưa có ao nào', style: TextStyle(color: AppColors.textHint, fontSize: 13, fontStyle: FontStyle.italic)),
                            )
                          else
                            ...zonePonds.map((p) {
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 40),
                                leading: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: _statusColor(p.status).withAlpha(20),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.water_rounded, color: _statusColor(p.status), size: 18),
                                ),
                                title: Row(
                                  children: [
                                    Text(p.code, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _statusColor(p.status).withAlpha(20),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(p.statusLabel, style: TextStyle(fontSize: 10, color: _statusColor(p.status), fontWeight: FontWeight.w600)),
                                    ),
                                  ],
                                ),
                                subtitle: Row(
                                  children: [
                                    Text('${p.typeLabel} • ${p.area}m²', style: const TextStyle(fontSize: 12)),
                                    if (p.currentPh != null) ...[
                                      const SizedBox(width: 8),
                                      Text('pH ${p.currentPh!.toStringAsFixed(1)}', style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500)),
                                    ],
                                    if (p.currentDo != null) ...[
                                      const SizedBox(width: 6),
                                      Text('DO ${p.currentDo!.toStringAsFixed(1)}', style: const TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w500)),
                                    ],
                                  ],
                                ),
                                trailing: PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textHint),
                                  onSelected: (v) {
                                    if (v == 'edit') widget.onEditPond(p);
                                    if (v == 'delete') widget.onDeletePond(p);
                                    if (v == 'detail') Navigator.pushNamed(context, '/pond-detail', arguments: p);
                                  },
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(value: 'detail', child: ListTile(leading: Icon(Icons.visibility, size: 20), title: Text('Xem chi tiết'), dense: true, contentPadding: EdgeInsets.zero)),
                                    const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit, size: 20), title: Text('Sửa'), dense: true, contentPadding: EdgeInsets.zero)),
                                    const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, color: AppColors.error, size: 20), title: Text('Xoá', style: TextStyle(color: AppColors.error)), dense: true, contentPadding: EdgeInsets.zero)),
                                  ],
                                ),
                              );
                            }),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
      ],
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
}

// ═════════════════════════════════════════════════════════════════════════════
// 2 – POND
// ═════════════════════════════════════════════════════════════════════════════

class _PondView extends StatefulWidget {
  final DataProvider dp;
  final VoidCallback onCreate;
  final Function(Pond) onEdit;
  final Function(Pond) onDelete;
  const _PondView({required this.dp, required this.onCreate, required this.onEdit, required this.onDelete});
  @override
  State<_PondView> createState() => _PondViewState();
}

class _PondViewState extends State<_PondView> {
  String _searchQuery = '';
  String _statusFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DataProvider>();
    var ponds = dp.ponds.toList();
    if (_statusFilter != 'all') ponds = ponds.where((p) => p.status == _statusFilter).toList();
    if (_searchQuery.isNotEmpty) {
      ponds = ponds.where((p) => p.code.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    final hasFilter = _statusFilter != 'all' || _searchQuery.isNotEmpty;

    return Column(
      children: [
        _SectionHeader(title: 'Ao nuôi (${ponds.length})', onAdd: widget.onCreate),
        // Stats row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _MiniStat('Đang nuôi', '${dp.activePonds}', AppColors.success),
              const SizedBox(width: 10),
              _MiniStat('Trống', '${dp.inactivePonds}', AppColors.textHint),
              const SizedBox(width: 10),
              _MiniStat('Bảo trì', '${dp.ponds.where((p) => p.status == 'maintenance').length}', AppColors.warning),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // ── Filter row ──
        AppFilterBar(
          children: [
            AppSearchBox(hint: 'Tìm ao...', onChanged: (v) => setState(() => _searchQuery = v)),
            AppDropMapFilter(
              value: _statusFilter,
              items: const {'all': 'Tất cả TT', 'active': 'Đang nuôi', 'inactive': 'Trống', 'maintenance': 'Bảo trì'},
              onChanged: (v) => setState(() => _statusFilter = v),
            ),
            if (hasFilter)
              AppClearFilterChip(onTap: () => setState(() { _statusFilter = 'all'; _searchQuery = ''; })),
          ],
        ),
        const SizedBox(height: 8),
        if (ponds.isEmpty)
          const Expanded(child: _EmptyState(icon: Icons.water_rounded, message: 'Không tìm thấy ao nuôi'))
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: ponds.length,
              itemBuilder: (_, i) {
                final p = ponds[i];
                final zone = p.zoneId != null ? dp.zoneById(p.zoneId!) : null;
                final batches = dp.batchesForPond(p.id);
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.pushNamed(context, '/pond-detail', arguments: p),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: _statusColor(p.status).withAlpha(20),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(Icons.water_rounded, color: _statusColor(p.status), size: 26),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(p.code, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                    const SizedBox(width: 8),
                                    _StatusChip(p.statusLabel, _statusColor(p.status)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${p.typeLabel} • ${p.area}m² • ${zone?.name ?? '—'}',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                ),
                                if (batches.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      '${batches.length} lô cá • ${batches.where((b) => b.status == 'active').length} đang nuôi',
                                      style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (p.currentPh != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _ParamBadge('pH', p.currentPh!.toStringAsFixed(1)),
                                if (p.currentDo != null) _ParamBadge('DO', p.currentDo!.toStringAsFixed(1)),
                              ],
                            ),
                          const SizedBox(width: 4),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textHint),
                            onSelected: (v) {
                              if (v == 'edit') widget.onEdit(p);
                              if (v == 'delete') widget.onDelete(p);
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit, size: 20), title: Text('Sửa'), dense: true, contentPadding: EdgeInsets.zero)),
                              const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, color: AppColors.error, size: 20), title: Text('Xoá', style: TextStyle(color: AppColors.error)), dense: true, contentPadding: EdgeInsets.zero)),
                            ],
                          ),
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

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat(this.label, this.value, this.color);
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

class _ParamBadge extends StatelessWidget {
  final String label;
  final String value;
  const _ParamBadge(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label ', style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.primary)),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 2b – SPECIES LIST
// ═════════════════════════════════════════════════════════════════════════════

class _SpeciesListView extends StatelessWidget {
  final DataProvider dp;
  final VoidCallback onCreate;
  final Function(Species) onEdit;
  final Function(Species) onDelete;
  const _SpeciesListView({required this.dp, required this.onCreate, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DataProvider>();
    final speciesList = dp.species.toList();
    return Column(
      children: [
        // ── Header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.pets_rounded, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Danh sách loài cá (${speciesList.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Thêm loài'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // ── List ──
        if (speciesList.isEmpty)
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.pets_rounded, size: 64, color: AppColors.textHint),
                  SizedBox(height: 12),
                  Text('Chưa có loài cá nào', style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                  SizedBox(height: 4),
                  Text('Nhấn "Thêm loài" để bắt đầu', style: TextStyle(color: AppColors.textHint, fontSize: 13)),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: speciesList.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final s = speciesList[index];
                final batchCount = dp.fishBatches.where((b) => b.speciesId == s.id).length;
                final activeBatchCount = dp.fishBatches.where((b) => b.speciesId == s.id && b.status == 'active').length;
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onEdit(s),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          // ── Image ──
                          Container(
                            width: 60, height: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: AppColors.primary.withAlpha(15),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: s.imageUrl.isNotEmpty
                                ? Image.network(s.imageUrl, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.pets, size: 28, color: AppColors.primary))
                                : const Icon(Icons.pets, size: 28, color: AppColors.primary),
                          ),
                          const SizedBox(width: 14),
                          // ── Info ──
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                if (s.description.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(s.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                                ],
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8, runSpacing: 4,
                                  children: [
                                    _SpeciesTag(Icons.thermostat, '${s.minTemp}-${s.maxTemp}°C'),
                                    _SpeciesTag(Icons.water_drop, 'pH ${s.requiredPh}'),
                                    _SpeciesTag(Icons.air, 'DO ≥${s.requiredDo}'),
                                    _SpeciesTag(Icons.scale, '${s.harvestableWeight.toInt()}g'),
                                    _SpeciesTag(Icons.calendar_today, '${s.growthDays}d'),
                                    _SpeciesTag(Icons.grid_view, '${s.densityPerM2}/m²'),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('$batchCount lô ($activeBatchCount đang nuôi)',
                                  style: TextStyle(fontSize: 11, color: activeBatchCount > 0 ? AppColors.success : AppColors.textHint,
                                    fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          // ── Actions ──
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                tooltip: 'Sửa',
                                onPressed: () => onEdit(s),
                                visualDensity: VisualDensity.compact,
                                color: AppColors.primary,
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18),
                                tooltip: 'Xoá',
                                onPressed: () => onDelete(s),
                                visualDensity: VisualDensity.compact,
                                color: AppColors.error,
                              ),
                            ],
                          ),
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

class _SpeciesTag extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SpeciesTag(this.icon, this.label);
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textSecondary),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 3 – BATCH
// ═════════════════════════════════════════════════════════════════════════════

class _BatchView extends StatefulWidget {
  final DataProvider dp;
  final VoidCallback onCreate;
  final VoidCallback onCreateSpecies;
  final VoidCallback onViewSpecies;
  final Function(FishBatch) onEdit;
  final Function(FishBatch) onDelete;
  final Function(Species) onEditSpecies;
  final Function(Species) onDeleteSpecies;
  final Function(FishBatch) onHarvest;
  final VoidCallback onFeeding;
  final VoidCallback onMortality;
  const _BatchView({required this.dp, required this.onCreate, required this.onCreateSpecies, required this.onViewSpecies, required this.onEdit, required this.onDelete, required this.onEditSpecies, required this.onDeleteSpecies, required this.onHarvest, required this.onFeeding, required this.onMortality});
  @override
  State<_BatchView> createState() => _BatchViewState();
}

class _BatchViewState extends State<_BatchView> {
  String _searchQuery = '';
  String _statusFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DataProvider>();
    var batches = dp.fishBatches.toList();
    if (_statusFilter != 'all') batches = batches.where((b) => b.status == _statusFilter).toList();
    if (_searchQuery.isNotEmpty) {
      batches = batches.where((b) {
        final sp = dp.speciesById(b.speciesId);
        final pondNames = b.pondIds.map((id) => dp.pondById(id)?.code ?? '').join(' ');
        return b.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               (sp?.name ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
               pondNames.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }
    final hasFilter = _statusFilter != 'all' || _searchQuery.isNotEmpty;
    final activeBatches = dp.fishBatches.where((b) => b.status == 'active').length;
    final totalQty = dp.fishBatches.fold<int>(0, (s, b) => s + b.currentQuantity);

    return Column(
      children: [
        _SectionHeader(title: 'Lô cá (${batches.length})', onAdd: widget.onCreate),
        // ── KPI row ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _MiniStat('Đang nuôi', '$activeBatches', AppColors.success),
              const SizedBox(width: 10),
              _MiniStat('Tổng cá', '$totalQty con', AppColors.primary),
              const SizedBox(width: 10),
              _MiniStat('Loài', '${dp.species.length}', AppColors.secondary),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // ── Action buttons: feeding, mortality ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: widget.onFeeding,
                icon: const Icon(Icons.restaurant, size: 16),
                label: const Text('Cho ăn'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.teal, side: const BorderSide(color: Colors.teal)),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: widget.onMortality,
                icon: const Icon(Icons.bug_report, size: 16),
                label: const Text('Hao hụt'),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: widget.onViewSpecies,
                icon: const Icon(Icons.pets, size: 16),
                label: Text('Loài (${dp.species.length})'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.secondary,
                  side: BorderSide(color: AppColors.secondary.withAlpha(60)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // ── Filter row ──
        AppFilterBar(
          children: [
            AppSearchBox(hint: 'Tìm lô cá / ao...', onChanged: (v) => setState(() => _searchQuery = v)),
            AppDropMapFilter(
              value: _statusFilter,
              items: const {'all': 'Tất cả TT', 'active': 'Đang nuôi', 'harvested': 'Đã thu', 'transferred': 'Chuyển'},
              onChanged: (v) => setState(() => _statusFilter = v),
            ),
            // Species chips
            ...dp.species.take(3).map((s) => GestureDetector(
              onTap: () => widget.onEditSpecies(s),
              onLongPress: () => widget.onDeleteSpecies(s),
              child: Chip(
                label: Text(s.name, style: const TextStyle(fontSize: 11)),
                backgroundColor: AppColors.primary.withAlpha(15),
                visualDensity: VisualDensity.compact,
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () => widget.onDeleteSpecies(s),
              ),
            )),
            if (hasFilter)
              AppClearFilterChip(onTap: () => setState(() { _statusFilter = 'all'; _searchQuery = ''; })),
          ],
        ),
        const SizedBox(height: 8),
        if (batches.isEmpty)
          const Expanded(child: _EmptyState(icon: Icons.set_meal_rounded, message: 'Không tìm thấy lô cá'))
        else
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: batches.length,
            itemBuilder: (_, i) {
              final b = batches[i];
              final sp = dp.speciesById(b.speciesId);
              final days = DateTime.now().difference(b.stockingDate).inDays;
              final pondCodes = b.pondIds.map((id) => dp.pondById(id)?.code ?? '?').join(', ');
              final displayName = b.name.isNotEmpty ? b.name : (sp?.name ?? 'Loài #${b.speciesId}');
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _statusColor(b.status).withAlpha(20),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.set_meal_rounded, color: _statusColor(b.status), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(displayName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                if (b.name.isNotEmpty && sp != null)
                                  Text(sp.name, style: const TextStyle(color: AppColors.primary, fontSize: 12)),
                                Text('Ao: $pondCodes • $days ngày nuôi',
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                              ],
                            ),
                          ),
                          _StatusChip(b.statusLabel, _statusColor(b.status)),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 20),
                            onSelected: (v) {
                              if (v == 'edit') widget.onEdit(b);
                              if (v == 'delete') widget.onDelete(b);
                              if (v == 'harvest') widget.onHarvest(b);
                            },
                            itemBuilder: (ctx) => [
                              if (b.status == 'active')
                                const PopupMenuItem(value: 'harvest', child: ListTile(leading: Icon(Icons.agriculture, color: Colors.green, size: 20), title: Text('Thu hoạch'), dense: true, contentPadding: EdgeInsets.zero)),
                              const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit, size: 20), title: Text('Sửa'), dense: true, contentPadding: EdgeInsets.zero)),
                              const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, color: AppColors.error, size: 20), title: Text('Xoá', style: TextStyle(color: AppColors.error)), dense: true, contentPadding: EdgeInsets.zero)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _InfoPill(Icons.format_list_numbered, '${b.currentQuantity} con'),
                          const SizedBox(width: 10),
                          _InfoPill(Icons.straighten, '${b.currentSize > 0 ? b.currentSize : b.initialSize} cm'),
                          const SizedBox(width: 10),
                          _InfoPill(Icons.monitor_weight_outlined, '${b.currentWeight > 0 ? b.currentWeight : b.initialWeight} g'),
                          if (b.importPrice > 0) ...[
                            const SizedBox(width: 10),
                            _InfoPill(Icons.attach_money, '${b.importPrice.round()} đ/con'),
                          ],
                        ],
                      ),
                      if (b.pondAllocations.length > 1) ...[
                        const SizedBox(height: 8),
                        Wrap(spacing: 6, runSpacing: 4, children: b.pondAllocations.map((a) {
                          final pCode = dp.pondById(a['pondId'] as String? ?? '')?.code ?? '?';
                          return Chip(
                            avatar: const Icon(Icons.water, size: 14),
                            label: Text('$pCode: ${a['quantity']} con', style: const TextStyle(fontSize: 11)),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          );
                        }).toList()),
                      ],
                    ],
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

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoPill(this.icon, this.text);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 6 – STAFF
// ═════════════════════════════════════════════════════════════════════════════

class _StaffView extends StatefulWidget {
  final DataProvider dp;
  final VoidCallback onCreate;
  final Function(Employee) onEdit;
  final Function(Employee) onDelete;
  final Function(Employee) onCreateAccount;
  final Function(Employee) onEditPermissions;
  const _StaffView({required this.dp, required this.onCreate, required this.onEdit, required this.onDelete, required this.onCreateAccount, required this.onEditPermissions});
  @override
  State<_StaffView> createState() => _StaffViewState();
}

class _StaffViewState extends State<_StaffView> {
  String _searchQuery = '';
  String _roleFilter = 'all';

  Color _roleColor(String role) {
    switch (role) {
      case 'owner': return AppColors.warning;
      case 'manager': return AppColors.primary;
      case 'technician': return AppColors.info;
      case 'worker': return AppColors.success;
      default: return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DataProvider>();
    var employees = dp.employees.toList();
    if (_roleFilter != 'all') employees = employees.where((e) => e.role == _roleFilter).toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      employees = employees.where((e) => e.name.toLowerCase().contains(q) || e.email.toLowerCase().contains(q) || e.phone.contains(_searchQuery) || e.roleLabel.toLowerCase().contains(q) || e.shift.toLowerCase().contains(q)).toList();
    }
    final hasFilter = _roleFilter != 'all' || _searchQuery.isNotEmpty;
    final withAccount = dp.employees.where((e) => e.hasAccount).length;

    return Column(
      children: [
        _SectionHeader(title: 'Nhân sự (${employees.length})', onAdd: widget.onCreate),
        // ── KPI row ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _MiniStat('Tổng NV', '${dp.employees.length}', AppColors.primary),
              const SizedBox(width: 10),
              _MiniStat('Có tài khoản', '$withAccount', AppColors.success),
              const SizedBox(width: 10),
              _MiniStat('Chưa có TK', '${dp.employees.length - withAccount}', AppColors.textHint),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // ── Filter row ──
        AppFilterBar(
          children: [
            AppSearchBox(hint: 'Tìm nhân viên...', onChanged: (v) => setState(() => _searchQuery = v)),
            AppDropMapFilter(
              value: _roleFilter,
              items: {
                'all': 'Tất cả CV',
                ...Employee.defaultRoles.map((k, v) => MapEntry(k, v)),
                ...{for (final r in dp.employees.map((e) => e.role).where((r) => !Employee.defaultRoles.containsKey(r)).toSet()) r: Employee.roleToLabel(r)},
              },
              onChanged: (v) => setState(() => _roleFilter = v),
            ),
            if (hasFilter)
              AppClearFilterChip(onTap: () => setState(() { _roleFilter = 'all'; _searchQuery = ''; })),
          ],
        ),
        const SizedBox(height: 8),
        if (employees.isEmpty)
          const Expanded(child: _EmptyState(icon: Icons.people_rounded, message: 'Không tìm thấy nhân viên'))
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: employees.length,
              itemBuilder: (_, i) {
                final e = employees[i];
                final branch = dp.branchById(e.branchId);
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: _roleColor(e.role).withAlpha(20),
                              child: Text(
                                e.name.isNotEmpty ? e.name[0].toUpperCase() : '?',
                                style: TextStyle(fontWeight: FontWeight.w700, color: _roleColor(e.role), fontSize: 18),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Expanded(child: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: _roleColor(e.role).withAlpha(15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(e.roleLabel, style: TextStyle(fontSize: 11, color: _roleColor(e.role), fontWeight: FontWeight.w600)),
                                    ),
                                  ]),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${e.shift.isNotEmpty ? 'Ca ${e.shift}' : '—'} • ${branch?.name ?? '—'}',
                                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, size: 20),
                              onSelected: (v) {
                                if (v == 'edit') widget.onEdit(e);
                                if (v == 'delete') widget.onDelete(e);
                                if (v == 'account') widget.onCreateAccount(e);
                                if (v == 'permissions') widget.onEditPermissions(e);
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit, size: 20), title: Text('Sửa thông tin'), dense: true, contentPadding: EdgeInsets.zero)),
                                if (!e.hasAccount)
                                  const PopupMenuItem(value: 'account', child: ListTile(leading: Icon(Icons.person_add, size: 20, color: AppColors.primary), title: Text('Tạo tài khoản', style: TextStyle(color: AppColors.primary)), dense: true, contentPadding: EdgeInsets.zero)),
                                if (e.hasAccount)
                                  const PopupMenuItem(value: 'permissions', child: ListTile(leading: Icon(Icons.security, size: 20, color: AppColors.info), title: Text('Phân quyền & Tài khoản', style: TextStyle(color: AppColors.info)), dense: true, contentPadding: EdgeInsets.zero)),
                                const PopupMenuDivider(),
                                const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, color: AppColors.error, size: 20), title: Text('Xoá', style: TextStyle(color: AppColors.error)), dense: true, contentPadding: EdgeInsets.zero)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(children: [
                          if (e.email.isNotEmpty) ...[
                            Icon(Icons.email_rounded, size: 14, color: AppColors.textHint),
                            const SizedBox(width: 4),
                            Text(e.email, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            const SizedBox(width: 12),
                          ],
                          if (e.phone.isNotEmpty) ...[
                            Icon(Icons.phone_rounded, size: 14, color: AppColors.textHint),
                            const SizedBox(width: 4),
                            Text(e.phone, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (e.hasAccount ? AppColors.success : AppColors.textHint).withAlpha(15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: (e.hasAccount ? AppColors.success : AppColors.textHint).withAlpha(40)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(
                                e.hasAccount ? Icons.check_circle_rounded : Icons.person_off_rounded,
                                size: 13,
                                color: e.hasAccount ? AppColors.success : AppColors.textHint,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                e.hasAccount ? 'Có tài khoản' : 'Chưa có tài khoản',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                  color: e.hasAccount ? AppColors.success : AppColors.textHint),
                              ),
                            ]),
                          ),
                        ]),
                        if (e.hasAccount && e.permissions.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: e.permissions.take(5).map((perm) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withAlpha(10),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                AppPermissions.labels[perm] ?? perm,
                                style: const TextStyle(fontSize: 10, color: AppColors.primary),
                              ),
                            )).toList(),
                          ),
                          if (e.permissions.length > 5)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('+${e.permissions.length - 5} quyền khác',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ),
                        ],
                      ],
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

// ═════════════════════════════════════════════════════════════════════════════
// 7 – TASK
// ═════════════════════════════════════════════════════════════════════════════

class _TaskView extends StatefulWidget {
  final DataProvider dp;
  final VoidCallback onCreate;
  final Function(Task) onEdit;
  final Function(Task) onDelete;
  const _TaskView({required this.dp, required this.onCreate, required this.onEdit, required this.onDelete});
  @override
  State<_TaskView> createState() => _TaskViewState();
}

class _TaskViewState extends State<_TaskView> {
  String _filter = 'all';
  String _typeFilter = 'all';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DataProvider>();
    List<dynamic> filtered = dp.tasks;
    if (_filter == 'pending') filtered = filtered.where((t) => t.status == 'pending').toList();
    if (_filter == 'done') filtered = filtered.where((t) => t.status == 'done').toList();
    if (_filter == 'overdue') filtered = filtered.where((t) => t.isOverdue).toList();
    if (_typeFilter != 'all') filtered = filtered.where((t) => t.type == _typeFilter).toList();
    if (_searchQuery.isNotEmpty) filtered = filtered.where((t) => t.title.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    final hasFilter = _filter != 'all' || _typeFilter != 'all' || _searchQuery.isNotEmpty;

    return Column(
      children: [
        _SectionHeader(title: 'Công việc (${filtered.length})', onAdd: widget.onCreate),
        // Filter row
        AppFilterBar(
          children: [
            AppFilterChip(label: 'Tất cả', active: _filter == 'all', onTap: () => setState(() => _filter = 'all')),
            AppFilterChip(label: 'Chờ xử lý', active: _filter == 'pending', onTap: () => setState(() => _filter = 'pending')),
            AppFilterChip(label: 'Hoàn thành', active: _filter == 'done', onTap: () => setState(() => _filter = 'done')),
            AppFilterChip(label: 'Quá hạn', active: _filter == 'overdue', onTap: () => setState(() => _filter = 'overdue')),
            AppSearchBox(hint: 'Tìm công việc...', onChanged: (v) => setState(() => _searchQuery = v)),
            AppDropMapFilter(
              value: _typeFilter,
              items: const {'all': 'Loại CV', 'feeding': 'Cho ăn', 'water_change': 'Thay nước', 'health_check': 'Kiểm tra SK', 'harvest': 'Thu hoạch', 'maintenance': 'Bảo trì', 'other': 'Khác'},
              onChanged: (v) => setState(() => _typeFilter = v),
            ),
            if (hasFilter)
              AppClearFilterChip(onTap: () => setState(() { _filter = 'all'; _typeFilter = 'all'; _searchQuery = ''; })),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: PaginatedListView<dynamic>(
            items: filtered,
            itemsPerPage: 20,
            emptyWidget: const _EmptyState(icon: Icons.task_alt_rounded, message: 'Không có công việc'),
            itemBuilder: (_, t, __) {
                    final emp = dp.employeeById(t.assignedTo);
                    final pond = dp.pondById(t.pondId);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (t.isOverdue ? AppColors.error : _statusColor(t.status)).withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            t.status == 'done' ? Icons.check_circle_rounded : (t.isOverdue ? Icons.warning_rounded : Icons.schedule_rounded),
                            color: t.isOverdue ? AppColors.error : _statusColor(t.status),
                            size: 20,
                          ),
                        ),
                        title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${t.typeLabel} • ${emp?.name ?? '—'} • ${pond?.code ?? '—'}\n${DateFormat('dd/MM/yyyy').format(t.dueDate)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _StatusChip(
                              t.isOverdue ? 'Quá hạn' : t.statusLabel,
                              t.isOverdue ? AppColors.error : _statusColor(t.status),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, size: 20),
                              onSelected: (v) {
                                if (v == 'edit') widget.onEdit(t);
                                if (v == 'delete') widget.onDelete(t);
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit, size: 20), title: Text('Sửa'), dense: true, contentPadding: EdgeInsets.zero)),
                                const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, color: AppColors.error, size: 20), title: Text('Xoá', style: TextStyle(color: AppColors.error)), dense: true, contentPadding: EdgeInsets.zero)),
                              ],
                            ),
                          ],
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

// ═════════════════════════════════════════════════════════════════════════════
// 9 – SALE
// ═════════════════════════════════════════════════════════════════════════════

class _SaleView extends StatefulWidget {
  final DataProvider dp;
  final VoidCallback onCreate;
  final Function(SaleOrder) onEdit;
  final Function(SaleOrder) onDelete;
  const _SaleView({required this.dp, required this.onCreate, required this.onEdit, required this.onDelete});
  @override
  State<_SaleView> createState() => _SaleViewState();
}

class _SaleViewState extends State<_SaleView> {
  String _searchQuery = '';
  String _statusFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DataProvider>();
    var orders = dp.saleOrders.toList();
    if (_statusFilter != 'all') orders = orders.where((s) => s.status == _statusFilter).toList();
    if (_searchQuery.isNotEmpty) {
      orders = orders.where((s) {
        final cust = dp.customerById(s.customerId);
        return (cust?.name ?? '').toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }
    final hasFilter = _statusFilter != 'all' || _searchQuery.isNotEmpty;
    final totalSales = orders.fold<double>(0, (s, o) => s + o.totalAmount);
    final completedCount = dp.saleOrders.where((s) => s.status == 'completed').length;
    final pendingCount = dp.saleOrders.where((s) => s.status == 'pending').length;

    return Column(
      children: [
        _SectionHeader(title: 'Bán hàng (${orders.length})', onAdd: widget.onCreate),
        // ── KPI row ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _MiniStat('Hoàn thành', '$completedCount', AppColors.success),
              const SizedBox(width: 10),
              _MiniStat('Chờ xử lý', '$pendingCount', AppColors.warning),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withAlpha(30)),
                  ),
                  child: Column(
                    children: [
                      Text('${_currencyFmt.format(totalSales)}đ', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primary)),
                      const Text('Doanh thu', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // ── Filter row ──
        AppFilterBar(
          children: [
            AppSearchBox(hint: 'Tìm khách hàng...', onChanged: (v) => setState(() => _searchQuery = v)),
            AppDropMapFilter(
              value: _statusFilter,
              items: const {'all': 'Tất cả TT', 'pending': 'Chờ xử lý', 'completed': 'Hoàn thành', 'cancelled': 'Đã huỷ'},
              onChanged: (v) => setState(() => _statusFilter = v),
            ),
            if (hasFilter)
              AppClearFilterChip(onTap: () => setState(() { _statusFilter = 'all'; _searchQuery = ''; })),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: PaginatedListView<SaleOrder>(
            items: orders,
            itemsPerPage: 20,
            emptyWidget: const _EmptyState(icon: Icons.point_of_sale_rounded, message: 'Không tìm thấy đơn bán'),
            itemBuilder: (_, s, __) {
                final cust = dp.customerById(s.customerId);
                final itemCount = s.items.length;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _statusColor(s.status).withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.receipt_rounded, color: _statusColor(s.status), size: 22),
                    ),
                    title: Text(cust?.name ?? 'KH #${s.customerId}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${DateFormat('dd/MM/yyyy').format(s.date)} • ${_currencyFmt.format(s.totalAmount)}đ • $itemCount SP',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _StatusChip(s.statusLabel, _statusColor(s.status)),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 20),
                          onSelected: (v) {
                            if (v == 'edit') widget.onEdit(s);
                            if (v == 'delete') widget.onDelete(s);
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit, size: 20), title: Text('Sửa'), dense: true, contentPadding: EdgeInsets.zero)),
                            const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, color: AppColors.error, size: 20), title: Text('Xoá', style: TextStyle(color: AppColors.error)), dense: true, contentPadding: EdgeInsets.zero)),
                          ],
                        ),
                      ],
                    ),
                    children: [
                      if (s.items.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Table(
                            columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(1), 2: FlexColumnWidth(2), 3: FlexColumnWidth(2)},
                            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                            children: [
                              const TableRow(
                                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
                                children: [
                                  Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Sản phẩm', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: AppColors.textSecondary))),
                                  Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('SL', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: AppColors.textSecondary), textAlign: TextAlign.center)),
                                  Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Đ.Giá', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: AppColors.textSecondary), textAlign: TextAlign.right)),
                                  Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('T.Tiền', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: AppColors.textSecondary), textAlign: TextAlign.right)),
                                ],
                              ),
                              ...s.items.map((item) {
                                final pName = (item['productName'] as String?) ?? dp.productById(item['productId'] as String? ?? '')?.name ?? '?';
                                final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
                                final price = (item['price'] as num?)?.toDouble() ?? 0;
                                final amount = (item['amount'] as num?)?.toDouble() ?? qty * price;
                                return TableRow(children: [
                                  Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(pName, style: const TextStyle(fontSize: 12))),
                                  Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 1), style: const TextStyle(fontSize: 12), textAlign: TextAlign.center)),
                                  Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text('${_currencyFmt.format(price)}đ', style: const TextStyle(fontSize: 12), textAlign: TextAlign.right)),
                                  Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text('${_currencyFmt.format(amount)}đ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                                ]);
                              }),
                            ],
                          ),
                        ),
                      if (s.items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('Không có chi tiết sản phẩm', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ═════════════════════════════════════════════════════════════════════════════
// HÀNG HÓA (Products)
// ═════════════════════════════════════════════════════════════════════════════

class _ProductView extends StatefulWidget {
  final DataProvider dp;
  final VoidCallback onCreate;
  final Function(Product) onEdit;
  final Function(Product) onDelete;
  const _ProductView({required this.dp, required this.onCreate, required this.onEdit, required this.onDelete});
  @override
  State<_ProductView> createState() => _ProductViewState();
}

class _ProductViewState extends State<_ProductView> {
  String _categoryFilter = 'all';
  bool _lowStockOnly = false;
  String _searchQuery = '';

  VoidCallback get onCreate => widget.onCreate;
  Function(Product) get onEdit => widget.onEdit;
  Function(Product) get onDelete => widget.onDelete;

  static IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'feed': return Icons.grass_rounded;
      case 'seed': return Icons.spa_rounded;
      case 'chemical': return Icons.science_rounded;
      case 'medicine': return Icons.medical_services_rounded;
      case 'accessory': return Icons.build_rounded;
      default: return Icons.category_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DataProvider>();
    final fmt = NumberFormat('#,###', 'vi');
    var products = dp.products.toList();
    if (_categoryFilter != 'all') products = products.where((p) => p.category == _categoryFilter).toList();
    if (_lowStockOnly) products = products.where((p) => p.isLowStock).toList();
    if (_searchQuery.isNotEmpty) products = products.where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase()) || p.sku.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    final lowStock = dp.products.where((p) => p.isLowStock).toList();
    final totalValue = dp.products.fold<double>(0, (s, p) => s + p.stock * p.price);
    final hasFilter = _categoryFilter != 'all' || _lowStockOnly || _searchQuery.isNotEmpty;

    return Column(
      children: [
        _SectionHeader(title: 'Hàng hóa (${products.length})', onAdd: onCreate),
        // ── Summary row ──
        SizedBox(
          height: 150,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              SizedBox(width: 170, child: _GradientKpiCard(icon: Icons.category_rounded, title: 'Sản phẩm', value: '${dp.products.length}', color: AppColors.kpiPrimary)),
              const SizedBox(width: 10),
              SizedBox(width: 170, child: _GradientKpiCard(icon: Icons.warning_rounded, title: 'Sắp hết', value: '${lowStock.length}', color: AppColors.kpiWarning)),
              const SizedBox(width: 10),
              SizedBox(width: 210, child: _GradientKpiCard(icon: Icons.attach_money_rounded, title: 'Giá trị kho', value: '${fmt.format(totalValue)}đ', color: AppColors.kpiPrimary)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // ── Filter row ──
        AppFilterBar(
          children: [
            AppSearchBox(hint: 'Tìm sản phẩm...', onChanged: (v) => setState(() => _searchQuery = v)),
            AppDropMapFilter(
              value: _categoryFilter,
              items: const {'all': 'Tất cả loại', 'feed': 'Thức ăn', 'seed': 'Giống', 'chemical': 'Vi sinh/HChất', 'medicine': 'Thuốc', 'accessory': 'Phụ kiện'},
              onChanged: (v) => setState(() => _categoryFilter = v),
            ),
            AppToggleChip(label: 'Sắp hết', active: _lowStockOnly, onTap: () => setState(() => _lowStockOnly = !_lowStockOnly)),
            if (hasFilter)
              AppClearFilterChip(onTap: () => setState(() { _categoryFilter = 'all'; _lowStockOnly = false; _searchQuery = ''; })),
          ],
        ),
        const SizedBox(height: 8),

        // ── Low stock warning ──
        if (lowStock.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.warning.withAlpha(15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warning.withAlpha(40)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
                  const SizedBox(width: 8),
                  Text('${lowStock.length} sản phẩm dưới mức tối thiểu',
                      style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
            ),
          ),

        // ── Product list ──
        Expanded(
          child: PaginatedListView<Product>(
            items: products,
            itemsPerPage: 20,
            emptyWidget: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.category_rounded, size: 64, color: AppColors.textHint.withAlpha(80)),
                    const SizedBox(height: 12),
                    Text(hasFilter ? 'Không tìm thấy sản phẩm phù hợp' : 'Chưa có sản phẩm', style: const TextStyle(color: AppColors.textHint)),
                  ]),
                ),
            itemBuilder: (_, p, __) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        leading: Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            color: (p.isLowStock ? AppColors.error : AppColors.secondary).withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(_categoryIcon(p.category), color: p.isLowStock ? AppColors.error : AppColors.secondary, size: 20),
                        ),
                        title: Text(p.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: p.isLowStock ? AppColors.error : null)),
                        subtitle: Text('${p.sku.isNotEmpty ? '${p.sku} • ' : ''}${p.categoryLabel} • ${fmt.format(p.price)}đ/${p.unit}', style: const TextStyle(fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${_smartQty(p.stock)} ${p.unit}',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: p.isLowStock ? AppColors.error : AppColors.textPrimary)),
                                Text(p.isLowStock ? 'Sắp hết!' : 'Min: ${_smartQty(p.minStock)}',
                                    style: TextStyle(fontSize: 11, color: p.isLowStock ? AppColors.error : AppColors.textHint)),
                              ],
                            ),
                            PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'edit') onEdit(p);
                                if (v == 'delete') onDelete(p);
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Sửa')])),
                                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: AppColors.error), SizedBox(width: 8), Text('Xoá', style: TextStyle(color: AppColors.error))])),
                              ],
                            ),
                          ],
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

// ═════════════════════════════════════════════════════════════════════════════
// 11 – SETTINGS
// ═════════════════════════════════════════════════════════════════════════════

class _SettingsView extends StatelessWidget {
  final DataProvider dp;
  final void Function(String key) onNavigate;
  final VoidCallback onProfile;
  final VoidCallback onHelp;
  void _showFactoryResetDialog(BuildContext context) {
    final confirmC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        bool loading = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
                  SizedBox(width: 8),
                  Text('Khôi phục cài đặt gốc'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('⚠️ Hành động này sẽ:', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Text('• Xóa toàn bộ chi nhánh, phân khu, ao nuôi'),
                        Text('• Xóa tất cả lô cá, loài cá'),
                        Text('• Xóa đơn hàng, khách hàng, nhà cung cấp'),
                        Text('• Xóa sản phẩm, kho hàng'),
                        Text('• Xóa nhân viên (trừ tài khoản hiện tại)'),
                        Text('• Xóa tất cả công việc, thông báo, báo cáo'),
                        SizedBox(height: 8),
                        Text('Dữ liệu không thể khôi phục sau khi xóa!',
                          style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Nhập XÓA DỮ LIỆU để xác nhận:'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmC,
                    decoration: const InputDecoration(
                      hintText: 'XÓA DỮ LIỆU',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
                  onPressed: loading ? null : () async {
                    if (confirmC.text.trim() != 'XÓA DỮ LIỆU') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vui lòng nhập đúng "XÓA DỮ LIỆU" để xác nhận'), backgroundColor: AppColors.error),
                      );
                      return;
                    }
                    setDialogState(() => loading = true);
                    final dp = context.read<DataProvider>();
                    final ok = await dp.factoryReset();
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ok ? 'Đã khôi phục cài đặt gốc thành công!' : 'Lỗi khi khôi phục cài đặt gốc'),
                          backgroundColor: ok ? AppColors.success : AppColors.error,
                        ),
                      );
                    }
                  },
                  child: loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Xóa toàn bộ dữ liệu'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  const _SettingsView({required this.dp, required this.onNavigate, required this.onProfile, required this.onHelp});

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DataProvider>();
    return ListView(
      padding: const EdgeInsets.all(AppSpace.xl),
      children: [
        Text('Cài đặt', style: AppText.headline),
        const SizedBox(height: AppSpace.xl),

        // ── Quản lý (moved modules) ──
        Text('Quản lý', style: AppText.subtitle.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: AppSpace.sm),
        Card(
          child: Column(
            children: [
              _SettingsTile(Icons.business_rounded, 'Chi nhánh & Ao nuôi', 'Quản lý chi nhánh, phân khu & ao', () => onNavigate('branch')),
              const Divider(height: 1),
              _SettingsTile(Icons.set_meal_rounded, 'Lô cá', 'Lô cá & loài cá', () => onNavigate('batch')),
              const Divider(height: 1),
              _SettingsTile(Icons.people_rounded, 'Nhân sự', 'Nhân viên, tài khoản & phân quyền', () => onNavigate('staff')),
              const Divider(height: 1),
              _SettingsTile(Icons.point_of_sale_rounded, 'Bán hàng', 'Đơn hàng & bán', () => onNavigate('sale')),
              const Divider(height: 1),
              _SettingsTile(Icons.person_pin_rounded, 'Khách hàng', 'Danh sách khách hàng', () => onNavigate('customer')),
              const Divider(height: 1),
              _SettingsTile(Icons.category_rounded, 'Hàng hóa', 'Quản lý sản phẩm & vật tư', () => onNavigate('products')),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.xl),

        // ── Thông số kỹ thuật ──
        Text('Thông số kỹ thuật', style: AppText.subtitle.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: AppSpace.sm),
        Card(
          child: Column(
            children: [
              _SettingsTile(Icons.pets_rounded, 'Loài cá', '${dp.species.length} loài cá', () => onNavigate('species')),
              const Divider(height: 1),
              _SettingsTile(Icons.water_drop_rounded, 'Thông số nước tiêu chuẩn', '${dp.waterStandards.where((w) => w.isActive).length} thông số đang bật', () => onNavigate('waterstandards')),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.xl),

        // ── Hệ thống ──
        Text('Hệ thống', style: AppText.subtitle.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: AppSpace.sm),
        Card(
          child: Column(
            children: [
              _SettingsTile(Icons.person_rounded, 'Thông tin tài khoản', 'Quản trị viên', onProfile),
              const Divider(height: 1),
              _SettingsTile(Icons.notifications_rounded, 'Thông báo', '${dp.unreadNotifications} chưa đọc', () => onNavigate('notifications')),
              const Divider(height: 1),
              _SettingsTile(Icons.storage_rounded, 'Dữ liệu', '${dp.ponds.length} ao • ${dp.employees.length} NV', () => onNavigate('data')),
              const Divider(height: 1),
              _SettingsTile(Icons.sync_rounded, 'Đồng bộ dữ liệu', 'Tải lại từ máy chủ', () => dp.loadAll()),
              const Divider(height: 1),
              Builder(builder: (ctx) {
                final themeP = ctx.watch<ThemeProvider>();
                return ListTile(
                  leading: Icon(
                    themeP.isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    color: AppColors.primary,
                  ),
                  title: const Text('Giao diện tối', style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    themeP.isDark ? 'Đang bật' : 'Đang tắt',
                    style: AppText.body.copyWith(color: AppColors.textSecondary),
                  ),
                  trailing: Switch(
                    value: themeP.isDark,
                    activeColor: AppColors.primary,
                    onChanged: (_) => themeP.toggle(),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              _SettingsTile(Icons.info_outline_rounded, 'Phiên bản', '1.0.0', () {}),
              const Divider(height: 1),
              _SettingsTile(Icons.help_outline_rounded, 'Trợ giúp', null, onHelp),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // ── Khôi phục cài đặt gốc ──
        Card(
          child: ListTile(
            leading: const Icon(Icons.restore_rounded, color: AppColors.error),
            title: const Text('Khôi phục cài đặt gốc', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
            subtitle: Text('Xóa toàn bộ dữ liệu, chỉ giữ tài khoản hiện tại', style: AppText.body.copyWith(color: AppColors.textSecondary)),
            onTap: () => _showFactoryResetDialog(context),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppColors.error),
            title: const Text('Đăng xuất', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
            onTap: () async {
              await context.read<AuthProvider>().signOut();
              context.read<DataProvider>().setToken(null);
              if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  const _SettingsTile(this.icon, this.title, this.subtitle, this.onTap);
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle != null ? Text(subtitle!, style: AppText.body.copyWith(color: AppColors.textSecondary)) : null,
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
      onTap: onTap,
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PROFILE PAGE
// ═════════════════════════════════════════════════════════════════════════════

class _ProfilePage extends StatefulWidget {
  final DataProvider dp;
  final User user;
  const _ProfilePage({required this.dp, required this.user});
  @override
  State<_ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<_ProfilePage> {
  late final TextEditingController _nameC;
  late final TextEditingController _phoneC;
  late final TextEditingController _addressC;
  late final TextEditingController _storeNameC;
  final _currentPwdC = TextEditingController();
  final _newPwdC = TextEditingController();
  final _confirmPwdC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameC = TextEditingController(text: widget.user.displayName);
    _phoneC = TextEditingController(text: widget.user.phone ?? '');
    _addressC = TextEditingController(text: widget.user.address ?? '');
    _storeNameC = TextEditingController(text: widget.user.storeName ?? '');
  }

  @override
  void dispose() {
    _nameC.dispose(); _phoneC.dispose(); _addressC.dispose(); _storeNameC.dispose();
    _currentPwdC.dispose(); _newPwdC.dispose(); _confirmPwdC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông tin tài khoản'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.xl),
        children: [
          // Avatar + role
          Center(
            child: Column(children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.primary.withAlpha(30),
                child: Text(widget.user.displayName.isNotEmpty ? widget.user.displayName[0].toUpperCase() : '?',
                  style: AppText.display.copyWith(color: AppColors.primary)),
              ),
              const SizedBox(height: AppSpace.sm),
              Text(widget.user.email, style: AppText.body.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpace.xs),
              Chip(label: Text(widget.user.roleLabel), backgroundColor: AppColors.primary.withAlpha(20)),
            ]),
          ),
          const SizedBox(height: AppSpace.xxl),

          // Info section
          Text('Thông tin cá nhân', style: AppText.title),
          const SizedBox(height: AppSpace.md),
          TextField(controller: _nameC, decoration: const InputDecoration(labelText: 'Họ tên', prefixIcon: Icon(Icons.person))),
          const SizedBox(height: 12),
          TextField(controller: _phoneC, decoration: const InputDecoration(labelText: 'Số điện thoại', prefixIcon: Icon(Icons.phone))),
          const SizedBox(height: 12),
          TextField(controller: _addressC, decoration: const InputDecoration(labelText: 'Địa chỉ', prefixIcon: Icon(Icons.location_on))),
          const SizedBox(height: 12),
          TextField(controller: _storeNameC, decoration: const InputDecoration(labelText: 'Tên cửa hàng', prefixIcon: Icon(Icons.store))),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _updateProfile,
            icon: const Icon(Icons.save),
            label: const Text('Cập nhật thông tin'),
          ),

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),

          // Change password
          Text('Đổi mật khẩu', style: AppText.title),
          const SizedBox(height: AppSpace.md),
          TextField(controller: _currentPwdC, decoration: const InputDecoration(labelText: 'Mật khẩu hiện tại', prefixIcon: Icon(Icons.lock)), obscureText: true),
          const SizedBox(height: 12),
          TextField(controller: _newPwdC, decoration: const InputDecoration(labelText: 'Mật khẩu mới', prefixIcon: Icon(Icons.lock_outline)), obscureText: true),
          const SizedBox(height: 12),
          TextField(controller: _confirmPwdC, decoration: const InputDecoration(labelText: 'Xác nhận mật khẩu mới', prefixIcon: Icon(Icons.lock_outline)), obscureText: true),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _changePassword,
            icon: const Icon(Icons.vpn_key),
            label: const Text('Đổi mật khẩu'),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
          ),
        ],
      ),
    );
  }

  Future<void> _updateProfile() async {
    final result = await widget.dp.updateProfile({
      'displayName': _nameC.text,
      'phone': _phoneC.text,
      'address': _addressC.text,
      'storeName': _storeNameC.text,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result != null ? 'Cập nhật thành công' : 'Lỗi cập nhật'),
        backgroundColor: result != null ? AppColors.success : AppColors.error,
      ));
    }
  }

  Future<void> _changePassword() async {
    if (_newPwdC.text != _confirmPwdC.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mật khẩu mới không khớp'), backgroundColor: AppColors.error),
      );
      return;
    }
    if (_newPwdC.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mật khẩu mới phải ít nhất 6 ký tự'), backgroundColor: AppColors.error),
      );
      return;
    }
    final ok = await widget.dp.changePassword(_currentPwdC.text, _newPwdC.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Đổi mật khẩu thành công' : 'Mật khẩu hiện tại không đúng'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ));
      if (ok) { _currentPwdC.clear(); _newPwdC.clear(); _confirmPwdC.clear(); }
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// HELP PAGE
// ═════════════════════════════════════════════════════════════════════════════

class _HelpPage extends StatelessWidget {
  const _HelpPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trợ giúp'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.xl),
        children: [
          Text('Hướng dẫn sử dụng AQUA Manager', style: AppText.headline),
          const SizedBox(height: AppSpace.lg),

          _helpSection('Tổng quan', 'Xem thống kê chung: ao nuôi, lô cá, công việc, doanh thu, tồn kho tại màn hình Tổng quan.'),
          _helpSection('Sơ đồ trại', 'Xem bản đồ trang trại với các ao nuôi được bố trí theo vùng và chi nhánh.'),
          _helpSection('Công việc', 'Quản lý công việc hàng ngày: tạo, giao, theo dõi tiến độ và hạn chót.'),
          _helpSection('Báo cáo', 'Xem báo cáo doanh thu, chi phí, lãi/lỗ theo lô cá, thống kê nợ nhà cung cấp.'),
          _helpSection('Kho', 'Quản lý phiếu nhập/xuất kho, kiểm kê tồn kho, theo dõi hàng tồn tối thiểu.'),
          _helpSection('Hàng hóa', 'Quản lý sản phẩm (thức ăn, thuốc, thiết bị), giá mua/bán, tồn kho.'),
          _helpSection('Thu chi', 'Quản lý phiếu thu, chi, theo dõi công nợ khách hàng và nhà cung cấp.'),
          _helpSection('Cài đặt', 'Quản lý ao nuôi, lô cá, nhân sự, bán hàng, chi nhánh, khách hàng.'),
          _helpSection('Thu hoạch', 'Ghi nhận thu hoạch từ lô cá: số lượng, trọng lượng, giá bán. Tìm trong Cài đặt > Lô cá.'),
          _helpSection('Cho ăn & Hao hụt', 'Ghi nhận cho ăn và hao hụt/bệnh trong phần Cài đặt > Lô cá.'),
          _helpSection('Xuất dữ liệu', 'Nhấn biểu tượng tải xuống ở thanh trên để xuất dữ liệu CSV.'),
          _helpSection('Tìm kiếm', 'Nhấn biểu tượng kính lúp ở thanh trên để tìm kiếm toàn hệ thống.'),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          const Text('Liên hệ hỗ trợ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Email: support@aquamanager.vn', style: TextStyle(color: AppColors.textSecondary)),
          const Text('Hotline: 1900-xxxx', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          const Text('Phiên bản: 1.0.0', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _helpSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary)),
              const SizedBox(height: 6),
              Text(content, style: const TextStyle(color: AppColors.textSecondary, height: 1.4)),
            ],
          ),
        ),
      ),
    );
  }
}

// (WaterStandardsView extracted to views/water_standards_view.dart)
// (NotificationPage extracted to views/notification_page.dart)

// ═════════════════════════════════════════════════════════════════════════════
// DATA MANAGEMENT PAGE
// ═════════════════════════════════════════════════════════════════════════════

class _DataManagementPage extends StatefulWidget {
  final DataProvider dp;
  const _DataManagementPage({required this.dp});
  @override
  State<_DataManagementPage> createState() => _DataManagementPageState();
}

class _DataManagementPageState extends State<_DataManagementPage> {
  DataProvider get dp => widget.dp;

  @override
  Widget build(BuildContext context) {
    final stats = <_DataStatItem>[
      _DataStatItem(Icons.water_rounded, 'Ao nuôi', dp.ponds.length, AppColors.primary),
      _DataStatItem(Icons.set_meal_rounded, 'Lô cá', dp.fishBatches.length, Colors.teal),
      _DataStatItem(Icons.pets_rounded, 'Loài', dp.species.length, Colors.orange),
      _DataStatItem(Icons.people_rounded, 'Nhân sự', dp.employees.length, Colors.indigo),
      _DataStatItem(Icons.task_alt_rounded, 'Công việc', dp.tasks.length, Colors.blue),
      _DataStatItem(Icons.inventory_2_rounded, 'Hàng hóa', dp.products.length, Colors.deepPurple),
      _DataStatItem(Icons.person_pin_rounded, 'Khách hàng', dp.customers.length, Colors.green),
      _DataStatItem(Icons.local_shipping_rounded, 'Nhà cung cấp', dp.suppliers.length, Colors.brown),
      _DataStatItem(Icons.receipt_long_rounded, 'Đơn bán', dp.saleOrders.length, AppColors.success),
      _DataStatItem(Icons.shopping_cart_rounded, 'Đơn mua', dp.purchaseOrders.length, Colors.cyan),
      _DataStatItem(Icons.receipt_rounded, 'Phiếu thu chi', dp.paymentVouchers.length, Colors.amber.shade700),
      _DataStatItem(Icons.sensors_rounded, 'Chỉ số MT', dp.sensorReadings.length, Colors.lightBlue),
      _DataStatItem(Icons.notifications_rounded, 'Thông báo', dp.notifications.length, Colors.pink),
    ];

    return Padding(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header
          Row(children: [
            const Icon(Icons.storage_rounded, color: AppColors.primary, size: 28),
            const SizedBox(width: 10),
            Text('Quản lý dữ liệu', style: AppText.headline),
            const Spacer(),
            FilledButton.icon(
              icon: const Icon(Icons.sync_rounded, size: 18),
              label: const Text('Đồng bộ lại'),
              onPressed: () async {
                await dp.loadAll();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã tải lại toàn bộ dữ liệu'), backgroundColor: AppColors.success),
                  );
                  setState(() {});
                }
              },
            ),
          ]),
          const SizedBox(height: AppSpace.lg),

          // ── Stats grid
          Text('Tổng quan dữ liệu', style: AppText.subtitle.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpace.sm),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                mainAxisExtent: 90,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: stats.length,
              itemBuilder: (_, i) {
                final s = stats[i];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: s.color.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(s.icon, color: s.color, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('${s.count}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: s.color)),
                          Text(s.label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis),
                        ],
                      )),
                    ]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DataStatItem {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  const _DataStatItem(this.icon, this.label, this.count, this.color);
}

/// Pond type combo: preset options + free text input
class _PondTypeAutocomplete extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String> onChanged;
  const _PondTypeAutocomplete({required this.initialValue, required this.onChanged});
  @override
  State<_PondTypeAutocomplete> createState() => _PondTypeAutocompleteState();
}

class _PondTypeAutocompleteState extends State<_PondTypeAutocomplete> {
  static const _presets = <String, String>{
    'earth': 'Ao đất',
    'hdpe': 'Ao HDPE',
    'glass': 'Bể kính',
    'cage': 'Lồng',
  };

  late final TextEditingController _ctrl;
  late String _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
    _ctrl = TextEditingController(text: _presets[_value] ?? _value);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _toKey(String display) {
    final entry = _presets.entries.where((e) => e.value == display);
    return entry.isNotEmpty ? entry.first.key : display;
  }

  @override
  Widget build(BuildContext context) {
    final allOptions = _presets.values.toList();
    return Autocomplete<String>(
      optionsBuilder: (v) {
        if (v.text.isEmpty) return allOptions;
        return allOptions.where((o) => o.toLowerCase().contains(v.text.toLowerCase()));
      },
      fieldViewBuilder: (ctx, textCtrl, focusNode, onSubmitted) {
        // Sync controller text on first build
        if (textCtrl.text.isEmpty && _ctrl.text.isNotEmpty) {
          textCtrl.text = _ctrl.text;
        }
        return TextField(
          controller: textCtrl,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Loại ao',
            prefixIcon: Icon(Icons.water),
            hintText: 'Chọn hoặc nhập loại ao mới',
          ),
          onChanged: (v) {
            _value = _toKey(v);
            widget.onChanged(_value);
          },
          onSubmitted: (_) => onSubmitted(),
        );
      },
      onSelected: (v) {
        _value = _toKey(v);
        widget.onChanged(_value);
      },
    );
  }
}
