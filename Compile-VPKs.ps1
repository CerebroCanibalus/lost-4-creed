# ============================================================================
#  Lost 4 Creed - VPK Compiler v2.1
#  >> Build engine with live progress, Turbo Mode & incremental hashing
# ============================================================================

#requires -Version 5

#region ======================================================================
# CONFIGURACI N
# ============================================================================
$script:sourceDir  = "D:\Software\SourceStuff\addons"
$script:outputDir  = "D:\Software\SourceStuff\addons\compiled"
$script:vpkExe     = "D:\Program Files (x86)\Steam\steamapps\common\Left 4 Dead 2\bin\vpk.exe"
$script:cacheFile  = Join-Path $script:outputDir ".compile_cache.json"

# Lista completa (ordenados por dependencia aproximada)
$script:ALL_ADDONS = @(
    "l4cCoreAddon",                # Core   va primero
    "l4cCoreSurvivorGameplay",     # Survivor mechanics
    "l4cCoreVisuals",              # Shaders / visuals
    "l4cMapRefresh",               # Map refresh (props + events)
    "l4cCustomInfected",           # Custom SI
    "l4cInfectedGameplay",         # Infected AI
    "l4cInfectedReplacements",     # Infected replacements
    "l4cAmbienceCore",             # Ambiente
    "l4cAnimationsCore",           # Animaciones
    "l4cEnvironmentCore",          # Entorno
    "l4cHordeMusic",               # Horde music
    "l4cHudGUI",                   # HUD
    "l4cItemsGuns",                # Items / guns
    "l4cMusicCuesAndSounds",       # Music cues
    "l4cSurvivorsCast",            # Survivor models
    "l4cWeaponItemScripts",        # Weapon scripts
    "l4cWeaponSounds"              # Weapon sounds
)

# L mite de procesos simult neos   igual a n cleos. No saturar I/O.
$script:maxParallel = [math]::Max(1, [Environment]::ProcessorCount)

#endregion

#region ======================================================================
# FUNCIONES AUXILIARES
# ============================================================================

function Format-Time {
    param([double]$Seconds)
    if ($Seconds -lt 60) { return "$([math]::Round($Seconds, 1))s" }
    $m = [math]::Floor($Seconds / 60)
    $s = $Seconds % 60
    return "${m}m $([math]::Round($s, 0))s"
}

function Format-Bar {
    param([double]$Fraction, [int]$Width = 25)
    $f = [math]::Max(0, [math]::Min(1, $Fraction))
    $fill = [math]::Floor($f * $Width)
    $emp  = $Width - $fill
    return ("#" * $fill) + ("." * $emp)
}

#    Cache incremental: hash MD5 de todos los archivos del addon           
function Get-AddonHash {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    $parts = @()
    Get-ChildItem -Path $Path -Recurse -File |
        Where-Object { $_.FullName -notmatch '\\.git\\|\\\\node_modules\\\\' } |
        ForEach-Object { $parts += "$($_.Name):$($_.Length):$($_.LastWriteTimeUtc.Ticks)" }
    if ($parts.Count -eq 0) { return $null }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($parts -join '|')
    $hash  = [System.BitConverter]::ToString(
        [System.Security.Cryptography.MD5]::Create().ComputeHash($bytes)
    ) -replace '-', ''
    return $hash
}

function Load-Cache {
    if (Test-Path $script:cacheFile) {
        try {
            $obj = Get-Content $script:cacheFile -Raw | ConvertFrom-Json -ErrorAction Stop
            # Convert PSCustomObject to hashtable (PS5 compat)
            $ht = @{}
            $obj.PSObject.Properties | ForEach-Object { $ht[$_.Name] = $_.Value }
            return $ht
        } catch { return @{} }
    }
    return @{}
}

function Save-Cache {
    param($Cache)
    try {
        $dir = Split-Path $script:cacheFile -Parent
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $Cache | ConvertTo-Json -Compress | Set-Content $script:cacheFile -Force
    } catch { Write-Warning "Cache I/O error: $_" }
}

#    Windows Defender                                                      
function Test-DefenderExclusion {
    param([string]$Path)
    try {
        $pref = Get-MpPreference -ErrorAction Stop
        return @($pref.ExclusionPath) -contains $Path
    } catch { return $null }
}

function Request-DefenderExclusion {
    param([string]$Path)
    $title = ">> TURBO MODE   Excluir de Windows Defender?"
    $msg = @"
vpk.exe escanea MILES de archivos. Con Defender activo, CADA ARCHIVO
es inspeccionado individualmente   DUPLICANDO el tiempo de compilacion.

Carpeta: $Path

 Agregar exclusion? (Se requiere UAC)
"@
    $choice = $Host.UI.PromptForChoice($title, $msg, @("&Si, excluir", "&No"), 0)
    if ($choice -eq 0) {
        try {
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "powershell.exe"
            $psi.Arguments = "-Command Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoProfile -Command Add-MpPreference -ExclusionPath ''$Path'''"
            $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
            [void][System.Diagnostics.Process]::Start($psi)
            Write-Host "  [OK] Exclusion enviada (revisa UAC si esta detras de esta ventana)" -ForegroundColor Green
            return $true
        } catch { Write-Host "  [X] Error: $_" -ForegroundColor Red }
    }
    return $false
}

#endregion

#region ======================================================================
# BANNER
# ============================================================================

function Show-Banner {
    param([int]$TotalAddons, [int]$CachedCount)

    Clear-Host
    Write-Host "                                                                " -ForegroundColor Cyan
    Write-Host " " -NoNewline -ForegroundColor Cyan
    Write-Host "                        ######     #######                       " -NoNewline -ForegroundColor DarkCyan
    Write-Host " " -ForegroundColor Cyan
    Write-Host " " -NoNewline -ForegroundColor Cyan
    Write-Host "  ##         #    #  ##      ##  ##       ##                     " -NoNewline -ForegroundColor Cyan
    Write-Host " " -ForegroundColor Cyan
    Write-Host " " -NoNewline -ForegroundColor Cyan
    Write-Host "  ##          ####   ##      ##  ##       ##                     " -NoNewline -ForegroundColor Cyan
    Write-Host " " -ForegroundColor Cyan
    Write-Host " " -NoNewline -ForegroundColor Cyan
    Write-Host "  ##          ####   ##      ##  ##       ##                     " -NoNewline -ForegroundColor Cyan
    Write-Host " " -ForegroundColor Cyan
    Write-Host " " -NoNewline -ForegroundColor Cyan
    Write-Host "  ##         #    #  ##      ##  ##       #                      " -NoNewline -ForegroundColor Cyan
    Write-Host " " -ForegroundColor Cyan
    Write-Host " " -NoNewline -ForegroundColor Cyan
    Write-Host "                       ######     #######                        " -NoNewline -ForegroundColor Cyan
    Write-Host " " -ForegroundColor Cyan
    Write-Host " " -ForegroundColor Cyan
    Write-Host "   Lost 4 Creed  -  VPK Compiler v2.1" -ForegroundColor Cyan
    Write-Host "   $TotalAddons addons  -  >> Parallel ($script:maxParallel simultaneous)  -     Turbo Mode" -ForegroundColor Cyan

    # Optimizations status
    $defenderExcluded = Test-DefenderExclusion -Path $script:sourceDir
    if ($defenderExcluded -eq $true) {
        Write-Host "      Defender excluded  -     Cache: $CachedCount addons  -  >> FULL TURBO" -ForegroundColor Green
    } elseif ($defenderExcluded -eq $false) {
        Write-Host "     Defender ACTIVO (ralentiza 2x)  -     Cache: $CachedCount addons" -ForegroundColor Yellow
        Write-Host "     Usa -ExcludeFromDefender para activar TURBO MODE" -ForegroundColor DarkYellow
    } else {
        Write-Host "      Defender: no verifiable  -     Cache: $CachedCount addons" -ForegroundColor Gray
    }

    Write-Host "                                                                " -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Origen: $($script:sourceDir)" -ForegroundColor Gray
    Write-Host "  Salida: $($script:outputDir)" -ForegroundColor Gray
    Write-Host ""
}

#endregion

#region ======================================================================
# MEN 
# ============================================================================

function Show-Menu {
    param([array]$AvailableAddons)

    Write-Host "      Addons disponibles    " -ForegroundColor Cyan
    Write-Host "  " -NoNewline
    Write-Host "[0]" -NoNewline -ForegroundColor Green
    Write-Host("  TODOS ({0})" -f $AvailableAddons.Count) -ForegroundColor Green

    for ($i = 0; $i -lt $AvailableAddons.Count; $i++) {
        $num   = $i + 1
        $name  = $AvailableAddons[$i]
        $vpk   = Join-Path $script:outputDir "$name.vpk"
        if (Test-Path $vpk) {
            $size = [math]::Round((Get-Item $vpk).Length / 1MB, 2)
            $time = (Get-Item $vpk).LastWriteTime.ToString("HH:mm")
            Write-Host "  " -NoNewline
            Write-Host "[$num]" -NoNewline -ForegroundColor Green
            Write-Host "  $name" -NoNewline -ForegroundColor White
            Write-Host " [${size}MB @ ${time}]" -ForegroundColor DarkGray
        } else {
            Write-Host "  " -NoNewline
            Write-Host "[$num]" -NoNewline -ForegroundColor Gray
            Write-Host "  $name" -ForegroundColor DarkGray
        }
    }

    Write-Host ""
    Write-Host "  Flags:" -ForegroundColor Gray
    Write-Host "  " -NoNewline
    Write-Host "  -ExcludeFromDefender" -NoNewline -ForegroundColor Yellow
    Write-Host "  Agregar exclusion Windows Defender (TURBO, 1 vez)"
    Write-Host "  " -NoNewline
    Write-Host "  -Force" -NoNewline -ForegroundColor Yellow
    Write-Host "  Recompilar todo (ignorar cache)"
    Write-Host "  " -NoNewline
    Write-Host "  -NoBanner" -NoNewline -ForegroundColor Yellow
    Write-Host "  Sin logo ASCII (output limpio)"
    Write-Host ""

    return Read-Host "  Selecciona el numero del addon (0=todos, o varios ej: 1,3,5)"
}

#endregion

#region ======================================================================
# MAIN
# ============================================================================

#    Parse args                                                              
$autoExclude   = [bool]($args -contains '-ExcludeFromDefender')
$noIncremental = [bool](($args -contains '-Force') -or ($args -contains '-NoIncremental'))
$noBanner      = [bool]($args -contains '-NoBanner')

#    Pre-flight                                                              
if (-not (Test-Path $script:vpkExe)) {
    Write-Host "[ERROR] vpk.exe no encontrado:" -ForegroundColor Red
    Write-Host "  $($script:vpkExe)" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $script:outputDir)) {
    New-Item -ItemType Directory -Path $script:outputDir -Force | Out-Null
}

#    Filter available addons                                                
$availableAddons = $script:ALL_ADDONS | Where-Object {
    Test-Path (Join-Path $script:sourceDir $_)
}

if ($availableAddons.Count -eq 0) {
    Write-Host "[ERROR] No se encontraron carpetas de addons" -ForegroundColor Red
    exit 1
}

#    Load cache                                                              
$cache = Load-Cache
$cachedCount = @($cache.Keys | Where-Object { $_ -in $availableAddons }).Count

#    Banner                                                                  
if (-not $noBanner) { Show-Banner -TotalAddons $availableAddons.Count -CachedCount $cachedCount }
Write-Host ""

#    Defender auto-exclusion                                                
$defenderExcluded = Test-DefenderExclusion -Path $script:sourceDir
if ($defenderExcluded -eq $false -and $autoExclude) {
    Request-DefenderExclusion -Path $script:sourceDir
    Start-Sleep 1
}

#    Menu                                                                    
$selection = Show-Menu -AvailableAddons $availableAddons

$selectedAddons = @()
if ($selection -eq "0") {
    $selectedAddons = $availableAddons
    Write-Host ""
    Write-Host "    Compilando TODOS ($($selectedAddons.Count))..." -ForegroundColor Green
} else {
    $nums = $selection -split ',' | ForEach-Object { $_.Trim() }
    foreach ($ns in $nums) {
        $n = 0
        if ([int]::TryParse($ns, [ref]$n) -and $n -ge 1 -and $n -le $availableAddons.Count) {
            $selectedAddons += $availableAddons[$n - 1]
        } else { Write-Host "    Numero invalido: $ns" -ForegroundColor Yellow }
    }
    $selectedAddons = $selectedAddons | Sort-Object -Unique
    if ($selectedAddons.Count -eq 0) {
        Write-Host "  [ERROR] Ningun addon valido seleccionado." -ForegroundColor Red; exit 1
    }
    Write-Host ""
    Write-Host "  Addons: $($selectedAddons -join ', ')" -ForegroundColor Cyan
}
Write-Host ""

#    Build job list                                                          
$jobs = @()
foreach ($addon in $selectedAddons) {
    $ap   = Join-Path $script:sourceDir $addon
    $svpk = Join-Path $script:sourceDir "$addon.vpk"
    $ovpk = Join-Path $script:outputDir "$addon.vpk"
    if (Test-Path $svpk) { Remove-Item $svpk -Force }

    $skip = $false
    if (-not $noIncremental) {
        $curHash = Get-AddonHash -Path $ap
        $cached  = $cache[$addon]
        if ($curHash -and $cached -and $curHash -eq $cached -and (Test-Path $ovpk)) {
            $sz = [math]::Round((Get-Item $ovpk).Length / 1MB, 2)
            $skip = $true
        }
    }

    $jobs += [PSCustomObject]@{
        Addon     = $addon
        Status    = if ($skip) { 'skipped' } else { 'queued' }
        Hash      = if ($skip) { $null } else { $curHash }
        StartTime = $null
        EndTime   = $null
        Process   = $null
        SourceVpk = $svpk
        OutputVpk = $ovpk
        SizeMB    = if ($skip) { $sz } else { 0 }
    }
}

#    Print initial status                                                   
$skipCount  = ($jobs | Where-Object Status -eq 'skipped').Count
$buildCount = ($jobs | Where-Object Status -ne 'skipped').Count
Write-Host "     Jobs: $($jobs.Count) total" -ForegroundColor White
if ($skipCount -gt 0) {
    Write-Host "    Cache hit: $skipCount (skipped)" -ForegroundColor DarkGray
}
Write-Host "  >> Max parallel: $script:maxParallel" -ForegroundColor DarkCyan
if ($noIncremental) {
    Write-Host "  >> Incremental: OFF (Force)" -ForegroundColor Yellow
}
Write-Host ""

#    Execution                                                               
$script:compileStart = Get-Date
$progressId = 1

# This is the main loop   launch and monitor
$done = $false
while (-not $done) {
    $now   = Get-Date
    $done  = $true

    # 1. Check completed processes
    $completed = 0
    foreach ($j in $jobs) {
        if ($j.Status -eq 'building' -and $j.Process.HasExited) {
            $j.EndTime = $now
            $elapsed   = ($j.EndTime - $j.StartTime).TotalSeconds

            # Move VPK
            if (Test-Path $j.SourceVpk) {
                try { Move-Item $j.SourceVpk $j.OutputVpk -Force -ErrorAction Stop } catch {
                    try { Copy-Item $j.SourceVpk $j.OutputVpk -Force } catch {}
                }
            }

            if (Test-Path $j.OutputVpk) {
                $j.SizeMB = [math]::Round((Get-Item $j.OutputVpk).Length / 1MB, 2)
                $j.Status = 'ok'
                Write-Host "  $([char]0x2714) $($j.Addon)" -NoNewline -ForegroundColor Green
                Write-Host "  $([math]::Round($elapsed,1))s" -NoNewline -ForegroundColor Gray
                Write-Host "  $($j.SizeMB)MB" -ForegroundColor DarkGray
                if ($j.Hash) { $cache[$j.Addon] = $j.Hash }
            } else {
                $j.Status = 'error'
                Write-Host "  $([char]0x2718) $($j.Addon)" -NoNewline -ForegroundColor Red
                Write-Host "  exit code $($j.Process.ExitCode)" -ForegroundColor Gray
            }
        }

        if ($j.Status -eq 'building' -or $j.Status -eq 'queued') { $done = $false }
    }

    # 2. Launch new processes (with throttle)
    $activeCount = ($jobs | Where-Object Status -eq 'building').Count
    if ($activeCount -lt $script:maxParallel) {
        $queued = $jobs | Where-Object Status -eq 'queued'
        $slots  = $script:maxParallel - $activeCount
        foreach ($q in $queued) {
            if ($slots -le 0) { break }
            $q.Status    = 'building'
            $q.StartTime = $now
            $q.Process = Start-Process -FilePath $script:vpkExe `
                -ArgumentList "`"$($q.Addon)`"" `
                -WorkingDirectory $script:sourceDir `
                -PassThru -WindowStyle Hidden
            #    Boost priority   I/O bound, less scheduling latency = more disk throughput
            try { $q.Process.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::High } catch {}
            Write-Host "  $([char]0x25B6) $($q.Addon) ..." -ForegroundColor Yellow
            $slots--
        }
    }

    # 3. Progress bar via Write-Progress
    $doneCount    = ($jobs | Where-Object { $_.Status -in @('ok','error','skipped') }).Count
    $totalCount   = $jobs.Count
    $fraction     = if ($totalCount -gt 0) { $doneCount / $totalCount } else { 0 }
    $elapsedTotal = ($now - $script:compileStart).TotalSeconds

    # ETA estimation
    $eta = ""
    if ($doneCount -gt 0 -and $fraction -gt 0.05) {
        $rate = $elapsedTotal / $doneCount
        $remaining = $totalCount - $doneCount
        $etaSecs = [math]::Round($rate * $remaining, 0)
        $eta = "  ETA: $(Format-Time -Seconds $etaSecs)"
    }

    $buildingNames = ($jobs | Where-Object Status -eq 'building' | ForEach-Object {
        $s = [math]::Round(($now - $_.StartTime).TotalSeconds, 1)
        "$($_.Addon) (${s}s)"
    }) -join ', '

    $statusLine = "$doneCount/$totalCount  -  $(Format-Time -Seconds $elapsedTotal)${eta}"
    if ($buildingNames) { $statusLine += "  -  Building: $buildingNames" }

    Write-Progress -Activity "Compiling VPKs" -Status $statusLine -PercentComplete ($fraction * 100) -Id $progressId

    if (-not $done) { Start-Sleep -Milliseconds 300 }
}

Write-Progress -Activity "Compiling VPKs" -Completed -Id $progressId
Write-Host ""

#    Save cache                                                              
Save-Cache -Cache $cache

#    Summary                                                                 
$okCount    = ($jobs | Where-Object Status -eq 'ok').Count
$errCount   = ($jobs | Where-Object Status -eq 'error').Count
$skipCount  = ($jobs | Where-Object Status -eq 'skipped').Count
$totalTime  = [math]::Round(((Get-Date) - $script:compileStart).TotalSeconds, 1)

Write-Host "                                                                " -ForegroundColor Cyan
Write-Host " " -NoNewline -ForegroundColor Cyan
Write-Host "                         R E S U M E N                      " -NoNewline -ForegroundColor Cyan
Write-Host " " -ForegroundColor Cyan
Write-Host "                                                                " -ForegroundColor Cyan
Write-Host ("   Seleccionados: {0,-36} " -f $jobs.Count) -ForegroundColor Cyan
Write-Host ("   Compilados:    {0,-36} " -f $okCount) -ForegroundColor Green
if ($skipCount -gt 0) { Write-Host ("   Cache:         {0,-36} " -f $skipCount) -ForegroundColor DarkGray }
Write-Host ("   Fallos:        {0,-36} " -f $errCount) -ForegroundColor $(if ($errCount -gt 0) { 'Red' } else { 'Green' })
Write-Host ("   Tiempo total:  {0,-36} " -f $(Format-Time -Seconds $totalTime)) -ForegroundColor Cyan

#    Timing sparklines   
$timed = $jobs | Where-Object { $_.EndTime } | Sort-Object { $_.EndTime - $_.StartTime }
if ($timed.Count -gt 0) {
    $maxT = ($timed | ForEach-Object { ($_.EndTime - $_.StartTime).TotalSeconds } | Measure-Object -Maximum).Maximum
    Write-Host "                                                                " -ForegroundColor Cyan
    Write-Host "   Times:" -ForegroundColor DarkCyan
    foreach ($t in $timed) {
        $sec   = ($t.EndTime - $t.StartTime).TotalSeconds
        $nBars = [math]::Max(1, [math]::Min(28, [math]::Floor(($sec / $maxT) * 28)))
        $bars  = "#" * $nBars
        Write-Host ("   {0,-30} {1} {2,5}s " -f $t.Addon, $bars.PadRight(28), [math]::Round($sec, 1)) -ForegroundColor Cyan
    }
}

Write-Host "                                                                " -ForegroundColor Cyan

#    Tips   
if ($errCount -gt 0) {
    Write-Host ""
    Write-Host "    Algunos addons fallaron. Usa Compile-VPKs-Debug.ps1 para diagnosticar." -ForegroundColor Yellow
}
$defenderNow = Test-DefenderExclusion -Path $script:sourceDir
if ($defenderNow -eq $false) {
    Write-Host ""
    Write-Host "  >> MEJORA: Ejecuta con '-ExcludeFromDefender' para DUPLICAR velocidad:" -ForegroundColor Yellow
    Write-Host "    .\Compile-VPKs.ps1 -ExcludeFromDefender" -ForegroundColor DarkYellow
    Write-Host "  (requiere admin, solo 1 vez)" -ForegroundColor DarkGray
}
if (-not $noBanner) {
    Write-Host ""
    Write-Host "  Los VPKs estan en: $($script:outputDir)" -ForegroundColor Cyan
}
Write-Host "  $(Format-Time -Seconds $totalTime)" -ForegroundColor Cyan
Read-Host "  Presiona Enter para salir"
