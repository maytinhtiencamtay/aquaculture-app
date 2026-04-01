/// Phiếu kiểm kê kho
class StockTake {
  final String id;
  final String code;          // KK-001
  final DateTime date;
  final String branchId;
  final List<Map<String, dynamic>> items; // [{productId, productName, unit, systemQty, actualQty, diff, reason}]
  final String status;        // draft, approved, cancelled
  final String note;
  final String createdBy;     // employeeId - người tạo phiếu
  final String checkedBy;     // employeeId - người kiểm kê
  final String approvedBy;    // employeeId - người duyệt
  final DateTime createdAt;
  final DateTime? updatedAt;

  StockTake({
    required this.id,
    this.code = '',
    required this.date,
    this.branchId = '',
    this.items = const [],
    this.status = 'draft',
    this.note = '',
    this.createdBy = '',
    this.checkedBy = '',
    this.approvedBy = '',
    required this.createdAt,
    this.updatedAt,
  });

  factory StockTake.fromJson(Map<String, dynamic> json) => StockTake(
    id: json['_id'] as String? ?? json['id'] as String? ?? '',
    code: json['code'] as String? ?? '',
    date: json['date'] != null ? DateTime.parse(json['date'] as String) : DateTime.now(),
    branchId: json['branchId'] as String? ?? '',
    items: json['items'] != null ? List<Map<String, dynamic>>.from(json['items'] as List) : [],
    status: json['status'] as String? ?? 'draft',
    note: json['note'] as String? ?? '',
    createdBy: json['createdBy'] as String? ?? '',
    checkedBy: json['checkedBy'] as String? ?? '',
    approvedBy: json['approvedBy'] as String? ?? '',
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.now(),
    updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : null,
  );

  Map<String, dynamic> toJson() => {
    'code': code, 'date': date.toIso8601String(), 'branchId': branchId,
    'items': items, 'status': status, 'note': note,
    'createdBy': createdBy, 'checkedBy': checkedBy, 'approvedBy': approvedBy,
  };

  String get statusLabel {
    switch (status) {
      case 'draft': return 'Nháp';
      case 'approved': return 'Đã duyệt';
      case 'cancelled': return 'Đã huỷ';
      default: return status;
    }
  }

  int get totalDiff {
    int d = 0;
    for (final item in items) {
      d += ((item['actualQty'] as num?)?.toInt() ?? 0) - ((item['systemQty'] as num?)?.toInt() ?? 0);
    }
    return d;
  }
}
