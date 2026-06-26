$baseDir = "$env:USERPROFILE\.pub-cache\hosted\[pub.dev](https://pub.dev)"
$razorpayDir = $null

@("razorpay_flutter-1.3.5","razorpay_flutter-1.3.6","razorpay_flutter-1.3.4") | ForEach-Object {
    $candidate = "$baseDir\$_\android"
    if ((Test-Path $candidate) -and ($razorpayDir -eq $null)) { $razorpayDir = $candidate }
}

if ($razorpayDir -eq $null) {
    $found = Get-ChildItem -Path $baseDir -Filter "razorpay_flutter*" -Directory -ErrorAction SilentlyContinue
    if ($found) { $razorpayDir = "$($found[0].FullName)\android" }
}

$buildFile = "$razorpayDir\build.gradle"
$content = Get-Content $buildFile -Raw
if ($content -match "namespace") { Write-Host "Already patched." -ForegroundColor Green; exit 0 }
$patched = $content -replace '(?m)^(\s*android\s*\{)', "`$1`n    namespace `"com.razorpay`""
Set-Content -Path $buildFile -Value $patched -Encoding UTF8
Write-Host "SUCCESS: razorpay_flutter patched!" -ForegroundColor Green
