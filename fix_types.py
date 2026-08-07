import os
import re

lib_dir = r"C:\hsap\roti_app\lib"

# Pairs of regex and replacement
replacements = [
    # workDayId
    (r'\bint\s+workDayId', 'String workDayId'),
    (r'\bint\?\s+workDayId', 'String? workDayId'),
    (r'\bint\s+get\s+_effectiveWorkDayId', 'String get _effectiveWorkDayId'),
    (r'\bint\?\s+get\s+_effectiveWorkDayId', 'String? get _effectiveWorkDayId'),
    
    # customerId
    (r'\bint\s+customerId', 'String customerId'),
    (r'\bint\?\s+customerId', 'String? customerId'),
    
    # supplierId
    (r'\bint\s+supplierId', 'String supplierId'),
    (r'\bint\?\s+supplierId', 'String? supplierId'),
    
    # productId
    (r'\bint\s+productId', 'String productId'),
    (r'\bint\?\s+productId', 'String? productId'),
    (r'\bint\?\s+selectedProductId', 'String? selectedProductId'),
    
    # DropdownMenuItem
    (r'DropdownMenuItem<int>', 'DropdownMenuItem<String>'),
    
    # Map types
    (r'Map<int,\s*String>', 'Map<String, String>'),
    (r'Map<int,\s*Map', 'Map<String, Map'),
    
    # General ID in functions
    (r'\bint\s+id', 'String id'),
    
    # Casting
    (r'as\s+int\b', 'as String'),
]

def fix_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
        
    new_content = content
    for pattern, repl in replacements:
        new_content = re.sub(pattern, repl, new_content)
        
    # specific fix for customer_statement_item.dart which still had "final int id" according to logs
    if "final int id;" in new_content:
        new_content = new_content.replace("final int id;", "final String? id;")
    if "final int quantity;" in new_content:
        new_content = new_content.replace("final int quantity;", "final int? quantity;")
        
    if new_content != content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
            
for root, dirs, files in os.walk(lib_dir):
    for file in files:
        if file.endswith('.dart'):
            fix_file(os.path.join(root, file))

print("Types fixed.")
