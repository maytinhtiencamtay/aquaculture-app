class Supplier {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final String taxCode;
  final String note;
  final DateTime createdAt;

  Supplier({
    required this.id,
    required this.name,
    this.phone = '',
    this.email = '',
    this.address = '',
    this.taxCode = '',
    this.note = '',
    required this.createdAt,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) => Supplier(
    id: json['_id'] as String? ?? json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    email: json['email'] as String? ?? '',
    address: json['address'] as String? ?? '',
    taxCode: json['taxCode'] as String? ?? '',
    note: json['note'] as String? ?? '',
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'name': name, 'phone': phone, 'email': email,
    'address': address, 'taxCode': taxCode, 'note': note,
  };
}
