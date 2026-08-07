@echo off
echo =======================================================
echo     Building Secure Release APK (Obfuscated)
echo =======================================================

echo.
echo Cleaning old builds...
call flutter clean

echo.
echo Fetching dependencies...
call flutter pub get

echo.
echo Building APK with Obfuscation...
call flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols

echo.
echo =======================================================
echo Build complete. The APK is located at:
echo build\app\outputs\flutter-apk\app-release.apk
echo =======================================================
pause
