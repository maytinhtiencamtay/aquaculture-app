class WaterStandard {
  final String id;
  final String name;
  final String paramKey;
  final String unit;
  final double safeMin;
  final double safeMax;
  final double optimalMin;
  final double optimalMax;
  final bool isActive;
  final String note;

  WaterStandard({
    required this.id,
    required this.name,
    required this.paramKey,
    required this.unit,
    required this.safeMin,
    required this.safeMax,
    required this.optimalMin,
    required this.optimalMax,
    this.isActive = true,
    this.note = '',
  });

  factory WaterStandard.fromJson(Map<String, dynamic> json) => WaterStandard(
    id: json['_id'] as String? ?? json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    paramKey: json['paramKey'] as String? ?? '',
    unit: json['unit'] as String? ?? '',
    safeMin: (json['safeMin'] as num?)?.toDouble() ?? 0,
    safeMax: (json['safeMax'] as num?)?.toDouble() ?? 0,
    optimalMin: (json['optimalMin'] as num?)?.toDouble() ?? 0,
    optimalMax: (json['optimalMax'] as num?)?.toDouble() ?? 0,
    isActive: json['isActive'] as bool? ?? true,
    note: json['note'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'paramKey': paramKey,
    'unit': unit,
    'safeMin': safeMin,
    'safeMax': safeMax,
    'optimalMin': optimalMin,
    'optimalMax': optimalMax,
    'isActive': isActive,
    'note': note,
  };
}
