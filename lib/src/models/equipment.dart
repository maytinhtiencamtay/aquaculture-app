class Equipment {
  final String id;
  final String name;
  final String type; // aerator, pump, feeder, generator, sensor, other
  final String brand;
  final String model;
  final String serialNumber;
  final String pondId;
  final String branchId;
  final String status; // active, maintenance, broken, retired
  final DateTime? purchaseDate;
  final double purchaseCost;
  final int warrantyMonths;
  final DateTime? lastMaintenanceDate;
  final DateTime? nextMaintenanceDate;
  final int maintenanceIntervalDays;
  final double powerConsumption; // kW
  final String note;
  final DateTime createdAt;

  Equipment({
    required this.id, required this.name, this.type = 'other',
    this.brand = '', this.model = '', this.serialNumber = '',
    this.pondId = '', this.branchId = '', this.status = 'active',
    this.purchaseDate, this.purchaseCost = 0, this.warrantyMonths = 12,
    this.lastMaintenanceDate, this.nextMaintenanceDate,
    this.maintenanceIntervalDays = 90, this.powerConsumption = 0,
    this.note = '', required this.createdAt,
  });

  bool get isMaintenanceDue {
    if (nextMaintenanceDate == null) return false;
    return DateTime.now().isAfter(nextMaintenanceDate!);
  }

  bool get isWarrantyActive {
    if (purchaseDate == null) return false;
    return DateTime.now().isBefore(purchaseDate!.add(Duration(days: warrantyMonths * 30)));
  }

  factory Equipment.fromJson(Map<String, dynamic> j) => Equipment(
    id: j['_id'] as String? ?? j['id'] as String? ?? '',
    name: j['name'] as String? ?? '',
    type: j['type'] as String? ?? 'other',
    brand: j['brand'] as String? ?? '',
    model: j['model'] as String? ?? '',
    serialNumber: j['serialNumber'] as String? ?? '',
    pondId: j['pondId'] as String? ?? '',
    branchId: j['branchId'] as String? ?? '',
    status: j['status'] as String? ?? 'active',
    purchaseDate: j['purchaseDate'] != null ? DateTime.parse(j['purchaseDate']) : null,
    purchaseCost: (j['purchaseCost'] as num?)?.toDouble() ?? 0,
    warrantyMonths: (j['warrantyMonths'] as num?)?.toInt() ?? 12,
    lastMaintenanceDate: j['lastMaintenanceDate'] != null ? DateTime.parse(j['lastMaintenanceDate']) : null,
    nextMaintenanceDate: j['nextMaintenanceDate'] != null ? DateTime.parse(j['nextMaintenanceDate']) : null,
    maintenanceIntervalDays: (j['maintenanceIntervalDays'] as num?)?.toInt() ?? 90,
    powerConsumption: (j['powerConsumption'] as num?)?.toDouble() ?? 0,
    note: j['note'] as String? ?? '',
    createdAt: j['createdAt'] != null ? DateTime.parse(j['createdAt']) : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'name': name, 'type': type, 'brand': brand, 'model': model,
    'serialNumber': serialNumber, 'pondId': pondId, 'branchId': branchId,
    'status': status,
    'purchaseDate': purchaseDate?.toIso8601String(),
    'purchaseCost': purchaseCost, 'warrantyMonths': warrantyMonths,
    'lastMaintenanceDate': lastMaintenanceDate?.toIso8601String(),
    'nextMaintenanceDate': nextMaintenanceDate?.toIso8601String(),
    'maintenanceIntervalDays': maintenanceIntervalDays,
    'powerConsumption': powerConsumption, 'note': note,
  };
}
