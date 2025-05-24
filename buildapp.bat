@echo off
echo Running flutter clean...
flutter clean
if %errorlevel% neq 0 exit /b %errorlevel%

echo Running flutter pub get...
flutter pub get
if %errorlevel% neq 0 exit /b %errorlevel%

echo Building APK in debug mode...
flutter build apk --debug
if %errorlevel% neq 0 exit /b %errorlevel%

echo Opening WhatsApp...
start "" "C:\Users\%USERNAME%\AppData\Local\WhatsApp\WhatsApp.exe"

echo Done.
