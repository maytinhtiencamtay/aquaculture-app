class SizeMeasurement {
  final String id;
  final String fishBatchId;
  final String pondId;
  final String storeId;
  final DateTime date;
  final double avgWeight;    // g — trọng lượng TB mẫu
  final double avgLength;    // cm — chiều dài TB mẫu
  final int sampleCount;     // số cá đo mẫu
  final int remainingQty;    // số cá còn lại (ước tính)
  final String measuredBy;   // tên/ID người đo
  final String note;
  final DateTime createdAt;

  SizeMeasurement({
    required this.id,
    required this.fishBatchId,
    this.pondId = '',
    this.storeId = '',
    required this.date,
    this.avgWeight = 0,
    this.avgLength = 0,
    this.sampleCount = 0,
    this.remainingQty = 0,
    this.measuredBy = '',
    this.note = '',
    required this.createdAt,
  });

  factory SizeMeasurement.fromJson(Map<String, dynamic> json) {
    return SizeMeasurement(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      fishBatchId: json['fishBatchId'] as String? ?? '',
      pondId: json['pondId'] as String? ?? '',
      storeId: json['storeId'] as String? ?? '',
      date: json['date'] != null ? DateTime.parse(json['date'] as String) : DateTime.now(),
      avgWeight: (json['avgWeight'] as num?)?.toDouble() ?? 0,
      avgLength: (json['avgLength'] as num?)?.toDouble() ?? 0,
      sampleCount: (json['sampleCount'] as num?)?.toInt() ?? 0,
      remainingQty: (json['remainingQty'] as num?)?.toInt() ?? 0,
      measuredBy: json['measuredBy'] as String? ?? '',
      note: json['note'] as String? ?? '',
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'fishBatchId': fishBatchId,
    'pondId': pondId,
    'storeId': storeId,
    'date': date.toIso8601String(),
    'avgWeight': avgWeight,
    'avgLength': avgLength,
    'sampleCount': sampleCount,
    'remainingQty': remainingQty,
    'measuredBy': measuredBy,
    'note': note,
  };
}
