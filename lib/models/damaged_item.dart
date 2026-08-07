class DamagedItem {
  final String id;
  final String workDayId;
  final String supplierId;
  final String productId;
  final int quantity;
  final double costPrice;
  final int isChargedToDistributor;
  final String createdAt;
  final String? syncStatus;
  final bool? isDeleted;

  DamagedItem({
    required this.id,
    required this.workDayId,
    required this.supplierId,
    required this.productId,
    required this.quantity,
    required this.costPrice,
    required this.isChargedToDistributor,
    required this.createdAt,
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
      'is_charged_to_distributor': isChargedToDistributor,
      'created_at': createdAt,
      'sync_status': syncStatus,
      'is_deleted': (isDeleted ?? false) ? 1 : 0,
    };
  }

  factory DamagedItem.fromMap(Map<String, dynamic> map) {
    return DamagedItem(
      id: map['id'],
      workDayId: map['work_day_id'],
      supplierId: map['supplier_id'],
      productId: map['product_id'],
      quantity: map['quantity'] is String 
          ? int.tryParse(map['quantity'].toString()) ?? 0 
          : (map['quantity'] as num?)?.toInt() ?? 0,
      costPrice: map['cost_price'] is String
          ? double.tryParse(map['cost_price'].toString()) ?? 0.0
          : (map['cost_price'] as num?)?.toDouble() ?? 0.0,
      isChargedToDistributor: map['is_charged_to_distributor'] is String
          ? (map['is_charged_to_distributor'] == '1' || map['is_charged_to_distributor'] == 'true' ? 1 : 0)
          : (map['is_charged_to_distributor'] == 1 || map['is_charged_to_distributor'] == true ? 1 : 0),
      createdAt: map['created_at'],
      syncStatus: map['sync_status'] ?? 'pending',
      isDeleted: map['is_deleted'] == 1,
    );
  }
}
