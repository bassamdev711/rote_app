class InventoryLoad {
  final String? id;
  final String workDayId;
  final String productId;
  final String supplierId;
  final int initialQuantity;
  final double costPrice;
  final String createdAt;

  final String? updatedAt;
  final String? lastSyncedAt;
  final String? syncStatus;
  final bool? isDeleted;
  InventoryLoad({
    this.id,
    required this.workDayId,
    required this.productId,
    required this.supplierId,
    required this.initialQuantity,
    required this.costPrice,
    required this.createdAt,
    this.updatedAt,
    this.lastSyncedAt,
    this.syncStatus = 'pending',
    this.isDeleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'work_day_id': workDayId,
      'product_id': productId,
      'supplier_id': supplierId,
      'initial_quantity': initialQuantity,
      'cost_price': costPrice,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'last_synced_at': lastSyncedAt,
      'sync_status': syncStatus,
      'is_deleted': (isDeleted ?? false) ? 1 : 0,
    };
  }

  factory InventoryLoad.fromMap(Map<String, dynamic> map) {
    return InventoryLoad(
      id: map['id'],
      workDayId: map['work_day_id'],
      productId: map['product_id'],
      supplierId: map['supplier_id'],
      initialQuantity: map['initial_quantity'] is String 
          ? int.tryParse(map['initial_quantity'].toString()) ?? 0 
          : (map['initial_quantity'] as num?)?.toInt() ?? 0,
      costPrice: map['cost_price'] is String
          ? double.tryParse(map['cost_price'].toString()) ?? 0.0
          : (map['cost_price'] as num?)?.toDouble() ?? 0.0,
      createdAt: map['created_at'],
      updatedAt: map['updated_at'] ?? '',
      lastSyncedAt: map['last_synced_at'],
      syncStatus: map['sync_status'] ?? 'pending',
      isDeleted: map['is_deleted'] == 1,
    );
  }

  InventoryLoad copyWith({
    String? id,
    String? workDayId,
    String? productId,
    String? supplierId,
    int? initialQuantity,
    double? costPrice,
    String? createdAt,
    String? updatedAt,
    String? lastSyncedAt,
    String? syncStatus,
    bool? isDeleted,
  }) {
    return InventoryLoad(
      id: id ?? this.id,
      workDayId: workDayId ?? this.workDayId,
      productId: productId ?? this.productId,
      supplierId: supplierId ?? this.supplierId,
      initialQuantity: initialQuantity ?? this.initialQuantity,
      costPrice: costPrice ?? this.costPrice,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
