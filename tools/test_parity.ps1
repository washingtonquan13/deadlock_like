# Physics-engine parity run (design §12, §13.3 T33).
# Runs the headless test suite on Jolt (project default), then on GodotPhysics3D via a temporary
# override.cfg, which is always deleted afterwards. Exit code 0 only if both runs pass.
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\test_parity.ps1 [-Godot <path to console exe>] [-Filter <names>]
param(
    [string]$Godot = "D:\PortablePrograms\Godot_v4.4.1-stable_win64.exe\Godot_v4.4.1-stable_win64_console.exe",
    # Passed to the runner after "--" (run_tests.gd may ignore it). Default: the T33 subset.
    [string]$Filter = "T02,T03,T04,T05,T21,T22,T23,T24,T25"
)

$ErrorActionPreference = "Stop"
$ProjectDir = Split-Path -Parent $PSScriptRoot
$Override = Join-Path $ProjectDir "override.cfg"

if (-not (Test-Path $Godot)) {
    Write-Error "Godot console executable not found: $Godot"
    exit 2
}

function Invoke-Suite([string]$Label) {
    Write-Host "=== $Label ==="
    & $Godot --headless --path $ProjectDir --import | Out-Null
    & $Godot --headless --path $ProjectDir -s res://tests/run_tests.gd -- "--filter=$Filter" | Out-Host
    $code = $LASTEXITCODE
    Write-Host "=== $Label exit code: $code ==="
    return $code
}

if (Test-Path $Override) {
    Write-Error "override.cfg already exists in $ProjectDir; refusing to overwrite it."
    exit 2
}

$jolt = Invoke-Suite "Jolt Physics"
$godotPhysics = 1
try {
    Set-Content -Path $Override -Encoding utf8 -Value "[physics]`n`n3d/physics_engine=`"GodotPhysics3D`"`n"
    $godotPhysics = Invoke-Suite "GodotPhysics3D"
}
finally {
    if (Test-Path $Override) { Remove-Item $Override -Force -Confirm:$false }
}

if ($jolt -eq 0 -and $godotPhysics -eq 0) {
    Write-Host "PARITY PASS"
    exit 0
}
Write-Host "PARITY FAIL (jolt=$jolt, godot_physics=$godotPhysics)"
exit 1
