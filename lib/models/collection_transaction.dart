class CollectionTransaction {
  final String? id;
  final String workDayId;
  final String customerId;
  final double amount;
  final String createdAt;

  final String? updatedAt;
  final String? lastSyncedAt;
  final String? syncStatus;
  final bool? isDeleted;
  CollectionTransaction({
    this.id,
    required this.workDayId,
    required this.customerId,
    required this.amount,
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
      'amount': amount,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'last_synced_at': lastSyncedAt,
      'sync_status': syncStatus,
      'is_deleted': (isDeleted ?? false) ? 1 : 0,
    };
  }

  factory CollectionTransaction.fromMap(Map<String, dynamic> map) {
    return CollectionTransaction(
      id: map['id'],
      workDayId: map['work_day_id'],
      customerId: map['customer_id'],
      amount: map['amount'] is String
          ? double.tryParse(map['amount'].toString()) ?? 0.0
          : (map['amount'] as num?)?.toDouble() ?? 0.0,
      createdAt: map['created_at'],
      updatedAt: map['updated_at'] ?? '',
      lastSyncedAt: map['last_synced_at'],
      syncStatus: map['sync_status'] ?? 'pending',
      isDeleted: map['is_deleted'] == 1,
    );
  }

  CollectionTransaction copyWith({
    String? id,
    String? workDayId,
    String? customerId,
    double? amount,
    String? createdAt,
    String? updatedAt,
    String? lastSyncedAt,
    String? syncStatus,
    bool? isDeleted,
  }) {
    return CollectionTransaction(
      id: id ?? this.id,
      workDayId: workDayId ?? this.workDayId,
      customerId: customerId ?? this.customerId,
      amount: amount ?? this.amount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
