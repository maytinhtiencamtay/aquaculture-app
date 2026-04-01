/// Phiếu nhập kho
class StockReceipt {
  final String id;
  final String code;          // NK-001
  final DateTime date;
  final String type;          // purchase (từ PO), transfer, other
  final String purchaseOrderId; // Tham chiếu PO (nếu nhập từ PO)
  final String supplierId;
  final String branchId;
  final List<Map<String, dynamic>> items; // [{productId, productName, qty, receivedQty, unitPrice, unit}]
  final double totalAmount;
  final String status;        // draft, approved, cancelled
  final String note;
  final String createdBy;     // employeeId - người tạo phiếu
  final String approvedBy;    // employeeId - người duyệt
  final DateTime createdAt;
  final DateTime? updatedAt;

  StockReceipt({
    required this.id,
    this.code = '',
    required this.date,
    this.type = 'purchase',
    this.purchaseOrderId = '',
    this.supplierId = '',
    this.branchId = '',
    this.items = const [],
    this.totalAmount = 0,
    this.status = 'draft',
    this.note = '',
    this.createdBy = '',
    this.approvedBy = '',
    required this.createdAt,
    this.updatedAt,
  });

  factory StockReceipt.fromJson(Map<String, dynamic> json) => StockReceipt(
    id: json['_id'] as String? ?? json['id'] as String? ?? '',
    code: json['code'] as String? ?? '',
    date: json['date'] != null ? DateTime.parse(json['date'] as String) : DateTime.now(),
    type: json['type'] as String? ?? 'purchase',
    purchaseOrderId: json['purchaseOrderId'] as String? ?? '',
    supplierId: json['supplierId'] as String? ?? '',
    branchId: json['branchId'] as String? ?? '',
    items: json['items'] != null ? List<Map<String, dynamic>>.from(json['items'] as List) : [],
    totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
    status: json['status'] as String? ?? 'draft',
    note: json['note'] as String? ?? '',
    createdBy: json['createdBy'] as String? ?? '',
    approvedBy: json['approvedBy'] as String? ?? '',
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.now(),
    updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : null,
  );

  Map<String, dynamic> toJson() => {
    '_id': id, 'code': code, 'date': date.toIso8601String(), 'type': type,
    'purchaseOrderId': purchaseOrderId, 'supplierId': supplierId,
    'branchId': branchId, 'items': items, 'totalAmount': totalAmount,
    'status': status, 'note': note, 'createdBy': createdBy, 'approvedBy': approvedBy,
  };

  String get typeLabel {
    switch (type) {
      case 'purchase': return 'Nhập từ PO';
      case 'transfer': return 'Nhập điều chuyển';
      case 'other': return 'Nhập khác';
      default: return type;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'draft': return 'Nháp';
      case 'approved': return 'Đã nhập kho';
      case 'cancelled': return 'Đã huỷ';
      default: return status;
    }
  }
}
