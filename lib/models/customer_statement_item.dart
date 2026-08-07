class CustomerStatementItem {
  final String id;
  final String type; // 'distribution', 'return', 'collection'
  final String? productId;
  final String? productName;
  final int? quantity;
  final double amount;
  final String createdAt;

  final String? updatedAt;
  final String? lastSyncedAt;
  final String? syncStatus;
  final bool? isDeleted;
  CustomerStatementItem({
    required this.id,
    required this.type,
    this.productId,
    this.productName,
    this.quantity,
    required this.amount,
    required this.createdAt,
    this.updatedAt,
    this.lastSyncedAt,
    this.syncStatus = 'pending',
    this.isDeleted = false,
  });

  bool get isDebt => type == 'distribution';
  bool get isCredit => type == 'collection' || type == 'return';
}
