// ============================================================================
// l4c_easter_eggs.nut — Cursed Creed Easter Eggs System
// ============================================================================
// Fusiona: poltergeists (simplificado) + eatpeople (reemplazado)
// Nuevos: Spectator gnome, Round-start gnome, Fire blessing, Cursed items
// Tabla: ::L4C_EasterEggs
// ============================================================================

::L4C_EasterEggs <- {
    Debug = 1
    HUD_PRINTTALK = 3      // ClientPrint chat channel (nativo L4D2)

    function Dbg(msg) {
        if (Debug) printl("[EasterEggs][DEBUG] " + msg)
    }

    function DbgWarn(msg) {
        printl("[EasterEggs][WARN] " + msg)
    }

    // ========================================================================
    // CONFIGURACIÓN
    // ========================================================================

    // Probabilidades (%)
    SPECTATOR_GNOME_CHANCE  = 1     // 1% por ronda que un spectator PUEDA crear gnomo
    ROUNDSTART_GNOME_CHANCE = 2     // 2% por ronda de gnomo inicial
    CURSED_ITEM_CHANCE      = 4     // 4% de que un item sea maldito al usarlo

    // Cooldowns
    PUSH_COOLDOWN       = 5.0   // segundos entre pushes de spectator
    FIRE_COOLDOWN       = 2.0   // segundos entre llamaradas de pitchfork
    PILLS_KILL_TIME     = 180.0 // 3 minutos hasta muerte
    ADRENALINE_DURATION = 30.0  // 30s de bonus daño

    // Estado
    CanCreateGnome      = false     // Si un spectator puede crear gnomo esta ronda
    GnomeCreated        = false     // Si ya se creó un gnomo
    RoundStartGnomeActive = false   // Si hay gnomo de inicio de ronda
    GnomeCarrier        = null      // Jugador que lleva el gnomo
    LastPushTime        = {}        // Tiempo del último push por spectator
    FireBlessedPlayers  = {}        // Jugadores con bendición de fuego

    // ========================================================================
    // ROUND START — Inicialización
    // ========================================================================

    function OnGameEvent_round_start_post_nav(params)
    {
        Dbg("ENTER round_start_post_nav")

        CanCreateGnome = RandomInt(1, 100) <= SPECTATOR_GNOME_CHANCE
        GnomeCreated = false
        RoundStartGnomeActive = false
        GnomeCarrier = null
        LastPushTime.clear()
        FireBlessedPlayers.clear()

        // Notificar a spectators si pueden crear gnomo
        if (CanCreateGnome) {
            foreach (p in MaoLib.YieldPlayers()) {
                if (!IsAliveSurvivor(p) && WasSurvivor(p)) {
                    ClientPrint(p, HUD_PRINTTALK, "\x05[Easter Egg] \x01You feel a \x03cursed presence\x01... Press \x04E\x01 to manifest a gnome!")
                }
            }
        }

        // Intentar gnomo de inicio de ronda
        TrySpawnRoundStartGnome()

        // Iniciar think de spectators
        MaoLib.AddTimer("easter_spectator", 0.5, function() { ::L4C_EasterEggs.SpectatorThink() })

        Dbg("EXIT round_start_post_nav — CanCreateGnome: " + CanCreateGnome)
    }

    // ========================================================================
    // SPECTATOR POLTERGEIST + GNOME CREATION
    // ========================================================================

    function SpectatorThink()
    {
        foreach (p in MaoLib.YieldPlayers()) {
            if (!p.IsValid()) continue
            if (IsAliveSurvivor(p)) continue  // Solo espectadores
            if (!WasSurvivor(p)) continue      // Que hayan sido survivor

            local idx = p.GetEntityIndex()
            local now = Time()

            // Push de props cada 5s
            if (now - (idx in LastPushTime ? LastPushTime[idx] : 0) >= PUSH_COOLDOWN) {
                TryPushProp(p)
                LastPushTime[idx] <- now
            }

            // Crear gnomo con E (si está disponible)
            if (CanCreateGnome && !GnomeCreated) {
                local buttons = p.GetButtonMask()
                if (buttons & 32) {  // IN_USE = 32
                    TryCreateSpectatorGnome(p)
                }
            }
        }
    }

    function TryPushProp(spectator)
    {
        local eyePos = spectator.EyePosition()
        local eyeAng = spectator.EyeAngles()
        local forward = eyeAng.Forward()

        // Trace hacia donde mira
        local trace = { start = eyePos, end = eyePos + forward * 200, mask = 0x200400B }
        TraceLine(trace)

        if (trace.hit && trace.ent != null && trace.ent.IsValid()) {
            local ent = trace.ent
            local classname = ent.GetClassname()

            // Solo props físicos
            if (classname == "prop_physics" || classname == "prop_physics_override") {
                local pushDir = forward * 300
                pushDir.z = 100  // Un poco hacia arriba
                ent.ApplyAbsVelocityImpulse(pushDir)
                Dbg("Spectator pushed prop: " + ent.GetName())
            }
        }
    }

    function TryCreateSpectatorGnome(spectator)
    {
        local eyePos = spectator.EyePosition()
        local eyeAng = spectator.EyeAngles()
        local forward = eyeAng.Forward()

        // Spawn 100u frente al spectator
        local spawnPos = eyePos + forward * 100
        spawnPos.z = spawnPos.z + 10

        local gnome = SpawnEntityFromTable("prop_physics", {
            origin = spawnPos,
            model = "models/props_junk/gnome.mdl",
            targetname = "cursed_gnome_spectator",
            rendercolor = "255 0 0",  // Rojo siniestro
        })

        if (gnome && gnome.IsValid()) {
            GnomeCreated = true

            // Glow rojo intenso
            NetProps.SetPropInt(gnome, "m_Glow.m_iGlowType", 3)
            NetProps.SetPropInt(gnome, "m_Glow.m_glowColorOverride", 16711680)  // Rojo puro
            NetProps.SetPropInt(gnome, "m_Glow.m_nGlowRange", 1500)

            // Anuncio
            ClientPrint(null, HUD_PRINTTALK, "\x05[CURSED GNOME] \x03A spectator has manifested a cursed gnome!")
            MaoLib_VFX.EmitSoundAt(spawnPos, "ambient/creatures/town_zombie_call1.wav")

            Dbg("Spectator created cursed gnome at " + spawnPos)
        }
    }

    // ========================================================================
    // GNOMO DE INICIO DE RONDA
    // ========================================================================

    function TrySpawnRoundStartGnome()
    {
        if (RandomInt(1, 100) > ROUNDSTART_GNOME_CHANCE) {
            Dbg("No round-start gnome this round")
            return
        }

        // Elegir survivor random
        local survivors = []
        foreach (s in MaoLib.YieldSurvivors()) {
            if (MaoLib.IsAlivePlayer(s)) survivors.append(s)
        }

        if (survivors.len() == 0) return

        local chosen = survivors[RandomInt(0, survivors.len() - 1)]
        local origin = chosen.GetOrigin()

        // Spawn gnome cerca
        local offset = Vector(RandomInt(-50, 50), RandomInt(-50, 50), 0)
        local gnome = SpawnEntityFromTable("prop_physics", {
            origin = origin + offset,
            model = "models/props_junk/gnome.mdl",
            targetname = "roundstart_gnome",
            rendercolor = "255 215 0",  // Dorado
        })

        if (gnome && gnome.IsValid()) {
            RoundStartGnomeActive = true
            GnomeCarrier = null

            // Glow dorado
            NetProps.SetPropInt(gnome, "m_Glow.m_iGlowType", 3)
            NetProps.SetPropInt(gnome, "m_Glow.m_glowColorOverride", 16766720)  // Dorado
            NetProps.SetPropInt(gnome, "m_Glow.m_nGlowRange", 2000)

            ClientPrint(null, HUD_PRINTTALK, "\x05[GNOME QUEST] \x03A golden gnome has appeared! Carry it to the saferoom for a blessing...")
            Dbg("Round-start gnome spawned near " + chosen.GetPlayerName())
        }
    }

    // ========================================================================
    // TRACKING DE GNOMO
    // ========================================================================

    function OnGameEvent_player_use(event)
    {
        if (!RoundStartGnomeActive) return

        local player = GetPlayerFromUserID(event.userid)
        if (!player || !player.IsSurvivor()) return

        // Buscar gnomo cerca
        local gnome = Entities.FindByName(null, "roundstart_gnome")
        if (!gnome || !gnome.IsValid()) return

        local dist = MaoLib.DistanceBetween(player.GetOrigin(), gnome.GetOrigin())
        if (dist < 80) {
            // Recoger gnomo
            GnomeCarrier = player
            gnome.Kill()

            player.SetContext("has_gnome", "true", 0)
            ClientPrint(player, HUD_PRINTTALK, "\x05[GNOME QUEST] \x01You carry the \x03golden gnome\x01! Protect it!")
            EmitSoundOnClient("npc/witch/voice/attack/female_shriek_1.wav", player)

            Dbg(player.GetPlayerName() + " picked up the gnome")
        }
    }

    function OnGameEvent_round_end(event)
    {
        // Cleanup timers (previenen fuga entre rondas)
        MaoLib.RemoveTimer("easter_spectator")
        MaoLib.RemoveTimer("easter_fire_check")
        
        // Stop heartbeatloop on all survivors (cursed pills sound)
        foreach (s in MaoLib.YieldSurvivors()) {
            if (s.IsValid() && s.IsSurvivor())
                StopSoundOn("player/heartbeatloop.wav", s)
        }
        
        // Recompensar si el carrier llegó vivo
        if (RoundStartGnomeActive && GnomeCarrier != null && GnomeCarrier.IsValid()) {
            if (MaoLib.IsAlivePlayer(GnomeCarrier)) {
                // Marcar para bendición de fuego en próxima ronda
                GnomeCarrier.SetContext("fire_blessing", "true", 0)
                ClientPrint(null, HUD_PRINTTALK, "\x05[GNOME QUEST] \x03" + GnomeCarrier.GetPlayerName() + " \x01delivered the gnome! \x04Fire blessing granted next round!")
            } else {
                ClientPrint(null, HUD_PRINTTALK, "\x05[GNOME QUEST] \x03The gnome carrier died... The blessing is lost.")
            }
        }

        // Limpiar estados
        RoundStartGnomeActive = false
        GnomeCarrier = null
        GnomeCreated = false
    }

    // ========================================================================
    // BENDICIÓN DE FUEGO (Pitchfork de fuego)
    // ========================================================================

    function OnGameEvent_player_spawn(event)
    {
        local player = GetPlayerFromUserID(event.userid)
        if (!player || !player.IsSurvivor()) return

        // Si tiene fire_blessing de ronda anterior
        if (player.GetContext("fire_blessing") == "true") {
            player.SetContext("fire_blessing", "", 0.1)  // Limpiar context
            FireBlessedPlayers[player.GetEntityIndex()] <- true

            // Dar pitchfork (melee aleatorio)
            player.GiveItem("weapon_melee")

            ClientPrint(player, HUD_PRINTTALK, "\x05[FIRE BLESSING] \x04Your melee weapon ignites with cursed fire!")
            Dbg(player.GetPlayerName() + " received fire blessing")
        }
    }

    function CheckFireMelee()
    {
        foreach (idx, blessed in FireBlessedPlayers) {
            if (!blessed) continue

            local player = PlayerInstanceFromIndex(idx)
            if (!player || !player.IsValid() || !MaoLib.IsAlivePlayer(player)) continue

            local weapon = player.GetActiveWeapon()
            if (!weapon) continue

            // Verificar si es melee
            local wpnClass = weapon.GetClassname()
            if (wpnClass != "weapon_melee") continue

            // Verificar si está atacando
            local buttons = player.GetButtonMask()
            if (!(buttons & 1)) continue  // IN_ATTACK = 1

            // Cooldown por jugador
            local lastFire = player.GetContext("last_fire_blessing")
            local now = Time()
            if (lastFire != "" && (now - lastFire.tofloat()) < FIRE_COOLDOWN) continue

            // Spawn fuego
            local eyePos = player.EyePosition()
            local forward = player.EyeAngles().Forward()
            local firePos = eyePos + forward * 80

            local fire = SpawnEntityFromTable("env_inferno", {
                origin = firePos,
                lifetime = 3,
                targetname = "blessed_fire_" + UniqueString(),
            })

            if (fire && fire.IsValid()) {
                DoEntFire("!self", "StartFire", "", 0, null, fire)
                DoEntFire("!self", "Kill", "", 3.5, null, fire)
                player.SetContext("last_fire_blessing", now.tostring(), 5)
                Dbg("Fire blessing activated for " + player.GetPlayerName())
            }
        }
    }

    // ========================================================================
    // CURSED ITEMS
    // ========================================================================

    function OnGameEvent_heal_success(event)
    {
        if (!("subject" in event)) return
        local player = GetPlayerFromUserID(event.subject)
        if (!player || !player.IsSurvivor()) return

        if (RandomInt(1, 100) <= CURSED_ITEM_CHANCE) {
            TriggerCursedMedkit(player)
        }
    }

    function OnGameEvent_pills_used(event)
    {
        local player = null
        if ("subject" in event) player = GetPlayerFromUserID(event.subject)
        else if ("userid" in event) player = GetPlayerFromUserID(event.userid)

        if (!player || !player.IsSurvivor()) return

        if (RandomInt(1, 100) <= CURSED_ITEM_CHANCE) {
            TriggerCursedPills(player)
        }
    }

    function OnGameEvent_adrenaline_used(event)
    {
        if (!("userid" in event)) return
        local player = GetPlayerFromUserID(event.userid)
        if (!player || !player.IsSurvivor()) return

        if (RandomInt(1, 100) <= CURSED_ITEM_CHANCE) {
            TriggerCursedAdrenaline(player)
        }
    }

    // --- CURSED MEDKIT ---
    function TriggerCursedMedkit(player)
    {
        Dbg("CURSED MEDKIT on " + player.GetPlayerName())

        // +50 max HP
        local newMax = player.GetMaxHealth() + 50
        player.SetMaxHealth(newMax)
        player.SetHealth(player.GetHealth() + 50)

        // Spawn tank cercano
        SpawnTankNear(player)

        ClientPrint(player, HUD_PRINTTALK, "\x03[CURSED] \x01The medkit tasted wrong... A \x05Tank \x01approaches! But you feel \x04stronger\x01.")
        EmitSoundOnClient("npc/tank/voice/growl/tank_growl_1.wav", player)
    }

    function SpawnTankNear(player)
    {
        local origin = player.GetOrigin()
        local spawnPos = origin + Vector(RandomInt(-300, 300), RandomInt(-300, 300), 0)

        // Spawn point para tank
        SpawnEntityFromTable("info_zombie_spawn", {
            origin = spawnPos,
            population = "tank",
            offer_tank = 1,
            targetname = "cursed_tank_spawn_" + UniqueString(),
        })

        // Forzar director a considerar tank
        Director.ResetTankTimer()

        Dbg("Tank spawn requested near " + player.GetPlayerName())
    }

    // --- CURSED PILLS ---
    function TriggerCursedPills(player)
    {
        Dbg("CURSED PILLS on " + player.GetPlayerName())

        // Speed boost x3 — auto-expira con el timer de muerte
        MaoLib.Modifiers.RegisterSpeed(player, 3.0, PILLS_KILL_TIME, "cursed_pills")

        // Marcar como maldito
        player.SetContext("cursed_pills", "true", 0)

        // Timer de muerte (3 minutos) — DelayCall one-shot, auto-remove
        MaoLib.DelayCall(function() {
            ::L4C_EasterEggs.KillCursedPlayer(player)
        }, PILLS_KILL_TIME)

        ClientPrint(player, HUD_PRINTTALK, "\x03[CURSED] \x04Speed x3 \x01for 3 minutes... but something feels \x03very wrong\x01.")
        EmitSoundOnClient("player/heartbeatloop.wav", player)
        // ⚠️ Schedule StopSoundOn — heartbeatloop es LOOPING, requiere parada explícita
        MaoLib.DelayCall(function() {
            if (player && player.IsValid())
                StopSoundOn("player/heartbeatloop.wav", player)
        }, PILLS_KILL_TIME)
    }

    function KillCursedPlayer(player)
    {
        if (!player || !player.IsValid() || !MaoLib.IsAlivePlayer(player)) return
        if (player.GetContext("cursed_pills") != "true") return

        Dbg("Cursed pills killing " + player.GetPlayerName())

        // Stop heartbeat sound
        StopSoundOn("player/heartbeatloop.wav", player)

        // Limpiar speed boost (Modifiers auto-cleanup round_end si expiró antes)
        MaoLib.Modifiers.ClearSource(player, "cursed_pills")

        // Limpiar context
        player.SetContext("cursed_pills", "", 0.1)

        // INSTAKILL — bypass incap
        // Primero eliminar buffer de salud
        player.SetHealthBuffer(0)
        // Daño masivo que debería matar directamente
        player.TakeDamage(9999, 0, player)

        // Si sigue vivo (tiene incap), forzar muerte
        if (MaoLib.IsAlivePlayer(player)) {
            NetProps.SetPropInt(player, "m_lifeState", 2)
        }

        ClientPrint(null, HUD_PRINTTALK, "\x03[CURSED] \x05" + player.GetPlayerName() + " \x01collapsed from cursed pills!")
        MaoLib_VFX.SpawnExplosion(player.GetOrigin(), "small")
    }

    // --- CURSED ADRENALINE ---
    function TriggerCursedAdrenaline(player)
    {
        Dbg("CURSED ADRENALINE on " + player.GetPlayerName())

        // +50% daño, friendly fire x2
        player.SetContext("cursed_adrenaline", "true", 0)

        // Timer para limpiar — DelayCall one-shot, auto-remove
        MaoLib.DelayCall(function() {
            if (player && player.IsValid()) {
                player.SetContext("cursed_adrenaline", "", 0.1)
                ClientPrint(player, HUD_PRINTTALK, "\x05[CURSED] \x01The cursed adrenaline wears off...")
            }
        }, ADRENALINE_DURATION)

        ClientPrint(player, HUD_PRINTTALK, "\x03[CURSED] \x04Damage +50% \x01for 30s, but \x03friendly fire is doubled\x01!")
    }

    // ========================================================================
    // DAÑO CURSED (+50% daño, FF x2)
    // ========================================================================

    function OnGameEvent_player_hurt(event)
    {
        if (!("attacker" in event) || !("userid" in event) || !("damage" in event)) return

        local attacker = GetPlayerFromUserID(event.attacker)
        local victim = GetPlayerFromUserID(event.userid)

        if (!attacker || !victim) return
        if (!attacker.IsSurvivor()) return
        if (attacker.GetContext("cursed_adrenaline") != "true") return

        local dmg = event.damage

        if (victim.IsSurvivor()) {
            // FRIENDLY FIRE x2 total (ya aplicó 1x, aplicamos 1x más)
            victim.SetHealth(victim.GetHealth() - dmg)
            Dbg("Cursed FF doubled on " + victim.GetPlayerName() + " for " + dmg)
        } else {
            // +50% daño a SI/commons (aplicar 0.5x extra)
            victim.SetHealth(victim.GetHealth() - (dmg * 0.5).tointeger())
            Dbg("Cursed damage +50% on " + victim.GetClassname())
        }
    }

    // ========================================================================
    // UTILIDADES
    // ========================================================================

    function IsAliveSurvivor(player)
    {
        return player != null && player.IsValid() && player.IsSurvivor() &&
               NetProps.GetPropInt(player, "m_lifeState") == 0
    }

    function WasSurvivor(player)
    {
        // Simple heuristic: survivors tienen modelo de survivor
        local model = player.GetModelName()
        return model.find("survivor_") != null
    }
}

__CollectGameEventCallbacks(::L4C_EasterEggs)

// Iniciar timer de fire blessing
MaoLib.AddTimer("easter_fire_check", 0.5, function() { ::L4C_EasterEggs.CheckFireMelee() })

printl("[L4C_EasterEggs] Loaded — Spectator poltergeist, cursed gnomes, fire blessing, cursed items")
