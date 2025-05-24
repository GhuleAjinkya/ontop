@echo off
echo Running flutter clean...
call flutter clean
if %errorlevel% neq 0 exit /b %errorlevel%

echo Running flutter pub get...
call flutter pub get
if %errorlevel% neq 0 exit /b %errorlevel%

echo Building APK in debug mode...
call flutter build apk --debug
if %errorlevel% neq 0 exit /b %errorlevel%

echo Opening .apk folder...
explorer "%cd%\build\app\outputs\flutter-apk"

echo Done.
pause
