class SupplierPayment {
  final String? id;
  final String supplierId;
  final double amount;
  final String type; // 'تسديد نقدي' or 'ديون إغلاق يوم'
  final String? workDayId;
  final String? notes;
  final String createdAt;

  final String? updatedAt;
  final String? lastSyncedAt;
  final String? syncStatus;
  final bool? isDeleted;

  SupplierPayment({
    this.id,
    required this.supplierId,
    required this.amount,
    required this.type,
    this.workDayId,
    this.notes,
    required this.createdAt,
    this.updatedAt,
    this.lastSyncedAt,
    this.syncStatus = 'pending',
    this.isDeleted = false,
  });

  SupplierPayment copyWith({
    String? id,
    String? supplierId,
    double? amount,
    String? type,
    String? workDayId,
    String? notes,
    String? createdAt,
    String? updatedAt,
    String? lastSyncedAt,
    String? syncStatus,
    bool? isDeleted,
  }) {
    return SupplierPayment(
      id: id ?? this.id,
      supplierId: supplierId ?? this.supplierId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      workDayId: workDayId ?? this.workDayId,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'supplier_id': supplierId,
      'amount': amount,
      'type': type,
      'work_day_id': workDayId,
      'notes': notes,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'last_synced_at': lastSyncedAt,
      'sync_status': syncStatus,
      'is_deleted': (isDeleted ?? false) ? 1 : 0,
    };
  }

  factory SupplierPayment.fromMap(Map<String, dynamic> map) {
    return SupplierPayment(
      id: map['id'],
      supplierId: map['supplier_id'],
      amount: (map['amount'] as num).toDouble(),
      type: map['type'],
      workDayId: map['work_day_id'],
      notes: map['notes'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'] ?? '',
      lastSyncedAt: map['last_synced_at'],
      syncStatus: map['sync_status'] ?? 'pending',
      isDeleted: map['is_deleted'] == 1,
    );
  }
}
