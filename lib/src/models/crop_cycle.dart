class CropCycle {
  final String id;
  final String name;
  final String branchId;
  final DateTime startDate;
  final DateTime? endDate;
  final String status; // planning, active, completed
  final List<String> pondIds;
  final List<String> fishBatchIds;
  final String speciesId;
  final double plannedBudget;
  final double actualCost;
  final double revenue;
  final int plannedDensity; // con/m²
  final String note;
  final String createdBy;
  final DateTime createdAt;

  CropCycle({
    required this.id, required this.name, this.branchId = '',
    required this.startDate, this.endDate,
    this.status = 'planning', this.pondIds = const [],
    this.fishBatchIds = const [], this.speciesId = '',
    this.plannedBudget = 0, this.actualCost = 0, this.revenue = 0,
    this.plannedDensity = 5, this.note = '', this.createdBy = '',
    required this.createdAt,
  });

  double get profit => revenue - actualCost;
  int get durationDays => (endDate ?? DateTime.now()).difference(startDate).inDays;

  factory CropCycle.fromJson(Map<String, dynamic> j) => CropCycle(
    id: j['_id'] as String? ?? j['id'] as String? ?? '',
    name: j['name'] as String? ?? '',
    branchId: j['branchId'] as String? ?? '',
    startDate: j['startDate'] != null ? DateTime.parse(j['startDate']) : DateTime.now(),
    endDate: j['endDate'] != null ? DateTime.parse(j['endDate']) : null,
    status: j['status'] as String? ?? 'planning',
    pondIds: (j['pondIds'] as List?)?.cast<String>() ?? [],
    fishBatchIds: (j['fishBatchIds'] as List?)?.cast<String>() ?? [],
    speciesId: j['speciesId'] as String? ?? '',
    plannedBudget: (j['plannedBudget'] as num?)?.toDouble() ?? 0,
    actualCost: (j['actualCost'] as num?)?.toDouble() ?? 0,
    revenue: (j['revenue'] as num?)?.toDouble() ?? 0,
    plannedDensity: (j['plannedDensity'] as num?)?.toInt() ?? 5,
    note: j['note'] as String? ?? '',
    createdBy: j['createdBy'] as String? ?? '',
    createdAt: j['createdAt'] != null ? DateTime.parse(j['createdAt']) : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'name': name, 'branchId': branchId,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'status': status, 'pondIds': pondIds,
    'fishBatchIds': fishBatchIds, 'speciesId': speciesId,
    'plannedBudget': plannedBudget, 'actualCost': actualCost,
    'revenue': revenue, 'plannedDensity': plannedDensity,
    'note': note, 'createdBy': createdBy,
  };
}
