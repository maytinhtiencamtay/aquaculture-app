class Task {
  final String id;
  final String assignedTo;
  final String pondId;
  final String type;
  final String title;
  final DateTime dueDate;
  final String status;
  final String note;
  final DateTime createdAt;

  Task({required this.id, required this.assignedTo, this.pondId = '', this.type = 'other', required this.title, required this.dueDate, this.status = 'pending', this.note = '', required this.createdAt});

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: json['_id'] as String? ?? json['id'] as String? ?? '',
    assignedTo: json['assignedTo'] as String? ?? '',
    pondId: json['pondId'] as String? ?? '',
    type: json['type'] as String? ?? 'other',
    title: json['title'] as String? ?? '',
    dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate'] as String) : DateTime.now(),
    status: json['status'] as String? ?? 'pending',
    note: json['note'] as String? ?? '',
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    '_id': id, 'assignedTo': assignedTo, 'pondId': pondId, 'type': type,
    'title': title, 'dueDate': dueDate.toIso8601String(),
    'status': status, 'note': note,
  };

  bool get isOverdue => status == 'pending' && dueDate.isBefore(DateTime.now());

  String get typeLabel {
    switch (type) {
      case 'feeding': return 'Cho ăn';
      case 'water_check': return 'Đo nước';
      case 'water_change': return 'Thay nước';
      case 'harvest': return 'Thu hoạch';
      case 'treatment': return 'Xử lý';
      case 'transfer': return 'Chuyển cá';
      case 'maintenance': return 'Bảo trì';
      default: return 'Khác';
    }
  }

  String get statusLabel {
    switch (status) {
      case 'pending': return 'Chờ xử lý';
      case 'done': return 'Hoàn thành';
      case 'cancelled': return 'Đã huỷ';
      default: return status;
    }
  }
}
