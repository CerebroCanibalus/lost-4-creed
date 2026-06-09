// ============================================================================
// l4c_acoustic_terror.nut — Acoustic Terror System
// ============================================================================
// Reemplaza: gunshots_horde.nut + integración con crowpiles
// Principio: El ruido atrae hordas. Más ruido = más pánico = más peligro.
// Tabla: ::L4C_AcousticTerror
// ============================================================================

::L4C_AcousticTerror <- {
    Debug = 1

    function Dbg(msg) {
        if (Debug) printl("[AcousticTerror][DEBUG] " + msg)
    }

    function DbgWarn(msg) {
        printl("[AcousticTerror][WARN] " + msg)
    }

    // ========================================================================
    // CONFIGURACIÓN
    // ========================================================================

    // Volumen acumulado para trigger horde
    VOLUME_LIMIT        = 150000    // 🔧 100k→150k: cap más alto = hordas menos frecuentes, más impacto
    HORDE_COOLDOWN      = 300.0     // 5 min entre hordas mínimo (antes 180)
    VOLUME_DECAY_RATE   = 50        // volumen perdido por segundo de silencio (antes 25)
    SHOT_VOLUME         = 600       // VOLUMEN FIJO por disparo (todas las armas)
    GRENADE_VOLUME      = 3000      // 🔧 5000→3000: granada contribuye menos
    WALK_VOLUME         = 20        // 🔧 1→20: contribución real (4 survs×20=80/s, tarda ~31min solo caminando)
    CROW_VOLUME         = 1000      // 🔧 500→1000: cuervos asustan el doble
    CROW_RADIUS         = 700       // 🔧 500→700: radio de detección más generoso

    // Feedback de tensión
    HEARTBEAT_INTERVAL_25 = 5.0     // cada 5s a ≥25% pánico
    HEARTBEAT_INTERVAL_50 = 3.0     // cada 3s a ≥50%
    HEARTBEAT_INTERVAL_75 = 1.5     // cada 1.5s a ≥75%

    // ========================================================================
    // CROW MECHANICS — Cuervos interactivos
    // ========================================================================
    // 1. ALARMA NATURAL: moverse cerca de cuervos (sin agacharse) los asusta → +volumen
    // 2. FUEGO: lanzar molotov sobre cuervos los quema → mueren con humo
    // 3. SI BILEADO: Special Infected cerca de cuervos → bileados 45s → commons los targetean
    CROW_ALARM_RADIUS       = 125       // radio para detectar survivors cerca de cuervos
    CROW_ALARM_VOLUME       = 300       // volumen añadido por cuervo asustado al caminar
    CROW_ALARM_COOLDOWN     = 8.0       // cooldown por cuervo antes de poder asustarse de nuevo
    CROW_ALARM_MIN_SPEED    = 50.0      // velocidad mínima del survivor para asustar (no crouch)
    CROW_BURN_RADIUS        = 300       // radio de fuego que mata cuervos
    CROW_SI_RADIUS          = 125       // radio para detectar SI cerca de cuervos
    CROW_SI_VOMIT_DURATION  = 45.0      // duración del efecto bile en SI
    CROW_SI_COOLDOWN        = 60.0      // cooldown por cuervo antes de volver a bilear SI
    CROW_SI_ANTIEXPLOIT_R   = 320       // radio: debe haber ≥1 survivor cerca del cuervo para que SI active
    CROW_CHECK_INTERVAL     = 1.0       // intervalo del timer de chequeo de cuervos

    // Crow state
    _crowCooldowns = {}                 // entindex → lastScareTime
    _crowBileCooldowns = {}             // entindex → lastBileTime
    _crowCheckTimer = ""                // nombre del timer de chequeo

    // Sistema de Pánico
    PANIC_INCREMENT     = 25        // 🔧 15→25: +25% por horda triggerada (escala más rápido)
    PANIC_DECAY_RATE    = 3.0       // 🔧 1.0→3.0: -3% por segundo de silencio (baja 3x más rápido)
    PANIC_AMBUSH_THRESHOLD = 50     // >50% = hordas por detrás
    PANIC_DOUBLE_THRESHOLD = 75     // >75% = DOBLE HORDE

    // Estado
    TotalVolume         = 0
    LastHordeTime       = -999
    LastShotTime        = 0
    PanicLevel          = 0         // 0-100
    IsSilent            = true
    SilentStartTime     = 0
    DirectorEnt         = null
    DefaultMobMinSize   = 0
    DefaultMobMaxSize   = 0

    // ========================================================================
    // INICIALIZACIÓN
    // ========================================================================

    function OnGameEvent_round_start_post_nav(params)
    {
        Dbg("ENTER round_start_post_nav")

        TotalVolume     = 0
        LastHordeTime   = -999
        LastShotTime    = 0
        PanicLevel      = 0
        IsSilent        = true
        SilentStartTime = Time()
        _lastHeartbeat  = 0
        _heartbeatActive = false

        DirectorEnt = Entities.FindByClassname(null, "info_director")

        // Cachear defaults de mob size
        DefaultMobMinSize = Convars.GetFloat("z_mob_spawn_min_size")
        DefaultMobMaxSize = Convars.GetFloat("z_mob_spawn_max_size")

        // Timer de caminata (cada 1s)
        MaoLib.AddTimer("acoustic_walk", 1.0, function() { ::L4C_AcousticTerror.CheckWalking() })

        // Timer de decay/panic (cada 0.5s para suavidad)
        MaoLib.AddTimer("acoustic_decay", 0.5, function() { ::L4C_AcousticTerror.DecayAndPanic() })

        // Timer de cuervos (cada 1s — alarma, SI bile, molotov)
        _crowCheckTimer = MaoLib.AddTimerAuto("acoustic_crows", CROW_CHECK_INTERVAL, function() { ::L4C_AcousticTerror._CheckCrows() })

        Dbg("Acoustic Terror initialized — Limit: " + VOLUME_LIMIT + " Cooldown: " + HORDE_COOLDOWN + "s")
    }

    // ========================================================================
    // VOLUMEN POR DISPARO (todas las armas = mismo valor)
    // ========================================================================

    function OnGameEvent_weapon_fire(event)
    {
        local player = GetPlayerFromUserID(event.userid)
        if (!player || !player.IsSurvivor()) return

        // Aplicar decay antes de sumar
        ApplyDecay()

        // Volumen base del disparo
        TotalVolume += SHOT_VOLUME
        LastShotTime = Time()
        IsSilent = false

        // Bonus por cuervos asustados
        local crowBonus = CountNearbyCrows(player.GetOrigin())
        if (crowBonus > 0) {
            TotalVolume += crowBonus * CROW_VOLUME
            Dbg("Crow scare bonus: +" + (crowBonus * CROW_VOLUME) + " (" + crowBonus + " crows)")
        }

        Dbg("Shot fired — Volume: " + TotalVolume + "/" + GetEffectiveLimit())

        TryTriggerHorde()
    }

    // ========================================================================
    // VOLUMEN POR GRANADAS
    // ========================================================================

    function OnGameEvent_hegrenade_detonate(params)
    {
        // Pipe bomb explosion
        AddNoise(GRENADE_VOLUME, "Pipe bomb detonated")
    }

    function OnGameEvent_molotov_thrown(params)
    {
        AddNoise(GRENADE_VOLUME, "Molotov thrown")
        // Quemar cuervos cercanos
        local player = GetPlayerFromUserID(params.userid)
        if (player && player.IsValid())
            _BurnCrowsAt(player.GetOrigin())
    }

    function OnGameEvent_vomitjar_thrown(params)
    {
        AddNoise(GRENADE_VOLUME * 0.6, "Bile jar thrown")  // Bile es menos ruidoso
    }

    // ========================================================================
    // VOLUMEN POR CAMINATA
    // ========================================================================

    function CheckWalking()
    {
        local movingSurvivors = 0
        foreach (s in MaoLib.YieldSurvivors()) {
            if (MaoLib.IsAlivePlayer(s)) {
                local vel = s.GetVelocity()
                local speed2D = sqrt(vel.x * vel.x + vel.y * vel.y)
                if (speed2D > 10.0 && NetProps.GetPropEntity(s, "m_hGroundEntity") != null) {
                    movingSurvivors++
                }
            }
        }

        if (movingSurvivors > 0) {
            TotalVolume += movingSurvivors * WALK_VOLUME
            IsSilent = false
            Dbg("Walking noise: +" + (movingSurvivors * WALK_VOLUME) + " (" + movingSurvivors + " moving)")
            TryTriggerHorde()
        }
    }

    // ========================================================================
    // DECAY + PÁNICO
    // ========================================================================

    function DecayAndPanic()
    {
        ApplyDecay()

        // Pánico decay si estamos en silencio
        if (IsSilent) {
            local elapsed = Time() - SilentStartTime
            if (elapsed > 3.0) {  // 3 segundos de silencio real para empezar a bajar
                // 🔧 Fix: timer a 0.5s → multiplicar por 0.5 para que sea X por SEGUNDO real
                PanicLevel = MaoLib.max(0, PanicLevel - PANIC_DECAY_RATE * 0.5)
            }
        }

        // Feedback de tensión: heartbeat ambiental según nivel de pánico
        _UpdateHeartbeat()
    }

    // ========================================================================
    // HEARTBEAT — Feedback de tensión ambiental
    // ========================================================================
    _lastHeartbeat = 0
    _heartbeatActive = false

    function _UpdateHeartbeat()
    {
        if (PanicLevel < 25) {
            // Pánico bajó del umbral — parar heartbeat en todos
            if (_heartbeatActive) {
                foreach (s in MaoLib.YieldSurvivors()) {
                    if (s.IsValid() && s.IsSurvivor())
                        StopSoundOn("player/heartbeatloop.wav", s)
                }
                _heartbeatActive = false
                Dbg("Heartbeat stopped — panic below 25%")
            }
            return
        }

        _heartbeatActive = true
        local now = Time()
        local interval = HEARTBEAT_INTERVAL_25
        if (PanicLevel >= 75) interval = HEARTBEAT_INTERVAL_75
        else if (PanicLevel >= 50) interval = HEARTBEAT_INTERVAL_50

        if (now - _lastHeartbeat < interval) return
        _lastHeartbeat = now

        // Emitir heartbeat a todos los survivors
        foreach (s in MaoLib.YieldSurvivors()) {
            if (s.IsValid() && s.IsSurvivor() && MaoLib.IsAlivePlayer(s))
                EmitSoundOnClient("player/heartbeatloop.wav", s)
        }
    }

    function ApplyDecay()
    {
        local now = Time()
        if (LastShotTime > 0) {
            local elapsed = now - LastShotTime
            local decay = elapsed * VOLUME_DECAY_RATE
            if (decay > 0) {
                TotalVolume -= decay
                if (TotalVolume < 0) TotalVolume = 0
            }
        }
        LastShotTime = now

        // Detectar inicio de silencio
        if (TotalVolume == 0 && !IsSilent) {
            IsSilent = true
            SilentStartTime = now
            Dbg("Silence detected — Panic will start decaying after 3s")
        }
    }

    // ========================================================================
    // TRIGGER DE HORDE
    // ========================================================================

    function TryTriggerHorde()
    {
        local limit = GetEffectiveLimit()
        if (TotalVolume < limit) return

        local now = Time()
        if (now - LastHordeTime < HORDE_COOLDOWN) {
            // En cooldown — cap volumen
            TotalVolume = limit
            return
        }

        // TRIGGER HORDE
        TriggerHorde(now)
    }

    function TriggerHorde(now)
    {
        if (!DirectorEnt || !DirectorEnt.IsValid()) {
            DirectorEnt = Entities.FindByClassname(null, "info_director")
        }

        if (!DirectorEnt) {
            DbgWarn("No info_director found!")
            return
        }

        // Aplicar efectos de pánico
        ApplyPanicEffects()

        // Trigger horde principal
        DoEntFire("!self", "ForcePanicEvent", "0", 0, null, DirectorEnt)

        // DOBLE HORDE si pánico > 75%
        if (PanicLevel >= PANIC_DOUBLE_THRESHOLD) {
            Dbg("DOUBLE HORDE — Panic: " + PanicLevel)
            MaoLib.DelayCall(function() {
                if (::L4C_AcousticTerror.DirectorEnt && ::L4C_AcousticTerror.DirectorEnt.IsValid()) {
                    DoEntFire("!self", "ForcePanicEvent", "0", 0, null, ::L4C_AcousticTerror.DirectorEnt)
                }
            }, 3.0)
        }

        // Incrementar pánico
        PanicLevel = MaoLib.min(100, PanicLevel + PANIC_INCREMENT)

        // Reset volumen
        TotalVolume = 0
        LastHordeTime = now

        // Anuncio
        local msg = "HORDE INCOMING! (Panic: " + PanicLevel + "%)"
        ClientPrint(null, 3, "\x03" + msg)  // 3 = HUD_PRINTTALK (chat)
        Dbg("HORDE TRIGGERED — Panic: " + PanicLevel + "% Volume reset")
    }

    // ========================================================================
    // EFECTOS DE PÁNICO
    // ========================================================================

    function ApplyPanicEffects()
    {
        // AMBUSH: hordas por detrás
        if (PanicLevel >= PANIC_AMBUSH_THRESHOLD) {
            Convars.SetValue("z_spawn_mobs_behind_chance", "75")
            Dbg("AMBUSH MODE — Spawning from behind")
        } else {
            Convars.SetValue("z_spawn_mobs_behind_chance", "25")
        }

        // INTENSIDAD: más commons por nivel de pánico (sistema de tiers)
        //   25% → +5  |  50% → +10  |  75% → +20  |  100% → +40
        local extraCommons = 0
        if (PanicLevel >= 100) extraCommons = 40
        else if (PanicLevel >= 75) extraCommons = 20
        else if (PanicLevel >= 50) extraCommons = 10
        else if (PanicLevel >= 25) extraCommons = 5
        if (extraCommons > 0) {
            local currentMin = Convars.GetFloat("z_mob_spawn_min_size")
            local currentMax = Convars.GetFloat("z_mob_spawn_max_size")
            Convars.SetValue("z_mob_spawn_min_size", (currentMin + extraCommons).tostring())
            Convars.SetValue("z_mob_spawn_max_size", (currentMax + extraCommons).tostring())
            Dbg("Horde size increased by " + extraCommons)
        }
    }

    // ========================================================================
    // CROW MECHANICS — Implementación
    // ========================================================================

    function _CheckCrows()
    {
        local allCrows = _FindAllCrows()
        if (allCrows.len() == 0) return

        // 1. ALARMA: survivors moviéndose (sin crouch) cerca de cuervos
        foreach (s in MaoLib.YieldSurvivors()) {
            if (!MaoLib.IsAlivePlayer(s)) continue
            if (s.IsIncapacitated()) continue

            // ¿Está moviéndose de pie? (FL_DUCKING = 2)
            local flags = NetProps.GetPropInt(s, "m_fFlags")
            if (flags & 2) continue  // agachado → no asusta

            local vel = s.GetVelocity()
            local speed2D = sqrt(vel.x * vel.x + vel.y * vel.y)
            if (speed2D < CROW_ALARM_MIN_SPEED) continue
            if (NetProps.GetPropEntity(s, "m_hGroundEntity") == null) continue  // en el aire

            local sPos = s.GetOrigin()
            foreach (crow in allCrows) {
                if (!crow.IsValid()) continue
                local crowIdx = crow.entindex()
                local dist = (crow.GetOrigin() - sPos).Length()
                if (dist > CROW_ALARM_RADIUS) continue

                // Cooldown check
                if (crowIdx in _crowCooldowns) {
                    if (Time() - _crowCooldowns[crowIdx] < CROW_ALARM_COOLDOWN) continue
                }

                // ¡Cuervo asustado!
                _crowCooldowns[crowIdx] <- Time()
                TotalVolume += CROW_ALARM_VOLUME
                IsSilent = false
                Dbg("CROW ALARM: survivor #" + s.GetEntityIndex() + " scared crow #" + crowIdx + " (+" + CROW_ALARM_VOLUME + " volume)")
                TryTriggerHorde()
                break  // un susto por survivor por tick
            }
        }

        // 2. SI BILE: Special Infected cerca de cuervos → bileados
        //    🛡️ Anti-exploit: debe haber ≥1 survivor cerca del cuervo
        foreach (si in MaoLib.YieldSpecials()) {
            if (!MaoLib.IsAlive(si)) continue
            if (si.IsPlayer() && si.IsSurvivor()) continue  // por si acaso

            local siPos = si.GetOrigin()
            foreach (crow in allCrows) {
                if (!crow.IsValid()) continue
                local crowIdx = crow.entindex()
                local dist = (crow.GetOrigin() - siPos).Length()
                if (dist > CROW_SI_RADIUS) continue

                // 🛡️ Anti-exploit: ¿hay algún survivor cerca del cuervo?
                if (!_HasSurvivorNearby(crow.GetOrigin(), CROW_SI_ANTIEXPLOIT_R)) continue

                // Cooldown check
                if (crowIdx in _crowBileCooldowns) {
                    if (Time() - _crowBileCooldowns[crowIdx] < CROW_SI_COOLDOWN) continue
                }

                // ¡SI biled por cuervos!
                _crowBileCooldowns[crowIdx] <- Time()
                _BileSI(si, crowIdx)
                break
            }
        }
    }

    // Aplica efecto bile a un SI → commons lo targetean por 45s
    function _BileSI(si, crowIdx)
    {
        Dbg("CROW BILE: SI #" + si.GetEntityIndex() + " biled by crow #" + crowIdx)

        // Spawn vomitjar projectile invisible y detonarlo a los pies del SI
        // → el engine aplica el efecto bile a entidades en rango (incluye SI)
        local jar = null
        try {
            jar = SpawnEntityFromTable("vomitjar_projectile", {
                origin = si.GetOrigin()
            })
        } catch(e) {
            DbgWarn("_BileSI: failed to spawn vomitjar_projectile: " + e)
        }

        if (jar && jar.IsValid()) {
            DoEntFire("!self", "Detonate", "", 0, null, jar)
            Dbg("  vomitjar detonated at SI position")
        } else {
            // Fallback: usar HitWithVomit (funciona en CTerrorPlayer, puede que no en SI)
            DbgWarn("  fallback: trying HitWithVomit on SI")
            try { si.HitWithVomit() } catch(e) { DbgWarn("  HitWithVomit failed: " + e) }
        }

        // Re-aplicar cada 20s para extender a 45s total
        local siIdx = si.GetEntityIndex()
        MaoLib.DelayCall(function() {
            local ent = EntIndexToHScript(siIdx)
            if (!ent || !ent.IsValid()) return
            Dbg("CROW BILE refresh for SI #" + siIdx)
            try {
                local jar2 = SpawnEntityFromTable("vomitjar_projectile", { origin = ent.GetOrigin() })
                if (jar2 && jar2.IsValid()) DoEntFire("!self", "Detonate", "", 0, null, jar2)
            } catch(e) {}
        }, 20.0)
        MaoLib.DelayCall(function() {
            local ent = EntIndexToHScript(siIdx)
            if (!ent || !ent.IsValid()) return
            Dbg("CROW BILE refresh #2 for SI #" + siIdx)
            try {
                local jar3 = SpawnEntityFromTable("vomitjar_projectile", { origin = ent.GetOrigin() })
                if (jar3 && jar3.IsValid()) DoEntFire("!self", "Detonate", "", 0, null, jar3)
            } catch(e) {}
        }, 40.0)
    }

    // Quema cuervos con molotov → mueren con humo
    function _BurnCrowsAt(pos)
    {
        local crows = _FindCrowsNear(pos, CROW_BURN_RADIUS)
        if (crows.len() == 0) return

        Dbg("CROW BURN: " + crows.len() + " crows near molotov at " + pos)
        foreach (crow in crows) {
            if (!crow.IsValid()) continue
            local crowPos = crow.GetOrigin()
            // Efecto de humo antes de matar
            MaoLib_VFX.SpawnParticle(crowPos, "weapon_grenade_smoke", 2.0)
            // Matar cuervo
            DoEntFire("!self", "Kill", "", 0.1, null, crow)
            // Limpiar cooldowns
            local crowIdx = crow.entindex()
            if (crowIdx in _crowCooldowns) delete _crowCooldowns[crowIdx]
            if (crowIdx in _crowBileCooldowns) delete _crowBileCooldowns[crowIdx]
        }
    }

    // Encuentra todos los npc_crow válidos en el mapa
    function _FindAllCrows()
    {
        local result = []
        local crow = null
        while (crow = Entities.FindByClassname(crow, "npc_crow")) {
            if (crow.IsValid()) result.append(crow)
        }
        return result
    }

    // Encuentra npc_crow cerca de una posición
    function _FindCrowsNear(pos, radius)
    {
        local result = []
        local crow = null
        while (crow = Entities.FindByClassnameWithin(crow, "npc_crow", pos, radius)) {
            if (crow.IsValid()) result.append(crow)
        }
        return result
    }

    // 🛡️ Anti-exploit: ¿hay algún survivor cerca de la posición?
    function _HasSurvivorNearby(pos, radius)
    {
        local player = null
        while (player = Entities.FindByClassnameWithin(player, "player", pos, radius)) {
            if (player.IsValid() && player.IsSurvivor() && MaoLib.IsAlivePlayer(player))
                return true
        }
        return false
    }

    function GetEffectiveLimit()
    {
        // 🔧 0.003→0.005: reducción 0-50% (a 100% pánico = 75k cap, más fácil triggerear)
        local reduction = PanicLevel * 0.005
        return VOLUME_LIMIT * (1.0 - reduction)
    }

    function CountNearbyCrows(pos)
    {
        local count = 0
        local crow = null
        while (crow = Entities.FindByClassnameWithin(crow, "npc_crow", pos, CROW_RADIUS)) {
            if (crow.IsValid()) count++
        }
        return count
    }

    function AddNoise(amount, reason)
    {
        ApplyDecay()
        TotalVolume += amount
        IsSilent = false
        Dbg(reason + " — Volume: " + TotalVolume + "/" + GetEffectiveLimit())
        TryTriggerHorde()
    }

    function OnGameEvent_round_end(params)
    {
        Dbg("Round end — Resetting panic and volume")
        MaoLib.RemoveTimer("acoustic_walk")
        MaoLib.RemoveTimer("acoustic_decay")
        MaoLib.RemoveTimer("acoustic_crows")
        TotalVolume = 0
        PanicLevel = 0
        _lastHeartbeat = 0
        Convars.SetValue("z_spawn_mobs_behind_chance", "25")
        // Reset mob size to defaults
        if (DefaultMobMinSize > 0) {
            Convars.SetValue("z_mob_spawn_min_size", DefaultMobMinSize.tostring())
            Convars.SetValue("z_mob_spawn_max_size", DefaultMobMaxSize.tostring())
        }
        // Stop heartbeat on all survivors
        foreach (s in MaoLib.YieldSurvivors()) {
            if (s.IsValid() && s.IsSurvivor())
                StopSoundOn("player/heartbeatloop.wav", s)
        }
        // Cleanup timers (previenen fuga entre rondas)
        MaoLib.RemoveTimer("acoustic_walk")
        MaoLib.RemoveTimer("acoustic_decay")
        MaoLib.RemoveTimer(_crowCheckTimer)
        // Cleanup crow state
        _crowCooldowns.clear()
        _crowBileCooldowns.clear()
    }
}

__CollectGameEventCallbacks(::L4C_AcousticTerror)

printl("[L4C_AcousticTerror] Loaded — Fixed weapon volume, grenades, walking, crow integration, panic system")
