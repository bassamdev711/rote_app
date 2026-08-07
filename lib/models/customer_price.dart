class CustomerPrice {
  final String? id;
  final String customerId;
  final String productId;
  final double customPrice;

  final String? updatedAt;
  final String? lastSyncedAt;
  final String? syncStatus;
  final bool? isDeleted;
  CustomerPrice({
    this.id,
    required this.customerId,
    required this.productId,
    required this.customPrice,
    this.updatedAt,
    this.lastSyncedAt,
    this.syncStatus = 'pending',
    this.isDeleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'product_id': productId,
      'custom_price': customPrice,
      'updated_at': updatedAt,
      'last_synced_at': lastSyncedAt,
      'sync_status': syncStatus,
      'is_deleted': (isDeleted ?? false) ? 1 : 0,
    };
  }

  factory CustomerPrice.fromMap(Map<String, dynamic> map) {
    return CustomerPrice(
      id: map['id'],
      customerId: map['customer_id'],
      productId: map['product_id'],
      customPrice: map['custom_price'] is String
          ? double.tryParse(map['custom_price'].toString()) ?? 0.0
          : (map['custom_price'] as num?)?.toDouble() ?? 0.0,
    
      updatedAt: map['updated_at'],

      lastSyncedAt: map['last_synced_at'],

      syncStatus: map['sync_status'] ?? 'pending',

      isDeleted: map['is_deleted'] == 1,
    );
  }

  CustomerPrice copyWith({
    String? id,
    String? customerId,
    String? productId,
    double? customPrice,
    String? updatedAt,
    String? lastSyncedAt,
    String? syncStatus,
    bool? isDeleted,
  }) {
    return CustomerPrice(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      productId: productId ?? this.productId,
      customPrice: customPrice ?? this.customPrice,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
