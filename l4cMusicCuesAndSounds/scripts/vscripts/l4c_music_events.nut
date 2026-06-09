//=============================================================================
// l4c_music_events.nut — Handlers de Game Events
// Namespace: ::L4C_Music_Events
// Parte del L4C VScript Music Manager
//=============================================================================
// CADA HANDLER:
//  1. Verifica condiciones del contexto
//  2. Decide categoría, prioridad y cooldown
//  3. Llama a L4C_Music.TriggerEvent()
//=============================================================================

::L4C_Music_Events <- {

    //=========================================
    // E02 — LAST MAN STANDING
    // 3+ survivors muertos/desconectados, 1 alive
    //=========================================
    function OnGameEvent_player_death(params)
    {
        local victim = GetPlayerFromUserID(params.userid)
        if (!victim || !victim.IsSurvivor()) return

        ::L4C_Music.AliveSurvivors--
        ::L4C_Music.Dbg("player_death: survivors vivos = " + ::L4C_Music.AliveSurvivors, 2)

        if (::L4C_Music.AliveSurvivors <= 1) {
            ::L4C_Music.Dbg("LAST MAN STANDING!", 1)
            ::L4C_Music.TriggerEvent("LastManStanding",
                ::L4C_Music.PRIORITY.CRITICAL, 0)
        }
    }

    //=========================================
    // E03 — DEFIB REVIVE
    // Desfibrilador usado exitosamente
    //=========================================
    function OnGameEvent_defibrillator_used(params)
    {
        ::L4C_Music.Dbg("DefibRevive!", 1)
        ::L4C_Music.TriggerEvent("DefibRevive",
            ::L4C_Music.PRIORITY.MEDIUM, 60)
    }

    //=========================================
    // E04 — LOW HEALTH
    // Jugador con HP < 15 (efecto localizado)
    // NOTA: Solo auditivo para el jugador herido
    //=========================================
    function OnGameEvent_player_hurt(params)
    {
        local victim = GetPlayerFromUserID(params.userid)
        if (!victim || !victim.IsSurvivor()) return

        // Reset calm timer — cualquier daño = hay combate
        ::L4C_Music.ResetCalmTimer()

        local health = params.health
        if (health > 0 && health < 15) {
            ::L4C_Music.Dbg("LowHealth: survivor con HP=" + health, 1)

            if (::L4C_Music.TriggerEvent("LowHealth",
                    ::L4C_Music.PRIORITY.HIGH, 90))
            {
                // Efecto adicional: latido/pantalla para el jugador herido
                // (opcional, se puede expandir después)
            }
        }
    }

    //=========================================
    // E05 — BOSS WAVE
    // 2+ Tanks activos simultáneamente
    //=========================================
    function OnGameEvent_tank_spawn(params)
    {
        ::L4C_Music.ActiveTanks++
        ::L4C_Music.ResetCalmTimer()
        ::L4C_Music.Dbg("tank_spawn: tanks activos = " + ::L4C_Music.ActiveTanks, 2)

        if (::L4C_Music.ActiveTanks >= 2) {
            ::L4C_Music.Dbg("BOSS WAVE! Múltiples tanks!", 1)
            ::L4C_Music.TriggerEvent("BossWave",
                ::L4C_Music.PRIORITY.CRITICAL, 0)
        }
    }

    function OnGameEvent_tank_killed(params)
    {
        ::L4C_Music.ActiveTanks--
        if (::L4C_Music.ActiveTanks < 0) ::L4C_Music.ActiveTanks = 0
        ::L4C_Music.Dbg("tank_killed: tanks restantes = " + ::L4C_Music.ActiveTanks, 2)
    }

    //=========================================
    // E06 — WITCH KILLED NO RAGE
    // Witch muerta sin haber sido enfadada antes
    //=========================================
    function OnGameEvent_witch_harasser_set(params)
    {
        ::L4C_Music.WitchRaged = true
        ::L4C_Music.ResetCalmTimer()
        ::L4C_Music.Dbg("Witch harasser set — rage detectado", 2)
    }

    function OnGameEvent_witch_killed(params)
    {
        if (!::L4C_Music.WitchRaged) {
            ::L4C_Music.Dbg("Witch KILLED sin rage — sneaky kill!", 1)
            ::L4C_Music.TriggerEvent("WitchKill",
                ::L4C_Music.PRIORITY.MEDIUM, 60)
        }
        ::L4C_Music.WitchRaged = false
    }

    //=========================================
    // E07 — FIRST AID USED
    // Heal exitoso
    //=========================================
    function OnGameEvent_heal_success(params)
    {
        ::L4C_Music.Dbg("FirstAidUsed!", 1)
        ::L4C_Music.TriggerEvent("FirstAidUsed",
            ::L4C_Music.PRIORITY.MEDIUM, 60)
    }

    //=========================================
    // E08 — BOOMER BILE ON TANK
    // Boomer explota cerca de un Tank
    // NOTA: vomit_bomb_tank no existe como VScript event
    //       Usamos boomer_exploded + distance check
    //=========================================
    function OnGameEvent_boomer_exploded(params)
    {
        local boomer = GetPlayerFromUserID(params.userid)
        if (!boomer || !boomer.IsValid()) return

        ::L4C_Music.ResetCalmTimer()
        local boomPos = boomer.GetOrigin()
        local tank = null
        local found = false

        while (tank = Entities.FindByClassname(tank, "tank_rock")) {
            // tank_rock tiene m_hThrower que apunta al Tank
            local thrower = NetProps.GetPropEntity(tank, "m_hThrower")
            if (thrower && thrower.IsValid() && thrower.IsPlayer()) {
                local dist = (thrower.GetOrigin() - boomPos).Length()
                if (dist < 500) {
                    found = true
                    break
                }
            }
        }

        // También buscar por classname "infected" con zombieClass == 8 (Tank)
        if (!found) {
            local ent = null
            while (ent = Entities.FindByClassname(ent, "infected")) {
                if (ent.IsValid() && NetProps.GetPropInt(ent, "m_zombieClass") == 8) {
                    local dist = (ent.GetOrigin() - boomPos).Length()
                    if (dist < 500) {
                        found = true
                        break
                    }
                }
            }
        }

        if (found) {
            ::L4C_Music.Dbg("BoomerBileTank! Boomer explotó cerca de un Tank", 1)
            ::L4C_Music.TriggerEvent("BoomerBileTank",
                ::L4C_Music.PRIORITY.MEDIUM, 90)
        }
    }

    //=========================================
    // E09 — RESCUE CLOSET
    // Survivors dentro del saferoom final, puerta sin cerrar
    //=========================================
    function OnGameEvent_rescue_door_open(params)
    {
        // Verificar si es un rescue final (trigger_finale presente)
        if (::L4C_Music.IsFinaleMap()) {
            ::L4C_Music.Dbg("RescueCloset — saferoom final abierto!", 1)
            ::L4C_Music.TriggerEvent("RescueCloset",
                ::L4C_Music.PRIORITY.LOW, 0)
        }
    }

    //=========================================
    // E10 — SILENCE
    // 50s sin combate después de horda
    //=========================================
    function OnGameEvent_panic_event_finished(params)
    {
        ::L4C_Music.Dbg("Panic event terminado — iniciando timer Silence 50s", 1)
        ::L4C_Music.SilenceTimerActive = true

        MaoLib.AddTimer("l4c_music_silence", 50.0, function() {
            if (!::L4C_Music.SilenceTimerActive) return  // Cancelado
            ::L4C_Music.Dbg("SILENCE — 50s sin combate!", 1)
            ::L4C_Music.TriggerEvent("Silence",
                ::L4C_Music.PRIORITY.LOW, 0)
        })
    }

    // Cancelar Silence si hay combate
    function OnGameEvent_create_panic_event(params)
    {
        ::L4C_Music.SilenceTimerActive = false
        MaoLib.RemoveTimer("l4c_music_silence")
        ::L4C_Music.ResetCalmTimer()
        ::L4C_Music.Dbg("Silence cancelado — nuevo combate", 2)

        // E01 — HORDE TRACK (12% probabilidad baja)
        if (RandomInt(1, 100) <= 12) {
            ::L4C_Music.Dbg("HordeTrack activado (12% roll)", 1)
            ::L4C_Music.TriggerEvent("Horde",
                ::L4C_Music.PRIORITY.HIGH, 120)
        }
    }

    //=========================================
    // E11 — NEAR DEATH
    // 2+ survivors incapped simultáneamente
    //=========================================
    function OnGameEvent_player_incapacitated(params)
    {
        ::L4C_Music.IncapacitatedCount++
        ::L4C_Music.ResetCalmTimer()
        ::L4C_Music.Dbg("player_incapacitated: total incapped = " + ::L4C_Music.IncapacitatedCount, 2)

        if (::L4C_Music.IncapacitatedCount >= 2) {
            ::L4C_Music.Dbg("NEAR DEATH! 2+ incapped!", 1)
            ::L4C_Music.TriggerEvent("NearDeath",
                ::L4C_Music.PRIORITY.HIGH, 120)
        }
    }

    // Recuperar contadores cuando revive/rescatan a alguien
    function OnGameEvent_revive_success(params)
    {
        ::L4C_Music.AliveSurvivors++
        ::L4C_Music.IncapacitatedCount--
        if (::L4C_Music.IncapacitatedCount < 0) ::L4C_Music.IncapacitatedCount = 0
        ::L4C_Music.Dbg("revive_success: alive=" + ::L4C_Music.AliveSurvivors + " incapped=" + ::L4C_Music.IncapacitatedCount, 2)
    }

    //=========================================
    // INICIALIZACIÓN EN ROUND START
    //=========================================
    function OnGameEvent_round_start(params)
    {
        ::L4C_Music.Dbg("round_start — Inicializando Music Manager", 1)

        // Resetear estado
        ::L4C_Music.Reset()

        // Inicializar entidades
        ::L4C_Music.Init()

        // Resetear contadores
        ::L4C_Music.AliveSurvivors = 4
        ::L4C_Music.IncapacitatedCount = 0
        ::L4C_Music.ActiveTanks = 0
        ::L4C_Music.ActiveWitches = 0
        ::L4C_Music.WitchRaged = false
        ::L4C_Music.SilenceTimerActive = false
    }

    //=========================================
    // LIMPIEZA EN ROUND END
    //=========================================
    function OnGameEvent_round_end(params)
    {
        ::L4C_Music.Dbg("round_end — Limpiando Music Manager", 1)
        ::L4C_Music.Reset()
        ::L4C_Music.SilenceTimerActive = false
        MaoLib.RemoveTimer("l4c_music_silence")
        MaoLib.RemoveTimer("l4c_music_calm_watch")
        MaoLib.RemoveTimer("l4c_music_swap")
        MaoLib.RemoveTimer("l4c_music_swap_commit")
    }

    function OnGameEvent_mission_lost(params)
    {
        ::L4C_Music.Dbg("mission_lost — Limpiando", 1)
        ::L4C_Music.Reset()
    }

    function OnGameEvent_map_transition(params)
    {
        ::L4C_Music.Dbg("map_transition — Limpiando", 1)
        ::L4C_Music.Reset()
    }
}

//=========================================
// HELPER: Detectar si es mapa de finale
//=========================================
::L4C_Music.IsFinaleMap <- function()
{
    // Buscar trigger_finale en el mapa
    local ent = null
    while (ent = Entities.FindByClassname(ent, "trigger_finale")) {
        if (ent.IsValid()) return true
    }
    return false
}

//=========================================
// REGISTRAR EVENTOS
//=========================================
__CollectGameEventCallbacks(::L4C_Music_Events);
