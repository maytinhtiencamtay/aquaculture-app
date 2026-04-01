class Zone {
  final String id;
  final String name;
  final String branchId;
  final String type;
  final DateTime createdAt;

  Zone({required this.id, required this.name, required this.branchId, this.type = 'farming', required this.createdAt});

  factory Zone.fromJson(Map<String, dynamic> json) => Zone(
    id: json['_id'] as String? ?? json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    branchId: json['branchId'] as String? ?? '',
    type: json['type'] as String? ?? 'farming',
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {'_id': id, 'name': name, 'branchId': branchId, 'type': type};

  String get typeLabel {
    switch (type) {
      case 'farming': return 'Nuôi';
      case 'treatment': return 'Xử lý';
      case 'logistics': return 'Hậu cần';
      default: return type;
    }
  }
}
