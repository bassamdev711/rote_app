import re

filepath = r"C:\hsap\roti_app\lib\views\main\home_screen.dart"

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace imports
content = content.replace("import '../license/license_guard.dart';", "import '../auth/auth_guard.dart';\nimport '../auth/login_screen.dart';")
content = content.replace("import '../license/license_info_screen.dart';", "")

# Replace LicenseGuard with AuthGuard
content = content.replace("LicenseGuard.run", "AuthGuard.run")

# Replace LicenseInfoScreen with LoginScreen in the header badge
content = content.replace("LicenseInfoScreen()", "LoginScreen()")

# Replace 'يتطلب ترخيصاً نشطاً' with 'يتطلب تسجيل الدخول'
content = content.replace("يتطلب ترخيصاً نشطاً", "يتطلب تسجيل الدخول")

# Replace 'محمي بالترخيص' with 'محمي بتسجيل الدخول'
content = content.replace("محمي بالترخيص", "محمي بتسجيل الدخول")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print("home_screen updated.")
