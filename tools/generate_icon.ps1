# PowerShell helper: convert AVIF to PNG and place into assets for flutter_launcher_icons
# Usage: run from project root
# Requires ImageMagick's `magick` command on PATH (supports AVIF)

$src = "$env:USERPROFILE\Downloads\Icon.avif"
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$destDir = Join-Path $projectRoot "assets"
$destFile = Join-Path $destDir "app_icon.png"

if (-Not (Test-Path $src)) {
    Write-Error "Source icon not found: $src"
    exit 1
}

if (-Not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Path $destDir | Out-Null
}

# Try ImageMagick
$magick = Get-Command magick -ErrorAction SilentlyContinue
if ($magick) {
    Write-Host "Converting AVIF -> PNG using ImageMagick..."
    magick "$src" -resize 1024x1024 -background none -gravity center -extent 1024x1024 "$destFile"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "ImageMagick conversion failed"
        exit 2
    }
    Write-Host "Saved $destFile"
} else {
    Write-Error "ImageMagick (magick) not found on PATH. Please install ImageMagick or convert manually to assets/app_icon.png"
    exit 3
}

Write-Host "Now run: flutter pub get; flutter pub run flutter_launcher_icons:main; flutter build apk --release"