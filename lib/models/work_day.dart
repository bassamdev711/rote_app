class WorkDay {
  final String? id;
  final String date;
  final bool isClosed;
  final String createdAt;
  final String? closedAt;

  final String? updatedAt;
  final String? lastSyncedAt;
  final String? syncStatus;
  final bool? isDeleted;
  WorkDay({
    this.id,
    required this.date,
    this.isClosed = false,
    required this.createdAt,
    this.closedAt,
    this.updatedAt,
    this.lastSyncedAt,
    this.syncStatus = 'pending',
    this.isDeleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'is_closed': isClosed ? 1 : 0,
      'created_at': createdAt,
      'closed_at': closedAt,
      'updated_at': updatedAt,
      'last_synced_at': lastSyncedAt,
      'sync_status': syncStatus,
      'is_deleted': (isDeleted ?? false) ? 1 : 0,
    };
  }

  factory WorkDay.fromMap(Map<String, dynamic> map) {
    return WorkDay(
      id: map['id'],
      date: map['date'],
      isClosed: map['is_closed'] == 1,
      createdAt: map['created_at'],
      closedAt: map['closed_at'],
      updatedAt: map['updated_at'] ?? '',
      lastSyncedAt: map['last_synced_at'],
      syncStatus: map['sync_status'] ?? 'pending',
      isDeleted: map['is_deleted'] == 1,
    );
  }

  WorkDay copyWith({
    String? id,
    String? date,
    bool? isClosed,
    String? createdAt,
    String? closedAt,
    String? updatedAt,
    String? lastSyncedAt,
    String? syncStatus,
    bool? isDeleted,
  }) {
    return WorkDay(
      id: id ?? this.id,
      date: date ?? this.date,
      isClosed: isClosed ?? this.isClosed,
      createdAt: createdAt ?? this.createdAt,
      closedAt: closedAt ?? this.closedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
