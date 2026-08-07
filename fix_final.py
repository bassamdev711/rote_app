import os
import re

roti_dir = r"C:\hsap\roti_app"
lib_dir = os.path.join(roti_dir, "lib")

def fix_all():
    for root, dirs, files in os.walk(lib_dir):
        for file in files:
            if not file.endswith('.dart'): continue
            path = os.path.join(root, file)
            with open(path, 'r', encoding='utf-8') as f:
                c = f.read()
            original = c
            
            # 1. Models isDeleted ? 1 : 0 => (isDeleted ?? false) ? 1 : 0
            c = c.replace("isDeleted ? 1 : 0", "(isDeleted ?? false) ? 1 : 0")
            
            # 2. Transaction Repo: quantity as String => quantity as int?
            if 'transaction_repository.dart' in file:
                c = c.replace("m['quantity'] as String", "m['quantity'] as int?")
                c = c.replace("Map<int, double> distQtyMap", "Map<String, double> distQtyMap")
                c = c.replace("Map<int, double> distRevenueMap", "Map<String, double> distRevenueMap")
                c = c.replace("Map<int, double> retQtyMap", "Map<String, double> retQtyMap")
                c = c.replace("Map<int, List> loadsByProduct", "Map<String, List> loadsByProduct")
                c = c.replace("Map<int, Map<String, int>> results", "Map<String, Map<String, int>> results")
                c = c.replace("Map<int, Map<String, dynamic>> results", "Map<String, Map<String, dynamic>> results")
                
            # 3. Models: (map['cost_price'] as String).toDouble() => (map['cost_price'] as num).toDouble()
            c = c.replace("(map['cost_price'] as String).toDouble()", "(map['cost_price'] as num).toDouble()")
            
            # 4. Providers
            if 'customer_provider.dart' in file:
                c = c.replace("family<CustomerBalanceSummary, int>", "family<CustomerBalanceSummary, String>")
            if 'product_provider.dart' in file:
                c = c.replace("family<List<SupplierProduct>, int>", "family<List<SupplierProduct>, String>")
                c = c.replace("supplierProductsProvider(supplierId)", "supplierProductsProvider(supplierId.toString())") # fallback

            # 5. Add Inventory Screen productTotals Map<String, String> -> Map<String, int>
            if 'add_inventory_screen.dart' in file:
                c = c.replace("Map<String, String> productTotals", "Map<String, int> productTotals")
            
            # 6. Supplier Products Screen Dropdown fixes
            if 'supplier_products_screen.dart' in file:
                c = c.replace("DropdownMenuItem<int>", "DropdownMenuItem<String>")
                
            if c != original:
                with open(path, 'w', encoding='utf-8') as f:
                    f.write(c)

fix_all()
print("All final fixes applied.")
