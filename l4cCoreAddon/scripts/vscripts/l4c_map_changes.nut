// l4c_map_changes.nut — Ajustes por mapa + Color Correction + Difficulty Scaling
// ♻️ 2026-07-02: Renombrado de lost4creet_map_changes.nut (typo fix).
// ♻️ 2026-07-02: Simplificado — sin tier system, sin magic multipliers.
// ♻️ 2026-07-02: Añadidos z_spawn_safety_range y horde_freq_mult por mapa.
//                horde_freq_mult es UN número que se multiplica por diff_freq_mult
//                en DifficultyScale para derivar los 4 sufijos de z_mob_spawn_*_interval.
//
// ESTRUCTURA:
//   1. SetCommonLimit / SetSpecialInterval / SetSafetyRange / SetHordeFreq por mapa
//      (include-time, lectura estática)
//   2. L4C_DifficultyScale — 4 valores planos por dificultad + escala de hordas
//      - Hook en OnGameEvent_round_start_post_nav (DESPUÉS de los Set* include-time)
//      - Lee la dificultad y aplica notify/behind/ghosts + z_mob_spawn_*_interval
//   3. L4C_CC_Loader — Color Correction (igual que antes)
//
// CAMPAÑAS CON HAMMER EDITS (Hopeless, Plan B, Dead Flag Blues, Aftershock):
//   NO se modifican. Sin common_limit ni CC.
// CAMPAÑAS CON CC NATIVA EN BSP (deathrow, derailed, fallindeath, noparking, zmb):
//   El BSP ya referencia su .raw. NO se tocan para CC. Solo common_limit + scale.
// CAMPAÑAS SIN CC NATIVA (heavencanwait, lockdown, urbanflight, zero warning, overkill):
//   CC + common_limit + scale.

// ════════════════════════════════════════════════════════════
// PARTE ESTÁTICA — Ajustes de common_limit y special_interval por mapa
// Se ejecuta en include-time (Director.GetMapName() disponible).
// Los valores NO se sobreescriben con scale — son overrides directos.
// ════════════════════════════════════════════════════════════

// Helper para no repetir Convars + DirectorOptions
::SetCommonLimit <- function(val) {
    local s = "" + val
    Convars.SetValue("z_common_limit", s)
    DirectorOptions.cm_CommonLimit = val
}

// Helper para SpecialRespawnInterval (no se setea en DirectorOptions, solo convar)
::SetSpecialInterval <- function(val) {
    local s = "" + val
    Convars.SetValue("SpecialRespawnInterval", s)
}

// Helper para z_spawn_safety_range (distancia mínima de spawn de SI)
::SetSafetyRange <- function(val) {
    local s = "" + val
    Convars.SetValue("z_spawn_safety_range", s)
}

// Helper para horde_freq_mult (>1.0 = hordas más frecuentes, <1.0 = menos frecuentes)
// Solo guarda el valor — el DifficultyScale lo lee en round_start_post_nav y aplica
// los 4 sufijos de z_mob_spawn_*_interval.
::SetHordeFreq <- function(mult) {
    ::L4C_CurrentHordeFreqMult = mult
}

// Default 1.0 — los mapas que no llamen SetHordeFreq mantienen hordas a frecuencia vanilla
::L4C_CurrentHordeFreqMult <- 1.0

// ── heavencanwait — introducción gentil, santuario en el finale ──
if(Director.GetMapName() == "hcw1_aircrash")  { SetCommonLimit(20); SetSpecialInterval(90); SetSafetyRange(1200); SetHordeFreq(0.7) }
if(Director.GetMapName() == "hcw2_rivermotel") { SetCommonLimit(25); SetSpecialInterval(80); SetSafetyRange(900);  SetHordeFreq(0.85) }
if(Director.GetMapName() == "hcw3_outskirts")  { SetCommonLimit(35); SetSpecialInterval(60); SetSafetyRange(350);  SetHordeFreq(1.0) }
if(Director.GetMapName() == "hcw4_cityhall")   { SetCommonLimit(40); SetSpecialInterval(45); SetSafetyRange(500);  SetHordeFreq(1.2) }
if(Director.GetMapName() == "hcw5_bombshelter") { SetCommonLimit(15); SetSpecialInterval(120); SetSafetyRange(2000); SetHordeFreq(0.5) }  // santuario

// ── lockdown — bt4 gauntlet clásico, bt5 caos finale ──
if(Director.GetMapName() == "bt1") { SetCommonLimit(20); SetSpecialInterval(90); SetSafetyRange(1000); SetHordeFreq(0.7) }
if(Director.GetMapName() == "bt2") { SetCommonLimit(30); SetSpecialInterval(60); SetSafetyRange(800);  SetHordeFreq(1.0) }
if(Director.GetMapName() == "bt3") { SetCommonLimit(40); SetSpecialInterval(45); SetSafetyRange(700);  SetHordeFreq(1.0) }
if(Director.GetMapName() == "bt4") { SetCommonLimit(50); SetSpecialInterval(25); SetSafetyRange(900);  SetHordeFreq(2.0) }  // gauntlet
if(Director.GetMapName() == "bt5") { SetCommonLimit(60); SetSpecialInterval(20); SetSafetyRange(600);  SetHordeFreq(2.5) }  // caos finale

// ── urbanflight — progresivo clásico, uf4 airfield pista enorme ──
if(Director.GetMapName() == "uf1_boulevard") { SetCommonLimit(15); SetSpecialInterval(90); SetSafetyRange(1200); SetHordeFreq(0.7) }
if(Director.GetMapName() == "uf2_rooftops")  { SetCommonLimit(25); SetSpecialInterval(70); SetSafetyRange(700);  SetHordeFreq(0.85) }
if(Director.GetMapName() == "uf3_harbor")    { SetCommonLimit(40); SetSpecialInterval(45); SetSafetyRange(500);  SetHordeFreq(1.2) }
if(Director.GetMapName() == "uf4_airfield")  { SetCommonLimit(55); SetSpecialInterval(30); SetSafetyRange(400);  SetHordeFreq(1.5) }  // pista enorme

// ── zero warning — extremo desde el inicio ──
if(Director.GetMapName() == "zerowarn_1r") { SetCommonLimit(40); SetSpecialInterval(40); SetSafetyRange(600); SetHordeFreq(1.3) }
if(Director.GetMapName() == "zerowarn_2r") { SetCommonLimit(50); SetSpecialInterval(30); SetSafetyRange(450); SetHordeFreq(1.6) }
if(Director.GetMapName() == "zerowarn_3r") { SetCommonLimit(65); SetSpecialInterval(20); SetSafetyRange(300); SetHordeFreq(2.0) }

// ── overkill — progresivo con finale largo ──
if(Director.GetMapName() == "evac2")        { SetCommonLimit(20); SetSpecialInterval(90); SetSafetyRange(1000); SetHordeFreq(0.7) }
if(Director.GetMapName() == "gasrun")       { SetCommonLimit(35); SetSpecialInterval(60); SetSafetyRange(800);  SetHordeFreq(1.0) }
if(Director.GetMapName() == "gasrunpart2")  { SetCommonLimit(45); SetSpecialInterval(40); SetSafetyRange(600);  SetHordeFreq(1.2) }
if(Director.GetMapName() == "gr-mapone-7")  { SetCommonLimit(55); SetSpecialInterval(25); SetSafetyRange(400);  SetHordeFreq(1.8) }  // finale largo

// ── campañas con CC nativa (solo common_limit + interval) ──

// Death Row
if(Director.GetMapName() == "deathrow01_streets") { SetCommonLimit(36); SetSpecialInterval(50); SetSafetyRange(700); SetHordeFreq(1.0) }

// No Parking — tranquilo
if(Director.GetMapName() == "noparking_lssw") { SetCommonLimit(18); SetSpecialInterval(80); SetSafetyRange(1000); SetHordeFreq(0.6) }

// Derailed
if(Director.GetMapName() == "l4d_derailed_boat2ver")    { SetCommonLimit(58); SetSpecialInterval(35); SetSafetyRange(500); SetHordeFreq(1.2) }
if(Director.GetMapName() == "l4d_derailed_finale2ver")  { SetCommonLimit(34); SetSpecialInterval(55); SetSafetyRange(700); SetHordeFreq(0.8) }

// Fallin Death
if(Director.GetMapName() == "l4d2_fallindeath04") { SetCommonLimit(20); SetSpecialInterval(80); SetSafetyRange(800); SetHordeFreq(0.9) }

// ZMB
if(Director.GetMapName() == "zmb13_m3_surface") { SetCommonLimit(41); SetSpecialInterval(45); SetSafetyRange(600); SetHordeFreq(1.0) }

// ════════════════════════════════════════════════════════════
// DIFFICULTY SCALING — 4 valores planos + escala de hordas por dificultad
//
// Tabla: ::L4C_DifficultyScale
//
// Se ejecuta en OnGameEvent_round_start_post_nav (DESPUÉS de los Set* include-time).
// Lee la dificultad del juego y aplica:
//   - z_mob_min_notify_count   (cuántos CI para trigger mob)
//   - z_spawn_mobs_behind_chance (% hordas detrás)
//   - z_ghost_delay_max/min    (cuánto tarda un SI ghost en aparecer)
//   - z_mob_spawn_min/max_interval por dificultad
//     Fórmula: final = vanilla / (horde_freq_mult_mapa * horde_diff_mult)
//
// horde_diff_mult: <1.0 = hordas más frecuentes (fácil), >1.0 = menos frecuentes (difícil).
//   A menor dificultad, hordas más frecuentes — los infected son menos letales, hay respiro
//   entre hordas para los jugadores novatos. A mayor dificultad, hordas más espaciadas —
//   los infected son letales, los jugadores expertos necesitan tiempo para curarse.
// ════════════════════════════════════════════════════════════

::L4C_DifficultyScale <- {

    Debug = 0
    function Dbg(msg) { if (Debug) printl("[Scale][DBG] " + msg) }
    function DbgW(msg) { printl("[Scale][WARN] " + msg) }

    // Apply y OnGameEvent_* se definen FUERA del constructor (vía <-)
    // para evitar que el LSP se confunda con métodos multi-línea.
    Apply = null
    OnGameEvent_round_start_post_nav = null

    SCALE = {
        [0] = { notify = 8,  behind = 30, ghosts = 30, horde_diff_mult = 1.8 },  // Easy
        [1] = { notify = 12, behind = 50, ghosts = 20, horde_diff_mult = 1.0 },  // Normal
        [2] = { notify = 18, behind = 75, ghosts = 15, horde_diff_mult = 0.7 },  // Hard
        [3] = { notify = 25, behind = 90, ghosts = 10, horde_diff_mult = 0.55 }, // Expert
    }

    HORDE_BASE = {
        [0] = { min = 120, max = 240 },  // Easy
        [1] = { min = 90,  max = 180 },  // Normal
        [2] = { min = 90,  max = 180 },  // Hard
        [3] = { min = 90,  max = 180 },  // Expert
    }
}
__CollectGameEventCallbacks(::L4C_DifficultyScale)

// ── Métodos multi-línea (fuera del constructor para evitar LSP confundido) ──

function __L4C_Apply() {
    local diff = GetDifficulty()
    if (!(diff in this.SCALE)) {
        this.DbgW("Difficulty " + diff + " no existe en SCALE — usando Normal")
        diff = 1
    }

    local s = this.SCALE[diff]
    Convars.SetValue("z_mob_min_notify_count", s.notify.tostring())
    Convars.SetValue("z_spawn_mobs_behind_chance", s.behind.tostring())
    Convars.SetValue("z_ghost_delay_max", s.ghosts.tostring())
    Convars.SetValue("z_ghost_delay_min", s.ghosts.tostring())

    // Hordas: aplicar horde_freq_mult del mapa × horde_diff_mult de la dificultad
    // Fórmula: final = vanilla / (map_mult * diff_mult)
    //   map_mult = L4C_CurrentHordeFreqMult (default 1.0)
    //   diff_mult = s.horde_diff_mult
    local mapMult = 1.0
    if ("L4C_CurrentHordeFreqMult" in getroottable()) {
        mapMult = ::L4C_CurrentHordeFreqMult
    }
    local totalMult = mapMult * s.horde_diff_mult
    if (totalMult < 0.1) totalMult = 0.1  // evitar división por 0

    // ⚠️ 'base' es keyword reservada en Squirrel — usar baseInfo (fix 2026-08-10)
    local baseInfo = this.HORDE_BASE[diff]
    local newMin = (baseInfo.min / totalMult).tointeger()
    local newMax = (baseInfo.max / totalMult).tointeger()

    // Clamps: min 15s, max 900s
    if (newMin < 15) newMin = 15
    if (newMax > 900) newMax = 900
    if (newMax < newMin) newMax = newMin

    // Aplicar a los 4 sufijos
    Convars.SetValue("z_mob_spawn_min_interval_easy",   newMin.tostring())
    Convars.SetValue("z_mob_spawn_min_interval_normal", newMin.tostring())
    Convars.SetValue("z_mob_spawn_min_interval_hard",   newMin.tostring())
    Convars.SetValue("z_mob_spawn_min_interval_expert", newMin.tostring())
    Convars.SetValue("z_mob_spawn_max_interval_easy",   newMax.tostring())
    Convars.SetValue("z_mob_spawn_max_interval_normal", newMax.tostring())
    Convars.SetValue("z_mob_spawn_max_interval_hard",   newMax.tostring())
    Convars.SetValue("z_mob_spawn_max_interval_expert", newMax.tostring())

    this.Dbg("Diff " + diff + " → notify " + s.notify + " | behind " + s.behind + "% | ghosts " + s.ghosts + "s")
    this.Dbg("Hordas: mapMult=" + format("%.2f", mapMult) + " × diffMult=" + format("%.2f", s.horde_diff_mult) + " = " + format("%.2f", totalMult))
        this.Dbg("         min=" + newMin + "s max=" + newMax + "s (base " + baseInfo.min + "/" + baseInfo.max + ")")
}

function __L4C_RoundStartPostNav(params) {
    this.Dbg("ENTER round_start_post_nav")
    this.Apply()
    this.Dbg("EXIT round_start_post_nav")
}

::L4C_DifficultyScale.Apply <- __L4C_Apply.bindenv(::L4C_DifficultyScale)
::L4C_DifficultyScale.OnGameEvent_round_start_post_nav <- __L4C_RoundStartPostNav.bindenv(::L4C_DifficultyScale)

// ════════════════════════════════════════════════════════════
// PARTE EVENTOS — Color Correction vía tabla registrada
// ⛔ Campañas con BSP original (deathrow, zmb, noparking, etc.)
//    NO están en MAP_CC — el BSP ya referencia su .raw.
// ⛔ Hopeless, Plan B, Dead Flag Blues — NO se tocan.
// ✅ Solo campañas sin CC nativa.
// ════════════════════════════════════════════════════════════

::L4C_CC_Loader <- {

    // MAP_CC se define fuera del constructor para evitar computed keys
    MAP_CC = null

    _spawned = false
    _cc_entity = null

    // Métodos multi-línea definidos fuera (vía local t = ...)
    OnGameEvent_round_start = null
    _spawnCC = null
    OnGameEvent_round_end = null

    // One-liners mantenidos dentro
    function OnGameEvent_map_transition(params) {
        this.OnGameEvent_round_end(params)
    }

    function OnGameEvent_mission_lost(params) {
        this.OnGameEvent_round_end(params)
    }
}
__CollectGameEventCallbacks(::L4C_CC_Loader)

// ── Métodos multi-línea (fuera del constructor) ──

function __L4C_RoundStart(params) {
    this._spawned = false
    this._cc_entity = null

    // 1. Matar TODOS los env_colorcorrection existentes
    local cc = null
    while (cc = Entities.FindByClassname(cc, "env_colorcorrection")) {
        if (cc && cc.IsValid()) {
            cc.Kill()
        }
    }
    // También matar color_correction legacy
    cc = null
    while (cc = Entities.FindByClassname(cc, "color_correction")) {
        if (cc && cc.IsValid()) {
            cc.Kill()
        }
    }

    // 2. Buscar raw name para este mapa
    local map = Director.GetMapName()
    if (map == null || map == "") return

    local rawName = null
    if (map in this.MAP_CC) {
        rawName = this.MAP_CC[map]
    } else {
        // Fallback: coincidencia parcial (map empieza con key)
        foreach (m, r in this.MAP_CC) {
            if (map.find(m) == 0) {
                rawName = r
                break
            }
        }
    }

    if (rawName == null) return  // no hay CC para este mapa

    // 3. Spawnear CC un frame después (BSP debe terminar de cargar)
    local self = this
    MaoLib.DelayCall(function() {
        self._spawnCC(rawName)
    }, 0.03)
}

function __L4C_SpawnCC(rawName) {
    if (this._spawned) return
    this._spawned = true

    local ent = SpawnEntityFromTable("env_colorcorrection", {
        targetname = "l4c_cc_" + rawName
        correctionName = "materials/correction/" + rawName + ".raw"
        StartDisabled = 0
        blendtime = 0.3
        minfalloff = -1
        maxfalloff = -1
        spawnflags = 0
    })

    if (ent == null || !ent.IsValid()) {
        printl("[L4C_CC] ERROR: No se pudo spawnear env_colorcorrection para " + rawName)
        return
    }

    this._cc_entity = ent
    ::L4C_Dbg("[L4C_CC] CC activado: " + rawName + " en " + Director.GetMapName())
}

function __L4C_RoundEnd(params) {
    this._spawned = false
    if (this._cc_entity != null && this._cc_entity.IsValid()) {
        this._cc_entity.Kill()
    }
    this._cc_entity = null
}

::L4C_CC_Loader.OnGameEvent_round_start <- __L4C_RoundStart.bindenv(::L4C_CC_Loader)
::L4C_CC_Loader._spawnCC <- __L4C_SpawnCC.bindenv(::L4C_CC_Loader)
::L4C_CC_Loader.OnGameEvent_round_end <- __L4C_RoundEnd.bindenv(::L4C_CC_Loader)

// ── Poblar MAP_CC (fuera del constructor para evitar computed keys) ──

::L4C_CC_Loader.MAP_CC <- {}
::L4C_CC_Loader.MAP_CC["hcw1_aircrash"]   = "hcw1"
::L4C_CC_Loader.MAP_CC["hcw2_rivermotel"] = "hwc2"
::L4C_CC_Loader.MAP_CC["hcw3_outskirts"]  = "hwc2"
::L4C_CC_Loader.MAP_CC["hcw4_cityhall"]   = "hwc4"
::L4C_CC_Loader.MAP_CC["hcw5_bombshelter"] = "hwc5"
::L4C_CC_Loader.MAP_CC["bt1"]             = "bt1"
::L4C_CC_Loader.MAP_CC["bt2"]             = "bt2"
::L4C_CC_Loader.MAP_CC["bt3"]             = "bt3"
::L4C_CC_Loader.MAP_CC["bt4"]             = "bt4"
::L4C_CC_Loader.MAP_CC["bt5"]             = "bt5"
::L4C_CC_Loader.MAP_CC["uf1_boulevard"]   = "uf1"
::L4C_CC_Loader.MAP_CC["uf2_rooftops"]    = "uf2"
::L4C_CC_Loader.MAP_CC["uf3_harbor"]      = "uf3"
::L4C_CC_Loader.MAP_CC["uf4_airfield"]    = "uf4"
::L4C_CC_Loader.MAP_CC["zerowarn_1r"]     = "zero1"
::L4C_CC_Loader.MAP_CC["zerowarn_2r"]     = "zero2"
::L4C_CC_Loader.MAP_CC["zerowarn_3r"]     = "zero3"
::L4C_CC_Loader.MAP_CC["evac2"]           = "overkill1"
::L4C_CC_Loader.MAP_CC["gasrun"]          = "overkill2"
::L4C_CC_Loader.MAP_CC["gasrunpart2"]     = "overkill3"
::L4C_CC_Loader.MAP_CC["gr-mapone-7"]     = "overkill4"

// Debug helper (silent si no existe)
if (!("L4C_Dbg" in getroottable())) {
    ::L4C_Dbg <- function(msg) { /* silent por defecto */ }
}

printl("[L4C_MapChanges] Cargado. Mapas con CC: " + (::L4C_CC_Loader.MAP_CC.len()) + " | Difficulty scale: 4 valores")
