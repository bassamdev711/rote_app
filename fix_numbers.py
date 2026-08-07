import os
import re

lib_dir = r"c:\hsap\roti_app\lib"

import_stmt = "import 'package:roti_app/core/utils/app_utils.dart';"

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    orig_content = content
    
    # Replace int.tryParse(...) -> AppUtils.tryParseInt(...)
    content = re.sub(r'int\.tryParse\(([^)]+)\)', r'AppUtils.tryParseInt(\1)', content)
    # Replace double.tryParse(...) -> AppUtils.tryParseDouble(...)
    content = re.sub(r'double\.tryParse\(([^)]+)\)', r'AppUtils.tryParseDouble(\1)', content)

    if content != orig_content:
        # Avoid importing app_utils in app_utils.dart itself
        if 'app_utils.dart' not in filepath:
            # Add import if missing
            # Need to adjust import path to be relative or use package:
            # In Flutter, 'package:YOUR_APP_NAME/...' is standard but let's see if there is another way.
            # We'll try to find the project name. It's usually roti_app. 
            # We'll use relative imports if possible. But since this is a quick script, we will just use the project root relative package import.
            # wait, let's use a relative import hack or assume 'package:roti_app/...' is fine if the app is named roti_app in pubspec.yaml.
            # I'll just use the relative one by computing depth!
            
            depth = filepath.replace(lib_dir, '').count(os.sep) - 1
            rel_prefix = '../' * depth if depth > 0 else './'
            rel_import = f"import '{rel_prefix}core/utils/app_utils.dart';"
            
            if "import 'package:" in content:
                # it's fine, we will just use relative
                pass
                
            if rel_import not in content:
                last_import = content.rfind("import '")
                if last_import != -1:
                    end_of_line = content.find('\n', last_import)
                    content = content[:end_of_line] + "\n" + rel_import + content[end_of_line:]
                else:
                    content = rel_import + "\n" + content
                    
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Modified: {filepath}")

for root, dirs, files in os.walk(lib_dir):
    for file in files:
        if file.endswith('.dart'):
            process_file(os.path.join(root, file))
