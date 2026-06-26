# ================================================================
# OFFRO — Release APK Build Script
# Run from: D:\projects\Offro  (project ROOT, not android folder)
# ================================================================

Write-Host "=== OFFRO Release Build ===" -ForegroundColor Cyan

# Step 1: Set Java
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:Path = "$env:JAVA_HOME\bin;$env:Path"

# Step 2: Boost Dart AOT memory (prevents OOM during snapshot generation)
$env:DART_VM_OPTIONS = "--old_gen_heap_size=2048"

# Step 3: Ensure asset folders exist (pubspec references them)
$assetDirs = @("assets", "assets\onboarding")
foreach ($dir in $assetDirs) {
    if (!(Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "  Created: $dir" -ForegroundColor Yellow
    }
}

# Step 4: Fix razorpay_flutter namespace (required every time after pub get)
$razorpayBuild = "$env:LOCALAPPDATA\..\Roaming\Pub\Cache\hosted\pub.dev\razorpay_flutter-1.3.5\android\build.gradle"
if (!(Test-Path $razorpayBuild)) {
    # Try alternate location
    $razorpayBuild = (Get-ChildItem -Path "$env:USERPROFILE\.pub-cache" -Recurse -Filter "build.gradle" -ErrorAction SilentlyContinue | 
        Where-Object { $_.FullName -like "*razorpay_flutter*" } | 
        Select-Object -First 1).FullName
}
if ($razorpayBuild -and (Test-Path $razorpayBuild)) {
    $rContent = Get-Content $razorpayBuild -Raw
    if ($rContent -notmatch 'namespace') {
        $rContent = $rContent -replace "(android\s*\{)", "`$1`n    namespace `"com.razorpay`""
        Set-Content -Path $razorpayBuild -Value $rContent
        Write-Host "  Patched razorpay_flutter namespace" -ForegroundColor Green
    }
}

# Step 5: Clean old build artifacts
Write-Host "`nStep 1/4: Cleaning build cache..." -ForegroundColor Cyan
flutter clean

# Step 6: Get dependencies
Write-Host "`nStep 2/4: Getting dependencies..." -ForegroundColor Cyan
flutter pub get

# Step 7: Patch razorpay again (pub get may have reset it)
if ($razorpayBuild -and (Test-Path $razorpayBuild)) {
    $rContent = Get-Content $razorpayBuild -Raw
    if ($rContent -notmatch 'namespace') {
        $rContent = $rContent -replace "(android\s*\{)", "`$1`n    namespace `"com.razorpay`""
        Set-Content -Path $razorpayBuild -Value $rContent
        Write-Host "  Re-patched razorpay_flutter namespace after pub get" -ForegroundColor Green
    }
}

# Step 8: Build release APK
Write-Host "`nStep 3/4: Building release APK..." -ForegroundColor Cyan
Set-Location android
.\gradlew.bat assembleRelease --no-daemon --max-workers=2
Set-Location ..

# Step 9: Show result
$apkPath = "build\app\outputs\flutter-apk\app-release.apk"
if (Test-Path $apkPath) {
    $size = (Get-Item $apkPath).Length / 1MB
    Write-Host "`n✅ BUILD SUCCESS!" -ForegroundColor Green
    Write-Host "   APK: $apkPath" -ForegroundColor Green
    Write-Host "   Size: $([math]::Round($size, 1)) MB" -ForegroundColor Green
} else {
    Write-Host "`n❌ Build failed — check output above" -ForegroundColor Red
}
