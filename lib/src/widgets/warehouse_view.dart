import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../models/purchase_order.dart';
import '../models/stock_receipt.dart';
import '../models/stock_issue.dart';
import '../models/stock_take.dart';
import '../models/supplier.dart';
import '../models/pond.dart';
import '../providers/data_provider.dart';
import '../theme/app_theme.dart';
import '../services/export_service.dart';
import 'shared_widgets.dart';

// ═════════════════════════════════════════════════════════════════════════════
// WAREHOUSE MANAGEMENT VIEW
// Tabs: Tổng kho | Đặt hàng | Nhập kho | Xuất kho | Kiểm kê | NCC
// ═════════════════════════════════════════════════════════════════════════════

final _currFmt = NumberFormat('#,###', 'vi');

class WarehouseView extends StatefulWidget {
  final DataProvider dp;
  const WarehouseView({super.key, required this.dp});
  @override
  State<WarehouseView> createState() => _WarehouseViewState();
}

class _WarehouseViewState extends State<WarehouseView> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _captureKey = GlobalKey();
  DataProvider get dp => widget.dp;

  // Filter state
  String _prodCategory = 'all';
  String _prodSearch = '';
  bool _prodLowStock = false;
  bool _prodExpiring = false;
  String _prodSort = 'name_asc';
  String _poStatus = 'all';
  String _receiptStatus = 'all';
  String _issueStatus = 'all';
  String _stStatus = 'all';
  String _suppSearch = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Export helpers ──
  void _exportExcel() {
    final tab = _tabCtrl.index;
    switch (tab) {
      case 0: _exportProducts();
      case 1: _exportPurchaseOrders();
      case 2: _exportReceipts();
      case 3: _exportIssues();
      case 4: _exportStockTakes();
      case 5: _exportSuppliers();
    }
  }

  void _exportProducts() {
    final headers = ['Mã SKU', 'Tên', 'Danh mục', 'Thương hiệu', 'Đơn vị', 'Giá bán', 'Giá vốn', 'Tồn kho', 'Tồn tối thiểu', 'Giá trị kho', 'Trạng thái', 'Ghi chú'];
    final rows = dp.products.map((p) => [
      p.sku, p.name, p.categoryLabel, p.brand, p.unit,
      p.price, p.costPrice, p.stock, p.minStock, p.stockValue,
      p.isActive ? 'Hoạt động' : 'Ngừng', p.note,
    ]).toList();
    ExportService.exportExcelAndNotify(context: context, sheetName: 'Hàng hóa', headers: headers, rows: rows, filePrefix: 'hang_hoa');
  }

  void _exportPurchaseOrders() {
    final headers = ['Mã', 'Ngày', 'Nhà cung cấp', 'Chi nhánh', 'Tổng tiền', 'Trạng thái', 'Ghi chú'];
    final rows = dp.purchaseOrders.map((po) {
      final supp = dp.suppliers.where((s) => s.id == po.supplierId).firstOrNull;
      final br = dp.branches.where((b) => b.id == po.branchId).firstOrNull;
      return [po.code.isNotEmpty ? po.code : 'PO#${po.id.substring(0, 6)}', _dateFmt.format(po.date), supp?.name ?? po.supplier, br?.name ?? '', po.total, po.statusLabel, po.note];
    }).toList();
    ExportService.exportExcelAndNotify(context: context, sheetName: 'Đặt hàng', headers: headers, rows: rows, filePrefix: 'dat_hang');
  }

  void _exportReceipts() {
    final headers = ['Mã', 'Ngày', 'Loại', 'NCC', 'Tổng tiền', 'Trạng thái', 'Ghi chú'];
    final rows = dp.stockReceipts.map((r) {
      final supp = dp.suppliers.where((s) => s.id == r.supplierId).firstOrNull;
      return [r.code.isNotEmpty ? r.code : 'NK#${r.id.substring(0, 6)}', _dateFmt.format(r.date), r.typeLabel, supp?.name ?? '', r.totalAmount, r.statusLabel, r.note];
    }).toList();
    ExportService.exportExcelAndNotify(context: context, sheetName: 'Nhập kho', headers: headers, rows: rows, filePrefix: 'nhap_kho');
  }

  void _exportIssues() {
    final headers = ['Mã', 'Ngày', 'Loại', 'Ao', 'Tổng tiền', 'Trạng thái', 'Ghi chú'];
    final rows = dp.stockIssues.map((i) {
      final pond = dp.ponds.where((p) => p.id == i.pondId).firstOrNull;
      return [i.code.isNotEmpty ? i.code : 'XK#${i.id.substring(0, 6)}', _dateFmt.format(i.date), i.typeLabel, pond?.code ?? '', i.totalAmount, i.statusLabel, i.note];
    }).toList();
    ExportService.exportExcelAndNotify(context: context, sheetName: 'Xuất kho', headers: headers, rows: rows, filePrefix: 'xuat_kho');
  }

  void _exportStockTakes() {
    final headers = ['Mã', 'Ngày', 'Chênh lệch', 'Trạng thái', 'Ghi chú'];
    final rows = dp.stockTakes.map((s) => [
      s.code.isNotEmpty ? s.code : 'KK#${s.id.substring(0, 6)}', _dateFmt.format(s.date), s.totalDiff, s.statusLabel, s.note,
    ]).toList();
    ExportService.exportExcelAndNotify(context: context, sheetName: 'Kiểm kê', headers: headers, rows: rows, filePrefix: 'kiem_ke');
  }

  void _exportSuppliers() {
    final headers = ['Tên', 'SĐT', 'Email', 'Địa chỉ', 'Mã thuế', 'Ghi chú'];
    final rows = dp.suppliers.map((s) => [s.name, s.phone, s.email, s.address, s.taxCode, s.note]).toList();
    ExportService.exportExcelAndNotify(context: context, sheetName: 'Nhà cung cấp', headers: headers, rows: rows, filePrefix: 'nha_cung_cap');
  }

  void _exportPng() {
    ExportService.exportPngAndNotify(context: context, captureKey: _captureKey, filePrefix: 'kho');
  }

  static final _dateFmt = DateFormat('dd/MM/yyyy');

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: isError ? 3 : 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    context.watch<DataProvider>();
    final lowStock = dp.lowStockCount;
    final totalProducts = dp.products.length;
    final totalValue = dp.products.fold<double>(0, (s, p) => s + p.stockValue);
    final pendingPO = dp.purchaseOrders.where((po) => po.status == 'draft' || po.status == 'approved').length;

    return RepaintBoundary(
      key: _captureKey,
      child: Column(
      children: [
        // ── Compact header: Title + stats + Add ──
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, 0),
          child: LayoutBuilder(builder: (context, box) {
            final narrow = box.maxWidth < 600;
            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('Quản lý kho', style: AppText.title.copyWith(fontSize: 18)),
                    const Spacer(),
                    IconButton(icon: const ExcelIcon(size: 20), tooltip: 'Xuất Excel', onPressed: _exportExcel),
                    IconButton(icon: const Icon(Icons.image_outlined, size: 20), tooltip: 'Xuất PNG', onPressed: _exportPng, style: IconButton.styleFrom(foregroundColor: AppColors.secondary)),
                  ]),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      _statPill(Icons.category_rounded, '$totalProducts', AppColors.primary),
                      const SizedBox(width: 6),
                      _statPill(Icons.warning_rounded, '$lowStock', lowStock > 0 ? AppColors.error : AppColors.success),
                      const SizedBox(width: 6),
                      _statPill(Icons.attach_money_rounded, '${_currFmt.format(totalValue)}đ', AppColors.secondary),
                      if (pendingPO > 0) ...[const SizedBox(width: 6), _statPill(Icons.pending_actions_rounded, '$pendingPO PO', AppColors.warning)],
                    ]),
                  ),
                ],
              );
            }
            return Row(
            children: [
              Text('Quản lý kho', style: AppText.title.copyWith(fontSize: 18)),
              const SizedBox(width: AppSpace.lg),
              // Inline stat pills
              _statPill(Icons.category_rounded, '$totalProducts', AppColors.primary),
              const SizedBox(width: AppSpace.xs + 2),
              _statPill(Icons.warning_rounded, '$lowStock', lowStock > 0 ? AppColors.error : AppColors.success),
              const SizedBox(width: AppSpace.xs + 2),
              _statPill(Icons.attach_money_rounded, '${_currFmt.format(totalValue)}đ', AppColors.secondary),
              const SizedBox(width: AppSpace.xs + 2),
              if (pendingPO > 0) ...[
                _statPill(Icons.pending_actions_rounded, '$pendingPO PO', AppColors.warning),
                const SizedBox(width: AppSpace.xs + 2),
              ],
              const Spacer(),
              // Export buttons
              IconButton(
                icon: const ExcelIcon(size: 20),
                tooltip: 'Xuất Excel',
                onPressed: _exportExcel,
              ),
              IconButton(
                icon: const Icon(Icons.image_outlined, size: 20),
                tooltip: 'Chụp ảnh PNG',
                onPressed: _exportPng,
                style: IconButton.styleFrom(foregroundColor: AppColors.primary),
              ),
              const SizedBox(width: AppSpace.sm),
              // Tab-aware add button
              ListenableBuilder(
                listenable: _tabCtrl,
                builder: (_, __) => FilledButton.icon(
                  onPressed: _onAddForCurrentTab,
                  icon: const Icon(Icons.add_rounded, size: AppSizes.iconSm),
                  label: Text(_addLabelForTab, style: AppText.body.copyWith(fontWeight: FontWeight.w600)),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    minimumSize: Size.zero,
                  ),
                ),
              ),
            ],
          );
          }),
        ),
        const SizedBox(height: 10),
        // ── Tab bar ──
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabCtrl,
            isScrollable: true,
            padding: const EdgeInsets.all(4),
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 13),
            indicator: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4)],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            dividerHeight: 0,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(child: _tabLabel(Icons.inventory_2_rounded, 'Tổng kho')),
              Tab(child: _tabLabel(Icons.shopping_cart_rounded, 'Đặt hàng')),
              Tab(child: _tabLabel(Icons.move_to_inbox_rounded, 'Nhập kho')),
              Tab(child: _tabLabel(Icons.outbox_rounded, 'Xuất kho')),
              Tab(child: _tabLabel(Icons.fact_check_rounded, 'Kiểm kê')),
              Tab(child: _tabLabel(Icons.store_rounded, 'NCC')),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // ── Tab content ──
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildProductsTab(),
              _buildPurchaseOrdersTab(),
              _buildReceiptsTab(),
              _buildIssuesTab(),
              _buildStockTakesTab(),
              _buildSuppliersTab(),
            ],
          ),
        ),
      ],
    ),
    );
  }

  // ── Header helpers ──

  Widget _statPill(IconData icon, String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: color.withAlpha(15), borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    ]),
  );

  Widget _iconText(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: AppColors.textSecondary),
      const SizedBox(width: 3),
      Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
    ],
  );

  String get _addLabelForTab {
    switch (_tabCtrl.index) {
      case 0: return 'Hàng hóa';
      case 1: return 'Đặt hàng';
      case 2: return 'Nhập kho';
      case 3: return 'Xuất kho';
      case 4: return 'Kiểm kê';
      case 5: return 'NCC';
      default: return 'Thêm';
    }
  }

  void _onAddForCurrentTab() {
    switch (_tabCtrl.index) {
      case 0: _showProductDialog(); break;
      case 1: _showPurchaseOrderDialog(); break;
      case 2: _showReceiptDialog(); break;
      case 3: _showIssueDialog(); break;
      case 4: _showStockTakeDialog(); break;
      case 5: _showSupplierDialog(); break;
    }
  }

  Widget _tabLabel(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // FILTER BAR HELPER
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildFilterBar({required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: children),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TAB 1: TỔNG KHO (Products)
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildProductsTab() {
    var products = dp.products.toList();
    final expiringCount = dp.products.where((p) => p.isExpiringSoon || p.isExpired).length;
    final inactiveCount = dp.products.where((p) => !p.isActive).length;

    // Filters
    if (_prodCategory != 'all') products = products.where((p) => p.category == _prodCategory).toList();
    if (_prodLowStock) products = products.where((p) => p.isLowStock).toList();
    if (_prodExpiring) products = products.where((p) => p.isExpiringSoon || p.isExpired).toList();
    if (_prodSearch.isNotEmpty) {
      final q = _prodSearch.toLowerCase();
      products = products.where((p) => p.name.toLowerCase().contains(q) || p.sku.toLowerCase().contains(q) || p.brand.toLowerCase().contains(q) || p.categoryLabel.toLowerCase().contains(q)).toList();
    }

    // Sorting
    switch (_prodSort) {
      case 'name_asc': products.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())); break;
      case 'name_desc': products.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase())); break;
      case 'stock_asc': products.sort((a, b) => a.stock.compareTo(b.stock)); break;
      case 'price_desc': products.sort((a, b) => b.price.compareTo(a.price)); break;
      case 'value_desc': products.sort((a, b) => b.stockValue.compareTo(a.stockValue)); break;
      case 'newest': products.sort((a, b) => b.createdAt.compareTo(a.createdAt)); break;
    }

    final hasProdFilter = _prodCategory != 'all' || _prodLowStock || _prodExpiring || _prodSearch.isNotEmpty;
    return Column(
      children: [
        _buildFilterBar(children: [
          Text('${products.length} sản phẩm', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(width: 10),
          _SearchBox(hint: 'Tìm tên, mã, thương hiệu...', onChanged: (v) => setState(() => _prodSearch = v)),
          const SizedBox(width: 8),
          _DropFilter(value: _prodCategory, items: const {'all': 'Tất cả loại', 'feed': 'Thức ăn', 'seed': 'Giống', 'chemical': 'Vi sinh/HChất', 'medicine': 'Thuốc', 'accessory': 'Phụ kiện', 'tool': 'Dụng cụ'}, onChanged: (v) => setState(() => _prodCategory = v)),
          const SizedBox(width: 8),
          _ToggleChip(label: 'Sắp hết', active: _prodLowStock, icon: Icons.warning_amber_rounded, onTap: () => setState(() => _prodLowStock = !_prodLowStock)),
          const SizedBox(width: 8),
          if (expiringCount > 0) ...[
            _ToggleChip(label: 'Hết hạn', active: _prodExpiring, icon: Icons.timer_off_rounded, onTap: () => setState(() => _prodExpiring = !_prodExpiring)),
            const SizedBox(width: 8),
          ],
          _DropFilter(value: _prodSort, items: const {'name_asc': 'Tên A→Z', 'name_desc': 'Tên Z→A', 'stock_asc': 'Tồn thấp', 'price_desc': 'Giá cao', 'value_desc': 'Giá trị kho', 'newest': 'Mới nhất'}, onChanged: (v) => setState(() => _prodSort = v)),
          if (hasProdFilter) ...[const SizedBox(width: 8), _ClearFilterChip(onPressed: () => setState(() { _prodCategory = 'all'; _prodLowStock = false; _prodExpiring = false; _prodSearch = ''; }))],
        ]),
        // ── Alert banners ──
        if (dp.lowStockCount > 0 || expiringCount > 0 || inactiveCount > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [
              if (dp.lowStockCount > 0)
                _alertBanner(Icons.warning_amber_rounded, '${dp.lowStockCount} sản phẩm dưới mức tối thiểu', AppColors.warning),
              if (expiringCount > 0)
                _alertBanner(Icons.timer_off_rounded, '$expiringCount sản phẩm sắp/đã hết hạn', AppColors.error),
              if (inactiveCount > 0)
                _alertBanner(Icons.pause_circle_outline, '$inactiveCount sản phẩm ngừng kinh doanh', AppColors.textHint),
            ]),
          ),
        Expanded(
          child: products.isEmpty
              ? _EmptyMsg(icon: Icons.inventory_2_rounded, msg: hasProdFilter ? 'Không tìm thấy hàng hóa' : 'Chưa có hàng hóa')
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: products.length,
                  itemBuilder: (_, i) {
                    final p = products[i];
                    final supplier = p.supplierId.isNotEmpty ? dp.supplierById(p.supplierId) : null;
                    final cardColor = p.isExpired ? AppColors.error : p.isLowStock ? AppColors.warning : !p.isActive ? AppColors.textHint : AppColors.secondary;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _showProductDetail(p),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Row 1: Icon + Name + SKU + Menu
                              Row(children: [
                                Container(
                                  width: 42, height: 42,
                                  decoration: BoxDecoration(color: cardColor.withAlpha(20), borderRadius: BorderRadius.circular(10)),
                                  child: Icon(_categoryIcon(p.category), color: cardColor, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [
                                    Flexible(child: Text(p.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: !p.isActive ? AppColors.textHint : null), overflow: TextOverflow.ellipsis)),
                                    if (!p.isActive) ...[const SizedBox(width: 6), const _StatusBadge('Ngừng KD', AppColors.textHint)],
                                  ]),
                                  Row(children: [
                                    if (p.sku.isNotEmpty) ...[Text(p.sku, style: const TextStyle(fontSize: 11, color: AppColors.textHint)), const SizedBox(width: 6)],
                                    _StatusBadge(p.categoryLabel, cardColor),
                                    if (p.brand.isNotEmpty) ...[const SizedBox(width: 6), Text(p.brand, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))],
                                  ]),
                                ])),
                                _moreMenu(
                                  onEdit: () => _showProductDialog(p),
                                  onDelete: () => _confirmDelete('products', p.id, p.name),
                                ),
                              ]),
                              const Divider(height: 14),
                              // Row 2: Price + Stock + Expiry
                              Row(children: [
                                _infoChip(Icons.sell_outlined, '${_currFmt.format(p.price)}đ/${p.unit}', AppColors.primary),
                                const SizedBox(width: 8),
                                if (p.costPrice > 0) ...[
                                  _infoChip(Icons.price_change_outlined, 'Nhập ${_currFmt.format(p.costPrice)}đ', AppColors.textSecondary),
                                  const SizedBox(width: 8),
                                ],
                                const Spacer(),
                                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                  Text('${p.stock.toStringAsFixed(p.stock == p.stock.roundToDouble() ? 0 : 1)} ${p.unit}',
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: p.stock <= 0 ? AppColors.error : (p.isLowStock ? AppColors.warning : AppColors.textPrimary))),
                                  Text(p.stock <= 0 ? 'Hết hàng!' : (p.isLowStock ? 'Sắp hết! (min: ${p.minStock.toStringAsFixed(0)})' : 'Tồn kho'),
                                      style: TextStyle(fontSize: 11, color: p.stock <= 0 ? AppColors.error : (p.isLowStock ? AppColors.warning : AppColors.textHint))),
                                ]),
                              ]),
                              // Row 3: Extra info tags
                              if (p.expiryDate != null || supplier != null || p.location.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Wrap(spacing: 8, runSpacing: 4, children: [
                                  if (p.expiryDate != null)
                                    _infoChip(
                                      p.isExpired ? Icons.dangerous_rounded : p.isExpiringSoon ? Icons.timer_outlined : Icons.event_available,
                                      'HSD: ${_dateFmt.format(p.expiryDate!)}',
                                      p.isExpired ? AppColors.error : p.isExpiringSoon ? AppColors.warning : AppColors.success,
                                    ),
                                  if (supplier != null) _infoChip(Icons.store_rounded, supplier.name, AppColors.info),
                                  if (p.location.isNotEmpty) _infoChip(Icons.location_on_rounded, p.location, AppColors.textSecondary),
                                ]),
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

  Widget _alertBanner(IconData icon, String msg, Color color) => Container(
    padding: const EdgeInsets.all(10),
    margin: const EdgeInsets.only(bottom: 6),
    decoration: BoxDecoration(color: color.withAlpha(15), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withAlpha(40))),
    child: Row(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 8),
      Text(msg, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
    ]),
  );

  Widget _infoChip(IconData icon, String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: color.withAlpha(12), borderRadius: BorderRadius.circular(6)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color)),
    ]),
  );

  void _showProductDetail(Product p) {
    final supplier = p.supplierId.isNotEmpty ? dp.supplierById(p.supplierId) : null;
    // Count purchase orders containing this product
    final poCount = dp.purchaseOrders.where((po) => po.items.any((item) => item['productId'] == p.id)).length;

    // ── Build stock card (thẻ kho) ──
    // Gather all stock movements: receipts (in) + issues (out)
    final movements = <Map<String, dynamic>>[];
    for (final r in dp.stockReceipts.where((r) => r.status == 'approved')) {
      for (final item in r.items) {
        if ((item['productId'] as String?) == p.id) {
          final qty = (item['receivedQty'] as num?)?.toDouble() ?? (item['qty'] as num?)?.toDouble() ?? 0;
          movements.add({
            'date': r.date,
            'code': r.code,
            'type': 'in',
            'label': 'Nhập kho',
            'qty': qty,
            'note': r.note,
          });
        }
      }
    }
    for (final si in dp.stockIssues.where((si) => si.status == 'approved')) {
      for (final item in si.items) {
        if ((item['productId'] as String?) == p.id) {
          final qty = ((item['qty'] as num?) ?? 0).toDouble();
          movements.add({
            'date': si.date,
            'code': si.code,
            'type': 'out',
            'label': si.typeLabel,
            'qty': qty,
            'note': si.note,
          });
        }
      }
    }
    // Sort by date ascending to compute running balance
    movements.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    double runningBalance = 0;
    for (final m in movements) {
      if (m['type'] == 'in') {
        runningBalance += (m['qty'] as double);
      } else {
        runningBalance -= (m['qty'] as double);
      }
      m['balance'] = runningBalance;
    }
    // Reverse to show newest first
    final movementsDesc = movements.reversed.toList();

    showDialog(
      context: context,
      builder: (dCtx) {
        int tabIndex = 0;
        return StatefulBuilder(builder: (dCtx, ss) => AlertDialog(
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.secondary.withAlpha(20), borderRadius: BorderRadius.circular(10)),
              child: Icon(_categoryIcon(p.category), color: AppColors.secondary, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, style: const TextStyle(fontSize: 16)),
              if (p.sku.isNotEmpty) Text('SKU: ${p.sku}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w400)),
            ])),
            _StatusBadge(p.categoryLabel, AppColors.secondary),
          ]),
          content: SizedBox(
            width: 600,
            height: 500,
            child: Column(children: [
              // Tab bar
              Row(children: [
                _tabBtn('Thông tin', 0, tabIndex, (i) => ss(() => tabIndex = i)),
                const SizedBox(width: 8),
                _tabBtn('Thẻ kho (${movements.length})', 1, tabIndex, (i) => ss(() => tabIndex = i)),
              ]),
              const Divider(height: 16),
              // Tab content
              Expanded(child: tabIndex == 0
                ? SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // ── Status badges ──
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      if (!p.isActive) _detailBadge('Ngừng KD', AppColors.textHint),
                      if (p.stock <= 0) _detailBadge('Hết hàng', AppColors.error)
                      else if (p.isLowStock) _detailBadge('Sắp hết hàng', AppColors.warning),
                      if (p.isOverStock) _detailBadge('Vượt tồn tối đa', AppColors.warning),
                      if (p.isExpired) _detailBadge('Đã hết hạn!', AppColors.error),
                      if (p.isExpiringSoon) _detailBadge('Sắp hết hạn', AppColors.warning),
                      if (p.isActive && p.stock > 0 && !p.isLowStock && !p.isExpired) _detailBadge('Bình thường', AppColors.success),
                    ]),
                    const SizedBox(height: 12),

                    // ── Stats cards ──
                    Row(children: [
                      Expanded(child: _detailStatCard('Tồn kho', '${p.stock.toStringAsFixed(p.stock == p.stock.roundToDouble() ? 0 : 1)} ${p.unit}', AppColors.primary)),
                      const SizedBox(width: 8),
                      Expanded(child: _detailStatCard('Giá trị kho', '${_currFmt.format(p.stockValue)}đ', AppColors.secondary)),
                      const SizedBox(width: 8),
                      Expanded(child: _detailStatCard('Lợi nhuận/SP', p.costPrice > 0 ? '${_currFmt.format(p.profit)}đ' : '—', p.profit > 0 ? AppColors.success : AppColors.textHint)),
                    ]),
                    const SizedBox(height: 16),

                    // ── Information ──
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(10)),
                      child: Column(children: [
                        _detailRow(Icons.sell_outlined, 'Giá bán', '${_currFmt.format(p.price)}đ / ${p.unit}'),
                        if (p.costPrice > 0) _detailRow(Icons.price_change_outlined, 'Giá nhập', '${_currFmt.format(p.costPrice)}đ / ${p.unit}'),
                        if (p.brand.isNotEmpty) _detailRow(Icons.business_center_outlined, 'Thương hiệu', p.brand),
                        if (p.origin.isNotEmpty) _detailRow(Icons.public, 'Xuất xứ', p.origin),
                        _detailRow(Icons.trending_down, 'Tồn tối thiểu', p.minStock > 0 ? '${p.minStock.toStringAsFixed(0)} ${p.unit}' : 'Chưa đặt'),
                        if (p.maxStock > 0) _detailRow(Icons.trending_up, 'Tồn tối đa', '${p.maxStock.toStringAsFixed(0)} ${p.unit}'),
                        if (p.expiryDate != null) _detailRow(Icons.timer_outlined, 'Hạn sử dụng', _dateFmt.format(p.expiryDate!)),
                        if (supplier != null) _detailRow(Icons.store_rounded, 'Nhà cung cấp', supplier.name),
                        if (p.location.isNotEmpty) _detailRow(Icons.location_on_rounded, 'Vị trí kho', p.location),
                        _detailRow(Icons.calendar_today_rounded, 'Ngày tạo', _dateFmt.format(p.createdAt)),
                        _detailRow(Icons.shopping_cart_rounded, 'Phiếu nhập liên quan', '$poCount phiếu'),
                      ]),
                    ),
                    if (p.description.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('Mô tả', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(p.description, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    ],
                    if (p.note.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('Ghi chú', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(p.note, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ]))
                // ── TAB: THẺ KHO (Stock Card) ──
                : movementsDesc.isEmpty
                  ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.receipt_long_rounded, size: 48, color: AppColors.textHint),
                      SizedBox(height: 8),
                      Text('Chưa có phiếu nhập/xuất nào', style: TextStyle(color: AppColors.textHint)),
                    ]))
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Summary row
                      Row(children: [
                        Expanded(child: _detailStatCard('Tổng nhập', '${movements.where((m) => m['type'] == 'in').fold(0.0, (s, m) => s + (m['qty'] as double)).toStringAsFixed(1)} ${p.unit}', AppColors.success)),
                        const SizedBox(width: 8),
                        Expanded(child: _detailStatCard('Tổng xuất', '${movements.where((m) => m['type'] == 'out').fold(0.0, (s, m) => s + (m['qty'] as double)).toStringAsFixed(1)} ${p.unit}', AppColors.warning)),
                        const SizedBox(width: 8),
                        Expanded(child: _detailStatCard('Tồn hiện tại', '${p.stock.toStringAsFixed(p.stock == p.stock.roundToDouble() ? 0 : 1)} ${p.unit}', AppColors.primary)),
                      ]),
                      const SizedBox(height: 12),
                      // Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: const BorderRadius.vertical(top: Radius.circular(8))),
                        child: const Row(children: [
                          SizedBox(width: 80, child: Text('Ngày', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                          SizedBox(width: 70, child: Text('Mã phiếu', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                          Expanded(child: Text('Loại', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                          SizedBox(width: 55, child: Text('Nhập', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary), textAlign: TextAlign.right)),
                          SizedBox(width: 55, child: Text('Xuất', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary), textAlign: TextAlign.right)),
                          SizedBox(width: 60, child: Text('Tồn', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary), textAlign: TextAlign.right)),
                        ]),
                      ),
                      // Movement list
                      Expanded(
                        child: ListView.builder(
                          itemCount: movementsDesc.length,
                          itemBuilder: (_, i) {
                            final m = movementsDesc[i];
                            final isIn = m['type'] == 'in';
                            final date = m['date'] as DateTime;
                            final balance = (m['balance'] as double);
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: AppColors.border.withAlpha(80))),
                                color: isIn ? AppColors.success.withAlpha(8) : AppColors.warning.withAlpha(8),
                              ),
                              child: Row(children: [
                                SizedBox(width: 80, child: Text(_dateFmt.format(date), style: const TextStyle(fontSize: 12))),
                                SizedBox(width: 70, child: Text(m['code'] as String, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary))),
                                Expanded(child: Text(m['label'] as String, style: const TextStyle(fontSize: 12))),
                                SizedBox(width: 55, child: Text(isIn ? '+${(m['qty'] as double).toStringAsFixed(1)}' : '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success), textAlign: TextAlign.right)),
                                SizedBox(width: 55, child: Text(!isIn ? '-${(m['qty'] as double).toStringAsFixed(1)}' : '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warning), textAlign: TextAlign.right)),
                                SizedBox(width: 60, child: Text(balance.toStringAsFixed(1), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
                              ]),
                            );
                          },
                        ),
                      ),
                    ]),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () { Navigator.pop(dCtx); _showProductDialog(p); }, child: const Text('Sửa')),
            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Đóng')),
          ],
        ));
      },
    );
  }

  Widget _tabBtn(String label, int index, int current, ValueChanged<int> onTap) {
    final isActive = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? AppColors.primary : AppColors.border),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isActive ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Icon(icon, size: 16, color: AppColors.textHint),
      const SizedBox(width: 8),
      SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
    ]),
  );

  Widget _detailStatCard(String label, String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
    decoration: BoxDecoration(color: color.withAlpha(12), borderRadius: BorderRadius.circular(10)),
    child: Column(children: [
      Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color), textAlign: TextAlign.center),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
    ]),
  );

  Widget _detailBadge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withAlpha(15), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withAlpha(40))),
    child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
  );

  // ═══════════════════════════════════════════════════════════════════════
  // TAB 2: ĐẶT HÀNG (Purchase Orders)
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildPurchaseOrdersTab() {
    var orders = dp.purchaseOrders.toList();
    if (_poStatus != 'all') orders = orders.where((o) => o.status == _poStatus).toList();
    orders.sort((a, b) => b.date.compareTo(a.date));
    return Column(
      children: [
        _buildFilterBar(children: [
          Text('${orders.length} phiếu', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(width: 10),
          _DropFilter(value: _poStatus, items: const {'all': 'Trạng thái', 'draft': 'Nháp', 'sent': 'Đã gửi NCC', 'waiting_receipt': 'Chờ nhập kho', 'completed': 'Đã nhập kho', 'cancelled': 'Đã huỷ'}, onChanged: (v) => setState(() => _poStatus = v)),
          if (_poStatus != 'all') ...[const SizedBox(width: 8), _ClearFilterChip(onPressed: () => setState(() => _poStatus = 'all'))],
        ]),
        Expanded(
          child: orders.isEmpty
              ? _EmptyMsg(icon: Icons.shopping_cart_rounded, msg: _poStatus != 'all' ? 'Không có phiếu phù hợp' : 'Chưa có phiếu đặt hàng')
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: orders.length,
                  itemBuilder: (_, i) {
                    final po = orders[i];
                    final branch = dp.branchById(po.branchId);
                    final supplier = po.supplierId.isNotEmpty ? dp.supplierById(po.supplierId) : null;
                    final supplierName = supplier?.name ?? po.supplier;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _showPODetail(po),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: _statusColor(po.status).withAlpha(20), borderRadius: BorderRadius.circular(10)),
                                    child: Icon(Icons.receipt_long_rounded, color: _statusColor(po.status), size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(po.code.isNotEmpty ? po.code : 'PO #${po.id.substring(0, 6)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                        Text('$supplierName • ${branch?.name ?? '—'}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  _StatusChip(po.statusLabel, _statusColor(po.status)),
                                  _moreMenu(
                                    onEdit: po.status == 'draft' ? () => _showPurchaseOrderDialog(po) : null,
                                    onDelete: po.status == 'draft' ? () => _confirmDelete('purchaseorders', po.id, po.code.isNotEmpty ? po.code : supplierName) : null,
                                    extra: [
                                      if (po.status == 'draft')
                                        PopupMenuItem(
                                          value: 'send',
                                          onTap: () => _sendPO(po),
                                          child: const ListTile(leading: Icon(Icons.send_rounded, size: 20, color: Color(0xFF2563EB)), title: Text('Gửi đơn cho NCC'), dense: true, contentPadding: EdgeInsets.zero),
                                        ),
                                      if (po.status == 'sent')
                                        PopupMenuItem(
                                          value: 'receipt',
                                          onTap: () => _createReceiptFromPO(po),
                                          child: const ListTile(leading: Icon(Icons.move_to_inbox_rounded, size: 20, color: AppColors.success), title: Text('Tạo phiếu nhập'), dense: true, contentPadding: EdgeInsets.zero),
                                        ),
                                      if (po.status != 'cancelled' && po.status != 'completed')
                                        PopupMenuItem(
                                          value: 'cancel',
                                          onTap: () async {
                                            await dp.update('purchaseorders', po.id, {...po.toJson(), 'status': 'cancelled'});
                                            _snack('Đã huỷ ${po.code}');
                                            setState(() {});
                                          },
                                          child: const ListTile(leading: Icon(Icons.cancel_rounded, size: 20, color: AppColors.error), title: Text('Huỷ đơn'), dense: true, contentPadding: EdgeInsets.zero),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Items summary
                              ...po.items.take(3).map((item) => Padding(
                                padding: const EdgeInsets.only(left: 46, bottom: 2),
                                child: Text(
                                  '${item['productName'] ?? 'SP'} × ${item['qty']} ${item['unit'] ?? ''} — ${_currFmt.format(((item['qty'] as num?) ?? 0) * ((item['unitPrice'] as num?) ?? 0))}đ',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              )),
                              if (po.items.length > 3)
                                Padding(
                                  padding: const EdgeInsets.only(left: 46),
                                  child: Text('+${po.items.length - 3} sản phẩm khác', style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                                ),
                              // Total + date
                              Padding(
                                padding: const EdgeInsets.only(left: 46, top: 4),
                                child: Row(
                                  children: [
                                    Text(_dateFmt.format(po.date), style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
                                    const Spacer(),
                                    Text('${_currFmt.format(po.total)}đ', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.primary)),
                                  ],
                                ),
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

  // ═══════════════════════════════════════════════════════════════════════
  // TAB 3: NHẬP KHO (Stock Receipts)
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildReceiptsTab() {
    var receipts = dp.stockReceipts.toList();
    if (_receiptStatus != 'all') receipts = receipts.where((r) => r.status == _receiptStatus).toList();
    receipts.sort((a, b) => b.date.compareTo(a.date));
    return Column(
      children: [
        _buildFilterBar(children: [
          Text('${receipts.length} phiếu', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(width: 10),
          _DropFilter(value: _receiptStatus, items: const {'all': 'Trạng thái', 'draft': 'Nháp', 'approved': 'Đã nhập kho', 'cancelled': 'Đã huỷ'}, onChanged: (v) => setState(() => _receiptStatus = v)),
          if (_receiptStatus != 'all') ...[const SizedBox(width: 8), _ClearFilterChip(onPressed: () => setState(() => _receiptStatus = 'all'))],
        ]),
        Expanded(
          child: receipts.isEmpty
              ? _EmptyMsg(icon: Icons.move_to_inbox_rounded, msg: _receiptStatus != 'all' ? 'Không có phiếu phù hợp' : 'Chưa có phiếu nhập kho')
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: receipts.length,
                  itemBuilder: (_, i) {
                    final r = receipts[i];
                    final supplier = r.supplierId.isNotEmpty ? dp.supplierById(r.supplierId) : null;
                    return GestureDetector(
                      onTap: () => _showDocSheet(
                        title: r.code.isNotEmpty ? r.code : 'NK #${r.id.substring(0, 6)}',
                        statusLabel: r.statusLabel, statusColor: _statusColor(r.status),
                        info: [('Loại', r.typeLabel), ('NCC', supplier?.name ?? '—'), ('Ngày', _dateFmt.format(r.date)), if (r.note.isNotEmpty) ('Ghi chú', r.note)],
                        items: r.items, qtyKey: 'receivedQty', total: r.totalAmount, totalColor: AppColors.success,
                      ),
                      child: Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: AppColors.success.withAlpha(20), borderRadius: BorderRadius.circular(10)),
                                  child: const Icon(Icons.move_to_inbox_rounded, color: AppColors.success, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(r.code.isNotEmpty ? r.code : 'NK #${r.id.substring(0, 6)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                      Text('${r.typeLabel} • ${supplier?.name ?? '—'}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                                _StatusChip(r.statusLabel, _statusColor(r.status)),
                                _moreMenu(
                                  onEdit: r.status == 'draft' ? () => _showReceiptDialog(r) : null,
                                  onDelete: r.status != 'approved' ? () => _confirmDelete('stockreceipts', r.id, r.code) : null,
                                  extra: [
                                    if (r.status == 'draft')
                                      PopupMenuItem(
                                        value: 'approve',
                                        onTap: () => _approveReceipt(r),
                                        child: const ListTile(leading: Icon(Icons.check_circle, size: 20, color: AppColors.success), title: Text('Duyệt nhập kho'), dense: true, contentPadding: EdgeInsets.zero),
                                      ),
                                    if (r.status == 'approved')
                                      PopupMenuItem(
                                        value: 'unapprove',
                                        onTap: () => _unapproveReceipt(r),
                                        child: const ListTile(leading: Icon(Icons.undo_rounded, size: 20, color: AppColors.warning), title: Text('Hoàn duyệt'), dense: true, contentPadding: EdgeInsets.zero),
                                      ),
                                    if (r.status == 'approved')
                                      PopupMenuItem(
                                        value: 'delete',
                                        onTap: () => _confirmDeleteApproved('stockreceipts', r.id, r.code, 'nhập kho'),
                                        child: const ListTile(leading: Icon(Icons.delete_forever, size: 20, color: AppColors.error), title: Text('Xoá phiếu', style: TextStyle(color: AppColors.error)), dense: true, contentPadding: EdgeInsets.zero),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ...r.items.take(3).map((item) => Padding(
                              padding: const EdgeInsets.only(left: 46, bottom: 2),
                              child: Text(
                                '${item['productName'] ?? 'SP'} × ${item['receivedQty'] ?? item['qty']} ${item['unit'] ?? ''}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            )),
                            Padding(
                              padding: const EdgeInsets.only(left: 46, top: 4),
                              child: Row(
                                children: [
                                  Text(_dateFmt.format(r.date), style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
                                  const Spacer(),
                                  Text('${_currFmt.format(r.totalAmount)}đ', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.success)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ));
                  },
                ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TAB 4: XUẤT KHO (Stock Issues)
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildIssuesTab() {
    var issues = dp.stockIssues.toList();
    if (_issueStatus != 'all') issues = issues.where((si) => si.status == _issueStatus).toList();
    issues.sort((a, b) => b.date.compareTo(a.date));
    return Column(
      children: [
        _buildFilterBar(children: [
          Text('${issues.length} phiếu', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(width: 10),
          _DropFilter(value: _issueStatus, items: const {'all': 'Trạng thái', 'draft': 'Nháp', 'approved': 'Đã duyệt'}, onChanged: (v) => setState(() => _issueStatus = v)),
          if (_issueStatus != 'all') ...[const SizedBox(width: 8), _ClearFilterChip(onPressed: () => setState(() => _issueStatus = 'all'))],
        ]),
        Expanded(
          child: issues.isEmpty
              ? _EmptyMsg(icon: Icons.outbox_rounded, msg: _issueStatus != 'all' ? 'Không có phiếu phù hợp' : 'Chưa có phiếu xuất kho')
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: issues.length,
                  itemBuilder: (_, i) {
                    final si = issues[i];
                    final pond = si.pondId.isNotEmpty ? dp.pondById(si.pondId) : null;
                    return GestureDetector(
                      onTap: () => _showDocSheet(
                        title: si.code.isNotEmpty ? si.code : 'XK #${si.id.substring(0, 6)}',
                        statusLabel: si.statusLabel, statusColor: _statusColor(si.status),
                        info: [('Loại', si.typeLabel), if (pond != null) ('Ao', pond.code), ('Ngày', _dateFmt.format(si.date)), if (si.note.isNotEmpty) ('Ghi chú', si.note)],
                        items: si.items, total: si.totalAmount, totalColor: AppColors.warning,
                      ),
                      child: Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: AppColors.warning.withAlpha(20), borderRadius: BorderRadius.circular(10)),
                                  child: const Icon(Icons.outbox_rounded, color: AppColors.warning, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(si.code.isNotEmpty ? si.code : 'XK #${si.id.substring(0, 6)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                      Text('${si.typeLabel}${pond != null ? ' • ${pond.code}' : ''}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                                _StatusChip(si.statusLabel, _statusColor(si.status)),
                                _moreMenu(
                                  onEdit: si.status == 'draft' ? () => _showIssueDialog(si) : null,
                                  onDelete: si.status != 'approved' ? () => _confirmDelete('stockissues', si.id, si.code) : null,
                                  extra: [
                                    if (si.status == 'draft')
                                      PopupMenuItem(
                                        value: 'approve',
                                        onTap: () => _approveIssue(si),
                                        child: const ListTile(leading: Icon(Icons.check_circle, size: 20, color: AppColors.warning), title: Text('Duyệt xuất kho'), dense: true, contentPadding: EdgeInsets.zero),
                                      ),
                                    if (si.status == 'approved')
                                      PopupMenuItem(
                                        value: 'unapprove',
                                        onTap: () => _unapproveIssue(si),
                                        child: const ListTile(leading: Icon(Icons.undo_rounded, size: 20, color: AppColors.warning), title: Text('Hoàn duyệt'), dense: true, contentPadding: EdgeInsets.zero),
                                      ),
                                    if (si.status == 'approved')
                                      PopupMenuItem(
                                        value: 'delete',
                                        onTap: () => _confirmDeleteApproved('stockissues', si.id, si.code, 'xuất kho'),
                                        child: const ListTile(leading: Icon(Icons.delete_forever, size: 20, color: AppColors.error), title: Text('Xoá phiếu', style: TextStyle(color: AppColors.error)), dense: true, contentPadding: EdgeInsets.zero),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ...si.items.take(3).map((item) => Padding(
                              padding: const EdgeInsets.only(left: 46, bottom: 2),
                              child: Text(
                                '${item['productName'] ?? 'SP'} × ${item['qty']} ${item['unit'] ?? ''}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            )),
                            Padding(
                              padding: const EdgeInsets.only(left: 46, top: 4),
                              child: Row(
                                children: [
                                  Text(_dateFmt.format(si.date), style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
                                  const Spacer(),
                                  Text('${_currFmt.format(si.totalAmount)}đ', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.warning)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ));
                  },
                ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TAB 5: KIỂM KÊ (StockTakes)
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildStockTakesTab() {
    var takes = dp.stockTakes.toList();
    if (_stStatus != 'all') takes = takes.where((st) => st.status == _stStatus).toList();
    takes.sort((a, b) => b.date.compareTo(a.date));
    return Column(
      children: [
        _buildFilterBar(children: [
          Text('${takes.length} phiếu', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(width: 10),
          _DropFilter(value: _stStatus, items: const {'all': 'Trạng thái', 'draft': 'Nháp', 'approved': 'Đã duyệt'}, onChanged: (v) => setState(() => _stStatus = v)),
          if (_stStatus != 'all') ...[const SizedBox(width: 8), _ClearFilterChip(onPressed: () => setState(() => _stStatus = 'all'))],
        ]),
        Expanded(
          child: takes.isEmpty
              ? _EmptyMsg(icon: Icons.fact_check_rounded, msg: _stStatus != 'all' ? 'Không có phiếu phù hợp' : 'Chưa có phiếu kiểm kê')
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: takes.length,
                  itemBuilder: (_, i) {
                    final st = takes[i];
                    return GestureDetector(
                      onTap: () => _showDocSheet(
                        title: st.code.isNotEmpty ? st.code : 'KK #${st.id.substring(0, 6)}',
                        statusLabel: st.statusLabel, statusColor: _statusColor(st.status),
                        info: [('Ngày', _dateFmt.format(st.date)), ('Sản phẩm', '${st.items.length}'), ('Chênh lệch', '${st.totalDiff}'), if (st.note.isNotEmpty) ('Ghi chú', st.note)],
                        items: st.items, qtyKey: 'actualQty', showDiff: true,
                      ),
                      child: Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: AppColors.info.withAlpha(20), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.fact_check_rounded, color: AppColors.info, size: 20),
                        ),
                        title: Text(st.code.isNotEmpty ? st.code : 'KK #${st.id.substring(0, 6)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        subtitle: Text('${_dateFmt.format(st.date)} • ${st.items.length} sản phẩm • Chênh lệch: ${st.totalDiff}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _StatusChip(st.statusLabel, _statusColor(st.status)),
                            _moreMenu(
                              onEdit: st.status == 'draft' ? () => _showStockTakeDialog(st) : null,
                              onDelete: st.status != 'approved' ? () => _confirmDelete('stocktakes', st.id, st.code) : null,
                              extra: [
                                if (st.status == 'draft')
                                  PopupMenuItem(
                                    value: 'approve',
                                    onTap: () => _approveStockTake(st),
                                    child: const ListTile(leading: Icon(Icons.check_circle, size: 20, color: AppColors.info), title: Text('Duyệt & điều chỉnh kho'), dense: true, contentPadding: EdgeInsets.zero),
                                  ),
                                if (st.status == 'approved')
                                  PopupMenuItem(
                                    value: 'unapprove',
                                    onTap: () => _unapproveStockTake(st),
                                    child: const ListTile(leading: Icon(Icons.undo_rounded, size: 20, color: AppColors.warning), title: Text('Hoàn duyệt'), dense: true, contentPadding: EdgeInsets.zero),
                                  ),
                                if (st.status == 'approved')
                                  PopupMenuItem(
                                    value: 'delete',
                                    onTap: () => _confirmDeleteApproved('stocktakes', st.id, st.code, 'kiểm kê'),
                                    child: const ListTile(leading: Icon(Icons.delete_forever, size: 20, color: AppColors.error), title: Text('Xoá phiếu', style: TextStyle(color: AppColors.error)), dense: true, contentPadding: EdgeInsets.zero),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ));
                  },
                ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TAB 6: NHÀ CUNG CẤP (Suppliers)
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildSuppliersTab() {
    var suppliers = dp.suppliers.toList();
    if (_suppSearch.isNotEmpty) suppliers = suppliers.where((s) => s.name.toLowerCase().contains(_suppSearch.toLowerCase()) || s.phone.toLowerCase().contains(_suppSearch.toLowerCase())).toList();
    return Column(
      children: [
        _buildFilterBar(children: [
          Text('${suppliers.length} NCC', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(width: 10),
          _SearchBox(hint: 'Tìm NCC...', onChanged: (v) => setState(() => _suppSearch = v)),
          if (_suppSearch.isNotEmpty) ...[const SizedBox(width: 8), _ClearFilterChip(onPressed: () => setState(() => _suppSearch = ''))],
        ]),
        Expanded(
          child: suppliers.isEmpty
              ? _EmptyMsg(icon: Icons.store_rounded, msg: _suppSearch.isNotEmpty ? 'Không tìm thấy NCC' : 'Chưa có nhà cung cấp')
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: suppliers.length,
                  itemBuilder: (_, i) {
                    final s = suppliers[i];
                    final poCount = dp.purchaseOrders.where((po) => po.supplierId == s.id).length;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: AppColors.primary.withAlpha(20),
                              child: Text(s.name.isNotEmpty ? s.name[0] : '?', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 18)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                  const SizedBox(height: 4),
                                  Wrap(spacing: 12, runSpacing: 4, children: [
                                    if (s.phone.isNotEmpty) _iconText(Icons.phone_outlined, s.phone),
                                    if (s.email.isNotEmpty) _iconText(Icons.email_outlined, s.email),
                                    if (s.taxCode.isNotEmpty) _iconText(Icons.receipt_long_outlined, 'MST: ${s.taxCode}'),
                                  ]),
                                  if (s.address.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Row(children: [const Icon(Icons.location_on_outlined, size: 13, color: AppColors.textSecondary), const SizedBox(width: 3), Expanded(child: Text(s.address, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis))]),
                                  ],
                                  if (poCount > 0) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(color: AppColors.primary.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                                      child: Text('$poCount đơn đặt hàng', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            _moreMenu(
                              onEdit: () => _showSupplierDialog(s),
                              onDelete: () => _confirmDelete('suppliers', s.id, s.name),
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

  // ═══════════════════════════════════════════════════════════════════════
  // DIALOGS
  // ═══════════════════════════════════════════════════════════════════════

  // ── PRODUCT DIALOG ──
  Future<void> _showProductDialog([Product? existing]) async {
    final isEdit = existing != null;
    final skuC = TextEditingController(text: existing?.sku ?? '');
    final nameC = TextEditingController(text: existing?.name ?? '');
    final brandC = TextEditingController(text: existing?.brand ?? '');
    final originC = TextEditingController(text: existing?.origin ?? '');
    final unitC = TextEditingController(text: existing?.unit ?? 'kg');
    final descC = TextEditingController(text: existing?.description ?? '');
    final priceC = TextEditingController(text: existing != null && existing.price > 0 ? existing.price.toString() : '');
    final costC = TextEditingController(text: existing != null && existing.costPrice > 0 ? existing.costPrice.toString() : '');
    final stockC = TextEditingController(text: existing != null && existing.stock > 0 ? existing.stock.toString() : '');
    final minC = TextEditingController(text: existing != null && existing.minStock > 0 ? existing.minStock.toString() : '');
    final maxC = TextEditingController(text: existing != null && existing.maxStock > 0 ? existing.maxStock.toString() : '');
    final locationC = TextEditingController(text: existing?.location ?? '');
    final noteC = TextEditingController(text: existing?.note ?? '');
    String category = existing?.category ?? 'feed';
    String? supplierId = existing?.supplierId.isNotEmpty == true ? existing!.supplierId : null;
    DateTime? expiryDate = existing?.expiryDate;
    bool isActive = existing?.isActive ?? true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, ss) => AlertDialog(
          title: Row(children: [
            Icon(isEdit ? Icons.edit : Icons.add_box_rounded, color: AppColors.secondary),
            const SizedBox(width: 8),
            Text(isEdit ? 'Sửa hàng hóa' : 'Thêm hàng hóa'),
          ]),
          content: SizedBox(
            width: 550,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
              // ── Thông tin cơ bản ──
              const Align(alignment: Alignment.centerLeft, child: Text('Thông tin cơ bản', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primary))),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(flex: 2, child: TextField(controller: skuC, decoration: const InputDecoration(labelText: 'Mã SP (SKU)', prefixIcon: Icon(Icons.qr_code), isDense: true))),
                const SizedBox(width: 10),
                Expanded(flex: 3, child: TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Tên hàng hóa *', prefixIcon: Icon(Icons.label_outlined), isDense: true))),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Danh mục', prefixIcon: Icon(Icons.category_outlined), isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'feed', child: Text('Thức ăn')),
                    DropdownMenuItem(value: 'seed', child: Text('Giống')),
                    DropdownMenuItem(value: 'chemical', child: Text('Vi sinh/Hoá chất')),
                    DropdownMenuItem(value: 'medicine', child: Text('Thuốc')),
                    DropdownMenuItem(value: 'accessory', child: Text('Phụ kiện')),
                    DropdownMenuItem(value: 'tool', child: Text('Dụng cụ')),
                  ],
                  onChanged: (v) => ss(() => category = v!),
                )),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: unitC, decoration: const InputDecoration(labelText: 'Đơn vị tính', prefixIcon: Icon(Icons.straighten), isDense: true))),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(controller: brandC, decoration: const InputDecoration(labelText: 'Thương hiệu', prefixIcon: Icon(Icons.business_center_outlined), isDense: true))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: originC, decoration: const InputDecoration(labelText: 'Xuất xứ', prefixIcon: Icon(Icons.public), isDense: true))),
              ]),
              const SizedBox(height: 10),
              TextField(controller: descC, decoration: const InputDecoration(labelText: 'Mô tả', prefixIcon: Icon(Icons.description_outlined), isDense: true), maxLines: 2),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // ── Giá & Nhà cung cấp ──
              const Align(alignment: Alignment.centerLeft, child: Text('Giá & Nhà cung cấp', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primary))),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: costC, decoration: const InputDecoration(labelText: 'Giá nhập', prefixIcon: Icon(Icons.price_change_outlined), isDense: true, suffixText: 'đ'), keyboardType: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: priceC, decoration: const InputDecoration(labelText: 'Giá bán', prefixIcon: Icon(Icons.sell_outlined), isDense: true, suffixText: 'đ'), keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 10),
              if (dp.suppliers.isNotEmpty)
                DropdownButtonFormField<String?>(
                  initialValue: (supplierId != null && dp.suppliers.any((s) => s.id == supplierId)) ? supplierId : null,
                  decoration: const InputDecoration(labelText: 'Nhà cung cấp', prefixIcon: Icon(Icons.store_outlined), isDense: true),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('— Không chọn —')),
                    ...dp.suppliers.map((s) => DropdownMenuItem<String?>(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (v) => ss(() => supplierId = v),
                ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // ── Tồn kho ──
              const Align(alignment: Alignment.centerLeft, child: Text('Tồn kho', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primary))),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(
                  controller: stockC,
                  decoration: InputDecoration(labelText: isEdit ? 'Tồn kho hiện tại' : 'Tồn kho ban đầu', prefixIcon: const Icon(Icons.inventory), isDense: true, helperText: isEdit ? 'Dùng nhập/xuất/kiểm kê để điều chỉnh' : null, helperStyle: const TextStyle(fontSize: 11)),
                  keyboardType: TextInputType.number,
                  readOnly: isEdit,
                )),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: locationC, decoration: const InputDecoration(labelText: 'Vị trí kho', prefixIcon: Icon(Icons.location_on_outlined), isDense: true))),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(controller: minC, decoration: const InputDecoration(labelText: 'Tồn tối thiểu', prefixIcon: Icon(Icons.trending_down), isDense: true), keyboardType: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: maxC, decoration: const InputDecoration(labelText: 'Tồn tối đa', prefixIcon: Icon(Icons.trending_up), isDense: true), keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 10),
              InkWell(
                onTap: () async {
                  final d = await _pickDate(dCtx, expiryDate ?? DateTime.now().add(const Duration(days: 365)));
                  if (d != null) ss(() => expiryDate = d);
                },
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Hạn sử dụng',
                    prefixIcon: const Icon(Icons.timer_outlined),
                    isDense: true,
                    suffixIcon: expiryDate != null ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => ss(() => expiryDate = null)) : null,
                  ),
                  child: Text(expiryDate != null ? _dateFmt.format(expiryDate!) : 'Chưa đặt', style: TextStyle(fontSize: 14, color: expiryDate != null ? null : AppColors.textHint)),
                ),
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // ── Ghi chú & Trạng thái ──
              TextField(controller: noteC, decoration: const InputDecoration(labelText: 'Ghi chú', prefixIcon: Icon(Icons.note_alt_outlined), isDense: true), maxLines: 2),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Đang kinh doanh', style: TextStyle(fontSize: 14)),
                subtitle: Text(isActive ? 'Sản phẩm đang hoạt động' : 'Ngừng kinh doanh', style: const TextStyle(fontSize: 12)),
                value: isActive,
                onChanged: (v) => ss(() => isActive = v),
              ),
            ]),
          ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Huỷ')),
            FilledButton.icon(onPressed: () => Navigator.pop(dCtx, true), icon: const Icon(Icons.check), label: Text(isEdit ? 'Cập nhật' : 'Thêm')),
          ],
        ),
      ),
    );

    if (ok == true && nameC.text.isNotEmpty) {
      final data = {
        'sku': skuC.text.trim(),
        'name': nameC.text.trim(),
        'category': category,
        'brand': brandC.text.trim(),
        'origin': originC.text.trim(),
        'unit': unitC.text.trim(),
        'description': descC.text.trim(),
        'price': double.tryParse(priceC.text) ?? 0,
        'costPrice': double.tryParse(costC.text) ?? 0,
        'stock': double.tryParse(stockC.text) ?? 0,
        'minStock': double.tryParse(minC.text) ?? 0,
        'maxStock': double.tryParse(maxC.text) ?? 0,
        'supplierId': supplierId ?? '',
        'location': locationC.text.trim(),
        'expiryDate': expiryDate?.toIso8601String(),
        'note': noteC.text.trim(),
        'isActive': isActive,
      };
      if (isEdit) {
        await dp.update('products', existing.id, data);
      } else {
        await dp.create('products', data);
      }
      _showSnack(isEdit ? 'Đã cập nhật hàng hóa' : 'Đã thêm hàng hóa');
      setState(() {});
    }
  }

  // ── DATE PICKER HELPER ──
  Future<DateTime?> _pickDate(BuildContext context, DateTime initial) async {
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('vi'),
    );
  }

  /// Generate next sequential code like PO-001, NK-002, etc.
  String _nextCode(String prefix, Iterable<String> existingCodes) {
    int maxNum = 0;
    final regex = RegExp('$prefix-(\\d+)');
    for (final code in existingCodes) {
      final match = regex.firstMatch(code);
      if (match != null) {
        final n = int.tryParse(match.group(1)!) ?? 0;
        if (n > maxNum) maxNum = n;
      }
    }
    return '$prefix-${(maxNum + 1).toString().padLeft(3, '0')}';
  }

  Widget _dateField(DateTime date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Ngày phiếu',
          prefixIcon: Icon(Icons.calendar_today),
        ),
        child: Text(_dateFmt.format(date), style: const TextStyle(fontSize: 14)),
      ),
    );
  }

  // ── PURCHASE ORDER DIALOG ──
  Future<void> _showPurchaseOrderDialog([PurchaseOrder? existing]) async {
    final isEdit = existing != null;
    DateTime selectedDate = existing?.date ?? DateTime.now();
    String? supplierId = (existing?.supplierId.isNotEmpty == true && dp.suppliers.any((s) => s.id == existing!.supplierId)) ? existing!.supplierId : (dp.suppliers.isNotEmpty ? dp.suppliers.first.id : null);
    final supplierTextC = TextEditingController(text: existing?.supplier ?? '');
    String? branchId = (existing?.branchId.isNotEmpty == true && dp.branches.any((b) => b.id == existing!.branchId)) ? existing!.branchId : (dp.branches.isNotEmpty ? dp.branches.first.id : null);
    final noteC = TextEditingController(text: existing?.note ?? '');
    final codeC = TextEditingController(text: existing?.code ?? _nextCode('PO', dp.purchaseOrders.map((o) => o.code)));
    String? createdBy = (existing?.createdBy.isNotEmpty == true && dp.employees.any((e) => e.id == existing!.createdBy)) ? existing!.createdBy : (dp.employees.isNotEmpty ? dp.employees.first.id : null);

    // Line items
    final lineItems = <Map<String, dynamic>>[
      if (existing != null) ...existing.items.map((e) => Map<String, dynamic>.from(e)),
    ];

    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, ss) {
          double total = 0;
          for (final item in lineItems) {
            total += ((item['qty'] as num?) ?? 0) * ((item['unitPrice'] as num?) ?? 0);
          }
          return AlertDialog(
            title: Row(children: [
              const Icon(Icons.shopping_cart_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(isEdit ? 'Sửa phiếu đặt hàng' : 'Tạo phiếu đặt hàng'),
            ]),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(controller: codeC, decoration: const InputDecoration(labelText: 'Mã phiếu', prefixIcon: Icon(Icons.tag))),
                  const SizedBox(height: 12),
                  _dateField(selectedDate, () async {
                    final d = await _pickDate(dCtx, selectedDate);
                    if (d != null) ss(() => selectedDate = d);
                  }),
                  const SizedBox(height: 12),
                  // Supplier dropdown or text
                  if (dp.suppliers.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: supplierId,
                      decoration: const InputDecoration(labelText: 'Nhà cung cấp', prefixIcon: Icon(Icons.store)),
                      items: dp.suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                      onChanged: (v) => ss(() {
                        supplierId = v;
                        supplierTextC.text = dp.supplierById(v!)?.name ?? '';
                      }),
                    )
                  else
                    TextField(controller: supplierTextC, decoration: const InputDecoration(labelText: 'Nhà cung cấp', prefixIcon: Icon(Icons.store))),
                  const SizedBox(height: 12),
                  if (dp.branches.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: branchId,
                      decoration: const InputDecoration(labelText: 'Chi nhánh', prefixIcon: Icon(Icons.business)),
                      items: dp.branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                      onChanged: (v) => ss(() => branchId = v),
                    ),
                  const SizedBox(height: 12),
                  TextField(controller: noteC, decoration: const InputDecoration(labelText: 'Ghi chú', prefixIcon: Icon(Icons.note)), maxLines: 2),
                  const SizedBox(height: 12),
                  if (dp.employees.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: createdBy,
                      decoration: const InputDecoration(labelText: 'Người tạo phiếu', prefixIcon: Icon(Icons.person)),
                      items: dp.employees.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
                      onChanged: (v) => ss(() => createdBy = v),
                    ),
                  const SizedBox(height: 16),
                  // Line items header
                  Row(
                    children: [
                      const Text('Danh sách hàng', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => ss(() {
                          lineItems.add({'productId': dp.products.isNotEmpty ? dp.products.first.id : '', 'productName': dp.products.isNotEmpty ? dp.products.first.name : '', 'qty': 0, 'unitPrice': dp.products.isNotEmpty ? dp.products.first.price : 0, 'unit': dp.products.isNotEmpty ? dp.products.first.unit : 'kg'});
                        }),
                        icon: const Icon(Icons.add_circle, size: 18),
                        label: const Text('Thêm dòng', style: TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                  ...lineItems.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: item['productId'] as String?,
                                  decoration: const InputDecoration(labelText: 'Sản phẩm', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                  items: dp.products.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis))).toList(),
                                  onChanged: (v) => ss(() {
                                    final p = dp.productById(v!);
                                    item['productId'] = v;
                                    item['productName'] = p?.name ?? '';
                                    item['unitPrice'] = p?.price ?? 0;
                                    item['unit'] = p?.unit ?? 'kg';
                                  }),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete, color: AppColors.error, size: 20),
                                onPressed: () => ss(() => lineItems.removeAt(idx)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: item['qty']?.toString() ?? '0',
                                  decoration: InputDecoration(labelText: 'SL (${item['unit'] ?? ''})', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) => ss(() => item['qty'] = int.tryParse(v) ?? 0),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  initialValue: item['unitPrice']?.toString() ?? '0',
                                  decoration: const InputDecoration(labelText: 'Đơn giá', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) => ss(() => item['unitPrice'] = double.tryParse(v) ?? 0),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('= ${_currFmt.format(((item['qty'] as num?) ?? 0) * ((item['unitPrice'] as num?) ?? 0))}đ',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text('Tổng cộng: ', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('${_currFmt.format(total)}đ', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.primary)),
                    ],
                  ),
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Huỷ')),
              FilledButton.icon(onPressed: lineItems.isEmpty ? null : () => Navigator.pop(dCtx, true), icon: const Icon(Icons.check), label: Text(isEdit ? 'Cập nhật' : 'Tạo phiếu')),
            ],
          );
        },
      ),
    );

    if (ok == true) {
      double total = 0;
      for (final item in lineItems) {
        total += ((item['qty'] as num?) ?? 0) * ((item['unitPrice'] as num?) ?? 0);
      }
      final data = {
        'code': codeC.text,
        'date': selectedDate.toIso8601String(),
        'supplierId': supplierId ?? '',
        'supplier': supplierTextC.text.isNotEmpty ? supplierTextC.text : (supplierId != null ? dp.supplierById(supplierId!)?.name ?? '' : ''),
        'branchId': branchId ?? '',
        'items': lineItems,
        'total': total,
        'status': existing?.status ?? 'draft',
        'note': noteC.text,
        'createdBy': createdBy ?? '',
      };
      if (isEdit) {
        await dp.update('purchaseorders', existing.id, data);
      } else {
        await dp.create('purchaseorders', data);
      }
      _showSnack(isEdit ? 'Đã cập nhật đơn mua' : 'Đã thêm đơn mua');
      setState(() {});
    }
  }

  // ── RECEIPT DIALOG ──
  Future<void> _showReceiptDialog([StockReceipt? existing]) async {
    final isEdit = existing != null;
    final codeC = TextEditingController(text: existing?.code ?? _nextCode('NK', dp.stockReceipts.map((r) => r.code)));
    DateTime selectedDate = existing?.date ?? DateTime.now();
    String type = existing?.type ?? 'purchase';
    String? supplierId = (existing?.supplierId.isNotEmpty == true && dp.suppliers.any((s) => s.id == existing!.supplierId)) ? existing!.supplierId : (dp.suppliers.isNotEmpty ? dp.suppliers.first.id : null);
    String? branchId = (existing?.branchId.isNotEmpty == true && dp.branches.any((b) => b.id == existing!.branchId)) ? existing!.branchId : (dp.branches.isNotEmpty ? dp.branches.first.id : null);
    final noteC = TextEditingController(text: existing?.note ?? '');
    String? createdBy = (existing?.createdBy.isNotEmpty == true && dp.employees.any((e) => e.id == existing!.createdBy)) ? existing!.createdBy : (dp.employees.isNotEmpty ? dp.employees.first.id : null);
    final lineItems = <Map<String, dynamic>>[
      if (existing != null) ...existing.items.map((e) => Map<String, dynamic>.from(e)),
    ];

    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, ss) {
          double total = 0;
          for (final item in lineItems) {
            total += ((item['receivedQty'] ?? item['qty']) as num? ?? 0).toDouble() * ((item['unitPrice'] as num?) ?? 0).toDouble();
          }
          return AlertDialog(
            title: Row(children: [
              const Icon(Icons.move_to_inbox_rounded, color: AppColors.success),
              const SizedBox(width: 8),
              Text(isEdit ? 'Sửa phiếu nhập kho' : 'Tạo phiếu nhập kho'),
            ]),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(controller: codeC, decoration: const InputDecoration(labelText: 'Mã phiếu', prefixIcon: Icon(Icons.tag))),
                  const SizedBox(height: 12),
                  _dateField(selectedDate, () async {
                    final d = await _pickDate(dCtx, selectedDate);
                    if (d != null) ss(() => selectedDate = d);
                  }),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Loại nhập', prefixIcon: Icon(Icons.category)),
                    items: const [
                      DropdownMenuItem(value: 'purchase', child: Text('Nhập từ đặt hàng')),
                      DropdownMenuItem(value: 'transfer', child: Text('Nhập điều chuyển')),
                      DropdownMenuItem(value: 'other', child: Text('Nhập khác')),
                    ],
                    onChanged: (v) => ss(() => type = v!),
                  ),
                  const SizedBox(height: 12),
                  if (dp.suppliers.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: supplierId,
                      decoration: const InputDecoration(labelText: 'Nhà cung cấp', prefixIcon: Icon(Icons.store)),
                      items: dp.suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                      onChanged: (v) => ss(() => supplierId = v),
                    ),
                  const SizedBox(height: 12),
                  if (dp.branches.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: branchId,
                      decoration: const InputDecoration(labelText: 'Chi nhánh', prefixIcon: Icon(Icons.business)),
                      items: dp.branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                      onChanged: (v) => ss(() => branchId = v),
                    ),
                  const SizedBox(height: 12),
                  if (dp.employees.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: createdBy,
                      decoration: const InputDecoration(labelText: 'Người tạo phiếu', prefixIcon: Icon(Icons.person)),
                      items: dp.employees.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
                      onChanged: (v) => ss(() => createdBy = v),
                    ),
                  const SizedBox(height: 12),
                  TextField(controller: noteC, decoration: const InputDecoration(labelText: 'Ghi chú', prefixIcon: Icon(Icons.note)), maxLines: 2),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Chi tiết hàng nhập', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => ss(() {
                          lineItems.add({'productId': dp.products.isNotEmpty ? dp.products.first.id : '', 'productName': dp.products.isNotEmpty ? dp.products.first.name : '', 'qty': 0, 'receivedQty': 0, 'unitPrice': dp.products.isNotEmpty ? dp.products.first.price : 0, 'unit': dp.products.isNotEmpty ? dp.products.first.unit : 'kg'});
                        }),
                        icon: const Icon(Icons.add_circle, size: 18),
                        label: const Text('Thêm dòng'),
                      ),
                    ],
                  ),
                  ...lineItems.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(10)),
                      child: Column(children: [
                        Row(children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: item['productId'] as String?,
                              decoration: const InputDecoration(labelText: 'Sản phẩm', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                              items: dp.products.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (v) => ss(() {
                                final p = dp.productById(v!);
                                item['productId'] = v;
                                item['productName'] = p?.name ?? '';
                                item['unitPrice'] = p?.price ?? 0;
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
                            initialValue: (item['receivedQty'] ?? item['qty'])?.toString() ?? '0',
                            decoration: InputDecoration(labelText: 'SL nhận (${item['unit'] ?? ''})', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => ss(() { item['receivedQty'] = int.tryParse(v) ?? 0; item['qty'] = int.tryParse(v) ?? 0; }),
                          )),
                          const SizedBox(width: 8),
                          Expanded(child: TextFormField(
                            initialValue: item['unitPrice']?.toString() ?? '0',
                            decoration: const InputDecoration(labelText: 'Đơn giá', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => ss(() => item['unitPrice'] = double.tryParse(v) ?? 0),
                          )),
                        ]),
                      ]),
                    );
                  }),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text('Tổng: ', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('${_currFmt.format(total)}đ', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.success)),
                    ],
                  ),
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Huỷ')),
              FilledButton.icon(onPressed: lineItems.isEmpty ? null : () => Navigator.pop(dCtx, true), icon: const Icon(Icons.check), label: Text(isEdit ? 'Cập nhật' : 'Tạo phiếu')),
            ],
          );
        },
      ),
    );

    if (ok == true) {
      double total = 0;
      for (final item in lineItems) {
        total += ((item['receivedQty'] ?? item['qty']) as num? ?? 0).toDouble() * ((item['unitPrice'] as num?) ?? 0).toDouble();
      }
      final data = {
        'code': codeC.text,
        'date': selectedDate.toIso8601String(),
        'type': type,
        'purchaseOrderId': existing?.purchaseOrderId ?? '',
        'supplierId': supplierId ?? '',
        'branchId': branchId ?? '',
        'items': lineItems,
        'totalAmount': total,
        'status': existing?.status ?? 'draft',
        'note': noteC.text,
        'createdBy': createdBy ?? '',
        'approvedBy': '',
      };
      if (isEdit) {
        await dp.update('stockreceipts', existing.id, data);
      } else {
        await dp.create('stockreceipts', data);
      }
      _showSnack(isEdit ? 'Đã cập nhật phiếu nhập' : 'Đã thêm phiếu nhập');
      setState(() {});
    }
  }

  // ── ISSUE DIALOG ──
  Future<void> _showIssueDialog([StockIssue? existing]) async {
    final isEdit = existing != null;
    final codeC = TextEditingController(text: existing?.code ?? _nextCode('XK', dp.stockIssues.map((si) => si.code)));
    DateTime selectedDate = existing?.date ?? DateTime.now();
    String type = existing?.type ?? 'usage';
    String? branchId = (existing?.branchId.isNotEmpty == true && dp.branches.any((b) => b.id == existing!.branchId)) ? existing!.branchId : (dp.branches.isNotEmpty ? dp.branches.first.id : null);
    String? pondId = existing?.pondId;
    String? createdByIssue = (existing?.createdBy.isNotEmpty == true && dp.employees.any((e) => e.id == existing!.createdBy)) ? existing!.createdBy : (dp.employees.isNotEmpty ? dp.employees.first.id : null);
    String? issuedTo = (existing?.issuedTo.isNotEmpty == true && dp.employees.any((e) => e.id == existing!.issuedTo)) ? existing!.issuedTo : null;
    final noteC = TextEditingController(text: existing?.note ?? '');
    final lineItems = <Map<String, dynamic>>[
      if (existing != null) ...existing.items.map((e) => Map<String, dynamic>.from(e)),
    ];

    // Helper: get ponds for selected branch (branch → zones → ponds)
    List<Pond> pondsForBranch(String? bId) {
      if (bId == null) return dp.ponds;
      final zoneIds = dp.zones.where((z) => z.branchId == bId).map((z) => z.id).toSet();
      return dp.ponds.where((p) => p.zoneId != null && zoneIds.contains(p.zoneId)).toList();
    }

    // Helper: pond display info (status + active fish)
    String pondLabel(Pond p) {
      final statusMap = {'active': 'Đang nuôi', 'inactive': 'Trống', 'maintenance': 'Bảo trì'};
      final statusText = statusMap[p.status] ?? p.status;
      final activeBatches = dp.batchesForPond(p.id).where((b) => b.status == 'active');
      if (activeBatches.isNotEmpty) {
        final speciesNames = activeBatches.map((b) {
          final sp = dp.speciesById(b.speciesId);
          return sp?.name ?? 'Lô #${b.id.substring(0, 4)}';
        }).join(', ');
        return '${p.code} — $statusText • $speciesNames';
      }
      return '${p.code} — $statusText';
    }

    // Validate that pondId belongs to the selected branch
    final branchPonds = pondsForBranch(branchId);
    if (pondId != null && !branchPonds.any((p) => p.id == pondId)) {
      pondId = null;
    }

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
          final canSubmit = lineItems.isNotEmpty && !hasOverStock && !hasZeroQty;

          // Ponds filtered by branch
          final filteredPonds = pondsForBranch(branchId);

          // Products already selected (for duplicate filter)
          final usedProductIds = lineItems.map((e) => e['productId'] as String?).whereType<String>().toSet();

          return AlertDialog(
            title: Row(children: [
              const Icon(Icons.outbox_rounded, color: AppColors.warning),
              const SizedBox(width: 8),
              Text(isEdit ? 'Sửa phiếu xuất kho' : 'Tạo phiếu xuất kho'),
            ]),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _dateField(selectedDate, () async {
                    final d = await _pickDate(dCtx, selectedDate);
                    if (d != null) ss(() => selectedDate = d);
                  }),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('issue_type'),
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Loại xuất', prefixIcon: Icon(Icons.category)),
                    items: const [
                      DropdownMenuItem(value: 'usage', child: Text('Xuất sử dụng (ao nuôi)')),
                      DropdownMenuItem(value: 'feeding', child: Text('Xuất cho ăn')),
                      DropdownMenuItem(value: 'sale', child: Text('Xuất bán')),
                      DropdownMenuItem(value: 'maintenance', child: Text('Xuất bảo trì')),
                      DropdownMenuItem(value: 'disposal', child: Text('Xuất huỷ')),
                      DropdownMenuItem(value: 'transfer', child: Text('Xuất điều chuyển')),
                    ],
                    onChanged: (v) => ss(() => type = v!),
                  ),
                  const SizedBox(height: 12),
                  // ── Chi nhánh (trước ao) ──
                  if (dp.branches.isNotEmpty)
                    DropdownButtonFormField<String>(
                      key: ValueKey('issue_branch_$branchId'),
                      initialValue: branchId,
                      decoration: const InputDecoration(labelText: 'Chi nhánh', prefixIcon: Icon(Icons.business)),
                      items: dp.branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                      onChanged: (v) => ss(() {
                        branchId = v;
                        // Reset pond khi đổi chi nhánh
                        final newPonds = pondsForBranch(v);
                        if (pondId != null && !newPonds.any((p) => p.id == pondId)) {
                          pondId = null;
                        }
                      }),
                    ),
                  // ── Ao nuôi (lọc theo chi nhánh, hiển thị trạng thái) ──
                  if (type == 'usage') ...[
                    const SizedBox(height: 12),
                    filteredPonds.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(10)),
                            child: Row(children: [
                              const Icon(Icons.info_outline, size: 16, color: AppColors.textHint),
                              const SizedBox(width: 8),
                              Text(branchId != null ? 'Chi nhánh chưa có ao nuôi' : 'Chọn chi nhánh trước', style: const TextStyle(fontSize: 13, color: AppColors.textHint)),
                            ]),
                          )
                        : DropdownButtonFormField<String?>(
                            key: ValueKey('issue_pond_${branchId}_$pondId'),
                            initialValue: (pondId != null && filteredPonds.any((p) => p.id == pondId)) ? pondId : null,
                            decoration: const InputDecoration(labelText: 'Ao nuôi liên quan', prefixIcon: Icon(Icons.water)),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('-- Không chọn --')),
                              ...filteredPonds.map((p) {
                                final isActive = p.status == 'active';
                                return DropdownMenuItem<String?>(
                                  value: p.id,
                                  child: Row(children: [
                                    Container(
                                      width: 8, height: 8,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isActive ? AppColors.success : (p.status == 'maintenance' ? AppColors.warning : AppColors.textHint),
                                      ),
                                    ),
                                    Expanded(child: Text(pondLabel(p), style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                                  ]),
                                );
                              }),
                            ],
                            onChanged: (v) => ss(() => pondId = v),
                          ),
                  ],
                  const SizedBox(height: 12),
                  TextField(controller: noteC, decoration: const InputDecoration(labelText: 'Ghi chú', prefixIcon: Icon(Icons.note)), maxLines: 2),
                  const SizedBox(height: 12),
                  if (dp.employees.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      key: const ValueKey('issue_createdBy'),
                      initialValue: createdByIssue,
                      decoration: const InputDecoration(labelText: 'Người tạo phiếu', prefixIcon: Icon(Icons.person)),
                      items: dp.employees.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
                      onChanged: (v) => ss(() => createdByIssue = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      key: const ValueKey('issue_issuedTo'),
                      initialValue: issuedTo,
                      decoration: const InputDecoration(labelText: 'Xuất cho nhân viên', prefixIcon: Icon(Icons.person_outline)),
                      items: [const DropdownMenuItem<String?>(value: null, child: Text('-- Không chọn --')), ...dp.employees.map((e) => DropdownMenuItem<String?>(value: e.id, child: Text(e.name)))],
                      onChanged: (v) => ss(() => issuedTo = v),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Chi tiết hàng xuất', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => ss(() {
                          // Tìm sản phẩm chưa được chọn
                          final available = dp.products.where((p) => !usedProductIds.contains(p.id)).toList();
                          final first = available.isNotEmpty ? available.first : (dp.products.isNotEmpty ? dp.products.first : null);
                          lineItems.add({
                            'productId': first?.id ?? '',
                            'productName': first?.name ?? '',
                            'qty': 0,
                            'unitPrice': first?.costPrice ?? 0,
                            'unit': first?.unit ?? 'kg',
                          });
                        }),
                        icon: const Icon(Icons.add_circle, size: 18),
                        label: const Text('Thêm dòng'),
                      ),
                    ],
                  ),
                  ...lineItems.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    final prod = dp.productById(item['productId'] as String? ?? '');
                    final qty = ((item['qty'] as num?) ?? 0).toDouble();
                    final stock = prod?.stock ?? 0;
                    final overStock = prod != null && qty > stock;
                    final zeroQty = qty <= 0;

                    // Available products: current + not yet selected
                    final currentPid = item['productId'] as String?;
                    final availableProducts = dp.products.where((p) => p.id == currentPid || !usedProductIds.contains(p.id)).toList();

                    return Container(
                      key: ValueKey('issue_line_$idx'),
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
                              key: ValueKey('issue_prod_${idx}_$currentPid'),
                              initialValue: currentPid,
                              decoration: const InputDecoration(labelText: 'Sản phẩm', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                              items: availableProducts.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.name} (tồn: ${p.stock.toStringAsFixed(0)})', overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (v) => ss(() {
                                // Cập nhật product id, name, giá vốn, đơn vị
                                final p = dp.productById(v!);
                                item['productId'] = v;
                                item['productName'] = p?.name ?? '';
                                item['unitPrice'] = p?.costPrice ?? 0;
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
                            key: ValueKey('issue_qty_${idx}_$currentPid'),
                            initialValue: qty > 0 ? qty.toStringAsFixed(0) : '',
                            decoration: InputDecoration(
                              labelText: 'SL xuất (${item['unit'] ?? ''})',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              helperText: prod != null ? 'Tồn: ${stock.toStringAsFixed(0)}' : null,
                              helperStyle: TextStyle(fontSize: 11, color: overStock ? AppColors.error : null),
                              errorText: overStock ? 'Vượt tồn kho!' : (zeroQty && qty == 0 && prod != null ? 'Nhập SL > 0' : null),
                              errorStyle: const TextStyle(fontSize: 11),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => ss(() => item['qty'] = double.tryParse(v) ?? 0),
                          )),
                          const SizedBox(width: 8),
                          Expanded(child: TextFormField(
                            key: ValueKey('issue_price_${idx}_$currentPid'),
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
                        const Icon(Icons.error_outline, size: 16, color: AppColors.error),
                        const SizedBox(width: 6),
                        const Expanded(child: Text('Có sản phẩm xuất vượt tồn kho!', style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w600))),
                      ]),
                    ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text('Tổng: ', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('${_currFmt.format(total)}đ', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.warning)),
                    ],
                  ),
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Huỷ')),
              FilledButton.icon(
                onPressed: canSubmit ? () => Navigator.pop(dCtx, true) : null,
                icon: const Icon(Icons.check),
                label: Text(isEdit ? 'Cập nhật' : 'Tạo phiếu'),
              ),
            ],
          );
        },
      ),
    );

    if (ok == true) {
      double total = 0;
      for (final item in lineItems) {
        total += ((item['qty'] as num?) ?? 0) * ((item['unitPrice'] as num?) ?? 0);
      }
      final data = {
        'code': codeC.text,
        'date': selectedDate.toIso8601String(),
        'type': type,
        'saleOrderId': existing?.saleOrderId ?? '',
        'pondId': pondId ?? '',
        'branchId': branchId ?? '',
        'items': lineItems,
        'totalAmount': total,
        'status': existing?.status ?? 'draft',
        'note': noteC.text,
        'createdBy': createdByIssue ?? '',
        'issuedTo': issuedTo ?? '',
        'approvedBy': '',
      };
      if (isEdit) {
        await dp.update('stockissues', existing.id, data);
      } else {
        await dp.create('stockissues', data);
      }
      _showSnack(isEdit ? 'Đã cập nhật phiếu xuất' : 'Đã thêm phiếu xuất');
      setState(() {});
    }
  }

  // ── STOCK TAKE DIALOG ──
  Future<void> _showStockTakeDialog([StockTake? existing]) async {
    final isEdit = existing != null;
    final codeC = TextEditingController(text: existing?.code ?? _nextCode('KK', dp.stockTakes.map((st) => st.code)));
    DateTime selectedDate = existing?.date ?? DateTime.now();
    String? branchId = (existing?.branchId.isNotEmpty == true && dp.branches.any((b) => b.id == existing!.branchId)) ? existing!.branchId : (dp.branches.isNotEmpty ? dp.branches.first.id : null);
    final noteC = TextEditingController(text: existing?.note ?? '');
    String? createdByST = (existing?.createdBy.isNotEmpty == true && dp.employees.any((e) => e.id == existing!.createdBy)) ? existing!.createdBy : (dp.employees.isNotEmpty ? dp.employees.first.id : null);
    String? checkedBy = (existing?.checkedBy.isNotEmpty == true && dp.employees.any((e) => e.id == existing!.checkedBy)) ? existing!.checkedBy : null;

    // Build items from products (pre-fill systemQty from current stock)
    final lineItems = <Map<String, dynamic>>[];
    if (existing != null) {
      lineItems.addAll(existing.items.map((e) => Map<String, dynamic>.from(e)));
    } else {
      for (final p in dp.products) {
        lineItems.add({
          'productId': p.id,
          'productName': p.name,
          'unit': p.unit,
          'systemQty': p.stock,
          'actualQty': p.stock,
          'diff': 0,
          'reason': '',
        });
      }
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, ss) => AlertDialog(
          title: Row(children: [
            const Icon(Icons.fact_check_rounded, color: AppColors.info),
            const SizedBox(width: 8),
            Text(isEdit ? 'Sửa phiếu kiểm kê' : 'Tạo phiếu kiểm kê'),
          ]),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: codeC, decoration: const InputDecoration(labelText: 'Mã phiếu', prefixIcon: Icon(Icons.tag))),
                const SizedBox(height: 12),
                _dateField(selectedDate, () async {
                  final d = await _pickDate(dCtx, selectedDate);
                  if (d != null) ss(() => selectedDate = d);
                }),
                const SizedBox(height: 12),
                if (dp.branches.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: branchId,
                    decoration: const InputDecoration(labelText: 'Chi nhánh', prefixIcon: Icon(Icons.business)),
                    items: dp.branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                    onChanged: (v) => ss(() => branchId = v),
                  ),
                const SizedBox(height: 12),
                TextField(controller: noteC, decoration: const InputDecoration(labelText: 'Ghi chú', prefixIcon: Icon(Icons.note)), maxLines: 2),
                const SizedBox(height: 12),
                if (dp.employees.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    initialValue: createdByST,
                    decoration: const InputDecoration(labelText: 'Người tạo phiếu', prefixIcon: Icon(Icons.person)),
                    items: dp.employees.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
                    onChanged: (v) => ss(() => createdByST = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: checkedBy,
                    decoration: const InputDecoration(labelText: 'Người kiểm kê', prefixIcon: Icon(Icons.fact_check)),
                    items: [const DropdownMenuItem<String>(value: null, child: Text('-- Chưa chọn --')), ...dp.employees.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name)))],
                    onChanged: (v) => ss(() => checkedBy = v),
                  ),
                ],
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Expanded(flex: 3, child: Text('Sản phẩm', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    SizedBox(width: 4),
                    Expanded(flex: 1, child: Text('Sổ sách', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12), textAlign: TextAlign.center)),
                    SizedBox(width: 4),
                    Expanded(flex: 1, child: Text('Thực tế', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12), textAlign: TextAlign.center)),
                    SizedBox(width: 4),
                    Expanded(flex: 1, child: Text('Chênh lệch', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12), textAlign: TextAlign.center)),
                  ],
                ),
                const Divider(),
                ...lineItems.asMap().entries.map((entry) {
                  final item = entry.value;
                  final diff = ((item['actualQty'] as num?) ?? 0).toDouble() - ((item['systemQty'] as num?) ?? 0).toDouble();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                      children: [
                        Expanded(flex: 3, child: Text('${item['productName']} (${item['unit']})', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 4),
                        Expanded(flex: 1, child: Text(((item['systemQty'] as num?) ?? 0).toStringAsFixed(0), textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
                        const SizedBox(width: 4),
                        Expanded(flex: 1, child: SizedBox(
                          height: 32,
                          child: TextFormField(
                            initialValue: ((item['actualQty'] as num?) ?? 0).toStringAsFixed(0),
                            decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6), border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13),
                            onChanged: (v) => ss(() {
                              item['actualQty'] = double.tryParse(v) ?? 0;
                              item['diff'] = ((item['actualQty'] as num?) ?? 0).toDouble() - ((item['systemQty'] as num?) ?? 0).toDouble();
                            }),
                          ),
                        )),
                        const SizedBox(width: 4),
                        Expanded(flex: 1, child: Text(
                          diff == 0 ? '0' : (diff > 0 ? '+${diff.toStringAsFixed(0)}' : diff.toStringAsFixed(0)),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: diff == 0 ? AppColors.textSecondary : (diff > 0 ? AppColors.success : AppColors.error)),
                        )),
                      ],
                        ),
                        if (diff != 0) Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: TextFormField(
                            initialValue: item['reason']?.toString() ?? '',
                            decoration: const InputDecoration(hintText: 'Lý do chênh lệch...', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6), border: OutlineInputBorder(), hintStyle: TextStyle(fontSize: 11)),
                            style: const TextStyle(fontSize: 12),
                            onChanged: (v) => item['reason'] = v,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Huỷ')),
            FilledButton.icon(onPressed: () => Navigator.pop(dCtx, true), icon: const Icon(Icons.check), label: Text(isEdit ? 'Cập nhật' : 'Tạo phiếu')),
          ],
        ),
      ),
    );

    if (ok == true) {
      final data = {
        'code': codeC.text,
        'date': selectedDate.toIso8601String(),
        'branchId': branchId ?? '',
        'items': lineItems,
        'status': existing?.status ?? 'draft',
        'note': noteC.text,
        'createdBy': createdByST ?? '',
        'checkedBy': checkedBy ?? '',
        'approvedBy': '',
      };
      if (isEdit) {
        await dp.update('stocktakes', existing.id, data);
      } else {
        await dp.create('stocktakes', data);
      }
      _showSnack(isEdit ? 'Đã cập nhật kiểm kê' : 'Đã thêm kiểm kê');
      setState(() {});
    }
  }

  // ── SUPPLIER DIALOG ──
  Future<void> _showSupplierDialog([Supplier? existing]) async {
    final isEdit = existing != null;
    final nameC = TextEditingController(text: existing?.name ?? '');
    final phoneC = TextEditingController(text: existing?.phone ?? '');
    final emailC = TextEditingController(text: existing?.email ?? '');
    final addrC = TextEditingController(text: existing?.address ?? '');
    final taxC = TextEditingController(text: existing?.taxCode ?? '');
    final noteC = TextEditingController(text: existing?.note ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.store_rounded, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(isEdit ? 'Sửa nhà cung cấp' : 'Thêm nhà cung cấp'),
        ]),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Tên NCC', prefixIcon: Icon(Icons.business))),
            const SizedBox(height: 12),
            TextField(controller: phoneC, decoration: const InputDecoration(labelText: 'Điện thoại', prefixIcon: Icon(Icons.phone)), keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            TextField(controller: emailC, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email)), keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 12),
            TextField(controller: addrC, decoration: const InputDecoration(labelText: 'Địa chỉ', prefixIcon: Icon(Icons.location_on))),
            const SizedBox(height: 12),
            TextField(controller: taxC, decoration: const InputDecoration(labelText: 'Mã số thuế', prefixIcon: Icon(Icons.receipt))),
            const SizedBox(height: 12),
            TextField(controller: noteC, decoration: const InputDecoration(labelText: 'Ghi chú', prefixIcon: Icon(Icons.note)), maxLines: 2),
          ]),
        ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Huỷ')),
          FilledButton.icon(onPressed: () => Navigator.pop(dCtx, true), icon: const Icon(Icons.check), label: Text(isEdit ? 'Cập nhật' : 'Thêm')),
        ],
      ),
    );

    if (ok == true && nameC.text.isNotEmpty) {
      final data = {
        'name': nameC.text,
        'phone': phoneC.text,
        'email': emailC.text,
        'address': addrC.text,
        'taxCode': taxC.text,
        'note': noteC.text,
      };
      if (isEdit) {
        await dp.update('suppliers', existing.id, data);
      } else {
        await dp.create('suppliers', data);
      }
      _showSnack(isEdit ? 'Đã cập nhật NCC' : 'Đã thêm NCC');
      setState(() {});
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ACTIONS (Approve, Create Receipt from PO, etc.)
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _sendPO(PurchaseOrder po) async {
    if (po.status != 'draft') { _snack('Đơn đã được gửi!'); return; }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Row(children: [Icon(Icons.send_rounded, color: Color(0xFF2563EB)), SizedBox(width: 8), Text('Gửi đơn đặt hàng')]),
        content: Text('Xác nhận gửi ${po.code} cho nhà cung cấp?\nSau khi gửi sẽ không thể sửa đơn.'),
        actions: [TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Huỷ')), ElevatedButton(onPressed: () => Navigator.pop(dCtx, true), child: const Text('Gửi NCC'))],
      ),
    );
    if (ok != true) return;
    await dp.update('purchaseorders', po.id, {...po.toJson(), 'status': 'sent'});
    _snack('Đã gửi ${po.code} cho NCC');
    setState(() {});
  }

  Future<void> _createReceiptFromPO(PurchaseOrder po) async {
    final code = _nextCode('NK', dp.stockReceipts.map((r) => r.code));
    final receiptItems = po.items.map((item) => {
      'productId': item['productId'],
      'productName': item['productName'] ?? '',
      'qty': item['qty'],
      'receivedQty': item['qty'],
      'unitPrice': item['unitPrice'],
      'unit': item['unit'] ?? '',
    }).toList();

    await dp.create('stockreceipts', {
      'code': code,
      'date': DateTime.now().toIso8601String(),
      'type': 'purchase',
      'purchaseOrderId': po.id,
      'supplierId': po.supplierId,
      'branchId': po.branchId,
      'items': receiptItems,
      'totalAmount': po.total,
      'status': 'draft',
      'note': 'Nhập từ ${po.code}',
      'createdBy': '',
      'approvedBy': '',
    });
    // Update PO → waiting_receipt
    await dp.update('purchaseorders', po.id, {...po.toJson(), 'status': 'waiting_receipt'});
    _snack('Đã tạo phiếu nhập $code từ ${po.code}');
    setState(() {});
  }

  Future<void> _approveReceipt(StockReceipt r) async {
    if (r.status != 'draft') { _snack('Phiếu đã được duyệt!'); return; }

    // ── Dialog chọn phương thức thanh toán ──
    String paymentMethod = 'cash';
    String? payNote;
    final supplier = r.supplierId.isNotEmpty ? dp.supplierById(r.supplierId) : null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, ss) {
          final noteC = TextEditingController(text: payNote ?? '');
          return AlertDialog(
            title: const Row(children: [Icon(Icons.check_circle, color: AppColors.success), SizedBox(width: 8), Text('Duyệt nhập kho')]),
            content: SizedBox(
              width: 420,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // ── Thông tin phiếu ──
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.success.withAlpha(12), borderRadius: BorderRadius.circular(10)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(r.code, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const Spacer(),
                      Text('${_currFmt.format(r.totalAmount)}đ', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.success)),
                    ]),
                    const SizedBox(height: 4),
                    Text('NCC: ${supplier?.name ?? '—'}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    Text('${r.items.length} sản phẩm • ${r.typeLabel}', style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
                  ]),
                ),
                const SizedBox(height: 16),
                // ── Phương thức thanh toán ──
                const Align(alignment: Alignment.centerLeft, child: Text('Phương thức thanh toán', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                const SizedBox(height: 8),
                ...['cash', 'transfer', 'debt'].map((m) {
                  final labels = {'cash': 'Tiền mặt', 'transfer': 'Chuyển khoản', 'debt': 'Công nợ'};
                  final icons = {'cash': Icons.payments_rounded, 'transfer': Icons.account_balance_rounded, 'debt': Icons.schedule_rounded};
                  final colors = {'cash': AppColors.success, 'transfer': const Color(0xFF2563EB), 'debt': AppColors.warning};
                  final selected = paymentMethod == m;
                  return InkWell(
                    onTap: () => ss(() => paymentMethod = m),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: selected ? colors[m]!.withAlpha(15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: selected ? colors[m]!.withAlpha(80) : Colors.transparent),
                      ),
                      child: Row(children: [
                        Container(
                          width: 20, height: 20,
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: selected ? colors[m]! : AppColors.textHint, width: 2)),
                          child: selected ? Center(child: Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: colors[m]))) : null,
                        ),
                        const SizedBox(width: 10),
                        Icon(icons[m], size: 20, color: colors[m]),
                        const SizedBox(width: 8),
                        Text(labels[m]!, style: TextStyle(fontSize: 14, fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
                      ]),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                if (paymentMethod == 'debt')
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.warning.withAlpha(15), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.warning.withAlpha(40))),
                    child: const Row(children: [
                      Icon(Icons.info_outline, size: 16, color: AppColors.warning),
                      SizedBox(width: 8),
                      Expanded(child: Text('Phiếu chi sẽ được tạo ở trạng thái Nháp.\nThanh toán sau tại mục Thu chi.', style: TextStyle(fontSize: 12, color: AppColors.warning))),
                    ]),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteC,
                  decoration: const InputDecoration(labelText: 'Ghi chú thanh toán', prefixIcon: Icon(Icons.note), isDense: true),
                  onChanged: (v) => payNote = v,
                ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Huỷ')),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(dCtx, true),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Xác nhận duyệt'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              ),
            ],
          );
        },
      ),
    );
    if (confirmed != true) return;

    // ── 1. Update stock ──
    for (final item in r.items) {
      final productId = item['productId'] as String?;
      if (productId == null) continue;
      final product = dp.productById(productId);
      if (product == null) continue;
      final qty = ((item['receivedQty'] ?? item['qty']) as num?)?.toDouble() ?? 0;
      await dp.update('products', productId, {
        ...product.toJson(),
        'stock': product.stock + qty,
      });
    }

    // ── 2. Update receipt status → approved ──
    await dp.update('stockreceipts', r.id, {...r.toJson(), 'status': 'approved', 'approvedBy': dp.employees.isNotEmpty ? dp.employees.first.id : ''});

    // ── 3. Update linked PO → completed ──
    if (r.purchaseOrderId.isNotEmpty) {
      final po = dp.purchaseOrders.where((p) => p.id == r.purchaseOrderId).firstOrNull;
      if (po != null) {
        await dp.update('purchaseorders', po.id, {...po.toJson(), 'status': 'completed'});
      }
    }

    // ── 4. Create payment voucher (phiếu chi) for supplier ──
    final pcCode = _nextCode('PC', dp.paymentVouchers.where((v) => v.isPayment).map((v) => v.code));
    await dp.create('paymentvouchers', {
      'code': pcCode,
      'type': 'payment',
      'category': 'mua_hang',
      'amount': r.totalAmount,
      'contactName': supplier?.name ?? '',
      'contactId': r.supplierId,
      'contactType': 'supplier',
      'description': 'Thanh toán nhập kho ${r.code}${r.purchaseOrderId.isNotEmpty ? ' (từ PO)' : ''}',
      'date': DateTime.now().toIso8601String(),
      'paymentMethod': paymentMethod,
      'status': paymentMethod == 'debt' ? 'draft' : 'confirmed',
      'referenceId': r.id,
      'referenceType': 'stock_receipt',
      'note': payNote ?? '',
      'createdBy': dp.employees.isNotEmpty ? dp.employees.first.id : '',
      'approvedBy': paymentMethod != 'debt' ? (dp.employees.isNotEmpty ? dp.employees.first.id : '') : '',
    });

    final methodLabel = paymentMethod == 'cash' ? 'tiền mặt' : (paymentMethod == 'transfer' ? 'chuyển khoản' : 'công nợ');
    _snack('Đã duyệt ${r.code} — Tạo phiếu chi $pcCode ($methodLabel)');
    setState(() {});
  }

  Future<void> _approveIssue(StockIssue si) async {
    if (si.status != 'draft') { _snack('Phiếu đã được duyệt!'); return; }
    // Check stock sufficiency
    final insufficientItems = <String>[];
    for (final item in si.items) {
      final productId = item['productId'] as String?;
      if (productId == null) continue;
      final product = dp.productById(productId);
      if (product == null) continue;
      final qty = ((item['qty'] as num?) ?? 0).toDouble();
      if (qty > product.stock) {
        insufficientItems.add('${product.name}: cần ${qty.toStringAsFixed(0)}, tồn ${product.stock.toStringAsFixed(0)}');
      }
    }
    if (insufficientItems.isNotEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dCtx) => AlertDialog(
          title: const Row(children: [Icon(Icons.warning_rounded, color: AppColors.warning), SizedBox(width: 8), Text('Tồn kho không đủ')]),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            ...insufficientItems.map((s) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('• $s', style: const TextStyle(color: AppColors.error, fontSize: 13)))),
            const SizedBox(height: 12),
            const Text('Vẫn tiếp tục? (tồn sẽ về 0)', style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.textSecondary)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Huỷ')),
            FilledButton(onPressed: () => Navigator.pop(dCtx, true), style: FilledButton.styleFrom(backgroundColor: AppColors.warning), child: const Text('Tiếp tục')),
          ],
        ),
      );
      if (proceed != true) return;
    }
    // Deduct stock for each item
    for (final item in si.items) {
      final productId = item['productId'] as String?;
      if (productId == null) continue;
      final product = dp.productById(productId);
      if (product == null) continue;
      final qty = ((item['qty'] as num?) ?? 0).toDouble();
      final newStock = (product.stock - qty).clamp(0.0, double.infinity);
      await dp.update('products', productId, {
        ...product.toJson(),
        'stock': newStock,
      });
    }
    await dp.update('stockissues', si.id, {...si.toJson(), 'status': 'approved'});
    _snack('Đã duyệt xuất kho ${si.code} — tồn kho đã trừ');
    setState(() {});
  }

  Future<void> _approveStockTake(StockTake st) async {
    if (st.status != 'draft') { _snack('Phiếu đã được duyệt!'); return; }
    // Adjust stock to actual quantities
    for (final item in st.items) {
      final productId = item['productId'] as String?;
      if (productId == null) continue;
      final product = dp.productById(productId);
      if (product == null) continue;
      final actualQty = ((item['actualQty'] as num?) ?? 0).toDouble();
      await dp.update('products', productId, {
        ...product.toJson(),
        'stock': actualQty,
      });
    }
    await dp.update('stocktakes', st.id, {...st.toJson(), 'status': 'approved'});
    _snack('Đã duyệt kiểm kê ${st.code} — tồn kho đã điều chỉnh');
    setState(() {});
  }

  // ── HOÀN DUYỆT (Un-approve) ──

  Future<void> _unapproveReceipt(StockReceipt r) async {
    if (r.status != 'approved') return;
    // Find linked payment voucher
    final linkedVoucher = dp.paymentVouchers.where((v) => v.referenceId == r.id && v.referenceType == 'stock_receipt').firstOrNull;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Row(children: [Icon(Icons.undo_rounded, color: AppColors.warning), SizedBox(width: 8), Text('Hoàn duyệt nhập kho')]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hoàn duyệt ${r.code}?'),
          const SizedBox(height: 8),
          const Text('• Tồn kho sẽ bị trừ lại theo số lượng nhập', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const Text('• Phiếu sẽ chuyển về trạng thái Nháp', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          if (r.purchaseOrderId.isNotEmpty)
            const Text('• PO liên quan sẽ chuyển về chờ nhập hàng', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          if (linkedVoucher != null)
            Text('• Phiếu chi ${linkedVoucher.code} (${_currFmt.format(linkedVoucher.amount)}đ) sẽ bị huỷ', style: const TextStyle(fontSize: 13, color: AppColors.error)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(dCtx, true), style: FilledButton.styleFrom(backgroundColor: AppColors.warning), child: const Text('Hoàn duyệt')),
        ],
      ),
    );
    if (ok != true) return;
    // Revert stock
    for (final item in r.items) {
      final productId = item['productId'] as String?;
      if (productId == null) continue;
      final product = dp.productById(productId);
      if (product == null) continue;
      final qty = ((item['receivedQty'] ?? item['qty']) as num?)?.toDouble() ?? 0;
      final newStock = (product.stock - qty).clamp(0.0, double.infinity);
      await dp.update('products', productId, {...product.toJson(), 'stock': newStock});
    }
    // Revert receipt → draft
    await dp.update('stockreceipts', r.id, {...r.toJson(), 'status': 'draft', 'approvedBy': ''});
    // Revert linked PO → waiting_receipt
    if (r.purchaseOrderId.isNotEmpty) {
      final po = dp.purchaseOrders.where((p) => p.id == r.purchaseOrderId).firstOrNull;
      if (po != null) {
        await dp.update('purchaseorders', po.id, {...po.toJson(), 'status': 'waiting_receipt'});
      }
    }
    // Cancel linked payment voucher
    if (linkedVoucher != null) {
      await dp.update('paymentvouchers', linkedVoucher.id, {...linkedVoucher.toJson(), 'status': 'cancelled'});
    }
    _snack('Đã hoàn duyệt ${r.code} — tồn kho đã trừ lại${linkedVoucher != null ? ', đã huỷ ${linkedVoucher.code}' : ''}');
    setState(() {});
  }

  Future<void> _unapproveIssue(StockIssue si) async {
    if (si.status != 'approved') return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Row(children: [Icon(Icons.undo_rounded, color: AppColors.warning), SizedBox(width: 8), Text('Hoàn duyệt xuất kho')]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hoàn duyệt ${si.code}?'),
          const SizedBox(height: 8),
          const Text('• Tồn kho sẽ được cộng lại theo số lượng xuất', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const Text('• Phiếu sẽ chuyển về trạng thái Nháp', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(dCtx, true), style: FilledButton.styleFrom(backgroundColor: AppColors.warning), child: const Text('Hoàn duyệt')),
        ],
      ),
    );
    if (ok != true) return;
    // Revert stock (add back)
    for (final item in si.items) {
      final productId = item['productId'] as String?;
      if (productId == null) continue;
      final product = dp.productById(productId);
      if (product == null) continue;
      final qty = ((item['qty'] as num?) ?? 0).toDouble();
      await dp.update('products', productId, {...product.toJson(), 'stock': product.stock + qty});
    }
    await dp.update('stockissues', si.id, {...si.toJson(), 'status': 'draft', 'approvedBy': ''});
    _snack('Đã hoàn duyệt ${si.code} — tồn kho đã cộng lại');
    setState(() {});
  }

  Future<void> _unapproveStockTake(StockTake st) async {
    if (st.status != 'approved') return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Row(children: [Icon(Icons.undo_rounded, color: AppColors.warning), SizedBox(width: 8), Text('Hoàn duyệt kiểm kê')]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hoàn duyệt ${st.code}?'),
          const SizedBox(height: 8),
          const Text('• Tồn kho sẽ quay về số lượng hệ thống (trước kiểm kê)', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const Text('• Phiếu sẽ chuyển về trạng thái Nháp', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(dCtx, true), style: FilledButton.styleFrom(backgroundColor: AppColors.warning), child: const Text('Hoàn duyệt')),
        ],
      ),
    );
    if (ok != true) return;
    // Revert stock to systemQty
    for (final item in st.items) {
      final productId = item['productId'] as String?;
      if (productId == null) continue;
      final product = dp.productById(productId);
      if (product == null) continue;
      final systemQty = ((item['systemQty'] ?? item['qty']) as num?)?.toDouble() ?? product.stock;
      await dp.update('products', productId, {...product.toJson(), 'stock': systemQty});
    }
    await dp.update('stocktakes', st.id, {...st.toJson(), 'status': 'draft', 'approvedBy': ''});
    _snack('Đã hoàn duyệt ${st.code} — tồn kho đã khôi phục');
    setState(() {});
  }

  Future<void> _confirmDeleteApproved(String resource, String id, String code, String typeLabel) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Row(children: [Icon(Icons.delete_forever, color: AppColors.error), SizedBox(width: 8), Text('Xoá phiếu đã duyệt')]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Xoá phiếu $typeLabel "$code"?'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.error.withAlpha(12), borderRadius: BorderRadius.circular(8)),
            child: const Row(children: [
              Icon(Icons.warning_rounded, size: 16, color: AppColors.error),
              SizedBox(width: 8),
              Expanded(child: Text('Phiếu đã duyệt — tồn kho đã thay đổi.\nNên hoàn duyệt trước khi xoá để tồn kho chính xác.', style: TextStyle(fontSize: 12, color: AppColors.error))),
            ]),
          ),
        ]),
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
      _snack('Đã xoá phiếu $code');
      setState(() {});
    }
  }

  void _showPODetail(PurchaseOrder po) {
    final supplier = po.supplierId.isNotEmpty ? dp.supplierById(po.supplierId) : null;
    final branch = dp.branchById(po.branchId);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
                child: Row(children: [
                  Expanded(child: Text(po.code.isNotEmpty ? po.code : 'PO #${po.id}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                  _StatusChip(po.statusLabel, _statusColor(po.status)),
                  const SizedBox(width: 4),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                ]),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _simpleDetailRow('Nhà cung cấp', supplier?.name ?? po.supplier),
                    _simpleDetailRow('Chi nhánh', branch?.name ?? '—'),
                    _simpleDetailRow('Ngày', _dateFmt.format(po.date)),
                    if (po.note.isNotEmpty) _simpleDetailRow('Ghi chú', po.note),
                    const SizedBox(height: 16),
                    const Text('Danh sách hàng', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 8),
                    ...po.items.map((item) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          Expanded(child: Text(item['productName']?.toString() ?? 'SP', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                          Text('${item['qty']} ${item['unit'] ?? ''} × ${_currFmt.format(item['unitPrice'] ?? 0)}đ', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                          const SizedBox(width: 8),
                          Text('${_currFmt.format(((item['qty'] as num?) ?? 0) * ((item['unitPrice'] as num?) ?? 0))}đ', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        ],
                      ),
                    )),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text('Tổng cộng: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        Text('${_currFmt.format(po.total)}đ', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.primary)),
                      ],
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _simpleDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        ],
      ),
    );
  }

  // ── GENERIC DOCUMENT DETAIL SHEET ──
  void _showDocSheet({
    required String title,
    required String statusLabel,
    required Color statusColor,
    required List<(String, String)> info,
    required List<Map<String, dynamic>> items,
    String qtyKey = 'qty',
    bool showDiff = false,
    double? total,
    Color? totalColor,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
                child: Row(children: [
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                  _StatusChip(statusLabel, statusColor),
                  const SizedBox(width: 4),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                ]),
              ),
              const Divider(height: 1),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    ...info.map((e) => _simpleDetailRow(e.$1, e.$2)),
                    const SizedBox(height: 16),
                    const Text('Danh sách hàng', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 8),
                    ...items.map((item) {
                      final name = item['productName']?.toString() ?? 'SP';
                      final qty = item[qtyKey] ?? item['qty'] ?? 0;
                      final unit = item['unit']?.toString() ?? '';
                      final price = item['unitPrice'] as num?;
                      final diff = item['diff'] as num?;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(10)),
                        child: Row(children: [
                          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                          Text('$qty $unit', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                          if (showDiff && diff != null) ...[
                            const SizedBox(width: 8),
                            Text('(${diff > 0 ? '+' : ''}${(diff is double) ? diff.toStringAsFixed(0) : diff})',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                                color: diff > 0 ? AppColors.success : diff < 0 ? AppColors.error : AppColors.textSecondary)),
                          ],
                          if (!showDiff && price != null) ...[
                            const SizedBox(width: 8),
                            Text('${_currFmt.format((qty as num) * price)}đ', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          ],
                        ]),
                      );
                    }),
                    if (total != null && total > 0) ...[
                      const Divider(),
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        const Text('Tổng: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        Text('${_currFmt.format(total)}đ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: totalColor ?? AppColors.primary)),
                      ]),
                    ],
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _confirmDelete(String resource, String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Xác nhận xoá'),
        content: Text('Bạn có chắc muốn xoá "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Huỷ')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await dp.remove(resource, id);
      setState(() {});
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Widget _moreMenu({VoidCallback? onEdit, VoidCallback? onDelete, List<PopupMenuEntry<String>>? extra}) {
    final hasItems = onEdit != null || onDelete != null || (extra != null && extra.isNotEmpty);
    if (!hasItems) return const SizedBox(width: 40);
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20),
      onSelected: (v) {
        if (v == 'edit' && onEdit != null) onEdit();
        if (v == 'delete' && onDelete != null) onDelete();
      },
      itemBuilder: (ctx) => [
        if (extra != null) ...extra,
        if (onEdit != null)
          const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit, size: 20), title: Text('Sửa'), dense: true, contentPadding: EdgeInsets.zero)),
        if (onDelete != null)
          const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, color: AppColors.error, size: 20), title: Text('Xoá', style: TextStyle(color: AppColors.error)), dense: true, contentPadding: EdgeInsets.zero)),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'draft': return AppColors.textHint;
      case 'approved': return AppColors.primary;
      case 'sent': return const Color(0xFF2563EB);
      case 'waiting_receipt': return AppColors.warning;
      case 'partially_received': return AppColors.warning;
      case 'completed': return AppColors.success;
      case 'cancelled': return AppColors.error;
      case 'pending': return AppColors.warning;
      default: return AppColors.textSecondary;
    }
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'feed': return Icons.restaurant_rounded;
      case 'seed': return Icons.eco_rounded;
      case 'chemical': return Icons.science_rounded;
      case 'medicine': return Icons.medical_services_rounded;
      case 'accessory': return Icons.build_rounded;
      default: return Icons.inventory_2_rounded;
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// HELPER WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

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
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _EmptyMsg extends StatelessWidget {
  final IconData icon;
  final String msg;
  const _EmptyMsg({required this.icon, required this.msg});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: AppColors.textHint.withAlpha(80)),
          const SizedBox(height: 12),
          Text(msg, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }
}

class _SearchBox extends StatefulWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  const _SearchBox({required this.hint, required this.onChanged});
  @override
  State<_SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<_SearchBox> {
  final _ctrl = TextEditingController();
  bool _hasText = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
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
          hintStyle: const TextStyle(fontSize: 12),
          prefixIcon: const Icon(Icons.search, size: 18),
          suffixIcon: _hasText
              ? GestureDetector(
                  onTap: () { _ctrl.clear(); widget.onChanged(''); setState(() => _hasText = false); },
                  child: const Icon(Icons.close, size: 16),
                )
              : null,
          suffixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 20),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: AppColors.primary)),
          filled: true,
          fillColor: AppColors.surfaceVariant,
        ),
      ),
    );
  }
}

class _DropFilter extends StatelessWidget {
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;
  const _DropFilter({required this.value, required this.items, required this.onChanged});
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

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;
  const _ToggleChip({required this.label, required this.active, required this.onTap, this.icon});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.error : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? AppColors.error : AppColors.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon!, size: 14, color: active ? Colors.white : AppColors.textSecondary), const SizedBox(width: 4)],
          Text(label, style: TextStyle(color: active ? Colors.white : AppColors.textSecondary, fontWeight: active ? FontWeight.w600 : FontWeight.w400, fontSize: 13)),
        ]),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withAlpha(15), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _ClearFilterChip extends StatelessWidget {
  final VoidCallback onPressed;
  const _ClearFilterChip({required this.onPressed});
  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.clear, size: 14),
      label: const Text('Xoá lọc', style: TextStyle(fontSize: 12)),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
    );
  }
}
