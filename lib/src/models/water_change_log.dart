class WaterChangeLog {
  final String id;
  final String pondId;
  final DateTime date;
  final double percentChanged; // % lượng nước thay
  final double volumeChanged; // m³
  final String waterSource; // well, river, reservoir, treatment
  final double? incomingPh;
  final double? incomingTemp;
  final double? incomingDo;
  final String reason; // routine, emergency, treatment, pre_stocking
  final String performedBy;
  final String note;
  final DateTime createdAt;

  WaterChangeLog({
    required this.id, this.pondId = '', required this.date,
    this.percentChanged = 30, this.volumeChanged = 0,
    this.waterSource = 'well', this.incomingPh, this.incomingTemp,
    this.incomingDo, this.reason = 'routine', this.performedBy = '',
    this.note = '', required this.createdAt,
  });

  factory WaterChangeLog.fromJson(Map<String, dynamic> j) => WaterChangeLog(
    id: j['_id'] as String? ?? j['id'] as String? ?? '',
    pondId: j['pondId'] as String? ?? '',
    date: j['date'] != null ? DateTime.parse(j['date']) : DateTime.now(),
    percentChanged: (j['percentChanged'] as num?)?.toDouble() ?? 30,
    volumeChanged: (j['volumeChanged'] as num?)?.toDouble() ?? 0,
    waterSource: j['waterSource'] as String? ?? 'well',
    incomingPh: (j['incomingPh'] as num?)?.toDouble(),
    incomingTemp: (j['incomingTemp'] as num?)?.toDouble(),
    incomingDo: (j['incomingDo'] as num?)?.toDouble(),
    reason: j['reason'] as String? ?? 'routine',
    performedBy: j['performedBy'] as String? ?? '',
    note: j['note'] as String? ?? '',
    createdAt: j['createdAt'] != null ? DateTime.parse(j['createdAt']) : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'pondId': pondId, 'date': date.toIso8601String(),
    'percentChanged': percentChanged, 'volumeChanged': volumeChanged,
    'waterSource': waterSource, 'incomingPh': incomingPh,
    'incomingTemp': incomingTemp, 'incomingDo': incomingDo,
    'reason': reason, 'performedBy': performedBy, 'note': note,
  };
}
