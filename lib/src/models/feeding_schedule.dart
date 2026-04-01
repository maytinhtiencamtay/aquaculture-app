class FeedingSchedule {
  final String id;
  final String pondId;
  final String fishBatchId;
  final String productId;
  final String productName;
  final double dailyAmount; // kg/ngày
  final int timesPerDay; // số lần/ngày
  final List<String> feedingTimes; // ["06:00", "11:00", "17:00"]
  final double rationPercent; // % trọng lượng cơ thể
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;
  final bool adjustForWeather; // giảm khi thời tiết xấu
  final String note;
  final DateTime createdAt;

  FeedingSchedule({
    required this.id, this.pondId = '', this.fishBatchId = '',
    this.productId = '', this.productName = '',
    this.dailyAmount = 0, this.timesPerDay = 3,
    this.feedingTimes = const ['06:00', '11:00', '17:00'],
    this.rationPercent = 3.0, required this.startDate,
    this.endDate, this.isActive = true, this.adjustForWeather = true,
    this.note = '', required this.createdAt,
  });

  factory FeedingSchedule.fromJson(Map<String, dynamic> j) => FeedingSchedule(
    id: j['_id'] as String? ?? j['id'] as String? ?? '',
    pondId: j['pondId'] as String? ?? '',
    fishBatchId: j['fishBatchId'] as String? ?? '',
    productId: j['productId'] as String? ?? '',
    productName: j['productName'] as String? ?? '',
    dailyAmount: (j['dailyAmount'] as num?)?.toDouble() ?? 0,
    timesPerDay: (j['timesPerDay'] as num?)?.toInt() ?? 3,
    feedingTimes: (j['feedingTimes'] as List?)?.cast<String>() ?? ['06:00', '11:00', '17:00'],
    rationPercent: (j['rationPercent'] as num?)?.toDouble() ?? 3.0,
    startDate: j['startDate'] != null ? DateTime.parse(j['startDate']) : DateTime.now(),
    endDate: j['endDate'] != null ? DateTime.parse(j['endDate']) : null,
    isActive: j['isActive'] as bool? ?? true,
    adjustForWeather: j['adjustForWeather'] as bool? ?? true,
    note: j['note'] as String? ?? '',
    createdAt: j['createdAt'] != null ? DateTime.parse(j['createdAt']) : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'pondId': pondId, 'fishBatchId': fishBatchId,
    'productId': productId, 'productName': productName,
    'dailyAmount': dailyAmount, 'timesPerDay': timesPerDay,
    'feedingTimes': feedingTimes, 'rationPercent': rationPercent,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'isActive': isActive, 'adjustForWeather': adjustForWeather,
    'note': note,
  };
}
