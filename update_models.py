import os
import re

models_dir = r"C:\hsap\roti_app\lib\models"

sync_fields_decl = """  final String updatedAt;
  final String? lastSyncedAt;
  final String syncStatus;
  final bool isDeleted;"""

sync_fields_constructor = """    required this.updatedAt,
    this.lastSyncedAt,
    this.syncStatus = 'pending',
    this.isDeleted = false,"""

sync_fields_tomap = """      'updated_at': updatedAt,
      'last_synced_at': lastSyncedAt,
      'sync_status': syncStatus,
      'is_deleted': isDeleted ? 1 : 0,"""

sync_fields_frommap = """      updatedAt: map['updated_at'] ?? '',
      lastSyncedAt: map['last_synced_at'],
      syncStatus: map['sync_status'] ?? 'pending',
      isDeleted: map['is_deleted'] == 1,"""

sync_fields_copywith_params = """    String? updatedAt,
    String? lastSyncedAt,
    String? syncStatus,
    bool? isDeleted,"""

sync_fields_copywith_assign = """      updatedAt: updatedAt ?? this.updatedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      isDeleted: isDeleted ?? this.isDeleted,"""

for filename in os.listdir(models_dir):
    if not filename.endswith('.dart'): continue
    filepath = os.path.join(models_dir, filename)
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Change int? id to String? id or int customerId to String customerId
    content = re.sub(r'\bint\?\s+id\b', 'String? id', content)
    content = re.sub(r'\bint\s+customerId\b', 'String customerId', content)
    content = re.sub(r'\bint\s+productId\b', 'String productId', content)
    content = re.sub(r'\bint\s+supplierId\b', 'String supplierId', content)
    content = re.sub(r'\bint\s+workDayId\b', 'String workDayId', content)
    content = re.sub(r'\bint\?\s+customerId\b', 'String? customerId', content)
    content = re.sub(r'\bint\?\s+productId\b', 'String? productId', content)
    content = re.sub(r'\bint\?\s+supplierId\b', 'String? supplierId', content)
    content = re.sub(r'\bint\?\s+workDayId\b', 'String? workDayId', content)
    
    # 2. Add properties
    # Find the last final String or bool field before the constructor
    match = re.search(r'(final\s+\w+\??\s+\w+;)\s*(?=\n\s*\w+\()', content)
    if match:
        content = content[:match.end()] + '\n' + sync_fields_decl + content[match.end():]
        
    # 3. Add to constructor
    # Find the end of constructor parameters
    match = re.search(r'(required\s+this\.\w+|this\.\w+),?\s*(?=\}\);)', content)
    if match:
        content = content[:match.end()] + ',\n' + sync_fields_constructor + content[match.end():]
        
    # 4. Add to toMap
    match = re.search(r"('[\w_]+':\s*[\w]+(?:\s*\?\s*1\s*:\s*0)?),?\s*(?=\n\s*\};)", content)
    if match:
        content = content[:match.end()] + ',\n' + sync_fields_tomap + content[match.end():]
        
    # 5. Add to fromMap
    match = re.search(r"(\w+:\s*map\['[\w_]+'\](?:[^,\n]+)?),?\s*(?=\n\s*\);)", content)
    if match:
        content = content[:match.end()] + ',\n' + sync_fields_frommap + content[match.end():]
        
    # 6. Add to copyWith params
    match = re.search(r'(\w+\??\s+\w+),?\s*(?=\n\s*\}\)\s*\{)', content)
    if match:
        content = content[:match.end()] + ',\n' + sync_fields_copywith_params + content[match.end():]
        
    # 7. Add to copyWith assignments
    match = re.search(r'(\w+:\s*\w+\s*\?\?\s*this\.\w+),?\s*(?=\n\s*\);)', content)
    if match:
        content = content[:match.end()] + ',\n' + sync_fields_copywith_assign + content[match.end():]
        
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

print("Models updated.")
