# Build shared snappy.dll into lib/windows-amd64/.
# Requires: Visual Studio Build Tools (cmake/cl), curl.
# Usage: .\scripts\build-snappy.ps1
# Env: SNAPPY_VERSION (default 1.2.2), DEST_DIR (optional)
$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$SnappyVersion = if ($env:SNAPPY_VERSION) { $env:SNAPPY_VERSION } else { "1.2.2" }
$Os = "windows"
$Arch = "amd64"
$Out = if ($env:DEST_DIR) { $env:DEST_DIR } else { Join-Path $Root "lib\$Os-$Arch" }
$Build = Join-Path $Root "build\snappy-$SnappyVersion-$Os-$Arch"
$SrcTgz = Join-Path $Root "build\snappy-$SnappyVersion.tar.gz"
$SrcUrl = "https://github.com/google/snappy/archive/refs/tags/$SnappyVersion.tar.gz"

New-Item -ItemType Directory -Force -Path (Join-Path $Root "build") | Out-Null
New-Item -ItemType Directory -Force -Path $Out | Out-Null

if (-not (Test-Path $SrcTgz)) {
  Write-Host "==> download $SrcUrl"
  Invoke-WebRequest -Uri $SrcUrl -OutFile $SrcTgz
}

if (Test-Path $Build) { Remove-Item -Recurse -Force $Build }
New-Item -ItemType Directory -Force -Path $Build | Out-Null
tar -xzf $SrcTgz -C $Build --strip-components=1

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $vswhere) {
  $vsDevCmd = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
    -property installationPath
  if ($vsDevCmd) {
    $devCmd = Join-Path $vsDevCmd "Common7\Tools\VsDevCmd.bat"
    if (Test-Path $devCmd) {
      Write-Host "==> enter VS x64 env via VsDevCmd.bat"
      cmd /c "`"$devCmd`" -arch=amd64 -host_arch=amd64 && set" | ForEach-Object {
        if ($_ -match '^(.*?)=(.*)$') { Set-Item -Path "env:$($matches[1])" -Value $matches[2] }
      }
    }
  }
}

if (-not (Get-Command cmake -ErrorAction SilentlyContinue)) {
  throw "cmake not found"
}

$Prefix = Join-Path $Build "prefix"
$CmakeBuild = Join-Path $Build "build"

Write-Host "==> cmake/build snappy $SnappyVersion -> $Out"
cmake -S $Build -B $CmakeBuild `
  -DCMAKE_BUILD_TYPE=Release `
  -DCMAKE_INSTALL_PREFIX="$Prefix" `
  -DBUILD_SHARED_LIBS=ON `
  -DSNAPPY_BUILD_TESTS=OFF `
  -DSNAPPY_BUILD_BENCHMARKS=OFF `
  -DSNAPPY_INSTALL=ON
cmake --build $CmakeBuild --config Release -j
cmake --install $CmakeBuild --config Release

Write-Host "==> stage DLLs into $Out"
if (Test-Path $Out) { Remove-Item -Recurse -Force $Out }
New-Item -ItemType Directory -Force -Path $Out | Out-Null

$search = @(
  (Join-Path $Prefix "bin"),
  (Join-Path $Prefix "lib"),
  (Join-Path $CmakeBuild "Release"),
  $CmakeBuild
)
$names = @("snappy.dll", "libsnappy.dll")
$copied = $false
foreach ($dir in $search) {
  if (-not (Test-Path $dir)) { continue }
  foreach ($name in $names) {
    $src = Join-Path $dir $name
    if (Test-Path $src) {
      Copy-Item $src (Join-Path $Out "snappy.dll") -Force
      $copied = $true
      Write-Host "  copied $name -> snappy.dll"
      break
    }
  }
  if ($copied) { break }
}

if (-not $copied) {
  Get-ChildItem -Recurse $Prefix -Filter *.dll -ErrorAction SilentlyContinue | Format-Table FullName
  Get-ChildItem -Recurse $CmakeBuild -Filter *.dll -ErrorAction SilentlyContinue | Format-Table FullName
  throw "snappy.dll not found under $Prefix"
}

Write-Host "==> staged:"
Get-ChildItem $Out | Format-Table Name, Length
Write-Host "OK: snappy $SnappyVersion -> $Os/$Arch"
