enum SyncStatus {
  pending,
  synced,
  failed
}

extension SyncStatusExtension on SyncStatus {
  String get name {
    switch (this) {
      case SyncStatus.pending:
        return 'pending';
      case SyncStatus.synced:
        return 'synced';
      case SyncStatus.failed:
        return 'failed';
    }
  }

  static SyncStatus fromString(String status) {
    switch (status) {
      case 'synced':
        return SyncStatus.synced;
      case 'failed':
        return SyncStatus.failed;
      case 'pending':
      default:
        return SyncStatus.pending;
    }
  }
}
