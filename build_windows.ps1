param (
    [switch]$Run
)

$ErrorActionPreference = "Stop"

$VS2022_CMAKE = "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
$BUILD_DIR = "build/windows"
$WINDOWS_DIR = "windows"
$EXE_PATH = "$BUILD_DIR\runner\Release\gistx.exe"

if (-not (Test-Path $VS2022_CMAKE)) {
    Write-Error "Visual Studio 2022 CMake not found at $VS2022_CMAKE"
}

Write-Host "Generating build files for Visual Studio 2022..."
if (-not (Test-Path $BUILD_DIR)) {
    New-Item -ItemType Directory -Force -Path $BUILD_DIR | Out-Null
}

Push-Location $WINDOWS_DIR
& $VS2022_CMAKE -G "Visual Studio 17 2022" -B "../$BUILD_DIR" .
if ($LASTEXITCODE -ne 0) {
    Pop-Location
    Write-Error "CMake generation failed."
}
Pop-Location

Write-Host "Building Release configuration..."
& $VS2022_CMAKE --build $BUILD_DIR --config Release --target INSTALL
if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed."
}

Write-Host "Build successful! Executable located at: $EXE_PATH"

if ($Run) {
    Write-Host "Starting application..."
    Start-Process -FilePath $EXE_PATH
}
