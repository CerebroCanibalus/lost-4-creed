# Lost 4 Creed - VPK Compiler (DEBUG)
# Version para ver errores de vpk.exe

$sourceDir = "D:\Software\SourceStuff\addons"
$outputDir = "D:\Software\SourceStuff\addons\compiled"
$vpkExe = "D:\Program Files (x86)\Steam\steamapps\common\Left 4 Dead 2\bin\vpk.exe"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  VPK Compiler - DEBUG MODE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Verificar vpk.exe
if (-not (Test-Path $vpkExe)) {
    Write-Host "[ERROR] No se encontro vpk.exe" -ForegroundColor Red
    exit 1
}

# Crear carpeta de salida
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

Write-Host "Probando con un solo addon..." -ForegroundColor Yellow
Write-Host ""

# Probar con el primero
$testFolder = "l4cCoreAddon"
$folderPath = Join-Path $sourceDir $testFolder

Write-Host "Folder: $folderPath" -ForegroundColor Gray
Write-Host "Existe: $(Test-Path $folderPath)" -ForegroundColor Gray
Write-Host ""

# Metodo 1: WorkingDirectory = sourceDir, argumento = nombre del folder
Write-Host "[METODO 1] vpk.exe create $testFolder" -ForegroundColor Cyan
Write-Host "WorkingDirectory: $sourceDir" -ForegroundColor Gray

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $vpkExe
$psi.Arguments = "create `"$testFolder`""
$psi.WorkingDirectory = $sourceDir
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.UseShellExecute = $false

$proc = [System.Diagnostics.Process]::Start($psi)
$stdout = $proc.StandardOutput.ReadToEnd()
$stderr = $proc.StandardError.ReadToEnd()
$proc.WaitForExit()

Write-Host "Exit code: $($proc.ExitCode)" -ForegroundColor $(if ($proc.ExitCode -eq 0) { "Green" } else { "Red" })
if ($stdout) { Write-Host "STDOUT: $stdout" -ForegroundColor Gray }
if ($stderr) { Write-Host "STDERR: $stderr" -ForegroundColor Red }
Write-Host ""

# Si se creo, moverlo
$vpkCreated = Join-Path $sourceDir "$testFolder.vpk"
if (Test-Path $vpkCreated) {
    Write-Host "[OK] VPK creado en: $vpkCreated" -ForegroundColor Green
    Move-Item $vpkCreated $outputDir -Force
    Write-Host "[OK] Movido a: $outputDir" -ForegroundColor Green
} else {
    Write-Host "[ERROR] No se creo el VPK" -ForegroundColor Red
}

Write-Host ""
Read-Host "Presiona Enter para salir"
