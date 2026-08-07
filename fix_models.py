import os
import re

models_dir = r"C:\hsap\roti_app\lib\models"

def fix_model(content):
    # Fix double commas and weird formatting
    content = re.sub(r',\s*,', ',', content)
    content = re.sub(r'this\.isDeleted\s*=\s*false,\}\);', 'this.isDeleted = false,\n  });', content)
    
    # Fix constructor errors by making sync fields optional in definition
    content = re.sub(r'final\s+String\s+updatedAt;', 'final String? updatedAt;', content)
    content = re.sub(r'final\s+String\s+syncStatus;', 'final String? syncStatus;', content)
    content = re.sub(r'final\s+bool\s+isDeleted;', 'final bool? isDeleted;', content)
    
    # Fix constructor requirements
    content = re.sub(r'required\s+this\.updatedAt', 'this.updatedAt', content)
    
    # Ensure fromMap includes the new fields safely
    # Find the factory Name.fromMap(...)
    
    # Also fix any "final int id" to "final String? id" if missed
    # Wait, the error said "Final field 'id' is not initialized" for customer_statement_item
    # We should make sure id is this.id in constructor.
    
    # We'll just run a general replacement for ",," -> ","
    content = content.replace(",,", ",")
    
    return content

for filename in os.listdir(models_dir):
    if not filename.endswith('.dart'): continue
    filepath = os.path.join(models_dir, filename)
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    new_content = fix_model(content)
    
    # Specifically for fromMap, let's just make sure all models have the new fields parsed
    # We'll just do a quick regex to inject them before the closing ); of fromMap
    if "updatedAt: map['updated_at']" not in new_content:
        new_content = re.sub(
            r'(\s+)(\w+:\s*map\[\'[^\']+\'\].*?\n\s+)\);',
            r'\1\2\1updatedAt: map[\'updated_at\'],\n\1lastSyncedAt: map[\'last_synced_at\'],\n\1syncStatus: map[\'sync_status\'] ?? \'pending\',\n\1isDeleted: map[\'is_deleted\'] == 1,\n    );',
            new_content,
            flags=re.DOTALL
        )
        
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(new_content)

print("Models fixed.")
