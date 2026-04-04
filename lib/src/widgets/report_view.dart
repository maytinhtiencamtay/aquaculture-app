import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../models/pond.dart';
import '../models/size_measurement.dart';
import '../models/payment_voucher.dart';
import '../providers/data_provider.dart';
import '../theme/app_theme.dart';
import '../services/export_service.dart';
import 'shared_widgets.dart';

// ═════════════════════════════════════════════════════════════════════════════
// BÁO CÁO TỔNG HỢP – Dashboard + Data Tables
// Tabs: Tổng quan | Thông số nước | Lô cá | Hàng hóa | Khách hàng | Doanh thu & Lợi nhuận
// ═════════════════════════════════════════════════════════════════════════════

final _cFmt = NumberFormat('#,###', 'vi');
final _dFmt = DateFormat('dd/MM/yyyy');
final _nFmt = NumberFormat('#,##0.#', 'vi');

class ReportView extends StatefulWidget {
  final DataProvider dp;
  const ReportView({super.key, required this.dp});
  @override
  State<ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends State<ReportView> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _captureKey = GlobalKey();
  DataProvider get dp => widget.dp;

  // Filter state per tab
  String _waterStatus = 'all';
  String _waterQuality = 'all';
  String _batchStatus = 'all';
  String _batchPeriod = 'all';
  String _prodCategory = 'all';
  bool _prodLowStock = false;
  String _custType = 'all';
  bool _custDebtOnly = false;
  String _saleStatus = 'all';
  String _salePeriod = 'all';
  String _cashType = 'all';
  String _cashMethod = 'all';
  String _cashPeriod = 'all';

  // Feed tab filters
  String _feedSpecies = 'all';
  String _feedPeriod = 'all';
  // Growth tab filters
  String _growthSpecies = 'all';
  String _growthPeriod = 'all';
  // Mortality tab filters
  String _mortPeriod = 'all';
  String _mortCause = 'all';
  // Disease tab filters
  String _diseaseStatus = 'all';
  String _diseaseSeverity = 'all';
  String _diseasePeriod = 'all';
  // Stock IO tab filters
  String _stockIOType = 'all';
  String _stockIOStatus = 'all';
  String _stockIOPeriod = 'all';
  // Staff tab filters
  String _staffRole = 'all';
  String _staffTaskStatus = 'all';
  String _staffPeriod = 'all';
  // Profit tab filter
  String _profitResult = 'all';

  // Lazy loading flags for tabs that call API
  bool _profitLoaded = false;
  bool _supplierDebtLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 15, vsync: this);
    _tabCtrl.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabCtrl.indexIsChanging) return; // ignore animation
    setState(() {}); // rebuild category chips
    final idx = _tabCtrl.index;
    if (idx == 8 && !_profitLoaded) {
      _profitLoaded = true;
      dp.loadProfitAnalysis();
    } else if (idx == 10 && !_supplierDebtLoaded) {
      _supplierDebtLoaded = true;
      dp.loadSupplierDebts();
    }
  }

  @override
  void dispose() {
    _tabCtrl.removeListener(_onTabChanged);
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Export helpers ──
  void _exportExcel() {
    final tab = _tabCtrl.index;
    switch (tab) {
      case 0: _exportOverview();
      case 1: _exportWater();
      case 2: _exportBatches();
      case 3: _exportFeed();
      case 4: _exportGrowth();
      case 5: _exportMortality();
      case 6: _exportDisease();
      case 7: _exportRevenue();
      case 8: _exportProfit();
      case 9: _exportCustomers();
      case 10: _exportSupplierDebt();
      case 11: _exportCashBook();
      case 12: _exportProducts();
      case 13: _exportStockIO();
      case 14: _exportStaff();
      default: _exportAll();
    }
  }

  void _exportAll() {
    final sheets = <ExcelSheetData>[
      ExcelSheetData(name: 'Lô cá', headers: ['Tên', 'Ao', 'Loài', 'Ngày thả', 'SL ban đầu', 'SL hiện tại', 'Trọng lượng(g)', 'Hao hụt', 'Thức ăn(kg)', 'Trạng thái'],
          rows: dp.fishBatches.map((b) {
            final pond = dp.ponds.where((p) => p.id == b.pondId).firstOrNull;
            final sp = dp.species.where((s) => s.id == b.speciesId).firstOrNull;
            return [b.name, pond?.code ?? '', sp?.name ?? '', _dFmt.format(b.stockingDate), b.initialQuantity, b.currentQuantity, b.currentWeight, b.mortalityQuantity, b.feedConsumed, b.statusLabel];
          }).toList()),
      ExcelSheetData(name: 'Hàng hóa', headers: ['Mã SKU', 'Tên', 'Danh mục', 'Đơn vị', 'Giá bán', 'Giá vốn', 'Tồn kho', 'Giá trị'],
          rows: dp.products.map((p) => [p.sku, p.name, p.categoryLabel, p.unit, p.price, p.costPrice, p.stock, p.stockValue]).toList()),
      ExcelSheetData(name: 'Khách hàng', headers: ['Tên', 'Loại', 'Công ty', 'SĐT', 'Công nợ', 'Ghi chú'],
          rows: dp.customers.map((c) => [c.name, c.typeLabel, c.company, c.phone, c.debt, c.note]).toList()),
      ExcelSheetData(name: 'Phiếu thu chi', headers: ['Mã', 'Loại', 'Số tiền', 'Đối tác', 'Ngày', 'Trạng thái'],
          rows: dp.paymentVouchers.map((v) => [v.code, v.typeLabel, v.amount, v.contactName, _dFmt.format(v.date), v.statusLabel]).toList()),
    ];
    ExportService.exportMultiSheetAndNotify(context: context, sheets: sheets, filePrefix: 'bao_cao', label: 'Báo cáo tổng hợp');
  }

  void _exportWater() {
    final headers = ['Ao', 'pH', 'DO (mg/L)', 'Nhiệt độ (°C)', 'NH3', 'Kiềm', 'Trạng thái'];
    final rows = dp.ponds.map((p) => [
      p.code, p.currentPh ?? '', p.currentDo ?? '', p.currentTemp ?? '',
      p.currentNh3 ?? '', p.currentAlkalinity ?? '', p.statusLabel,
    ]).toList();
    ExportService.exportExcelAndNotify(context: context, sheetName: 'Thông số nước', headers: headers, rows: rows, filePrefix: 'thong_so_nuoc');
  }

  void _exportBatches() {
    final headers = ['Tên', 'Ao', 'Loài', 'Ngày thả', 'SL ban đầu', 'SL hiện tại', 'Trọng lượng(g)', 'Hao hụt', 'Thức ăn(kg)', 'Nguồn gốc', 'Trạng thái'];
    final rows = dp.fishBatches.map((b) {
      final pond = dp.ponds.where((p) => p.id == b.pondId).firstOrNull;
      final sp = dp.species.where((s) => s.id == b.speciesId).firstOrNull;
      return [b.name, pond?.code ?? '', sp?.name ?? '', _dFmt.format(b.stockingDate), b.initialQuantity, b.currentQuantity, b.currentWeight, b.mortalityQuantity, b.feedConsumed, b.source, b.statusLabel];
    }).toList();
    ExportService.exportExcelAndNotify(context: context, sheetName: 'Lô cá', headers: headers, rows: rows, filePrefix: 'lo_ca');
  }

  void _exportProducts() {
    final headers = ['Mã SKU', 'Tên', 'Danh mục', 'Thương hiệu', 'Đơn vị', 'Giá bán', 'Giá vốn', 'Tồn kho', 'Tồn tối thiểu', 'Giá trị kho'];
    final rows = dp.products.map((p) => [p.sku, p.name, p.categoryLabel, p.brand, p.unit, p.price, p.costPrice, p.stock, p.minStock, p.stockValue]).toList();
    ExportService.exportExcelAndNotify(context: context, sheetName: 'Hàng hóa', headers: headers, rows: rows, filePrefix: 'hang_hoa');
  }

  void _exportCustomers() {
    final headers = ['Tên', 'Loại', 'Công ty', 'SĐT', 'Email', 'Địa chỉ', 'Công nợ', 'Ghi chú'];
    final rows = dp.customers.map((c) => [c.name, c.typeLabel, c.company, c.phone, c.email, c.address, c.debt, c.note]).toList();
    ExportService.exportExcelAndNotify(context: context, sheetName: 'Khách hàng', headers: headers, rows: rows, filePrefix: 'khach_hang');
  }

  void _exportRevenue() {
    final headers = ['Mã', 'Khách hàng', 'Ngày', 'Tổng tiền', 'Trạng thái'];
    final rows = dp.saleOrders.map((o) {
      final cust = dp.customers.where((c) => c.id == o.customerId).firstOrNull;
      return [o.id.substring(0, 8), cust?.name ?? '', _dFmt.format(o.date), o.totalAmount, o.statusLabel];
    }).toList();
    ExportService.exportExcelAndNotify(context: context, sheetName: 'Doanh thu', headers: headers, rows: rows, filePrefix: 'doanh_thu');
  }

  void _exportCashBook() {
    final headers = ['Mã', 'Loại', 'Danh mục', 'Số tiền', 'Đối tác', 'Ngày', 'Thanh toán', 'Trạng thái'];
    final rows = dp.paymentVouchers.map((v) => [
      v.code, v.typeLabel, v.categoryLabel, v.amount,
      v.contactName, _dFmt.format(v.date),
      v.paymentMethod == 'cash' ? 'Tiền mặt' : v.paymentMethod == 'transfer' ? 'Chuyển khoản' : 'Thẻ',
      v.statusLabel,
    ]).toList();
    ExportService.exportExcelAndNotify(context: context, sheetName: 'Sổ quỹ', headers: headers, rows: rows, filePrefix: 'so_quy');
  }

  void _exportOverview() {
    final activeBatches = dp.fishBatches.where((b) => b.status == 'active').toList();
    final totalBiomass = activeBatches.fold(0.0, (s, b) => s + (b.currentWeight * b.currentQuantity / 1000));
    final completedSales = dp.saleOrders.where((o) => o.status == 'completed');
    final totalRevenue = completedSales.fold(0.0, (s, o) => s + o.totalAmount);
    final completedPurchases = dp.purchaseOrders.where((o) => o.status == 'completed');
    final totalCost = completedPurchases.fold(0.0, (s, o) => s + o.total);
    final headers = ['Chỉ số', 'Giá trị'];
    final rows = <List<dynamic>>[
      ['Số ao', dp.ponds.length],
      ['Lô đang nuôi', activeBatches.length],
      ['Tổng cá', activeBatches.fold<int>(0, (s, b) => s + b.currentQuantity)],
      ['Sinh khối (kg)', totalBiomass.toStringAsFixed(1)],
      ['Tổng doanh thu', totalRevenue],
      ['Tổng chi phí', totalCost],
      ['Lợi nhuận gộp', totalRevenue - totalCost],
      ['Tổng khách hàng', dp.customers.length],
      ['Tổng sản phẩm', dp.products.length],
      ['Nhân viên', dp.employees.length],
    ];
    ExportService.exportExcelAndNotify(context: context, sheetName: 'Tổng quan', headers: headers, rows: rows, filePrefix: 'tong_quan');
  }

  void _exportProfit() {
    final headers = ['Lô cá', 'Doanh thu', 'Chi TĂ', 'Chi khác', 'Tổng chi', 'Lợi nhuận'];
    final rows = dp.profitAnalysis.map((item) => [
      item['batchName']?.toString() ?? '',
      (item['revenue'] as num?)?.toDouble() ?? 0,
      (item['feedCost'] as num?)?.toDouble() ?? 0,
      (item['otherCost'] as num?)?.toDouble() ?? 0,
      (item['totalCost'] as num?)?.toDouble() ?? 0,
      (item['profit'] as num?)?.toDouble() ?? 0,
    ]).toList();
    ExportService.exportExcelAndNotify(context: context, sheetName: 'Lãi lỗ', headers: headers, rows: rows, filePrefix: 'lai_lo');
  }

  void _exportSupplierDebt() {
    final headers = ['Nhà cung cấp', 'Tổng mua', 'Đã trả', 'Còn nợ'];
    final rows = dp.supplierDebts.map((d) => [
      d['supplierName']?.toString() ?? '',
      (d['totalPurchase'] as num?)?.toDouble() ?? 0,
      (d['totalPaid'] as num?)?.toDouble() ?? 0,
      (d['debt'] as num?)?.toDouble() ?? 0,
    ]).toList();
    ExportService.exportExcelAndNotify(context: context, sheetName: 'Nợ NCC', headers: headers, rows: rows, filePrefix: 'no_ncc');
  }

  void _exportFeed() {
    final batches = dp.fishBatches.where((b) => b.status == 'active').toList();
    final headers = ['Ao', 'Loài', 'SL cá', 'TL/con (g)', 'Sinh khối (kg)', 'Hệ số TĂ', 'TĂ/ngày (kg)', 'Tổng TĂ (kg)', 'FCR', 'Chi phí TĂ', 'Ngày nuôi'];
    final rows = batches.map((b) {
      final pond = dp.pondById(b.pondId);
      final sp = dp.speciesById(b.speciesId);
      final wt = b.currentWeight > 0 ? b.currentWeight : b.initialWeight;
      final biomass = b.currentQuantity * wt / 1000;
      final feedRatio = sp?.feedRatio ?? 1.5;
      final dailyKg = biomass * feedRatio / 100;
      return [pond?.code ?? '', sp?.name ?? '', b.currentQuantity, wt, biomass, feedRatio, dailyKg, b.feedConsumed, b.fcr, 0.0, b.daysOfCulture];
    }).toList();
    ExportService.exportExcelAndNotify(context: context, sheetName: 'Thức ăn', headers: headers, rows: rows, filePrefix: 'thuc_an');
  }

  void _exportGrowth() {
    final batches = dp.fishBatches.where((b) => b.status == 'active').toList();
    final sheets = <ExcelSheetData>[
      ExcelSheetData(
        name: 'Tăng trưởng',
        headers: ['Ao', 'Loài', 'TL ban đầu (g)', 'TL hiện tại (g)', 'Tăng (g)', 'Tốc độ (g/ngày)', 'KT ban đầu (cm)', 'KT hiện tại (cm)', 'Ngày nuôi', 'Tiến độ (%)'],
        rows: batches.map((b) {
          final pond = dp.pondById(b.pondId);
          final sp = dp.speciesById(b.speciesId);
          final lastW = b.currentWeight > 0 ? b.currentWeight : b.initialWeight;
          final gain = lastW - b.initialWeight;
          final days = b.daysOfCulture.clamp(1, 9999);
          final daily = gain / days;
          final targetW = sp?.harvestableWeight ?? 500;
          final progress = targetW > 0 ? (lastW / targetW * 100).clamp(0, 200) : 0;
          return [pond?.code ?? '', sp?.name ?? '', b.initialWeight, lastW, gain, daily, b.initialSize, b.currentSize, days, progress];
        }).toList(),
      ),
      ExcelSheetData(
        name: 'Lịch sử đo',
        headers: ['Ngày đo', 'Ao', 'Loài', 'TL mẫu (g)', 'KT mẫu (cm)', 'Số mẫu', 'SL ước tính', 'Người đo', 'Ghi chú'],
        rows: dp.sizeMeasurements.map((m) {
          final b = dp.fishBatches.where((b) => b.id == m.fishBatchId).firstOrNull;
          final sp = b != null ? dp.speciesById(b.speciesId) : null;
          final pond = dp.pondById(m.pondId);
          return [_dFmt.format(m.date), pond?.code ?? '', sp?.name ?? '', m.avgWeight, m.avgLength, m.sampleCount, m.remainingQty, m.measuredBy, m.note];
        }).toList(),
      ),
    ];
    ExportService.exportMultiSheetAndNotify(context: context, sheets: sheets, filePrefix: 'tang_truong', label: 'Tăng trưởng');
  }

  void _exportMortality() {
    final batches = dp.fishBatches.where((b) => b.status == 'active').toList();
    final sheets = <ExcelSheetData>[
      ExcelSheetData(
        name: 'Hao hụt theo lô',
        headers: ['Ao', 'Loài', 'SL ban đầu', 'SL hiện tại', 'Hao hụt', 'Tỷ lệ sống (%)'],
        rows: batches.map((b) {
          final pond = dp.pondById(b.pondId);
          final sp = dp.speciesById(b.speciesId);
          return [pond?.code ?? '', sp?.name ?? '', b.initialQuantity, b.currentQuantity, b.mortalityQuantity, b.survivalRate];
        }).toList(),
      ),
      ExcelSheetData(
        name: 'Chi tiết hao hụt',
        headers: ['Ngày', 'Ao', 'Lô cá', 'Số lượng', 'Nguyên nhân', 'Ghi chú'],
        rows: dp.mortalityLogs.map((ml) {
          final bid = ml['fishBatchId'] as String? ?? '';
          final pid = ml['pondId'] as String? ?? '';
          final pond = dp.pondById(pid);
          final batch = dp.fishBatches.where((b) => b.id == bid).firstOrNull;
          final sp = batch != null ? dp.speciesById(batch.speciesId) : null;
          return [ml['date'] ?? '', pond?.code ?? '', sp?.name ?? '', (ml['quantity'] as num?)?.toInt() ?? 0, ml['cause'] ?? '', ml['note'] ?? ''];
        }).toList(),
      ),
    ];
    ExportService.exportMultiSheetAndNotify(context: context, sheets: sheets, filePrefix: 'hao_hut', label: 'Hao hụt');
  }

  void _exportDisease() {
    final sheets = <ExcelSheetData>[
      ExcelSheetData(
        name: 'Bệnh',
        headers: ['Ngày', 'Ao', 'Bệnh', 'Mức độ', 'Trạng thái', 'Triệu chứng'],
        rows: dp.diseaseLogs.map((d) {
          final pond = dp.pondById(d.pondId);
          return [_dFmt.format(d.detectedDate), pond?.code ?? '', d.diseaseName, d.severity, d.status, d.symptoms];
        }).toList(),
      ),
      ExcelSheetData(
        name: 'Điều trị',
        headers: ['Ao', 'Thuốc', 'Liều lượng', 'Cách dùng', 'Ngày BĐ', 'Thời gian (ngày)', 'Cách ly (ngày)', 'Trạng thái'],
        rows: dp.treatmentLogs.map((t) {
          final pond = dp.pondById(t.pondId);
          return [pond?.code ?? '', t.medicineName, '${t.dosage} ${t.dosageUnit}', t.method, _dFmt.format(t.startDate), t.durationDays, t.withdrawalDays, t.status];
        }).toList(),
      ),
    ];
    ExportService.exportMultiSheetAndNotify(context: context, sheets: sheets, filePrefix: 'benh_dieu_tri', label: 'Bệnh & Điều trị');
  }

  void _exportStockIO() {
    final sheets = <ExcelSheetData>[
      ExcelSheetData(
        name: 'Phiếu nhập',
        headers: ['Mã', 'Ngày', 'NCC', 'Giá trị', 'Trạng thái'],
        rows: dp.stockReceipts.map((r) {
          final sup = dp.suppliers.where((s) => s.id == r.supplierId).firstOrNull;
          return [r.code, _dFmt.format(r.date), sup?.name ?? '', r.totalAmount, r.status == 'approved' ? 'Đã duyệt' : r.status == 'draft' ? 'Nháp' : 'Huỷ'];
        }).toList(),
      ),
      ExcelSheetData(
        name: 'Phiếu xuất',
        headers: ['Mã', 'Ngày', 'Loại', 'Ao', 'Giá trị', 'Trạng thái'],
        rows: dp.stockIssues.map((i) {
          final pond = dp.pondById(i.pondId);
          final typeLabel = i.type == 'feeding' ? 'Cho ăn' : i.type == 'sale' ? 'Bán' : i.type == 'usage' ? 'Sử dụng' : i.type;
          return [i.code, _dFmt.format(i.date), typeLabel, pond?.code ?? '', i.totalAmount, i.status == 'approved' ? 'Đã duyệt' : i.status == 'draft' ? 'Nháp' : 'Huỷ'];
        }).toList(),
      ),
    ];
    ExportService.exportMultiSheetAndNotify(context: context, sheets: sheets, filePrefix: 'nhap_xuat_kho', label: 'Nhập/Xuất kho');
  }

  void _exportStaff() {
    final sheets = <ExcelSheetData>[
      ExcelSheetData(
        name: 'Nhân viên',
        headers: ['Tên', 'Chức vụ', 'SĐT', 'Email'],
        rows: dp.employees.map((e) => [e.name, e.role, e.phone, e.email]).toList(),
      ),
      ExcelSheetData(
        name: 'Công việc',
        headers: ['Tiêu đề', 'Ao', 'Nhân viên', 'Loại', 'Hạn', 'Trạng thái'],
        rows: dp.tasks.map((t) {
          final pond = dp.pondById(t.pondId);
          final emp = dp.employeeById(t.assignedTo);
          return [t.title, pond?.code ?? '', emp?.name ?? '', t.type, _dFmt.format(t.dueDate), t.status == 'done' ? 'Xong' : t.isOverdue ? 'Quá hạn' : 'Chờ'];
        }).toList(),
      ),
    ];
    ExportService.exportMultiSheetAndNotify(context: context, sheets: sheets, filePrefix: 'nhan_su', label: 'Nhân sự & CV');
  }

  void _exportPng() {
    ExportService.exportPngAndNotify(context: context, captureKey: _captureKey, filePrefix: 'bao_cao');
  }

  // ── Period filter constants & helper ──
  static const _periodItems = {'all': 'Tất cả', 'today': 'Hôm nay', 'week': '7 ngày', 'month': '30 ngày', 'quarter': '90 ngày', 'year': '1 năm'};

  DateTime? _periodCutoff(String period) {
    if (period == 'all') return null;
    final now = DateTime.now();
    return switch (period) {
      'today' => DateTime(now.year, now.month, now.day),
      'week' => now.subtract(const Duration(days: 7)),
      'month' => now.subtract(const Duration(days: 30)),
      'quarter' => now.subtract(const Duration(days: 90)),
      'year' => now.subtract(const Duration(days: 365)),
      _ => null,
    };
  }

  bool _afterCutoff(DateTime date, DateTime? cutoff) => cutoff == null || !date.isBefore(cutoff);

  bool _afterCutoffStr(String? dateStr, DateTime? cutoff) {
    if (cutoff == null) return true;
    if (dateStr == null || dateStr.length < 10) return false;
    final d = DateTime.tryParse(dateStr);
    return d != null && !d.isBefore(cutoff);
  }

  // Removed _buildFilterBar — using AppFilterBar from shared_widgets

  @override
  Widget build(BuildContext context) {
    context.watch<DataProvider>();
    return RepaintBoundary(
      key: _captureKey,
      child: Column(
      children: [
        // ── Header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF6366F1)]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: const Color(0xFF3B82F6).withAlpha(40), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Báo cáo tổng hợp', style: AppText.title.copyWith(fontSize: 18)),
                    const SizedBox(height: 2),
                    Text('Dashboard & Bảng dữ liệu chi tiết', style: AppText.body.copyWith(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              _headerAction(Icons.table_chart_outlined, 'Excel', _exportExcel),
              const SizedBox(width: 4),
              _headerAction(Icons.image_outlined, 'PNG', _exportPng),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Category chips ──
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: List.generate(_categoryLabels.length, (i) {
              final active = _activeCategory == i;
              return Padding(
                padding: EdgeInsets.only(right: i < _categoryLabels.length - 1 ? 8 : 0),
                child: GestureDetector(
                  onTap: () => _tabCtrl.animateTo(_categoryStartTab[i]),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: active ? _categoryColors[i].withAlpha(15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: active ? _categoryColors[i] : AppColors.border, width: active ? 1.5 : 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_categoryIcons[i], size: 14, color: active ? _categoryColors[i] : AppColors.textHint),
                        const SizedBox(width: 6),
                        Text(_categoryLabels[i], style: TextStyle(
                          fontSize: 12, fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                          color: active ? _categoryColors[i] : AppColors.textSecondary,
                        )),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),

        // ── Tab bar ──
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(12)),
          child: TabBar(
            controller: _tabCtrl,
            isScrollable: true,
            padding: const EdgeInsets.all(4),
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 12.5),
            indicator: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4)]),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            dividerHeight: 0,
            tabAlignment: TabAlignment.start,
            tabs: [
              // ★ Tổng quan
              Tab(child: _tl(Icons.dashboard_rounded, 'Tổng quan')),
              // 🐟 Nuôi trồng
              Tab(child: _tlSep(Icons.water_drop_rounded, 'Nước')),
              Tab(child: _tl(Icons.set_meal_rounded, 'Lô cá')),
              Tab(child: _tl(Icons.restaurant_rounded, 'Thức ăn')),
              Tab(child: _tl(Icons.trending_up_rounded, 'Tăng trưởng')),
              Tab(child: _tl(Icons.heart_broken_rounded, 'Hao hụt')),
              Tab(child: _tl(Icons.coronavirus_rounded, 'Bệnh & ĐT')),
              // 💰 Kinh doanh
              Tab(child: _tlSep(Icons.monetization_on_rounded, 'Doanh thu')),
              Tab(child: _tl(Icons.analytics_rounded, 'Lãi/Lỗ')),
              Tab(child: _tl(Icons.people_rounded, 'Khách hàng')),
              Tab(child: _tl(Icons.account_balance_wallet_rounded, 'Nợ NCC')),
              // 📋 Quản lý
              Tab(child: _tlSep(Icons.menu_book_rounded, 'Sổ quỹ')),
              Tab(child: _tl(Icons.inventory_2_rounded, 'Hàng hóa')),
              Tab(child: _tl(Icons.swap_horiz_rounded, 'Nhập/Xuất kho')),
              Tab(child: _tl(Icons.groups_rounded, 'Nhân sự')),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildOverviewTab(),    // 0  (was 0)
              _buildWaterTab(),       // 1  (was 1)
              _buildBatchTab(),       // 2  (was 2)
              _buildFeedTab(),        // 3  (was 9)
              _buildGrowthTab(),      // 4  (was 10)
              _buildMortalityTab(),   // 5  (was 11)
              _buildDiseaseTab(),     // 6  (was 12)
              _buildRevenueTab(),     // 7  (was 5)
              _buildProfitTab(),      // 8  (was 6)
              _buildCustomerTab(),    // 9  (was 4)
              _buildSupplierDebtTab(),// 10 (was 7)
              _buildCashBookTab(),    // 11 (was 8)
              _buildProductTab(),     // 12 (was 3)
              _buildStockIOTab(),     // 13 (was 13)
              _buildStaffTab(),       // 14 (was 14)
            ],
          ),
        ),
      ],
    ),
    );
  }

  // ── Category navigation data ──
  static const _categoryLabels = ['Tổng quan', 'Nuôi trồng', 'Kinh doanh', 'Quản lý'];
  static const _categoryIcons = [Icons.dashboard_rounded, Icons.water_rounded, Icons.monetization_on_rounded, Icons.settings_rounded];
  static const _categoryColors = [Color(0xFF3B82F6), Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFF8B5CF6)];
  static const _categoryStartTab = [0, 1, 7, 11];
  int get _activeCategory {
    final idx = _tabCtrl.index;
    if (idx >= 11) return 3;
    if (idx >= 7) return 2;
    if (idx >= 1) return 1;
    return 0;
  }

  Widget _tl(IconData ic, String t) => Row(mainAxisSize: MainAxisSize.min, children: [Icon(ic, size: 15), const SizedBox(width: 5), Text(t)]);
  /// Tab label with left separator dot (first tab of a group)
  Widget _tlSep(IconData ic, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 3, height: 3, margin: const EdgeInsets.only(right: 8), decoration: const BoxDecoration(color: AppColors.textHint, shape: BoxShape.circle)),
    Icon(ic, size: 15), const SizedBox(width: 5), Text(t),
  ]);
  /// Header action button
  Widget _headerAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TAB 1: TỔNG QUAN DASHBOARD
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildOverviewTab() {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final prevMonthStart = DateTime(now.year, now.month - 1, 1);

    // ── Nuôi trồng ──
    final activeBatches = dp.fishBatches.where((b) => b.status == 'active').toList();
    final totalBiomassKg = activeBatches.fold(0.0, (s, b) => s + (b.currentWeight * b.currentQuantity / 1000));
    final avgSurvivalRate = activeBatches.isNotEmpty
        ? activeBatches.fold(0.0, (s, b) => s + b.survivalRate) / activeBatches.length : 0.0;
    final avgFcr = activeBatches.where((b) => b.fcr > 0).isEmpty ? 0.0
        : activeBatches.where((b) => b.fcr > 0).fold(0.0, (s, b) => s + b.fcr) / activeBatches.where((b) => b.fcr > 0).length;

    // ── Tài chính — chỉ đơn đã hoàn thành ──
    final completedSales = dp.saleOrders.where((o) => o.status == 'completed');
    final totalRevenue = completedSales.fold(0.0, (s, o) => s + o.totalAmount);
    final completedPurchases = dp.purchaseOrders.where((o) => o.status == 'completed');
    final totalCost = completedPurchases.fold(0.0, (s, o) => s + o.total);
    final grossProfit = totalRevenue - totalCost;

    // ── Tháng này vs tháng trước ──
    final salesThisMonth = completedSales.where((o) => o.date.isAfter(monthStart) || o.date.isAtSameMomentAs(monthStart)).fold(0.0, (s, o) => s + o.totalAmount);
    final salesPrevMonth = completedSales.where((o) => o.date.isAfter(prevMonthStart) && o.date.isBefore(monthStart)).fold(0.0, (s, o) => s + o.totalAmount);

    // ── Thu chi thực tế ──
    final cashIn = dp.totalReceipts;
    final cashOut = dp.totalPayments;
    final cashBalance = cashIn - cashOut;

    // ── Cảnh báo nước (dùng WaterStandard nếu có) ──
    final phWarnings = dp.ponds.where((p) => p.currentPh != null && (p.currentPh! > 8.5 || p.currentPh! < 6.5)).length;
    final doWarnings = dp.ponds.where((p) => p.currentDo != null && p.currentDo! < 4).length;
    final nh3Warnings = dp.ponds.where((p) => p.currentNh3 != null && p.currentNh3! > 0.1).length;
    final totalWaterWarnings = phWarnings + doWarnings + nh3Warnings;

    // ── Công việc ──
    final pendingTasks = dp.pendingTasks;
    final overdueTasks = dp.overdueTasks;

    // ── Tồn kho ──
    final outOfStock = dp.products.where((p) => p.stock <= 0 && p.isActive).length;
    final lowStock = dp.lowStockCount;

    return LayoutBuilder(builder: (context, box) {
      final narrow = box.maxWidth < 500;
      Widget kpiRow(List<Widget> children) {
        if (!narrow) return Row(children: children);
        // Split into pairs for narrow layout
        final pairs = <Widget>[];
        for (int i = 0; i < children.length; i += 2) {
          final rowItems = <Widget>[children[i]];
          if (i + 1 < children.length) {
            rowItems.add(children[i + 1]);
          }
          pairs.add(Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
            child: Row(children: rowItems),
          ));
        }
        return Column(children: pairs);
      }

      return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ═══════════════ SECTION 1: NUÔI TRỒNG ═══════════════
        _sectionHeader(Icons.water_rounded, 'Nuôi trồng', AppColors.primary),
        const SizedBox(height: 8),
        kpiRow([
          _kpiCard('Ao nuôi', '${dp.activePonds}/${dp.ponds.length}', Icons.water_rounded, AppColors.primary, subtitle: '${dp.inactivePonds} trống'),
          _kpiCard('Lô cá', '${dp.activeBatches}', Icons.set_meal_rounded, AppColors.success, subtitle: '${dp.fishBatches.where((b) => b.status == 'harvested').length} đã thu hoạch'),
          _kpiCard('Sinh khối', '${_nFmt.format(totalBiomassKg)} kg', Icons.scale_rounded, const Color(0xFF8B5CF6), subtitle: totalBiomassKg >= 1000 ? '≈ ${_nFmt.format(totalBiomassKg / 1000)} tấn' : null),
        ]),
        const SizedBox(height: 8),
        kpiRow([
          _kpiCard('Tỷ lệ sống TB', '${avgSurvivalRate.toStringAsFixed(1)}%', Icons.favorite_rounded, avgSurvivalRate >= 80 ? AppColors.success : (avgSurvivalRate >= 60 ? AppColors.warning : AppColors.error)),
          _kpiCard('FCR TB', avgFcr > 0 ? avgFcr.toStringAsFixed(2) : '—', Icons.restaurant_rounded, avgFcr > 0 && avgFcr <= 1.5 ? AppColors.success : (avgFcr <= 2.0 ? AppColors.warning : AppColors.error)),
          _kpiCard('Loài nuôi', '${dp.species.length}', Icons.eco_rounded, const Color(0xFF059669)),
        ]),

        const SizedBox(height: 18),

        // ═══════════════ SECTION 2: TÀI CHÍNH ═══════════════
        _sectionHeader(Icons.monetization_on_rounded, 'Tài chính', AppColors.success),
        const SizedBox(height: 8),

        // Profit highlight
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: grossProfit >= 0 ? AppColors.kpiSuccess : AppColors.kpiDanger,
            borderRadius: BorderRadius.circular(AppSizes.borderRadius),
          ),
          child: Row(children: [
            Icon(grossProfit >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: Colors.white, size: 30),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Lợi nhuận gộp (Doanh thu - Chi phí mua)', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text('${_cFmt.format(grossProfit)}đ', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            ])),
          ]),
        ),
        const SizedBox(height: 8),

        kpiRow([
          _kpiCard('Doanh thu bán', '${_cFmt.format(totalRevenue)}đ', Icons.trending_up_rounded, AppColors.success, subtitle: '${completedSales.length} đơn hoàn thành'),
          _kpiCard('Chi phí mua', '${_cFmt.format(totalCost)}đ', Icons.shopping_cart_rounded, AppColors.error, subtitle: '${completedPurchases.length} đơn đã nhập'),
        ]),
        const SizedBox(height: 8),

        // Revenue this month vs prev month
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            const Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.textSecondary),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Doanh thu T${now.month}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              Text('${_cFmt.format(salesThisMonth)}đ', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ])),
            Container(width: 1, height: 32, color: AppColors.textHint.withAlpha(40)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Tháng trước', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              Text('${_cFmt.format(salesPrevMonth)}đ', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ])),
            if (salesPrevMonth > 0) ...[
                  _growthBadge(salesThisMonth, salesPrevMonth),
            ],
          ]),
        ),
        const SizedBox(height: 8),

        // Cash flow
        kpiRow([
          _kpiCard('Số dư quỹ', '${_cFmt.format(cashBalance)}đ', Icons.account_balance_rounded, cashBalance >= 0 ? const Color(0xFF059669) : AppColors.error),
          _kpiCard('Thu thực tế', '${_cFmt.format(cashIn)}đ', Icons.arrow_downward_rounded, const Color(0xFF10B981)),
          _kpiCard('Chi thực tế', '${_cFmt.format(cashOut)}đ', Icons.arrow_upward_rounded, const Color(0xFFEF4444)),
        ]),

        const SizedBox(height: 12),

        // ── Mini Revenue Trend Chart ──
        Builder(builder: (_) {
          final monthlyRev = <String, double>{};
          final monthlyCst = <String, double>{};
          for (final s in completedSales) {
            final key = DateFormat('MM/yyyy').format(s.date);
            monthlyRev[key] = (monthlyRev[key] ?? 0) + s.totalAmount;
          }
          for (final p in completedPurchases) {
            final key = DateFormat('MM/yyyy').format(p.date);
            monthlyCst[key] = (monthlyCst[key] ?? 0) + p.total;
          }
          final months = {...monthlyRev.keys, ...monthlyCst.keys}.toList()..sort();
          if (months.length < 2) return const SizedBox.shrink();
          final revSpots = months.asMap().entries.map((e) => FlSpot(e.key.toDouble(), monthlyRev[e.value] ?? 0)).toList();
          final costSpots = months.asMap().entries.map((e) => FlSpot(e.key.toDouble(), monthlyCst[e.value] ?? 0)).toList();
          final allVals = [...revSpots.map((s) => s.y), ...costSpots.map((s) => s.y)];
          final maxVal = allVals.reduce((a, b) => a > b ? a : b);
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Text('Xu hướng doanh thu & chi phí', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    _chartLegendDot(AppColors.success, 'Thu'),
                    const SizedBox(width: 10),
                    _chartLegendDot(AppColors.error, 'Chi'),
                  ]),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 160,
                    child: LineChart(
                      LineChartData(
                        maxY: maxVal * 1.15,
                        minY: 0,
                        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: AppColors.border.withAlpha(50), strokeWidth: 0.7)),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(sideTitles: SideTitles(
                            showTitles: true, reservedSize: 44,
                            getTitlesWidget: (value, meta) {
                              if (value == 0) return const SizedBox.shrink();
                              String t;
                              if (value >= 1e9) { t = '${(value / 1e9).toStringAsFixed(1)}tỷ'; }
                              else if (value >= 1e6) { t = '${(value / 1e6).toStringAsFixed(0)}tr'; }
                              else if (value >= 1e3) { t = '${(value / 1e3).toStringAsFixed(0)}k'; }
                              else { t = value.toStringAsFixed(0); }
                              return Text(t, style: const TextStyle(fontSize: 9, color: AppColors.textHint));
                            },
                          )),
                          bottomTitles: AxisTitles(sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= months.length) return const SizedBox.shrink();
                              return Padding(padding: const EdgeInsets.only(top: 4), child: Text('T${months[idx].split('/').first}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600)));
                            },
                          )),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        lineBarsData: [
                          LineChartBarData(spots: revSpots, isCurved: true, color: AppColors.success, barWidth: 2.5, dotData: FlDotData(show: months.length <= 6), belowBarData: BarAreaData(show: true, color: AppColors.success.withAlpha(25))),
                          LineChartBarData(spots: costSpots, isCurved: true, color: AppColors.error, barWidth: 2.5, dotData: FlDotData(show: months.length <= 6), belowBarData: BarAreaData(show: true, color: AppColors.error.withAlpha(20))),
                        ],
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            tooltipBorderRadius: BorderRadius.circular(8),
                            getTooltipItems: (spots) => spots.map((s) {
                              final label = s.barIndex == 0 ? 'Thu' : 'Chi';
                              return LineTooltipItem('$label: ${_cFmt.format(s.y)}đ', TextStyle(color: s.bar.color, fontSize: 11, fontWeight: FontWeight.w600));
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 18),

        // ═══════════════ SECTION 3: CẢNH BÁO ═══════════════
        if (totalWaterWarnings > 0 || overdueTasks > 0 || outOfStock > 0 || lowStock > 0 || dp.totalDebt > 0 || dp.totalSupplierDebt > 0) ...[
          _sectionHeader(Icons.warning_amber_rounded, 'Cảnh báo & Công việc', AppColors.warning),
          const SizedBox(height: 8),
          // Water alerts
          if (totalWaterWarnings > 0)
            _alertCard(Icons.water_drop_rounded, 'Chất lượng nước', [
              if (phWarnings > 0) '$phWarnings ao pH bất thường',
              if (doWarnings > 0) '$doWarnings ao DO thấp (< 4 mg/L)',
              if (nh3Warnings > 0) '$nh3Warnings ao NH₃ cao',
            ], AppColors.warning, onTap: () => _tabCtrl.animateTo(1)),

          // Task alerts
          if (pendingTasks > 0 || overdueTasks > 0)
            _alertCard(Icons.task_alt_rounded, 'Công việc', [
              if (overdueTasks > 0) '$overdueTasks công việc quá hạn!',
              if (pendingTasks > 0) '$pendingTasks công việc đang chờ',
            ], overdueTasks > 0 ? AppColors.error : AppColors.info),

          // Stock alerts
          if (outOfStock > 0 || lowStock > 0)
            _alertCard(Icons.inventory_2_rounded, 'Tồn kho', [
              if (outOfStock > 0) '$outOfStock sản phẩm hết hàng!',
              if (lowStock > 0) '$lowStock sản phẩm sắp hết',
            ], outOfStock > 0 ? AppColors.error : AppColors.warning, onTap: () => _tabCtrl.animateTo(12)),

          // Debt alerts
          if (dp.totalDebt > 0)
            _alertCard(Icons.person_pin_rounded, 'Công nợ khách hàng', [
              '${dp.customers.where((c) => c.debt > 0).length} khách còn nợ: ${_cFmt.format(dp.totalDebt)}đ',
            ], AppColors.warning, onTap: () => _tabCtrl.animateTo(9)),

          if (dp.totalSupplierDebt > 0)
            _alertCard(Icons.local_shipping_rounded, 'Nợ nhà cung cấp', [
              'Tổng nợ NCC: ${_cFmt.format(dp.totalSupplierDebt)}đ',
            ], AppColors.error, onTap: () => _tabCtrl.animateTo(10)),

          const SizedBox(height: 18),
        ],

        // ═══════════════ SECTION 4: TỔNG QUAN NHANH ═══════════════
        _sectionHeader(Icons.dns_rounded, 'Tổng quan hệ thống', AppColors.textSecondary),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Wrap(
              spacing: 0,
              runSpacing: 0,
              children: [
                _statTile(Icons.business_rounded, 'Chi nhánh', '${dp.branches.length}', AppColors.primary),
                _statTile(Icons.people_rounded, 'Nhân viên', '${dp.employees.length}', const Color(0xFF6366F1)),
                _statTile(Icons.person_pin_rounded, 'Khách hàng', '${dp.customers.length}', const Color(0xFF0891B2)),
                _statTile(Icons.inventory_2_rounded, 'Sản phẩm', '${dp.products.length}', const Color(0xFFD97706)),
                _statTile(Icons.local_shipping_rounded, 'NCC', '${dp.suppliers.length}', const Color(0xFF7C3AED)),
                _statTile(Icons.point_of_sale_rounded, 'Đơn bán', '${dp.saleOrders.length}', AppColors.success),
                _statTile(Icons.shopping_cart_rounded, 'Đơn mua', '${dp.purchaseOrders.length}', AppColors.error),
                _statTile(Icons.receipt_long_rounded, 'Phiếu thu chi', '${dp.paymentVouchers.length}', const Color(0xFF059669)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
    }); // end LayoutBuilder
  }

  // ── Overview helpers ──

  Widget _sectionHeader(IconData icon, String title, Color color) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: color),
      ),
      const SizedBox(width: 8),
      Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
    ]);
  }

  Widget _kpiCard(String title, String value, IconData? icon, Color color, {String? subtitle}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(30)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (icon != null)
            Row(children: [
              Icon(icon, size: 15, color: color.withAlpha(180)),
              const SizedBox(width: 4),
              Flexible(child: Text(title, style: TextStyle(fontSize: 11, color: color.withAlpha(180), fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
            ])
          else
            Text(title, style: TextStyle(fontSize: 11, color: color.withAlpha(180), fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color))),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 10, color: color.withAlpha(140)), overflow: TextOverflow.ellipsis),
          ],
        ]),
      ),
    );
  }

  Widget _growthBadge(double current, double previous) {
    final pct = previous > 0 ? ((current - previous) / previous * 100) : 0.0;
    final isUp = pct >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (isUp ? AppColors.success : AppColors.error).withAlpha(15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(isUp ? Icons.arrow_upward : Icons.arrow_downward, size: 12, color: isUp ? AppColors.success : AppColors.error),
        Text('${isUp ? '+' : ''}${pct.toStringAsFixed(0)}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isUp ? AppColors.success : AppColors.error)),
      ]),
    );
  }

  Widget _alertCard(IconData icon, String title, List<String> items, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withAlpha(10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(30)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color)),
            const SizedBox(height: 2),
            ...items.map((t) => Text('• $t', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
          ])),
          if (onTap != null) Icon(Icons.chevron_right_rounded, size: 18, color: color.withAlpha(100)),
        ]),
      ),
    );
  }

  Widget _statTile(IconData icon, String label, String value, Color color) {
    return SizedBox(
      width: 130,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(icon, size: 16, color: color),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ]),
      ),
    );
  }

  Widget _chartLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TAB 2: THÔNG SỐ NƯỚC
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildWaterTab() {
    final activePonds = dp.ponds.where((p) => p.status == 'active').toList();
    var allPonds = dp.ponds.toList()..sort((a, b) => a.code.compareTo(b.code));
    if (_waterStatus != 'all') {
      allPonds = allPonds.where((p) => p.status == _waterStatus).toList();
    }
    if (_waterQuality != 'all') {
      allPonds = allPonds.where((p) {
        final eval = _waterEvaluation(p);
        if (_waterQuality == 'good') return eval == 'Tốt';
        if (_waterQuality == 'warning') return eval == 'Cảnh báo';
        if (_waterQuality == 'danger') return eval == 'Nguy hiểm';
        return true;
      }).toList();
    }
    final hasWaterFilter = _waterStatus != 'all' || _waterQuality != 'all';

    // Averages
    final pondsWithPh = activePonds.where((p) => p.currentPh != null).toList();
    final pondsWithDo = activePonds.where((p) => p.currentDo != null).toList();
    final pondsWithTemp = activePonds.where((p) => p.currentTemp != null).toList();
    final pondsWithNh3 = activePonds.where((p) => p.currentNh3 != null).toList();

    final avgPh = pondsWithPh.isNotEmpty ? pondsWithPh.fold(0.0, (s, p) => s + p.currentPh!) / pondsWithPh.length : 0.0;
    final avgDo = pondsWithDo.isNotEmpty ? pondsWithDo.fold(0.0, (s, p) => s + p.currentDo!) / pondsWithDo.length : 0.0;
    final avgTemp = pondsWithTemp.isNotEmpty ? pondsWithTemp.fold(0.0, (s, p) => s + p.currentTemp!) / pondsWithTemp.length : 0.0;
    final avgNh3 = pondsWithNh3.isNotEmpty ? pondsWithNh3.fold(0.0, (s, p) => s + p.currentNh3!) / pondsWithNh3.length : 0.0;

    return Column(
      children: [
        // Average KPI
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              _kpiCard('pH TB', avgPh.toStringAsFixed(1), null, _phColor(avgPh)),
                  _kpiCard('DO TB', '${avgDo.toStringAsFixed(1)} mg/L', null, _doColor(avgDo)),
                  _kpiCard('Nhiệt độ TB', '${avgTemp.toStringAsFixed(1)}°C', null, AppColors.info),
                  _kpiCard('NH₃ TB', '${avgNh3.toStringAsFixed(3)} mg/L', null, _nh3Color(avgNh3)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Filter bar
        AppFilterBar(children: [
          AppDropMapFilter(value: _waterStatus, items: const {'all': 'TT Ao', 'active': 'Đang nuôi', 'empty': 'Trống', 'maintenance': 'Bảo trì'}, onChanged: (v) => setState(() => _waterStatus = v)),
          AppDropMapFilter(value: _waterQuality, items: const {'all': 'Chất lượng', 'good': 'Tốt', 'warning': 'Cảnh báo', 'danger': 'Nguy hiểm'}, onChanged: (v) => setState(() => _waterQuality = v)),
          if (hasWaterFilter) ...[const SizedBox(width: 8), AppClearFilterChip(onTap: () => setState(() { _waterStatus = 'all'; _waterQuality = 'all'; }))],
        ]),
        // Table header
        _TableHeader(title: 'Bảng thông số nước (${allPonds.length} ao)'),
        // Table
        Expanded(
          child: allPonds.isEmpty
              ? const _EmptyMsg(icon: Icons.water_drop_rounded, msg: 'Chưa có dữ liệu ao')
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildDataTable(
                    columns: const ['Ao', 'Trạng thái', 'pH', 'DO (mg/L)', 'Nhiệt độ (°C)', 'NH₃ (mg/L)', 'Kiềm', 'Đánh giá'],
                    rows: allPonds.map((p) {
                      final eval = _waterEvaluation(p);
                      return [
                        p.code,
                        p.statusLabel,
                        p.currentPh?.toStringAsFixed(1) ?? '—',
                        p.currentDo?.toStringAsFixed(1) ?? '—',
                        p.currentTemp?.toStringAsFixed(1) ?? '—',
                        p.currentNh3?.toStringAsFixed(3) ?? '—',
                        p.currentAlkalinity?.toStringAsFixed(0) ?? '—',
                        eval,
                      ];
                    }).toList(),
                    cellColors: allPonds.map((p) {
                      return {
                        2: p.currentPh != null ? _phColor(p.currentPh!) : null,
                        3: p.currentDo != null ? _doColor(p.currentDo!) : null,
                        5: p.currentNh3 != null ? _nh3Color(p.currentNh3!) : null,
                        7: _evalColor(_waterEvaluation(p)),
                      };
                    }).toList(),
                  ),
                ),
        ),
      ],
    );
  }

  String _waterEvaluation(Pond p) {
    if (p.status != 'active') return '—';
    int issues = 0;
    if (p.currentPh != null && (p.currentPh! < 6.5 || p.currentPh! > 8.5)) issues++;
    if (p.currentDo != null && p.currentDo! < 4) issues++;
    if (p.currentNh3 != null && p.currentNh3! > 0.1) issues++;
    if (p.currentTemp != null && (p.currentTemp! < 20 || p.currentTemp! > 35)) issues++;
    if (issues == 0) return 'Tốt';
    if (issues == 1) return 'Cảnh báo';
    return 'Nguy hiểm';
  }

  Color _phColor(double v) => (v < 6.5 || v > 8.5) ? AppColors.error : (v < 7.0 || v > 8.0) ? AppColors.warning : AppColors.success;
  Color _doColor(double v) => v < 3 ? AppColors.error : v < 4 ? AppColors.warning : AppColors.success;
  Color _nh3Color(double v) => v > 0.1 ? AppColors.error : v > 0.05 ? AppColors.warning : AppColors.success;
  Color? _evalColor(String e) => e == 'Tốt' ? AppColors.success : e == 'Cảnh báo' ? AppColors.warning : e == 'Nguy hiểm' ? AppColors.error : null;

  // ═══════════════════════════════════════════════════════════════════
  // TAB 3: LÔ CÁ
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildBatchTab() {
    final batchCutoff = _periodCutoff(_batchPeriod);
    var batches = dp.fishBatches.toList()..sort((a, b) => b.stockingDate.compareTo(a.stockingDate));
    if (_batchPeriod != 'all') batches = batches.where((b) => _afterCutoff(b.stockingDate, batchCutoff)).toList();
    if (_batchStatus != 'all') batches = batches.where((b) => b.status == _batchStatus).toList();
    // KPI luôn dùng dữ liệu gốc (không bị filter ảnh hưởng)
    final allBatches = dp.fishBatches;
    final active = allBatches.where((b) => b.status == 'active').toList();
    final totalQty = active.fold(0, (s, b) => s + b.currentQuantity);
    final totalBiomass = active.fold(0.0, (s, b) => s + (b.currentWeight * b.currentQuantity / 1000));
    final avgFcr = active.isNotEmpty ? active.where((b) => b.fcr > 0).fold(0.0, (s, b) => s + b.fcr) / (active.where((b) => b.fcr > 0).length.clamp(1, 9999)) : 0.0;
    final avgSurvival = active.isNotEmpty ? active.fold(0.0, (s, b) => s + b.survivalRate) / active.length : 0.0;
    final harvestedCount = allBatches.where((b) => b.status == 'harvested').length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              _kpiCard('Đang nuôi', '${active.length} lô', null, AppColors.primary),
                  _kpiCard('Tổng cá', _cFmt.format(totalQty), null, AppColors.info),
                  _kpiCard('Sinh khối', '${_nFmt.format(totalBiomass)} kg', null, AppColors.success),
                  _kpiCard('FCR TB', avgFcr.toStringAsFixed(2), null, avgFcr > 2 ? AppColors.warning : AppColors.success),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              _kpiCard('Tỷ lệ sống TB', '${avgSurvival.toStringAsFixed(1)}%', null, avgSurvival < 80 ? AppColors.warning : AppColors.success),
                  _kpiCard('Đã thu hoạch', '$harvestedCount lô', null, AppColors.secondary),
                  _kpiCard('Thức ăn tiêu thụ', '${_nFmt.format(active.fold(0.0, (s, b) => s + b.feedConsumed))} kg', null, AppColors.info),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Filter bar
        AppFilterBar(children: [
          AppDropMapFilter(value: _batchPeriod, items: _periodItems, onChanged: (v) => setState(() => _batchPeriod = v)),
          AppDropMapFilter(value: _batchStatus, items: const {'all': 'Trạng thái', 'active': 'Đang nuôi', 'harvested': 'Đã thu hoạch', 'transferred': 'Đã chuyển', 'closed': 'Đã đóng'}, onChanged: (v) => setState(() => _batchStatus = v)),
          if (_batchStatus != 'all' || _batchPeriod != 'all') ...[const SizedBox(width: 8), AppClearFilterChip(onTap: () => setState(() { _batchStatus = 'all'; _batchPeriod = 'all'; }))],
        ]),
        _TableHeader(title: 'Bảng lô cá (${batches.length} lô)'),
        Expanded(
          child: batches.isEmpty
              ? const _EmptyMsg(icon: Icons.set_meal_rounded, msg: 'Chưa có lô cá')
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildDataTable(
                    columns: const ['Ao', 'Loài', 'Ngày thả', 'Ngày nuôi', 'SL ban đầu', 'SL hiện tại', 'TL sống (%)', 'TL TB (g)', 'Sinh khối (kg)', 'FCR', 'Trạng thái'],
                    rows: batches.map((b) {
                      final pond = dp.pondById(b.pondId);
                      final sp = dp.speciesById(b.speciesId);
                      final biomass = b.currentWeight * b.currentQuantity / 1000;
                      return [
                        pond?.code ?? '—',
                        sp?.name ?? '—',
                        _dFmt.format(b.stockingDate),
                        '${b.daysOfCulture}',
                        _cFmt.format(b.initialQuantity),
                        _cFmt.format(b.currentQuantity),
                        b.survivalRate.toStringAsFixed(1),
                        _nFmt.format(b.currentWeight),
                        _nFmt.format(biomass),
                        b.fcr > 0 ? b.fcr.toStringAsFixed(2) : '—',
                        b.statusLabel,
                      ];
                    }).toList(),
                    cellColors: batches.map((b) {
                      return {
                        6: b.survivalRate < 70 ? AppColors.error : b.survivalRate < 85 ? AppColors.warning : AppColors.success,
                        9: b.fcr > 0 ? (b.fcr > 2.5 ? AppColors.error : b.fcr > 1.8 ? AppColors.warning : AppColors.success) : null,
                        10: b.status == 'active' ? AppColors.success : b.status == 'harvested' ? AppColors.info : AppColors.textHint,
                      };
                    }).toList(),
                  ),
                ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TAB 4: HÀNG HÓA
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildProductTab() {
    var products = dp.products.toList()..sort((a, b) => a.name.compareTo(b.name));
    if (_prodCategory != 'all') products = products.where((p) => p.category == _prodCategory).toList();
    if (_prodLowStock) products = products.where((p) => p.isLowStock).toList();
    final totalValue = dp.products.fold(0.0, (s, p) => s + p.stockValue);
    final lowStock = dp.products.where((p) => p.isLowStock).toList();
    final hasProdFilter = _prodCategory != 'all' || _prodLowStock;

    // Category breakdown
    final categoryMap = <String, int>{};
    final categoryValue = <String, double>{};
    for (final p in products) {
      categoryMap[p.category] = (categoryMap[p.category] ?? 0) + 1;
      categoryValue[p.category] = (categoryValue[p.category] ?? 0) + p.stockValue;
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              _kpiCard('Tổng SP', '${products.length}', null, AppColors.primary),
                  _kpiCard('Sắp hết hàng', '${lowStock.length}', null, lowStock.isNotEmpty ? AppColors.error : AppColors.success),
                  _kpiCard('Giá trị kho', '${_cFmt.format(totalValue)}đ', null, AppColors.info),
                  _kpiCard('Danh mục', '${categoryMap.length}', null, AppColors.secondary),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Category breakdown bar
        if (categoryMap.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Phân bổ theo danh mục', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ...categoryMap.entries.map((e) {
                      final label = _catLabel(e.key);
                      final pct = products.isNotEmpty ? e.value / products.length * 100 : 0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 12))),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(value: pct / 100, backgroundColor: AppColors.surfaceVariant, color: AppColors.primary.withAlpha(180), minHeight: 6),
                              ),
                            ),
                                              Text('${e.value} (${pct.toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        // Filter bar
        AppFilterBar(children: [
          AppDropMapFilter(value: _prodCategory, items: const {'all': 'Danh mục', 'feed': 'Thức ăn', 'seed': 'Giống', 'chemical': 'Vi sinh/HChất', 'medicine': 'Thuốc', 'accessory': 'Phụ kiện', 'tool': 'Dụng cụ'}, onChanged: (v) => setState(() => _prodCategory = v)),
          AppToggleChip(label: 'Sắp hết', active: _prodLowStock, activeColor: AppColors.error, onTap: () => setState(() => _prodLowStock = !_prodLowStock)),
          if (hasProdFilter) ...[const SizedBox(width: 8), AppClearFilterChip(onTap: () => setState(() { _prodCategory = 'all'; _prodLowStock = false; }))],
        ]),
        _TableHeader(title: 'Bảng hàng hóa (${products.length} sản phẩm)'),
        Expanded(
          child: products.isEmpty
              ? const _EmptyMsg(icon: Icons.inventory_2_rounded, msg: 'Chưa có hàng hóa')
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildDataTable(
                    columns: const ['SKU', 'Tên SP', 'Danh mục', 'ĐVT', 'Giá', 'Tồn kho', 'Tồn TT', 'Giá trị', 'TT'],
                    rows: products.map((p) {
                      return [
                        p.sku.isNotEmpty ? p.sku : '—',
                        p.name,
                        p.categoryLabel,
                        p.unit,
                        '${_cFmt.format(p.price)}đ',
                        _nFmt.format(p.stock),
                        p.minStock > 0 ? _nFmt.format(p.minStock) : '—',
                        '${_cFmt.format(p.stockValue)}đ',
                        p.isLowStock ? '⚠️' : '✓',
                      ];
                    }).toList(),
                    cellColors: products.map((p) {
                      return {
                        8: p.isLowStock ? AppColors.error : AppColors.success,
                      };
                    }).toList(),
                  ),
                ),
        ),
      ],
    );
  }

  String _catLabel(String c) {
    switch (c) {
      case 'feed': return 'Thức ăn';
      case 'seed': return 'Giống';
      case 'chemical': return 'Vi sinh/HChất';
      case 'medicine': return 'Thuốc';
      case 'accessory': return 'Phụ kiện';
      default: return c;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // TAB 5: KHÁCH HÀNG
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildCustomerTab() {
    var customers = dp.customers.toList()..sort((a, b) => a.name.compareTo(b.name));
    if (_custType != 'all') customers = customers.where((c) => c.type == _custType).toList();
    if (_custDebtOnly) customers = customers.where((c) => c.debt > 0).toList();
    final totalDebt = dp.totalDebt;
    final totalCustomers = dp.customers.length;
    final wholesale = dp.customers.where((c) => c.type == 'wholesale').length;
    final retail = dp.customers.where((c) => c.type == 'retail').length;
    final withDebt = dp.customers.where((c) => c.debt > 0).length;
    final hasCustFilter = _custType != 'all' || _custDebtOnly;

    // Revenue per customer — chỉ đơn hoàn thành
    final customerRevenue = <String, double>{};
    final customerOrders = <String, int>{};
    for (final o in dp.saleOrders.where((o) => o.status == 'completed')) {
      customerRevenue[o.customerId] = (customerRevenue[o.customerId] ?? 0) + o.totalAmount;
      customerOrders[o.customerId] = (customerOrders[o.customerId] ?? 0) + 1;
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              _kpiCard('Tổng KH', '$totalCustomers', null, AppColors.primary),
                  _kpiCard('Đại lý', '$wholesale', null, AppColors.info),
                  _kpiCard('Khách lẻ', '$retail', null, AppColors.secondary),
                  _kpiCard('Công nợ', '${_cFmt.format(totalDebt)}đ', null, withDebt > 0 ? AppColors.error : AppColors.success),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Filter bar
        AppFilterBar(children: [
          AppDropMapFilter(value: _custType, items: const {'all': 'Loại KH', 'wholesale': 'Đại lý', 'retail': 'Khách lẻ'}, onChanged: (v) => setState(() => _custType = v)),
          AppToggleChip(label: 'Có công nợ', active: _custDebtOnly, activeColor: AppColors.error, onTap: () => setState(() => _custDebtOnly = !_custDebtOnly)),
          if (hasCustFilter) ...[const SizedBox(width: 8), AppClearFilterChip(onTap: () => setState(() { _custType = 'all'; _custDebtOnly = false; }))],
        ]),
        // Top customers
        if (customerRevenue.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Top khách hàng theo doanh thu', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ..._topCustomers(customerRevenue, 5),
                  ],
                ),
              ),
            ),
          ),
        _TableHeader(title: 'Bảng khách hàng (${customers.length} KH)'),
        Expanded(
          child: customers.isEmpty
              ? const _EmptyMsg(icon: Icons.people_rounded, msg: 'Chưa có khách hàng')
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildDataTable(
                    columns: const ['Tên KH', 'Loại', 'Địa chỉ', 'Liên hệ', 'Số đơn', 'Doanh thu', 'Công nợ'],
                    rows: customers.map((c) {
                      return [
                        c.name,
                        c.typeLabel,
                        c.address.isNotEmpty ? c.address : '—',
                        c.contact.isNotEmpty ? c.contact : '—',
                        '${customerOrders[c.id] ?? 0}',
                        '${_cFmt.format(customerRevenue[c.id] ?? 0)}đ',
                        c.debt > 0 ? '${_cFmt.format(c.debt)}đ' : '0đ',
                      ];
                    }).toList(),
                    cellColors: customers.map((c) {
                      return {
                        6: c.debt > 0 ? AppColors.error : AppColors.success,
                      };
                    }).toList(),
                  ),
                ),
        ),
      ],
    );
  }

  List<Widget> _topCustomers(Map<String, double> revenueMap, int limit) {
    final sorted = revenueMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(limit);
    final maxVal = top.isNotEmpty ? top.first.value : 1;
    return top.map((e) {
      final c = dp.customerById(e.key);
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            SizedBox(width: 120, child: Text(c?.name ?? '—', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: e.value / maxVal, backgroundColor: AppColors.surfaceVariant, color: AppColors.success.withAlpha(180), minHeight: 6),
              ),
            ),
              Text('${_cFmt.format(e.value)}đ', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }).toList();
  }

  // ═══════════════════════════════════════════════════════════════════
  // TAB 6: DOANH THU & LỢI NHUẬN
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildRevenueTab() {
    final saleCutoff = _periodCutoff(_salePeriod);
    var sales = dp.saleOrders.toList()..sort((a, b) => b.date.compareTo(a.date));
    if (_salePeriod != 'all') {
      sales = sales.where((s) => _afterCutoff(s.date, saleCutoff)).toList();
    }
    if (_saleStatus != 'all') {
      sales = sales.where((s) => s.status == _saleStatus).toList();
    }
    final hasSaleFilter = _saleStatus != 'all' || _salePeriod != 'all';
    final completedSales = sales.where((s) => s.status == 'completed').toList();
    final totalRevenue = completedSales.fold(0.0, (s, o) => s + o.totalAmount);
    var completedPurchases = dp.purchaseOrders.where((o) => o.status == 'completed').toList();
    if (saleCutoff != null) completedPurchases = completedPurchases.where((o) => _afterCutoff(o.date, saleCutoff)).toList();
    final totalCost = completedPurchases.fold(0.0, (s, o) => s + o.total);
    var confirmedReceipts = dp.paymentVouchers.where((v) => v.isReceipt && v.status == 'confirmed').toList();
    var confirmedPayments = dp.paymentVouchers.where((v) => v.isPayment && v.status == 'confirmed').toList();
    if (saleCutoff != null) {
      confirmedReceipts = confirmedReceipts.where((v) => _afterCutoff(v.date, saleCutoff)).toList();
      confirmedPayments = confirmedPayments.where((v) => _afterCutoff(v.date, saleCutoff)).toList();
    }
    final totalIn = confirmedReceipts.fold(0.0, (s, v) => s + v.amount);
    final totalOut = confirmedPayments.fold(0.0, (s, v) => s + v.amount);
    final grossProfit = totalRevenue - totalCost;
    final cashFlow = totalIn - totalOut;
    final margin = totalRevenue > 0 ? (grossProfit / totalRevenue * 100) : 0.0;

    // Monthly breakdown — chỉ đơn completed
    final monthlyRevenue = <String, double>{};
    final monthlyCost = <String, double>{};
    for (final s in completedSales) {
      final key = DateFormat('MM/yyyy').format(s.date);
      monthlyRevenue[key] = (monthlyRevenue[key] ?? 0) + s.totalAmount;
    }
    for (final p in completedPurchases) {
      final key = DateFormat('MM/yyyy').format(p.date);
      monthlyCost[key] = (monthlyCost[key] ?? 0) + p.total;
    }
    final allMonths = {...monthlyRevenue.keys, ...monthlyCost.keys}.toList()..sort();

    // Expense categories from payment vouchers
    final expenseByCategory = <String, double>{};
    for (final v in confirmedPayments) {
      expenseByCategory[v.category] = (expenseByCategory[v.category] ?? 0) + v.amount;
    }
    final sortedExpenses = expenseByCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // KPI Row
        Row(
          children: [
            _kpiCard('Doanh thu', '${_cFmt.format(totalRevenue)}đ', null, AppColors.success),
              _kpiCard('Chi phí mua', '${_cFmt.format(totalCost)}đ', null, AppColors.error),
              _kpiCard('LN gộp', '${_cFmt.format(grossProfit)}đ', null, grossProfit >= 0 ? AppColors.success : AppColors.error),
              _kpiCard('Biên LN', '${margin.toStringAsFixed(1)}%', null, margin >= 20 ? AppColors.success : AppColors.warning),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _kpiCard('Thu thực tế', '${_cFmt.format(totalIn)}đ', null, AppColors.success),
              _kpiCard('Chi thực tế', '${_cFmt.format(totalOut)}đ', null, AppColors.error),
              _kpiCard('Dòng tiền', '${_cFmt.format(cashFlow)}đ', null, cashFlow >= 0 ? AppColors.success : AppColors.error),
              _kpiCard('Công nợ KH', '${_cFmt.format(dp.totalDebt)}đ', null, dp.totalDebt > 0 ? AppColors.warning : AppColors.success),
          ],
        ),
        const SizedBox(height: 14),

        // Sale status filter (đưa lên trên thay vì ở cuối)
        AppFilterBar(children: [
          AppDropMapFilter(value: _salePeriod, items: _periodItems, onChanged: (v) => setState(() => _salePeriod = v)),
          AppDropMapFilter(value: _saleStatus, items: const {'all': 'Trạng thái', 'pending': 'Chờ xử lý', 'completed': 'Hoàn thành', 'cancelled': 'Đã huỷ'}, onChanged: (v) => setState(() => _saleStatus = v)),
          if (hasSaleFilter) ...[const SizedBox(width: 8), AppClearFilterChip(onTap: () => setState(() { _saleStatus = 'all'; _salePeriod = 'all'; }))],
        ]),
        const SizedBox(height: 8),

        // ── Bar Chart: Doanh thu & Chi phí theo tháng ──
        if (allMonths.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Biểu đồ Doanh thu & Chi phí', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      _chartLegendDot(AppColors.success, 'Doanh thu'),
                      const SizedBox(width: 12),
                      _chartLegendDot(AppColors.error, 'Chi phí'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 220,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: allMonths.map((m) {
                          final rev = monthlyRevenue[m] ?? 0;
                          final cost = monthlyCost[m] ?? 0;
                          return rev > cost ? rev : cost;
                        }).reduce((a, b) => a > b ? a : b) * 1.15,
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            tooltipBorderRadius: BorderRadius.circular(8),
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final m = allMonths[group.x.toInt()];
                              final label = rodIndex == 0 ? 'Thu' : 'Chi';
                              return BarTooltipItem(
                                '$m\n$label: ${_cFmt.format(rod.toY)}đ',
                                const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 50,
                              getTitlesWidget: (value, meta) {
                                if (value == 0) return const SizedBox.shrink();
                                String text;
                                if (value >= 1e9) {
                                  text = '${(value / 1e9).toStringAsFixed(1)}tỷ';
                                } else if (value >= 1e6) {
                                  text = '${(value / 1e6).toStringAsFixed(0)}tr';
                                } else if (value >= 1e3) {
                                  text = '${(value / 1e3).toStringAsFixed(0)}k';
                                } else {
                                  text = value.toStringAsFixed(0);
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Text(text, style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx < 0 || idx >= allMonths.length) return const SizedBox.shrink();
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(allMonths[idx].split('/').first, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                                );
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: null,
                          getDrawingHorizontalLine: (value) => FlLine(color: AppColors.border.withAlpha(60), strokeWidth: 0.8),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: allMonths.asMap().entries.map((entry) {
                          final rev = monthlyRevenue[entry.value] ?? 0;
                          final cost = monthlyCost[entry.value] ?? 0;
                          return BarChartGroupData(
                            x: entry.key,
                            barRods: [
                              BarChartRodData(toY: rev, color: AppColors.success, width: 12, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                              BarChartRodData(toY: cost, color: AppColors.error, width: 12, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                            ],
                            barsSpace: 3,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── Pie Chart: Chi phí theo danh mục ──
        if (sortedExpenses.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Cơ cấu chi phí', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 200,
                    child: Row(
                      children: [
                        Expanded(
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 36,
                              sections: sortedExpenses.asMap().entries.map((entry) {
                                final pct = totalOut > 0 ? entry.value.value / totalOut * 100 : 0.0;
                                final colors = [
                                  const Color(0xFFEF4444), const Color(0xFFF97316), const Color(0xFFEAB308),
                                  const Color(0xFF22C55E), const Color(0xFF3B82F6), const Color(0xFF8B5CF6),
                                  const Color(0xFFEC4899), const Color(0xFF6366F1), const Color(0xFF14B8A6),
                                ];
                                return PieChartSectionData(
                                  value: entry.value.value,
                                  title: pct >= 8 ? '${pct.toStringAsFixed(0)}%' : '',
                                  color: colors[entry.key % colors.length],
                                  radius: 52,
                                  titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: sortedExpenses.asMap().entries.take(7).map((entry) {
                              final colors = [
                                const Color(0xFFEF4444), const Color(0xFFF97316), const Color(0xFFEAB308),
                                const Color(0xFF22C55E), const Color(0xFF3B82F6), const Color(0xFF8B5CF6),
                                const Color(0xFFEC4899), const Color(0xFF6366F1), const Color(0xFF14B8A6),
                              ];
                              final pct = totalOut > 0 ? entry.value.value / totalOut * 100 : 0.0;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    Container(width: 10, height: 10, decoration: BoxDecoration(color: colors[entry.key % colors.length], borderRadius: BorderRadius.circular(2))),
                                                              Expanded(child: Text(PaymentVoucher.categoryLabelFor(entry.value.key), style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                                    Text('${pct.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Monthly Revenue vs Cost table
        if (allMonths.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Doanh thu & Chi phí theo tháng', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  ...allMonths.map((m) {
                    final rev = monthlyRevenue[m] ?? 0;
                    final cost = monthlyCost[m] ?? 0;
                    final p = rev - cost;
                    final maxVal = [rev, cost].reduce((a, b) => a > b ? a : b);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(m, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              const Spacer(),
                              Text('LN: ${_cFmt.format(p)}đ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p >= 0 ? AppColors.success : AppColors.error)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const SizedBox(width: 50, child: Text('Thu', style: TextStyle(fontSize: 11, color: AppColors.textSecondary))),
                              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: maxVal > 0 ? rev / maxVal : 0, backgroundColor: AppColors.surfaceVariant, color: AppColors.success, minHeight: 8))),
                                                  SizedBox(width: 90, child: Text('${_cFmt.format(rev)}đ', style: const TextStyle(fontSize: 11), textAlign: TextAlign.right)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const SizedBox(width: 50, child: Text('Chi', style: TextStyle(fontSize: 11, color: AppColors.textSecondary))),
                              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: maxVal > 0 ? cost / maxVal : 0, backgroundColor: AppColors.surfaceVariant, color: AppColors.error, minHeight: 8))),
                                                  SizedBox(width: 90, child: Text('${_cFmt.format(cost)}đ', style: const TextStyle(fontSize: 11), textAlign: TextAlign.right)),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Expense categories
        if (sortedExpenses.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Chi phí theo danh mục', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  ...sortedExpenses.map((e) {
                    final pct = totalOut > 0 ? e.value / totalOut * 100 : 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          SizedBox(width: 110, child: Text(PaymentVoucher.categoryLabelFor(e.key), style: const TextStyle(fontSize: 12))),
                          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: pct / 100, backgroundColor: AppColors.surfaceVariant, color: AppColors.error.withAlpha(180), minHeight: 6))),
                                          Text('${_cFmt.format(e.value)}đ', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                          Text('(${pct.toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),

        // Sales table
        _TableHeader(title: 'Bảng đơn bán hàng (${sales.length} đơn)'),
        const SizedBox(height: 4),
        sales.isEmpty
            ? const _EmptyMsg(icon: Icons.point_of_sale_rounded, msg: 'Chưa có đơn bán')
            : _buildDataTable(
                columns: const ['Ngày', 'Khách hàng', 'Ao', 'Tổng tiền', 'Trạng thái'],
                rows: sales.map((s) {
                  final c = dp.customerById(s.customerId);
                  final p = dp.pondById(s.pondId);
                  return [
                    _dFmt.format(s.date),
                    c?.name ?? '—',
                    p?.code ?? '—',
                    '${_cFmt.format(s.totalAmount)}đ',
                    s.statusLabel,
                  ];
                }).toList(),
                cellColors: sales.map((s) {
                  return {
                    4: s.status == 'completed' ? AppColors.success : s.status == 'pending' ? AppColors.warning : AppColors.textHint,
                  };
                }).toList(),
              ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TAB 10: THỨC ĂN THEO LÔ / AO
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildFeedTab() {
    final allBatches = dp.fishBatches.where((b) => b.status == 'active').toList();
    final speciesOpts = allBatches.map((b) => dp.speciesById(b.speciesId)?.name ?? '').toSet().where((s) => s.isNotEmpty).toList()..sort();
    final batches = _feedSpecies == 'all' ? allBatches : allBatches.where((b) => dp.speciesById(b.speciesId)?.name == _feedSpecies).toList();
    final feedCutoff = _periodCutoff(_feedPeriod);
    var feedIssues = dp.stockIssues.where((si) => si.type == 'feeding' && si.status == 'approved').toList();
    var feedLogs = dp.feedingLogs.toList();
    if (feedCutoff != null) {
      feedIssues = feedIssues.where((si) => _afterCutoff(si.date, feedCutoff)).toList();
      feedLogs = feedLogs.where((fl) => _afterCutoffStr(fl['date'] as String?, feedCutoff)).toList();
    }

    // Per-batch aggregation
    final batchFeed = <String, double>{}; // batchId → total kg from feedingLogs
    for (final fl in feedLogs) {
      final bid = fl['fishBatchId'] as String? ?? '';
      final qty = (fl['quantity'] as num?)?.toDouble() ?? 0;
      if (bid.isNotEmpty) batchFeed[bid] = (batchFeed[bid] ?? 0) + qty;
    }

    // Per-pond aggregation from stock issues
    final pondFeed = <String, double>{}; // pondId → total kg
    final pondCost = <String, double>{};
    for (final si in feedIssues) {
      final pid = si.pondId;
      if (pid.isEmpty) continue;
      for (final it in si.items) {
        final qty = (it['qty'] as num?)?.toDouble() ?? 0;
        final cost = qty * ((it['unitPrice'] as num?)?.toDouble() ?? 0);
        pondFeed[pid] = (pondFeed[pid] ?? 0) + qty;
        pondCost[pid] = (pondCost[pid] ?? 0) + cost;
      }
    }

    // Also add from feedingLogs
    for (final fl in feedLogs) {
      final pid = fl['pondId'] as String? ?? '';
      final qty = (fl['quantity'] as num?)?.toDouble() ?? 0;
      if (pid.isNotEmpty) {
        pondFeed[pid] = (pondFeed[pid] ?? 0) + qty;
      }
    }

    // Build rows per batch
    final rows = <List<String>>[];
    final colors = <Map<int, Color?>>[];
    double totalFeed = 0, totalCost = 0;
    int totalFish = 0;
    double totalBiomass = 0;

    for (final b in batches) {
      final pond = dp.pondById(b.pondId);
      final sp = dp.speciesById(b.speciesId);
      final qtyInPond = b.currentQuantity;
      final wt = b.currentWeight > 0 ? b.currentWeight : b.initialWeight;
      final biomass = qtyInPond * wt / 1000;
      final feedRatio = sp?.feedRatio ?? 1.5;
      final dailyKg = biomass * feedRatio / 100;
      final consumed = b.feedConsumed;
      final fcr = b.fcr;
      final feedFromLogs = batchFeed[b.id] ?? 0;
      final totalUsed = math.max(consumed, feedFromLogs);
      final costForPond = pondCost[b.pondId] ?? 0;

      totalFeed += totalUsed;
      totalCost += costForPond;
      totalFish += qtyInPond;
      totalBiomass += biomass;

      rows.add([
        pond?.code ?? '—',
        sp?.name ?? '—',
        _cFmt.format(qtyInPond),
        '${wt.toStringAsFixed(0)}g',
        '${biomass.toStringAsFixed(1)}',
        '${feedRatio}%',
        dailyKg.toStringAsFixed(1),
        '${_nFmt.format(totalUsed)}',
        fcr > 0 ? fcr.toStringAsFixed(2) : '—',
        '${_cFmt.format(costForPond.round())}đ',
        '${b.daysOfCulture}',
      ]);
      colors.add({
        8: fcr > 0 ? (fcr > 2.5 ? AppColors.error : fcr > 1.8 ? AppColors.warning : AppColors.success) : null,
      });
    }

    return Column(
      children: [
        AppFilterBar(children: [
          AppDropMapFilter(value: _feedPeriod, items: _periodItems, onChanged: (v) => setState(() => _feedPeriod = v)),
          AppDropMapFilter(value: _feedSpecies, items: {'all': 'Tất cả loài', for (final s in speciesOpts) s: s}, onChanged: (v) => setState(() => _feedSpecies = v)),
          if (_feedSpecies != 'all' || _feedPeriod != 'all') AppClearFilterChip(onTap: () => setState(() { _feedSpecies = 'all'; _feedPeriod = 'all'; })),
        ]),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(children: [
            _kpiCard('Lô đang nuôi', '${batches.length}', null, AppColors.primary),
              _kpiCard('Tổng cá', _cFmt.format(totalFish), null, AppColors.info),
              _kpiCard('Sinh khối', '${_nFmt.format(totalBiomass)} kg', null, AppColors.success),
              _kpiCard('TĂ đã dùng', '${_nFmt.format(totalFeed)} kg', null, AppColors.warning),
              _kpiCard('Chi phí TĂ', '${_cFmt.format(totalCost.round())}đ', null, AppColors.error),
          ]),
        ),
        _TableHeader(title: 'Thức ăn theo lô cá / ao (${batches.length} lô)'),
        Expanded(
          child: batches.isEmpty
              ? const _EmptyMsg(icon: Icons.restaurant_rounded, msg: 'Chưa có dữ liệu')
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildDataTable(
                    columns: const ['Ao', 'Loài', 'SL cá', 'TL/con', 'Sinh khối (kg)', 'Hệ số TĂ', 'TĂ/ngày (kg)', 'Tổng TĂ (kg)', 'FCR', 'Chi phí TĂ', 'Ngày nuôi'],
                    rows: rows,
                    cellColors: colors,
                  ),
                ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TAB 11: TĂNG TRƯỞNG (Biểu đồ & bảng đo size)
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildGrowthTab() {
    final growthCutoff = _periodCutoff(_growthPeriod);
    var allMeasurements = dp.sizeMeasurements.toList()..sort((a, b) => b.date.compareTo(a.date));
    if (growthCutoff != null) allMeasurements = allMeasurements.where((m) => _afterCutoff(m.date, growthCutoff)).toList();
    final allBatches = dp.fishBatches.where((b) => b.status == 'active').toList();
    final speciesOpts = allBatches.map((b) => dp.speciesById(b.speciesId)?.name ?? '').toSet().where((s) => s.isNotEmpty).toList()..sort();
    final batches = _growthSpecies == 'all' ? allBatches : allBatches.where((b) => dp.speciesById(b.speciesId)?.name == _growthSpecies).toList();
    final batchIds = batches.map((b) => b.id).toSet();
    final measurements = _growthSpecies == 'all' ? allMeasurements : allMeasurements.where((m) => batchIds.contains(m.fishBatchId)).toList();

    // Group by batchId
    final grouped = <String, List<SizeMeasurement>>{};
    for (final m in dp.sizeMeasurements) {
      grouped.putIfAbsent(m.fishBatchId, () => []).add(m);
    }
    for (final list in grouped.values) {
      list.sort((a, b) => a.date.compareTo(b.date));
    }

    // Growth summary per batch
    final growthRows = <List<String>>[];
    final growthColors = <Map<int, Color?>>[];
    for (final b in batches) {
      final sp = dp.speciesById(b.speciesId);
      final pond = dp.pondById(b.pondId);
      final bMeasures = grouped[b.id] ?? [];
      final firstW = b.initialWeight;
      final lastW = b.currentWeight > 0 ? b.currentWeight : firstW;
      final firstS = b.initialSize;
      final lastS = b.currentSize > 0 ? b.currentSize : firstS;
      final weightGain = lastW - firstW;
      final days = b.daysOfCulture.clamp(1, 9999);
      final dailyGrowth = weightGain / days;
      final targetW = sp?.harvestableWeight ?? 500;
      final progress = targetW > 0 ? (lastW / targetW * 100).clamp(0, 200) : 0;
      final daysToHarvest = dailyGrowth > 0 ? ((targetW - lastW) / dailyGrowth).round() : 0;

      growthRows.add([
        pond?.code ?? '—',
        sp?.name ?? '—',
        '${firstW.toStringAsFixed(0)}g → ${lastW.toStringAsFixed(0)}g',
        '+${weightGain.toStringAsFixed(0)}g',
        '${dailyGrowth.toStringAsFixed(1)} g/ngày',
        '${firstS.toStringAsFixed(1)} → ${lastS.toStringAsFixed(1)} cm',
        '${bMeasures.length} lần',
        '${progress.toStringAsFixed(0)}%',
        '${targetW.toStringAsFixed(0)}g',
        daysToHarvest > 0 ? '~$daysToHarvest ngày' : '—',
        '$days',
      ]);
      final p = progress.toDouble();
      growthColors.add({
        7: p >= 100 ? AppColors.success : p >= 70 ? AppColors.info : p >= 40 ? AppColors.warning : AppColors.error,
      });
    }

    return Column(
      children: [
        AppFilterBar(children: [
          AppDropMapFilter(value: _growthPeriod, items: _periodItems, onChanged: (v) => setState(() => _growthPeriod = v)),
          AppDropMapFilter(value: _growthSpecies, items: {'all': 'Tất cả loài', for (final s in speciesOpts) s: s}, onChanged: (v) => setState(() => _growthSpecies = v)),
          if (_growthSpecies != 'all' || _growthPeriod != 'all') AppClearFilterChip(onTap: () => setState(() { _growthSpecies = 'all'; _growthPeriod = 'all'; })),
        ]),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(children: [
            _kpiCard('Lô theo dõi', '${batches.length}', null, AppColors.primary),
              _kpiCard('Lần đo', '${measurements.length}', null, AppColors.info),
              _kpiCard('TL TB hiện tại', '${batches.isNotEmpty ? (batches.fold(0.0, (s, b) => s + (b.currentWeight > 0 ? b.currentWeight : b.initialWeight)) / batches.length).toStringAsFixed(0) : 0}g', null, AppColors.success),
          ]),
        ),
        _TableHeader(title: 'Tăng trưởng theo lô (${batches.length} lô)'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (growthRows.isNotEmpty)
                  _buildDataTable(
                    columns: const ['Ao', 'Loài', 'Trọng lượng', 'Tăng', 'Tốc độ', 'Kích thước', 'Số lần đo', 'Tiến độ', 'Mục tiêu', 'Còn lại', 'Ngày nuôi'],
                    rows: growthRows,
                    cellColors: growthColors,
                  ),
                const SizedBox(height: 16),
                // Measurement history table
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Lịch sử đo mẫu', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 8),
                      if (measurements.isEmpty)
                        const Padding(padding: EdgeInsets.all(24), child: Text('Chưa có dữ liệu đo', style: TextStyle(color: AppColors.textSecondary)))
                      else
                        _buildDataTable(
                          columns: const ['Ngày đo', 'Ao', 'Loài', 'TL mẫu (g)', 'KT mẫu (cm)', 'Số mẫu', 'SL ước tính', 'Người đo', 'Ghi chú'],
                          rows: measurements.map((m) {
                            final b = dp.fishBatches.where((b) => b.id == m.fishBatchId).firstOrNull;
                            final sp = b != null ? dp.speciesById(b.speciesId) : null;
                            final pond = dp.pondById(m.pondId);
                            return [
                              _dFmt.format(m.date),
                              pond?.code ?? '—',
                              sp?.name ?? '—',
                              _nFmt.format(m.avgWeight),
                              _nFmt.format(m.avgLength),
                              '${m.sampleCount}',
                              m.remainingQty > 0 ? _cFmt.format(m.remainingQty) : '—',
                              m.measuredBy.isNotEmpty ? m.measuredBy : '—',
                              m.note.isNotEmpty ? m.note : '—',
                            ];
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TAB 12: HAO HỤT / TỶ LỆ SỐNG
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildMortalityTab() {
    final now = DateTime.now();
    var logs = dp.mortalityLogs.toList()
      ..sort((a, b) => (b['date'] as String? ?? '').compareTo(a['date'] as String? ?? ''));
    final batches = dp.fishBatches.where((b) => b.status == 'active').toList();

    // Period filter
    if (_mortPeriod != 'all') {
      final cutoff = _mortPeriod == 'week' ? now.subtract(const Duration(days: 7))
          : _mortPeriod == 'month' ? DateTime(now.year, now.month - 1, now.day)
          : DateTime(now.year, now.month - 3, now.day);
      logs = logs.where((ml) {
        final d = ml['date'] as String? ?? '';
        if (d.length < 10) return false;
        return DateTime.tryParse(d)?.isAfter(cutoff) ?? false;
      }).toList();
    }
    // Cause filter
    if (_mortCause != 'all') {
      logs = logs.where((ml) => (ml['cause'] as String? ?? 'Không rõ') == _mortCause).toList();
    }

    // Aggregate mortality per batch
    final batchMort = <String, int>{};
    final batchCauses = <String, Map<String, int>>{};
    for (final ml in logs) {
      final bid = ml['fishBatchId'] as String? ?? '';
      final qty = (ml['quantity'] as num?)?.toInt() ?? 0;
      final cause = ml['cause'] as String? ?? 'Không rõ';
      batchMort[bid] = (batchMort[bid] ?? 0) + qty;
      batchCauses.putIfAbsent(bid, () => {});
      batchCauses[bid]![cause] = (batchCauses[bid]![cause] ?? 0) + qty;
    }

    // Total aggregates
    final totalMort = logs.fold<int>(0, (s, m) => s + ((m['quantity'] as num?)?.toInt() ?? 0));
    // Cause summary
    final causeSummary = <String, int>{};
    for (final ml in logs) {
      final cause = ml['cause'] as String? ?? 'Không rõ';
      final qty = (ml['quantity'] as num?)?.toInt() ?? 0;
      causeSummary[cause] = (causeSummary[cause] ?? 0) + qty;
    }
    final sortedCauses = causeSummary.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final causeOpts = dp.mortalityLogs.map((ml) => ml['cause'] as String? ?? 'Không rõ').toSet().toList()..sort();

    return Column(
      children: [
        AppFilterBar(children: [
          AppDropMapFilter(value: _mortPeriod, items: const {'all': 'Tất cả', 'week': '7 ngày', 'month': '30 ngày', 'quarter': '90 ngày'}, onChanged: (v) => setState(() => _mortPeriod = v)),
          AppDropMapFilter(value: _mortCause, items: {'all': 'Tất cả NN', for (final c in causeOpts) c: c}, onChanged: (v) => setState(() => _mortCause = v)),
          if (_mortPeriod != 'all' || _mortCause != 'all') AppClearFilterChip(onTap: () => setState(() { _mortPeriod = 'all'; _mortCause = 'all'; })),
        ]),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(children: [
            _kpiCard('Tổng hao hụt', _cFmt.format(totalMort), null, AppColors.error),
              _kpiCard('Số lần ghi nhận', '${logs.length}', null, AppColors.warning),
              _kpiCard('Nguyên nhân chính', sortedCauses.isNotEmpty ? sortedCauses.first.key : '—', null, AppColors.info),
          ]),
        ),
        _TableHeader(title: 'Hao hụt theo lô (${batches.length} lô)'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Per-batch mortality
                _buildDataTable(
                  columns: const ['Ao', 'Loài', 'SL ban đầu', 'SL hiện tại', 'Hao hụt', 'Tỷ lệ sống (%)', 'Nguyên nhân chính'],
                  rows: batches.map((b) {
                    final pond = dp.pondById(b.pondId);
                    final sp = dp.speciesById(b.speciesId);
                    final mort = batchMort[b.id] ?? b.mortalityQuantity;
                    final causes = batchCauses[b.id] ?? {};
                    final topCause = causes.isNotEmpty ? (causes.entries.toList()..sort((a, c) => c.value.compareTo(a.value))).first.key : '—';
                    return [
                      pond?.code ?? '—',
                      sp?.name ?? '—',
                      _cFmt.format(b.initialQuantity),
                      _cFmt.format(b.currentQuantity),
                      _cFmt.format(mort),
                      b.survivalRate.toStringAsFixed(1),
                      topCause,
                    ];
                  }).toList(),
                  cellColors: batches.map((b) {
                    return {
                      5: b.survivalRate < 70 ? AppColors.error : b.survivalRate < 85 ? AppColors.warning : AppColors.success,
                    };
                  }).toList(),
                ),
                const SizedBox(height: 16),
                // Cause breakdown
                if (sortedCauses.isNotEmpty) Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Thống kê nguyên nhân hao hụt', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 8),
                      _buildDataTable(
                        columns: const ['Nguyên nhân', 'Số lượng', 'Tỷ lệ (%)'],
                        rows: sortedCauses.map((e) => [
                          e.key,
                          _cFmt.format(e.value),
                          totalMort > 0 ? '${(e.value / totalMort * 100).toStringAsFixed(1)}%' : '0%',
                        ]).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Recent logs
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Lịch sử ghi nhận hao hụt', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 8),
                      if (logs.isEmpty)
                        const Padding(padding: EdgeInsets.all(24), child: Text('Chưa ghi nhận hao hụt', style: TextStyle(color: AppColors.textSecondary)))
                      else
                        _buildDataTable(
                          columns: const ['Ngày', 'Ao', 'Lô cá', 'Số lượng', 'Nguyên nhân', 'Ghi chú'],
                          rows: logs.take(50).map((ml) {
                            final bid = ml['fishBatchId'] as String? ?? '';
                            final pid = ml['pondId'] as String? ?? '';
                            final pond = dp.pondById(pid);
                            final batch = dp.fishBatches.where((b) => b.id == bid).firstOrNull;
                            final sp = batch != null ? dp.speciesById(batch.speciesId) : null;
                            final date = ml['date'] as String? ?? '';
                            return [
                              date.length >= 10 ? _dFmt.format(DateTime.parse(date)) : '—',
                              pond?.code ?? '—',
                              sp?.name ?? '—',
                              _cFmt.format((ml['quantity'] as num?)?.toInt() ?? 0),
                              ml['cause'] as String? ?? '—',
                              (ml['note'] as String? ?? '').isNotEmpty ? (ml['note'] as String) : '—',
                            ];
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TAB 13: BỆNH & ĐIỀU TRỊ
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildDiseaseTab() {
    final diseaseCutoff = _periodCutoff(_diseasePeriod);
    var diseases = dp.diseaseLogs.toList()..sort((a, b) => b.detectedDate.compareTo(a.detectedDate));
    var treatments = dp.treatmentLogs.toList()..sort((a, b) => b.startDate.compareTo(a.startDate));

    // Apply period filter
    if (diseaseCutoff != null) {
      diseases = diseases.where((d) => _afterCutoff(d.detectedDate, diseaseCutoff)).toList();
      treatments = treatments.where((t) => _afterCutoff(t.startDate, diseaseCutoff)).toList();
    }
    // Apply status filter
    if (_diseaseStatus != 'all') {
      diseases = diseases.where((d) => d.status == _diseaseStatus).toList();
      final pondIds = diseases.map((d) => d.pondId).toSet();
      treatments = treatments.where((t) => pondIds.contains(t.pondId)).toList();
    }
    // Apply severity filter
    if (_diseaseSeverity != 'all') {
      diseases = diseases.where((d) => d.severity == _diseaseSeverity).toList();
    }

    final activeDisease = diseases.where((d) => d.status != 'resolved').length;
    final resolvedDisease = diseases.where((d) => d.status == 'resolved').length;
    final activeTreatment = treatments.where((t) => t.status == 'in_progress').length;
    final withdrawalActive = treatments.where((t) => t.isWithdrawalActive).length;

    // Disease name frequency
    final diseaseFreq = <String, int>{};
    for (final d in diseases) {
      diseaseFreq[d.diseaseName] = (diseaseFreq[d.diseaseName] ?? 0) + 1;
    }
    final topDiseases = diseaseFreq.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        AppFilterBar(children: [
          AppDropMapFilter(value: _diseasePeriod, items: _periodItems, onChanged: (v) => setState(() => _diseasePeriod = v)),
          AppDropMapFilter(value: _diseaseStatus, items: const {'all': 'Tất cả TT', 'detected': 'Phát hiện', 'treating': 'Đang trị', 'resolved': 'Đã khỏi', 'recurring': 'Tái phát'}, onChanged: (v) => setState(() => _diseaseStatus = v)),
          AppDropMapFilter(value: _diseaseSeverity, items: const {'all': 'Tất cả MĐ', 'mild': 'Nhẹ', 'moderate': 'TB', 'severe': 'Nặng'}, onChanged: (v) => setState(() => _diseaseSeverity = v)),
          if (_diseaseStatus != 'all' || _diseaseSeverity != 'all' || _diseasePeriod != 'all') AppClearFilterChip(onTap: () => setState(() { _diseaseStatus = 'all'; _diseaseSeverity = 'all'; _diseasePeriod = 'all'; })),
        ]),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(children: [
            _kpiCard('Bệnh đang theo dõi', '$activeDisease', null, AppColors.error),
              _kpiCard('Đã khỏi', '$resolvedDisease', null, AppColors.success),
              _kpiCard('Đang điều trị', '$activeTreatment', null, AppColors.warning),
              _kpiCard('Đang cách ly', '$withdrawalActive', null, AppColors.info),
          ]),
        ),
        _TableHeader(title: 'Danh sách bệnh (${diseases.length})'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Disease log table
                if (diseases.isEmpty)
                  const Padding(padding: EdgeInsets.all(24), child: _EmptyMsg(icon: Icons.coronavirus_rounded, msg: 'Chưa ghi nhận bệnh'))
                else
                  _buildDataTable(
                    columns: const ['Ngày', 'Ao', 'Bệnh', 'Mức độ', 'Trạng thái', 'Triệu chứng'],
                    rows: diseases.map((d) {
                      final pond = dp.pondById(d.pondId);
                      return [
                        _dFmt.format(d.detectedDate),
                        pond?.code ?? '—',
                        d.diseaseName,
                        d.severity == 'severe' ? 'Nặng' : d.severity == 'moderate' ? 'TB' : 'Nhẹ',
                        d.status == 'resolved' ? 'Đã khỏi' : d.status == 'treating' ? 'Đang trị' : d.status == 'recurring' ? 'Tái phát' : 'Phát hiện',
                        d.symptoms.isNotEmpty ? d.symptoms : '—',
                      ];
                    }).toList(),
                    cellColors: diseases.map((d) {
                      return {
                        3: d.severity == 'severe' ? AppColors.error : d.severity == 'moderate' ? AppColors.warning : AppColors.success,
                        4: d.status == 'resolved' ? AppColors.success : d.status == 'treating' ? AppColors.warning : AppColors.error,
                      };
                    }).toList(),
                  ),
                const SizedBox(height: 16),
                // Treatment table
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Phác đồ điều trị', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 8),
                      if (treatments.isEmpty)
                        const Padding(padding: EdgeInsets.all(24), child: Text('Chưa có', style: TextStyle(color: AppColors.textSecondary)))
                      else
                        _buildDataTable(
                          columns: const ['Ao', 'Thuốc', 'Liều', 'Cách dùng', 'Ngày BĐ', 'Thời gian', 'Cách ly', 'Trạng thái'],
                          rows: treatments.map((t) {
                            final pond = dp.pondById(t.pondId);
                            final methodLabel = t.method == 'bath' ? 'Tắm' : t.method == 'feed_mix' ? 'Trộn TĂ' : t.method == 'splash' ? 'Tát' : t.method;
                            return [
                              pond?.code ?? '—',
                              t.medicineName,
                              '${t.dosage} ${t.dosageUnit}',
                              methodLabel,
                              _dFmt.format(t.startDate),
                              '${t.durationDays} ngày',
                              t.withdrawalDays > 0 ? '${t.withdrawalDays} ngày' : '—',
                              t.status == 'completed' ? 'Xong' : t.status == 'in_progress' ? 'Đang trị' : 'Huỷ',
                            ];
                          }).toList(),
                          cellColors: treatments.map((t) {
                            return {
                              7: t.status == 'completed' ? AppColors.success : t.status == 'in_progress' ? AppColors.warning : AppColors.textHint,
                            };
                          }).toList(),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Top diseases
                if (topDiseases.isNotEmpty) Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Bệnh thường gặp', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 8),
                      _buildDataTable(
                        columns: const ['Bệnh', 'Số lần', 'Tỷ lệ'],
                        rows: topDiseases.map((e) => [
                          e.key,
                          '${e.value} lần',
                          '${(e.value / diseases.length * 100).toStringAsFixed(0)}%',
                        ]).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TAB 14: NHẬP / XUẤT KHO
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildStockIOTab() {
    final stockCutoff = _periodCutoff(_stockIOPeriod);
    var receipts = dp.stockReceipts.toList()..sort((a, b) => b.date.compareTo(a.date));
    var issues = dp.stockIssues.toList()..sort((a, b) => b.date.compareTo(a.date));

    // Period filter
    if (stockCutoff != null) {
      receipts = receipts.where((r) => _afterCutoff(r.date, stockCutoff)).toList();
      issues = issues.where((i) => _afterCutoff(i.date, stockCutoff)).toList();
    }
    // Status filter
    if (_stockIOStatus != 'all') {
      receipts = receipts.where((r) => r.status == _stockIOStatus).toList();
      issues = issues.where((i) => i.status == _stockIOStatus).toList();
    }

    final totalIn = receipts.where((r) => r.status == 'approved').fold(0.0, (s, r) => s + r.totalAmount);
    final totalOut = issues.where((i) => i.status == 'approved').fold(0.0, (s, i) => s + i.totalAmount);
    final feedIssues = issues.where((i) => i.type == 'feeding' && i.status == 'approved').length;
    final saleIssues = issues.where((i) => i.type == 'sale' && i.status == 'approved').length;

    // product movement summary
    final productIn = <String, double>{};
    final productOut = <String, double>{};
    for (final r in receipts.where((r) => r.status == 'approved')) {
      for (final it in r.items) {
        final pid = it['productId'] as String? ?? '';
        final qty = (it['receivedQty'] as num?)?.toDouble() ?? (it['qty'] as num?)?.toDouble() ?? 0;
        productIn[pid] = (productIn[pid] ?? 0) + qty;
      }
    }
    for (final i in issues.where((i) => i.status == 'approved')) {
      for (final it in i.items) {
        final pid = it['productId'] as String? ?? '';
        final qty = (it['qty'] as num?)?.toDouble() ?? 0;
        productOut[pid] = (productOut[pid] ?? 0) + qty;
      }
    }
    final allPids = {...productIn.keys, ...productOut.keys};

    return Column(
      children: [
        AppFilterBar(children: [
          AppDropMapFilter(value: _stockIOPeriod, items: _periodItems, onChanged: (v) => setState(() => _stockIOPeriod = v)),
          AppDropMapFilter(value: _stockIOType, items: const {'all': 'Tất cả', 'receipt': 'Phiếu nhập', 'issue': 'Phiếu xuất'}, onChanged: (v) => setState(() => _stockIOType = v)),
          AppDropMapFilter(value: _stockIOStatus, items: const {'all': 'Tất cả TT', 'approved': 'Đã duyệt', 'draft': 'Nháp'}, onChanged: (v) => setState(() => _stockIOStatus = v)),
          if (_stockIOType != 'all' || _stockIOStatus != 'all' || _stockIOPeriod != 'all') AppClearFilterChip(onTap: () => setState(() { _stockIOType = 'all'; _stockIOStatus = 'all'; _stockIOPeriod = 'all'; })),
        ]),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(children: [
            _kpiCard('Phiếu nhập', '${receipts.length}', null, AppColors.success),
              _kpiCard('Phiếu xuất', '${issues.length}', null, AppColors.warning),
              _kpiCard('GT nhập', '${_cFmt.format(totalIn.round())}đ', null, AppColors.info),
              _kpiCard('GT xuất', '${_cFmt.format(totalOut.round())}đ', null, AppColors.error),
              _kpiCard('Cho ăn', '$feedIssues lần', null, AppColors.primary),
          ]),
        ),
        _TableHeader(title: 'Tổng hợp nhập xuất kho'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Product IO summary
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tổng hợp theo sản phẩm', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 8),
                      _buildDataTable(
                        columns: const ['Sản phẩm', 'ĐVT', 'Nhập', 'Xuất', 'Tồn hiện tại', 'Tồn tối thiểu'],
                        rows: allPids.map((pid) {
                          final prod = dp.productById(pid);
                          return [
                            prod?.name ?? pid,
                            prod?.unit ?? '',
                            _nFmt.format(productIn[pid] ?? 0),
                            _nFmt.format(productOut[pid] ?? 0),
                            _nFmt.format(prod?.stock ?? 0),
                            _nFmt.format(prod?.minStock ?? 0),
                          ];
                        }).toList(),
                        cellColors: allPids.map((pid) {
                          final prod = dp.productById(pid);
                          return {
                            4: prod != null && prod.isLowStock ? AppColors.error : AppColors.success,
                          };
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Recent receipts
                if (_stockIOType != 'issue') Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Phiếu nhập kho (${receipts.length})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 8),
                      _buildDataTable(
                        columns: const ['Mã', 'Ngày', 'NCC', 'Giá trị', 'Trạng thái'],
                        rows: receipts.map((r) {
                          final sup = dp.suppliers.where((s) => s.id == r.supplierId).firstOrNull;
                          return [
                            r.code,
                            _dFmt.format(r.date),
                            sup?.name ?? '—',
                            '${_cFmt.format(r.totalAmount.round())}đ',
                            r.status == 'approved' ? 'Đã duyệt' : r.status == 'draft' ? 'Nháp' : 'Huỷ',
                          ];
                        }).toList(),
                        cellColors: receipts.map((r) => <int, Color?>{
                          4: r.status == 'approved' ? AppColors.success : r.status == 'draft' ? AppColors.warning : AppColors.textHint,
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                if (_stockIOType != 'issue') const SizedBox(height: 16),
                // Recent issues
                if (_stockIOType != 'receipt') Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Phiếu xuất kho (${issues.length})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 8),
                      _buildDataTable(
                        columns: const ['Mã', 'Ngày', 'Loại', 'Ao', 'Giá trị', 'Trạng thái'],
                        rows: issues.map((i) {
                          final pond = dp.pondById(i.pondId);
                          final typeLabel = i.type == 'feeding' ? 'Cho ăn' : i.type == 'sale' ? 'Bán' : i.type == 'usage' ? 'Sử dụng' : i.type;
                          return [
                            i.code,
                            _dFmt.format(i.date),
                            typeLabel,
                            pond?.code ?? '—',
                            '${_cFmt.format(i.totalAmount.round())}đ',
                            i.status == 'approved' ? 'Đã duyệt' : i.status == 'draft' ? 'Nháp' : 'Huỷ',
                          ];
                        }).toList(),
                        cellColors: issues.map((i) => <int, Color?>{
                          5: i.status == 'approved' ? AppColors.success : i.status == 'draft' ? AppColors.warning : AppColors.textHint,
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TAB 15: NHÂN SỰ & CÔNG VIỆC
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildStaffTab() {
    final staffCutoff = _periodCutoff(_staffPeriod);
    final employees = dp.employees.toList();
    var tasks = dp.tasks.toList();
    final today = DateTime.now();

    // Period filter on tasks
    if (staffCutoff != null) {
      tasks = tasks.where((t) => _afterCutoff(t.dueDate, staffCutoff)).toList();
    }

    // Role filter
    final roleOpts = employees.map((e) => e.role).where((r) => r.isNotEmpty).toSet().toList()..sort();
    final filteredEmps = _staffRole == 'all' ? employees : employees.where((e) => e.role == _staffRole).toList();
    final empIds = filteredEmps.map((e) => e.id).toSet();

    // Task status filter
    if (_staffTaskStatus == 'done') {
      tasks = tasks.where((t) => t.status == 'done').toList();
    } else if (_staffTaskStatus == 'pending') {
      tasks = tasks.where((t) => t.status == 'pending' && !t.isOverdue).toList();
    } else if (_staffTaskStatus == 'overdue') {
      tasks = tasks.where((t) => t.status == 'pending' && t.isOverdue).toList();
    }
    // Also filter tasks by employee if role filter active
    if (_staffRole != 'all') {
      tasks = tasks.where((t) => empIds.contains(t.assignedTo)).toList();
    }

    final totalTasks = tasks.length;
    final doneTasks = tasks.where((t) => t.status == 'done').length;
    final pendingTasks = tasks.where((t) => t.status == 'pending').length;
    final overdueTasks = tasks.where((t) => t.status == 'pending' && t.isOverdue).length;

    // Tasks per employee
    final empTasks = <String, int>{};
    final empDone = <String, int>{};
    final empOverdue = <String, int>{};
    for (final t in tasks) {
      final eid = t.assignedTo;
      empTasks[eid] = (empTasks[eid] ?? 0) + 1;
      if (t.status == 'done') empDone[eid] = (empDone[eid] ?? 0) + 1;
      if (t.status == 'pending' && t.isOverdue) empOverdue[eid] = (empOverdue[eid] ?? 0) + 1;
    }

    // Task type breakdown
    final taskTypes = <String, int>{};
    for (final t in tasks) {
      final type = t.type.isNotEmpty ? t.type : 'other';
      taskTypes[type] = (taskTypes[type] ?? 0) + 1;
    }
    final typeLabels = {
      'feeding': 'Cho ăn', 'water_check': 'Đo nước', 'water_change': 'Thay nước',
      'transfer': 'Chuyển cá', 'maintenance': 'Bảo trì', 'treatment': 'Điều trị',
      'harvest': 'Thu hoạch', 'other': 'Khác',
    };

    return Column(
      children: [
        AppFilterBar(children: [
          AppDropMapFilter(value: _staffPeriod, items: _periodItems, onChanged: (v) => setState(() => _staffPeriod = v)),
          AppDropMapFilter(value: _staffRole, items: {'all': 'Tất cả CV', for (final r in roleOpts) r: r}, onChanged: (v) => setState(() => _staffRole = v)),
          AppDropMapFilter(value: _staffTaskStatus, items: const {'all': 'Tất cả TT', 'done': 'Hoàn thành', 'pending': 'Đang chờ', 'overdue': 'Quá hạn'}, onChanged: (v) => setState(() => _staffTaskStatus = v)),
          if (_staffRole != 'all' || _staffTaskStatus != 'all' || _staffPeriod != 'all') AppClearFilterChip(onTap: () => setState(() { _staffRole = 'all'; _staffTaskStatus = 'all'; _staffPeriod = 'all'; })),
        ]),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(children: [
            _kpiCard('Nhân viên', '${filteredEmps.length}', null, AppColors.primary),
              _kpiCard('Tổng CV', '$totalTasks', null, AppColors.info),
              _kpiCard('Hoàn thành', '$doneTasks', null, AppColors.success),
              _kpiCard('Đang chờ', '$pendingTasks', null, AppColors.warning),
              _kpiCard('Quá hạn', '$overdueTasks', null, overdueTasks > 0 ? AppColors.error : AppColors.success),
          ]),
        ),
        _TableHeader(title: 'Nhân sự & Công việc'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Employee performance table
                _buildDataTable(
                  columns: const ['Nhân viên', 'Chức vụ', 'Tổng CV', 'Hoàn thành', 'Tỷ lệ HT', 'Quá hạn'],
                  rows: filteredEmps.map((e) {
                    final total = empTasks[e.id] ?? 0;
                    final done = empDone[e.id] ?? 0;
                    final overdue = empOverdue[e.id] ?? 0;
                    final rate = total > 0 ? (done / total * 100) : 0.0;
                    return [
                      e.name,
                      e.role.isNotEmpty ? e.role : '—',
                      '$total',
                      '$done',
                      '${rate.toStringAsFixed(0)}%',
                      '$overdue',
                    ];
                  }).toList(),
                  cellColors: filteredEmps.map((e) {
                    final total = empTasks[e.id] ?? 0;
                    final done = empDone[e.id] ?? 0;
                    final overdue = empOverdue[e.id] ?? 0;
                    final rate = total > 0 ? (done / total * 100) : 100.0;
                    return {
                      4: rate >= 80 ? AppColors.success : rate >= 50 ? AppColors.warning : AppColors.error,
                      5: overdue > 0 ? AppColors.error : AppColors.success,
                    };
                  }).toList(),
                ),
                const SizedBox(height: 16),
                // Task type breakdown
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Phân bổ loại công việc', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 8),
                      _buildDataTable(
                        columns: const ['Loại CV', 'Số lượng', 'Tỷ lệ'],
                        rows: taskTypes.entries.map((e) => [
                          typeLabels[e.key] ?? e.key,
                          '${e.value}',
                          totalTasks > 0 ? '${(e.value / totalTasks * 100).toStringAsFixed(0)}%' : '0%',
                        ]).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Recent tasks
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Công việc gần đây (${math.min(tasks.length, 30)} / $totalTasks)', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 8),
                      _buildDataTable(
                        columns: const ['Tiêu đề', 'Ao', 'Nhân viên', 'Hạn', 'Trạng thái'],
                        rows: (tasks..sort((a, b) => b.dueDate.compareTo(a.dueDate))).take(30).map((t) {
                          final pond = dp.pondById(t.pondId);
                          final emp = dp.employeeById(t.assignedTo);
                          return [
                            t.title,
                            pond?.code ?? '—',
                            emp?.name ?? '—',
                            _dFmt.format(t.dueDate),
                            t.status == 'done' ? 'Xong' : (t.isOverdue ? 'Quá hạn' : 'Chờ'),
                          ];
                        }).toList(),
                        cellColors: (tasks..sort((a, b) => b.dueDate.compareTo(a.dueDate))).take(30).map((t) => <int, Color?>{
                          4: t.status == 'done' ? AppColors.success : (t.isOverdue ? AppColors.error : AppColors.warning),
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // REUSABLE DATA TABLE
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildDataTable({
    required List<String> columns,
    required List<List<String>> rows,
    List<Map<int, Color?>>? cellColors,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                columnSpacing: 16,
                headingRowHeight: 40,
                dataRowMinHeight: 36,
                dataRowMaxHeight: 44,
                headingRowColor: WidgetStateProperty.all(AppColors.primary.withAlpha(15)),
                headingTextStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                dataTextStyle: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                columns: columns.map((c) => DataColumn(label: Text(c))).toList(),
                rows: rows.asMap().entries.map((entry) {
                  final rowIdx = entry.key;
                  final row = entry.value;
                  final colors = cellColors != null && rowIdx < cellColors.length ? cellColors[rowIdx] : <int, Color?>{};
                  return DataRow(
                    color: WidgetStateProperty.resolveWith((states) => rowIdx.isOdd ? AppColors.surfaceVariant.withAlpha(80) : null),
                    cells: row.asMap().entries.map((cell) {
                      final color = colors[cell.key];
                      return DataCell(
                        Text(
                          cell.value,
                          style: TextStyle(
                            fontSize: 12,
                            color: color,
                            fontWeight: color != null ? FontWeight.w600 : null,
                          ),
                        ),
                      );
                    }).toList(),
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TAB 7: LÃI / LỖ THEO LÔ CÁ
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildProfitTab() {
    if (!_profitLoaded && dp.profitAnalysis.isEmpty) {
      return const Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.analytics_outlined, size: 48, color: AppColors.textHint),
          SizedBox(height: 12),
          Text('Nhấn vào tab này để tải dữ liệu lãi/lỗ', style: TextStyle(color: AppColors.textSecondary)),
        ],
      ));
    }
    if (dp.profitAnalysis.isEmpty) {
      return const Center(child: _EmptyMsg(icon: Icons.analytics_outlined, msg: 'Không có dữ liệu lãi/lỗ'));
    }
    var profitData = dp.profitAnalysis.toList();
    if (_profitResult == 'profit') {
      profitData = profitData.where((e) => ((e['profit'] as num?)?.toDouble() ?? 0) >= 0).toList();
    } else if (_profitResult == 'loss') {
      profitData = profitData.where((e) => ((e['profit'] as num?)?.toDouble() ?? 0) < 0).toList();
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppFilterBar(children: [
          AppDropMapFilter(value: _profitResult, items: const {'all': 'Tất cả', 'profit': 'Có lãi', 'loss': 'Bị lỗ'}, onChanged: (v) => setState(() => _profitResult = v)),
          if (_profitResult != 'all') AppClearFilterChip(onTap: () => setState(() => _profitResult = 'all')),
        ]),
        const SizedBox(height: 8),
        // Summary
        Row(
          children: [
            _kpiCard(
              'Tổng doanh thu',
              _cFmt.format(profitData.fold(0.0, (s, e) => s + ((e['revenue'] as num?)?.toDouble() ?? 0))),
              null, AppColors.success,
            ),
            const SizedBox(width: 8),
            _kpiCard(
              'Tổng chi phí',
              _cFmt.format(profitData.fold(0.0, (s, e) => s + ((e['totalCost'] as num?)?.toDouble() ?? 0))),
              null, AppColors.error,
            ),
            const SizedBox(width: 8),
            _kpiCard(
              'Lợi nhuận ròng',
              _cFmt.format(profitData.fold(0.0, (s, e) => s + ((e['profit'] as num?)?.toDouble() ?? 0))),
              null, AppColors.primary,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Profit Bar Chart ──
        if (profitData.length >= 2)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Text('Lãi/Lỗ theo lô cá', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    _chartLegendDot(AppColors.success, 'Lãi'),
                    const SizedBox(width: 10),
                    _chartLegendDot(AppColors.error, 'Lỗ'),
                  ]),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: (profitData.length * 44.0).clamp(120, 320),
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            tooltipBorderRadius: BorderRadius.circular(8),
                            getTooltipItem: (group, gi, rod, ri) {
                              final item = profitData[group.x.toInt()];
                              final name = item['batchName']?.toString() ?? 'Lô #${item['batchId']}';
                              return BarTooltipItem('$name\n${_cFmt.format(rod.toY)}đ', const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600));
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(sideTitles: SideTitles(
                            showTitles: true, reservedSize: 70,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= profitData.length) return const SizedBox.shrink();
                              final name = profitData[idx]['batchName']?.toString() ?? 'Lô ${idx + 1}';
                              return Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Text(name.length > 10 ? '${name.substring(0, 10)}…' : name, style: const TextStyle(fontSize: 10), textAlign: TextAlign.right),
                              );
                            },
                          )),
                          bottomTitles: AxisTitles(sideTitles: SideTitles(
                            showTitles: true, reservedSize: 28,
                            getTitlesWidget: (value, meta) {
                              if (value == 0) return const SizedBox.shrink();
                              String t;
                              final v = value.abs();
                              if (v >= 1e9) { t = '${(value / 1e9).toStringAsFixed(1)}tỷ'; }
                              else if (v >= 1e6) { t = '${(value / 1e6).toStringAsFixed(0)}tr'; }
                              else if (v >= 1e3) { t = '${(value / 1e3).toStringAsFixed(0)}k'; }
                              else { t = value.toStringAsFixed(0); }
                              return Padding(padding: const EdgeInsets.only(top: 4), child: Text(t, style: const TextStyle(fontSize: 9, color: AppColors.textHint)));
                            },
                          )),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: FlGridData(show: true, drawHorizontalLine: false, getDrawingVerticalLine: (v) => FlLine(color: AppColors.border.withAlpha(50), strokeWidth: 0.7)),
                        borderData: FlBorderData(show: false),
                        barGroups: profitData.asMap().entries.map((entry) {
                          final profit = (entry.value['profit'] as num?)?.toDouble() ?? 0;
                          return BarChartGroupData(
                            x: entry.key,
                            barRods: [
                              BarChartRodData(
                                toY: profit,
                                color: profit >= 0 ? AppColors.success : AppColors.error,
                                width: 18,
                                borderRadius: profit >= 0
                                    ? const BorderRadius.horizontal(right: Radius.circular(4))
                                    : const BorderRadius.horizontal(left: Radius.circular(4)),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                      swapAnimationDuration: const Duration(milliseconds: 300),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (profitData.length >= 2) const SizedBox(height: 14),

        // Per-batch table
        ...profitData.map((item) {
          final profit = (item['profit'] as num?)?.toDouble() ?? 0;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(profit >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        color: profit >= 0 ? AppColors.success : AppColors.error, size: 22),
                                  Expanded(child: Text(item['batchName']?.toString() ?? 'Lô #${item['batchId']}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: profit >= 0 ? AppColors.success.withAlpha(20) : AppColors.error.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(profit >= 0 ? '+${_cFmt.format(profit)}' : _cFmt.format(profit),
                          style: TextStyle(color: profit >= 0 ? AppColors.success : AppColors.error, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _metricCol('Doanh thu', _cFmt.format((item['revenue'] as num?)?.toDouble() ?? 0)),
                      _metricCol('Chi thức ăn', _cFmt.format((item['feedCost'] as num?)?.toDouble() ?? 0)),
                      _metricCol('Chi khác', _cFmt.format((item['otherCost'] as num?)?.toDouble() ?? 0)),
                      _metricCol('Tổng chi', _cFmt.format((item['totalCost'] as num?)?.toDouble() ?? 0)),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _metricCol(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TAB 8: NỢ NHÀ CUNG CẤP
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildSupplierDebtTab() {
    if (!_supplierDebtLoaded && dp.supplierDebts.isEmpty) {
      return const Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_balance_wallet_outlined, size: 48, color: AppColors.textHint),
          SizedBox(height: 12),
          Text('Nhấn vào tab này để tải dữ liệu nợ NCC', style: TextStyle(color: AppColors.textSecondary)),
        ],
      ));
    }
    final debts = dp.supplierDebts.where((d) => ((d['debt'] as num?)?.toDouble() ?? 0) > 0).toList();
    if (debts.isEmpty) {
      return const Center(child: _EmptyMsg(icon: Icons.account_balance_wallet_outlined, msg: 'Không có nợ nhà cung cấp'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Total debt summary
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppColors.kpiDanger,
            borderRadius: BorderRadius.circular(AppSizes.borderRadius),
          ),
          child: Row(children: [
            const Icon(Icons.account_balance_wallet, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tổng nợ nhà cung cấp', style: TextStyle(color: Colors.white70, fontSize: 13)),
                Text('${_cFmt.format(dp.totalSupplierDebt)} đ',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              ],
            )),
          ]),
        ),
        // Per-supplier list
        ...debts.map((d) => Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.error.withAlpha(20),
              child: const Icon(Icons.local_shipping, color: AppColors.error, size: 20),
            ),
            title: Text(d['supplierName']?.toString() ?? '—', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('Mua: ${_cFmt.format((d['totalPurchase'] as num?)?.toDouble() ?? 0)} • Trả: ${_cFmt.format((d['totalPaid'] as num?)?.toDouble() ?? 0)}',
              style: const TextStyle(fontSize: 12)),
            trailing: Text('${_cFmt.format((d['debt'] as num?)?.toDouble() ?? 0)} đ',
              style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        )),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TAB 9: SỔ QUỸ (CASH BOOK)
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildCashBookTab() {
    final now = DateTime.now();
    var vouchers = dp.paymentVouchers.where((v) => v.status == 'confirmed').toList();
    final draftVouchers = dp.paymentVouchers.where((v) => v.status == 'draft').toList();

    // ── Filter by period ──
    if (_cashPeriod == 'today') {
      vouchers = vouchers.where((v) => v.date.year == now.year && v.date.month == now.month && v.date.day == now.day).toList();
    } else if (_cashPeriod == 'week') {
      final weekAgo = now.subtract(const Duration(days: 7));
      vouchers = vouchers.where((v) => v.date.isAfter(weekAgo)).toList();
    } else if (_cashPeriod == 'month') {
      vouchers = vouchers.where((v) => v.date.year == now.year && v.date.month == now.month).toList();
    } else if (_cashPeriod == 'quarter') {
      final q = ((now.month - 1) ~/ 3) * 3 + 1;
      vouchers = vouchers.where((v) => v.date.year == now.year && v.date.month >= q && v.date.month < q + 3).toList();
    }

    // ── Filter by type ──
    if (_cashType == 'receipt') {
      vouchers = vouchers.where((v) => v.isReceipt).toList();
    } else if (_cashType == 'payment') {
      vouchers = vouchers.where((v) => v.isPayment).toList();
    }

    // ── Filter by method ──
    if (_cashMethod != 'all') {
      vouchers = vouchers.where((v) => v.paymentMethod == _cashMethod).toList();
    }

    vouchers.sort((a, b) => b.date.compareTo(a.date));

    // ── Calculate totals ──
    final totalIn = vouchers.where((v) => v.isReceipt).fold(0.0, (s, v) => s + v.amount);
    final totalOut = vouchers.where((v) => v.isPayment).fold(0.0, (s, v) => s + v.amount);
    final balance = totalIn - totalOut;

    // ── Overall balance (all time, all confirmed) ──
    final overallIn = dp.totalReceipts;
    final overallOut = dp.totalPayments;
    final overallBalance = overallIn - overallOut;

    // ── Group by date ──
    final grouped = <String, List<PaymentVoucher>>{};
    for (final v in vouchers) {
      final key = _dFmt.format(v.date);
      grouped.putIfAbsent(key, () => []).add(v);
    }

    final hasFilter = _cashType != 'all' || _cashMethod != 'all' || _cashPeriod != 'all';

    return Column(
      children: [
        // ── Summary cards ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: overallBalance >= 0
                  ? AppColors.kpiSuccess
                  : AppColors.kpiDanger,
              borderRadius: BorderRadius.circular(AppSizes.borderRadius),
            ),
            child: Column(children: [
              Row(children: [
                const Icon(Icons.account_balance, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Số dư quỹ hiện tại', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    Text('${_cFmt.format(overallBalance)} đ',
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                  ],
                )),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _cashSummaryItem('Tổng thu', overallIn, Icons.arrow_downward_rounded, const Color(0xFF34D399))),
                const SizedBox(width: 10),
                Expanded(child: _cashSummaryItem('Tổng chi', overallOut, Icons.arrow_upward_rounded, const Color(0xFFFCA5A5))),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 8),

        // ── Period filtered summary ──
        if (_cashPeriod != 'all')
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _kpiCard('Thu kỳ này', '${_cFmt.format(totalIn)}đ', null, AppColors.success),
              const SizedBox(width: 8),
              _kpiCard('Chi kỳ này', '${_cFmt.format(totalOut)}đ', null, AppColors.error),
              const SizedBox(width: 8),
              _kpiCard('Chênh lệch', '${balance >= 0 ? '+' : ''}${_cFmt.format(balance)}đ', null, balance >= 0 ? AppColors.success : AppColors.error),
            ]),
          ),
        if (_cashPeriod != 'all') const SizedBox(height: 8),

        // ── Filters ──
        AppFilterBar(children: [
          AppDropMapFilter(value: _cashPeriod, items: const {'all': 'Tất cả', 'today': 'Hôm nay', 'week': 'Tuần này', 'month': 'Tháng này', 'quarter': 'Quý này'}, onChanged: (v) => setState(() => _cashPeriod = v)),
          AppDropMapFilter(value: _cashType, items: const {'all': 'Thu & Chi', 'receipt': 'Phiếu thu', 'payment': 'Phiếu chi'}, onChanged: (v) => setState(() => _cashType = v)),
          AppDropMapFilter(value: _cashMethod, items: const {'all': 'PT thanh toán', 'cash': 'Tiền mặt', 'transfer': 'Chuyển khoản'}, onChanged: (v) => setState(() => _cashMethod = v)),
          if (hasFilter) ...[const SizedBox(width: 6), AppClearFilterChip(onTap: () => setState(() { _cashType = 'all'; _cashMethod = 'all'; _cashPeriod = 'all'; }))],
        ]),

        // ── Transaction count ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(children: [
            Text('${vouchers.length} giao dịch', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const Spacer(),
            if (vouchers.isNotEmpty)
              Text('Thu: ${_cFmt.format(totalIn)}đ  •  Chi: ${_cFmt.format(totalOut)}đ',
                style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
          ]),
        ),

        // ── Transaction list ──
        Expanded(
          child: vouchers.isEmpty
              ? const Center(child: _EmptyMsg(icon: Icons.menu_book_rounded, msg: 'Chưa có giao dịch'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: grouped.length,
                  itemBuilder: (_, gi) {
                    final dateKey = grouped.keys.elementAt(gi);
                    final dayItems = grouped[dateKey]!;
                    final dayIn = dayItems.where((v) => v.isReceipt).fold(0.0, (s, v) => s + v.amount);
                    final dayOut = dayItems.where((v) => v.isPayment).fold(0.0, (s, v) => s + v.amount);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Date header ──
                        Padding(
                          padding: const EdgeInsets.only(top: 10, bottom: 6),
                          child: Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: AppColors.primary.withAlpha(15), borderRadius: BorderRadius.circular(8)),
                              child: Text(dateKey, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                            ),
                            const Spacer(),
                            if (dayIn > 0) Text('+${_cFmt.format(dayIn)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success)),
                            if (dayIn > 0 && dayOut > 0) const Text(' / ', style: TextStyle(fontSize: 11, color: AppColors.textHint)),
                            if (dayOut > 0) Text('-${_cFmt.format(dayOut)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.error)),
                          ]),
                        ),
                        // ── Day's transactions ──
                        ...dayItems.map((v) => _cashBookEntry(v)),
                      ],
                    );
                  },
                ),
        ),

        // ── Draft vouchers warning ──
        if (draftVouchers.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: AppColors.warning.withAlpha(15), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.warning.withAlpha(40))),
            child: Row(children: [
              const Icon(Icons.schedule_rounded, size: 16, color: AppColors.warning),
                  Text('${draftVouchers.length} phiếu chờ xác nhận',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warning)),
              const Spacer(),
              Text('${_cFmt.format(draftVouchers.fold(0.0, (s, v) => s + v.amount))}đ',
                style: const TextStyle(fontSize: 12, color: AppColors.warning)),
            ]),
          ),
      ],
    );
  }

  Widget _cashSummaryItem(String label, double amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withAlpha(20), borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: color.withAlpha(200))),
          Text('${_cFmt.format(amount)}đ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
        ]),
      ]),
    );
  }

  Widget _cashBookEntry(PaymentVoucher v) {
    final isIn = v.isReceipt;
    final color = isIn ? AppColors.success : AppColors.error;
    final methodIcons = {'cash': Icons.payments_rounded, 'transfer': Icons.account_balance_rounded, 'card': Icons.credit_card_rounded};
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: color.withAlpha(15), borderRadius: BorderRadius.circular(10)),
              child: Icon(isIn ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(v.code, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: color.withAlpha(12), borderRadius: BorderRadius.circular(4)),
                    child: Text(v.categoryLabel, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 3),
                Text(
                  v.description.isNotEmpty ? v.description : (v.contactName.isNotEmpty ? v.contactName : v.note),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ],
            )),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${isIn ? '+' : '-'}${_cFmt.format(v.amount)}đ',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: color)),
              const SizedBox(height: 2),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(methodIcons[v.paymentMethod] ?? Icons.money, size: 12, color: AppColors.textHint),
                      Text(v.paymentMethodLabel, style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
              ]),
            ]),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// HELPER WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

class _TableHeader extends StatelessWidget {
  final String title;
  const _TableHeader({required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 4, height: 18,
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF3B82F6), Color(0xFF6366F1)]),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ],
      ),
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
          Icon(icon, size: 56, color: AppColors.textHint),
          const SizedBox(height: 12),
          Text(msg, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}


