//=============================================================================
// l4c_music_core.nut — Núcleo del VScript Music Manager
// Namespace: ::L4C_Music
// Parte del L4C VScript Music Manager
//=============================================================================
// Gestiona:
//  - 2 entidades ambient_generic para crossfade
//  - Cola de prioridades con interrupción
//  - Cooldowns por categoría
//  - Estados (SAFE, AMBULATORY, COMBAT, BOSS, DEATH, SILENCE)
//  - Debug con 3 niveles
//=============================================================================

//=========================================
// NAMESPACE
//=========================================
if (!("L4C_Music" in getroottable())) ::L4C_Music <- {}
if (!("L4C_Music_Events" in getroottable())) ::L4C_Music_Events <- {}

//=========================================
// CONSTANTES DE PRIORIDAD
//=========================================
::L4C_Music.PRIORITY <- {
    CRITICAL    = 100,    // Interrumpe TODO (Tank, BossWave, LastManStanding)
    HIGH        = 80,     // Interrumpe MED/LOW (Horde, NearDeath)
    MEDIUM      = 60,     // Interrumpe LOW (Defib, Heal, Bile)
    LOW         = 40,     // No interrumpe (Rescue, Silence, SafeRoom)
    AMBIENT     = 20      // Background loops
}

//=========================================
// ESTADOS DEL SISTEMA
//=========================================
::L4C_Music.STATE <- {
    OFF         = 0,
    SAFE        = 1,      // En saferoom
    AMBULATORY  = 2,      // Explorando, sin combate
    COMBAT      = 3,      // En combate activo
    BOSS        = 4,      // Boss (Tank/Witch aggro)
    DEATH       = 5,      // Muerte/derrota inminente
    SILENCE     = 6       // Silencio programado (post-combate)
}

//=========================================
// VARIABLES DE ESTADO
//=========================================
::L4C_Music.CurrentState <- ::L4C_Music.STATE.OFF
::L4C_Music.CurrentPriority <- 0
::L4C_Music.CurrentCategory <- ""
::L4C_Music.Debug <- 1          // 0=quiet, 1=info, 2=verbose

// Entidades ambient_generic para crossfade
::L4C_Music.ambActive <- null
::L4C_Music.ambStandby <- null
::L4C_Music.bInit <- false

// Contadores de estado
::L4C_Music.ActiveTanks <- 0
::L4C_Music.ActiveWitches <- 0
::L4C_Music.AliveSurvivors <- 4
::L4C_Music.IncapacitatedCount <- 0
::L4C_Music.WitchRaged <- false     // Track si witch fue enfadada
::L4C_Music.LastCombatTime <- 0     // Timestamp último evento de combate

// Cooldowns: { category: nextAllowedTime }
::L4C_Music.Cooldowns <- {}
::L4C_Music.SilenceTimerActive <- false

//=========================================
// DEBUG
//=========================================
::L4C_Music.Dbg <- function(msg, level = 1)
{
    if (::L4C_Music.Debug >= level)
        printl("[L4C_Music] " + msg)
}

::L4C_Music.DbgWarn <- function(msg)
{
    printl("[L4C_Music][WARN] " + msg)
}

//=========================================
// INICIALIZACIÓN
//=========================================
::L4C_Music.Init <- function()
{
    ::L4C_Music.Dbg("Init() — Creando entidades ambient_generic", 1)

    // Spawn 2 ambient_generic para crossfade
    local origin = Vector(0, 0, 0)

    ::L4C_Music.ambActive = SpawnEntityFromTable("ambient_generic", {
        origin = origin,
        targetname = "l4c_music_active",
        message = "common/null.wav",
        health = 1.0,
        spawnflags = 1,         // Start silent
        preset = 0,
        volstart = 0,
        fadeinc = 0,
        fadedec = 0,
        SourceEntityName = "",
        radius = 10000,
        pitch = 100,
        spinup = 0,
        spindown = 0,
        lfotype = 0,
        lforate = 0,
        lfomodpitch = 0,
        lfomodvol = 0,
    })

    ::L4C_Music.ambStandby = SpawnEntityFromTable("ambient_generic", {
        origin = origin,
        targetname = "l4c_music_standby",
        message = "common/null.wav",
        health = 1.0,
        spawnflags = 1,         // Start silent
        preset = 0,
        volstart = 0,
        fadeinc = 0,
        fadedec = 0,
        SourceEntityName = "",
        radius = 10000,
        pitch = 100,
        spinup = 0,
        spindown = 0,
        lfotype = 0,
        lforate = 0,
        lfomodpitch = 0,
        lfomodvol = 0,
    })

    // Dispatch spawn en ambas
    ::L4C_Music.ambActive.DispatchSpawn()
    ::L4C_Music.ambStandby.DispatchSpawn()

    ::L4C_Music.bInit = true
    ::L4C_Music.CurrentState = ::L4C_Music.STATE.SAFE
    ::L4C_Music.LastCombatTime = Time()

    // Iniciar vigilancia de calma
    ::L4C_Music.StartCalmWatch()

    ::L4C_Music.Dbg("Init() — Entidades creadas OK. CalmWatch iniciado.", 1)
}

//=========================================
// COOLDOWN SYSTEM
//=========================================
::L4C_Music.IsCooldownReady <- function(category)
{
    if (!(category in ::L4C_Music.Cooldowns)) return true
    return Time() >= ::L4C_Music.Cooldowns[category]
}

::L4C_Music.SetCooldown <- function(category, seconds)
{
    ::L4C_Music.Cooldowns[category] <- Time() + seconds
    ::L4C_Music.Dbg("Cooldown set '" + category + "' → " + seconds + "s", 2)
}

//=========================================
// CROSSFADE ENGINE
//=========================================
::L4C_Music.Crossfade <- function(newTrack, newPriority, newCategory)
{
    if (!::L4C_Music.bInit) {
        ::L4C_Music.DbgWarn("Crossfade() llamado sin Init()")
        return
    }

    // Si no hay track (cadena vacía), solo silenciar
    if (newTrack == "") {
        ::L4C_Music.Dbg("Crossfade() — Track vacío, silenciando", 1)
        DoEntFire("!self", "FadeOut", "2.0", 0, null, ::L4C_Music.ambActive)
        ::L4C_Music.CurrentPriority = 0
        ::L4C_Music.CurrentCategory = ""
        return
    }

    ::L4C_Music.Dbg("Crossfade() → " + newTrack + " (prio:" + newPriority + ")", 1)

    // 1. Silenciar activo con fade
    DoEntFire("!self", "FadeOut", "1.5", 0, null, ::L4C_Music.ambActive)

    // 2. Configurar standby con el nuevo track (delay para que fade out inicie)
    MaoLib.AddTimer("l4c_music_swap", 0.3, function() {
        // Cambiar wave en standby
        ::L4C_Music.ambStandby.__KeyValueFromString("message", newTrack)

        // Iniciar standby
        DoEntFire("!self", "PlaySound", "", 0, null, ::L4C_Music.ambStandby)
        DoEntFire("!self", "Volume", "1.0", 0.2, null, ::L4C_Music.ambStandby)

        ::L4C_Music.Dbg("Swap: standby ahora suena '" + newTrack + "'", 2)

        // 3. Swap references después del fade
        MaoLib.AddTimer("l4c_music_swap_commit", 2.0, function() {
            // Detener completamente el anterior
            DoEntFire("!self", "StopSound", "", 0, null, ::L4C_Music.ambActive)

            // Intercambiar referencias
            local temp = ::L4C_Music.ambActive
            ::L4C_Music.ambActive = ::L4C_Music.ambStandby
            ::L4C_Music.ambStandby = temp

            ::L4C_Music.CurrentPriority = newPriority
            ::L4C_Music.CurrentCategory = newCategory
            ::L4C_Music.Dbg("Swap completado → active: '" + newTrack + "'", 1)
        })
    })
}

//=========================================
// TRIGGER EVENT — Punto de entrada único
//=========================================
::L4C_Music.TriggerEvent <- function(category, priority, cooldownSec, trackPath = null)
{
    ::L4C_Music.Dbg("TriggerEvent('" + category + "', prio:" + priority + ")", 1)

    // Verificar cooldown
    if (!::L4C_Music.IsCooldownReady(category)) {
        local remaining = ::L4C_Music.Cooldowns[category] - Time()
        ::L4C_Music.Dbg("  Cooldown activo para '" + category + "', faltan " + remaining.tostring() + "s", 1)
        return false
    }

    // Verificar prioridad
    if (priority < ::L4C_Music.CurrentPriority) {
        ::L4C_Music.Dbg("  Prioridad " + priority + " < actual " + ::L4C_Music.CurrentPriority + " — DESCARTADO", 1)
        return false
    }

    // Obtener track
    if (trackPath == null)
        trackPath = ::L4C_Music.GetTrack(category)

    // Ejecutar crossfade
    ::L4C_Music.Crossfade(trackPath, priority, category)

    // Set cooldown
    if (cooldownSec > 0)
        ::L4C_Music.SetCooldown(category, cooldownSec)

    // Actualizar estado según categoría
    ::L4C_Music.UpdateState(category)

    return true
}

//=========================================
// UPDATE STATE
//=========================================
::L4C_Music.UpdateState <- function(category)
{
    switch (category)
    {
        case "Tank":
        case "BossWave":
            ::L4C_Music.CurrentState = ::L4C_Music.STATE.BOSS
            break
        case "Horde":
        case "PZAttack":
        case "NearDeath":
            ::L4C_Music.CurrentState = ::L4C_Music.STATE.COMBAT
            break
        case "LastManStanding":
        case "LowHealth":
            ::L4C_Music.CurrentState = ::L4C_Music.STATE.DEATH
            break
        case "Calm":
            ::L4C_Music.CurrentState = ::L4C_Music.STATE.AMBULATORY
            break
        case "RescueCloset":
        case "SafeRoom":
            ::L4C_Music.CurrentState = ::L4C_Music.STATE.SAFE
            break
        case "Silence":
            ::L4C_Music.CurrentState = ::L4C_Music.STATE.SILENCE
            break
        default:
            ::L4C_Music.CurrentState = ::L4C_Music.STATE.AMBULATORY
            break
    }
    ::L4C_Music.Dbg("Estado → " + ::L4C_Music.CurrentState, 2)
}

//=========================================
// CALM WATCH — 90s sin violencia → Calm
//=========================================
::L4C_Music.StartCalmWatch <- function()
{
    MaoLib.RemoveTimer("l4c_music_calm_watch")
    MaoLib.AddTimer("l4c_music_calm_watch", 5.0, function() {
        if (!::L4C_Music.bInit) return
        if (::L4C_Music.CurrentCategory == "Calm") return   // Ya sonando
        if (::L4C_Music.CurrentPriority > ::L4C_Music.PRIORITY.AMBIENT) return

        if (Time() - ::L4C_Music.LastCombatTime >= 90) {
            ::L4C_Music.Dbg("90s sin violencia → Calm", 1)
            ::L4C_Music.TriggerEvent("Calm",
                ::L4C_Music.PRIORITY.AMBIENT, 0)
        }
    })
}

::L4C_Music.ResetCalmTimer <- function()
{
    ::L4C_Music.LastCombatTime = Time()
}

//=========================================
// STOP MUSIC
//=========================================
::L4C_Music.StopAll <- function(fadeOut = 2.0)
{
    if (!::L4C_Music.bInit) return
    ::L4C_Music.Dbg("StopAll() — fade:" + fadeOut + "s", 1)
    DoEntFire("!self", "FadeOut", fadeOut.tostring(), 0, null, ::L4C_Music.ambActive)
    DoEntFire("!self", "StopSound", "", (fadeOut + 0.5).tostring(), null, ::L4C_Music.ambActive)
    ::L4C_Music.CurrentPriority = 0
    ::L4C_Music.CurrentCategory = ""
    ::L4C_Music.CurrentState = ::L4C_Music.STATE.SAFE
}

//=========================================
// RESET (round_end / mission_lost)
//=========================================
::L4C_Music.Reset <- function()
{
    ::L4C_Music.Dbg("Reset()", 1)
    ::L4C_Music.StopAll(1.0)
    ::L4C_Music.ActiveTanks = 0
    ::L4C_Music.ActiveWitches = 0
    ::L4C_Music.AliveSurvivors = 4
    ::L4C_Music.IncapacitatedCount = 0
    ::L4C_Music.Cooldowns = {}
    ::L4C_Music.SilenceTimerActive = false
    ::L4C_Music.WitchRaged = false
    ::L4C_Music.LastCombatTime = 0
    ::L4C_Music.CurrentState = ::L4C_Music.STATE.OFF
    MaoLib.RemoveTimer("l4c_music_calm_watch")
    ::L4C_Music.bInit = false
    ::L4C_Music.ambActive = null
    ::L4C_Music.ambStandby = null
}
