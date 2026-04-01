class Species {
  final String id;
  final String name;
  final String description;
  final String imageUrl;          // URL hình ảnh loài cá
  final double requiredTemp;    // Nhiệt độ tối ưu (°C)
  final double minTemp;         // Nhiệt độ tối thiểu (°C)
  final double maxTemp;         // Nhiệt độ tối đa (°C)
  final double requiredPh;
  final double requiredDo;      // Oxy hoà tan tối thiểu (mg/L)
  final double maxNh3;          // Ngưỡng NH3 tối đa (mg/L)
  final double feedRatio;       // Tỷ lệ cho ăn (% trọng lượng/ngày)
  final double harvestableWeight; // Trọng lượng thu hoạch (g/con)
  final int growthDays;         // Số ngày nuôi đến thu hoạch
  final double densityPerM2;    // Mật độ (con/m²)
  final DateTime createdAt;
  final DateTime? updatedAt;

  Species({
    required this.id, required this.name, this.description = '',
    this.imageUrl = '',
    this.requiredTemp = 28, this.minTemp = 20, this.maxTemp = 35,
    this.requiredPh = 7, this.requiredDo = 4, this.maxNh3 = 0.1,
    this.feedRatio = 1.5, this.harvestableWeight = 500,
    this.growthDays = 180, this.densityPerM2 = 5,
    required this.createdAt, this.updatedAt,
  });

  factory Species.fromJson(Map<String, dynamic> json) => Species(
    id: json['_id'] as String? ?? json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    description: json['description'] as String? ?? '',
    imageUrl: json['imageUrl'] as String? ?? '',
    requiredTemp: (json['requiredTemp'] as num?)?.toDouble() ?? 28,
    minTemp: (json['minTemp'] as num?)?.toDouble() ?? 20,
    maxTemp: (json['maxTemp'] as num?)?.toDouble() ?? 35,
    requiredPh: (json['requiredPh'] as num?)?.toDouble() ?? 7,
    requiredDo: (json['requiredDo'] as num?)?.toDouble() ?? 4,
    maxNh3: (json['maxNh3'] as num?)?.toDouble() ?? 0.1,
    feedRatio: (json['feedRatio'] as num?)?.toDouble() ?? 1.5,
    harvestableWeight: (json['harvestableWeight'] as num?)?.toDouble() ?? 500,
    growthDays: (json['growthDays'] as num?)?.toInt() ?? 180,
    densityPerM2: (json['densityPerM2'] as num?)?.toDouble() ?? 5,
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.now(),
    updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : null,
  );

  Map<String, dynamic> toJson() => {
    'name': name, 'description': description,
    'imageUrl': imageUrl,
    'requiredTemp': requiredTemp, 'minTemp': minTemp, 'maxTemp': maxTemp,
    'requiredPh': requiredPh, 'requiredDo': requiredDo, 'maxNh3': maxNh3,
    'feedRatio': feedRatio, 'harvestableWeight': harvestableWeight,
    'growthDays': growthDays, 'densityPerM2': densityPerM2,
  };
}
