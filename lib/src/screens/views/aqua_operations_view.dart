import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../providers/data_provider.dart';
import '../../models/disease_log.dart';
import '../../models/treatment_log.dart';
import '../../models/feeding_schedule.dart';
import '../../models/crop_cycle.dart';
import '../../models/equipment.dart';
import '../../models/daily_log.dart';
import '../../models/water_change_log.dart';
import '../../models/size_measurement.dart';
import '../../theme/app_theme.dart';

// ═════════════════════════════════════════════════════════════════════════════
// AQUACULTURE OPERATIONS VIEW
// Tabs: Dịch bệnh | Điều trị | Lịch cho ăn | Vụ nuôi | Thiết bị | Nhật ký | Thay nước
// ═════════════════════════════════════════════════════════════════════════════

class AquaOperationsView extends StatefulWidget {
  final DataProvider dp;
  const AquaOperationsView({super.key, required this.dp});
  @override
  State<AquaOperationsView> createState() => _AquaOperationsViewState();
}

class _AquaOperationsViewState extends State<AquaOperationsView> with TickerProviderStateMixin {
  late final TabController _tabCtrl;
  DataProvider get dp => widget.dp;
  final _dateFmt = DateFormat('dd/MM/yyyy');
  final _currFmt = NumberFormat('#,###', 'vi');

  // ── Filters ──
  String _filterPondId = '';
  String _filterBatchId = '';
  DateTime? _filterFrom;
  DateTime? _filterTo;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 8, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    );
  }

  bool _inDateRange(DateTime date) {
    if (_filterFrom != null && date.isBefore(_filterFrom!)) return false;
    if (_filterTo != null && date.isAfter(_filterTo!.add(const Duration(days: 1)))) return false;
    return true;
  }

  void _clearFilters() => setState(() {
    _filterPondId = '';
    _filterBatchId = '';
    _filterFrom = null;
    _filterTo = null;
  });

  Widget _buildFilterBar(bool hasFilter) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          // Pond filter
          _FilterDropdown(
            icon: Icons.pool_rounded,
            label: _filterPondId.isEmpty ? 'Tất cả ao' : dp.ponds.where((p) => p.id == _filterPondId).firstOrNull?.code ?? 'Ao ?',
            isActive: _filterPondId.isNotEmpty,
            items: [
              PopupMenuItem(value: '', child: const Text('Tất cả ao')),
              ...dp.ponds.map((p) => PopupMenuItem(value: p.id, child: Text(p.code))),
            ],
            onSelected: (v) => setState(() => _filterPondId = v),
          ),
          const SizedBox(width: 8),
          // Batch filter
          _FilterDropdown(
            icon: Icons.set_meal_rounded,
            label: _filterBatchId.isEmpty ? 'Tất cả lô' : dp.fishBatches.where((b) => b.id == _filterBatchId).firstOrNull?.name ?? 'Lô ?',
            isActive: _filterBatchId.isNotEmpty,
            items: [
              PopupMenuItem(value: '', child: const Text('Tất cả lô')),
              ...dp.fishBatches.where((b) => b.status == 'active').map((b) => PopupMenuItem(value: b.id, child: Text(b.name))),
            ],
            onSelected: (v) => setState(() => _filterBatchId = v),
          ),
          const SizedBox(width: 8),
          // Date from
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _filterFrom ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
              if (d != null) setState(() => _filterFrom = d);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _filterFrom != null ? AppColors.primary.withAlpha(15) : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _filterFrom != null ? AppColors.primary.withAlpha(60) : AppColors.border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.calendar_today, size: 14, color: _filterFrom != null ? AppColors.primary : AppColors.textHint),
                const SizedBox(width: 4),
                Text(_filterFrom != null ? 'Từ ${_dateFmt.format(_filterFrom!)}' : 'Từ ngày',
                    style: TextStyle(fontSize: 12, color: _filterFrom != null ? AppColors.primary : AppColors.textSecondary, fontWeight: _filterFrom != null ? FontWeight.w600 : FontWeight.normal)),
              ]),
            ),
          ),
          const SizedBox(width: 6),
          // Date to
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _filterTo ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
              if (d != null) setState(() => _filterTo = d);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _filterTo != null ? AppColors.primary.withAlpha(15) : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _filterTo != null ? AppColors.primary.withAlpha(60) : AppColors.border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.event, size: 14, color: _filterTo != null ? AppColors.primary : AppColors.textHint),
                const SizedBox(width: 4),
                Text(_filterTo != null ? 'Đến ${_dateFmt.format(_filterTo!)}' : 'Đến ngày',
                    style: TextStyle(fontSize: 12, color: _filterTo != null ? AppColors.primary : AppColors.textSecondary, fontWeight: _filterTo != null ? FontWeight.w600 : FontWeight.normal)),
              ]),
            ),
          ),
          if (hasFilter) ...[
            const SizedBox(width: 8),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _clearFilters,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: AppColors.error.withAlpha(15), borderRadius: BorderRadius.circular(8)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.close, size: 14, color: AppColors.error),
                  SizedBox(width: 4),
                  Text('Xoá bộ lọc', style: TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasFilter = _filterPondId.isNotEmpty || _filterBatchId.isNotEmpty || _filterFrom != null || _filterTo != null;
    return Column(children: [
      // ── Header ──
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(children: [
          const Icon(Icons.biotech_rounded, color: AppColors.primary, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Vận hành nuôi trồng', style: AppText.title.copyWith(fontSize: 18)),
              Text('Dịch bệnh, điều trị, cho ăn, vụ nuôi, thiết bị',
                  style: AppText.body.copyWith(color: AppColors.textSecondary, fontSize: 12)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 8),
      // ── Filter bar ──
      _buildFilterBar(hasFilter),
      // ── Tabs ──
      TabBar(
        controller: _tabCtrl,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        tabs: const [
          Tab(icon: Icon(Icons.coronavirus_rounded, size: 18), text: 'Dịch bệnh'),
          Tab(icon: Icon(Icons.medical_services_rounded, size: 18), text: 'Điều trị'),
          Tab(icon: Icon(Icons.restaurant_rounded, size: 18), text: 'Lịch cho ăn'),
          Tab(icon: Icon(Icons.agriculture_rounded, size: 18), text: 'Vụ nuôi'),
          Tab(icon: Icon(Icons.settings_rounded, size: 18), text: 'Thiết bị'),
          Tab(icon: Icon(Icons.edit_note_rounded, size: 18), text: 'Nhật ký'),
          Tab(icon: Icon(Icons.water_drop_rounded, size: 18), text: 'Thay nước'),
          Tab(icon: Icon(Icons.straighten_rounded, size: 18), text: 'Đo kích thước'),
        ],
      ),
      Expanded(
        child: TabBarView(controller: _tabCtrl, children: [
          _buildDiseaseTab(),
          _buildTreatmentTab(),
          _buildFeedingScheduleTab(),
          _buildCropCycleTab(),
          _buildEquipmentTab(),
          _buildDailyLogTab(),
          _buildWaterChangeTab(),
          _buildSizeMeasurementTab(),
        ]),
      ),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 1: DỊCH BỆNH
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildDiseaseTab() {
    final logs = dp.diseaseLogs.where((d) {
      if (_filterPondId.isNotEmpty && d.pondId != _filterPondId) return false;
      if (_filterBatchId.isNotEmpty && d.fishBatchId != _filterBatchId) return false;
      if (!_inDateRange(d.detectedDate)) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.detectedDate.compareTo(a.detectedDate));
    return Column(children: [
      _buildHeader(
        'Theo dõi dịch bệnh',
        '${logs.where((d) => d.status == 'detected' || d.status == 'treating').length} ca đang xử lý',
        Icons.coronavirus_rounded,
        AppColors.error,
        () => _showDiseaseDialog(),
      ),
      Expanded(child: logs.isEmpty
          ? _emptyState(Icons.coronavirus_outlined, 'Chưa ghi nhận dịch bệnh')
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: logs.length,
              itemBuilder: (_, i) => _buildDiseaseCard(logs[i]),
            )),
    ]);
  }

  Widget _buildDiseaseCard(DiseaseLog d) {
    final pond = dp.ponds.where((p) => p.id == d.pondId).firstOrNull;
    final severityColor = d.severity == 'severe' ? AppColors.error
        : d.severity == 'moderate' ? AppColors.warning : AppColors.success;
    final statusLabel = {'detected': 'Phát hiện', 'treating': 'Đang trị', 'resolved': 'Đã khỏi', 'recurring': 'Tái phát'}[d.status] ?? d.status;
    final statusColor = d.status == 'resolved' ? AppColors.success
        : d.status == 'treating' ? AppColors.info : AppColors.error;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: severityColor.withAlpha(30),
          child: Icon(Icons.coronavirus_rounded, color: severityColor, size: 22),
        ),
        title: Text(d.diseaseName, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Ao: ${pond?.code ?? '?'} · ${_dateFmt.format(d.detectedDate)}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          if (d.symptoms.isNotEmpty) Text(d.symptoms, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Row(children: [
            _chip(statusLabel, statusColor),
            const SizedBox(width: 6),
            _chip({'severe': 'Nghiêm trọng', 'moderate': 'Trung bình', 'mild': 'Nhẹ'}[d.severity] ?? d.severity, severityColor),
            if (d.affectedQuantity > 0) ...[
              const SizedBox(width: 6),
              _chip('${d.affectedQuantity} con', AppColors.textSecondary),
            ],
          ]),
        ]),
        trailing: PopupMenuButton<String>(
          onSelected: (v) => _onDiseaseAction(v, d),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Sửa')),
            const PopupMenuItem(value: 'treat', child: Text('Thêm điều trị')),
            const PopupMenuItem(value: 'resolve', child: Text('Đánh dấu khỏi')),
            const PopupMenuItem(value: 'delete', child: Text('Xóa')),
          ],
        ),
      ),
    );
  }

  void _onDiseaseAction(String action, DiseaseLog d) async {
    switch (action) {
      case 'edit': _showDiseaseDialog(d);
      case 'treat': _showTreatmentDialog(TreatmentLog(id: '', diseaseLogId: d.id, pondId: d.pondId, fishBatchId: d.fishBatchId, medicineName: '', startDate: DateTime.now(), createdAt: DateTime.now()));
      case 'resolve':
        await dp.update('diseaselogs', d.id, {'status': 'resolved'});
        _showSnack('Đã đánh dấu khỏi bệnh');
      case 'delete':
        await dp.remove('diseaselogs', d.id);
        _showSnack('Đã xóa');
    }
  }

  Future<void> _showDiseaseDialog([DiseaseLog? existing]) async {
    final isEdit = existing != null;
    final nameC = TextEditingController(text: existing?.diseaseName ?? '');
    final sympC = TextEditingController(text: existing?.symptoms ?? '');
    final noteC = TextEditingController(text: existing?.note ?? '');
    final affC = TextEditingController(text: existing != null ? existing.affectedQuantity.toString() : '0');
    String severity = existing?.severity ?? 'moderate';
    String status = existing?.status ?? 'detected';
    String pondId = existing?.pondId ?? '';
    String batchId = existing?.fishBatchId ?? '';
    DateTime date = existing?.detectedDate ?? DateTime.now();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(isEdit ? 'Sửa bệnh' : 'Ghi nhận bệnh'),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Tên bệnh *', prefixIcon: Icon(Icons.coronavirus))),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: pondId.isEmpty ? null : pondId,
                decoration: const InputDecoration(labelText: 'Ao', prefixIcon: Icon(Icons.pool)),
                items: dp.ponds.map((p) => DropdownMenuItem(value: p.id, child: Text(p.code))).toList(),
                onChanged: (v) => setSt(() => pondId = v ?? ''),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: batchId.isEmpty ? null : batchId,
                decoration: const InputDecoration(labelText: 'Lô cá', prefixIcon: Icon(Icons.set_meal)),
                items: dp.fishBatches.where((b) => b.status == 'active').map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                onChanged: (v) => setSt(() => batchId = v ?? ''),
              ),
              const SizedBox(height: 10),
              TextField(controller: sympC, decoration: const InputDecoration(labelText: 'Triệu chứng', prefixIcon: Icon(Icons.description)), maxLines: 2),
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
                Expanded(child: DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'Trạng thái'),
                  items: const [
                    DropdownMenuItem(value: 'detected', child: Text('Phát hiện')),
                    DropdownMenuItem(value: 'treating', child: Text('Đang trị')),
                    DropdownMenuItem(value: 'resolved', child: Text('Đã khỏi')),
                    DropdownMenuItem(value: 'recurring', child: Text('Tái phát')),
                  ],
                  onChanged: (v) => setSt(() => status = v ?? 'detected'),
                )),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(controller: affC, decoration: const InputDecoration(labelText: 'Số con bị ảnh hưởng'), keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: InkWell(
                  onTap: () async {
                    final d = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2030));
                    if (d != null) setSt(() => date = d);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Ngày phát hiện'),
                    child: Text(_dateFmt.format(date)),
                  ),
                )),
              ]),
              const SizedBox(height: 10),
              TextField(controller: noteC, decoration: const InputDecoration(labelText: 'Ghi chú'), maxLines: 2),
            ])),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isEdit ? 'Cập nhật' : 'Thêm')),
          ],
        ),
      ),
    );
    if (ok == true && nameC.text.isNotEmpty) {
      final data = {
        'diseaseName': nameC.text, 'symptoms': sympC.text,
        'severity': severity, 'status': status,
        'pondId': pondId, 'fishBatchId': batchId,
        'detectedDate': date.toIso8601String(),
        'affectedQuantity': int.tryParse(affC.text) ?? 0,
        'note': noteC.text,
      };
      if (isEdit) {
        await dp.update('diseaselogs', existing.id, data);
      } else {
        await dp.create('diseaselogs', data);
      }
      _showSnack(isEdit ? 'Đã cập nhật' : 'Đã ghi nhận bệnh');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 2: ĐIỀU TRỊ
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildTreatmentTab() {
    final logs = dp.treatmentLogs.where((t) {
      if (_filterPondId.isNotEmpty && t.pondId != _filterPondId) return false;
      if (_filterBatchId.isNotEmpty && t.fishBatchId != _filterBatchId) return false;
      if (!_inDateRange(t.startDate)) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    final activeWithdrawal = logs.where((t) => t.isWithdrawalActive).length;
    return Column(children: [
      _buildHeader(
        'Điều trị & Thuốc',
        '$activeWithdrawal ao đang cách ly',
        Icons.medical_services_rounded,
        AppColors.info,
        () => _showTreatmentDialog(),
      ),
      if (activeWithdrawal > 0)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.error.withAlpha(20), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Icons.warning_rounded, color: AppColors.error, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text('$activeWithdrawal phác đồ đang trong thời gian cách ly thuốc — KHÔNG thu hoạch!',
                style: const TextStyle(fontSize: 13, color: AppColors.error, fontWeight: FontWeight.w600))),
          ]),
        ),
      const SizedBox(height: 6),
      Expanded(child: logs.isEmpty
          ? _emptyState(Icons.medical_services_outlined, 'Chưa có phác đồ điều trị')
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: logs.length,
              itemBuilder: (_, i) => _buildTreatmentCard(logs[i]),
            )),
    ]);
  }

  Widget _buildTreatmentCard(TreatmentLog t) {
    final pond = dp.ponds.where((p) => p.id == t.pondId).firstOrNull;
    final statusLabel = {'in_progress': 'Đang điều trị', 'completed': 'Hoàn tất', 'cancelled': 'Huỷ'}[t.status] ?? t.status;
    final statusColor = t.status == 'completed' ? AppColors.success : t.status == 'in_progress' ? AppColors.warning : AppColors.textHint;
    final methodLabel = {'bath': 'Tắm', 'feed_mix': 'Trộn thức ăn', 'splash': 'Tát', 'inject': 'Tiêm'}[t.method] ?? t.method;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.medical_services_rounded, color: statusColor, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(t.medicineName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
            _chip(statusLabel, statusColor),
          ]),
          const SizedBox(height: 6),
          Wrap(spacing: 12, runSpacing: 4, children: [
            _infoTag(Icons.pool, 'Ao ${pond?.code ?? '?'}'),
            _infoTag(Icons.category, methodLabel),
            _infoTag(Icons.science, '${t.dosage} ${t.dosageUnit}'),
            _infoTag(Icons.calendar_today, '${_dateFmt.format(t.startDate)} · ${t.durationDays} ngày'),
            if (t.cost > 0) _infoTag(Icons.attach_money, '${_currFmt.format(t.cost)}đ'),
          ]),
          if (t.isWithdrawalActive) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: AppColors.error.withAlpha(20), borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.block_rounded, color: AppColors.error, size: 16),
                const SizedBox(width: 6),
                Text('Cách ly ${t.withdrawalDays} ngày — Thu hoạch an toàn sau ${t.safeHarvestDate != null ? _dateFmt.format(t.safeHarvestDate!) : '?'}',
                    style: const TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600)),
              ]),
            ),
          ],
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton.icon(icon: const Icon(Icons.edit, size: 16), label: const Text('Sửa'), onPressed: () => _showTreatmentDialog(t)),
            TextButton.icon(icon: const Icon(Icons.delete_outline, size: 16), label: const Text('Xóa'),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                onPressed: () async { await dp.remove('treatmentlogs', t.id); _showSnack('Đã xóa'); }),
          ]),
        ]),
      ),
    );
  }

  Future<void> _showTreatmentDialog([TreatmentLog? existing]) async {
    final isEdit = existing != null && existing.id.isNotEmpty;
    final medC = TextEditingController(text: existing?.medicineName ?? '');
    final doseC = TextEditingController(text: existing != null ? existing.dosage.toString() : '');
    final durC = TextEditingController(text: existing != null ? existing.durationDays.toString() : '3');
    final wdC = TextEditingController(text: existing != null ? existing.withdrawalDays.toString() : '0');
    final costC = TextEditingController(text: existing != null && existing.cost > 0 ? existing.cost.toString() : '');
    final noteC = TextEditingController(text: existing?.note ?? '');
    String pondId = existing?.pondId ?? '';
    String batchId = existing?.fishBatchId ?? '';
    String diseaseLogId = existing?.diseaseLogId ?? '';
    String medType = existing?.medicineType ?? 'chemical';
    String doseUnit = existing?.dosageUnit ?? 'ml/m3';
    String method = existing?.method ?? 'bath';
    String status = existing?.status ?? 'in_progress';
    DateTime startDate = existing?.startDate ?? DateTime.now();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(isEdit ? 'Sửa phác đồ' : 'Thêm phác đồ điều trị'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Ngày bắt đầu
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(context: ctx, initialDate: startDate, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 30)));
                  if (d != null) {
                    final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(startDate));
                    setSt(() => startDate = DateTime(d.year, d.month, d.day, t?.hour ?? startDate.hour, t?.minute ?? startDate.minute));
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Ngày giờ bắt đầu điều trị', prefixIcon: Icon(Icons.calendar_today)),
                  child: Text(DateFormat('dd/MM/yyyy HH:mm').format(startDate)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(controller: medC, decoration: const InputDecoration(labelText: 'Tên thuốc / hóa chất *', prefixIcon: Icon(Icons.medical_services))),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: DropdownButtonFormField<String>(
                  value: medType,
                  decoration: const InputDecoration(labelText: 'Loại'),
                  items: const [
                    DropdownMenuItem(value: 'antibiotic', child: Text('Kháng sinh')),
                    DropdownMenuItem(value: 'chemical', child: Text('Hóa chất')),
                    DropdownMenuItem(value: 'probiotic', child: Text('Vi sinh')),
                    DropdownMenuItem(value: 'herbal', child: Text('Thảo dược')),
                    DropdownMenuItem(value: 'other', child: Text('Khác')),
                  ],
                  onChanged: (v) => setSt(() => medType = v ?? 'chemical'),
                )),
                const SizedBox(width: 8),
                Expanded(child: DropdownButtonFormField<String>(
                  value: method,
                  decoration: const InputDecoration(labelText: 'Cách dùng'),
                  items: const [
                    DropdownMenuItem(value: 'bath', child: Text('Tắm')),
                    DropdownMenuItem(value: 'feed_mix', child: Text('Trộn thức ăn')),
                    DropdownMenuItem(value: 'splash', child: Text('Tát')),
                    DropdownMenuItem(value: 'inject', child: Text('Tiêm')),
                  ],
                  onChanged: (v) => setSt(() => method = v ?? 'bath'),
                )),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: DropdownButtonFormField<String>(
                  value: pondId.isEmpty ? null : pondId,
                  decoration: const InputDecoration(labelText: 'Ao'),
                  items: dp.ponds.map((p) => DropdownMenuItem(value: p.id, child: Text(p.code))).toList(),
                  onChanged: (v) => setSt(() => pondId = v ?? ''),
                )),
                const SizedBox(width: 8),
                Expanded(child: DropdownButtonFormField<String>(
                  value: diseaseLogId.isEmpty ? null : diseaseLogId,
                  decoration: const InputDecoration(labelText: 'Bệnh liên quan'),
                  items: dp.diseaseLogs.where((d) => d.status != 'resolved').map((d) => DropdownMenuItem(value: d.id, child: Text(d.diseaseName))).toList(),
                  onChanged: (v) => setSt(() => diseaseLogId = v ?? ''),
                )),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(controller: doseC, decoration: const InputDecoration(labelText: 'Liều lượng'), keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                SizedBox(width: 120, child: DropdownButtonFormField<String>(
                  value: doseUnit,
                  decoration: const InputDecoration(labelText: 'Đơn vị'),
                  items: const [
                    DropdownMenuItem(value: 'ml/m3', child: Text('ml/m³')),
                    DropdownMenuItem(value: 'g/kg', child: Text('g/kg TĂ')),
                    DropdownMenuItem(value: 'ppm', child: Text('ppm')),
                    DropdownMenuItem(value: 'ml/kg', child: Text('ml/kg')),
                  ],
                  onChanged: (v) => setSt(() => doseUnit = v ?? 'ml/m3'),
                )),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(controller: durC, decoration: const InputDecoration(labelText: 'Số ngày điều trị'), keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: wdC, decoration: const InputDecoration(labelText: 'Ngày cách ly'), keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(controller: costC, decoration: const InputDecoration(labelText: 'Chi phí (VNĐ)'), keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'Trạng thái'),
                  items: const [
                    DropdownMenuItem(value: 'in_progress', child: Text('Đang điều trị')),
                    DropdownMenuItem(value: 'completed', child: Text('Hoàn tất')),
                    DropdownMenuItem(value: 'cancelled', child: Text('Huỷ bỏ')),
                  ],
                  onChanged: (v) => setSt(() => status = v ?? 'in_progress'),
                )),
              ]),
              const SizedBox(height: 10),
              TextField(controller: noteC, decoration: const InputDecoration(labelText: 'Ghi chú'), maxLines: 2),
            ])),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isEdit ? 'Cập nhật' : 'Thêm')),
          ],
        ),
      ),
    );
    if (ok == true && medC.text.isNotEmpty) {
      final dur = int.tryParse(durC.text) ?? 1;
      final wd = int.tryParse(wdC.text) ?? 0;
      final endDate = startDate.add(Duration(days: dur));
      final safeDate = endDate.add(Duration(days: wd));
      final data = {
        'medicineName': medC.text, 'medicineType': medType,
        'dosage': double.tryParse(doseC.text) ?? 0, 'dosageUnit': doseUnit,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'durationDays': dur, 'withdrawalDays': wd,
        'safeHarvestDate': wd > 0 ? safeDate.toIso8601String() : null,
        'method': method, 'status': status,
        'cost': double.tryParse(costC.text) ?? 0,
        'pondId': pondId, 'fishBatchId': batchId,
        'diseaseLogId': diseaseLogId, 'note': noteC.text,
      };
      if (isEdit) {
        await dp.update('treatmentlogs', existing.id, data);
      } else {
        await dp.create('treatmentlogs', data);
      }
      _showSnack(isEdit ? 'Đã cập nhật' : 'Đã thêm phác đồ');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 3: LỊCH CHO ĂN
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildFeedingScheduleTab() {
    final schedules = dp.feedingSchedules.where((s) {
      if (_filterPondId.isNotEmpty && s.pondId != _filterPondId) return false;
      if (_filterBatchId.isNotEmpty && s.fishBatchId != _filterBatchId) return false;
      if (!_inDateRange(s.createdAt)) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final active = schedules.where((s) => s.isActive).length;
    return Column(children: [
      _buildHeader('Lịch cho ăn', '$active lịch đang hoạt động', Icons.restaurant_rounded, AppColors.warning, () => _showFeedingScheduleDialog()),
      Expanded(child: schedules.isEmpty
          ? _emptyState(Icons.restaurant_outlined, 'Chưa có lịch cho ăn')
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: schedules.length,
              itemBuilder: (_, i) => _buildFeedingScheduleCard(schedules[i]),
            )),
    ]);
  }

  Widget _buildFeedingScheduleCard(FeedingSchedule s) {
    final pond = dp.ponds.where((p) => p.id == s.pondId).firstOrNull;
    final batch = dp.fishBatches.where((b) => b.id == s.fishBatchId).firstOrNull;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.restaurant_rounded, color: s.isActive ? AppColors.warning : AppColors.textHint, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(
              '${pond?.code ?? 'Ao ?'} · ${batch?.name ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            )),
            _chip(s.isActive ? 'Hoạt động' : 'Tắt', s.isActive ? AppColors.success : AppColors.textHint),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 4, children: [
            _infoTag(Icons.scale, '${s.dailyAmount} kg/ngày'),
            _infoTag(Icons.schedule, '${s.timesPerDay} lần/ngày'),
            _infoTag(Icons.percent, '${s.rationPercent}% trọng lượng'),
            if (s.productName.isNotEmpty) _infoTag(Icons.inventory_2, s.productName),
          ]),
          if (s.feedingTimes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 6, children: s.feedingTimes.map((t) => Chip(
              label: Text(t, style: const TextStyle(fontSize: 11)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            )).toList()),
          ],
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton.icon(icon: const Icon(Icons.edit, size: 16), label: const Text('Sửa'), onPressed: () => _showFeedingScheduleDialog(s)),
            TextButton.icon(icon: const Icon(Icons.delete_outline, size: 16), label: const Text('Xóa'),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                onPressed: () async { await dp.remove('feedingschedules', s.id); _showSnack('Đã xóa'); }),
          ]),
        ]),
      ),
    );
  }

  Future<void> _showFeedingScheduleDialog([FeedingSchedule? existing]) async {
    final isEdit = existing != null;
    final amountC = TextEditingController(text: existing != null ? existing.dailyAmount.toString() : '');
    final timesC = TextEditingController(text: existing != null ? existing.timesPerDay.toString() : '3');
    final ratioC = TextEditingController(text: existing != null ? existing.rationPercent.toString() : '3');
    final noteC = TextEditingController(text: existing?.note ?? '');
    String pondId = existing?.pondId ?? '';
    String batchId = existing?.fishBatchId ?? '';
    String productId = existing?.productId ?? '';
    bool active = existing?.isActive ?? true;
    List<String> times = List.from(existing?.feedingTimes ?? ['06:00', '11:00', '17:00']);
    DateTime selectedDate = existing?.createdAt ?? DateTime.now();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          // Auto-calculate suggested amount based on pond's actual fish
          double suggestedKg = 0;
          double pondBiomass = 0;
          int pondFishCount = 0;
          if (pondId.isNotEmpty) {
            final batchesInPond = dp.fishBatches.where((b) => b.status == 'active' && b.pondIds.contains(pondId)).toList();
            for (final b in batchesInPond) {
              final qtyInPond = b.quantityInPond(pondId);
              final wt = b.currentWeight > 0 ? b.currentWeight : b.initialWeight;
              pondFishCount += qtyInPond;
              pondBiomass += qtyInPond * wt / 1000;
            }
            final ratio = double.tryParse(ratioC.text) ?? 3;
            suggestedKg = pondBiomass * ratio / 100;
          }

          return AlertDialog(
          title: Text(isEdit ? 'Sửa lịch cho ăn' : 'Thêm lịch cho ăn'),
          content: SizedBox(
            width: 450,
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
                  decoration: const InputDecoration(labelText: 'Ngày giờ bắt đầu', prefixIcon: Icon(Icons.calendar_today)),
                  child: Text(DateFormat('dd/MM/yyyy HH:mm').format(selectedDate)),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: pondId.isEmpty ? null : pondId,
                decoration: const InputDecoration(labelText: 'Ao *', prefixIcon: Icon(Icons.pool)),
                items: dp.ponds.where((p) => p.status == 'active').map((p) {
                  final fishCount = dp.fishBatches.where((b) => b.status == 'active' && b.pondIds.contains(p.id))
                      .fold<int>(0, (s, b) => s + b.quantityInPond(p.id));
                  return DropdownMenuItem(value: p.id, child: Text('${p.code} ($fishCount con)'));
                }).toList(),
                onChanged: (v) => setSt(() {
                  pondId = v ?? '';
                  // Auto-set batch if only one in this pond
                  if (pondId.isNotEmpty) {
                    final batchesInPond = dp.fishBatches.where((b) => b.status == 'active' && b.pondIds.contains(pondId)).toList();
                    if (batchesInPond.length == 1) batchId = batchesInPond.first.id;
                    // Set ratio from species
                    if (batchesInPond.isNotEmpty) {
                      final sp = dp.speciesById(batchesInPond.first.speciesId);
                      if (sp != null) ratioC.text = sp.feedRatio.toString();
                    }
                  }
                }),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: batchId.isEmpty ? null : batchId,
                decoration: const InputDecoration(labelText: 'Lô cá', prefixIcon: Icon(Icons.set_meal)),
                items: dp.fishBatches.where((b) => b.status == 'active').map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                onChanged: (v) => setSt(() => batchId = v ?? ''),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: productId.isEmpty ? null : productId,
                decoration: const InputDecoration(labelText: 'Thức ăn', prefixIcon: Icon(Icons.inventory_2)),
                items: dp.products.where((p) => p.category == 'feed' && p.isActive).map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                onChanged: (v) => setSt(() => productId = v ?? ''),
              ),
              const SizedBox(height: 10),
              // Per-pond fish info + feed ratio slider
              if (pondId.isNotEmpty && pondFishCount > 0) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withAlpha(15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning.withAlpha(40)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.set_meal, size: 14, color: AppColors.warning),
                      const SizedBox(width: 6),
                      Text('$pondFishCount con • Sinh khối: ${pondBiomass.toStringAsFixed(1)} kg',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.tune, size: 14, color: AppColors.warning),
                      const SizedBox(width: 6),
                      Text('Hệ số: ${(double.tryParse(ratioC.text) ?? 3).toStringAsFixed(1)}% thân',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('→ ${suggestedKg.toStringAsFixed(1)} kg/ngày',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.warning)),
                    ]),
                    Slider(
                      value: (double.tryParse(ratioC.text) ?? 3).clamp(0.5, 10.0),
                      min: 0.5, max: 10.0, divisions: 19,
                      label: '${(double.tryParse(ratioC.text) ?? 3).toStringAsFixed(1)}%',
                      activeColor: AppColors.warning,
                      onChanged: (v) => setSt(() {
                        ratioC.text = v.toStringAsFixed(1);
                        amountC.text = (pondBiomass * v / 100).toStringAsFixed(1);
                      }),
                    ),
                    InkWell(
                      onTap: () => setSt(() {
                        amountC.text = suggestedKg.toStringAsFixed(1);
                      }),
                      child: Row(children: [
                        const Icon(Icons.lightbulb_outline, size: 14, color: AppColors.warning),
                        const SizedBox(width: 6),
                        Text('Áp dụng đề xuất ${suggestedKg.toStringAsFixed(1)} kg',
                          style: const TextStyle(fontSize: 11, color: AppColors.warning, decoration: TextDecoration.underline)),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
              ],
              Row(children: [
                Expanded(child: TextField(controller: amountC, decoration: const InputDecoration(labelText: 'Lượng (kg/ngày)'), keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: ratioC, decoration: const InputDecoration(labelText: '% trọng lượng'), keyboardType: TextInputType.number,
                  onChanged: (_) => setSt(() {}))),
              ]),
              const SizedBox(height: 10),
              TextField(controller: timesC, decoration: const InputDecoration(labelText: 'Số lần/ngày'), keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerLeft, child: Text('Giờ cho ăn:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary))),
              Wrap(spacing: 6, children: [
                ...times.asMap().entries.map((e) => Chip(
                  label: Text(e.value),
                  onDeleted: () => setSt(() => times.removeAt(e.key)),
                )),
                ActionChip(label: const Text('+ Thêm giờ'), onPressed: () async {
                  final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.now());
                  if (t != null) setSt(() => times.add('${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'));
                }),
              ]),
              const SizedBox(height: 10),
              SwitchListTile(title: const Text('Hoạt động'), value: active, onChanged: (v) => setSt(() => active = v)),
              TextField(controller: noteC, decoration: const InputDecoration(labelText: 'Ghi chú'), maxLines: 2),
            ])),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isEdit ? 'Cập nhật' : 'Thêm')),
          ],
        );
        },
      ),
    );
    if (ok == true && pondId.isNotEmpty) {
      final product = dp.products.where((p) => p.id == productId).firstOrNull;
      final data = {
        'pondId': pondId, 'fishBatchId': batchId,
        'productId': productId, 'productName': product?.name ?? '',
        'dailyAmount': double.tryParse(amountC.text) ?? 0,
        'timesPerDay': int.tryParse(timesC.text) ?? 3,
        'feedingTimes': times,
        'rationPercent': double.tryParse(ratioC.text) ?? 3,
        'startDate': selectedDate.toIso8601String(),
        'isActive': active, 'note': noteC.text,
      };
      if (isEdit) {
        await dp.update('feedingschedules', existing.id, data);
      } else {
        await dp.create('feedingschedules', data);
      }
      _showSnack(isEdit ? 'Đã cập nhật' : 'Đã thêm lịch cho ăn');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 4: VỤ NUÔI
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildCropCycleTab() {
    final cycles = dp.cropCycles.where((c) {
      if (_filterPondId.isNotEmpty && !c.pondIds.contains(_filterPondId)) return false;
      if (_filterBatchId.isNotEmpty && !c.fishBatchIds.contains(_filterBatchId)) return false;
      if (!_inDateRange(c.startDate)) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    return Column(children: [
      _buildHeader('Vụ nuôi', '${cycles.where((c) => c.status == 'active').length} vụ đang nuôi', Icons.agriculture_rounded, AppColors.success, () => _showCropCycleDialog()),
      Expanded(child: cycles.isEmpty
          ? _emptyState(Icons.agriculture_outlined, 'Chưa có vụ nuôi')
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: cycles.length,
              itemBuilder: (_, i) => _buildCropCycleCard(cycles[i]),
            )),
    ]);
  }

  Widget _buildCropCycleCard(CropCycle c) {
    final species = dp.species.where((s) => s.id == c.speciesId).firstOrNull;
    final statusLabel = {'planning': 'Kế hoạch', 'active': 'Đang nuôi', 'completed': 'Hoàn thành'}[c.status] ?? c.status;
    final statusColor = c.status == 'active' ? AppColors.success : c.status == 'completed' ? AppColors.info : AppColors.warning;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.agriculture_rounded, color: statusColor, size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
            _chip(statusLabel, statusColor),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 4, children: [
            _infoTag(Icons.calendar_today, '${_dateFmt.format(c.startDate)}${c.endDate != null ? ' → ${_dateFmt.format(c.endDate!)}' : ''}'),
            if (species != null) _infoTag(Icons.pets, species.name),
            _infoTag(Icons.pool, '${c.pondIds.length} ao'),
            _infoTag(Icons.set_meal, '${c.fishBatchIds.length} lô'),
            _infoTag(Icons.timelapse, '${c.durationDays} ngày'),
          ]),
          if (c.plannedBudget > 0 || c.revenue > 0) ...[
            const SizedBox(height: 8),
            Row(children: [
              if (c.plannedBudget > 0) Expanded(child: _miniStat('Ngân sách', '${_currFmt.format(c.plannedBudget)}đ', AppColors.info)),
              if (c.actualCost > 0) Expanded(child: _miniStat('Chi phí', '${_currFmt.format(c.actualCost)}đ', AppColors.warning)),
              if (c.revenue > 0) Expanded(child: _miniStat('Doanh thu', '${_currFmt.format(c.revenue)}đ', AppColors.success)),
              Expanded(child: _miniStat('Lợi nhuận', '${_currFmt.format(c.profit)}đ', c.profit >= 0 ? AppColors.success : AppColors.error)),
            ]),
          ],
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton.icon(icon: const Icon(Icons.edit, size: 16), label: const Text('Sửa'), onPressed: () => _showCropCycleDialog(c)),
            TextButton.icon(icon: const Icon(Icons.delete_outline, size: 16), label: const Text('Xóa'),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                onPressed: () async { await dp.remove('cropcycles', c.id); _showSnack('Đã xóa'); }),
          ]),
        ]),
      ),
    );
  }

  Future<void> _showCropCycleDialog([CropCycle? existing]) async {
    final isEdit = existing != null;
    final nameC = TextEditingController(text: existing?.name ?? '');
    final budgetC = TextEditingController(text: existing != null && existing.plannedBudget > 0 ? existing.plannedBudget.toString() : '');
    final noteC = TextEditingController(text: existing?.note ?? '');
    String branchId = existing?.branchId ?? (dp.branches.isNotEmpty ? dp.branches.first.id : '');
    String speciesId = existing?.speciesId ?? '';
    String status = existing?.status ?? 'planning';
    DateTime startDate = existing?.startDate ?? DateTime.now();
    DateTime? endDate = existing?.endDate;
    List<String> pondIds = List.from(existing?.pondIds ?? []);
    List<String> batchIds = List.from(existing?.fishBatchIds ?? []);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(isEdit ? 'Sửa vụ nuôi' : 'Tạo vụ nuôi'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Tên vụ *', prefixIcon: Icon(Icons.agriculture))),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: DropdownButtonFormField<String>(
                  value: branchId.isEmpty ? null : branchId,
                  decoration: const InputDecoration(labelText: 'Chi nhánh'),
                  items: dp.branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                  onChanged: (v) => setSt(() => branchId = v ?? ''),
                )),
                const SizedBox(width: 8),
                Expanded(child: DropdownButtonFormField<String>(
                  value: speciesId.isEmpty ? null : speciesId,
                  decoration: const InputDecoration(labelText: 'Loài nuôi'),
                  items: dp.species.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                  onChanged: (v) => setSt(() => speciesId = v ?? ''),
                )),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: InkWell(
                  onTap: () async {
                    final d = await showDatePicker(context: ctx, initialDate: startDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                    if (d != null) setSt(() => startDate = d);
                  },
                  child: InputDecorator(decoration: const InputDecoration(labelText: 'Bắt đầu'), child: Text(_dateFmt.format(startDate))),
                )),
                const SizedBox(width: 8),
                Expanded(child: InkWell(
                  onTap: () async {
                    final d = await showDatePicker(context: ctx, initialDate: endDate ?? startDate.add(const Duration(days: 180)), firstDate: DateTime(2020), lastDate: DateTime(2030));
                    if (d != null) setSt(() => endDate = d);
                  },
                  child: InputDecorator(decoration: const InputDecoration(labelText: 'Kết thúc (dự kiến)'), child: Text(endDate != null ? _dateFmt.format(endDate!) : 'Chưa đặt')),
                )),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'Trạng thái'),
                  items: const [
                    DropdownMenuItem(value: 'planning', child: Text('Kế hoạch')),
                    DropdownMenuItem(value: 'active', child: Text('Đang nuôi')),
                    DropdownMenuItem(value: 'completed', child: Text('Hoàn thành')),
                  ],
                  onChanged: (v) => setSt(() => status = v ?? 'planning'),
                )),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: budgetC, decoration: const InputDecoration(labelText: 'Ngân sách (VNĐ)'), keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerLeft, child: Text('Chọn ao (${pondIds.length}):', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
              Wrap(spacing: 6, runSpacing: 4, children: dp.ponds.map((p) => FilterChip(
                label: Text(p.code), selected: pondIds.contains(p.id),
                onSelected: (v) => setSt(() => v ? pondIds.add(p.id) : pondIds.remove(p.id)),
              )).toList()),
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerLeft, child: Text('Chọn lô cá (${batchIds.length}):', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
              Wrap(spacing: 6, runSpacing: 4, children: dp.fishBatches.where((b) => b.status == 'active').map((b) => FilterChip(
                label: Text(b.name), selected: batchIds.contains(b.id),
                onSelected: (v) => setSt(() => v ? batchIds.add(b.id) : batchIds.remove(b.id)),
              )).toList()),
              const SizedBox(height: 10),
              TextField(controller: noteC, decoration: const InputDecoration(labelText: 'Ghi chú'), maxLines: 2),
            ])),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isEdit ? 'Cập nhật' : 'Tạo')),
          ],
        ),
      ),
    );
    if (ok == true && nameC.text.isNotEmpty) {
      final data = {
        'name': nameC.text, 'branchId': branchId, 'speciesId': speciesId,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'status': status, 'pondIds': pondIds, 'fishBatchIds': batchIds,
        'plannedBudget': double.tryParse(budgetC.text) ?? 0,
        'note': noteC.text,
      };
      if (isEdit) {
        await dp.update('cropcycles', existing.id, data);
      } else {
        await dp.create('cropcycles', data);
      }
      _showSnack(isEdit ? 'Đã cập nhật' : 'Đã tạo vụ nuôi');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 5: THIẾT BỊ
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildEquipmentTab() {
    final items = dp.equipmentList.where((e) {
      if (_filterPondId.isNotEmpty && e.pondId != _filterPondId) return false;
      return true;
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final mainDue = items.where((e) => e.isMaintenanceDue).length;
    return Column(children: [
      _buildHeader('Thiết bị', mainDue > 0 ? '$mainDue cần bảo trì' : '${items.length} thiết bị', Icons.settings_rounded, AppColors.secondary, () => _showEquipmentDialog()),
      if (mainDue > 0)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.warning.withAlpha(20), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Icons.build_circle_rounded, color: AppColors.warning, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text('$mainDue thiết bị đã quá hạn bảo trì!',
                style: const TextStyle(fontSize: 13, color: AppColors.warning, fontWeight: FontWeight.w600))),
          ]),
        ),
      const SizedBox(height: 6),
      Expanded(child: items.isEmpty
          ? _emptyState(Icons.settings_outlined, 'Chưa có thiết bị')
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: items.length,
              itemBuilder: (_, i) => _buildEquipmentCard(items[i]),
            )),
    ]);
  }

  Widget _buildEquipmentCard(Equipment e) {
    final pond = dp.ponds.where((p) => p.id == e.pondId).firstOrNull;
    final typeLabel = {'aerator': 'Quạt nước', 'pump': 'Máy bơm', 'feeder': 'Máy cho ăn', 'generator': 'Máy phát điện', 'sensor': 'Cảm biến', 'other': 'Khác'}[e.type] ?? e.type;
    final statusColor = e.status == 'active' ? AppColors.success : e.status == 'maintenance' ? AppColors.warning : e.status == 'broken' ? AppColors.error : AppColors.textHint;
    final statusLabel = {'active': 'Hoạt động', 'maintenance': 'Bảo trì', 'broken': 'Hỏng', 'retired': 'Loại bỏ'}[e.status] ?? e.status;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              backgroundColor: statusColor.withAlpha(30), radius: 18,
              child: Icon(e.type == 'aerator' ? Icons.air : e.type == 'pump' ? Icons.water : e.type == 'feeder' ? Icons.restaurant : Icons.settings, color: statusColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Text('$typeLabel${e.brand.isNotEmpty ? ' · ${e.brand}' : ''}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ])),
            _chip(statusLabel, statusColor),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 4, children: [
            if (pond != null) _infoTag(Icons.pool, 'Ao ${pond.code}'),
            if (e.powerConsumption > 0) _infoTag(Icons.bolt, '${e.powerConsumption} kW'),
            if (e.purchaseCost > 0) _infoTag(Icons.attach_money, '${_currFmt.format(e.purchaseCost)}đ'),
            if (e.nextMaintenanceDate != null) _infoTag(
              Icons.build,
              'BT: ${_dateFmt.format(e.nextMaintenanceDate!)}',
            ),
          ]),
          if (e.isMaintenanceDue) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.warning.withAlpha(20), borderRadius: BorderRadius.circular(6)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.warning_rounded, color: AppColors.warning, size: 14),
                SizedBox(width: 4),
                Text('Quá hạn bảo trì!', style: TextStyle(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w600)),
              ]),
            ),
          ],
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton.icon(icon: const Icon(Icons.edit, size: 16), label: const Text('Sửa'), onPressed: () => _showEquipmentDialog(e)),
            TextButton.icon(icon: const Icon(Icons.delete_outline, size: 16), label: const Text('Xóa'),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                onPressed: () async { await dp.remove('equipment', e.id); _showSnack('Đã xóa'); }),
          ]),
        ]),
      ),
    );
  }

  Future<void> _showEquipmentDialog([Equipment? existing]) async {
    final isEdit = existing != null;
    final nameC = TextEditingController(text: existing?.name ?? '');
    final brandC = TextEditingController(text: existing?.brand ?? '');
    final serialC = TextEditingController(text: existing?.serialNumber ?? '');
    final costC = TextEditingController(text: existing != null && existing.purchaseCost > 0 ? existing.purchaseCost.toString() : '');
    final powerC = TextEditingController(text: existing != null && existing.powerConsumption > 0 ? existing.powerConsumption.toString() : '');
    final intervalC = TextEditingController(text: existing != null ? existing.maintenanceIntervalDays.toString() : '90');
    final noteC = TextEditingController(text: existing?.note ?? '');
    String type = existing?.type ?? 'aerator';
    String status = existing?.status ?? 'active';
    String pondId = existing?.pondId ?? '';
    String branchId = existing?.branchId ?? (dp.branches.isNotEmpty ? dp.branches.first.id : '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(isEdit ? 'Sửa thiết bị' : 'Thêm thiết bị'),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Tên thiết bị *', prefixIcon: Icon(Icons.settings))),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Loại'),
                  items: const [
                    DropdownMenuItem(value: 'aerator', child: Text('Quạt nước')),
                    DropdownMenuItem(value: 'pump', child: Text('Máy bơm')),
                    DropdownMenuItem(value: 'feeder', child: Text('Máy cho ăn')),
                    DropdownMenuItem(value: 'generator', child: Text('Máy phát điện')),
                    DropdownMenuItem(value: 'sensor', child: Text('Cảm biến')),
                    DropdownMenuItem(value: 'other', child: Text('Khác')),
                  ],
                  onChanged: (v) => setSt(() => type = v ?? 'aerator'),
                )),
                const SizedBox(width: 8),
                Expanded(child: DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'Trạng thái'),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Hoạt động')),
                    DropdownMenuItem(value: 'maintenance', child: Text('Đang bảo trì')),
                    DropdownMenuItem(value: 'broken', child: Text('Hỏng')),
                    DropdownMenuItem(value: 'retired', child: Text('Loại bỏ')),
                  ],
                  onChanged: (v) => setSt(() => status = v ?? 'active'),
                )),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(controller: brandC, decoration: const InputDecoration(labelText: 'Hãng'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: serialC, decoration: const InputDecoration(labelText: 'Số serial'))),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: DropdownButtonFormField<String>(
                  value: pondId.isEmpty ? null : pondId,
                  decoration: const InputDecoration(labelText: 'Ao'),
                  items: dp.ponds.map((p) => DropdownMenuItem(value: p.id, child: Text(p.code))).toList(),
                  onChanged: (v) => setSt(() => pondId = v ?? ''),
                )),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: powerC, decoration: const InputDecoration(labelText: 'Công suất (kW)'), keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(controller: costC, decoration: const InputDecoration(labelText: 'Giá mua (VNĐ)'), keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: intervalC, decoration: const InputDecoration(labelText: 'Chu kỳ BT (ngày)'), keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 10),
              TextField(controller: noteC, decoration: const InputDecoration(labelText: 'Ghi chú'), maxLines: 2),
            ])),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isEdit ? 'Cập nhật' : 'Thêm')),
          ],
        ),
      ),
    );
    if (ok == true && nameC.text.isNotEmpty) {
      final interval = int.tryParse(intervalC.text) ?? 90;
      final data = {
        'name': nameC.text, 'type': type, 'brand': brandC.text,
        'serialNumber': serialC.text, 'pondId': pondId, 'branchId': branchId,
        'status': status,
        'purchaseCost': double.tryParse(costC.text) ?? 0,
        'powerConsumption': double.tryParse(powerC.text) ?? 0,
        'maintenanceIntervalDays': interval,
        'nextMaintenanceDate': DateTime.now().add(Duration(days: interval)).toIso8601String(),
        'note': noteC.text,
      };
      if (isEdit) {
        await dp.update('equipment', existing.id, data);
      } else {
        await dp.create('equipment', data);
      }
      _showSnack(isEdit ? 'Đã cập nhật' : 'Đã thêm thiết bị');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 6: NHẬT KÝ TỔNG HỢP (TIMELINE)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Collects ALL events for a pond (or all ponds) into a unified timeline.
  List<_TimelineEvent> _buildTimelineEvents({String? pondId}) {
    final events = <_TimelineEvent>[];
    final pid = pondId ?? _filterPondId;
    bool matchPond(String id) => pid.isEmpty || id == pid;
    bool matchBatch(String id) => _filterBatchId.isEmpty || id == _filterBatchId;

    // 1. Thả cá (Fish stocking)
    for (final b in dp.fishBatches) {
      if (!matchBatch(b.id)) continue;
      if (pid.isNotEmpty && b.pondId != pid) continue;
      if (!_inDateRange(b.createdAt)) continue;
      final pond = dp.ponds.where((p) => p.id == b.pondId).firstOrNull;
      final sp = dp.species.where((s) => s.id == b.speciesId).firstOrNull;
      events.add(_TimelineEvent(
        date: b.createdAt,
        type: 'stocking',
        icon: Icons.set_meal_rounded,
        color: AppColors.primary,
        title: 'Thả cá: ${b.name}',
        subtitle: '${sp?.name ?? ''} · ${_currFmt.format(b.initialQuantity)} con · ${b.initialWeight}g/con',
        extra: pond != null ? 'Ao ${pond.code}' : '',
        pondId: b.pondId,
        entityId: b.id,
      ));
    }

    // 2. Đo nước (Water measurement - from pond updatedAt when has water params)
    for (final p in dp.ponds) {
      if (!matchPond(p.id)) continue;
      if (p.updatedAt != null && (p.currentPh != null || p.currentDo != null || p.currentTemp != null)) {
        if (!_inDateRange(p.updatedAt!)) continue;
        final params = <String>[];
        if (p.currentPh != null) params.add('pH: ${p.currentPh!.toStringAsFixed(1)}');
        if (p.currentDo != null) params.add('DO: ${p.currentDo!.toStringAsFixed(1)}');
        if (p.currentTemp != null) params.add('${p.currentTemp!.toStringAsFixed(1)}°C');
        if (p.currentNh3 != null) params.add('NH₃: ${p.currentNh3!.toStringAsFixed(2)}');
        events.add(_TimelineEvent(
          date: p.updatedAt!,
          type: 'water_measure',
          icon: Icons.science_rounded,
          color: const Color(0xFF7C4DFF),
          title: 'Đo nước',
          subtitle: params.join(' · '),
          extra: 'Ao ${p.code}',
          pondId: p.id,
          entityId: p.id,
        ));
      }
    }

    // 3. Cho cá ăn (Feeding logs)
    for (final log in dp.feedingLogs) {
      final logPond = log['pondId'] as String? ?? '';
      if (!matchPond(logPond)) continue;
      final date = DateTime.tryParse(log['date'] as String? ?? '');
      if (date == null || !_inDateRange(date)) continue;
      final qty = (log['quantity'] as num?)?.toDouble() ?? 0;
      final unit = log['unit'] as String? ?? 'kg';
      final pName = log['productName'] as String? ?? '';
      final pond = dp.ponds.where((p) => p.id == logPond).firstOrNull;
      events.add(_TimelineEvent(
        date: date,
        type: 'feeding',
        icon: Icons.restaurant_rounded,
        color: AppColors.success,
        title: 'Cho ăn: ${pName.isNotEmpty ? pName : 'Thức ăn'}',
        subtitle: '${qty.toStringAsFixed(1)} $unit',
        extra: pond != null ? 'Ao ${pond.code}' : '',
        pondId: logPond,
        entityId: log['_id'] as String? ?? '',
      ));
    }

    // 4. Dịch bệnh (Disease logs)
    for (final d in dp.diseaseLogs) {
      if (!matchPond(d.pondId)) continue;
      if (_filterBatchId.isNotEmpty && d.fishBatchId != _filterBatchId) continue;
      if (!_inDateRange(d.detectedDate)) continue;
      final pond = dp.ponds.where((p) => p.id == d.pondId).firstOrNull;
      final statusLabel = {'detected': 'Phát hiện', 'treating': 'Đang trị', 'resolved': 'Đã khỏi', 'recurring': 'Tái phát'}[d.status] ?? d.status;
      events.add(_TimelineEvent(
        date: d.detectedDate,
        type: 'disease',
        icon: Icons.coronavirus_rounded,
        color: AppColors.error,
        title: 'Bệnh: ${d.diseaseName}',
        subtitle: '$statusLabel${d.affectedQuantity > 0 ? ' · ${d.affectedQuantity} con' : ''}${d.symptoms.isNotEmpty ? '\n${d.symptoms}' : ''}',
        extra: pond != null ? 'Ao ${pond.code}' : '',
        pondId: d.pondId,
        entityId: d.id,
      ));
    }

    // 5. Thay nước (Water change logs)
    for (final w in dp.waterChangeLogs) {
      if (!matchPond(w.pondId)) continue;
      if (!_inDateRange(w.date)) continue;
      final pond = dp.ponds.where((p) => p.id == w.pondId).firstOrNull;
      final reasonLabel = {'routine': 'Định kỳ', 'emergency': 'Khẩn cấp', 'treatment': 'Xử lý', 'pre_stocking': 'Trước thả giống'}[w.reason] ?? w.reason;
      events.add(_TimelineEvent(
        date: w.date,
        type: 'water_change',
        icon: Icons.water_drop_rounded,
        color: AppColors.info,
        title: 'Thay nước ${w.percentChanged.toStringAsFixed(0)}%',
        subtitle: '$reasonLabel${w.volumeChanged > 0 ? ' · ${w.volumeChanged.toStringAsFixed(1)} m³' : ''}',
        extra: pond != null ? 'Ao ${pond.code}' : '',
        pondId: w.pondId,
        entityId: w.id,
      ));
    }

    // 6. Điều trị (Treatment logs)
    for (final t in dp.treatmentLogs) {
      if (!matchPond(t.pondId)) continue;
      if (!_inDateRange(t.startDate)) continue;
      final pond = dp.ponds.where((p) => p.id == t.pondId).firstOrNull;
      final statusLabel = {'in_progress': 'Đang trị', 'completed': 'Hoàn tất', 'cancelled': 'Huỷ'}[t.status] ?? t.status;
      final methodLabel = {'bath': 'Tắm', 'feed_mix': 'Trộn TĂ', 'splash': 'Tát', 'inject': 'Tiêm'}[t.method] ?? t.method;
      events.add(_TimelineEvent(
        date: t.startDate,
        type: 'treatment',
        icon: Icons.medical_services_rounded,
        color: const Color(0xFF5C6BC0),
        title: 'Điều trị: ${t.medicineName}',
        subtitle: '$statusLabel · $methodLabel · ${t.dosage} ${t.dosageUnit} · ${t.durationDays} ngày${t.isWithdrawalActive ? '\n⚠ Cách ly đến ${t.safeHarvestDate != null ? _dateFmt.format(t.safeHarvestDate!) : '?'}' : ''}',
        extra: pond != null ? 'Ao ${pond.code}' : '',
        pondId: t.pondId,
        entityId: t.id,
      ));
    }

    // 7. Chuyển cá / Nhập cá (Transfers - from farm_map feeding/mortality logs)
    for (final log in dp.maintenanceLogs) {
      final logPond = log['pondId'] as String? ?? '';
      if (!matchPond(logPond)) continue;
      final date = DateTime.tryParse(log['startedAt'] as String? ?? log['createdAt'] as String? ?? '');
      if (date == null || !_inDateRange(date)) continue;
      final pond = dp.ponds.where((p) => p.id == logPond).firstOrNull;
      final status = log['status'] as String? ?? '';
      final statusLabel = {'in_progress': 'Đang làm', 'completed': 'Hoàn tất', 'cancelled': 'Huỷ'}[status] ?? status;
      events.add(_TimelineEvent(
        date: date,
        type: 'maintenance',
        icon: Icons.build_rounded,
        color: AppColors.warning,
        title: 'Bảo trì ao',
        subtitle: statusLabel,
        extra: pond != null ? 'Ao ${pond.code}' : '',
        pondId: logPond,
        entityId: log['_id'] as String? ?? '',
      ));
    }

    // 8. Hao hụt (Mortality logs)
    for (final log in dp.mortalityLogs) {
      final logPond = log['pondId'] as String? ?? '';
      if (!matchPond(logPond)) continue;
      final date = DateTime.tryParse(log['date'] as String? ?? '');
      if (date == null || !_inDateRange(date)) continue;
      final qty = (log['quantity'] as num?)?.toInt() ?? 0;
      final cause = log['cause'] as String? ?? '';
      final pond = dp.ponds.where((p) => p.id == logPond).firstOrNull;
      events.add(_TimelineEvent(
        date: date,
        type: 'mortality',
        icon: Icons.heart_broken_rounded,
        color: AppColors.error,
        title: 'Hao hụt: $qty con',
        subtitle: cause.isNotEmpty ? cause : 'Không rõ nguyên nhân',
        extra: pond != null ? 'Ao ${pond.code}' : '',
        pondId: logPond,
        entityId: log['_id'] as String? ?? '',
      ));
    }

    // 9. Xuất bán (Sale orders with batch in pond)
    for (final so in dp.saleOrders) {
      if (!_inDateRange(so.createdAt)) continue;
      // Check if any item refers to a batch in the filtered pond
      bool relevant = pid.isEmpty;
      if (!relevant) {
        for (final b in dp.fishBatches) {
          if (b.pondId == pid && so.items.any((it) => it['fishBatchId'] == b.id)) {
            relevant = true;
            break;
          }
        }
      }
      if (!relevant) continue;
      final customer = dp.customers.where((c) => c.id == so.customerId).firstOrNull;
      events.add(_TimelineEvent(
        date: so.createdAt,
        type: 'sale',
        icon: Icons.shopping_bag_rounded,
        color: AppColors.secondary,
        title: 'Xuất bán',
        subtitle: '${customer?.name ?? 'Khách lẻ'} · ${_currFmt.format(so.totalAmount)}đ',
        extra: '',
        pondId: pid,
        entityId: so.id,
      ));
    }

    // 10. Nhật ký hàng ngày (Daily logs)
    for (final d in dp.dailyLogs) {
      if (!matchPond(d.pondId)) continue;
      if (!_inDateRange(d.date)) continue;
      final pond = dp.ponds.where((p) => p.id == d.pondId).firstOrNull;
      final weatherLbl = {'sunny': '☀️', 'cloudy': '☁️', 'rainy': '🌧️', 'stormy': '⛈️'}[d.weather] ?? '';
      final shiftLabel = {'morning': 'Sáng', 'afternoon': 'Chiều', 'night': 'Tối'}[d.shift] ?? d.shift;
      final parts = <String>[shiftLabel, weatherLbl];
      if (d.activities.isNotEmpty) parts.add(d.activities);
      if (d.incidentNote.isNotEmpty) parts.add('⚠ ${d.incidentNote}');
      events.add(_TimelineEvent(
        date: d.date,
        type: 'daily_log',
        icon: Icons.edit_note_rounded,
        color: const Color(0xFF6D4C41),
        title: 'Nhật ký',
        subtitle: parts.join(' · '),
        extra: pond != null ? 'Ao ${pond.code}' : '',
        pondId: d.pondId,
        entityId: d.id,
      ));
    }

    // Sort by date descending
    events.sort((a, b) => b.date.compareTo(a.date));
    return events;
  }

  Widget _buildDailyLogTab() {
    final events = _buildTimelineEvents();
    return Column(children: [
      _buildHeader('Nhật ký tổng hợp', '${events.length} sự kiện', Icons.timeline_rounded, AppColors.primary, () => _showDailyLogDialog()),
      Expanded(child: events.isEmpty
          ? _emptyState(Icons.timeline_outlined, 'Chưa có sự kiện nào')
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: events.length,
              itemBuilder: (_, i) => _buildTimelineCard(events[i], i, events.length),
            )),
    ]);
  }

  Widget _buildTimelineCard(_TimelineEvent e, int index, int total) {
    final timeFmt = DateFormat('HH:mm');
    final isFirst = index == 0;
    final isLast = index == total - 1;
    final canTap = e.entityId.isNotEmpty && const ['daily_log', 'disease', 'treatment', 'water_change'].contains(e.type);

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Timeline line + dot ──
        SizedBox(
          width: 32,
          child: Column(children: [
            if (!isFirst) Container(width: 2, height: 8, color: AppColors.border),
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: e.color.withAlpha(25),
                shape: BoxShape.circle,
                border: Border.all(color: e.color, width: 2),
              ),
              child: Icon(e.icon, size: 12, color: e.color),
            ),
            if (!isLast) Expanded(child: Container(width: 2, color: AppColors.border)),
          ]),
        ),
        const SizedBox(width: 8),
        // ── Card content ──
        Expanded(
          child: GestureDetector(
            onTap: canTap ? () => _onTimelineEventTap(e) : null,
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: e.color.withAlpha(8),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: e.color.withAlpha(30)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(e.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: e.color))),
                  if (canTap)
                    Icon(Icons.edit_rounded, size: 14, color: e.color.withAlpha(120)),
                  if (e.extra.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(4)),
                      child: Text(e.extra, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ]),
                if (e.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(e.subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 3, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(child: Text('${_dateFmt.format(e.date)} ${timeFmt.format(e.date)}', style: const TextStyle(fontSize: 10, color: AppColors.textHint))),
                  if (canTap)
                    Text('Nhấn để xem/sửa', style: TextStyle(fontSize: 9, color: e.color.withAlpha(100))),
                ]),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Tap handler for timeline events ──
  void _onTimelineEventTap(_TimelineEvent e) {
    switch (e.type) {
      case 'daily_log':
        final log = dp.dailyLogs.where((d) => d.id == e.entityId).firstOrNull;
        if (log != null) _showDailyLogDetailDialog(log);
        break;
      case 'disease':
        final d = dp.diseaseLogs.where((d) => d.id == e.entityId).firstOrNull;
        if (d != null) _showDiseaseDetailDialog(d);
        break;
      case 'treatment':
        final t = dp.treatmentLogs.where((t) => t.id == e.entityId).firstOrNull;
        if (t != null) _showTreatmentDetailDialog(t);
        break;
      case 'water_change':
        final w = dp.waterChangeLogs.where((w) => w.id == e.entityId).firstOrNull;
        if (w != null) _showWaterChangeDetailDialog(w);
        break;
    }
  }

  // ── Detail dialog for daily log (view + edit + delete) ──
  void _showDailyLogDetailDialog(DailyLog log) {
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
    final pond = dp.ponds.where((p) => p.id == log.pondId).firstOrNull;
    final shiftLabel = {'morning': 'Sáng', 'afternoon': 'Chiều', 'night': 'Tối'}[log.shift] ?? log.shift;
    final weatherLabel = {'sunny': '☀️ Nắng', 'cloudy': '☁️ Mây', 'rainy': '🌧️ Mưa', 'stormy': '⛈️ Bão'}[log.weather] ?? log.weather;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.edit_note_rounded, color: const Color(0xFF6D4C41), size: 22),
          const SizedBox(width: 8),
          const Expanded(child: Text('Chi tiết nhật ký', style: TextStyle(fontSize: 18))),
        ]),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            _detailRow('📅 Ngày', dateFmt.format(log.date)),
            _detailRow('🕐 Ca', shiftLabel),
            _detailRow('🌤 Thời tiết', weatherLabel),
            if (pond != null) _detailRow('🐟 Ao', pond.code),
            if (log.waterTemp != null) _detailRow('🌡 Nhiệt độ nước', '${log.waterTemp!.toStringAsFixed(1)}°C'),
            if (log.activities.isNotEmpty) _detailRow('📝 Hoạt động', log.activities),
            if (log.feedingNote.isNotEmpty) _detailRow('🍽 Cho ăn', log.feedingNote),
            if (log.healthNote.isNotEmpty) _detailRow('❤ Sức khoẻ', log.healthNote),
            if (log.incidentNote.isNotEmpty) _detailRow('⚠ Sự cố', log.incidentNote),
            if (log.note.isNotEmpty) _detailRow('💬 Ghi chú', log.note),
            if (log.loggedBy.isNotEmpty) ...[
              const Divider(),
              Text('Người ghi: ${log.loggedBy}', style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
            ],
          ])),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final confirmed = await showDialog<bool>(context: ctx, builder: (c) => AlertDialog(
                title: const Text('Xoá nhật ký?'),
                content: const Text('Bạn có chắc muốn xoá nhật ký này?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Huỷ')),
                  FilledButton(onPressed: () => Navigator.pop(c, true), style: FilledButton.styleFrom(backgroundColor: AppColors.error), child: const Text('Xoá')),
                ],
              ));
              if (confirmed == true) {
                await dp.remove('dailylogs', log.id);
                if (ctx.mounted) Navigator.pop(ctx);
                _showSnack('Đã xoá nhật ký');
              }
            },
            child: const Text('Xoá', style: TextStyle(color: AppColors.error)),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showDailyLogDialog(log);
            },
            child: const Text('Sửa'),
          ),
        ],
      ),
    );
  }

  // ── Detail dialog for disease log ──
  void _showDiseaseDetailDialog(DiseaseLog d) {
    final dateFmt = DateFormat('dd/MM/yyyy');
    final pond = dp.ponds.where((p) => p.id == d.pondId).firstOrNull;
    final batch = dp.fishBatches.where((b) => b.id == d.fishBatchId).firstOrNull;
    final statusLabel = {'detected': 'Phát hiện', 'treating': 'Đang trị', 'resolved': 'Đã khỏi', 'recurring': 'Tái phát'}[d.status] ?? d.status;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.coronavirus_rounded, color: AppColors.error, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Text('Bệnh: ${d.diseaseName}', style: const TextStyle(fontSize: 18))),
        ]),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            _detailRow('📅 Phát hiện', dateFmt.format(d.detectedDate)),
            _detailRow('📊 Trạng thái', statusLabel),
            if (pond != null) _detailRow('🐟 Ao', pond.code),
            if (batch != null) _detailRow('🐡 Lô', batch.name),
            if (d.affectedQuantity > 0) _detailRow('🔢 Số con ảnh hưởng', '${d.affectedQuantity}'),
            if (d.symptoms.isNotEmpty) _detailRow('🩺 Triệu chứng', d.symptoms),
            if (d.severity.isNotEmpty) _detailRow('⚡ Mức độ', {'mild': 'Nhẹ', 'moderate': 'Trung bình', 'severe': 'Nặng'}[d.severity] ?? d.severity),
            if (d.note.isNotEmpty) _detailRow('💬 Ghi chú', d.note),
          ])),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final confirmed = await showDialog<bool>(context: ctx, builder: (c) => AlertDialog(
                title: const Text('Xoá ghi bệnh?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Huỷ')),
                  FilledButton(onPressed: () => Navigator.pop(c, true), style: FilledButton.styleFrom(backgroundColor: AppColors.error), child: const Text('Xoá')),
                ],
              ));
              if (confirmed == true) {
                await dp.remove('diseaselogs', d.id);
                if (ctx.mounted) Navigator.pop(ctx);
                _showSnack('Đã xoá');
              }
            },
            child: const Text('Xoá', style: TextStyle(color: AppColors.error)),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showDiseaseDialog(d);
            },
            child: const Text('Sửa'),
          ),
        ],
      ),
    );
  }

  // ── Detail dialog for treatment log ──
  void _showTreatmentDetailDialog(TreatmentLog t) {
    final dateFmt = DateFormat('dd/MM/yyyy');
    final pond = dp.ponds.where((p) => p.id == t.pondId).firstOrNull;
    final statusLabel = {'in_progress': 'Đang trị', 'completed': 'Hoàn tất', 'cancelled': 'Huỷ'}[t.status] ?? t.status;
    final methodLabel = {'bath': 'Tắm', 'feed_mix': 'Trộn TĂ', 'splash': 'Tát', 'inject': 'Tiêm'}[t.method] ?? t.method;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.medical_services_rounded, color: Color(0xFF5C6BC0), size: 22),
          const SizedBox(width: 8),
          Expanded(child: Text('Điều trị: ${t.medicineName}', style: const TextStyle(fontSize: 18))),
        ]),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            _detailRow('📅 Bắt đầu', dateFmt.format(t.startDate)),
            _detailRow('📊 Trạng thái', statusLabel),
            _detailRow('💊 Phương pháp', methodLabel),
            if (pond != null) _detailRow('🐟 Ao', pond.code),
            _detailRow('💉 Liều lượng', '${t.dosage} ${t.dosageUnit}'),
            _detailRow('⏱ Thời gian', '${t.durationDays} ngày'),
            if (t.isWithdrawalActive) _detailRow('⚠ Cách ly đến', t.safeHarvestDate != null ? dateFmt.format(t.safeHarvestDate!) : 'N/A'),
            if (t.note.isNotEmpty) _detailRow('💬 Ghi chú', t.note),
          ])),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final confirmed = await showDialog<bool>(context: ctx, builder: (c) => AlertDialog(
                title: const Text('Xoá điều trị?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Huỷ')),
                  FilledButton(onPressed: () => Navigator.pop(c, true), style: FilledButton.styleFrom(backgroundColor: AppColors.error), child: const Text('Xoá')),
                ],
              ));
              if (confirmed == true) {
                await dp.remove('treatmentlogs', t.id);
                if (ctx.mounted) Navigator.pop(ctx);
                _showSnack('Đã xoá');
              }
            },
            child: const Text('Xoá', style: TextStyle(color: AppColors.error)),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showTreatmentDialog(t);
            },
            child: const Text('Sửa'),
          ),
        ],
      ),
    );
  }

  // ── Detail dialog for water change log ──
  void _showWaterChangeDetailDialog(WaterChangeLog w) {
    final dateFmt = DateFormat('dd/MM/yyyy');
    final pond = dp.ponds.where((p) => p.id == w.pondId).firstOrNull;
    final reasonLabel = {'routine': 'Định kỳ', 'emergency': 'Khẩn cấp', 'treatment': 'Xử lý', 'pre_stocking': 'Trước thả giống'}[w.reason] ?? w.reason;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.water_drop_rounded, color: AppColors.info, size: 22),
          const SizedBox(width: 8),
          const Expanded(child: Text('Chi tiết thay nước', style: TextStyle(fontSize: 18))),
        ]),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            _detailRow('📅 Ngày', dateFmt.format(w.date)),
            _detailRow('💧 Tỷ lệ', '${w.percentChanged.toStringAsFixed(0)}%'),
            if (w.volumeChanged > 0) _detailRow('📐 Thể tích', '${w.volumeChanged.toStringAsFixed(1)} m³'),
            _detailRow('📌 Lý do', reasonLabel),
            if (pond != null) _detailRow('🐟 Ao', pond.code),
            if (w.incomingPh != null) _detailRow('pH vào', '${w.incomingPh}'),
            if (w.incomingTemp != null) _detailRow('🌡 Nhiệt độ vào', '${w.incomingTemp}°C'),
            if (w.note.isNotEmpty) _detailRow('💬 Ghi chú', w.note),
          ])),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final confirmed = await showDialog<bool>(context: ctx, builder: (c) => AlertDialog(
                title: const Text('Xoá phiếu thay nước?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Huỷ')),
                  FilledButton(onPressed: () => Navigator.pop(c, true), style: FilledButton.styleFrom(backgroundColor: AppColors.error), child: const Text('Xoá')),
                ],
              ));
              if (confirmed == true) {
                await dp.remove('waterchangelogs', w.id);
                if (ctx.mounted) Navigator.pop(ctx);
                _showSnack('Đã xoá');
              }
            },
            child: const Text('Xoá', style: TextStyle(color: AppColors.error)),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showWaterChangeDialog(w);
            },
            child: const Text('Sửa'),
          ),
        ],
      ),
    );
  }

  // ── Shared detail row helper ──
  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 140, child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
      ]),
    );
  }

  Widget _noteRow(IconData icon, String label, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text('$label: ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
      ]),
    );
  }

  Future<void> _showDailyLogDialog([DailyLog? existing]) async {
    final isEdit = existing != null;
    final actC = TextEditingController(text: existing?.activities ?? '');
    final feedC = TextEditingController(text: existing?.feedingNote ?? '');
    final healthC = TextEditingController(text: existing?.healthNote ?? '');
    final incidentC = TextEditingController(text: existing?.incidentNote ?? '');
    final noteC = TextEditingController(text: existing?.note ?? '');
    String pondId = existing?.pondId ?? '';
    String shift = existing?.shift ?? 'morning';
    String weather = existing?.weather ?? 'sunny';
    DateTime date = existing?.date ?? DateTime.now();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(isEdit ? 'Sửa nhật ký' : 'Ghi nhật ký'),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(child: InkWell(
                  onTap: () async {
                    final d = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2030));
                    if (d != null) setSt(() => date = d);
                  },
                  child: InputDecorator(decoration: const InputDecoration(labelText: 'Ngày'), child: Text(_dateFmt.format(date))),
                )),
                const SizedBox(width: 8),
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
              ]),
              const SizedBox(height: 10),
              Row(children: [
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
                const SizedBox(width: 8),
                Expanded(child: DropdownButtonFormField<String>(
                  value: pondId.isEmpty ? null : pondId,
                  decoration: const InputDecoration(labelText: 'Ao'),
                  items: dp.ponds.map((p) => DropdownMenuItem(value: p.id, child: Text(p.code))).toList(),
                  onChanged: (v) => setSt(() => pondId = v ?? ''),
                )),
              ]),
              const SizedBox(height: 10),
              TextField(controller: actC, decoration: const InputDecoration(labelText: 'Hoạt động chính'), maxLines: 2),
              const SizedBox(height: 10),
              TextField(controller: feedC, decoration: const InputDecoration(labelText: 'Ghi chú cho ăn')),
              const SizedBox(height: 10),
              TextField(controller: healthC, decoration: const InputDecoration(labelText: 'Ghi chú sức khỏe cá')),
              const SizedBox(height: 10),
              TextField(controller: incidentC, decoration: const InputDecoration(labelText: 'Sự cố (nếu có)')),
              const SizedBox(height: 10),
              TextField(controller: noteC, decoration: const InputDecoration(labelText: 'Ghi chú khác'), maxLines: 2),
            ])),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isEdit ? 'Cập nhật' : 'Ghi nhận')),
          ],
        ),
      ),
    );
    if (ok == true) {
      final data = {
        'date': date.toIso8601String(), 'shift': shift,
        'weather': weather, 'pondId': pondId,
        'activities': actC.text, 'feedingNote': feedC.text,
        'healthNote': healthC.text, 'incidentNote': incidentC.text,
        'note': noteC.text,
      };
      if (isEdit) {
        await dp.update('dailylogs', existing.id, data);
      } else {
        await dp.create('dailylogs', data);
      }
      _showSnack(isEdit ? 'Đã cập nhật' : 'Đã ghi nhật ký');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 7: THAY NƯỚC
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildWaterChangeTab() {
    final logs = dp.waterChangeLogs.where((w) {
      if (_filterPondId.isNotEmpty && w.pondId != _filterPondId) return false;
      if (!_inDateRange(w.date)) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return Column(children: [
      _buildHeader('Lịch sử thay nước', '${logs.length} lần thay', Icons.water_drop_rounded, AppColors.info, () => _showWaterChangeDialog()),
      Expanded(child: logs.isEmpty
          ? _emptyState(Icons.water_drop_outlined, 'Chưa ghi nhận thay nước')
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: logs.length,
              itemBuilder: (_, i) => _buildWaterChangeCard(logs[i]),
            )),
    ]);
  }

  Widget _buildWaterChangeCard(WaterChangeLog w) {
    final pond = dp.ponds.where((p) => p.id == w.pondId).firstOrNull;
    final reasonLabel = {'routine': 'Định kỳ', 'emergency': 'Khẩn cấp', 'treatment': 'Xử lý', 'pre_stocking': 'Trước thả giống'}[w.reason] ?? w.reason;
    final sourceLabel = {'well': 'Giếng', 'river': 'Sông', 'reservoir': 'Hồ chứa', 'treatment': 'Nước xử lý'}[w.waterSource] ?? w.waterSource;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.info.withAlpha(30),
          child: const Icon(Icons.water_drop_rounded, color: AppColors.info, size: 22),
        ),
        title: Text('Ao ${pond?.code ?? '?'} — ${w.percentChanged.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${_dateFmt.format(w.date)} · $reasonLabel · $sourceLabel', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          if (w.volumeChanged > 0) Text('${w.volumeChanged.toStringAsFixed(1)} m³', style: const TextStyle(fontSize: 12)),
          Wrap(spacing: 8, children: [
            if (w.incomingPh != null) Text('pH: ${w.incomingPh}', style: const TextStyle(fontSize: 11)),
            if (w.incomingTemp != null) Text('Temp: ${w.incomingTemp}°C', style: const TextStyle(fontSize: 11)),
            if (w.incomingDo != null) Text('DO: ${w.incomingDo}', style: const TextStyle(fontSize: 11)),
          ]),
        ]),
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'edit') _showWaterChangeDialog(w);
            if (v == 'delete') { await dp.remove('waterchangelogs', w.id); _showSnack('Đã xóa'); }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Sửa')),
            const PopupMenuItem(value: 'delete', child: Text('Xóa')),
          ],
        ),
      ),
    );
  }

  Future<void> _showWaterChangeDialog([WaterChangeLog? existing]) async {
    final isEdit = existing != null;
    final pctC = TextEditingController(text: existing != null ? existing.percentChanged.toString() : '30');
    final volC = TextEditingController(text: existing != null && existing.volumeChanged > 0 ? existing.volumeChanged.toString() : '');
    final phC = TextEditingController(text: existing?.incomingPh?.toString() ?? '');
    final tempC = TextEditingController(text: existing?.incomingTemp?.toString() ?? '');
    final doC = TextEditingController(text: existing?.incomingDo?.toString() ?? '');
    final noteC = TextEditingController(text: existing?.note ?? '');
    String pondId = existing?.pondId ?? '';
    String reason = existing?.reason ?? 'routine';
    String source = existing?.waterSource ?? 'well';
    DateTime date = existing?.date ?? DateTime.now();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(isEdit ? 'Sửa thay nước' : 'Ghi nhận thay nước'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Ngày ghi nhận
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime.now());
                  if (d != null) {
                    final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(date));
                    setSt(() => date = DateTime(d.year, d.month, d.day, t?.hour ?? date.hour, t?.minute ?? date.minute));
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Ngày giờ ghi nhận', prefixIcon: Icon(Icons.calendar_today)),
                  child: Text(DateFormat('dd/MM/yyyy HH:mm').format(date)),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: pondId.isEmpty ? null : pondId,
                decoration: const InputDecoration(labelText: 'Ao *', prefixIcon: Icon(Icons.pool)),
                items: dp.ponds.map((p) => DropdownMenuItem(value: p.id, child: Text(p.code))).toList(),
                onChanged: (v) => setSt(() => pondId = v ?? ''),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(controller: pctC, decoration: const InputDecoration(labelText: '% thay'), keyboardType: TextInputType.number)),
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
                    DropdownMenuItem(value: 'treatment', child: Text('Xử lý')),
                    DropdownMenuItem(value: 'pre_stocking', child: Text('Trước thả giống')),
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
                    DropdownMenuItem(value: 'treatment', child: Text('Nước xử lý')),
                  ],
                  onChanged: (v) => setSt(() => source = v ?? 'well'),
                )),
              ]),
              const SizedBox(height: 12),
              const Align(alignment: Alignment.centerLeft, child: Text('Thông số nước đầu vào:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: TextField(controller: phC, decoration: const InputDecoration(labelText: 'pH'), keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: tempC, decoration: const InputDecoration(labelText: 'Temp (°C)'), keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: doC, decoration: const InputDecoration(labelText: 'DO (mg/L)'), keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 10),
              TextField(controller: noteC, decoration: const InputDecoration(labelText: 'Ghi chú'), maxLines: 2),
            ])),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isEdit ? 'Cập nhật' : 'Ghi nhận')),
          ],
        ),
      ),
    );
    if (ok == true && pondId.isNotEmpty) {
      final data = {
        'pondId': pondId, 'date': date.toIso8601String(),
        'percentChanged': double.tryParse(pctC.text) ?? 30,
        'volumeChanged': double.tryParse(volC.text) ?? 0,
        'waterSource': source, 'reason': reason,
        'incomingPh': double.tryParse(phC.text),
        'incomingTemp': double.tryParse(tempC.text),
        'incomingDo': double.tryParse(doC.text),
        'note': noteC.text,
      };
      if (isEdit) {
        await dp.update('waterchangelogs', existing.id, data);
      } else {
        await dp.create('waterchangelogs', data);
      }
      _showSnack(isEdit ? 'Đã cập nhật' : 'Đã ghi nhận thay nước');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SHARED HELPERS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildHeader(String title, String subtitle, IconData icon, Color color, VoidCallback onAdd) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ])),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Thêm'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            textStyle: const TextStyle(fontSize: 13),
          ),
        ),
      ]),
    );
  }

  // TAB 8: ĐO KÍCH THƯỚC
  // ═════════════════════════════════════════════════════════════════════
  Widget _buildSizeMeasurementTab() {
    final dp = widget.dp;
    var items = dp.sizeMeasurements.toList();

    // Apply filters
    if (_filterPondId != null) {
      items = items.where((m) => m.pondId == _filterPondId).toList();
    }
    if (_filterBatchId != null) {
      items = items.where((m) => m.fishBatchId == _filterBatchId).toList();
    }
    if (_filterFrom != null || _filterTo != null) {
      items = items.where((m) => _inDateRange(m.date)).toList();
    }

    items.sort((a, b) => b.date.compareTo(a.date));
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');

    return Column(children: [
      _buildHeader(
        'Đo kích thước',
        '${items.length} lần đo',
        Icons.straighten_rounded,
        const Color(0xFF6366F1),
        () => _showAddMeasurementDialog(dp),
      ),
      Expanded(child: items.isEmpty ? _emptyState(Icons.straighten_outlined, 'Chưa có dữ liệu đo kích thước') : ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final m = items[i];
          final batch = dp.fishBatches.where((b) => b.id == m.fishBatchId).firstOrNull;
          final batchName = batch?.name ?? '?';
          final pond = dp.ponds.where((p) => p.id == m.pondId).firstOrNull;
          final sp = batch != null ? dp.speciesById(batch.speciesId) : null;

          // Find previous measurement for growth comparison
          final prevMeasurements = dp.sizeMeasurements
              .where((pm) => pm.fishBatchId == m.fishBatchId && pm.date.isBefore(m.date))
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));
          final prev = prevMeasurements.isNotEmpty ? prevMeasurements.first : null;
          final weightDiff = prev != null && prev.avgWeight > 0 ? m.avgWeight - prev.avgWeight : null;
          final lengthDiff = prev != null && prev.avgLength > 0 && m.avgLength > 0 ? m.avgLength - prev.avgLength : null;
          final daysBetween = prev != null ? m.date.difference(prev.date).inDays : null;

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Header
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.straighten_rounded, size: 20, color: Color(0xFF6366F1)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(batchName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text('${sp?.name ?? ''} · ${pond?.code ?? ''} · ${dateFmt.format(m.date)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ])),
                  if (m.sampleCount > 0)
                    _chip('${m.sampleCount} mẫu', AppColors.info),
                ]),
                const SizedBox(height: 12),

                // Measurement values
                Row(children: [
                  Expanded(child: _measureCard('Trọng lượng', '${m.avgWeight.toStringAsFixed(0)}g', weightDiff != null ? '${weightDiff >= 0 ? "+" : ""}${weightDiff.toStringAsFixed(0)}g' : null, weightDiff)),
                  const SizedBox(width: 10),
                  if (m.avgLength > 0)
                    Expanded(child: _measureCard('Chiều dài', '${m.avgLength.toStringAsFixed(1)}cm', lengthDiff != null ? '${lengthDiff >= 0 ? "+" : ""}${lengthDiff.toStringAsFixed(1)}cm' : null, lengthDiff)),
                ]),

                // Growth rate
                if (weightDiff != null && daysBetween != null && daysBetween > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.success.withAlpha(12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      const Icon(Icons.trending_up_rounded, size: 14, color: AppColors.success),
                      const SizedBox(width: 6),
                      Text('Tăng trưởng: ${(weightDiff / daysBetween).toStringAsFixed(1)}g/ngày trong $daysBetween ngày',
                        style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ],

                // Remaining qty
                if (m.remainingQty > 0) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.inventory_2_outlined, size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text('Số lượng còn: ${m.remainingQty} con', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ]),
                ],

                // Measured by + note
                if (m.measuredBy.isNotEmpty || m.note.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    if (m.measuredBy.isNotEmpty) ...[
                      const Icon(Icons.person_outline, size: 13, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Text(m.measuredBy, style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                      const SizedBox(width: 12),
                    ],
                    if (m.note.isNotEmpty)
                      Expanded(child: Text(m.note, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis)),
                  ]),
                ],
              ]),
            ),
          );
        },
      )),
    ]);
  }

  Widget _measureCard(String label, String value, String? diff, double? diffVal) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withAlpha(10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF6366F1).withAlpha(30)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Row(children: [
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF6366F1))),
          if (diff != null) ...[
            const SizedBox(width: 6),
            Text(diff, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: (diffVal ?? 0) >= 0 ? AppColors.success : AppColors.error)),
          ],
        ]),
      ]),
    );
  }

  Future<void> _showAddMeasurementDialog(DataProvider dp) async {
    final ponds = dp.ponds.where((p) => p.status == 'active').toList();
    if (ponds.isEmpty) return;

    String? selPondId = ponds.first.id;
    String? selBatchId;
    final weightC = TextEditingController();
    final lengthC = TextEditingController();
    final sampleC = TextEditingController();
    final qtyC = TextEditingController();
    final noteC = TextEditingController();
    DateTime selDate = DateTime.now();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(builder: (dCtx, ss) {
        final batches = dp.fishBatches.where((b) => b.status == 'active' && b.pondId == selPondId).toList();
        if (selBatchId == null && batches.isNotEmpty) selBatchId = batches.first.id;
        final selBatch = batches.where((b) => b.id == selBatchId).firstOrNull;

        return AlertDialog(
          title: const Row(children: [
            Icon(Icons.straighten_rounded, color: Color(0xFF6366F1)),
            SizedBox(width: 8),
            Text('Đo kích thước cá'),
          ]),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Pond selector
                DropdownButtonFormField<String>(
                  value: selPondId,
                  decoration: const InputDecoration(labelText: 'Ao', prefixIcon: Icon(Icons.water)),
                  items: ponds.map((p) {
                    final cnt = dp.fishBatches.where((b) => b.status == 'active' && b.pondId == p.id).length;
                    return DropdownMenuItem(value: p.id, child: Text('${p.code} ($cnt lô)'));
                  }).toList(),
                  onChanged: (v) => ss(() { selPondId = v; selBatchId = null; }),
                ),
                const SizedBox(height: 12),
                // Batch selector
                if (batches.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: selBatchId,
                    decoration: const InputDecoration(labelText: 'Lô cá', prefixIcon: Icon(Icons.set_meal)),
                    items: batches.map((b) {
                      final sp = dp.speciesById(b.speciesId);
                      final wt = b.currentWeight > 0 ? b.currentWeight : b.initialWeight;
                      return DropdownMenuItem(value: b.id, child: Text('${b.name} – ${sp?.name ?? ''} (${wt.toStringAsFixed(0)}g)'));
                    }).toList(),
                    onChanged: (v) => ss(() => selBatchId = v),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.warning.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                    child: const Row(children: [
                      Icon(Icons.warning_amber, size: 16, color: AppColors.warning),
                      SizedBox(width: 8),
                      Text('Ao này chưa có lô cá hoạt động', style: TextStyle(fontSize: 12, color: AppColors.warning)),
                    ]),
                  ),
                const SizedBox(height: 12),
                // Date picker
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today, size: 20),
                  title: Text('Ngày đo: ${DateFormat('dd/MM/yyyy HH:mm').format(selDate)}'),
                  trailing: const Icon(Icons.edit_calendar),
                  onTap: () async {
                    final d = await showDatePicker(context: dCtx, initialDate: selDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                    if (d != null) {
                      final t = await showTimePicker(context: dCtx, initialTime: TimeOfDay.fromDateTime(selDate));
                      ss(() => selDate = DateTime(d.year, d.month, d.day, t?.hour ?? selDate.hour, t?.minute ?? selDate.minute));
                    }
                  },
                ),
                const SizedBox(height: 12),
                // Weight + Length
                Row(children: [
                  Expanded(child: TextField(controller: weightC, decoration: const InputDecoration(labelText: 'Trọng lượng TB (g)', prefixIcon: Icon(Icons.monitor_weight_rounded)), keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: lengthC, decoration: const InputDecoration(labelText: 'Chiều dài TB (cm)', prefixIcon: Icon(Icons.straighten)), keyboardType: TextInputType.number)),
                ]),
                const SizedBox(height: 12),
                // Sample count + remaining qty
                Row(children: [
                  Expanded(child: TextField(controller: sampleC, decoration: const InputDecoration(labelText: 'Số mẫu đo', prefixIcon: Icon(Icons.filter_list)), keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: qtyC, decoration: InputDecoration(labelText: 'Số cá còn lại', prefixIcon: const Icon(Icons.inventory_2_outlined), hintText: selBatch != null ? '${selBatch.currentQuantity}' : ''), keyboardType: TextInputType.number)),
                ]),
                const SizedBox(height: 12),
                TextField(controller: noteC, decoration: const InputDecoration(labelText: 'Ghi chú', prefixIcon: Icon(Icons.note)), maxLines: 2),

                // Current vs new comparison
                if (selBatch != null && weightC.text.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.info.withAlpha(12), borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      const Icon(Icons.compare_arrows, size: 16, color: AppColors.info),
                      const SizedBox(width: 8),
                      Text('Hiện tại: ${(selBatch.currentWeight > 0 ? selBatch.currentWeight : selBatch.initialWeight).toStringAsFixed(0)}g → Mới: ${weightC.text}g',
                        style: const TextStyle(fontSize: 12, color: AppColors.info, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ],
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Huỷ')),
            FilledButton.icon(
              onPressed: batches.isEmpty || weightC.text.isEmpty ? null : () => Navigator.pop(dCtx, true),
              icon: const Icon(Icons.save, size: 18),
              label: const Text('Lưu'),
            ),
          ],
        );
      }),
    );

    if (ok != true || selBatchId == null) return;
    await dp.create('sizemeasurements', {
      'fishBatchId': selBatchId,
      'pondId': selPondId,
      'storeId': dp.fishBatches.where((b) => b.id == selBatchId).firstOrNull?.branchId ?? '',
      'date': selDate.toIso8601String(),
      'avgWeight': double.tryParse(weightC.text) ?? 0,
      'avgLength': double.tryParse(lengthC.text) ?? 0,
      'sampleCount': int.tryParse(sampleC.text) ?? 0,
      'remainingQty': int.tryParse(qtyC.text) ?? 0,
      'measuredBy': '',
      'note': noteC.text.trim(),
    });
  }

  Widget _emptyState(IconData icon, String msg) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 56, color: AppColors.textHint),
      const SizedBox(height: 8),
      Text(msg, style: const TextStyle(color: AppColors.textHint, fontSize: 14)),
    ]));
  }

  Widget _chip(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _infoTag(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: AppColors.textSecondary),
      const SizedBox(width: 3),
      Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
    ]);
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(children: [
      Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color)),
      Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
    ]);
  }

  Widget _FilterDropdown({
    required IconData icon,
    required String label,
    required bool isActive,
    required List<PopupMenuEntry<String>> items,
    required ValueChanged<String> onSelected,
  }) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (_) => items,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withAlpha(15) : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? AppColors.primary.withAlpha(60) : AppColors.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: isActive ? AppColors.primary : AppColors.textHint),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(
            fontSize: 12,
            color: isActive ? AppColors.primary : AppColors.textSecondary,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          )),
          const SizedBox(width: 2),
          Icon(Icons.arrow_drop_down, size: 16, color: isActive ? AppColors.primary : AppColors.textHint),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TIMELINE EVENT MODEL
// ═══════════════════════════════════════════════════════════════════════════
class _TimelineEvent {
  final DateTime date;
  final String type;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String extra;
  final String pondId;
  final String entityId; // ID of the original entity (for edit/view)

  const _TimelineEvent({
    required this.date,
    required this.type,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.extra,
    required this.pondId,
    this.entityId = '',
  });
}
