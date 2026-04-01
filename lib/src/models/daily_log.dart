class DailyLog {
  final String id;
  final String pondId;
  final String branchId;
  final DateTime date;
  final String shift; // morning, afternoon, night
  final String loggedBy;
  final String weather; // sunny, cloudy, rainy, stormy
  final double? waterTemp;
  final String activities; // mô tả hoạt động
  final String feedingNote;
  final String healthNote;
  final String incidentNote;
  final List<String> photos;
  final String note;
  final DateTime createdAt;

  DailyLog({
    required this.id, this.pondId = '', this.branchId = '',
    required this.date, this.shift = 'morning', this.loggedBy = '',
    this.weather = 'sunny', this.waterTemp,
    this.activities = '', this.feedingNote = '',
    this.healthNote = '', this.incidentNote = '',
    this.photos = const [], this.note = '',
    required this.createdAt,
  });

  factory DailyLog.fromJson(Map<String, dynamic> j) => DailyLog(
    id: j['_id'] as String? ?? j['id'] as String? ?? '',
    pondId: j['pondId'] as String? ?? '',
    branchId: j['branchId'] as String? ?? '',
    date: j['date'] != null ? DateTime.parse(j['date']) : DateTime.now(),
    shift: j['shift'] as String? ?? 'morning',
    loggedBy: j['loggedBy'] as String? ?? '',
    weather: j['weather'] as String? ?? 'sunny',
    waterTemp: (j['waterTemp'] as num?)?.toDouble(),
    activities: j['activities'] as String? ?? '',
    feedingNote: j['feedingNote'] as String? ?? '',
    healthNote: j['healthNote'] as String? ?? '',
    incidentNote: j['incidentNote'] as String? ?? '',
    photos: (j['photos'] as List?)?.cast<String>() ?? [],
    note: j['note'] as String? ?? '',
    createdAt: j['createdAt'] != null ? DateTime.parse(j['createdAt']) : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'pondId': pondId, 'branchId': branchId,
    'date': date.toIso8601String(), 'shift': shift,
    'loggedBy': loggedBy, 'weather': weather,
    'waterTemp': waterTemp, 'activities': activities,
    'feedingNote': feedingNote, 'healthNote': healthNote,
    'incidentNote': incidentNote, 'photos': photos, 'note': note,
  };
}
