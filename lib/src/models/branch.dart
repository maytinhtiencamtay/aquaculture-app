class Branch {
  String id;
  String name;
  String address;
  String contact;
  String manager;
  DateTime createdAt;

  Branch({
    required this.id,
    required this.name,
    this.address = '',
    this.contact = '',
    this.manager = '',
    required this.createdAt,
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: json['_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      contact: json['contact'] as String? ?? '',
      manager: json['manager'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'address': address,
      'contact': contact,
      'manager': manager,
    };
  }
}