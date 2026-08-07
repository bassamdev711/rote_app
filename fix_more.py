import os
import re
import codecs

roti_dir = r"C:\hsap\roti_app"

def remove_bom(filepath):
    try:
        with codecs.open(filepath, 'r', encoding='utf-8-sig') as f:
            content = f.read()
        with codecs.open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
    except Exception as e:
        pass

# 1. Fix backslashes in models
models_dir = os.path.join(roti_dir, r"lib\models")
for file in os.listdir(models_dir):
    if file.endswith('.dart'):
        filepath = os.path.join(models_dir, file)
        remove_bom(filepath)
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        if r"\'" in content:
            content = content.replace(r"\'", "'")
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
                
# 2. Fix customer_repository BOM
remove_bom(os.path.join(roti_dir, r"lib\repositories\customer_repository.dart"))

# 3. add_inventory_screen.dart
path_add_inv = os.path.join(roti_dir, r"lib\views\main\add_inventory_screen.dart")
with open(path_add_inv, 'r', encoding='utf-8') as f: c = f.read()
c = c.replace("Map<int, int> productTotals", "Map<String, int> productTotals")
with open(path_add_inv, 'w', encoding='utf-8') as f: f.write(c)

# 4. customers_screen.dart
path_cust = os.path.join(roti_dir, r"lib\views\customers\customers_screen.dart")
with open(path_cust, 'r', encoding='utf-8') as f: c = f.read()
c = c.replace("final int quantity = summary.quantity;", "final int quantity = summary.quantity ?? 0;")
with open(path_cust, 'w', encoding='utf-8') as f: f.write(c)

# 5. add_customer_screen.dart
path_add_cust = os.path.join(roti_dir, r"lib\views\customers\add_customer_screen.dart")
with open(path_add_cust, 'r', encoding='utf-8') as f: c = f.read()
c = c.replace("Map<int, TextEditingController>", "Map<String, TextEditingController>")
c = c.replace("productId: productId,", "productId: productId.toString(),") # if it's still expecting String but productId is int in some map loop
with open(path_add_cust, 'w', encoding='utf-8') as f: f.write(c)

# 6. supplier_products_screen.dart
path_supp = os.path.join(roti_dir, r"lib\views\settings\supplier_products_screen.dart")
with open(path_supp, 'r', encoding='utf-8') as f: c = f.read()
# Ensure DropdownButtonFormField is <String>
c = c.replace("DropdownButtonFormField(", "DropdownButtonFormField<String>(")
c = c.replace("DropdownMenuItem<int>", "DropdownMenuItem<String>")
c = c.replace("int? selectedProductId", "String? selectedProductId")
with open(path_supp, 'w', encoding='utf-8') as f: f.write(c)

print("Errors fixed.")
