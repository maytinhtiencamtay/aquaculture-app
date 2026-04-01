class Customer {
  final String id;
  final String name;
  final String type;
  final String company;
  final String phone;
  final String email;
  final String address;
  final String contact;
  final String note;
  final double debt;
  final DateTime createdAt;

  Customer({required this.id, required this.name, this.type = 'retail', this.company = '', this.phone = '', this.email = '', this.address = '', this.contact = '', this.note = '', this.debt = 0, required this.createdAt});

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    id: json['_id'] as String? ?? json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    type: json['type'] as String? ?? 'retail',
    company: json['company'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    email: json['email'] as String? ?? '',
    address: json['address'] as String? ?? '',
    contact: json['contact'] as String? ?? '',
    note: json['note'] as String? ?? '',
    debt: (json['debt'] as num?)?.toDouble() ?? 0,
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {'name': name, 'type': type, 'company': company, 'phone': phone, 'email': email, 'address': address, 'contact': contact, 'note': note, 'debt': debt};

  String get typeLabel => type == 'wholesale' ? 'Đại lý' : 'Khách lẻ';
}
