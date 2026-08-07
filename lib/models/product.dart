class Product {
  final String? id;
  final String name;
  final double defaultPrice;
  final String? unitName;
  final int? itemsPerUnit;
  final String createdAt;

  final String? updatedAt;
  final String? lastSyncedAt;
  final String? syncStatus;
  final bool? isDeleted;
  Product({
    this.id,
    required this.name,
    required this.defaultPrice,
    this.unitName,
    this.itemsPerUnit,
    required this.createdAt,
    this.updatedAt,
    this.lastSyncedAt,
    this.syncStatus = 'pending',
    this.isDeleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'default_price': defaultPrice,
      'unit_name': unitName,
      'items_per_unit': itemsPerUnit,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'last_synced_at': lastSyncedAt,
      'sync_status': syncStatus,
      'is_deleted': (isDeleted ?? false) ? 1 : 0,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      defaultPrice: map['default_price'] is String 
          ? double.tryParse(map['default_price'].toString()) ?? 0.0
          : (map['default_price'] as num?)?.toDouble() ?? 0.0,
      unitName: map['unit_name'],
      itemsPerUnit: map['items_per_unit'] != null
          ? (map['items_per_unit'] is String ? int.tryParse(map['items_per_unit']) : (map['items_per_unit'] as num).toInt())
          : null,
      createdAt: map['created_at'],
      updatedAt: map['updated_at'] ?? '',
      lastSyncedAt: map['last_synced_at'],
      syncStatus: map['sync_status'] ?? 'pending',
      isDeleted: map['is_deleted'] == 1,
    );
  }

  Product copyWith({
    String? id,
    String? name,
    double? defaultPrice,
    String? unitName,
    int? itemsPerUnit,
    String? createdAt,
    String? updatedAt,
    String? lastSyncedAt,
    String? syncStatus,
    bool? isDeleted,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      defaultPrice: defaultPrice ?? this.defaultPrice,
      unitName: unitName ?? this.unitName,
      itemsPerUnit: itemsPerUnit ?? this.itemsPerUnit,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
