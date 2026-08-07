import os
import re

repos_dir = r"C:\hsap\roti_app\lib\repositories"

def fix_insert(content):
    # Match Future<String> insert(Model m) async { ... }
    # Replace db.insert(...) with map = m.toMap(); id = map['id'] ?? Uuid().v4(); map['id']=id; db.insert(table, map); return id;
    
    pattern = r"Future<String>\s+insert\(\w+\s+(\w+)\)\s*async\s*\{\s*Database\s+db\s*=\s*await\s+_dbHelper\.database;\s*return\s+await\s+db\.insert\('([^']+)',\s*\1\.toMap\(\)\);\s*\}"
    
    def repl(m):
        var_name = m.group(1)
        table = m.group(2)
        return f"""Future<String> insert({var_name.__class__.__name__} {var_name}) async {{
    Database db = await _dbHelper.database;
    final map = {var_name}.toMap();
    final String id = map['id'] ?? const Uuid().v4();
    map['id'] = id;
    await db.insert('{table}', map);
    return id;
  }}"""
    
    # We need a more robust regex since Model type is needed
    pattern2 = r"Future<String>\s+insert\(([\w]+)\s+([\w]+)\)\s*async\s*\{\s*Database\s+db\s*=\s*await\s+_dbHelper\.database;\s*return\s+await\s+db\.insert\('([^']+)',\s*\2\.toMap\(\)\);\s*\}"
    
    def repl2(m):
        type_name = m.group(1)
        var_name = m.group(2)
        table = m.group(3)
        return f"""Future<String> insert({type_name} {var_name}) async {{
    Database db = await _dbHelper.database;
    final map = {var_name}.toMap();
    final String id = map['id'] ?? const Uuid().v4();
    map['id'] = id;
    await db.insert('{table}', map);
    return id;
  }}"""

    return re.sub(pattern2, repl2, content)

for filename in os.listdir(repos_dir):
    if not filename.endswith('.dart'): continue
    filepath = os.path.join(repos_dir, filename)
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    new_content = fix_insert(content)
    
    # fix loops for prices, products etc where txn.insert is used
    new_content = re.sub(
        r"await\s+txn\.insert\('([^']+)',\s*([\w]+)\.toMap\(\)\);",
        r"final map = \2.toMap(); map['id'] = map['id'] ?? const Uuid().v4(); await txn.insert('\1', map);",
        new_content
    )
    
    # For db.query we should probably filter out is_deleted = 1
    # db.query('table') -> db.query('table', where: 'is_deleted = 0')
    # but we'll keep it simple for now, maybe the app wants to see them or filter in UI. Better to filter here.
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(new_content)

print("Repos fixed for insert.")
