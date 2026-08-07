class Customer {
  final String? id;
  final String name;
  final String? neighborhood;
  final String? phone;
  final String? notes;
  final String createdAt;

  final String? updatedAt;
  final String? lastSyncedAt;
  final String? syncStatus;
  final bool? isDeleted;
  Customer({
    this.id,
    required this.name,
    this.neighborhood,
    this.phone,
    this.notes,
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
      'neighborhood': neighborhood,
      'phone': phone,
      'notes': notes,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'last_synced_at': lastSyncedAt,
      'sync_status': syncStatus,
      'is_deleted': (isDeleted ?? false) ? 1 : 0,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'],
      name: map['name'],
      neighborhood: map['neighborhood'],
      phone: map['phone'],
      notes: map['notes'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'] ?? '',
      lastSyncedAt: map['last_synced_at'],
      syncStatus: map['sync_status'] ?? 'pending',
      isDeleted: map['is_deleted'] == 1,
    );
  }

  Customer copyWith({
    String? id,
    String? name,
    String? neighborhood,
    String? phone,
    String? notes,
    String? createdAt,
    String? updatedAt,
    String? lastSyncedAt,
    String? syncStatus,
    bool? isDeleted,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      neighborhood: neighborhood ?? this.neighborhood,
      phone: phone ?? this.phone,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
