class Pond {
  final String id;
  final String code;
  final String? zoneId;
  final double area;
  final double volume;
  final double depth;
  final String type;
  final String status;
  final double? currentTemp;
  final double? currentPh;
  final double? currentDo;
  final double? currentNh3;
  final double? currentAlkalinity;
  final double? mapX;
  final double? mapY;
  final String measuredBy;     // employeeId - nhân viên đo nước
  final DateTime createdAt;
  final DateTime? updatedAt;

  Pond({
    required this.id,
    required this.code,
    this.zoneId,
    this.area = 0,
    this.volume = 0,
    this.depth = 0,
    this.type = 'earth',
    this.status = 'inactive',
    this.currentTemp,
    this.currentPh,
    this.currentDo,
    this.currentNh3,
    this.currentAlkalinity,
    this.mapX,
    this.mapY,
    this.measuredBy = '',
    required this.createdAt,
    this.updatedAt,
  });

  factory Pond.fromJson(Map<String, dynamic> json) {
    return Pond(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      zoneId: json['zoneId'] is Map ? (json['zoneId'] as Map)['_id'] as String? : json['zoneId'] as String?,
      area: (json['area'] as num?)?.toDouble() ?? 0,
      volume: (json['volume'] as num?)?.toDouble() ?? 0,
      depth: (json['depth'] as num?)?.toDouble() ?? 0,
      type: json['type'] as String? ?? 'earth',
      status: json['status'] as String? ?? 'inactive',
      currentTemp: (json['currentTemp'] as num?)?.toDouble(),
      currentPh: (json['currentPh'] as num?)?.toDouble(),
      currentDo: (json['currentDo'] as num?)?.toDouble(),
      currentNh3: (json['currentNh3'] as num?)?.toDouble(),
      currentAlkalinity: (json['currentAlkalinity'] as num?)?.toDouble(),
      mapX: (json['mapX'] as num?)?.toDouble(),
      mapY: (json['mapY'] as num?)?.toDouble(),
      measuredBy: json['measuredBy'] as String? ?? '',
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.now(),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'zoneId': zoneId,
      'area': area,
      'volume': volume,
      'depth': depth,
      'type': type,
      'status': status,
      'currentTemp': currentTemp,
      'currentPh': currentPh,
      'currentDo': currentDo,
      'currentNh3': currentNh3,
      'currentAlkalinity': currentAlkalinity,
      'mapX': mapX,
      'mapY': mapY,
      'measuredBy': measuredBy,
    };
  }

  String get statusLabel {
    switch (status) {
      case 'active':
        return 'Đang nuôi';
      case 'inactive':
        return 'Trống';
      case 'maintenance':
        return 'Bảo trì';
      case 'treatment':
        return 'Xử lý';
      default:
        return status;
    }
  }

  String get typeLabel {
    switch (type) {
      case 'earth':
        return 'Ao đất';
      case 'hdpe':
        return 'Ao HDPE';
      case 'glass':
        return 'Bể kính';
      case 'cage':
        return 'Lồng';
      default:
        return type;
    }
  }
}
