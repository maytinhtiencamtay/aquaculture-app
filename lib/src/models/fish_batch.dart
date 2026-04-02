class FishBatch {
  final String id;
  final String name;           // Tên lô cá (VD: "Lô cá tra 01")
  final String pondId;         // Ao chính (backward compat) — ao đầu tiên hoặc duy nhất
  final String branchId;       // Chi nhánh
  final String speciesId;
  final List<Map<String, dynamic>> pondAllocations; // [{pondId, quantity}] — phân bổ cá vào nhiều ao
  final DateTime stockingDate;
  final int initialQuantity;
  final double initialSize;    // cm
  final double initialWeight;  // g
  final double importPrice;    // VNĐ/con — giá nhập
  final int currentQuantity;
  final double currentSize;    // cm – kích thước TB hiện tại
  final double currentWeight;  // g – trọng lượng TB hiện tại
  final int mortalityQuantity; // số lượng hao hụt tích luỹ
  final double feedConsumed;   // kg thức ăn đã dùng
  final DateTime? expectedHarvestDate;
  final DateTime? harvestDate;
  final double harvestWeight;  // kg tổng sản lượng thu hoạch
  final int harvestQuantity;   // số lượng thu hoạch
  final String status;
  final String source;
  final String note;
  final String createdBy;      // employeeId - người tạo lô
  final String inspectedBy;    // employeeId - nhân viên kiểm định cá
  final DateTime createdAt;
  final DateTime? updatedAt;

  FishBatch({
    required this.id, this.name = '', required this.pondId, this.branchId = '',
    required this.speciesId, this.pondAllocations = const [],
    required this.stockingDate, required this.initialQuantity,
    this.initialSize = 0, this.initialWeight = 0, this.importPrice = 0,
    this.currentQuantity = 0, this.currentSize = 0, this.currentWeight = 0,
    this.mortalityQuantity = 0, this.feedConsumed = 0,
    this.expectedHarvestDate, this.harvestDate,
    this.harvestWeight = 0, this.harvestQuantity = 0,
    this.status = 'active', this.source = '', this.note = '',
    this.createdBy = '', this.inspectedBy = '',
    required this.createdAt, this.updatedAt,
  });

  factory FishBatch.fromJson(Map<String, dynamic> json) {
    final allocs = json['pondAllocations'] != null
        ? List<Map<String, dynamic>>.from(json['pondAllocations'] as List)
        : <Map<String, dynamic>>[];
    return FishBatch(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      pondId: json['pondId'] as String? ?? '',
      branchId: json['branchId'] as String? ?? '',
      speciesId: json['speciesId'] as String? ?? '',
      pondAllocations: allocs,
      stockingDate: json['stockingDate'] != null ? DateTime.parse(json['stockingDate'] as String) : DateTime.now(),
      initialQuantity: (json['initialQuantity'] as num?)?.toInt() ?? 0,
      initialSize: (json['initialSize'] as num?)?.toDouble() ?? 0,
      initialWeight: (json['initialWeight'] as num?)?.toDouble() ?? 0,
      importPrice: (json['importPrice'] as num?)?.toDouble() ?? 0,
      currentQuantity: (json['currentQuantity'] as num?)?.toInt() ?? 0,
      currentSize: (json['currentSize'] as num?)?.toDouble() ?? 0,
      currentWeight: (json['currentWeight'] as num?)?.toDouble() ?? 0,
      mortalityQuantity: (json['mortalityQuantity'] as num?)?.toInt() ?? 0,
      feedConsumed: (json['feedConsumed'] as num?)?.toDouble() ?? 0,
      expectedHarvestDate: json['expectedHarvestDate'] != null ? DateTime.parse(json['expectedHarvestDate'] as String) : null,
      harvestDate: json['harvestDate'] != null ? DateTime.parse(json['harvestDate'] as String) : null,
      harvestWeight: (json['harvestWeight'] as num?)?.toDouble() ?? 0,
      harvestQuantity: (json['harvestQuantity'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'active',
      source: json['source'] as String? ?? '',
      note: json['note'] as String? ?? '',
      createdBy: json['createdBy'] as String? ?? '',
      inspectedBy: json['inspectedBy'] as String? ?? '',
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.now(),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': id, 'name': name, 'pondId': pondId, 'branchId': branchId,
    'speciesId': speciesId, 'pondAllocations': pondAllocations,
    'stockingDate': stockingDate.toIso8601String(),
    'initialQuantity': initialQuantity, 'initialSize': initialSize,
    'initialWeight': initialWeight, 'importPrice': importPrice,
    'currentQuantity': currentQuantity,
    'currentSize': currentSize, 'currentWeight': currentWeight,
    'mortalityQuantity': mortalityQuantity, 'feedConsumed': feedConsumed,
    'expectedHarvestDate': expectedHarvestDate?.toIso8601String(),
    'harvestDate': harvestDate?.toIso8601String(),
    'harvestWeight': harvestWeight, 'harvestQuantity': harvestQuantity,
    'status': status, 'source': source, 'note': note,
    'createdBy': createdBy, 'inspectedBy': inspectedBy,
  };

  /// Số cá đã phân bổ vào ao
  int get allocatedQuantity => pondAllocations.fold<int>(0, (s, a) => s + ((a['quantity'] as num?)?.toInt() ?? 0));
  /// Số cá chưa phân bổ (dựa trên số lượng còn sống)
  int get unallocatedQuantity => (currentQuantity - allocatedQuantity).clamp(0, currentQuantity);
  /// Lấy số cá trong 1 ao cụ thể
  int quantityInPond(String pId) {
    // Check pondAllocations first, fall back to pondId
    for (final a in pondAllocations) {
      if (a['pondId'] == pId) return (a['quantity'] as num?)?.toInt() ?? 0;
    }
    return pondId == pId ? currentQuantity : 0;
  }
  /// Danh sách pondId mà lô cá này đang nuôi
  List<String> get pondIds {
    if (pondAllocations.isNotEmpty) return pondAllocations.map((a) => a['pondId'] as String).toList();
    return pondId.isNotEmpty ? [pondId] : [];
  }

  /// Tỷ lệ sống sót (%)
  double get survivalRate => initialQuantity > 0 ? (currentQuantity / initialQuantity) * 100 : 0;
  /// Tỷ lệ hao hụt (%)
  double get mortalityRate => initialQuantity > 0 ? (mortalityQuantity / initialQuantity) * 100 : 0;
  /// Hệ số chuyển đổi thức ăn (FCR)
  double get fcr {
    final biomassGain = (currentWeight * currentQuantity / 1000) - (initialWeight * initialQuantity / 1000);
    return biomassGain > 0 && feedConsumed > 0 ? feedConsumed / biomassGain : 0;
  }
  /// Số ngày nuôi
  int get daysOfCulture => DateTime.now().difference(stockingDate).inDays;
  /// Tổng giá nhập
  double get totalImportCost => importPrice * initialQuantity;

  String get statusLabel {
    switch (status) {
      case 'active': return 'Đang nuôi';
      case 'transferred': return 'Đã chuyển';
      case 'harvested': return 'Đã thu hoạch';
      default: return status;
    }
  }
}
