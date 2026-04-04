import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/payment_voucher.dart';
import '../providers/data_provider.dart';
import '../theme/app_theme.dart';
import '../services/export_service.dart';
import 'shared_widgets.dart';

// ═════════════════════════════════════════════════════════════════════════════
// PHIẾU THU CHI – Professional Payment/Receipt Voucher Management
// Tabs: Tổng quan | Phiếu thu | Phiếu chi
// ═════════════════════════════════════════════════════════════════════════════

final _currFmt = NumberFormat('#,###', 'vi');
final _dateFmt = DateFormat('dd/MM/yyyy');

class PaymentVoucherView extends StatefulWidget {
  final DataProvider dp;
  const PaymentVoucherView({super.key, required this.dp});
  @override
  State<PaymentVoucherView> createState() => _PaymentVoucherViewState();
}

class _PaymentVoucherViewState extends State<PaymentVoucherView> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _captureKey = GlobalKey();
  DataProvider get dp => widget.dp;
  String _filterStatus = 'all';
  String _filterMethod = 'all';
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Export helpers ──
  void _exportExcel() {
    final headers = ['Mã', 'Loại', 'Danh mục', 'Số tiền', 'Đối tác', 'Diễn giải', 'Ngày', 'Thanh toán', 'Trạng thái', 'Ghi chú'];
    final rows = dp.paymentVouchers.map((v) => [
      v.code, v.typeLabel, v.categoryLabel, v.amount,
      v.contactName, v.description, _dateFmt.format(v.date),
      v.paymentMethod == 'cash' ? 'Tiền mặt' : v.paymentMethod == 'transfer' ? 'Chuyển khoản' : 'Thẻ',
      v.statusLabel, v.note,
    ]).toList();
    ExportService.exportExcelAndNotify(context: context, sheetName: 'Phiếu thu chi', headers: headers, rows: rows, filePrefix: 'thu_chi');
  }

  void _exportPng() {
    ExportService.exportPngAndNotify(context: context, captureKey: _captureKey, filePrefix: 'thu_chi');
  }

  List<PaymentVoucher> _filtered(String type) {
    var list = dp.paymentVouchers.toList();
    if (type == 'receipt') list = list.where((v) => v.isReceipt).toList();
    if (type == 'payment') list = list.where((v) => v.isPayment).toList();
    if (_filterStatus != 'all') list = list.where((v) => v.status == _filterStatus).toList();
    if (_filterMethod != 'all') list = list.where((v) => v.paymentMethod == _filterMethod).toList();
    if (_dateRange != null) {
      list = list.where((v) => !v.date.isBefore(_dateRange!.start) && !v.date.isAfter(_dateRange!.end.add(const Duration(days: 1)))).toList();
    }
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    context.watch<DataProvider>();
    return RepaintBoundary(
      key: _captureKey,
      child: Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.sm),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.kpiPrimary, borderRadius: BorderRadius.circular(AppSizes.borderRadius)),
                child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Phiếu Thu Chi', style: AppText.title.copyWith(fontSize: 18)),
                    Text('Quản lý thu chi chuyên nghiệp', style: AppText.body.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
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
            ],
          ),
        ),
        // Summary cards
        _buildSummaryCards(),
        const SizedBox(height: 4),
        // Filter row
        _buildFilterRow(),
        const SizedBox(height: 4),
        // Tab bar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(12)),
          child: TabBar(
            controller: _tabCtrl,
            padding: const EdgeInsets.all(4),
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 13),
            indicator: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4)]),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            dividerHeight: 0,
            tabs: [
              Tab(child: _tabLabel(Icons.analytics_rounded, 'Tổng quan')),
              Tab(child: _tabLabel(Icons.arrow_downward_rounded, 'Phiếu thu')),
              Tab(child: _tabLabel(Icons.arrow_upward_rounded, 'Phiếu chi')),
              Tab(child: _tabLabel(Icons.history_rounded, 'Nhật ký')),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildOverviewTab(),
              _buildVoucherListTab('receipt'),
              _buildVoucherListTab('payment'),
              _buildAuditLogTab(),
            ],
          ),
        ),
      ],
    ),
    );
  }

  Widget _tabLabel(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16), const SizedBox(width: 6), Text(text)]);
  }

  // ═══════════════════════════════════════════════════════════════════
  // SUMMARY CARDS
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildSummaryCards() {
    final receipts = dp.totalReceipts;
    final payments = dp.totalPayments;
    final balance = dp.cashBalance;
    final pending = dp.paymentVouchers.where((v) => v.status == 'draft').length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 500;
          final cards = [
            Expanded(child: _SummaryCard(
              icon: Icons.arrow_downward_rounded,
              label: 'Tổng thu',
              value: '${_currFmt.format(receipts)}đ',
              color: AppColors.kpiSuccess,
            )),
            const SizedBox(width: 8),
            Expanded(child: _SummaryCard(
              icon: Icons.arrow_upward_rounded,
              label: 'Tổng chi',
              value: '${_currFmt.format(payments)}đ',
              color: AppColors.kpiDanger,
            )),
            const SizedBox(width: 8),
            Expanded(child: _SummaryCard(
              icon: Icons.account_balance_wallet_rounded,
              label: 'Số dư',
              value: '${_currFmt.format(balance)}đ',
              color: balance >= 0 ? AppColors.kpiPrimary : AppColors.kpiDanger,
            )),
            const SizedBox(width: 8),
            Expanded(child: _SummaryCard(
              icon: Icons.pending_actions_rounded,
              label: 'Chờ duyệt',
              value: '$pending',
              color: AppColors.kpiWarning,
            )),
          ];
          if (narrow) {
            return Column(children: [
              Row(children: cards.sublist(0, 3)), // Thu + Chi
              const SizedBox(height: 8),
              Row(children: cards.sublist(4)),     // Số dư + Chờ duyệt
            ]);
          }
          return Row(children: cards);
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // FILTER ROW
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildFilterRow() {
    return AppFilterBar(
      children: [
        AppTapFilter(
          label: _filterStatus == 'all' ? 'Trạng thái' : _statusName(_filterStatus),
          active: _filterStatus != 'all',
          onTap: () => _showStatusFilter(),
        ),
        AppTapFilter(
          label: _filterMethod == 'all' ? 'Hình thức' : _methodName(_filterMethod),
          active: _filterMethod != 'all',
          onTap: () => _showMethodFilter(),
        ),
        AppTapFilter(
          label: _dateRange != null ? '${_dateFmt.format(_dateRange!.start)} - ${_dateFmt.format(_dateRange!.end)}' : 'Khoảng thời gian',
          active: _dateRange != null,
          onTap: () => _pickDateRange(),
        ),
        if (_filterStatus != 'all' || _filterMethod != 'all' || _dateRange != null)
          AppClearFilterChip(onTap: () => setState(() { _filterStatus = 'all'; _filterMethod = 'all'; _dateRange = null; })),
      ],
    );
  }

  void _showStatusFilter() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.all(16), child: Text('Trạng thái', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            for (final s in ['all', 'draft', 'confirmed', 'cancelled'])
              ListTile(
                leading: Icon(s == _filterStatus ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: s == _filterStatus ? AppColors.primary : AppColors.textHint),
                title: Text(s == 'all' ? 'Tất cả' : _statusName(s)),
                onTap: () { setState(() => _filterStatus = s); Navigator.pop(ctx); },
              ),
          ],
        ),
      ),
    );
  }

  void _showMethodFilter() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.all(16), child: Text('Hình thức thanh toán', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            for (final m in ['all', 'cash', 'transfer', 'card'])
              ListTile(
                leading: Icon(m == _filterMethod ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: m == _filterMethod ? AppColors.primary : AppColors.textHint),
                title: Text(m == 'all' ? 'Tất cả' : _methodName(m)),
                onTap: () { setState(() => _filterMethod = m); Navigator.pop(ctx); },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _dateRange,
      locale: const Locale('vi'),
    );
    if (range != null) setState(() => _dateRange = range);
  }

  String _statusName(String s) {
    switch (s) {
      case 'draft': return 'Nháp';
      case 'confirmed': return 'Đã xác nhận';
      case 'cancelled': return 'Đã huỷ';
      default: return s;
    }
  }

  String _methodName(String m) {
    switch (m) {
      case 'cash': return 'Tiền mặt';
      case 'transfer': return 'Chuyển khoản';
      case 'card': return 'Thẻ';
      default: return m;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // OVERVIEW TAB
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildOverviewTab() {
    final all = _filtered('all');
    final receipts = all.where((v) => v.isReceipt).toList();
    final payments = all.where((v) => v.isPayment).toList();
    final totalIn = receipts.where((v) => v.status == 'confirmed').fold(0.0, (s, v) => s + v.amount);
    final totalOut = payments.where((v) => v.status == 'confirmed').fold(0.0, (s, v) => s + v.amount);

    // Category breakdown
    final receiptByCategory = <String, double>{};
    for (final v in receipts.where((v) => v.status == 'confirmed')) {
      receiptByCategory[v.category] = (receiptByCategory[v.category] ?? 0) + v.amount;
    }
    final paymentByCategory = <String, double>{};
    for (final v in payments.where((v) => v.status == 'confirmed')) {
      paymentByCategory[v.category] = (paymentByCategory[v.category] ?? 0) + v.amount;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Revenue card
        _OverviewSection(
          title: 'Thu nhập',
          icon: Icons.trending_up_rounded,
          iconColor: AppColors.success,
          amount: totalIn,
          count: receipts.length,
          categories: receiptByCategory,
          color: AppColors.success,
        ),
        const SizedBox(height: 12),
        // Expense card
        _OverviewSection(
          title: 'Chi phí',
          icon: Icons.trending_down_rounded,
          iconColor: AppColors.error,
          amount: totalOut,
          count: payments.length,
          categories: paymentByCategory,
          color: AppColors.error,
        ),
        const SizedBox(height: 16),
        // Recent transactions
        Row(
          children: [
            const Text('Giao dịch gần đây', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('${all.length} phiếu', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 8),
        if (all.isEmpty)
          const _EmptyMsg(icon: Icons.receipt_long_rounded, msg: 'Chưa có phiếu thu chi')
        else
          ...all.take(10).map((v) => _VoucherCard(
            voucher: v,
            dp: dp,
            onTap: () => _showVoucherDetail(v),
            onEdit: () => _showVoucherDialog(v.type, v),
            onDelete: () => _deleteVoucher(v),
            onConfirm: v.status == 'draft' ? () => _confirmVoucher(v) : null,
          )),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // VOUCHER LIST TAB
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildVoucherListTab(String type) {
    final list = _filtered(type);
    final confirmed = list.where((v) => v.status == 'confirmed').toList();
    final totalConfirmed = confirmed.fold(0.0, (s, v) => s + v.amount);

    return Column(
      children: [
        // Tab header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type == 'receipt' ? 'Phiếu thu (${list.length})' : 'Phiếu chi (${list.length})',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Đã xác nhận: ${_currFmt.format(totalConfirmed)}đ',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => _showVoucherDialog(type, null),
                icon: const Icon(Icons.add, size: 18),
                label: Text(type == 'receipt' ? 'Tạo phiếu thu' : 'Tạo phiếu chi'),
                style: FilledButton.styleFrom(
                  backgroundColor: type == 'receipt' ? AppColors.success : AppColors.error,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? _EmptyMsg(
                  icon: type == 'receipt' ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                  msg: type == 'receipt' ? 'Chưa có phiếu thu' : 'Chưa có phiếu chi',
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final v = list[i];
                    return _VoucherCard(
                      voucher: v,
                      dp: dp,
                      onTap: () => _showVoucherDetail(v),
                      onEdit: () => _showVoucherDialog(v.type, v),
                      onDelete: () => _deleteVoucher(v),
                      onConfirm: v.status == 'draft' ? () => _confirmVoucher(v) : null,
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // VOUCHER DETAIL
  // ═══════════════════════════════════════════════════════════════════

  void _showVoucherDetail(PaymentVoucher v) {
    final contact = v.contactType == 'customer' ? dp.customerById(v.contactId)
                   : v.contactType == 'supplier' ? dp.supplierById(v.contactId)
                   : v.contactType == 'employee' ? dp.employeeById(v.contactId)
                   : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(20),
          children: [
            // Handle bar
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            // Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: v.isReceipt ? AppColors.kpiSuccess : AppColors.kpiDanger,
                    borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                  ),
                  child: Icon(v.isReceipt ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.code.isNotEmpty ? v.code : v.typeLabel, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      Text(v.typeLabel, style: TextStyle(fontSize: 13, color: v.isReceipt ? AppColors.success : AppColors.error, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                _StatusChip(v.statusLabel, _statusColor(v.status)),
              ],
            ),
            const SizedBox(height: 20),
            // Amount
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: v.isReceipt ? AppColors.kpiSuccess : AppColors.kpiDanger,
                borderRadius: BorderRadius.circular(AppSizes.borderRadius),
              ),
              child: Column(
                children: [
                  const Text('Số tiền', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('${_currFmt.format(v.amount)}đ', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Details
            _DetailCard(children: [
              _DetailRow('Ngày', _dateFmt.format(v.date)),
              _DetailRow('Danh mục', v.categoryLabel),
              _DetailRow('Hình thức', v.paymentMethodLabel),
              if (v.contactName.isNotEmpty) _DetailRow(v.isReceipt ? 'Người nộp' : 'Người nhận', v.contactName),
              if (contact != null) _DetailRow('Loại', v.contactType == 'customer' ? 'Khách hàng' : v.contactType == 'supplier' ? 'Nhà cung cấp' : 'Nhân viên'),
              if (v.description.isNotEmpty) _DetailRow('Diễn giải', v.description),
              if (v.note.isNotEmpty) _DetailRow('Ghi chú', v.note),
            ]),
            const SizedBox(height: 12),
            _DetailCard(children: [
              _DetailRow('Ngày tạo', _dateFmt.format(v.createdAt)),
              if (v.createdBy.isNotEmpty) _DetailRow('Người tạo', dp.employeeById(v.createdBy)?.name ?? v.createdBy),
              if (v.approvedBy.isNotEmpty) _DetailRow('Người duyệt', dp.employeeById(v.approvedBy)?.name ?? v.approvedBy),
            ]),
            const SizedBox(height: 20),
            // Actions
            if (v.status == 'draft') ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () { Navigator.pop(ctx); _showVoucherDialog(v.type, v); },
                      icon: const Icon(Icons.edit),
                      label: const Text('Sửa'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () { Navigator.pop(ctx); _confirmVoucher(v); },
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Xác nhận'),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () { Navigator.pop(ctx); _deleteVoucher(v); },
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  label: const Text('Xoá phiếu', style: TextStyle(color: AppColors.error)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ADD/EDIT VOUCHER DIALOG
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _showVoucherDialog(String type, PaymentVoucher? existing) async {
    final isEdit = existing != null;
    final codeCtrl = TextEditingController(text: existing?.code ?? _nextCode(type));
    final amountCtrl = TextEditingController(text: isEdit && existing.amount > 0 ? existing.amount.toStringAsFixed(0) : '');
    final contactCtrl = TextEditingController(text: existing?.contactName ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final noteCtrl = TextEditingController(text: existing?.note ?? '');
    var selectedCategory = existing?.category ?? (type == 'receipt' ? 'ban_hang' : 'mua_hang');
    var selectedMethod = existing?.paymentMethod ?? 'cash';
    var selectedDate = existing?.date ?? DateTime.now();
    var selectedStatus = existing?.status ?? 'draft';
    var contactId = existing?.contactId ?? '';
    var contactType = existing?.contactType ?? '';

    final cats = type == 'receipt' ? PaymentVoucher.receiptCategories : PaymentVoucher.paymentCategories;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: type == 'receipt' ? AppColors.kpiSuccess : AppColors.kpiDanger,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(type == 'receipt' ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Text(isEdit ? 'Sửa ${type == 'receipt' ? 'phiếu thu' : 'phiếu chi'}' : 'Tạo ${type == 'receipt' ? 'phiếu thu' : 'phiếu chi'}'),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Code
                  TextFormField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(labelText: 'Mã phiếu', prefixIcon: Icon(Icons.tag)),
                  ),
                  const SizedBox(height: 12),
                  // Amount
                  TextFormField(
                    controller: amountCtrl,
                    decoration: const InputDecoration(labelText: 'Số tiền *', prefixIcon: Icon(Icons.attach_money), suffixText: 'đ'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  // Category
                  DropdownButtonFormField<String>(
                    initialValue: cats.contains(selectedCategory) ? selectedCategory : cats.first,
                    decoration: const InputDecoration(labelText: 'Danh mục', prefixIcon: Icon(Icons.category)),
                    items: cats.map((c) => DropdownMenuItem(value: c, child: Text(PaymentVoucher.categoryLabelFor(c)))).toList(),
                    onChanged: (v) => setDState(() => selectedCategory = v!),
                  ),
                  const SizedBox(height: 12),
                  // Payment method
                  DropdownButtonFormField<String>(
                    initialValue: selectedMethod,
                    decoration: const InputDecoration(labelText: 'Hình thức', prefixIcon: Icon(Icons.payment)),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Tiền mặt')),
                      DropdownMenuItem(value: 'transfer', child: Text('Chuyển khoản')),
                      DropdownMenuItem(value: 'card', child: Text('Thẻ')),
                    ],
                    onChanged: (v) => setDState(() => selectedMethod = v!),
                  ),
                  const SizedBox(height: 12),
                  // Date
                  InkWell(
                    onTap: () async {
                      final d = await showDatePicker(context: ctx, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                      if (d != null) setDState(() => selectedDate = d);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Ngày', prefixIcon: Icon(Icons.calendar_today)),
                      child: Text(_dateFmt.format(selectedDate)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Contact
                  TextFormField(
                    controller: contactCtrl,
                    decoration: InputDecoration(
                      labelText: type == 'receipt' ? 'Người nộp tiền' : 'Người nhận tiền',
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Contact type
                  DropdownButtonFormField<String>(
                    initialValue: contactType.isEmpty ? '' : contactType,
                    decoration: const InputDecoration(labelText: 'Đối tượng', prefixIcon: Icon(Icons.groups)),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('Không chọn')),
                      DropdownMenuItem(value: 'customer', child: Text('Khách hàng')),
                      DropdownMenuItem(value: 'supplier', child: Text('Nhà cung cấp')),
                      DropdownMenuItem(value: 'employee', child: Text('Nhân viên')),
                    ],
                    onChanged: (v) {
                      setDState(() {
                        contactType = v!;
                        contactId = '';
                      });
                    },
                  ),
                  // Contact ID selection
                  if (contactType == 'customer' && dp.customers.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: contactId.isNotEmpty && dp.customers.any((c) => c.id == contactId) ? contactId : null,
                      decoration: const InputDecoration(labelText: 'Chọn khách hàng', prefixIcon: Icon(Icons.person_pin)),
                      items: dp.customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                      onChanged: (v) => setDState(() {
                        contactId = v ?? '';
                        final c = dp.customerById(v ?? '');
                        if (c != null) contactCtrl.text = c.name;
                      }),
                    ),
                  ],
                  if (contactType == 'supplier' && dp.suppliers.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: contactId.isNotEmpty && dp.suppliers.any((s) => s.id == contactId) ? contactId : null,
                      decoration: const InputDecoration(labelText: 'Chọn NCC', prefixIcon: Icon(Icons.local_shipping)),
                      items: dp.suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                      onChanged: (v) => setDState(() {
                        contactId = v ?? '';
                        final s = dp.supplierById(v ?? '');
                        if (s != null) contactCtrl.text = s.name;
                      }),
                    ),
                  ],
                  if (contactType == 'employee' && dp.employees.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: contactId.isNotEmpty && dp.employees.any((e) => e.id == contactId) ? contactId : null,
                      decoration: const InputDecoration(labelText: 'Chọn nhân viên', prefixIcon: Icon(Icons.badge)),
                      items: dp.employees.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
                      onChanged: (v) => setDState(() {
                        contactId = v ?? '';
                        final e = dp.employeeById(v ?? '');
                        if (e != null) contactCtrl.text = e.name;
                      }),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Description
                  TextFormField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Diễn giải *', prefixIcon: Icon(Icons.description)),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  // Status (only for edit)
                  if (isEdit)
                    DropdownButtonFormField<String>(
                      initialValue: selectedStatus,
                      decoration: const InputDecoration(labelText: 'Trạng thái', prefixIcon: Icon(Icons.verified)),
                      items: const [
                        DropdownMenuItem(value: 'draft', child: Text('Nháp')),
                        DropdownMenuItem(value: 'confirmed', child: Text('Đã xác nhận')),
                        DropdownMenuItem(value: 'cancelled', child: Text('Đã huỷ')),
                      ],
                      onChanged: (v) => setDState(() => selectedStatus = v!),
                    ),
                  const SizedBox(height: 12),
                  // Note
                  TextFormField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(labelText: 'Ghi chú', prefixIcon: Icon(Icons.note)),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Huỷ')),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dCtx, true),
              icon: const Icon(Icons.save, size: 18),
              label: Text(isEdit ? 'Cập nhật' : 'Tạo phiếu'),
              style: FilledButton.styleFrom(backgroundColor: type == 'receipt' ? AppColors.success : AppColors.primary),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;

    final amount = double.tryParse(amountCtrl.text.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
    if (amount <= 0 || descCtrl.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số tiền và diễn giải'), backgroundColor: AppColors.error),
      );
      return;
    }

    final data = {
      'code': codeCtrl.text.trim(),
      'type': type,
      'category': selectedCategory,
      'amount': amount,
      'contactName': contactCtrl.text.trim(),
      'contactId': contactId,
      'contactType': contactType,
      'description': descCtrl.text.trim(),
      'date': selectedDate.toIso8601String(),
      'paymentMethod': selectedMethod,
      'status': selectedStatus,
      'note': noteCtrl.text.trim(),
      'createdBy': '',
      'approvedBy': selectedStatus == 'confirmed' ? '' : '',
    };

    bool success;
    if (isEdit) {
      success = await dp.update('paymentvouchers', existing.id, data);
    } else {
      success = await dp.create('paymentvouchers', data);
    }

    if (!mounted) return;
    setState(() {});
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEdit ? 'Đã cập nhật phiếu' : 'Đã tạo phiếu thành công'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  String _nextCode(String type) {
    final prefix = type == 'receipt' ? 'PT' : 'PC';
    final existing = dp.paymentVouchers.where((v) => v.type == type && v.code.startsWith(prefix)).toList();
    final num = existing.length + 1;
    return '$prefix-${num.toString().padLeft(3, '0')}';
  }

  // ═══════════════════════════════════════════════════════════════════
  // ACTIONS
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _confirmVoucher(PaymentVoucher v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Xác nhận phiếu'),
        content: Text('Xác nhận ${v.typeLabel} ${v.code} - ${_currFmt.format(v.amount)}đ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Huỷ')),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final success = await dp.update('paymentvouchers', v.id, {...v.toJson(), 'status': 'confirmed'});
    if (!mounted) return;
    setState(() {});
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xác nhận phiếu'), backgroundColor: AppColors.success),
      );
    }
  }

  Future<void> _deleteVoucher(PaymentVoucher v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Xoá phiếu'),
        content: Text('Bạn có chắc muốn xoá "${v.code.isNotEmpty ? v.code : v.typeLabel}"?'),
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
    if (ok != true || !mounted) return;
    await dp.remove('paymentvouchers', v.id);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã xoá phiếu'), backgroundColor: AppColors.success),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed': return AppColors.success;
      case 'draft': return AppColors.warning;
      case 'cancelled': return AppColors.textHint;
      default: return AppColors.textSecondary;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // AUDIT LOG TAB
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildAuditLogTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: dp.loadAuditLogs(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final logs = snap.data ?? dp.auditLogs;
        if (logs.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.history_rounded, size: 48, color: AppColors.textHint.withAlpha(80)),
              const SizedBox(height: 12),
              const Text('Chưa có nhật ký', style: TextStyle(color: AppColors.textSecondary)),
            ]),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (ctx, i) {
            final log = logs[i];
            final action = log['action'] as String? ?? '';
            final code = log['code'] as String? ?? '';
            final ts = log['timestamp'] as String? ?? '';
            final userId = log['userId'] as String? ?? '';
            final user = dp.employeeById(userId);

            IconData icon;
            Color color;
            String label;
            switch (action) {
              case 'create': icon = Icons.add_circle_rounded; color = AppColors.success; label = 'Tạo mới';
              case 'update': icon = Icons.edit_rounded; color = AppColors.warning; label = 'Sửa';
              case 'confirm': icon = Icons.check_circle_rounded; color = AppColors.primary; label = 'Duyệt';
              case 'delete': icon = Icons.delete_rounded; color = AppColors.error; label = 'Xoá';
              default: icon = Icons.info_rounded; color = AppColors.textSecondary; label = action;
            }

            String timeStr = '';
            if (ts.isNotEmpty) {
              try {
                final dt = DateTime.parse(ts);
                timeStr = _dateFmt.format(dt);
                final h = dt.hour.toString().padLeft(2, '0');
                final m = dt.minute.toString().padLeft(2, '0');
                timeStr = '$h:$m $timeStr';
              } catch (_) {
                timeStr = ts;
              }
            }

            // Build change summary
            String changes = '';
            if (action == 'update' || action == 'confirm') {
              final oldData = log['oldData'] as Map<String, dynamic>?;
              final newData = log['newData'] as Map<String, dynamic>?;
              if (oldData != null && newData != null) {
                final diffs = <String>[];
                for (final key in ['status', 'amount', 'category', 'contactName', 'note', 'paymentMethod']) {
                  if (oldData[key]?.toString() != newData[key]?.toString()) {
                    diffs.add('$key: ${oldData[key]} → ${newData[key]}');
                  }
                }
                if (diffs.isNotEmpty) changes = diffs.join(', ');
              }
            }

            return ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: color.withAlpha(25),
                child: Icon(icon, size: 18, color: color),
              ),
              title: Row(children: [
                Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: color)),
                const SizedBox(width: 8),
                Text(code, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
              ]),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (changes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(changes, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ),
                  Row(children: [
                    Icon(Icons.person_outline, size: 12, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Text(user?.name ?? userId, style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                    const Spacer(),
                    Text(timeStr, style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                  ]),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// HELPER WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _SummaryCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(AppSizes.borderRadius)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _VoucherCard extends StatelessWidget {
  final PaymentVoucher voucher;
  final DataProvider dp;
  final VoidCallback onTap, onEdit, onDelete;
  final VoidCallback? onConfirm;
  const _VoucherCard({required this.voucher, required this.dp, required this.onTap, required this.onEdit, required this.onDelete, this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final v = voucher;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: v.isReceipt ? AppColors.kpiSuccess : AppColors.kpiDanger,
                  borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                ),
                child: Icon(v.isReceipt ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (v.code.isNotEmpty) ...[
                          Text(v.code, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          const SizedBox(width: 8),
                        ],
                        _StatusChip(v.statusLabel, _statusColorFor(v.status)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(v.description.isNotEmpty ? v.description : v.categoryLabel, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 12, color: AppColors.textHint),
                        const SizedBox(width: 4),
                        Text(_dateFmt.format(v.date), style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
                        const SizedBox(width: 12),
                        Icon(Icons.payment, size: 12, color: AppColors.textHint),
                        const SizedBox(width: 4),
                        Text(v.paymentMethodLabel, style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
                        if (v.contactName.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Icon(Icons.person, size: 12, color: AppColors.textHint),
                          const SizedBox(width: 4),
                          Flexible(child: Text(v.contactName, style: const TextStyle(fontSize: 12, color: AppColors.textHint), overflow: TextOverflow.ellipsis)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${v.isReceipt ? '+' : '-'}${_currFmt.format(v.amount)}đ',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: v.isReceipt ? AppColors.success : AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildPopupMenu(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPopupMenu() {
    return PopupMenuButton<String>(
      iconSize: 20,
      icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textSecondary),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      onSelected: (val) {
        switch (val) {
          case 'edit': onEdit();
          case 'delete': onDelete();
          case 'confirm': onConfirm?.call();
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Sửa')])),
        if (onConfirm != null)
          const PopupMenuItem(value: 'confirm', child: Row(children: [Icon(Icons.check_circle, size: 18, color: AppColors.success), SizedBox(width: 8), Text('Xác nhận')])),
        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: AppColors.error), SizedBox(width: 8), Text('Xoá', style: TextStyle(color: AppColors.error))])),
      ],
    );
  }

  static Color _statusColorFor(String status) {
    switch (status) {
      case 'confirmed': return AppColors.success;
      case 'draft': return AppColors.warning;
      case 'cancelled': return AppColors.textHint;
      default: return AppColors.textSecondary;
    }
  }
}

class _OverviewSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor, color;
  final double amount;
  final int count;
  final Map<String, double> categories;
  const _OverviewSection({required this.title, required this.icon, required this.iconColor, required this.amount, required this.count, required this.categories, required this.color});

  @override
  Widget build(BuildContext context) {
    final sorted = categories.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 22),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('$count phiếu', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 8),
            Text('${_currFmt.format(amount)}đ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            if (sorted.isNotEmpty) ...[
              const Divider(height: 20),
              ...sorted.map((e) {
                final pct = amount > 0 ? (e.value / amount * 100) : 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(PaymentVoucher.categoryLabelFor(e.key), style: const TextStyle(fontSize: 13)),
                            const SizedBox(height: 2),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: pct / 100,
                                backgroundColor: AppColors.surfaceVariant,
                                color: color.withAlpha(180),
                                minHeight: 4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('${_currFmt.format(e.value)}đ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 4),
                      Text('(${pct.toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withAlpha(60))),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final List<Widget> children;
  const _DetailCard({required this.children});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: children),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  const _DetailRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
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
