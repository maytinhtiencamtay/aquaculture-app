class SaleOrder {
  final String id;
  final String customerId;
  final DateTime date;
  final String pondId;
  final String fishBatchId;
  final List<Map<String, dynamic>> items;
  final double totalAmount;
  final String status;
  final DateTime createdAt;

  SaleOrder({required this.id, required this.customerId, required this.date, this.pondId = '', this.fishBatchId = '', this.items = const [], this.totalAmount = 0, this.status = 'pending', required this.createdAt});

  factory SaleOrder.fromJson(Map<String, dynamic> json) => SaleOrder(
    id: json['_id'] as String? ?? json['id'] as String? ?? '',
    customerId: json['customerId'] as String? ?? '',
    date: json['date'] != null ? DateTime.parse(json['date'] as String) : DateTime.now(),
    pondId: json['pondId'] as String? ?? '',
    fishBatchId: json['fishBatchId'] as String? ?? '',
    items: json['items'] != null ? List<Map<String, dynamic>>.from(json['items'] as List) : [],
    totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
    status: json['status'] as String? ?? 'pending',
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    '_id': id, 'customerId': customerId, 'date': date.toIso8601String(),
    'pondId': pondId, 'fishBatchId': fishBatchId,
    'items': items, 'totalAmount': totalAmount, 'status': status,
  };

  String get statusLabel {
    switch (status) {
      case 'pending': return 'Chờ xử lý';
      case 'completed': return 'Hoàn thành';
      case 'cancelled': return 'Đã huỷ';
      default: return status;
    }
  }
}
