import os
import re

repos_dir = r"C:\hsap\roti_app\lib\repositories"

for filename in os.listdir(repos_dir):
    if not filename.endswith('.dart'): continue
    filepath = os.path.join(repos_dir, filename)
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Import uuid if not imported
    if "import 'package:uuid/uuid.dart';" not in content:
        content = "import 'package:uuid/uuid.dart';\n" + content

    # Replace Future<int> insert(Model m) with Future<String> insert(Model m)
    content = re.sub(r'Future<int>\s+insert\(', r'Future<String> insert(', content)
    
    # Replace int customerId to String customerId
    content = re.sub(r'\bint\s+customerId\b', 'String customerId', content)
    content = re.sub(r'\bint\s+productId\b', 'String productId', content)
    content = re.sub(r'\bint\s+supplierId\b', 'String supplierId', content)
    content = re.sub(r'\bint\s+workDayId\b', 'String workDayId', content)
    content = re.sub(r'\bint\s+id\b', 'String id', content)
    
    # Delete: update the query to soft delete instead of delete
    # This is tricky because it depends on the table name.
    # Let's replace: db.delete('table', where: 'id = ?', whereArgs: [id])
    # With: db.update('table', {'is_deleted': 1, 'sync_status': 'pending', 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id])
    def replace_delete(match):
        table = match.group(1)
        where = match.group(2)
        args = match.group(3)
        return f"await db.update({table}, {{'is_deleted': 1, 'sync_status': 'pending', 'updated_at': DateTime.now().toIso8601String()}}, where: {where}, whereArgs: {args})"

    content = re.sub(r"await\s+db\.delete\(\s*('[^']+')\s*,\s*where:\s*([^,]+)\s*,\s*whereArgs:\s*([^)]+)\)", replace_delete, content)

    # In update method: need to inject updated_at and sync_status = pending.
    # But usually it's model.toMap() which already has them. We just need to make sure the model passed has the updated fields.
    # We will leave update as is, because the model should be updated before passing to repo.

    # Fix return types for insert
    # return await db.insert(...) -> await db.insert(...); return model.id; 
    # But model.id might be null before insert. 
    # This is better done manually for each repo if it's complex, but let's try a regex for simple cases:
    # "return await db.insert('customers', customer.toMap());"
    # -> "final id = Uuid().v4(); final map = customer.toMap(); map['id'] = id; await db.insert('customers', map); return id;"

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

print("Repos updated partially.")
