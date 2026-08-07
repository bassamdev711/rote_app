import os
import re

def fix_dist_tab():
    path = r"C:\hsap\roti_app\lib\views\distribution\tabs\distribution_tab.dart"
    with open(path, 'r', encoding='utf-8') as f: content = f.read()
    content = content.replace("d.quantity * d.price", "(d.quantity ?? 0) * d.price")
    content = content.replace("(qty - dist.quantity) : qty", "(qty - (dist.quantity ?? 0)) : qty")
    with open(path, 'w', encoding='utf-8') as f: f.write(content)

def fix_return_tab():
    path = r"C:\hsap\roti_app\lib\views\distribution\tabs\return_tab.dart"
    with open(path, 'r', encoding='utf-8') as f: content = f.read()
    content = content.replace("r.quantity * r.price", "(r.quantity ?? 0) * r.price")
    with open(path, 'w', encoding='utf-8') as f: f.write(content)

def fix_summary_tab():
    path = r"C:\hsap\roti_app\lib\views\distribution\tabs\summary_tab.dart"
    with open(path, 'r', encoding='utf-8') as f: content = f.read()
    content = content.replace("d.quantity.toDouble()", "(d.quantity ?? 0).toDouble()")
    content = content.replace("r.quantity.toDouble()", "(r.quantity ?? 0).toDouble()")
    content = content.replace("as String) + d.quantity", "as int) + (d.quantity ?? 0)")
    content = content.replace("as String) + r.quantity", "as int) + (r.quantity ?? 0)")
    content = content.replace("d.quantity * d.price", "(d.quantity ?? 0) * d.price")
    content = content.replace("r.quantity * r.price", "(r.quantity ?? 0) * r.price")
    content = content.replace("as String) > 0", "as int) > 0")
    with open(path, 'w', encoding='utf-8') as f: f.write(content)

def fix_supplier_products_screen():
    path = r"C:\hsap\roti_app\lib\views\settings\supplier_products_screen.dart"
    with open(path, 'r', encoding='utf-8') as f: content = f.read()
    content = content.replace("DropdownButtonFormField(", "DropdownButtonFormField<String>(")
    content = content.replace("DropdownMenuItem<int>", "DropdownMenuItem<String>")
    with open(path, 'w', encoding='utf-8') as f: f.write(content)

def fix_day_load_details_screen():
    path = r"C:\hsap\roti_app\lib\views\main\day_load_details_screen.dart"
    with open(path, 'r', encoding='utf-8') as f: content = f.read()
    content = content.replace("Map<String, String> productTotals", "Map<String, int> productTotals")
    content = content.replace("as String?) ?? 0", "as int?) ?? 0")
    with open(path, 'w', encoding='utf-8') as f: f.write(content)

fix_dist_tab()
fix_return_tab()
fix_summary_tab()
fix_supplier_products_screen()
fix_day_load_details_screen()

print("Fixed specific compilation errors.")
