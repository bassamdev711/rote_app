class SupplierReturn {
  final String? id;
  final String workDayId;
  final String supplierId;
  final String productId;
  final int? quantity;
  final double costPrice;
  final String createdAt;

  final String? updatedAt;
  final String? lastSyncedAt;
  final String? syncStatus;
  final bool? isDeleted;
  SupplierReturn({
    this.id,
    required this.workDayId,
    required this.supplierId,
    required this.productId,
    required this.quantity,
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
      'supplier_id': supplierId,
      'product_id': productId,
      'quantity': quantity,
      'cost_price': costPrice,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'last_synced_at': lastSyncedAt,
      'sync_status': syncStatus,
      'is_deleted': (isDeleted ?? false) ? 1 : 0,
    };
  }

  factory SupplierReturn.fromMap(Map<String, dynamic> map) {
    return SupplierReturn(
      id: map['id'],
      workDayId: map['work_day_id'],
      supplierId: map['supplier_id'],
      productId: map['product_id'],
      quantity: map['quantity'] != null 
          ? (map['quantity'] is String ? int.tryParse(map['quantity']) : (map['quantity'] as num).toInt()) 
          : null,
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
}
