class TreatmentLog {
  final String id;
  final String diseaseLogId;
  final String pondId;
  final String fishBatchId;
  final String medicineName;
  final String medicineType; // antibiotic, chemical, probiotic, herbal, other
  final double dosage;
  final String dosageUnit; // ml/m3, g/kg, ppm
  final DateTime startDate;
  final DateTime? endDate;
  final int durationDays;
  final int withdrawalDays; // thời gian cách ly trước thu hoạch
  final DateTime? safeHarvestDate;
  final String method; // bath, feed_mix, splash, inject
  final String status; // in_progress, completed, cancelled
  final double cost;
  final String treatedBy;
  final String note;
  final DateTime createdAt;

  TreatmentLog({
    required this.id, this.diseaseLogId = '', this.pondId = '',
    this.fishBatchId = '', required this.medicineName,
    this.medicineType = 'chemical', this.dosage = 0,
    this.dosageUnit = 'ml/m3', required this.startDate,
    this.endDate, this.durationDays = 1, this.withdrawalDays = 0,
    this.safeHarvestDate, this.method = 'bath',
    this.status = 'in_progress', this.cost = 0,
    this.treatedBy = '', this.note = '', required this.createdAt,
  });

  bool get isWithdrawalActive {
    if (withdrawalDays <= 0) return false;
    final end = endDate ?? startDate.add(Duration(days: durationDays));
    final safe = end.add(Duration(days: withdrawalDays));
    return DateTime.now().isBefore(safe);
  }

  factory TreatmentLog.fromJson(Map<String, dynamic> j) => TreatmentLog(
    id: j['_id'] as String? ?? j['id'] as String? ?? '',
    diseaseLogId: j['diseaseLogId'] as String? ?? '',
    pondId: j['pondId'] as String? ?? '',
    fishBatchId: j['fishBatchId'] as String? ?? '',
    medicineName: j['medicineName'] as String? ?? '',
    medicineType: j['medicineType'] as String? ?? 'chemical',
    dosage: (j['dosage'] as num?)?.toDouble() ?? 0,
    dosageUnit: j['dosageUnit'] as String? ?? 'ml/m3',
    startDate: j['startDate'] != null ? DateTime.parse(j['startDate']) : DateTime.now(),
    endDate: j['endDate'] != null ? DateTime.parse(j['endDate']) : null,
    durationDays: (j['durationDays'] as num?)?.toInt() ?? 1,
    withdrawalDays: (j['withdrawalDays'] as num?)?.toInt() ?? 0,
    safeHarvestDate: j['safeHarvestDate'] != null ? DateTime.parse(j['safeHarvestDate']) : null,
    method: j['method'] as String? ?? 'bath',
    status: j['status'] as String? ?? 'in_progress',
    cost: (j['cost'] as num?)?.toDouble() ?? 0,
    treatedBy: j['treatedBy'] as String? ?? '',
    note: j['note'] as String? ?? '',
    createdAt: j['createdAt'] != null ? DateTime.parse(j['createdAt']) : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'diseaseLogId': diseaseLogId, 'pondId': pondId,
    'fishBatchId': fishBatchId, 'medicineName': medicineName,
    'medicineType': medicineType, 'dosage': dosage,
    'dosageUnit': dosageUnit, 'startDate': startDate.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'durationDays': durationDays, 'withdrawalDays': withdrawalDays,
    'safeHarvestDate': safeHarvestDate?.toIso8601String(),
    'method': method, 'status': status, 'cost': cost,
    'treatedBy': treatedBy, 'note': note,
  };
}
