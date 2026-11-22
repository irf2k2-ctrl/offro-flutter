@echo off
REM OffrO - PRODUCTION Android APK with remote (published) Arabic translations ON.
REM Usage (from the project ROOT):  tools\build_production_apk.cmd https://<production-api-host>
REM
REM Run this ONLY after the go-live checklist (docs/GO_LIVE_TRANSLATIONS.md in the BACKEND repo) and after the owner has verified the production
REM host. The URL must be exactly the host in kRemoteProductionHost (lib/core/l10n/remote/remote_translation_config.dart);
REM with any other URL the app builds fine but remote translations stay OFF (fails safe).
REM
REM Keep your usual production signing and the razorpay_flutter namespace patch (fix_razorpay.ps1) steps exactly as you do today.

IF "%~1"=="" (
  echo Usage: tools\build_production_apk.cmd https://^<production-api-host^>
  EXIT /B 2
)

flutter pub get
IF ERRORLEVEL 1 EXIT /B 1

flutter build apk --release ^
  --dart-define=API_BASE_URL=%~1 ^
  --dart-define=ENABLE_REMOTE_TRANSLATIONS=true
IF ERRORLEVEL 1 EXIT /B 1

echo.
echo APK: build\app\outputs\flutter-apk\app-release.apk
