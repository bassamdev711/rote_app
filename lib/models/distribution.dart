class Distribution {
  final String? id;
  final String workDayId;
  final String customerId;
  final String productId;
  final String supplierId;
  final int? quantity;
  final double price;
  final String createdAt;

  final String? updatedAt;
  final String? lastSyncedAt;
  final String? syncStatus;
  final bool? isDeleted;
  Distribution({
    this.id,
    required this.workDayId,
    required this.customerId,
    required this.productId,
    required this.supplierId,
    required this.quantity,
    required this.price,
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
      'customer_id': customerId,
      'product_id': productId,
      'supplier_id': supplierId,
      'quantity': quantity,
      'price': price,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'last_synced_at': lastSyncedAt,
      'sync_status': syncStatus,
      'is_deleted': (isDeleted ?? false) ? 1 : 0,
    };
  }

  factory Distribution.fromMap(Map<String, dynamic> map) {
    return Distribution(
      id: map['id'],
      workDayId: map['work_day_id'],
      customerId: map['customer_id'],
      productId: map['product_id'],
      supplierId: map['supplier_id'] ?? 'unknown',
      quantity: map['quantity'] != null 
          ? (map['quantity'] is String ? int.tryParse(map['quantity']) : (map['quantity'] as num).toInt()) 
          : null,
      price: map['price'] is String
          ? double.tryParse(map['price'].toString()) ?? 0.0
          : (map['price'] as num?)?.toDouble() ?? 0.0,
      createdAt: map['created_at'],
      updatedAt: map['updated_at'] ?? '',
      lastSyncedAt: map['last_synced_at'],
      syncStatus: map['sync_status'] ?? 'pending',
      isDeleted: map['is_deleted'] == 1,
    );
  }

  Distribution copyWith({
    String? id,
    String? workDayId,
    String? customerId,
    String? productId,
    String? supplierId,
    int? quantity,
    double? price,
    String? createdAt,
    String? updatedAt,
    String? lastSyncedAt,
    String? syncStatus,
    bool? isDeleted,
  }) {
    return Distribution(
      id: id ?? this.id,
      workDayId: workDayId ?? this.workDayId,
      customerId: customerId ?? this.customerId,
      productId: productId ?? this.productId,
      supplierId: supplierId ?? this.supplierId,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
