class PaymentVoucher {
  final String id;
  final String code;         // PT-001 (thu) / PC-001 (chi)
  final String type;         // 'receipt' = phiếu thu, 'payment' = phiếu chi
  final String category;     // ban_hang, thu_no, thu_khac, mua_hang, tra_no, luong, dien_nuoc, thuc_an, thuoc, khac
  final double amount;
  final String contactName;  // Người nộp/nhận
  final String contactId;    // customerId / supplierId / employeeId (optional)
  final String contactType;  // 'customer' | 'supplier' | 'employee' | ''
  final String description;
  final DateTime date;
  final String paymentMethod; // 'cash' | 'transfer' | 'card'
  final String status;       // 'draft' | 'confirmed' | 'cancelled'
  final String referenceId;  // orderId, purchaseOrderId, etc.
  final String referenceType; // 'sale_order' | 'purchase_order' | ''
  final String note;
  final String createdBy;
  final String approvedBy;
  final DateTime createdAt;

  PaymentVoucher({
    required this.id,
    this.code = '',
    this.type = 'receipt',
    this.category = 'khac',
    this.amount = 0,
    this.contactName = '',
    this.contactId = '',
    this.contactType = '',
    this.description = '',
    required this.date,
    this.paymentMethod = 'cash',
    this.status = 'draft',
    this.referenceId = '',
    this.referenceType = '',
    this.note = '',
    this.createdBy = '',
    this.approvedBy = '',
    required this.createdAt,
  });

  factory PaymentVoucher.fromJson(Map<String, dynamic> json) => PaymentVoucher(
    id: json['_id'] as String? ?? json['id'] as String? ?? '',
    code: json['code'] as String? ?? '',
    type: json['type'] as String? ?? 'receipt',
    category: json['category'] as String? ?? 'khac',
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    contactName: json['contactName'] as String? ?? '',
    contactId: json['contactId'] as String? ?? '',
    contactType: json['contactType'] as String? ?? '',
    description: json['description'] as String? ?? '',
    date: json['date'] != null ? DateTime.parse(json['date'] as String) : DateTime.now(),
    paymentMethod: json['paymentMethod'] as String? ?? 'cash',
    status: json['status'] as String? ?? 'draft',
    referenceId: json['referenceId'] as String? ?? '',
    referenceType: json['referenceType'] as String? ?? '',
    note: json['note'] as String? ?? '',
    createdBy: json['createdBy'] as String? ?? '',
    approvedBy: json['approvedBy'] as String? ?? '',
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'code': code,
    'type': type,
    'category': category,
    'amount': amount,
    'contactName': contactName,
    'contactId': contactId,
    'contactType': contactType,
    'description': description,
    'date': date.toIso8601String(),
    'paymentMethod': paymentMethod,
    'status': status,
    'referenceId': referenceId,
    'referenceType': referenceType,
    'note': note,
    'createdBy': createdBy,
    'approvedBy': approvedBy,
  };

  bool get isReceipt => type == 'receipt';
  bool get isPayment => type == 'payment';

  String get typeLabel => isReceipt ? 'Phiếu thu' : 'Phiếu chi';

  String get categoryLabel {
    switch (category) {
      case 'ban_hang': return 'Bán hàng';
      case 'thu_no': return 'Thu công nợ';
      case 'thu_khac': return 'Thu khác';
      case 'mua_hang': return 'Mua hàng';
      case 'tra_no': return 'Trả công nợ';
      case 'luong': return 'Lương nhân viên';
      case 'dien_nuoc': return 'Điện nước';
      case 'thuc_an': return 'Thức ăn';
      case 'thuoc': return 'Thuốc & hóa chất';
      case 'van_chuyen': return 'Vận chuyển';
      case 'sua_chua': return 'Sửa chữa';
      case 'khac': return 'Khác';
      default: return category;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'draft': return 'Nháp';
      case 'confirmed': return 'Đã xác nhận';
      case 'cancelled': return 'Đã huỷ';
      default: return status;
    }
  }

  String get paymentMethodLabel {
    switch (paymentMethod) {
      case 'cash': return 'Tiền mặt';
      case 'transfer': return 'Chuyển khoản';
      case 'card': return 'Thẻ';
      default: return paymentMethod;
    }
  }

  static List<String> get receiptCategories => ['ban_hang', 'thu_no', 'thu_khac', 'khac'];
  static List<String> get paymentCategories => ['mua_hang', 'tra_no', 'luong', 'dien_nuoc', 'thuc_an', 'thuoc', 'van_chuyen', 'sua_chua', 'khac'];

  static String categoryLabelFor(String cat) {
    switch (cat) {
      case 'ban_hang': return 'Bán hàng';
      case 'thu_no': return 'Thu công nợ';
      case 'thu_khac': return 'Thu khác';
      case 'mua_hang': return 'Mua hàng';
      case 'tra_no': return 'Trả công nợ';
      case 'luong': return 'Lương nhân viên';
      case 'dien_nuoc': return 'Điện nước';
      case 'thuc_an': return 'Thức ăn';
      case 'thuoc': return 'Thuốc & hóa chất';
      case 'van_chuyen': return 'Vận chuyển';
      case 'sua_chua': return 'Sửa chữa';
      case 'khac': return 'Khác';
      default: return cat;
    }
  }
}
