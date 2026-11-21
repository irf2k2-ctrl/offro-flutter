@echo off
REM OffrO - STAGING Android APK (Phase K). Run from the project ROOT (the folder that contains pubspec.yaml).
REM Staging backend + remote (published) Arabic translations ON. Never use this for a production build:
REM remote translations also require the exact staging API host, so they cannot activate against any other backend.
REM
REM If your usual flow needs the razorpay_flutter namespace patch after "pub get" (fix_razorpay.ps1), run it between
REM the two steps below, exactly as you do for your normal builds.

flutter pub get
IF ERRORLEVEL 1 EXIT /B 1

flutter build apk --release ^
  --dart-define=API_BASE_URL=https://offro-backend-staging-d375.up.railway.app ^
  --dart-define=ENABLE_REMOTE_TRANSLATIONS=true
IF ERRORLEVEL 1 EXIT /B 1

echo.
echo APK: build\app\outputs\flutter-apk\app-release.apk
