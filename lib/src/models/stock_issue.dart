/// Phiếu xuất kho
class StockIssue {
  final String id;
  final String code;          // XK-001
  final DateTime date;
  final String type;          // sale (xuất bán), usage (sử dụng cho ao), disposal (huỷ), transfer, feeding (cho ăn)
  final String saleOrderId;   // Tham chiếu SO (nếu xuất bán)
  final String pondId;        // Ao liên quan (nếu xuất sử dụng / cho ăn)
  final String fishBatchId;   // Lô cá liên quan (nếu cho ăn)
  final String branchId;
  final List<Map<String, dynamic>> items; // [{productId, productName, qty, unitPrice, unit}]
  final double totalAmount;
  final String status;        // draft, approved, cancelled
  final String note;
  final String createdBy;     // employeeId - người tạo phiếu
  final String issuedTo;      // employeeId - xuất cho nhân viên nào
  final String approvedBy;    // employeeId - người duyệt
  final String confirmedBy;   // employeeId - nhân viên xác nhận đã cho ăn
  final DateTime? confirmedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  StockIssue({
    required this.id,
    this.code = '',
    required this.date,
    this.type = 'usage',
    this.saleOrderId = '',
    this.pondId = '',
    this.fishBatchId = '',
    this.branchId = '',
    this.items = const [],
    this.totalAmount = 0,
    this.status = 'draft',
    this.note = '',
    this.createdBy = '',
    this.issuedTo = '',
    this.approvedBy = '',
    this.confirmedBy = '',
    this.confirmedAt,
    required this.createdAt,
    this.updatedAt,
  });

  factory StockIssue.fromJson(Map<String, dynamic> json) => StockIssue(
    id: json['_id'] as String? ?? json['id'] as String? ?? '',
    code: json['code'] as String? ?? '',
    date: json['date'] != null ? DateTime.parse(json['date'] as String) : DateTime.now(),
    type: json['type'] as String? ?? 'usage',
    saleOrderId: json['saleOrderId'] as String? ?? '',
    pondId: json['pondId'] as String? ?? '',
    fishBatchId: json['fishBatchId'] as String? ?? '',
    branchId: json['branchId'] as String? ?? '',
    items: json['items'] != null ? List<Map<String, dynamic>>.from(json['items'] as List) : [],
    totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
    status: json['status'] as String? ?? 'draft',
    note: json['note'] as String? ?? '',
    createdBy: json['createdBy'] as String? ?? '',
    issuedTo: json['issuedTo'] as String? ?? '',
    approvedBy: json['approvedBy'] as String? ?? '',
    confirmedBy: json['confirmedBy'] as String? ?? '',
    confirmedAt: json['confirmedAt'] != null ? DateTime.parse(json['confirmedAt'] as String) : null,
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.now(),
    updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : null,
  );

  Map<String, dynamic> toJson() => {
    'code': code, 'date': date.toIso8601String(), 'type': type,
    'saleOrderId': saleOrderId, 'pondId': pondId, 'fishBatchId': fishBatchId,
    'branchId': branchId, 'items': items, 'totalAmount': totalAmount,
    'status': status, 'note': note, 'createdBy': createdBy, 'issuedTo': issuedTo, 'approvedBy': approvedBy,
    'confirmedBy': confirmedBy, if (confirmedAt != null) 'confirmedAt': confirmedAt!.toIso8601String(),
  };

  String get typeLabel {
    switch (type) {
      case 'sale': return 'Xuất bán';
      case 'usage': return 'Xuất sử dụng';
      case 'disposal': return 'Xuất huỷ';
      case 'transfer': return 'Xuất điều chuyển';
      case 'feeding': return 'Xuất cho ăn';
      case 'maintenance': return 'Xuất bảo trì';
      case 'treatment': return 'Xuất điều trị';
      default: return type;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'draft': return 'Nháp';
      case 'approved': return 'Đã duyệt';
      case 'confirmed': return 'Đã cho ăn';
      case 'cancelled': return 'Đã huỷ';
      default: return status;
    }
  }
}
