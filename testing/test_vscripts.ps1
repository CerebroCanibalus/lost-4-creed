# ==============================================================================
# L4D2 VScript Comprehensive Test Runner v5.0
# Validates VScripts from ALL addons with L4D2-specific edge cases
# Updated for MaoLib v2026 (Fase 1-3), native wrappers, and systemic patterns
# ==============================================================================

param(
    [switch]$Verbose,
    [switch]$CheckIncludes,
    [switch]$CheckSyntax,
    [switch]$CheckThinkers,
    [switch]$CheckEvents,
    [switch]$CheckConflicts,
    [switch]$CheckEdgeCases,
    [switch]$SimulateLoad,
    [switch]$CheckMaoLib,
    [switch]$CheckTimers,
    [switch]$CheckNatives,
    [switch]$CheckClosures,
    [switch]$FullTest
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [Text.Encoding]::UTF8

# ==============================================================================
# CONFIGURATION
# ==============================================================================
$basePath = "D:\Software\SourceStuff\addons"

$folders = @(
    "l4cCoreAddon\scripts\vscripts",
    "l4cCoreSurvivorGameplay\scripts\vscripts",
    "l4cWeaponItemScripts\scripts\vscripts",
    "l4cInfectedGameplay\scripts\vscripts",
    "l4cCustomInfected\scripts\vscripts",
    "l4cInfectedReplacements\scripts\vscripts",
    "l4cCoreVisuals\scripts\vscripts",
    "l4cHordeMusic\scripts\vscripts",
    "l4cItemsGuns\scripts\vscripts",
    "l4cMapRefresh\scripts\vscripts",
    "l4cEnvironmentCore\scripts\vscripts",
    "l4cHudGUI\scripts\vscripts"
)

# VSLib-only functions (will cause runtime errors in L4D2 native)
$vslibOnlyFunctions = @(
    'Utils\.CreateEntities',
    'VSLib\.',
    'include\s*\(\s*"vslib'
)

# Deprecated/problematic functions (MaoLib v2026 removed these)
$deprecatedFunctions = @(
    'GetEntityByHandle',
    'GetGameTime',
    'EntFire\s*\(',
    'SetVelocity\s*\(',
    'compilestring',           # Fase 1: compilestring RCE removed
    'DelayCall\s*\(\s*"',      # Fase 1: DelayCall no longer accepts string
    'DelayCallOpt\s*\(\s*"',    # Fase 1: DelayCallOpt no longer accepts string
    'AddThinkToEnt',           # Rule: NEVER use, use MaoLib.AddTimer
    'logic_timer',             # Entity-based timer - prefer MaoLib.AddTimer
    'DoUniqueString'           # Doesn't exist in L4D2
)

# Risky patterns in callbacks
$riskyPatterns = @{
    'SpawnEntityFromTable in event' = 'event.*SpawnEntityFromTable|SpawnEntityFromTable.*event'
    'EntFire in callback' = 'EntFire\s*\([^)]*\)'
    'AmbientGeneric in callback' = 'SpawnEntityFromTable\s*\(\s*"ambient_generic"'
    'env_explosion spawn in loop' = 'loop.*env_explosion|env_explosion.*loop'
}

# ==============================================================================
# L4D2 VALID GAME EVENTS (265 events)
# ==============================================================================
$validGameEvents = @(
    'ability_out_of_range','ability_use','achievement_earned','achievement_write_failed',
    'adrenaline_used','ammo_pack_used','ammo_pack_used_fail_doesnt_use_ammo','ammo_pack_used_fail_full',
    'ammo_pack_used_fail_no_weapon','ammo_pickup','ammo_pile_weapon_cant_use_ammo','area_cleared',
    'award_earned','begin_scavenge_overtime','boomer_exploded','boomer_near',
    'bot_player_replace','break_breakable','break_prop','bullet_impact',
    'c1m4_scavenge_instructions','chair_charged','charger_carry_end','charger_carry_start',
    'charger_charge_end','charger_charge_start','charger_impact','charger_killed',
    'charger_pummel_end','charger_pummel_start','checkpoint_door_open','choke_begin',
    'choke_end','choke_start','choke_stopped','create_panic_event',
    'dead_survivor_visible','defibrillator_begin','defibrillator_interrupted','defibrillator_used',
    'defibrillator_used_fail','difficulty_changed','door_close','door_moving',
    'door_open','door_unlock','drag_begin','drag_end',
    'entered_spit','entity_shoved','entity_visible','explain_*',
    'explain_burger_sign','explain_c1m4_finale','explain_c2m4_ticketbooth','explain_c3m4_radio1',
    'explain_c3m4_radio2','explain_c3m4_rescue','explain_c6m3_finale','explain_carousel_button',
    'explain_carousel_destination','explain_gates_are_open','explain_gun_shop','explain_gun_shop_tanker',
    'explain_hotel_elevator_doors','explain_return_item','explain_save_items','explain_sewer_gate',
    'explain_sewer_run','explain_stage_finale_start','explain_stage_lighting','explain_stage_pyrotechnics',
    'explain_stage_survival_start','explain_store_alarm','explain_store_item','explain_store_item_stop',
    'explain_survival_alarm','explain_survival_carousel','explain_survival_generic','explain_survival_radio',
    'explain_vehicle_arrival','explosion','fatal_vomit','final_reportscreen',
    'finale_bridge_lowering','finale_escape_start','finale_radio_damaged','finale_radio_start',
    'finale_rush','finale_start','finale_vehicle_incoming','finale_vehicle_leaving',
    'finale_vehicle_ready','finale_win','fire_ignite','foot_locker_opened',
    'friendly_fire','gameinstructor_*','gascan_*','gauntlet_finale_start',
    'ghost_spawn_time','give_weapon','golden_crowbar_pickup','grenade_bounce',
    'heal_begin','heal_end','heal_interrupted','heal_success',
    'hegrenade_detonate','horde_alert','hostname_changed','hunter_headshot',
    'hunter_punched','infected_death','infected_decapitated','infected_hurt',
    'infected_shoved','item_pickup','jockey_headshot','jockey_killed',
    'jockey_punched','jockey_ride','jockey_ride_end','lunge_pounce',
    'lunge_shove','m60_streak_ended','map_transition','melee_kill',
    'mission_complete','mission_lost','mob_spawn','molotov_thrown',
    'mounted_gun_overheated','mounted_gun_start','nav_blocked','nav_generate',
    'non_melee_fired','non_pistol_fired','panic_event_finished','pills_used',
    'pills_used_fail','pipe_bomb_thrown','player_afk','player_blind',
    'player_blocked','player_bot_replace','player_chat','player_connect',
    'player_death','player_disconnect','player_entered_checkpoint','player_entered_start_area',
    'player_falldamage','player_first_spawn','player_footstep','player_hurt',
    'player_hurt_concise','player_incapacitated','player_incapacitated_start','player_jump',
    'player_jump_apex','player_land','player_ledge_grab','player_ledge_release',
    'player_left_checkpoint','player_left_safe_area','player_left_start_area','player_no_longer_it',
    'player_now_it','player_say','player_shoved','player_spawn',
    'player_talking_state','player_team','player_transitioned','player_use',
    'pounce_attempt_stopped','pounce_begin','pounce_end','pounce_stopped',
    'punched_clown','receive_upgrade','relocated','request_weapon_stats',
    'rescue_door_open','respawning','revive_begin','revive_end',
    'revive_interrupted','revive_success','round_end','round_end_message',
    'round_freeze_end','round_start','round_start_post_nav','round_start_pre_entity',
    'scavenge_*','scavenge_gas_can_destroyed','set_instructor_group_enabled','smoker_choke',
    'smoker_tongue_broken','song_played','spawner_give_item','spec_target_updated',
    'spit_burst','spitter_killed','start_score_animation','stashwhacker_game_won',
    'success_checkpoint_button_used','survival_at_10min','survival_at_30min','survival_round_start',
    'survivor_call_for_help','survivor_rescue_abandoned','survivor_rescued','tank_frustrated',
    'tank_killed','tank_rock_killed','tank_spawn','temp_c4m1_getgas',
    'temp_c4m3_return_to_boat','tongue_broke_bent','tongue_broke_victim_died','tongue_grab',
    'tongue_pull_stopped','tongue_release','total_ammo_below_40','triggered_car_alarm',
    'triggered_car_alarm_cancel','upgrade_explosive_ammo','upgrade_failed_no_primary','upgrade_incendiary_ammo',
    'upgrade_item_already_used','upgrade_pack_added','upgrade_pack_begin','upgrade_pack_used',
    'use_target','versus_*','versus_marker_reached','vomit_bomb_tank',
    'vomitjar_thrown','vote_cast_no','vote_cast_yes','vote_changed',
    'vote_ended','vote_failed','vote_passed','vote_started',
    'waiting_checkpoint_button_used','waiting_checkpoint_door_used','waiting_door_used_versus','weapon_drop',
    'weapon_drop_to_prop','weapon_fire','weapon_fire_at_40','weapon_fire_on_empty',
    'weapon_given','weapon_pickup','weapon_reload','weapon_spawn_visible',
    'weapon_zoom','witch_harasser_set','witch_killed','witch_spawn',
    'zombie_ignited'
)

# ==============================================================================
# MAOLIB v2026 MODULES & THEIR IncludeScript NAMES
# ==============================================================================
$maoLibModules = @{
    'MaoLib\.'           = 'maolib'
    'MaoLib_VFX\.'       = 'maolib_vfx'
    'MaoLib\.NavUtils\.' = 'maolib_navutils'
    'MaoLib\.Input\.'    = 'maolib_input'
    'MaoLib\.PlayerState\.' = 'maolib_state'
    'MaoLib\.Cooldowns\.' = 'maolib_cooldowns'
    'MaoLib\.HUD\.'      = 'maolib_hud'
    'MaoLib\.Modifiers\.' = 'maolib_modifiers'
    'MaoLib\.AoE\.'      = 'maolib_aoe'
    'MaoLib\.StatusEffects\.' = 'maolib_status'
    'MaoLib\.Mapper\.'   = 'maolib_mapper'
}

# Native METHODS (entity.Method()) - should NEVER be called as global functions
$nativeMethods = @(
    'IsPlayer','IsValid','GetHealth','GetOrigin','Kill','EyePosition','EyeAngles',
    'GetForwardVector','GetModelName','DispatchSpawn','EnableDraw','DisableDraw',
    'SetParent','entindex','GetClassname','GetVelocity','SetVelocity','GetScriptScope',
    'ConnectOutput','DisconnectOutput','TakeDamage','Stagger','ApplyDamage',
    'ApplyDamageEx','OverrideEntityFriction','SetEntityContext','GetEntityContext',
    'SetEntityContextNum','PrecacheModel','PrecacheSound','GetEntityCenter',
    'IsSurvivor','IsPlayerOnFire','IsPlayerStaggering','IsPlayerHanging',
    'IsPlayerDominated','IsPlayerIT','IsPlayerAdrenalineActive',
    'GetPlayerAliveDuration','GetPlayerHealthBuffer','GetPlayerActiveWeapon',
    'GetPlayerButtons','IsButtonPressed','StaggerPlayer','UseAdrenaline',
    'SetPlayerHealthBuffer','GetPlayerZombieType','GivePlayerItem','GivePlayerUpgrade',
    'GivePlayerAmmo','VomitPlayer','ExtinguishPlayer','RevivePlayer','DefibPlayer'
)

# Native GLOBALS (function(entity)) - should NEVER be called as methods
$nativeGlobals = @(
    'IsPlayerABot','EntIndexToHScript','GetPlayerFromUserID','Time','UniqueString',
    'SpawnEntityFromTable','SpawnEntityGroupFromTable','PrecacheEntityFromTable'
)

# ==============================================================================
# VSCRIPT COMMENT FILTER (reduces false positives in regex analysis)
# ==============================================================================
function Remove-VScriptComments {
    param([string]$content)
    if (-not $content) { return "" }
    # Remove block comments /* ... */ (non-greedy, across lines)
    $content = [regex]::Replace($content, '/\*.*?\*/', '', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    # Remove line comments // ... (to end of line)
    $content = [regex]::Replace($content, '//.*$', '', [System.Text.RegularExpressions.RegexOptions]::Multiline)
    return $content
}

# ==============================================================================
# OUTPUT HELPERS
# ==============================================================================
function Write-Status($msg, $type) {
    switch ($type) {
        "info"    { $color = "White" }
        "success" { $color = "Green" }
        "warning" { $color = "Yellow" }
        "error"   { $color = "Red" }
        "header"  { $color = "Cyan" }
        "critical"{ $color = "Magenta" }
        default   { $color = "White" }
    }
    Write-Host $msg -ForegroundColor $color
}

function Write-Detail($msg, $indent = 2) {
    $prefix = "  " * $indent
    Write-Host "$prefix$msg" -ForegroundColor DarkGray
}

# ==============================================================================
# RESULTS TRACKING
# ==============================================================================
$results = @{
    TotalFiles = 0
    SyntaxErrors = 0
    MissingIncludes = 0
    ThinkerIssues = 0
    EventConflicts = 0
    GlobalConflicts = 0
    ConvarConflicts = 0
    FunctionConflicts = 0
    EdgeCaseIssues = 0
    VSLibUsage = 0
    DeprecatedUsage = 0
    EntityLeakRisks = 0
    CallstackErrors = 0
    CallstackWarnings = 0
    LLMErrors = 0
    LLMWarnings = 0
    LoadingCrash = 0
    RuntimeCrash = 0
    DependencyIssues = 0
    MaoLibIssues = 0
    TimerIssues = 0
    NativeMisuse = 0
    ClosureIssues = 0
    InvalidEvents = 0
    Details = @()
}

# ==============================================================================
# LOAD ALL SCRIPTS
# ==============================================================================
Write-Status "`n=== L4D2 VScript Comprehensive Test Runner v5.0 ===" "header"
Write-Status "Base path: $basePath" "info"
Write-Status "MaoLib v2026 validation enabled" "info"

$allScripts = @()
$scriptContents = @{}  # Name -> Content
$scriptPaths = @{}     # Name -> FullPath
$scriptAddons = @{}    # Name -> Addon

foreach ($folder in $folders) {
    $fullPath = Join-Path $basePath $folder
    if (Test-Path $fullPath) {
        $scripts = Get-ChildItem -Path $fullPath -Filter "*.nut" -File -Recurse | Where-Object {
            $path = $_.FullName
            # Exclude reference code and backup scripts
            -not ($path -match '\\referencias\\') -and
            -not ($path -match '_backup_old_scripts') -and
            -not ($path -match '\\archived_')
        }
        $allScripts += $scripts
        foreach ($s in $scripts) {
            $scriptContents[$s.BaseName] = Get-Content $s.FullName -Raw -ErrorAction SilentlyContinue
            $scriptPaths[$s.BaseName] = $s.FullName
            $scriptAddons[$s.BaseName] = ($folder -split '\\')[0]
        }
        Write-Status "  $($scripts.Count) scripts in $folder" "success"
    } else {
        Write-Status "  MISSING: $folder" "error"
    }
}

$results.TotalFiles = $allScripts.Count
Write-Status "`nTotal VScripts found: $($results.TotalFiles)" "header"

$addonScriptCounts = @{}
foreach ($folder in $folders) {
    $addonName = ($folder -split '\\')[0]
    $fullPath = Join-Path $basePath $folder
    if (Test-Path $fullPath) {
        $count = @(Get-ChildItem -Path $fullPath -Filter "*.nut" -File -Recurse).Count
        $addonScriptCounts[$addonName] = $count
    } else {
        $addonScriptCounts[$addonName] = 0
    }
}
foreach ($addon in ($addonScriptCounts.Keys | Sort-Object)) {
    Write-Host ("    {0,-30} {1,3} scripts" -f $addon, $addonScriptCounts[$addon])
}
Write-Host ""

$addonTotals = @{}
foreach ($addon in $addonScriptCounts.Keys) {
    $addonTotals[$addon] = @{ Criticals = 0; Warnings = 0 }
}

if ($results.TotalFiles -eq 0) {
    Write-Status "No scripts found! Exiting." "error"
    exit 1
}

$allScriptNames = $scriptContents.Keys | Sort-Object -Unique

$fileStats = @{}
foreach ($name in $allScriptNames) {
    $fileStats[$name] = @{ Criticals = 0; Warnings = 0; Addon = $scriptAddons[$name] }
}

# Helper to track per-file stats
function Track-Issue($scriptName, $severity) {
    if (-not $fileStats[$scriptName]) {
        $fileStats[$scriptName] = @{ Criticals = 0; Warnings = 0; Addon = $scriptAddons[$scriptName] }
    }
    if ($severity -eq "CRITICAL") {
        $fileStats[$scriptName].Criticals++
    } else {
        $fileStats[$scriptName].Warnings++
    }
}

# ==============================================================================
# TEST 1: SYNTAX VALIDATION (Enhanced)
# ==============================================================================
if ($CheckSyntax -or $FullTest) {
    Write-Status "`n[TEST 1] Enhanced Syntax Validation..." "info"

    foreach ($scriptName in $scriptContents.Keys) {
        $content = $scriptContents[$scriptName]
        if (-not $content) { continue }

        $issues = @()
        $cleanContent = $content -replace '"[^"]*"', '""' -replace "'[^']*'", "''"
        $openBraces = ([regex]::Matches($cleanContent, '\{')).Count
        $closeBraces = ([regex]::Matches($cleanContent, '\}')).Count
        if ($openBraces -ne $closeBraces) {
            $issues += "Unmatched braces: $openBraces open vs $closeBraces close"
        }
        $openParens = ([regex]::Matches($cleanContent, '\(')).Count
        $closeParens = ([regex]::Matches($cleanContent, '\)')).Count
        if ($openParens -ne $closeParens) {
            $issues += "Unmatched parens: $openParens open vs $closeParens close"
        }
        $openBrackets = ([regex]::Matches($cleanContent, '\[')).Count
        $closeBrackets = ([regex]::Matches($cleanContent, '\]')).Count
        if ($openBrackets -ne $closeBrackets) {
            $issues += "Unmatched brackets: $openBrackets open vs $closeBrackets close"
        }
        $allQuotes = ([regex]::Matches($content, '"')).Count
        if ($allQuotes % 2 -ne 0) {
            $issues += "Odd number of quotes - potential unclosed string"
        }
        $mlStrings = [regex]::Matches($content, '@"')
        $mlStringsEnd = [regex]::Matches($content, '"@')
        if ($mlStrings.Count -ne $mlStringsEnd.Count) {
            $issues += 'Unclosed multiline string (@" "@)'
        }
        $blockComments = [regex]::Matches($content, '/\*|\*/')
        if ($blockComments.Count % 2 -ne 0) {
            $issues += 'Unclosed block comment (/* */)'
        }
        $lines = $content -split "`n"
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i].Trim()
            if ($line -match '^return\s+[^;]+$' -and $line -notmatch '[{}]$') {
                $issues += "Line $($i+1): return without semicolon may cause issues"
                break
            }
        }

        if ($issues.Count -gt 0) {
            $results.SyntaxErrors++
            if ($Verbose) {
                Write-Status "  SYNTAX: $scriptName" "error"
                foreach ($issue in $issues) { Write-Detail $issue 2 }
            }
        }
    }
    Write-Status "  Syntax errors: $($results.SyntaxErrors)" $(if ($results.SyntaxErrors -eq 0) { "success" } else { "warning" })
}

# ==============================================================================
# TEST 2: THINKER ANALYSIS (CRITICAL)
# ==============================================================================
if ($CheckThinkers -or $FullTest) {
    Write-Status "`n[TEST 2] Thinker Entity Analysis..." "info"
    Write-Status "  Detecting AddThinkToEnt, logic_timer, info_target thinkers, entity leaks..." "info"

    $thinkerIssues = @()

    foreach ($scriptName in $scriptContents.Keys) {
        $content = $scriptContents[$scriptName]
        if (-not $content) { continue }

        $addThinkMatches = [regex]::Matches($content, 'AddThinkToEnt\s*\(')
        if ($addThinkMatches.Count -gt 0) {
            $thinkerIssues += @{
                Script = $scriptName
                Type = "WARNING"
                Issue = "AddThinkToEnt used - native but overwrites previous think on same entity. Use MaoLib.AddTimer instead."
                Count = $addThinkMatches.Count
            }
            $results.ThinkerIssues++
        }

        $timerMatches = [regex]::Matches($content, 'SpawnEntityFromTable\s*\(\s*"logic_timer"')
        if ($timerMatches.Count -gt 0) {
            $hasRoundEnd = $content -match 'round_end|mission_lost|round_start'
            $hasCleanup = $content -match 'Kill.*logic_timer|Remove.*timer|cleanup.*timer'
            if (-not $hasCleanup) {
                $thinkerIssues += @{
                    Script = $scriptName
                    Type = "WARNING"
                    Issue = "logic_timer spawned without cleanup mechanism (entity leak risk)"
                    Count = $timerMatches.Count
                }
                $results.EntityLeakRisks++
            }
            $results.ThinkerIssues++
        }

        $infoTargetMatches = [regex]::Matches($content, 'SpawnEntityFromTable\s*\(\s*"info_target"')
        if ($infoTargetMatches.Count -gt 0) {
            $hasCleanup = $content -match 'Kill.*info_target|Remove.*info_target'
            if (-not $hasCleanup) {
                $thinkerIssues += @{
                    Script = $scriptName
                    Type = "WARNING"
                    Issue = "info_target spawned without cleanup (entity leak risk)"
                    Count = $infoTargetMatches.Count
                }
                $results.EntityLeakRisks++
            }
        }

        $scheduleMatches = [regex]::Matches($content, 'Schedule\s*\(')
        if ($scheduleMatches.Count -gt 0) {
            $hasStopFlag = $content -match 'bActive|bRunning|bEnabled|round_end|mission_lost'
            if (-not $hasStopFlag) {
                $thinkerIssues += @{
                    Script = $scriptName
                    Type = "WARNING"
                    Issue = 'Schedule() used without apparent stop flag (potential infinite loop)'
                    Count = $scheduleMatches.Count
                }
                $results.ThinkerIssues++
            }
        }

        $createMatches = [regex]::Matches($content, 'CreateEntity|SpawnEntityFromTable\s*\(\s*"')
        if ($createMatches.Count -gt 0) {
            $entityTypes = @()
            $entityMatch = [regex]::Matches($content, 'SpawnEntityFromTable\s*\(\s*"([^"]+)"')
            foreach ($m in $entityMatch) { $entityTypes += $m.Groups[1].Value }
            $hasCleanup = $content -match 'Kill\s*\(|DoEntFire.*Kill|AcceptEntityInput.*Kill'
            $persistentTypes = @("env_explosion", "ambient_generic", "info_target", "logic_timer", "point_hurt")
            $spawnedPersistent = $entityTypes | Where-Object { $persistentTypes -contains $_ }
            if ($spawnedPersistent -and -not $hasCleanup) {
                $thinkerIssues += @{
                    Script = $scriptName
                    Type = "WARNING"
                    Issue = "Spawns persistent entities ($($spawnedPersistent -join ', ')) without cleanup"
                    Count = $spawnedPersistent.Count
                }
                $results.EntityLeakRisks++
            }
        }

        $loopSpawnPattern = '(for|foreach|while).*\{[^}]*SpawnEntityFromTable|SpawnEntityFromTable[^;]*;[^;]*SpawnEntityFromTable'
        if ($content -match $loopSpawnPattern) {
            $thinkerIssues += @{
                Script = $scriptName
                Type = "CRITICAL"
                Issue = "Spawning entities inside loops (EDICT overflow risk)"
                Count = 1
            }
            $results.ThinkerIssues++
        }
    }

    if ($thinkerIssues.Count -gt 0) {
        Write-Status "  Thinker/Entity issues: $($thinkerIssues.Count)" "warning"
        if ($Verbose) {
            foreach ($issue in $thinkerIssues) {
                $color = if ($issue.Type -eq "CRITICAL") { "Red" } else { "Yellow" }
                Write-Host "    [$($issue.Type)] $($issue.Script): $($issue.Issue)" -ForegroundColor $color
            }
        }
    } else {
        Write-Status "  No thinker issues detected!" "success"
    }
}

# ==============================================================================
# TEST 3: EVENT CALLBACK CONFLICTS + VALID EVENT CHECK
# ==============================================================================
if ($CheckEvents -or $FullTest) {
    Write-Status "`n[TEST 3] Event Callback Analysis..." "info"
    Write-Status "  Detecting __CollectGameEventCallbacks ambiguities, OnGameEvent_ conflicts, invalid events..." "info"

    $eventCallbacks = @{}
    $collectCallbacks = @{}
    $invalidEvents = @()

    foreach ($scriptName in $scriptContents.Keys) {
        $content = $scriptContents[$scriptName]
        if (-not $content) { continue }

        $collectMatches = [regex]::Matches($content, '__CollectGameEventCallbacks\s*\(\s*(\w+)\s*\)')
        foreach ($match in $collectMatches) {
            $target = $match.Groups[1].Value
            $collectCallbacks[$scriptName] = $target
            if ($target -eq "this") {
                $results.EventConflicts++
                if ($Verbose) {
                    Write-Status "  WARNING: $scriptName uses __CollectGameEventCallbacks(this) - scope is ambiguous" "warning"
                }
            }
            if ($target -eq "getroottable") {
                $results.EventConflicts++
                if ($Verbose) {
                    Write-Status "  CRITICAL: $scriptName uses __CollectGameEventCallbacks(getroottable()) - PROHIBITED" "error"
                }
                Track-Issue $scriptName "CRITICAL"
            }
        }

        $collectEventMatches = [regex]::Matches($content, '__CollectEventCallbacks\s*\(\s*(\w+)\s*\)')
        foreach ($match in $collectEventMatches) {
            $target = $match.Groups[1].Value
            if (-not $collectCallbacks.ContainsKey($scriptName)) {
                $collectCallbacks[$scriptName] = $target
            }
        }

        $eventMatches = [regex]::Matches($content, 'function\s+OnGameEvent_(\w+)')
        foreach ($match in $eventMatches) {
            $eventName = $match.Groups[1].Value
            # Check if event is valid
            if ($validGameEvents -notcontains $eventName) {
                $invalidEvents += @{
                    Script = $scriptName
                    Event = $eventName
                    Issue = "OnGameEvent_$eventName handles non-existent event. Check spelling."
                }
                $results.InvalidEvents++
                Track-Issue $scriptName "WARNING"
            }
            if (-not $eventCallbacks[$eventName]) {
                $eventCallbacks[$eventName] = @{ Scripts = @{} }
            }
            $eventCallbacks[$eventName].Scripts[$scriptName] = $true
        }
    }

    $eventConflicts = @()
    foreach ($eventName in $eventCallbacks.Keys) {
        $scripts = $eventCallbacks[$eventName].Scripts
        if ($scripts.Count -gt 1) {
            $eventConflicts += @{
                Event = $eventName
                Scripts = $scripts.Keys
                Count = $scripts.Count
            }
            $results.EventConflicts++
        }
    }

    if ($eventConflicts.Count -gt 0) {
        Write-Status "  Event callback conflicts: $($eventConflicts.Count)" "warning"
        if ($Verbose) {
            foreach ($conflict in $eventConflicts) {
                Write-Host "    Event '$($conflict.Event)' handled by $($conflict.Count) scripts:" -ForegroundColor Yellow
                foreach ($s in $conflict.Scripts) { Write-Host "      - $s" -ForegroundColor White }
            }
        }
    }

    if ($invalidEvents.Count -gt 0) {
        Write-Status "  Invalid event handlers: $($invalidEvents.Count)" "warning"
        if ($Verbose) {
            foreach ($ie in $invalidEvents) {
                Write-Host "    [$($ie.Script)] $($ie.Issue)" -ForegroundColor Yellow
            }
        }
    }

    if ($eventConflicts.Count -eq 0 -and $invalidEvents.Count -eq 0) {
        Write-Status "  No event callback conflicts!" "success"
    }

    if ($collectCallbacks.Count -gt 0 -and $Verbose) {
        Write-Status "  __CollectGameEventCallbacks usage:" "info"
        foreach ($script in $collectCallbacks.Keys) {
            Write-Detail "$script -> $($collectCallbacks[$script])" 2
        }
    }
}

# ==============================================================================
# TEST 4: GLOBAL VARIABLE CONFLICTS
# ==============================================================================
if ($CheckConflicts -or $FullTest) {
    Write-Status "`n[TEST 4] Global Variable and Function Conflicts..." "info"

    $globalVars = @{}
    $globalFunctions = @{}

    $skipPatterns = @('if', 'for', 'while', 'function', 'return', 'local', 'null', 'this', 'self',
                      'foreach', 'switch', 'case', 'default', 'continue', 'break', 'true', 'false',
                      'else', 'elseif', 'in', 'typeof', 'clone', 'delegate', 'parent', 'vargv',
                      'const', 'enum', 'extends', 'class', 'static', 'constructor')

    foreach ($scriptName in $scriptContents.Keys) {
        $content = $scriptContents[$scriptName]
        if (-not $content) { continue }

        $scopedMatches = [regex]::Matches($content, '::(\w+)')
        foreach ($match in $scopedMatches) {
            $varName = $match.Groups[1].Value
            if ($skipPatterns -contains $varName) { continue }
            if ($varName -match '^\d') { continue }
            if (-not $globalVars[$varName]) { $globalVars[$varName] = @{ Scripts = @{}; Addons = @{} } }
            $globalVars[$varName].Scripts[$scriptName] = $scriptAddons[$scriptName]
            $globalVars[$varName].Addons[$scriptAddons[$scriptName]] = $true
        }

        $assignMatches = [regex]::Matches($content, '(?<=^\s|[,;{\(]\s*)(\w+)\s*<-', [System.Text.RegularExpressions.RegexOptions]::Multiline)
        foreach ($match in $assignMatches) {
            $varName = $match.Groups[1].Value
            if ($skipPatterns -contains $varName) { continue }
            if ($varName -match '^\d') { continue }
            if (-not $globalVars[$varName]) { $globalVars[$varName] = @{ Scripts = @{}; Addons = @{} } }
            $globalVars[$varName].Scripts[$scriptName] = $scriptAddons[$scriptName]
            $globalVars[$varName].Addons[$scriptAddons[$scriptName]] = $true
        }

        $funcMatches = [regex]::Matches($content, 'function\s+(\w+)\s*\(')
        foreach ($match in $funcMatches) {
            $funcName = $match.Groups[1].Value
            if ($skipPatterns -contains $funcName) { continue }
            if (-not $globalFunctions[$funcName]) { $globalFunctions[$funcName] = @{ Scripts = @{} } }
            $globalFunctions[$funcName].Scripts[$scriptName] = $scriptAddons[$scriptName]
        }
    }

    $varConflicts = @()
    foreach ($varName in $globalVars.Keys) {
        $scripts = $globalVars[$varName].Scripts
        if ($scripts.Count -gt 1) {
            $addons = $globalVars[$varName].Addons.Keys
            if ($addons.Count -gt 1) {
                $varConflicts += @{ Variable = $varName; Scripts = $scripts.Keys; CrossAddon = $true; Addons = $addons }
                $results.GlobalConflicts++
            } else {
                $varConflicts += @{ Variable = $varName; Scripts = $scripts.Keys; CrossAddon = $false; Addons = $addons }
            }
        }
    }

    if ($varConflicts.Count -gt 0) {
        $criticalCount = ($varConflicts | Where-Object { $_.CrossAddon }).Count
        if ($criticalCount -gt 0) { Write-Status "  CROSS-ADDON global conflicts: $criticalCount" "error" }
        $warningCount = ($varConflicts | Where-Object { -not $_.CrossAddon }).Count
        if ($warningCount -gt 0) { Write-Status "  Same-addon global conflicts: $warningCount" "warning" }
        if ($Verbose) {
            foreach ($conflict in $varConflicts | Where-Object { $_.CrossAddon }) {
                Write-Host "    CRITICAL: Variable '$($conflict.Variable)' used across addons:" -ForegroundColor Red
                foreach ($s in $conflict.Scripts) { Write-Host "      - $s ($($globalVars[$conflict.Variable].Scripts[$s]))" -ForegroundColor White }
            }
        }
    } else {
        Write-Status "  No global variable conflicts!" "success"
    }

    $funcConflicts = @()
    foreach ($funcName in $globalFunctions.Keys) {
        $scripts = $globalFunctions[$funcName].Scripts
        if ($scripts.Count -gt 1) {
            $funcConflicts += @{ Function = $funcName; Scripts = $scripts.Keys }
            $results.FunctionConflicts++
        }
    }

    if ($funcConflicts.Count -gt 0) {
        Write-Status "  Function name conflicts: $($funcConflicts.Count)" "warning"
        if ($Verbose) {
            foreach ($conflict in $funcConflicts | Select-Object -First 10) {
                Write-Host "    Function '$($conflict.Function)' defined in multiple scripts:" -ForegroundColor Yellow
                foreach ($s in $conflict.Scripts) { Write-Host "      - $s" -ForegroundColor White }
            }
            if ($funcConflicts.Count -gt 10) { Write-Detail "... and $($funcConflicts.Count - 10) more" 2 }
        }
    }
}

# ==============================================================================
# TEST 5: DIRECTOROPTIONS & CONVAR CONFLICTS
# ==============================================================================
if ($CheckConflicts -or $FullTest) {
    Write-Status "`n[TEST 5] DirectorOptions and Convar Conflicts..." "info"

    $directorOptionsUsage = @{}
    $convarUsage = @{}

    foreach ($scriptName in $scriptContents.Keys) {
        $content = $scriptContents[$scriptName]
        if (-not $content) { continue }

        $doMatches = [regex]::Matches($content, 'DirectorOptions\.(\w+)\s*<-')
        foreach ($match in $doMatches) {
            $key = $match.Groups[1].Value
            if (-not $directorOptionsUsage[$key]) { $directorOptionsUsage[$key] = @{ Scripts = @{} } }
            $directorOptionsUsage[$key].Scripts[$scriptName] = $true
        }

        if ($content -match 'DirectorOptions\s*=\s*\{') {
            $results.EdgeCaseIssues++
            if ($Verbose) { Write-Status "  WARNING: $scriptName overwrites entire DirectorOptions object" "warning" }
        }

        $cvPattern = 'Convars\.SetValue\s*\(\s*"([^"]+)"'
        $cvMatches = [regex]::Matches($content, $cvPattern)
        foreach ($match in $cvMatches) {
            $cvName = $match.Groups[1].Value
            if (-not $convarUsage[$cvName]) { $convarUsage[$cvName] = @{ Scripts = @{} } }
            $convarUsage[$cvName].Scripts[$scriptName] = $true
        }
    }

    $doConflicts = @()
    foreach ($key in $directorOptionsUsage.Keys) {
        $scripts = $directorOptionsUsage[$key].Scripts
        if ($scripts.Count -gt 1) {
            $doConflicts += @{ Key = $key; Scripts = $scripts.Keys }
        }
    }

    if ($doConflicts.Count -gt 0) {
        Write-Status "  DirectorOptions key conflicts: $($doConflicts.Count)" "warning"
        if ($Verbose) {
            foreach ($conflict in $doConflicts) {
                Write-Host "    Key '$($conflict.Key)' set by multiple scripts:" -ForegroundColor Yellow
                foreach ($s in $conflict.Scripts) { Write-Host "      - $s" -ForegroundColor White }
            }
        }
    }

    $cvConflicts = @()
    foreach ($cv in $convarUsage.Keys) {
        $scripts = $convarUsage[$cv].Scripts
        if ($scripts.Count -gt 1) {
            $cvConflicts += @{ Convar = $cv; Scripts = $scripts.Keys }
            $results.ConvarConflicts++
        }
    }

    if ($cvConflicts.Count -gt 0) {
        Write-Status "  Convar conflicts: $($cvConflicts.Count)" "warning"
        if ($Verbose) {
            foreach ($conflict in $cvConflicts | Select-Object -First 10) {
                Write-Host "    Convar '$($conflict.Convar)' set by multiple scripts:" -ForegroundColor Yellow
                foreach ($s in $conflict.Scripts) { Write-Host "      - $s" -ForegroundColor White }
            }
        }
    }
}

# ==============================================================================
# TEST 6: EDGE CASES & L4D2-SPECIFIC ISSUES
# ==============================================================================
if ($CheckEdgeCases -or $FullTest) {
    Write-Status "`n[TEST 6] L4D2 Edge Cases & Risky Patterns..." "info"

    $edgeIssues = @()

    foreach ($scriptName in $scriptContents.Keys) {
        $content = $scriptContents[$scriptName]
        if (-not $content) { continue }

        foreach ($func in $vslibOnlyFunctions) {
            $matches = [regex]::Matches($content, $func)
            if ($matches.Count -gt 0) {
                $edgeIssues += @{ Script = $scriptName; Severity = "CRITICAL"; Issue = "Uses VSLib-only function '$func' - will crash in native L4D2" }
                $results.VSLibUsage++
            }
        }

        foreach ($func in $deprecatedFunctions) {
            $matches = [regex]::Matches($content, $func)
            if ($matches.Count -gt 0) {
                $edgeIssues += @{ Script = $scriptName; Severity = "WARNING"; Issue = "Uses deprecated/risky function matching '$func'" }
                $results.DeprecatedUsage++
            }
        }

        if ($content -match 'GetPlayerFromUserID\s*\(') {
            $lines = $content -split "`n"
            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ($lines[$i] -match 'GetPlayerFromUserID' -and
                    $lines[$i] -notmatch '==\s*null|null\s*==|!=\s*null|null\s*!=|IsValid' -and
                    ($i -eq 0 -or $lines[$i-1] -notmatch 'GetPlayerFromUserID.*null|null.*GetPlayerFromUserID')) {
                    $edgeIssues += @{ Script = $scriptName; Severity = "WARNING"; Issue = "Line $($i+1): GetPlayerFromUserID without null check" }
                    $results.EdgeCaseIssues++
                    break
                }
            }
        }

        if ($content -match '\.IsValid\s*\(\)') {
            $lines = $content -split "`n"
            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ($lines[$i] -match '(\w+)\.IsValid\s*\(\)') {
                    $varName = $matches[1]
                    if ($varName -ne "this" -and $varName -ne "self" -and
                        $lines[$i] -notmatch "$varName\s*!=\s*null|$varName\s*==\s*null") {
                        $edgeIssues += @{ Script = $scriptName; Severity = "INFO"; Issue = "Line $($i+1): .$varName.IsValid() without prior null check" }
                        $results.EdgeCaseIssues++
                        break
                    }
                }
            }
        }

        if ($content -match 'rawset\s*\([^,]+,\s*null\s*\)') {
            $edgeIssues += @{ Script = $scriptName; Severity = "WARNING"; Issue = "Uses rawset(table, key, null) instead of rawdelete(table, key) - memory leak" }
            $results.EdgeCaseIssues++
        }

        $includeThisMatches = [regex]::Matches($content, 'IncludeScript\s*\(\s*"[^"]+"\s*,\s*this\s*\)')
        if ($includeThisMatches.Count -gt 0) {
            $edgeIssues += @{ Script = $scriptName; Severity = "WARNING"; Issue = "IncludeScript(..., this) - 'this' scope is ambiguous in L4D2 VScript" }
            $results.EdgeCaseIssues++
        }

        foreach ($pattern in $riskyPatterns.Keys) {
            $regex = $riskyPatterns[$pattern]
            if ($content -match $regex) {
                $edgeIssues += @{ Script = $scriptName; Severity = "WARNING"; Issue = "Risky pattern: $pattern" }
                $results.EdgeCaseIssues++
            }
        }

        $netpropMatches = [regex]::Matches($content, 'NetProps\.(Set|Get)Prop\w+\s*\(\s*(\w+)')
        foreach ($match in $netpropMatches) {
            $varName = $match.Groups[2].Value
            if ($varName -ne "player" -and $varName -ne "entity" -and $varName -ne "ent") {
                $edgeIssues += @{ Script = $scriptName; Severity = "INFO"; Issue = "NetProps used on variable '$varName' - verify entity is valid first" }
                $results.EdgeCaseIssues++
                break
            }
        }

        if ($content -match '/\s*\w+\s*\)?\s*==\s*0|/\s*0') {
            $edgeIssues += @{ Script = $scriptName; Severity = "WARNING"; Issue = "Potential division by zero" }
            $results.EdgeCaseIssues++
        }
    }

    if ($edgeIssues.Count -gt 0) {
        $criticalCount = ($edgeIssues | Where-Object { $_.Severity -eq "CRITICAL" }).Count
        $warningCount = ($edgeIssues | Where-Object { $_.Severity -eq "WARNING" }).Count
        $infoCount = ($edgeIssues | Where-Object { $_.Severity -eq "INFO" }).Count
        if ($criticalCount -gt 0) { Write-Status "  CRITICAL edge cases: $criticalCount" "error" }
        if ($warningCount -gt 0) { Write-Status "  Warnings: $warningCount" "warning" }
        if ($infoCount -gt 0) { Write-Status "  Info: $infoCount" "info" }
        if ($Verbose) {
            foreach ($issue in $edgeIssues | Where-Object { $_.Severity -eq "CRITICAL" }) {
                Write-Host "    [CRITICAL] $($issue.Script): $($issue.Issue)" -ForegroundColor Red
            }
            foreach ($issue in $edgeIssues | Where-Object { $_.Severity -eq "WARNING" } | Select-Object -First 15) {
                Write-Host "    [WARNING] $($issue.Script): $($issue.Issue)" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Status "  No edge case issues!" "success"
    }
}

# ==============================================================================
# TEST 7: INCLUDESCRIPT VALIDATION
# ==============================================================================
if ($CheckIncludes -or $FullTest) {
    Write-Status "`n[TEST 7] IncludeScript Dependencies..." "info"

    $missingIncludes = @()
    $circularRisk = @()
    $badScopeIncludes = @()

    foreach ($scriptName in $scriptContents.Keys) {
        $content = $scriptContents[$scriptName]
        if (-not $content) { continue }

        $includeMatches = [regex]::Matches($content, 'IncludeScript\s*\(\s*"([^"]+)"')
        foreach ($match in $includeMatches) {
            $includeName = $match.Groups[1].Value
            if ($includeName -match '^vscripts/' -or $includeName -match '^libraries/' -or
                $includeName -match 'vslib' -or $includeName -match '^left4dead') { continue }
            if ($allScriptNames -notcontains $includeName) {
                $missingIncludes += @{ FromScript = $scriptName; MissingScript = $includeName }
                $results.MissingIncludes++
            }
            if ($includeName -eq $scriptName) {
                $circularRisk += @{ Script = $scriptName; Issue = "Self-inclusion detected" }
            }
        }

        $bareMatches = [regex]::Matches($content, 'IncludeScript\s*\(\s*"[^"]+"\s*\)')
        foreach ($m in $bareMatches) {
            $incName = $m.Groups[0].Value
            $badScopeIncludes += @{ Script = $scriptName; Include = $incName; Issue = 'IncludeScript("name") without scope - should be IncludeScript("name", getroottable())' }
            $results.MissingIncludes++
        }
    }

    if ($missingIncludes.Count -gt 0) {
        Write-Status "  Missing includes: $($missingIncludes.Count)" "warning"
        if ($Verbose) {
            foreach ($inc in $missingIncludes) { Write-Host "    - $($inc.FromScript) -> $($inc.MissingScript)" -ForegroundColor Yellow }
        }
    } else {
        Write-Status "  All includes resolved!" "success"
    }

    if ($circularRisk.Count -gt 0) {
        Write-Status "  Circular inclusion risks: $($circularRisk.Count)" "error"
        if ($Verbose) {
            foreach ($risk in $circularRisk) { Write-Host "    - $($risk.Script): $($risk.Issue)" -ForegroundColor Red }
        }
    }

    if ($badScopeIncludes.Count -gt 0) {
        Write-Status "  IncludeScript WITHOUT getroottable(): $($badScopeIncludes.Count)" "warning"
        if ($Verbose) {
            foreach ($inc in $badScopeIncludes) { Write-Host "    - $($inc.Script) -> $($inc.Include)" -ForegroundColor Yellow }
        }
    }
}

# ==============================================================================
# TEST 8: LOAD ORDER SIMULATION
# ==============================================================================
if ($SimulateLoad -or $FullTest) {
    Write-Status "`n[TEST 8] Load Order Simulation..." "info"

    $loadOrder = @()
    $loadedInOrder = @{}
    $overwriteWarnings = @()

    $directorScripts = @()
    foreach ($folder in $folders) {
        $dbaPath = Join-Path (Join-Path $basePath $folder) "director_base_addon.nut"
        if (Test-Path $dbaPath) { $directorScripts += $dbaPath }
    }

    if ($directorScripts.Count -eq 0) {
        Write-Status "  No director_base_addon.nut found for simulation" "warning"
    } else {
        foreach ($dba in $directorScripts) {
            $content = Get-Content $dba -Raw
            $includes = [regex]::Matches($content, 'IncludeScript\s*\(\s*"([^"]+)"')
            foreach ($match in $includes) {
                $scriptName = $match.Groups[1].Value
                if ($scriptContents.ContainsKey($scriptName)) {
                    if ($loadedInOrder.ContainsKey($scriptName)) {
                        $overwriteWarnings += @{ Script = $scriptName; FirstLoaded = $loadedInOrder[$scriptName]; SecondLoaded = $dba }
                    } else {
                        $loadedInOrder[$scriptName] = $dba
                        $loadOrder += $scriptName
                    }
                }
            }
        }

        Write-Status "  Simulated load order: $($loadOrder.Count) scripts" "info"
        if ($Verbose) {
            for ($i = 0; $i -lt $loadOrder.Count; $i++) { Write-Detail "$($i+1). $($loadOrder[$i])" 2 }
        }

        if ($overwriteWarnings.Count -gt 0) {
            Write-Status "  Scripts loaded multiple times: $($overwriteWarnings.Count)" "warning"
            if ($Verbose) {
                foreach ($w in $overwriteWarnings) {
                    Write-Host "    - $($w.Script) loaded by both $($w.FirstLoaded) and $($w.SecondLoaded)" -ForegroundColor Yellow
                }
            }
        }
    }
}

# ==============================================================================
# TEST 9: ENTITY LEAK RISK ASSESSMENT
# ==============================================================================
if ($FullTest) {
    Write-Status "`n[TEST 9] Entity Leak Risk Assessment..." "info"

    $entitySpawners = @()

    foreach ($scriptName in $scriptContents.Keys) {
        $content = $scriptContents[$scriptName]
        if (-not $content) { continue }

        $spawnCount = 0
        $spawnMatches = [regex]::Matches($content, 'SpawnEntityFromTable\s*\(\s*"([^"]+)"')
        $spawnCount += $spawnMatches.Count
        $createMatches = [regex]::Matches($content, 'CreateEntity\s*\(')
        $spawnCount += $createMatches.Count

        if ($spawnCount -gt 0) {
            $hasRoundEnd = $content -match 'OnGameEvent_round_end|OnGameEvent_mission_lost|round_end|mission_lost'
            $hasCleanup = $content -match 'Kill\s*\(|DoEntFire.*Kill|AcceptEntityInput.*Kill|RemoveEntity|UTIL_Remove'
            $entitySpawners += @{ Script = $scriptName; SpawnCount = $spawnCount; HasCleanup = $hasCleanup; HasRoundEnd = $hasRoundEnd }
            if (-not $hasCleanup -and -not $hasRoundEnd) { $results.EntityLeakRisks++ }
        }
    }

    $highRisk = $entitySpawners | Where-Object { -not $_.HasCleanup -and -not $_.HasRoundEnd }
    $mediumRisk = $entitySpawners | Where-Object { (-not $_.HasCleanup -and $_.HasRoundEnd) -or ($_.HasCleanup -and -not $_.HasRoundEnd) }

    if ($highRisk.Count -gt 0) {
        Write-Status "  HIGH RISK (spawns entities, no cleanup): $($highRisk.Count) scripts" "error"
        if ($Verbose) {
            foreach ($risk in $highRisk) { Write-Host "    - $($risk.Script) ($($risk.SpawnCount) spawns)" -ForegroundColor Red }
        }
    }
    if ($mediumRisk.Count -gt 0) {
        Write-Status "  MEDIUM RISK (partial cleanup): $($mediumRisk.Count) scripts" "warning"
    }
    if ($highRisk.Count -eq 0 -and $mediumRisk.Count -eq 0) {
        Write-Status "  All entity spawners have proper cleanup!" "success"
    }
}

# ==============================================================================
# TEST 10: CALLSTACK ERROR DETECTION (Method Detachment + Scope Errors)
# ==============================================================================
if ($FullTest) {
    Write-Status "`n[TEST 10] Callstack Error Detection..." "info"
    Write-Status "  Detecting method detachment, scope errors, callback 'this' loss..." "info"

    $callstackIssues = @()
    $issueCount = 0
    $globalTableNames = @{}
    $scriptFunctionNames = @{}

    foreach ($scriptName in $scriptContents.Keys) {
        $content = $scriptContents[$scriptName]
        if (-not $content) { continue }

        $tableMatches = [regex]::Matches($content, '(?:(?:::)?(\w+))\s*<-\s*\{')
        foreach ($m in $tableMatches) {
            $name = $m.Groups[1].Value
            if ($skipPatterns -notcontains $name) { $globalTableNames[$name] = $true }
        }
        $scopedTableMatches = [regex]::Matches($content, '::(\w+)\s*<-\s*\{')
        foreach ($m in $scopedTableMatches) {
            $name = $m.Groups[1].Value
            if ($skipPatterns -notcontains $name) { $globalTableNames[$name] = $true }
        }
        $methodNames = @()
        $methodMatches = [regex]::Matches($content, 'function\s+(\w+)\s*\(')
        foreach ($m in $methodMatches) { $methodNames += $m.Groups[1].Value }
        $scriptFunctionNames[$scriptName] = $methodNames
    }

    foreach ($scriptName in $scriptContents.Keys) {
        $content = $scriptContents[$scriptName]
        if (-not $content) { continue }
        $lines = $content -split "`n"

        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i].Trim()
            $lineNum = $i + 1

            $timerMatch = [regex]::Match($line, 'MaoLib\.(?:AddTimer|AddTimerSafe|AddTimerForce|AddTimerAuto)\s*\([^)]*,\s*([^,)]+)\s*,\s*(\w+)\s*\)')
            if ($timerMatch.Success) {
                $callback = $timerMatch.Groups[2].Value
                if ($callback -match '^[A-Za-z_]\w*$' -and
                    @('function','this','null','true','false','self','parent','vargv') -notcontains $callback -and
                    $callback -notmatch '^\$') {
                    $callstackIssues += @{
                        Script = $scriptName; Line = $lineNum; Type = "METHOD_DETACHMENT"; Severity = "CRITICAL"
                        Issue = "Callback '$callback' passed raw to AddTimer - loses 'this' environment. Wrap in: function() { Table.$callback(); }"
                        Pattern = "AddTimer"
                    }
                    $issueCount++
                    Track-Issue $scriptName "CRITICAL"
                }
            }

            $qualifiedTimerMatch = [regex]::Match($line, 'MaoLib\.(?:AddTimer|AddTimerSafe|AddTimerForce|AddTimerAuto)\s*\([^)]*,\s*([^,)]+)\s*,\s*::(\w+)\.(\w+)\s*\)')
            if ($qualifiedTimerMatch.Success) {
                $tableName = $qualifiedTimerMatch.Groups[2].Value
                $methodName = $qualifiedTimerMatch.Groups[3].Value
                $callstackIssues += @{
                    Script = $scriptName; Line = $lineNum; Type = "METHOD_DETACHMENT"; Severity = "CRITICAL"
                    Issue = "Callback '::$tableName.$methodName' passed raw to AddTimer - loses 'this'. Wrap in: function() { ::$tableName.$methodName(); }"
                    Pattern = "AddTimer"
                }
                $issueCount++
                Track-Issue $scriptName "CRITICAL"
            }

            $updateMatch = [regex]::Match($line, 'ScriptedMode_AddUpdate\s*\(\s*(\w+)\s*\)')
            if ($updateMatch.Success) {
                $callback = $updateMatch.Groups[1].Value
                if ($callback -notmatch 'function' -and $callback -ne 'this') {
                    $callstackIssues += @{
                        Script = $scriptName; Line = $lineNum; Type = "METHOD_DETACHMENT"; Severity = "CRITICAL"
                        Issue = "Method '$callback' passed raw to ScriptedMode_AddUpdate loses 'this'. Wrap in: function() { this.$callback(); }"
                        Pattern = "ScriptedMode_AddUpdate"
                    }
                    $issueCount++
                    Track-Issue $scriptName "CRITICAL"
                }
            }

            $dsMatch = [regex]::Match($line, 'DirectorScript\.(\w+)')
            if ($dsMatch.Success) {
                $globalName = $dsMatch.Groups[1].Value
                $excludeList = @('DirectorOptions','MapOptions','MapState','ScriptScope','BeginScript')
                if ($globalTableNames.ContainsKey($globalName) -and $excludeList -notcontains $globalName) {
                    $callstackIssues += @{
                        Script = $scriptName; Line = $lineNum; Type = "SCOPE_ERROR"; Severity = "CRITICAL"
                        Issue = "'DirectorScript.$globalName' - '$globalName' is a GLOBAL table, NOT in DirectorScript. Use '::$globalName' instead."
                        Pattern = "DirectorScript"
                    }
                    $issueCount++
                    Track-Issue $scriptName "CRITICAL"
                }
            }

            $globalEventMatch = [regex]::Match($line, '^function\s+OnGameEvent_(\w+)')
            if ($globalEventMatch.Success) {
                if ($line -match '^function\s+OnGameEvent_') {
                    $callstackIssues += @{
                        Script = $scriptName; Line = $lineNum; Type = "EVENT_CONFLICT"; Severity = "HIGH"
                        Issue = "OnGameEvent_$($globalEventMatch.Groups[1].Value) defined as GLOBAL function, not in a table. Conflicts with __CollectGameEventCallbacks table registration."
                        Pattern = "GlobalEventHandler"
                    }
                    $issueCount++
                    Track-Issue $scriptName "WARNING"
                }
            }

            $propFuncMatch = [regex]::Match($line, '^\s+(\w+)\s*=\s*function\s*\(')
            if ($propFuncMatch.Success) {
                $funcName = $propFuncMatch.Groups[1].Value
                if ($funcName -match '^OnGameEvent_') {
                    $callstackIssues += @{
                        Script = $scriptName; Line = $lineNum; Type = "PROPERTY_STYLE"; Severity = "HIGH"
                        Issue = "'$funcName' uses property-style (= function()) instead of method (function $funcName()). Breaks table environment - bare-name calls to other methods will fail."
                        Pattern = "PropertyMethod"
                    }
                    $issueCount++
                    Track-Issue $scriptName "WARNING"
                }
            }

            $kwMatch = [regex]::Match($line, '(?<=^|\s)(?:local|foreach)\s+((?:break|case|catch|class|clone|continue|const|default|delegate|delete|else|enum|extends|for|foreach|function|if|in|local|null|resume|return|switch|this|throw|try|typeof|while|parent|yield|constructor|vargc|vargv|instanceof|true|false|static)\b)\s*[=,(]')
            if ($kwMatch.Success) {
                $kw = $kwMatch.Groups[1].Value
                $callstackIssues += @{
                    Script = $scriptName; Line = $lineNum; Type = "KEYWORD_AS_IDENTIFIER"; Severity = "CRITICAL"
                    Issue = "'$kw' es keyword reservada de Squirrel usada como identifier -> error 'expected IDENTIFIER'. Renombrar."
                    Pattern = "ReservedKeyword"
                }
                $issueCount++
                Track-Issue $scriptName "CRITICAL"
            }

            $paramKwMatch = [regex]::Match($line, 'function\s+\w+\s*\(\s*(break|case|catch|class|clone|continue|const|default|delegate|delete|else|enum|extends|for|foreach|function|if|in|local|null|resume|return|switch|this|throw|try|typeof|while|parent|yield|constructor|vargc|vargv|instanceof|true|false|static)\b')
            if ($paramKwMatch.Success) {
                $kw = $paramKwMatch.Groups[1].Value
                $callstackIssues += @{
                    Script = $scriptName; Line = $lineNum; Type = "KEYWORD_AS_IDENTIFIER"; Severity = "CRITICAL"
                    Issue = "'$kw' es keyword reservada usada como parametro de funcion -> error 'expected IDENTIFIER'"
                    Pattern = "ReservedKeyword"
                }
                $issueCount++
                Track-Issue $scriptName "CRITICAL"
            }
        }

        $addThinkMatches = [regex]::Matches($content, 'AddThinkToEnt\s*\(\s*(\w+)\s*,\s*"(\w+)"\s*\)')
        foreach ($m in $addThinkMatches) {
            $thinkName = $m.Groups[2].Value
            $callstackIssues += @{
                Script = $scriptName; Line = "? (AddThinkToEnt)"; Type = "THINK_BINDING"; Severity = "INFO"
                Issue = "AddThinkToEnt with think '$thinkName' - verify it's bound to correct scope via closure or scope assignment"
                Pattern = "AddThinkToEnt"
            }
            $issueCount++
        }
    }

    $criticalCount = ($callstackIssues | Where-Object { $_.Severity -eq "CRITICAL" }).Count
    $highCount = ($callstackIssues | Where-Object { $_.Severity -eq "HIGH" }).Count
    $infoCount = ($callstackIssues | Where-Object { $_.Severity -eq "INFO" }).Count

    if ($callstackIssues.Count -gt 0) {
        if ($criticalCount -gt 0) { Write-Status "  CRITICAL callstack issues: $criticalCount" "error" }
        if ($highCount -gt 0) { Write-Status "  HIGH severity issues: $highCount" "warning" }
        if ($infoCount -gt 0) { Write-Status "  Info items: $infoCount" "info" }

        if ($Verbose) {
            Write-Status "`n  --- Callstack Issue Details ---" "header"
            $patterns = $callstackIssues | Group-Object Pattern
            foreach ($p in $patterns) {
                Write-Status "  [$($p.Name)] $($p.Count) occurrences:" "info"
                $fileGroups = $p.Group | Group-Object { "$($_.Script)|$($_.Issue)" }
                foreach ($fg in $fileGroups) {
                    $issue = $fg.Group[0]
                    $sevColor = switch ($issue.Severity) { "CRITICAL" { "Red" } "HIGH" { "Yellow" } default { "DarkGray" } }
                    if ($fg.Count -gt 1) {
                        $lines = ($fg.Group | ForEach-Object { $_.Line }) -join ", "
                        Write-Host "    [$($issue.Severity)] $($issue.Script):$lines" -ForegroundColor $sevColor
                    } else {
                        Write-Host "    [$($issue.Severity)] $($issue.Script):$($issue.Line)" -ForegroundColor $sevColor
                    }
                    Write-Host "      $($issue.Issue)" -ForegroundColor DarkGray
                }
                $fixText = switch ($p.Name) {
                    "AddTimer" { "Wrap callback in anonymous function: MaoLib.AddTimer(`"name`", interval, function() { Table.Method(); })" }
                    "ScriptedMode_AddUpdate" { "Wrap in closure: ScriptedMode_AddUpdate(function() { this.MethodName(); })" }
                    "DirectorScript" { "Replace DirectorScript.X with ::X (X is in getroottable)" }
                    "GlobalEventHandler" { "Move OnGameEvent_* into a dedicated table with __CollectGameEventCallbacks" }
                    "PropertyMethod" { "Change 'Name = function()' to 'function Name()' inside table" }
                    default { "" }
                }
                if ($fixText) { Write-Host "    FIX: $fixText" -ForegroundColor Cyan }
                Write-Host ""
            }
        }
    } else {
        Write-Status "  No callstack issues detected!" "success"
    }

    $results.CallstackErrors = $criticalCount
    $results.CallstackWarnings = $highCount
}

# ==============================================================================
# TEST 11: LLM COMMON ERROR PATTERNS
# ==============================================================================
if ($FullTest) {
    Write-Status "`n[TEST 11] LLM Common Error Patterns..." "info"

    $llmIssues = @()
    $issueCount = 0

    foreach ($scriptName in $scriptContents.Keys) {
        $content = $scriptContents[$scriptName]
        if (-not $content) { continue }
        $lines = $content -split "`n"

        if ($content -match '__CollectGameEventCallbacks\s*\(\s*getroottable\s*\(\s*\)\s*\)') {
            $llmIssues += @{
                Script = $scriptName; Line = 0; Type = "LLM_HIJACK"; Severity = "CRITICAL"
                Issue = "__CollectGameEventCallbacks(getroottable()) PROHIBIDO - secuestra eventos de TODOS los scripts. Usar tabla dedicada: __CollectGameEventCallbacks(::MiTabla)"
            }
            $issueCount++
            Track-Issue $scriptName "CRITICAL"
        }

        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            if ($line -match '\btype\s*\(') {
                $cleanLine = $line -replace 'typeof', '' -replace 'typename', ''
                if ($cleanLine -match '\btype\s*\(') {
                    $llmIssues += @{
                        Script = $scriptName; Line = $i + 1; Type = "LLM_TYPEOF"; Severity = "CRITICAL"
                        Issue = "type() no existe en Squirrel 3.x L4D2 VScript. Usar typeof() en su lugar. Linea: $($line.Trim())"
                    }
                    $issueCount++
                    Track-Issue $scriptName "CRITICAL"
                }
            }

            if ($line -match 'EntIndexToHScript\s*\(\s*params\.(attacker|userid|victim)\s*\)') {
                $paramName = $matches[1]
                $llmIssues += @{
                    Script = $scriptName; Line = $i + 1; Type = "LLM_ENTINDEX"; Severity = "HIGH"
                    Issue = "params.$paramName es USERID, no entindex. Usar GetPlayerFromUserID(params.$paramName) en lugar de EntIndexToHScript(). Linea: $($line.Trim())"
                }
                $issueCount++
                Track-Issue $scriptName "WARNING"
            }
        }

        $hallucinatedParams = @(
            'params\.killer\b','params\.damager\b','params\.slayer\b','params\.murderer\b',
            'params\.bullet\b','params\.projectile\b','params\.source\b','params\.target\b',
            'params\.zombie\b','params\.common\b','params\.special\b','params\.boss\b',
            'params\.infected_id\b','params\.player_id\b','params\.killerid\b',
            'params\.victimid\b','params\.attackerid\b'
        )

        foreach ($pattern in $hallucinatedParams) {
            for ($i = 0; $i -lt $lines.Count; $i++) {
                $line = $lines[$i]
                if ($line -match $pattern) {
                    $paramName = $matches[0]
                    $isEventHandler = $false
                    for ($j = [Math]::Max(0, $i - 20); $j -lt $i; $j++) {
                        if ($lines[$j] -match 'function\s+OnGameEvent_\w+\s*\(') { $isEventHandler = $true; break }
                    }
                    if ($isEventHandler) {
                        $llmIssues += @{
                            Script = $scriptName; Line = $i + 1; Type = "LLM_HALLUCINATED_PARAM"; Severity = "HIGH"
                            Issue = "'$paramName' no existe en eventos L4D2. Parametros reales: userid, attacker, weapon, type, etc. Linea: $($line.Trim())"
                        }
                        $issueCount++
                        Track-Issue $scriptName "WARNING"
                    }
                }
            }
        }

        if ($content -match '(foreach|for)\s*\(.*\)\s*\{[^}]*Entities\.FindByClassname') {
            $depth = 0
            $nestedEntityLoop = $false
            foreach ($line in $lines) {
                if ($line -match '\bforeach\b.*\{' -or ($line -match '\bfor\b.*\{' -and $line -notmatch 'local\s+\w+\s*=')) { $depth++ }
                if ($line -match '\}') { $depth-- }
                if ($depth -ge 2 -and $line -match 'Entities\.FindByClassname') { $nestedEntityLoop = $true }
            }
            if ($nestedEntityLoop) {
                $llmIssues += @{
                    Script = $scriptName; Line = "?(nested)"; Type = "LLM_ENTITY_INVALIDATION"; Severity = "WARNING"
                    Issue = "Nested entity iteration: inner Entities.FindByClassname puede invalidar handles del loop exterior."
                }
                $issueCount++
            }
        }

        if ($content -match '\[\s*\w+\s*\]\s*!=\s*null' -or $content -match '\[\s*\w+\s*\]\s*==\s*null') {
            $llmIssues += @{
                Script = $scriptName; Line = 0; Type = "LLM_IN_OPERATOR"; Severity = "INFO"
                Issue = "Comparacion con null para chequeo de tabla. Preferir 'key in table' que funciona aunque el valor sea null."
            }
            $issueCount++
        }

        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i].Trim()
            if ($line -match 'IncludeScript\s*\(\s*"([^"]+)"\s*\)\s*$') {
                $incName = $matches[1]
                $llmIssues += @{
                    Script = $scriptName; Line = $i + 1; Type = "LLM_INCLUDESCRIPT_SCOPE"; Severity = "HIGH"
                    Issue = "IncludeScript(`"$incName`") sin scope. Agregar: IncludeScript(`"$incName`", getroottable())"
                }
                $issueCount++
                Track-Issue $scriptName "WARNING"
            }
        }

        $hasCallbackRegistration = ($content -match '__CollectGameEventCallbacks' -or $content -match '__CollectEventCallbacks')
        if ($hasCallbackRegistration) {
            for ($i = 0; $i -lt $lines.Count; $i++) {
                $line = $lines[$i]
                if ($line -match '^\s+(\w+)\s*=\s*function\s*\(') {
                    $funcName = $matches[1]
                    if ($funcName -notmatch '^(__Collect|OnGameEvent_|Get|Set|Is)') {
                        $llmIssues += @{
                            Script = $scriptName; Line = $i + 1; Type = "LLM_PROPERTY_METHOD"; Severity = "INFO"
                            Issue = "'$funcName' usa propiedad (= function()) en vez de metodo (function $funcName()). Pierde table environment."
                        }
                        $issueCount++
                    }
                }
            }
        }

        if ($content -match '\{\s*[^}]*\b(class|delete|static|default|parent|catch|throw|enum|extends|constructor|instanceof|yield|vargc|vargv)\s*=') {
            $llmIssues += @{
                Script = $scriptName; Line = 0; Type = "LLM_KEYWORD_KEY"; Severity = "HIGH"
                Issue = "Squirrel keyword usado como key en table literal. Usar [`"keyword`"] = value en vez de keyword = value"
            }
            $issueCount++
            Track-Issue $scriptName "WARNING"
        }
    }

    $criticalCount = ($llmIssues | Where-Object { $_.Severity -eq "CRITICAL" }).Count
    $highCount = ($llmIssues | Where-Object { $_.Severity -eq "HIGH" }).Count
    $warningCount = ($llmIssues | Where-Object { $_.Severity -eq "WARNING" }).Count
    $infoCount = ($llmIssues | Where-Object { $_.Severity -eq "INFO" }).Count

    if ($llmIssues.Count -gt 0) {
        if ($criticalCount -gt 0) { Write-Status "  LLM CRITICAL errors: $criticalCount" "error" }
        if ($highCount -gt 0) { Write-Status "  LLM HIGH issues: $highCount" "warning" }
        if ($warningCount -gt 0) { Write-Status "  LLM Warnings: $warningCount" "warning" }
        if ($infoCount -gt 0) { Write-Status "  LLM Info: $infoCount" "info" }

        if ($Verbose) {
            Write-Status "`n  --- LLM Pattern Details ---" "header"
            $patterns = $llmIssues | Group-Object Type
            foreach ($p in $patterns) {
                Write-Status "  [$($p.Name)] $($p.Count) occurrences:" "info"
                $scriptGroups = $p.Group | Group-Object Script
                foreach ($sg in $scriptGroups) {
                    $first = $sg.Group[0]
                    $sevColor = switch ($first.Severity) { "CRITICAL" { "Red" } "HIGH" { "Yellow" } default { "DarkGray" } }
                    if ($sg.Count -gt 1) {
                        $lines = ($sg.Group | ForEach-Object { if ($_.Line -gt 0) { $_.Line } }) -join ", "
                        Write-Host "    [$($first.Severity)] $($first.Script) ($($sg.Count)x): $lines" -ForegroundColor $sevColor
                    } else {
                        Write-Host "    [$($first.Severity)] $($first.Script):$($first.Line)" -ForegroundColor $sevColor
                    }
                    Write-Host "      $($first.Issue)" -ForegroundColor DarkGray
                }
            }
        }
    } else {
        Write-Status "  No LLM common errors detected!" "success"
    }

    $results.LLMErrors = $criticalCount
    $results.LLMWarnings = $highCount + $warningCount
}

# ==============================================================================
# TEST 12: LOADING CRASH PATTERNS (CRITICAL)
# ==============================================================================
if ($FullTest) {
    Write-Status "`n[TEST 12] Loading Crash Pattern Detection..." "info"

    $loadIssues = @()

    foreach ($scriptName in $scriptContents.Keys) {
        $content = $scriptContents[$scriptName]
        if (-not $content) { continue }

        $infoNullMatches = [regex]::Matches($content, 'SpawnEntityFromTable\s*\(\s*"info_null"')
        if ($infoNullMatches.Count -ge 2) {
            $loadIssues += [PSCustomObject]@{
                Script = $scriptName; Type = "LOAD_INFO_NULL"; Severity = "CRITICAL"; Count = $infoNullMatches.Count
                Issue = "$($infoNullMatches.Count)x info_null spawn - 2+ info_null entities CAUSAN CRASH al abrir saferoom door. Usar info_target o prop_dynamic en vez."
            }
            $results.LoadingCrash++
            Track-Issue $scriptName "CRITICAL"
        }

        if ($content -match 'SpawnEntityFromTable\s*\(\s*"env_projectedtexture"') {
            $loadIssues += [PSCustomObject]@{
                Script = $scriptName; Type = "LOAD_PROJECTED_TEXTURE"; Severity = "CRITICAL"; Count = 1
                Issue = "env_projectedtexture spawn - entidad problematica conocida que causa crashes. Evitar su uso."
            }
            $results.LoadingCrash++
            Track-Issue $scriptName "CRITICAL"
        }

        $spawnCalls = [regex]::Matches($content, '(SpawnEntityFromTable|CreateEntity)\s*\(\s*"(prop_dynamic|prop_physics|prop_dynamic_override)"')
        foreach ($m in $spawnCalls) {
            $pos = $m.Index + $m.Length
            $afterText = $content.Substring($pos)
            $tableMatch = [regex]::Match($afterText, '\{(?:[^{}]|(?<Open>\{)|(?<-Open>\}))*(?(Open)(?!))\}')
            if ($tableMatch.Success) {
                $tableStr = $tableMatch.Value
                if ($tableStr -notmatch '\bmodel\s*=') {
                    $loadIssues += [PSCustomObject]@{
                        Script = $scriptName; Type = "LOAD_MISSING_MODEL"; Severity = "CRITICAL"; Count = 1
                        Issue = "prop_dynamic/prop_physics spawn sin key 'model' - CRASH al spawnear sin modelo. Agregar: model = `"path/to/model.mdl`""
                    }
                    $results.LoadingCrash++
                    Track-Issue $scriptName "CRITICAL"
                }
            }
        }

        if ($content -match 'SpawnEntityFromTable' -and $content -match 'DispatchSpawn\s*\(') {
            $loadIssues += [PSCustomObject]@{
                Script = $scriptName; Type = "LOAD_DOUBLE_SPAWN"; Severity = "HIGH"; Count = 1
                Issue = "SpawnEntityFromTable + DispatchSpawn - SpawnEntityFromTable ya auto-spawnea. DispatchSpawn extra puede causar crash por double-spawn."
            }
            $results.LoadingCrash++
            Track-Issue $scriptName "WARNING"
        }

        if ($content -match '\bDoUniqueString\s*\(') {
            $loadIssues += [PSCustomObject]@{
                Script = $scriptName; Type = "LOAD_DO_UNIQUE_STRING"; Severity = "CRITICAL"; Count = 1
                Issue = "DoUniqueString() NO existe en L4D2 VScript. Usar UniqueString() en su lugar - causa RUNTIME CRASH."
            }
            $results.LoadingCrash++
            Track-Issue $scriptName "CRITICAL"
        }

        $bareIncludes = [regex]::Matches($content, 'IncludeScript\s*\(\s*"[^"]+"\s*\)')
        foreach ($m in $bareIncludes) {
            $hasAnyScope = $content -match 'IncludeScript\s*\([^)]+,\s*(getroottable|this|g_MapScript|g_ModeScript|DirectorScript)'
            if (-not $hasAnyScope) {
                $loadIssues += [PSCustomObject]@{
                    Script = $scriptName; Type = "LOAD_INCLUDE_SCOPE"; Severity = "HIGH"; Count = 1
                    Issue = 'IncludeScript sin scope - puede cargar en ambito incorrecto. Agregar segundo argumento: IncludeScript("...", getroottable())'
                }
                $results.LoadingCrash++
                Track-Issue $scriptName "WARNING"
                break
            }
        }
    }

    $criticalLC = ($loadIssues | Where-Object { $_.Severity -eq "CRITICAL" }).Count
    $highLC = ($loadIssues | Where-Object { $_.Severity -eq "HIGH" }).Count

    if ($loadIssues.Count -gt 0) {
        if ($criticalLC -gt 0) { Write-Status "  Loading CRITICAL issues: $criticalLC" "error" }
        if ($highLC -gt 0) { Write-Status "  Loading HIGH issues: $highLC" "warning" }
        if ($Verbose) {
            Write-Status "`n  --- Loading Crash Details ---" "header"
            $patterns = $loadIssues | Group-Object Type
            foreach ($p in $patterns) {
                $isCritical = ($p.Group[0].Severity -eq "CRITICAL")
                $color = if ($isCritical) { "Red" } else { "Yellow" }
                Write-Host "  [$($p.Name)] $($p.Count) issues:" -ForegroundColor $color
                $scriptGroups = $p.Group | Group-Object Script
                foreach ($sg in $scriptGroups) { Write-Host "    $($sg.Name)" -ForegroundColor $color }
                Write-Host "    FIX: $($p.Group[0].Issue)" -ForegroundColor Cyan
            }
        }
    } else {
        Write-Status "  No loading crash patterns detected!" "success"
    }
}

# ==============================================================================
# TEST 13: RUNTIME CRASH PATTERNS (CRITICAL)
# ==============================================================================
if ($FullTest) {
    Write-Status "`n[TEST 13] Runtime Crash Pattern Detection..." "info"

    $runIssues = @()

    foreach ($scriptName in $scriptContents.Keys) {
        $content = $scriptContents[$scriptName]
        if (-not $content) { continue }
        $lines = $content -split "`n"

        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i].Trim()
            if ($line -match '(\w+)\.Kill\s*\(\s*\)') {
                $varName = $matches[1]
                $safeVars = @('ent','entity','this','self','weapon','item','particle')
                if ($safeVars -notcontains $varName -and $varName -notmatch '^[A-Z][A-Za-z]*$' -and $varName.Length -gt 1) {
                    $hasGuard = $false
                    $killIdx = $line.IndexOf("$varName.Kill()")
                    if ($killIdx -ge 0) {
                        $beforeKill = $line.Substring(0, $killIdx)
                        if ($beforeKill -match 'if\s*\(.*\b' + [regex]::Escape($varName) + '\b') { $hasGuard = $true }
                    }
                    if (-not $hasGuard) {
                        for ($j = [Math]::Max(0, $i-3); $j -lt $i; $j++) {
                            if ($lines[$j] -match "$varName\s*!=\s*null|$varName\s*&&|\bIsValid\b.*$varName|$varName.*IsValid\b") {
                                $hasGuard = $true; break
                            }
                        }
                    }
                    if (-not $hasGuard) {
                        $runIssues += [PSCustomObject]@{
                            Script = $scriptName; Line = $i + 1; Type = "RUNTIME_KILL_GUARD"; Severity = "HIGH"
                            Issue = "'$varName.Kill()' sin null/valid check - CRASHEA si la entidad ya fue eliminada. Usar: if ($varName && $varName.IsValid()) $varName.Kill()"
                        }
                        $results.RuntimeCrash++
                        Track-Issue $scriptName "WARNING"
                    }
                }
            }
        }

        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i].Trim()
            if ($line -match 'local\s+(\w+)\s*=\s*GetPlayerFromUserID\s*\(') {
                $varName = $matches[1]
                $foundGuard = $false
                for ($j = $i+1; $j -lt [Math]::Min($i+6, $lines.Count); $j++) {
                    $checkLine = $lines[$j].Trim()
                    if ($checkLine -match "if\s*\([^)]*!?\s*$varName|$varName\s*(==|!=)\s*null|null\s*(==|!=)\s*$varName|$varName\s*&&|IsValid.*$varName") {
                        $foundGuard = $true; break
                    }
                    if ($checkLine -match "$varName\.\w+\s*\(") {
                        $runIssues += [PSCustomObject]@{
                            Script = $scriptName; Line = $j + 1; Type = "RUNTIME_NULL_PLAYER"; Severity = "HIGH"
                            Issue = "GetPlayerFromUserID devuelve null si jugador se desconecto. Metodo '$($checkLine -replace '\s+', ' ')' sin null check en $varName."
                        }
                        $results.RuntimeCrash++
                        Track-Issue $scriptName "WARNING"
                        break
                    }
                }
            }
        }

        if ($content -match '\bforeach\b' -and ($content -match '\bremove\s*\(' -or $content -match '\bappend\s*\(' -or $content -match '\brawdelete\b' -or $content -match '\bdelete\s+')) {
            $foreachMatches = [regex]::Matches($content, 'foreach\s*\([^)]+\)')
            foreach ($fm in $foreachMatches) {
                $foreachBody = $fm.Value
                $collectionMatch = [regex]::Match($foreachBody, '\bin\s+(\w+(?:\.\w+)*)\s*$')
                if (-not $collectionMatch.Success) { continue }
                $collectionName = $collectionMatch.Groups[1].Value
                if ($collectionName -eq '' -or $collectionName.Length -lt 2) { continue }
                $blockStart = $fm.Index + $fm.Length
                $bracePos = $content.IndexOf('{', $blockStart)
                if ($bracePos -lt 0) { continue }
                $depth = 0
                $blockEnd = -1
                for ($k = $bracePos; $k -lt $content.Length; $k++) {
                    if ($content[$k] -eq '{') { $depth++ }
                    elseif ($content[$k] -eq '}') { $depth--; if ($depth -eq 0) { $blockEnd = $k; break } }
                }
                if ($blockEnd -lt 0) { continue }
                $blockContent = $content.Substring($bracePos + 1, $blockEnd - $bracePos - 1)
                $isDangerousModify = $false
                if ($blockContent -match '\b' + [regex]::Escape($collectionName) + '\.(remove|append)\s*\(') { $isDangerousModify = $true }
                if (-not $isDangerousModify -and $blockContent -match '(rawdelete|delete)\s*\(\s*' + [regex]::Escape($collectionName)) { $isDangerousModify = $true }
                if ($isDangerousModify) {
                    $runIssues += [PSCustomObject]@{
                        Script = $scriptName; Type = "RUNTIME_FOREACH_MODIFY"; Severity = "HIGH"
                        Issue = "foreach sobre '$collectionName' contiene .remove()/.append() en la misma coleccion - puede invalidar el iterador."
                    }
                    $results.RuntimeCrash++
                    Track-Issue $scriptName "WARNING"
                }
            }
        }

        if ($content -match 'foreach\s*\([^)]+in\s+\w+\)' -and $content -match 'rawdelete|delete\s+') {
            $foreachMatches = [regex]::Matches($content, 'foreach\s*\([^)]+in\s+(\w+)\)')
            foreach ($fm in $foreachMatches) {
                $collectionName = $fm.Groups[1].Value
                $startPos = $fm.Index
                $endPos = [Math]::Min($startPos + 500, $content.Length)
                $window = $content.Substring($startPos, $endPos - $startPos)
                if ($window -match "(rawdelete|delete)\s*\(\s*$collectionName") {
                    $runIssues += [PSCustomObject]@{
                        Script = $scriptName; Type = "RUNTIME_TABLE_MODIFY"; Severity = "HIGH"
                        Issue = "foreach sobre tabla '$collectionName' con rawdelete/delete dentro - invalida el iterador."
                    }
                    $results.RuntimeCrash++
                    Track-Issue $scriptName "WARNING"
                    break
                }
            }
        }
    }

    $criticalRC = ($runIssues | Where-Object { $_.Severity -eq "CRITICAL" }).Count
    $highRC = ($runIssues | Where-Object { $_.Severity -eq "HIGH" }).Count

    if ($runIssues.Count -gt 0) {
        if ($criticalRC -gt 0) { Write-Status "  Runtime CRITICAL issues: $criticalRC" "error" }
        if ($highRC -gt 0) { Write-Status "  Runtime HIGH issues: $highRC" "warning" }
        if ($Verbose) {
            Write-Status "`n  --- Runtime Crash Details ---" "header"
            $patterns = $runIssues | Group-Object Type
            foreach ($p in $patterns) {
                $isCritical = ($p.Group[0].Severity -eq "CRITICAL")
                $color = if ($isCritical) { "Red" } else { "Yellow" }
                Write-Host "  [$($p.Name)] $($p.Count) issues:" -ForegroundColor $color
                $fileGroups = $p.Group | Group-Object Script
                foreach ($fg in $fileGroups) {
                    Write-Host "    $($fg.Name) ($($fg.Count)x)" -ForegroundColor $color
                    if ($fg.Count -le 3) {
                        foreach ($item in $fg.Group) {
                            if ($item.Line -gt 0) { Write-Host "      Line $($item.Line): $($item.Issue)" -ForegroundColor DarkGray }
                        }
                    }
                }
            }
        }
    } else {
        Write-Status "  No runtime crash patterns detected!" "success"
    }
}

# ==============================================================================
# TEST 14: DEPENDENCY CONSISTENCY
# ==============================================================================
if ($FullTest) {
    Write-Status "`n[TEST 14] Dependency Consistency Check..." "info"

    $depIssues = @()

    foreach ($scriptName in $scriptContents.Keys) {
        $content = $scriptContents[$scriptName]
        if (-not $content) { continue }

        if ($content -match '\bMaoLib\.\w+') {
            $hasMaoLibInclude = $content -match 'IncludeScript\s*\(\s*"maolib"'
            $hasMaoLibGuard = $content -match '"MaoLib"\s+in\s+getroottable'
            if (-not $hasMaoLibInclude -and -not $hasMaoLibGuard) {
                $depIssues += [PSCustomObject]@{
                    Script = $scriptName; Type = "DEP_MAOLIB"; Severity = "HIGH"
                    Issue = 'Usa MaoLib.* pero no tiene IncludeScript("maolib") ni guard. CRASHEA si maolib no se cargo antes.'
                }
                $results.DependencyIssues++
                Track-Issue $scriptName "WARNING"
            }
        }

        if ($content -match '\bMaoLib_VFX\.\w+') {
            $hasVFXInclude = $content -match 'IncludeScript\s*\(\s*"maolib_vfx"'
            if (-not $hasVFXInclude) {
                $depIssues += [PSCustomObject]@{
                    Script = $scriptName; Type = "DEP_MAOLIB_VFX"; Severity = "HIGH"
                    Issue = 'Usa MaoLib_VFX.* pero no tiene IncludeScript("maolib_vfx").'
                }
                $results.DependencyIssues++
                Track-Issue $scriptName "WARNING"
            }
        }

        if ($content -match '\bMaoLib\.NavUtils\.\w+') {
            $hasNavInclude = $content -match 'IncludeScript\s*\(\s*"maolib_navutils"'
            if (-not $hasNavInclude) {
                $depIssues += [PSCustomObject]@{
                    Script = $scriptName; Type = "DEP_NAVUTILS"; Severity = "HIGH"
                    Issue = 'Usa MaoLib.NavUtils.* pero no tiene IncludeScript("maolib_navutils").'
                }
                $results.DependencyIssues++
                Track-Issue $scriptName "WARNING"
            }
        }

        if ($content -match 'function\s+OnGameEvent_\w+') {
            $hasRegistration = $content -match '__CollectGameEventCallbacks|__CollectEventCallbacks'
            if (-not $hasRegistration) {
                $depIssues += [PSCustomObject]@{
                    Script = $scriptName; Type = "DEP_ORPHANED_EVENTS"; Severity = "HIGH"
                    Issue = "Define OnGameEvent_* handlers pero no tiene __CollectGameEventCallbacks() - los eventos NUNCA se ejecutan."
                }
                $results.DependencyIssues++
                Track-Issue $scriptName "WARNING"
            }
        }

        if ($content -match 'g_MapScript\.\w+') {
            $hasGuard = $content -match 'g_MapScript\s*(!=|==|in)' -or $content -match '".*g_MapScript.*"\s+in\s+'
            if (-not $hasGuard) {
                $depIssues += [PSCustomObject]@{ Script = $scriptName; Type = "DEP_MAPSCRIPT"; Severity = "INFO"
                    Issue = "Accede a g_MapScript.X sin verificar - puede no existir en ciertos puntos de carga." }
                $results.DependencyIssues++
            }
        }

        if ($content -match 'DirectorScript\.(ScriptScope|BeginScript|DirectorOptions|MapOptions|MapState)\s*=') {
        } elseif ($content -match 'DirectorScript\.(\w+)') {
            $propName = $matches[1]
            if ($propName -notmatch '^(RunScript|BeginScript|ScriptScope|DirectorOptions|MapOptions|MapState)$') {
                $knownGlobal = $globalTableNames.ContainsKey($propName)
                if ($knownGlobal) {
                } elseif (-not $content -match '\b' + [regex]::Escape($propName) + '\s*<-\s*\{') {
                    $depIssues += [PSCustomObject]@{ Script = $scriptName; Type = "DEP_DIRECTORSCRIPT"; Severity = "INFO"
                        Issue = "Accede a DirectorScript.$propName que puede no ser nativo. Verificar que no deberia ser ::$propName." }
                    $results.DependencyIssues++
                }
            }
        }
    }

    $highDC = ($depIssues | Where-Object { $_.Severity -eq "HIGH" }).Count
    $infoDC = ($depIssues | Where-Object { $_.Severity -eq "INFO" }).Count

    if ($depIssues.Count -gt 0) {
        if ($highDC -gt 0) { Write-Status "  Dependency HIGH issues: $highDC" "warning" }
        if ($infoDC -gt 0) { Write-Status "  Dependency INFO items: $infoDC" "info" }
        if ($Verbose) {
            Write-Status "`n  --- Dependency Details ---" "header"
            $patterns = $depIssues | Group-Object Type
            foreach ($p in $patterns) {
                $color = if ($p.Group[0].Severity -eq "HIGH") { "Yellow" } else { "DarkGray" }
                Write-Host "  [$($p.Name)] $($p.Count) issues:" -ForegroundColor $color
                $scriptGroups = $p.Group | Group-Object Script
                foreach ($sg in $scriptGroups) { Write-Host "    $($sg.Name)" -ForegroundColor $color }
                Write-Host "    FIX: $($p.Group[0].Issue)" -ForegroundColor Cyan
            }
        }
    } else {
        Write-Status "  No dependency issues detected!" "success"
    }
}

# ==============================================================================
# TEST 15: MAOLIB v2026 VALIDATION (NEW)
# ==============================================================================
if ($CheckMaoLib -or $FullTest) {
    Write-Status "`n[TEST 15] MaoLib v2026 Validation..." "info"
    Write-Status "  Detecting deprecated APIs, silent killers, missing module includes..." "info"

    $maoLibIssues = @()

    foreach ($scriptName in $scriptContents.Keys) {
        $content = $scriptContents[$scriptName]
        if (-not $content) { continue }

        if ($content -match '\bcompilestring\b') {
            $issue = [PSCustomObject]@{
                Script = $scriptName
                Type = "MAOLIB_COMPILESTRING"
                Severity = "CRITICAL"
                IssueText = "compilestring() detected - Fase 1 ELIMINATED all compilestring usage (RCE vulnerability). Use MaoLib.ParseConfigString() or closures."
            }
            $maoLibIssues += $issue
            $results.MaoLibIssues++
            Track-Issue $scriptName "CRITICAL"
        }

        if ($content -match '"MaoLib"\s+in\s+getroottable\s*\(\s*\)') {
            $issue = [PSCustomObject]@{
                Script = $scriptName
                Type = "MAOLIB_SILENT_KILLER"
                Severity = "CRITICAL"
                IssueText = 'MaoLib in getroottable() is a SILENT KILLER. Creates zombie scripts. MaoLib is HARD DEPENDENCY - fail fast without checks.'
            }
            $maoLibIssues += $issue
            $results.MaoLibIssues++
            Track-Issue $scriptName "CRITICAL"
        }

        $dcPattern = 'DelayCall\s*\(\s*"'
        if ($content -match $dcPattern) {
            $issue = [PSCustomObject]@{
                Script = $scriptName
                Type = "MAOLIB_DELAYCALL_STRING"
                Severity = "CRITICAL"
                IssueText = 'DelayCall(string, ...) is DEPRECATED (Fase 1). Now accepts closures: MaoLib.DelayCall(function() <...>, delay)'
            }
            $maoLibIssues += $issue
            $results.MaoLibIssues++
            Track-Issue $scriptName "CRITICAL"
        }

        $addMonitorMatches = [regex]::Matches($content, 'AddMonitor\s*\(')
        if ($addMonitorMatches.Count -gt 0) {
            if ($content -match 'info_target.*AddMonitor|AddMonitor.*info_target') {
                $issue = [PSCustomObject]@{
                    Script = $scriptName
                    Type = "MAOLIB_ADDMONITOR_LEGACY"
                    Severity = "WARNING"
                    IssueText = 'AddMonitor with manual info_target detected. v2026 AddMonitor is a wrapper over AddTimer.'
                }
                $maoLibIssues += $issue
                $results.MaoLibIssues++
                Track-Issue $scriptName "WARNING"
            }
        }

        foreach ($modulePattern in $maoLibModules.Keys) {
            if ($content -match $modulePattern) {
                $expectedInclude = $maoLibModules[$modulePattern]
                $hasInclude = $content -match ("IncludeScript\s*\(\s*`"" + $expectedInclude + "`"")
                if (-not $hasInclude) {
                    if ($scriptAddons[$scriptName] -ne "l4cCoreAddon") {
                        $issue = [PSCustomObject]@{
                            Script = $scriptName
                            Type = "MAOLIB_MISSING_INCLUDE"
                            Severity = "HIGH"
                            IssueText = "Uses $modulePattern but missing IncludeScript for $expectedInclude"
                        }
                        $maoLibIssues += $issue
                        $results.MaoLibIssues++
                        Track-Issue $scriptName "WARNING"
                    }
                }
            }
        }

        if ($content -match 'EntityOutputs\.AddOutput') {
            $issue = [PSCustomObject]@{
                Script = $scriptName
                Type = "MAOLIB_VS_LIB_REMNANT"
                Severity = "CRITICAL"
                IssueText = 'EntityOutputs.AddOutput() is VSLib - CRASH in native L4D2. Use MaoLib.Mapper.ConnectOutput() or MaoLib.Mapper.AddOutput().'
            }
            $maoLibIssues += $issue
            $results.MaoLibIssues++
            Track-Issue $scriptName "CRITICAL"
        }

        if ($content -match 'compilestring.*return') {
            $issue = [PSCustomObject]@{
                Script = $scriptName
                Type = "MAOLIB_COMPILESTRING_RETURN"
                Severity = "CRITICAL"
                IssueText = 'compilestring(return + data)() pattern detected. Replace with MaoLib.ParseConfigString(data)'
            }
            $maoLibIssues += $issue
            $results.MaoLibIssues++
            Track-Issue $scriptName "CRITICAL"
        }
    }

    $criticalMaoLib = ($maoLibIssues | Where-Object { $_.Severity -eq "CRITICAL" }).Count
    $highMaoLib = ($maoLibIssues | Where-Object { $_.Severity -eq "HIGH" }).Count
    $warningMaoLib = ($maoLibIssues | Where-Object { $_.Severity -eq "WARNING" }).Count

    if ($maoLibIssues.Count -gt 0) {
        if ($criticalMaoLib -gt 0) { Write-Status "  MaoLib CRITICAL issues: $criticalMaoLib" "error" }
        if ($highMaoLib -gt 0) { Write-Status "  MaoLib HIGH issues: $highMaoLib" "warning" }
        if ($warningMaoLib -gt 0) { Write-Status "  MaoLib Warnings: $warningMaoLib" "warning" }

        if ($Verbose) {
            Write-Status "`n  --- MaoLib v2026 Details ---" "header"
            $patterns = $maoLibIssues | Group-Object Type
            foreach ($p in $patterns) {
                $color = switch ($p.Group[0].Severity) { "CRITICAL" { "Red" } "HIGH" { "Yellow" } default { "DarkGray" } }
                Write-Host "  [$($p.Name)] $($p.Count) issues:" -ForegroundColor $color
                $scriptGroups = $p.Group | Group-Object Script
                foreach ($sg in $scriptGroups) { Write-Host "    $($sg.Name)" -ForegroundColor $color }
                Write-Host "    FIX: $($p.Group[0].IssueText)" -ForegroundColor Cyan
            }
        }
    } else {
        Write-Status "  MaoLib v2026 validation passed!" "success"
    }
}

# ==============================================================================
# TEST 16: TIMER CLEANUP VALIDATION (NEW - CRITICAL)
# ==============================================================================
if ($CheckTimers -or $FullTest) {
    Write-Status "`n[TEST 16] Timer Cleanup Validation..." "info"
    Write-Status "  Detecting timers without cleanup, AddTimer used as one-shot, loop timers..." "info"

    $timerIssues = @()

    foreach ($scriptName in $scriptContents.Keys) {
        $rawContent = $scriptContents[$scriptName]
        if (-not $rawContent) { continue }
        
        # Strip comments for more accurate regex analysis
        $content = Remove-VScriptComments $rawContent

        # Find all timer creations with hardcoded names and intervals
        $timerCreations = [regex]::Matches($content, '(?:::\s*)?MaoLib\.(?:AddTimer|AddTimerSafe|AddTimerForce|AddTimerAuto)\s*\(\s*"([^"]+)"\s*,\s*([0-9.]+)\s*,')
        if ($timerCreations.Count -eq 0) { continue }

        $timerNames = $timerCreations | ForEach-Object { $_.Groups[1].Value }
        $timerIntervals = @{}
        foreach ($tc in $timerCreations) {
            $timerIntervals[$tc.Groups[1].Value] = [float]$tc.Groups[2].Value
        }

        # Check for round_end/mission_lost/map_transition handlers
        $hasRoundEnd = $content -match 'OnGameEvent_round_end|OnGameEvent_mission_lost|OnGameEvent_map_transition'
        
        # Check for cleanup functions that remove timers (e.g., _Cleanup() called by maprefresh_main)
        $hasExternalCleanup = $content -match 'function\s+_Cleanup\s*\(' -and $content -match 'RemoveTimer\s*\(|ClearAllTimers\s*\('

        # --- TIMER_NO_CLEANUP: No round_end handler at all ---
        if (-not $hasRoundEnd -and -not $hasExternalCleanup) {
            $issue = [PSCustomObject]@{
                Script = $scriptName
                Type = "TIMER_NO_CLEANUP"
                Severity = "HIGH"
                IssueText = "Creates timers but has NO round_end/mission_lost/map_transition handler. Timers persist between rounds."
            }
            $timerIssues += $issue
            $results.TimerIssues++
            Track-Issue $scriptName "WARNING"
            continue
        }

        # --- TIMER_CLEANUP_INCOMPLETE: Has round_end but no visible cleanup mechanism ---
        # We check the ENTIRE file for cleanup patterns, not just inside the round_end handler.
        # This catches helper functions like Shutdown(), Cleanup(), cleanupAll() called from round_end.
        $hasAnyRemoval = $content -match 'RemoveTimer\s*\(|ClearAllTimers\s*\('
        $hasCleanupFunc = $content -match '(?m)function\s+(?:Shutdown|Cleanup|ClearAll|cleanupAll|OnRoundEnd|_Cleanup|CleanupAll)\s*\('
        
        if (-not $hasAnyRemoval -and -not $hasCleanupFunc) {
            $issue = [PSCustomObject]@{
                Script = $scriptName
                Type = "TIMER_CLEANUP_INCOMPLETE"
                Severity = "WARNING"
                IssueText = "Has round_end handler but no RemoveTimer/ClearAllTimers or cleanup function found in file."
            }
            $timerIssues += $issue
            $results.TimerIssues++
            Track-Issue $scriptName "WARNING"
        }

        # --- TIMER_ONESHOT: Short interval (<=0.5s) without matching RemoveTimer ---
        # Check if script uses RemoveTimer at all (even with variables) - indicates timer discipline
        $hasAnyRemoveTimer = $content -match 'RemoveTimer\s*\('
        
        foreach ($timerName in $timerNames) {
            $interval = $timerIntervals[$timerName]
            if ($interval -le 0.5) {
                $escapedName = [regex]::Escape($timerName)
                # Check for matching RemoveTimer by timer name literal (supports ::MaoLib.RemoveTimer)
                $hasMatchingRemoval = $content -match ('RemoveTimer\s*\(\s*["'']' + $escapedName + '["'']')
                # Also check if timer name appears near RemoveTimer (variable-based removal like RemoveTimer(s._timerName))
                $hasVariableRemoval = $content -match ('RemoveTimer.*' + $escapedName)
                
                # If script has no RemoveTimer at all, flag it. If it has RemoveTimer (even variable-based), assume discipline.
                if (-not $hasMatchingRemoval -and -not $hasVariableRemoval -and -not $hasAnyRemoveTimer) {
                    $issue = [PSCustomObject]@{
                        Script = $scriptName
                        Type = "TIMER_ONESHOT"
                        Severity = "INFO"
                        IssueText = "Timer '$timerName' interval=${interval}s has no matching RemoveTimer. If one-shot, use MaoLib.DelayCall()."
                    }
                    $timerIssues += $issue
                    $results.TimerIssues++
                }
            }
        }

        # --- TIMER_DYNAMIC: Dynamic timer names (concatenation in name) ---
        $dynamicMatches = [regex]::Matches($content, '(?:::\s*)?MaoLib\.(?:AddTimer|AddTimerSafe)\s*\(\s*"[^"]*\+')
        if ($dynamicMatches.Count -gt 0) {
            $issue = [PSCustomObject]@{
                Script = $scriptName
                Type = "TIMER_DYNAMIC"
                Severity = "WARNING"
                IssueText = "Dynamic timer names make cleanup impossible. Use MaoLib.DelayCall() or store names in a table."
            }
            $timerIssues += $issue
            $results.TimerIssues++
            Track-Issue $scriptName "WARNING"
        }
    }

    $criticalTimer = ($timerIssues | Where-Object { $_.Severity -eq "CRITICAL" }).Count
    $highTimer = ($timerIssues | Where-Object { $_.Severity -eq "HIGH" }).Count
    $warningTimer = ($timerIssues | Where-Object { $_.Severity -eq "WARNING" }).Count
    $infoTimer = ($timerIssues | Where-Object { $_.Severity -eq "INFO" }).Count

    if ($timerIssues.Count -gt 0) {
        if ($criticalTimer -gt 0) { Write-Status "  Timer CRITICAL issues: $criticalTimer" "error" }
        if ($highTimer -gt 0) { Write-Status "  Timer HIGH issues: $highTimer" "warning" }
        if ($warningTimer -gt 0) { Write-Status "  Timer Warnings: $warningTimer" "warning" }
        if ($infoTimer -gt 0) { Write-Status "  Timer Info: $infoTimer" "info" }

        if ($Verbose) {
            Write-Status "`n  --- Timer Cleanup Details ---" "header"
            $patterns = $timerIssues | Group-Object Type
            foreach ($p in $patterns) {
                $color = switch ($p.Group[0].Severity) { "CRITICAL" { "Red" } "HIGH" { "Yellow" } "WARNING" { "Yellow" } default { "DarkGray" } }
                Write-Host "  [$($p.Name)] $($p.Count) issues:" -ForegroundColor $color
                $scriptGroups = $p.Group | Group-Object Script
                foreach ($sg in $scriptGroups) { Write-Host "    $($sg.Name)" -ForegroundColor $color }
                Write-Host "    FIX: $($p.Group[0].IssueText)" -ForegroundColor Cyan
            }
        }
    } else {
        Write-Status "  All timers properly managed!" "success"
    }
}

# ==============================================================================
# TEST 17: NATIVE API MISUSE (NEW)
# ==============================================================================
if ($CheckNatives -or $FullTest) {
    Write-Status "`n[TEST 17] Native API Misuse Detection..." "info"
    Write-Status "  Detecting methods called as globals and globals called as methods..." "info"

    $nativeIssues = @()

    foreach ($scriptName in $scriptContents.Keys) {
        $content = $scriptContents[$scriptName]
        if (-not $content) { continue }
        $lines = $content -split "`n"

        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]

            foreach ($method in $nativeMethods) {
                $pattern = '(?<!\.|::)\b' + [regex]::Escape($method) + '\s*\('
                if ($line -match $pattern) {
                    $prevChar = $line.Substring(0, $matches[0].Index)
                    if (-not ($prevChar -match '\.\s*$')) {
                        $issue = [PSCustomObject]@{
                            Script = $scriptName
                            Line = $i + 1
                            Type = "NATIVE_METHOD_AS_GLOBAL"
                            Severity = "HIGH"
                            IssueText = "$method() is a METHOD, not a global function. Called as global will fail."
                        }
                        $nativeIssues += $issue
                        $results.NativeMisuse++
                        Track-Issue $scriptName "WARNING"
                    }
                }
            }

            foreach ($globalFn in $nativeGlobals) {
                $pattern = '\.(?:\w+\.)*' + [regex]::Escape($globalFn) + '\s*\('
                if ($line -match $pattern) {
                    $issue = [PSCustomObject]@{
                        Script = $scriptName
                        Line = $i + 1
                        Type = "NATIVE_GLOBAL_AS_METHOD"
                        Severity = "HIGH"
                        IssueText = "$globalFn() is a GLOBAL function, not a method. Use $globalFn(entity) instead."
                    }
                    $nativeIssues += $issue
                    $results.NativeMisuse++
                    Track-Issue $scriptName "WARNING"
                }
            }

            if ($line -match '\bGetEntityByHandle\s*\(') {
                $issue = [PSCustomObject]@{
                    Script = $scriptName
                    Line = $i + 1
                    Type = "NATIVE_NONEXISTENT"
                    Severity = "CRITICAL"
                    IssueText = "GetEntityByHandle() does NOT exist in L4D2 VScript. Use EntIndexToHScript() or GetPlayerFromUserID()."
                }
                $nativeIssues += $issue
                $results.NativeMisuse++
                Track-Issue $scriptName "CRITICAL"
            }
        }
    }

    $criticalNative = ($nativeIssues | Where-Object { $_.Severity -eq "CRITICAL" }).Count
    $highNative = ($nativeIssues | Where-Object { $_.Severity -eq "HIGH" }).Count

    if ($nativeIssues.Count -gt 0) {
        if ($criticalNative -gt 0) { Write-Status "  Native CRITICAL issues: $criticalNative" "error" }
        if ($highNative -gt 0) { Write-Status "  Native HIGH issues: $highNative" "warning" }
        if ($Verbose) {
            Write-Status "`n  --- Native API Details ---" "header"
            $patterns = $nativeIssues | Group-Object Type
            foreach ($p in $patterns) {
                $color = if ($p.Group[0].Severity -eq "CRITICAL") { "Red" } else { "Yellow" }
                Write-Host "  [$($p.Name)] $($p.Count) issues:" -ForegroundColor $color
                $scriptGroups = $p.Group | Group-Object Script
                foreach ($sg in $scriptGroups) {
                    Write-Host "    $($sg.Name) ($($sg.Count)x)" -ForegroundColor $color
                    if ($sg.Count -le 3) {
                        foreach ($item in $sg.Group) {
                            Write-Host "      Line $($item.Line): $($item.IssueText)" -ForegroundColor DarkGray
                        }
                    }
                }
            }
        }
    } else {
        Write-Status "  No native API misuse detected!" "success"
    }
}

# ==============================================================================
# TEST 18: LOOP-VARIABLE CLOSURE CAPTURE (NEW)
# ==============================================================================
if ($CheckClosures -or $FullTest) {
    Write-Status "`n[TEST 18] Loop-Variable Closure Capture Detection..." "info"
    Write-Status "  Detecting closures inside loops that capture loop variables by reference..." "info"

    $closureIssues = @()

    foreach ($scriptName in $scriptContents.Keys) {
        $content = $scriptContents[$scriptName]
        if (-not $content) { continue }
        $lines = $content -split "`n"

        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]

            if ($line -match '\b(foreach|while|for)\b') {
                $loopStart = $i
                $loopVar = $null

                if ($line -match 'foreach\s*\(\s*(?:local\s+)?(\w+)\s+in\s') {
                    $loopVar = $matches[1]
                } elseif ($line -match 'while\s*\(\s*(?:local\s+)?(\w+)\s*=\s*') {
                    $loopVar = $matches[1]
                }

                if (-not $loopVar) { continue }

                $braceDepth = 0
                $inBlock = $false
                $loopEnd = $i
                for ($j = $i; $j -lt $lines.Count; $j++) {
                    $checkLine = $lines[$j]
                    if ($checkLine -match '\{') { $braceDepth++; $inBlock = $true }
                    if ($checkLine -match '\}') { $braceDepth-- }
                    if ($inBlock -and $braceDepth -le 0) { $loopEnd = $j; break }
                }

                for ($j = $loopStart; $j -le $loopEnd; $j++) {
                    if ($lines[$j] -match '\bfunction\s*\(' -or $lines[$j] -match '@\s*\(') {
                        $closureStart = $j
                        $closureEnd = $closureStart
                        $cbDepth = 0
                        $inCb = $false
                        for ($k = $j; $k -le $loopEnd; $k++) {
                            if ($lines[$k] -match '\{') { $cbDepth++; $inCb = $true }
                            if ($lines[$k] -match '\}') { $cbDepth-- }
                            if ($inCb -and $cbDepth -le 0) { $closureEnd = $k; break }
                        }

                        $closureUsesLoopVar = $false
                        $hasLocalCopy = $false
                        for ($k = $closureStart; $k -le $closureEnd; $k++) {
                            if ($lines[$k] -match '\b' + [regex]::Escape($loopVar) + '\b') {
                                $closureUsesLoopVar = $true
                            }
                        }

                        for ($k = $loopStart; $k -lt $closureStart; $k++) {
                            if ($lines[$k] -match 'local\s+\w+\s*=\s*\b' + [regex]::Escape($loopVar) + '\b') {
                                $hasLocalCopy = $true
                            }
                        }

                        if ($closureUsesLoopVar -and -not $hasLocalCopy) {
                            $issue = [PSCustomObject]@{
                                Script = $scriptName
                                Line = $j + 1
                                Type = "CLOSURE_LOOP_CAPTURE"
                                Severity = "HIGH"
                                IssueText = "Closure inside loop captures $loopVar by REFERENCE. Fix: add local captured = $loopVar before the closure."
                            }
                            $closureIssues += $issue
                            $results.ClosureIssues++
                            Track-Issue $scriptName "WARNING"
                        }
                    }
                }
            }
        }
    }

    if ($closureIssues.Count -gt 0) {
        Write-Status "  Closure capture issues: $($closureIssues.Count)" "warning"
        if ($Verbose) {
            Write-Status "`n  --- Closure Capture Details ---" "header"
            $scriptGroups = $closureIssues | Group-Object Script
            foreach ($sg in $scriptGroups) {
                Write-Host "  $($sg.Name) ($($sg.Count)x)" -ForegroundColor Yellow
                foreach ($issue in $sg.Group) {
                    Write-Host "    Line $($issue.Line): $($issue.IssueText)" -ForegroundColor DarkGray
                }
            }
        }
    } else {
        Write-Status "  No closure capture issues detected!" "success"
    }
}

# ==============================================================================
# TEST 19: SELF-CONTAINED OPERATIONS (NEW)
# ==============================================================================
if ($FullTest) {
    Write-Status "`n[TEST 19] Self-Contained Operations Validation..." "info"
    Write-Status "  Detecting deferred logic on entities that may die between frames..." "info"

    $selfContainedIssues = @()

    foreach ($scriptName in $scriptContents.Keys) {
        $content = $scriptContents[$scriptName]
        if (-not $content) { continue }
        $lines = $content -split "`n"

        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]

            if ($line -match 'EntFire\s*\(\s*"[^"]*"\s*,\s*"RunScriptCode"\s*,\s*"[^"]*EntIndexToHScript[^"]*"') {
                $issue = [PSCustomObject]@{
                    Script = $scriptName
                    Line = $i + 1
                    Type = "SELF_ENTINDEX_DELAY"
                    Severity = "HIGH"
                    IssueText = "EntFire + RunScriptCode + EntIndexToHScript with delay: entindex slot may be reassigned."
                }
                $selfContainedIssues += $issue
                Track-Issue $scriptName "WARNING"
            }

            if ($line -match 'DoEntFire\s*\(\s*"!self"\s*,\s*"RunScriptCode"') {
                $issue = [PSCustomObject]@{
                    Script = $scriptName
                    Line = $i + 1
                    Type = "SELF_DODELAY"
                    Severity = "HIGH"
                    IssueText = "DoEntFire with !self RunScriptCode and delay: entity may die before script runs."
                }
                $selfContainedIssues += $issue
                Track-Issue $scriptName "WARNING"
            }

            if ($line -match '(\w+)\s*=\s*\.?entindex\s*\(\s*\)') {
                $varName = $matches[1]
                $usedLater = $false
                for ($j = $i + 1; $j -lt $lines.Count; $j++) {
                    if ($lines[$j] -match ("EntIndexToHScript\s*\(\s*" + $varName + "\s*\)")) {
                        $usedLater = $true
                        break
                    }
                }
                if ($usedLater) {
                    $issue = [PSCustomObject]@{
                        Script = $scriptName
                        Line = $i + 1
                        Type = "SELF_STORED_ENTINDEX"
                        Severity = "HIGH"
                        IssueText = "$varName stores entindex for later use. Slot may be reassigned. Capture entity in closure instead."
                    }
                    $selfContainedIssues += $issue
                    Track-Issue $scriptName "WARNING"
                }
            }

            if ($line -match '::\w+\s*<-\s*(\w+)') {
                $storedVar = $matches[1]
                if ($storedVar -notmatch '^(true|false|null|\d)') {
                    $issue = [PSCustomObject]@{
                        Script = $scriptName
                        Line = $i + 1
                        Type = "SELF_GLOBAL_ENTITY_REF"
                        Severity = "INFO"
                        IssueText = "Storing entity reference in global table. Entity may become invalid. Always guard with IsValid()."
                    }
                    $selfContainedIssues += $issue
                }
            }
        }
    }

    if ($selfContainedIssues.Count -gt 0) {
        Write-Status "  Self-contained operation issues: $($selfContainedIssues.Count)" "warning"
        if ($Verbose) {
            Write-Status "`n  --- Self-Contained Details ---" "header"
            $patterns = $selfContainedIssues | Group-Object Type
            foreach ($p in $patterns) {
                Write-Host "  [$($p.Name)] $($p.Count) issues:" -ForegroundColor Yellow
                $scriptGroups = $p.Group | Group-Object Script
                foreach ($sg in $scriptGroups) { Write-Host "    $($sg.Name)" -ForegroundColor Yellow }
                Write-Host "    FIX: $($p.Group[0].IssueText)" -ForegroundColor Cyan
            }
        }
    } else {
        Write-Status "  All operations are self-contained!" "success"
    }
}
# ==============================================================================
# FINAL SUMMARY
# ==============================================================================
Write-Status "`n=== FINAL TEST SUMMARY ===" "header"
Write-Host "  Total scripts analyzed:   $($results.TotalFiles)" -ForegroundColor Cyan
Write-Host "`n  Issues by category:" -ForegroundColor White

$issueLabels = [ordered]@{
    "Syntax Errors"        = $results.SyntaxErrors
    "Missing Includes"     = $results.MissingIncludes
    "Thinker Issues"       = $results.ThinkerIssues
    "Event Conflicts"      = $results.EventConflicts
    "Invalid Events"       = $results.InvalidEvents
    "Global Conflicts"     = $results.GlobalConflicts
    "Convar Conflicts"     = $results.ConvarConflicts
    "Function Conflicts"   = $results.FunctionConflicts
    "Edge Cases"           = $results.EdgeCaseIssues
    "VSLib Usage"          = $results.VSLibUsage
    "Deprecated Usage"     = $results.DeprecatedUsage
    "Entity Leak Risks"    = $results.EntityLeakRisks
    "Callstack Critical"   = $results.CallstackErrors
    "Callstack Warnings"   = $results.CallstackWarnings
    "LLM Critical"         = $results.LLMErrors
    "LLM Warnings"         = $results.LLMWarnings
    "Loading Crash"        = $results.LoadingCrash
    "Runtime Crash"        = $results.RuntimeCrash
    "Dependency Issues"    = $results.DependencyIssues
    "MaoLib v2026 Issues"  = $results.MaoLibIssues
    "Timer Issues"         = $results.TimerIssues
    "Native Misuse"        = $results.NativeMisuse
    "Closure Issues"       = $results.ClosureIssues
}

$totalCritical = 0
$totalWarnings = 0

foreach ($label in $issueLabels.Keys) {
    $count = $issueLabels[$label]
    if ($count -gt 0) {
        if ($label -match "Critical|VSLib|Loading Crash|Runtime Crash|MaoLib.*Issues|Native Misuse|Invalid Events") {
            Write-Host "    $label : $count" -ForegroundColor Red
            $totalCritical += $count
        } else {
            Write-Host "    $label : $count" -ForegroundColor Yellow
            $totalWarnings += $count
        }
    } else {
        Write-Host "    $label : 0" -ForegroundColor Green
    }
}

$totalIssues = ($issueLabels.Values | Measure-Object -Sum).Sum

# Compute per-addon totals from fileStats
$addonTotals = @{}
foreach ($name in $fileStats.Keys) {
    $s = $fileStats[$name]
    $a = $s.Addon
    if (-not $addonTotals[$a]) { $addonTotals[$a] = @{ Criticals = 0; Warnings = 0 } }
    $addonTotals[$a].Criticals += $s.Criticals
    $addonTotals[$a].Warnings += $s.Warnings
}

Write-Status "`n  Addon issue breakdown:" "info"
foreach ($addon in ($addonTotals.Keys | Sort-Object)) {
    $c = $addonTotals[$addon].Criticals
    $w = $addonTotals[$addon].Warnings
    $total = $c + $w
    if ($total -eq 0) { continue }
    $color = if ($c -gt 0) { "Red" } elseif ($w -gt 0) { "Yellow" } else { "Green" }
    Write-Host ("    {0,-30} {1,4} critical, {2,4} warnings" -f $addon, $c, $w) -ForegroundColor $color
}

$topOffenders = @($fileStats.Keys | Where-Object { $fileStats[$_].Criticals -gt 0 -or $fileStats[$_].Warnings -gt 0 } | Sort-Object { $fileStats[$_].Criticals + $fileStats[$_].Warnings } -Descending | Select-Object -First 10)
if ($topOffenders.Count -gt 0) {
    Write-Status "`n  Top offenders:" "info"
    foreach ($name in $topOffenders) {
        $s = $fileStats[$name]
        $addon = $s.Addon
        if (-not $addon) { $addon = "?" }
        $color = if ($s.Criticals -gt 0) { "Red" } elseif ($s.Warnings -gt 0) { "Yellow" } else { "Gray" }
        $totalIssuesForFile = $s.Criticals + $s.Warnings
        Write-Host ("    {1,-30} {2,3} critical, {3,3} warnings ({4,3} total) [{0}]" -f $addon, $name, $s.Criticals, $s.Warnings, $totalIssuesForFile) -ForegroundColor $color
    }
}

Write-Status "`n=== VERDICT ===" "header"
if ($totalIssues -eq 0) {
    Write-Status "[PASS] ALL TESTS PASSED - No issues detected!" "success"
    exit 0
} elseif ($totalCritical -eq 0) {
    Write-Status "[WARN] $totalIssues issues found (no critical) - review recommended" "warning"
    Write-Status "Run with -Verbose for details" "info"
    exit 0
} else {
    Write-Status "[FAIL] $totalCritical CRITICAL issues + $totalWarnings warnings found!" "error"
    Write-Status "Run with -Verbose for details" "info"
    exit 1
}
