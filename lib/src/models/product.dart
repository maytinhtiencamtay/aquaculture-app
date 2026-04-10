class Product {
  final String id;
  final String sku;
  final String name;
  final String category;
  final String brand;
  final String origin;
  final String unit;
  final String description;
  final double price;
  final double costPrice;
  final double stock;
  final double minStock;
  final double maxStock;
  final String supplierId;
  final String location;
  final DateTime? expiryDate;
  final String note;
  final bool isActive;
  final double conversionRatio;  // Hệ số quy đổi: 1 đơn vị nguyên liệu → X đơn vị thành phẩm (VD: 1 gói ART → 3kg ART ủ)
  final String processedUnit;   // Đơn vị thành phẩm sau quy đổi (VD: 'kg' cho ART ủ)
  final DateTime createdAt;

  Product({
    required this.id, this.sku = '', required this.name, this.category = 'feed',
    this.brand = '', this.origin = '', this.unit = 'kg', this.description = '',
    this.price = 0, this.costPrice = 0, this.stock = 0, this.minStock = 0, this.maxStock = 0,
    this.supplierId = '', this.location = '', this.expiryDate, this.note = '',
    this.isActive = true, this.conversionRatio = 0, this.processedUnit = '',
    required this.createdAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['_id'] as String? ?? json['id'] as String? ?? '',
    sku: json['sku'] as String? ?? '',
    name: json['name'] as String? ?? '',
    category: json['category'] as String? ?? 'feed',
    brand: json['brand'] as String? ?? '',
    origin: json['origin'] as String? ?? '',
    unit: json['unit'] as String? ?? 'kg',
    description: json['description'] as String? ?? '',
    price: (json['price'] as num?)?.toDouble() ?? 0,
    costPrice: (json['costPrice'] as num?)?.toDouble() ?? 0,
    stock: (json['stock'] as num?)?.toDouble() ?? 0,
    minStock: (json['minStock'] as num?)?.toDouble() ?? 0,
    maxStock: (json['maxStock'] as num?)?.toDouble() ?? 0,
    supplierId: json['supplierId'] as String? ?? '',
    location: json['location'] as String? ?? '',
    expiryDate: json['expiryDate'] != null ? DateTime.tryParse(json['expiryDate'] as String) : null,
    note: json['note'] as String? ?? '',
    isActive: json['isActive'] as bool? ?? true,
    conversionRatio: (json['conversionRatio'] as num?)?.toDouble() ?? 0,
    processedUnit: json['processedUnit'] as String? ?? '',
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'sku': sku, 'name': name, 'category': category, 'brand': brand, 'origin': origin,
    'unit': unit, 'description': description, 'price': price, 'costPrice': costPrice,
    'stock': stock, 'minStock': minStock, 'maxStock': maxStock,
    'supplierId': supplierId, 'location': location,
    'expiryDate': expiryDate?.toIso8601String(), 'note': note, 'isActive': isActive,
    'conversionRatio': conversionRatio, 'processedUnit': processedUnit,
  };

  bool get isLowStock => minStock > 0 && stock <= minStock;
  bool get isOverStock => maxStock > 0 && stock > maxStock;
  bool get isExpired => expiryDate != null && expiryDate!.isBefore(DateTime.now());
  bool get isExpiringSoon => expiryDate != null && !isExpired && expiryDate!.difference(DateTime.now()).inDays <= 30;
  double get stockValue => stock * costPrice;
  double get profit => price - costPrice;
  /// Số lượng thành phẩm quy đổi được từ tồn kho hiện tại
  double get processedStock => conversionRatio > 0 ? stock * conversionRatio : stock;
  /// Có hệ số quy đổi hay không
  bool get hasConversion => conversionRatio > 0;
  /// Giá thành phẩm quy đổi / đơn vị
  double get processedCostPrice => conversionRatio > 0 ? costPrice / conversionRatio : costPrice;

  String get categoryLabel {
    switch (category) {
      case 'feed': return 'Thức ăn';
      case 'seed': return 'Giống';
      case 'chemical': return 'Vi sinh/Hoá chất';
      case 'medicine': return 'Thuốc';
      case 'accessory': return 'Phụ kiện';
      case 'tool': return 'Dụng cụ';
      default: return category;
    }
  }
}
