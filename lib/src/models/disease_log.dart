class DiseaseLog {
  final String id;
  final String pondId;
  final String fishBatchId;
  final String diseaseName;
  final String symptoms;
  final String severity; // mild, moderate, severe
  final DateTime detectedDate;
  final String detectedBy;
  final String status; // detected, treating, resolved, recurring
  final int affectedQuantity;
  final double mortalityFromDisease;
  final String note;
  final DateTime createdAt;

  DiseaseLog({
    required this.id, this.pondId = '', this.fishBatchId = '',
    required this.diseaseName, this.symptoms = '',
    this.severity = 'moderate', required this.detectedDate,
    this.detectedBy = '', this.status = 'detected',
    this.affectedQuantity = 0, this.mortalityFromDisease = 0,
    this.note = '', required this.createdAt,
  });

  factory DiseaseLog.fromJson(Map<String, dynamic> j) => DiseaseLog(
    id: j['_id'] as String? ?? j['id'] as String? ?? '',
    pondId: j['pondId'] as String? ?? '',
    fishBatchId: j['fishBatchId'] as String? ?? '',
    diseaseName: j['diseaseName'] as String? ?? '',
    symptoms: j['symptoms'] as String? ?? '',
    severity: j['severity'] as String? ?? 'moderate',
    detectedDate: j['detectedDate'] != null ? DateTime.parse(j['detectedDate']) : DateTime.now(),
    detectedBy: j['detectedBy'] as String? ?? '',
    status: j['status'] as String? ?? 'detected',
    affectedQuantity: (j['affectedQuantity'] as num?)?.toInt() ?? 0,
    mortalityFromDisease: (j['mortalityFromDisease'] as num?)?.toDouble() ?? 0,
    note: j['note'] as String? ?? '',
    createdAt: j['createdAt'] != null ? DateTime.parse(j['createdAt']) : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'pondId': pondId, 'fishBatchId': fishBatchId,
    'diseaseName': diseaseName, 'symptoms': symptoms,
    'severity': severity, 'detectedDate': detectedDate.toIso8601String(),
    'detectedBy': detectedBy, 'status': status,
    'affectedQuantity': affectedQuantity,
    'mortalityFromDisease': mortalityFromDisease, 'note': note,
  };
}
