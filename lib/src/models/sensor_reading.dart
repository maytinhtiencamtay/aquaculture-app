class SensorReading {
  final String id;
  final String pondId;
  final String pondCode;
  final DateTime timestamp;
  final double? temperature;
  final double? pH;
  final double? oxygen;
  final double? nh3;
  final double? alkalinity;
  final String measuredBy;

  SensorReading({
    required this.id,
    required this.pondId,
    this.pondCode = '',
    required this.timestamp,
    this.temperature,
    this.pH,
    this.oxygen,
    this.nh3,
    this.alkalinity,
    this.measuredBy = '',
  });

  factory SensorReading.fromJson(Map<String, dynamic> json) {
    return SensorReading(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      pondId: json['pondId'] as String? ?? '',
      pondCode: json['pondCode'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      temperature: (json['temperature'] as num?)?.toDouble(),
      pH: (json['pH'] as num?)?.toDouble(),
      oxygen: (json['oxygen'] as num?)?.toDouble(),
      nh3: (json['nh3'] as num?)?.toDouble(),
      alkalinity: (json['alkalinity'] as num?)?.toDouble(),
      measuredBy: json['measuredBy'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pondId': pondId,
      'pondCode': pondCode,
      'timestamp': timestamp.toIso8601String(),
      'temperature': temperature,
      'pH': pH,
      'oxygen': oxygen,
      'nh3': nh3,
      'alkalinity': alkalinity,
      'measuredBy': measuredBy,
    };
  }
}
