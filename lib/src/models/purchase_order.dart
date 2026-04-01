class PurchaseOrder {
  final String id;
  final String code;
  final DateTime date;
  final String supplierId;
  final String supplier;
  final String branchId;
  final List<Map<String, dynamic>> items; // [{productId, productName, qty, unitPrice, unit}]
  final double total;
  final String status; // draft, approved, partially_received, completed, cancelled
  final String note;
  final String createdBy;    // employeeId - người tạo phiếu
  final DateTime createdAt;
  final DateTime? updatedAt;

  PurchaseOrder({required this.id, this.code = '', required this.date, this.supplierId = '', this.supplier = '', this.branchId = '', this.items = const [], this.total = 0, this.status = 'draft', this.note = '', this.createdBy = '', required this.createdAt, this.updatedAt});

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) => PurchaseOrder(
    id: json['_id'] as String? ?? json['id'] as String? ?? '',
    code: json['code'] as String? ?? '',
    date: json['date'] != null ? DateTime.parse(json['date'] as String) : DateTime.now(),
    supplierId: json['supplierId'] as String? ?? '',
    supplier: json['supplier'] as String? ?? '',
    branchId: json['branchId'] as String? ?? '',
    items: json['items'] != null ? List<Map<String, dynamic>>.from(json['items'] as List) : [],
    total: (json['total'] as num?)?.toDouble() ?? 0,
    status: json['status'] as String? ?? 'draft',
    note: json['note'] as String? ?? '',
    createdBy: json['createdBy'] as String? ?? '',
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.now(),
    updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : null,
  );

  Map<String, dynamic> toJson() => {
    '_id': id, 'code': code, 'date': date.toIso8601String(), 'supplierId': supplierId,
    'supplier': supplier, 'branchId': branchId, 'items': items,
    'total': total, 'status': status, 'note': note, 'createdBy': createdBy,
  };

  String get statusLabel {
    switch (status) {
      case 'draft': return 'Nháp';
      case 'sent': return 'Đã gửi NCC';
      case 'waiting_receipt': return 'Chờ nhập kho';
      case 'approved': return 'Đã duyệt';
      case 'partially_received': return 'Nhận 1 phần';
      case 'completed': return 'Đã nhập kho';
      case 'cancelled': return 'Đã huỷ';
      default: return status;
    }
  }
}
