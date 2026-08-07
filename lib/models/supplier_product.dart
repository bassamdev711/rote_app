class SupplierProduct {
  final String? id;
  final String supplierId;
  final String productId;
  final double costPrice;

  final String? updatedAt;
  final String? lastSyncedAt;
  final String? syncStatus;
  final bool? isDeleted;
  SupplierProduct({
    this.id,
    required this.supplierId,
    required this.productId,
    required this.costPrice,
    this.updatedAt,
    this.lastSyncedAt,
    this.syncStatus = 'pending',
    this.isDeleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'supplier_id': supplierId,
      'product_id': productId,
      'cost_price': costPrice,
      'updated_at': updatedAt,
      'last_synced_at': lastSyncedAt,
      'sync_status': syncStatus,
      'is_deleted': (isDeleted ?? false) ? 1 : 0,
    };
  }

  factory SupplierProduct.fromMap(Map<String, dynamic> map) {
    return SupplierProduct(
      id: map['id'],
      supplierId: map['supplier_id'],
      productId: map['product_id'],
      costPrice: map['cost_price'] is String
          ? double.tryParse(map['cost_price'].toString()) ?? 0.0
          : (map['cost_price'] as num?)?.toDouble() ?? 0.0,
    
      updatedAt: map['updated_at'],

      lastSyncedAt: map['last_synced_at'],

      syncStatus: map['sync_status'] ?? 'pending',

      isDeleted: map['is_deleted'] == 1,
    );
  }
}
