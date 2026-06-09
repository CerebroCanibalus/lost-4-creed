// ============================================================
// L4CWI — RRLogic System v2.0
// Integración avanzada con Reworked Recoil (rrlogic.nut):
//   1. Hunting Rifle — Bloodletter (sangrado AoE acumulable, MaoLib.AoE)
//   2. Desert Rifle — Rampage (full-auto burst + fire rate progresivo + recoil dinámico)
// ============================================================

::L4CWI_RRLogic <- {
    VERSION = "2.1"
    CONFIG_PATH = "l4cwi_config/rrlogic_system.cfg"

    // ============================================================
    // DEBUG
    // ============================================================
    Debug = 1

    function Dbg(msg) {
        if (this.Debug) printl("[L4CWI_RRLogic][DEBUG] " + msg)
    }
    function DbgWarn(msg) {
        printl("[L4CWI_RRLogic][WARN] " + msg)
    }
    function DbgError(msg) {
        printl("[L4CWI_RRLogic][ERROR] " + msg)
    }

    // ============================================================
    // HUNTING RIFLE — BLOODLETTER (DoT + AoE one-shot)
    // ============================================================
    HUNTING_BLEED_ENABLED = true
    HUNTING_BLEED_RADIUS = 120
    HUNTING_BLEED_DMG_PER_STACK = 6
    HUNTING_BLEED_MAX_STACKS = 5
    HUNTING_BLEED_DURATION = 4.0
    HUNTING_DAMAGE_MULT = 0.75

    // Stacks de sangrado por entidad (para daño AoE y DoT acumulativo)
    // _BleedStacks[entIdx] = { stacks, expireTime }
    _BleedStacks = {}

    // 🛡️ GUARD: Previene cascada infinita de AoE anidados
    // Sin este guard, cada common dañado por el AoE dispara otro AoE → recursión → crash
    _HuntingAoEActive = false

    // 🛡️ CAP: Máximo de commons afectados por AoE por disparo
    // Sin este cap, 20+ commons muriendo simultáneamente crashea el engine
    HUNTING_AOE_MAX_COMMONS = 8

    // 🛡️ CRITICAL: Damage recursion guard. TakeDamage()/AoE.Apply.Damage() inside
    // OnGameEvent_player_hurt/infected_hurt fires the same event again. Without this
    // flag, bonus damage from hunting/desert rifles triggers infinite recursion.
    // SINGLE flag covers BOTH handlers because AoE from player_hurt generates
    // infected_hurt events — we must block cross-event ping-pong, not just same-event loops.
    _processingDamageEvent = false

    // ============================================================
    // DESERT RIFLE — RAMPAGE
    // ============================================================
    DESERT_FULLAUTO_ENABLED = true
    DESERT_RAMP_ENABLED = true
    DESERT_RAMP_START_INTERVAL = 0.12
    DESERT_RAMP_MAX_INTERVAL = 0.05
    DESERT_RAMP_ACCEL_TIME = 2.0
    DESERT_DAMAGE_MULT = 1.02
    DESERT_AMMO_MULT = 3
    DESERT_AMMO_BONUS = 30
    DESERT_AMMO_THRESHOLD = 150
    DESERT_AMMO_CHECK_INTERVAL = 5.0

    // [player] = { startTime, lastShot }
    DesertStreaks = {}

    // Jugadores con shove pendiente de restaurar (Fase 1 del próximo frame)
    // [player] = PreviousAttack (m_flNextPrimaryAttack antes del shove)
    DesertShovePrevAttack = {}

    // ============================================================
    // RRLOGIC COMPAT — Recoil dinámico
    // ============================================================
    DESERT_RRLOGIC_RECOIL_MULT_START = 1.0
    DESERT_RRLOGIC_RECOIL_MULT_MAX = 3.0

    RRLOGIC_DETECTED = false
    RRLOGIC_ORIGINAL = null

    // ============================================================
    // INIT
    // ============================================================
    function Init() {
        this.Dbg("ENTER Init")

        local defaults = {
            hunting_bleed_enabled = true,
            hunting_bleed_radius = 120,
            hunting_bleed_dmg_per_stack = 6,
            hunting_bleed_max_stacks = 5,
            hunting_bleed_duration = 4.0,
            hunting_damage_mult = 0.75,
            desert_fullauto_enabled = true,
            desert_ramp_enabled = true,
            desert_ramp_start_interval = 0.12,
            desert_ramp_max_interval = 0.05,
            desert_ramp_accel_time = 2.0,
            desert_damage_mult = 1.02,
            desert_ammo_mult = 3,
            desert_ammo_bonus = 30,
            desert_ammo_threshold = 150,
            desert_rrlogic_recoil_start = 1.0,
            desert_rrlogic_recoil_max = 3.0,
        }

        local cfg = ::L4CWI_Core.ParseConfig(CONFIG_PATH, defaults)
        HUNTING_BLEED_ENABLED = cfg.hunting_bleed_enabled
        HUNTING_BLEED_RADIUS = cfg.hunting_bleed_radius
        HUNTING_BLEED_DMG_PER_STACK = cfg.hunting_bleed_dmg_per_stack
        HUNTING_BLEED_MAX_STACKS = cfg.hunting_bleed_max_stacks
        HUNTING_BLEED_DURATION = cfg.hunting_bleed_duration
        HUNTING_DAMAGE_MULT = cfg.hunting_damage_mult
        DESERT_FULLAUTO_ENABLED = cfg.desert_fullauto_enabled
        DESERT_RAMP_ENABLED = cfg.desert_ramp_enabled
        DESERT_RAMP_START_INTERVAL = cfg.desert_ramp_start_interval
        DESERT_RAMP_MAX_INTERVAL = cfg.desert_ramp_max_interval
        DESERT_RAMP_ACCEL_TIME = cfg.desert_ramp_accel_time
        DESERT_DAMAGE_MULT = cfg.desert_damage_mult
        DESERT_AMMO_MULT = cfg.desert_ammo_mult
        DESERT_AMMO_BONUS = cfg.desert_ammo_bonus
        DESERT_AMMO_THRESHOLD = cfg.desert_ammo_threshold
        DESERT_RRLOGIC_RECOIL_MULT_START = cfg.desert_rrlogic_recoil_start
        DESERT_RRLOGIC_RECOIL_MULT_MAX = cfg.desert_rrlogic_recoil_max

        DetectRRLogic()

        if (DESERT_RAMP_ENABLED || DESERT_FULLAUTO_ENABLED) {
            ScheduleDesertUpdate()
        }
        if (DESERT_RAMP_ENABLED) {
            ScheduleDesertAmmoCheck()
        }

        this.Dbg("EXIT Init — Hunting: " + HUNTING_BLEED_ENABLED +
                 ", Desert: " + DESERT_RAMP_ENABLED +
                 ", RRLogic: " + RRLOGIC_DETECTED)
    }

    // ============================================================
    // RRLOGIC DETECTION & PATCHING
    // ============================================================
    function DetectRRLogic() {
        this.Dbg("ENTER DetectRRLogic")

        if (!("YsReworkedRecoil" in getroottable())) {
            this.Dbg("ABORT: RRLogic not detected — running without recoil integration")
            return
        }

        local rr = ::YsReworkedRecoil
        if (!("Config" in rr) || !("rifle_desert" in rr.Config)) {
            this.DbgWarn("RRLogic detected but rifle_desert not in config")
            return
        }

        if (!("cachedVars" in rr)) {
            this.DbgWarn("RRLogic detected but cachedVars missing")
            return
        }

        RRLOGIC_DETECTED = true

        local origConfig = rr.Config["rifle_desert"]
        local origCached = null
        if ("rifle_desert" in rr.cachedVars) {
            origCached = rr.cachedVars["rifle_desert"]
        }

        local origFastGun = null
        if ("fastGuns" in rr && "rifle_desert" in rr.fastGuns) {
            origFastGun = rr.fastGuns["rifle_desert"]
        }

        RRLOGIC_ORIGINAL = {
            baseRecoil = origConfig.baseRecoil,
            horzBias = origConfig.horzBias,
            cached = origCached,
            fastGun = origFastGun
        }

        if ("fastGuns" in rr) {
            rr.fastGuns["rifle_desert"] <- DESERT_RAMP_MAX_INTERVAL
        }

        this.Dbg("EXIT DetectRRLogic — original recoil: " + RRLOGIC_ORIGINAL.baseRecoil +
                 ", patched fastGun: " + DESERT_RAMP_MAX_INTERVAL)
    }

    function ApplyRRLogicRecoilMult(mult) {
        if (!RRLOGIC_DETECTED || RRLOGIC_ORIGINAL == null) return

        local rr = ::YsReworkedRecoil
        local orig = RRLOGIC_ORIGINAL

        local newRecoil = orig.baseRecoil * mult
        rr.Config["rifle_desert"].baseRecoil = newRecoil

        if (orig.cached != null && "rifle_desert" in rr.cachedVars) {
            local crouchMult = rr.Config.crouchMult
            local walkMult = rr.Config.walkMult
            rr.cachedVars["rifle_desert"][0] = newRecoil * crouchMult
            rr.cachedVars["rifle_desert"][1] = newRecoil * walkMult
        }

        this.Dbg("RRLogic recoil updated — mult: " + mult + " new base: " + newRecoil)
    }

    function RestoreRRLogicDefaults() {
        if (!RRLOGIC_DETECTED || RRLOGIC_ORIGINAL == null) return

        local rr = ::YsReworkedRecoil
        local orig = RRLOGIC_ORIGINAL

        rr.Config["rifle_desert"].baseRecoil = orig.baseRecoil

        if (orig.cached != null && "rifle_desert" in rr.cachedVars) {
            rr.cachedVars["rifle_desert"][0] = orig.cached[0]
            rr.cachedVars["rifle_desert"][1] = orig.cached[1]
        }

        if (orig.fastGun != null && "fastGuns" in rr) {
            rr.fastGuns["rifle_desert"] = orig.fastGun
        }

        this.Dbg("RRLogic defaults restored")
    }

    function GetRRLogicRecoilMult(streakTime) {
        if (streakTime <= 0) return DESERT_RRLOGIC_RECOIL_MULT_START
        if (streakTime >= DESERT_RAMP_ACCEL_TIME) return DESERT_RRLOGIC_RECOIL_MULT_MAX

        local t = streakTime / DESERT_RAMP_ACCEL_TIME
        return DESERT_RRLOGIC_RECOIL_MULT_START +
               (DESERT_RRLOGIC_RECOIL_MULT_MAX - DESERT_RRLOGIC_RECOIL_MULT_START) * t
    }

    // ============================================================
    // SHARED: infected_hurt — Hunting bleed (DoT) + Desert damage
    // ============================================================
    function OnGameEvent_infected_hurt(params) {
        // 🛡️ CRITICAL: prevent recursive damage loops from bonus damage/AoE
        if (this._processingDamageEvent) return

        if (!("entityid" in params) || !("attacker" in params) || !("amount" in params)) return
        if (!params.attacker) return

        this._processingDamageEvent = true

        // infected_hunt: weapon puede venir en params o lo obtenemos del arma activa
        local weapon = ""
        if ("weapon" in params) {
            weapon = params.weapon
        } else {
            local wep = GetPlayerFromUserID(params.attacker)
            if (wep && wep.IsSurvivor()) {
                local activeWep = wep.GetActiveWeapon()
                if (activeWep) {
                    local cls = activeWep.GetClassname()
                    if (cls.len() > 7 && cls.slice(0, 7) == "weapon_") {
                        weapon = cls.slice(7)
                    } else {
                        weapon = cls
                    }
                }
            }
        }
        local infected = EntIndexToHScript(params.entityid)
        local attacker = GetPlayerFromUserID(params.attacker)
        if (!infected || !attacker || !attacker.IsSurvivor()) {
            this._processingDamageEvent = false
            return
        }

        // --- HUNTING RIFLE BLOODLETTER ---
        if (HUNTING_BLEED_ENABLED && weapon == "hunting_rifle") {
            // ★ FIX: no resucitar muertos — healBack solo si HP > 0
            local healBack = params.amount * (1.0 - HUNTING_DAMAGE_MULT)
            if (healBack > 0 && infected.IsValid()) {
                local currentHp = infected.GetHealth()
                if (currentHp > 0 && currentHp < infected.GetMaxHealth()) {
                    local newHealth = currentHp + healBack
                    if (newHealth > infected.GetMaxHealth())
                        newHealth = infected.GetMaxHealth()
                    infected.SetHealth(newHealth.tointeger())
                }
            }
            _ApplyHuntingBleed(infected, attacker)
        }

        // --- DESERT RIFLE RAMPAGE ---
        if (DESERT_RAMP_ENABLED && weapon == "rifle_desert") {
            local bonusDmg = params.amount * (DESERT_DAMAGE_MULT - 1.0)
            if (bonusDmg > 0 && infected.IsValid()) {
                infected.TakeDamage(bonusDmg, 131072, attacker)
            }
        }

        this._processingDamageEvent = false
    }

    // ============================================================
    // SHARED: player_hurt — Hunting bleed (DoT) + Desert damage
    // ============================================================
    function OnGameEvent_player_hurt(params) {
        // 🛡️ CRITICAL: prevent recursive damage loops from bonus damage/AoE
        if (this._processingDamageEvent) return

        if (!("userid" in params) || !("attacker" in params) || !("weapon" in params)) return
        if (!params.attacker) return

        local weapon = params.weapon
        local special = GetPlayerFromUserID(params.userid)
        local attacker = GetPlayerFromUserID(params.attacker)
        if (!special || !attacker || !attacker.IsSurvivor()) return
        if (special.IsSurvivor()) return

        this._processingDamageEvent = true

        // --- HUNTING RIFLE BLOODLETTER ---
        if (HUNTING_BLEED_ENABLED && weapon == "hunting_rifle") {
            if ("dmg_health" in params) {
                local healBack = params.dmg_health * (1.0 - HUNTING_DAMAGE_MULT)
                // Misma protección: no curar muertos
                if (healBack > 0 && special.IsValid()) {
                    local currentHp = special.GetHealth()
                    if (currentHp > 0 && currentHp < special.GetMaxHealth()) {
                        local newHealth = currentHp + healBack
                        if (newHealth > special.GetMaxHealth())
                            newHealth = special.GetMaxHealth()
                        special.SetHealth(newHealth.tointeger())
                    }
                }
            }
            _ApplyHuntingBleed(special, attacker)
        }

        // --- DESERT RIFLE RAMPAGE ---
        if (DESERT_RAMP_ENABLED && weapon == "rifle_desert") {
            if ("dmg_health" in params) {
                local bonusDmg = params.dmg_health * (DESERT_DAMAGE_MULT - 1.0)
                if (bonusDmg > 0 && special.IsValid() && NetProps.GetPropInt(special, "m_lifeState") == 0) {
                    special.TakeDamage(bonusDmg, 131072, attacker)
                }
            }
        }

        this._processingDamageEvent = false
    }

    // ============================================================
    // HUNTING RIFLE — Bleed v3 (DoT + AoE one-shot al impactar)
    // ============================================================
    // Cada impacto de hunting_rifle:
    //   1. Aplica DoT al objetivo (si sobrevive) — NO refresca duración
    //   2. AoE instantáneo alrededor del impacto (aunque mate al instante)
    //   3. Stacks acumulan daño AoE por disparo
    // El DoT expira naturalmente a los HUNTING_BLEED_DURATION segundos.
    // ============================================================

    function _ApplyHuntingBleed(victim, attacker) {
        if (!victim || !victim.IsValid()) return

        local origin = victim.GetOrigin()
        local entIdx = victim.GetEntityIndex()
        local now = Time()
        local isAlive = (NetProps.GetPropInt(victim, "m_lifeState") == 0)
        local SE = ::MaoLib.StatusEffects

        // --- TRACKEO DE STACKS ---
        if (!(entIdx in _BleedStacks))
            _BleedStacks[entIdx] <- { stacks = 0, expireTime = 0 }
        _BleedStacks[entIdx].stacks += 1
        if (_BleedStacks[entIdx].stacks > HUNTING_BLEED_MAX_STACKS)
            _BleedStacks[entIdx].stacks = HUNTING_BLEED_MAX_STACKS

        local stacks = _BleedStacks[entIdx].stacks

        // --- DoT (solo si la víctima sobrevivió) ---
        // NO refrescar duración: solo aplicar si el DoT anterior expiró
        if (isAlive && now >= _BleedStacks[entIdx].expireTime) {
            // DPS proporcional a stacks: más balas = más sangrado
            local dps = (stacks * HUNTING_BLEED_DMG_PER_STACK).tofloat() / HUNTING_BLEED_DURATION
            SE.ApplyDoT(victim, "dot_bleed",
                dps, HUNTING_BLEED_DURATION, attacker)
            _BleedStacks[entIdx].expireTime = now + HUNTING_BLEED_DURATION
            _BleedStacks[entIdx].stacks = 1 // Reset stacks al iniciar nuevo ciclo DoT

            this.Dbg("Hunting bleed DoT applied: entIdx=" + entIdx + " dps=" + dps)
        }

        // --- AoE INSTANTÁNEO (siempre, aunque la víctima muera) ---
        local aoeDmg = stacks * HUNTING_BLEED_DMG_PER_STACK * 0.5
        _ApplyHuntingAoE(origin, aoeDmg, attacker, victim)

        // Wound decal (solo si viva)
        if (isAlive && NetProps.GetPropInt(victim, "m_iRequestedWound1") == -1)
            NetProps.SetPropInt(victim, "m_iRequestedWound1", 22)

        // Limpieza periódica de stacks expirados
        _CleanupExpiredBleeds()
    }

    // Aplica daño AoE instantáneo alrededor del punto de impacto
    function _ApplyHuntingAoE(origin, aoeDmg, attacker, ignoreEnt) {
        if (aoeDmg <= 0) return

        // 🛡️ GUARD: Previene cascada — el AoE de un common daña otro common
        // → infected_hurt → _ApplyHuntingBleed → _ApplyHuntingAoE → ∞
        if (_HuntingAoEActive) return
        _HuntingAoEActive = true

        try {
            local aoeOpts = { falloff = "linear", origin = origin, radius = HUNTING_BLEED_RADIUS }

            // Commons (CAP: evita crash con 20+ muertes simultáneas)
            local commons = MaoLib.AoE.Select.Circle(origin, HUNTING_BLEED_RADIUS, {
                className = "infected", ignoreEnt = ignoreEnt, aliveOnly = true,
                maxResults = HUNTING_AOE_MAX_COMMONS
            })
            if (commons.len() > 0)
                MaoLib.AoE.Apply.Damage(commons, aoeDmg, attacker, 131072, aoeOpts)

            // Special Infected (CAP: mismo límite por seguridad)
            local specials = MaoLib.AoE.Select.Circle(origin, HUNTING_BLEED_RADIUS, {
                className = "player",
                filter = function(ent) { return !ent.IsSurvivor() },
                ignoreEnt = ignoreEnt, aliveOnly = true,
                maxResults = 4
            })
            if (specials.len() > 0)
                MaoLib.AoE.Apply.Damage(specials, aoeDmg, attacker, 131072, aoeOpts)

            // Witch
            local witches = MaoLib.AoE.Select.Circle(origin, HUNTING_BLEED_RADIUS, {
                className = "witch", ignoreEnt = ignoreEnt, aliveOnly = true
            })
            if (witches.len() > 0)
                MaoLib.AoE.Apply.Damage(witches, aoeDmg, attacker, 131072, aoeOpts)

            this.Dbg("Hunting AoE one-shot: dmg=" + aoeDmg + " radius=" + HUNTING_BLEED_RADIUS)
        } catch(e) {
            this.DbgError("_ApplyHuntingAoE exception: " + e)
        }

        _HuntingAoEActive = false
    }

    // Limpia stacks de entidades cuyo DoT ya expiró o que ya no existen
    function _CleanupExpiredBleeds() {
        local now = Time()
        local toRemove = []

        foreach (entIdx, data in _BleedStacks) {
            // Si expiró hace más de 1s, limpiar
            if (data.expireTime > 0 && now - data.expireTime > 1.0) {
                toRemove.append(entIdx)
                continue
            }
            // Si la entidad ya no existe
            local ent = EntIndexToHScript(entIdx)
            if (!ent || !ent.IsValid()) {
                toRemove.append(entIdx)
            }
        }

        foreach (entIdx in toRemove)
            delete _BleedStacks[entIdx]
    }

    // ============================================================
    // DESERT RIFLE — Full-auto burst + Ramping logic
    // ============================================================
    function OnGameEvent_weapon_fire(params) {
        if (!DESERT_RAMP_ENABLED && !DESERT_FULLAUTO_ENABLED) return
        if (!("weapon" in params) || !("userid" in params)) return
        if (params.weapon != "rifle_desert") return

        local player = GetPlayerFromUserID(params.userid)
        if (!player || !player.IsValid() || !player.IsSurvivor()) return

        local weapon = player.GetActiveWeapon()
        if (!weapon || !weapon.IsValid() || weapon.GetClassname() != "weapon_rifle_desert") return

        // Ignorar bots — ellos manejan el burst nativamente
        if (IsPlayerABot(player)) return

        local now = Time()

        if (player in DesertStreaks) {
            DesertStreaks[player].lastShot = now
        } else {
            DesertStreaks[player] <- {
                startTime = now,
                lastShot = now
            }
            this.Dbg("Desert streak START for player " + player.GetPlayerUserId())
        }
    }

    function ScheduleDesertUpdate() {
        if (!DESERT_RAMP_ENABLED && !DESERT_FULLAUTO_ENABLED) return
		MaoLib.AddTimerForce("desert_ramp_update", 0.05, function() {
            try {
                ::L4CWI_RRLogic.UpdateDesertRamping()
            } catch (e) {
                ::L4CWI_RRLogic.DbgError("UpdateDesertRamping crash: " + e)
            }
        })
    }

    function UpdateDesertRamping() {
        // ================================================================
        // FASE 1: LIMPIAR SHOVE DEL FRAME ANTERIOR
        // Restaurar tiempos de ataque y reemplazar animaciones de shove
        // por animaciones de disparo para que el full-auto sea invisible.
        // ================================================================
        foreach (player, prevAttack in DesertShovePrevAttack) {
            if (!::MaoLib.IsReal(player)) continue

            local weapon = player.GetActiveWeapon()
            if (!weapon || !weapon.IsValid() || weapon.GetClassname() != "weapon_rifle_desert") continue

            // Calcular intervalo actual del ramp
            local streakTime = 0
            if (player in DesertStreaks)
                streakTime = Time() - DesertStreaks[player].startTime
            local interval = GetDesertInterval(streakTime)

            // Restaurar tiempos de ataque: prevAttack + interval
            local newAttack = prevAttack + interval
            NetProps.SetPropFloat(weapon, "m_flNextPrimaryAttack", newAttack)
            NetProps.SetPropFloat(weapon, "m_flNextSecondaryAttack", newAttack)
            NetProps.SetPropFloat(player, "m_flNextAttack", newAttack)

            // Quitar bit de shove forzado (solo el bit 2048, preservar el resto)
            local forced = NetProps.GetPropInt(player, "m_afButtonForced")
            if (forced & 2048)
                NetProps.SetPropInt(player, "m_afButtonForced", forced & ~2048)

            // Reemplazar animaciones: ocultar shove, mostrar disparo
            _ReplaceShoveAnimation(player, prevAttack)

            // Silenciar sonidos de shove
            StopSoundOn("Weapon.Swing", player)
            StopSoundOn("Weapon.HitWorld", player)
        }
        DesertShovePrevAttack.clear()

        // ================================================================
        // FASE 2: FORZAR SHOVE PARA NUEVO BURST (si aplica)
        // ================================================================
        if (DesertStreaks.len() == 0) return

        local now = Time()
        local toRemove = []
        local anyActive = false

        foreach (player, data in DesertStreaks) {
            if (!::MaoLib.IsReal(player) || !player.IsSurvivor() || NetProps.GetPropInt(player, "m_lifeState") != 0) {
                toRemove.append(player)
                continue
            }

            local weapon = player.GetActiveWeapon()
            if (!weapon || !weapon.IsValid() || weapon.GetClassname() != "weapon_rifle_desert") {
                toRemove.append(player)
                continue
            }

            local buttons = NetProps.GetPropInt(player, "m_nButtons")
            local holdingAttack = (buttons & 1) != 0

            if (!holdingAttack) {
                if (now - data.lastShot > 0.3) {
                    toRemove.append(player)
                    continue
                }
            } else {
                data.lastShot = now
            }

            anyActive = true

            local streakTime = now - data.startTime
            local interval = GetDesertInterval(streakTime)
            local nextAttack = NetProps.GetPropFloat(weapon, "m_flNextPrimaryAttack")

            // --- FULL-AUTO: Forzar shove para reiniciar burst cycle ---
            if (DESERT_FULLAUTO_ENABLED && holdingAttack && nextAttack <= now + 0.02) {
                // Guardar m_flNextPrimaryAttack actual para restaurar en Fase 1
                DesertShovePrevAttack[player] <- nextAttack

                // Resetear penalización de shove
                NetProps.SetPropInt(player, "m_iShovePenalty", 0)

                // Forzar shove (bit 2048 = BUTTON_SHOVE)
                local forced = NetProps.GetPropInt(player, "m_afButtonForced")
                NetProps.SetPropInt(player, "m_afButtonForced", forced | 2048)

                this.Dbg("Desert full-auto pulse — streakTime: " + streakTime + " interval: " + interval)
            }

            // --- RAMPING: Acelerar cadencia de disparo ---
            if (nextAttack > now) {
                local desiredNext = now + interval
                if (desiredNext < nextAttack && desiredNext >= now + 0.01) {
                    NetProps.SetPropFloat(weapon, "m_flNextPrimaryAttack", desiredNext)
                    NetProps.SetPropFloat(player, "m_flNextAttack", desiredNext)
                }
            }

            // Update rrlogic recoil if active
            if (RRLOGIC_DETECTED) {
                local recoilMult = GetRRLogicRecoilMult(streakTime)
                ApplyRRLogicRecoilMult(recoilMult)
            }
        }

        foreach (player in toRemove) {
            if (player in DesertStreaks) {
                delete DesertStreaks[player]
                if (player in DesertShovePrevAttack) delete DesertShovePrevAttack[player]
                this.Dbg("Desert streak END for player " + (player.IsValid() ? player.GetPlayerUserId() : "INVALID"))
            }
        }

        if (!anyActive && RRLOGIC_DETECTED) {
            RestoreRRLogicDefaults()
        }
    }

    // ================================================================
    // ANIMATION FIX — Reemplaza animación de shove por disparo
    // ================================================================
    // Cuando forzamos shove para full-auto, el engine reproduce la
    // animación de shove. Esto la reemplaza por la animación de disparo
    // para que el full-auto sea invisible.
    // ================================================================
    function _ReplaceShoveAnimation(player, prevAttack) {
        try {
            // Reemplazar gesture (animación de brazos en 3ra persona)
            NetProps.SetPropIntArray(player, "m_NetGestureSequence", 421, 0)
            NetProps.SetPropIntArray(player, "m_NetGestureActivity", 947, 0)
            NetProps.SetPropFloatArray(player, "m_NetGestureStartTime", prevAttack, 0)

            // Reemplazar viewmodel layer (animación del arma en 1ra persona)
            local viewmodel = NetProps.GetPropEntity(player, "m_hViewModel")
            if (viewmodel && viewmodel.IsValid()) {
                NetProps.SetPropInt(viewmodel, "m_nLayer", 0)
                NetProps.SetPropInt(viewmodel, "m_nLayerSequence", 6)
                NetProps.SetPropFloat(viewmodel, "m_flLayerStartTime", prevAttack)
            }
        } catch (e) {
            this.DbgWarn("_ReplaceShoveAnimation failed: " + e)
        }
    }

    function GetDesertInterval(streakTime) {
        if (streakTime <= 0) return DESERT_RAMP_START_INTERVAL
        if (streakTime >= DESERT_RAMP_ACCEL_TIME) return DESERT_RAMP_MAX_INTERVAL

        local t = streakTime / DESERT_RAMP_ACCEL_TIME
        return DESERT_RAMP_START_INTERVAL - (DESERT_RAMP_START_INTERVAL - DESERT_RAMP_MAX_INTERVAL) * t
    }

    // ============================================================
    // DESERT RIFLE — Ammo management
    // ============================================================
    function OnGameEvent_ammo_pickup(params) {
        if (!DESERT_RAMP_ENABLED) return
        if (!("userid" in params)) return

        local player = GetPlayerFromUserID(params.userid)
        if (!::L4CWI_Core.IsSurvivorAlive(player)) return

        local weapon = player.GetActiveWeapon()
        if (!weapon || weapon.GetClassname() != "weapon_rifle_desert") return

        GiveDesertAmmoBonus(player, DESERT_AMMO_MULT)
    }

    function ScheduleDesertAmmoCheck() {
        if (!DESERT_RAMP_ENABLED) return
        MaoLib.AddTimerForce("desert_ammo_check", DESERT_AMMO_CHECK_INTERVAL, function() {
            try {
                ::L4CWI_RRLogic.CheckDesertAmmo()
            } catch (e) {
                ::L4CWI_RRLogic.DbgError("CheckDesertAmmo crash: " + e)
            }
        })
    }

    function CheckDesertAmmo() {
        local ent = null
        while (ent = Entities.FindByClassname(ent, "player")) {
            if (!ent.IsValid() || !ent.IsSurvivor()) continue
            if (NetProps.GetPropInt(ent, "m_lifeState") != 0) continue

            local weapon = ent.GetActiveWeapon()
            if (!weapon || weapon.GetClassname() != "weapon_rifle_desert") continue

            local ammoType = NetProps.GetPropInt(weapon, "m_iPrimaryAmmoType")
            local currentAmmo = NetProps.GetPropIntArray(ent, "m_iAmmo", ammoType)

            if (currentAmmo < DESERT_AMMO_THRESHOLD) {
                GiveDesertAmmoBonus(ent, 1)
            }
        }
    }

    function GiveDesertAmmoBonus(player, multiplier) {
        if (!::MaoLib.IsReal(player)) return

        local weapon = player.GetActiveWeapon()
        if (!weapon || !weapon.IsValid() || weapon.GetClassname() != "weapon_rifle_desert") return

        local ammoType = NetProps.GetPropInt(weapon, "m_iPrimaryAmmoType")
        local currentAmmo = NetProps.GetPropIntArray(player, "m_iAmmo", ammoType)

        local bonus = (multiplier > 1) ? (currentAmmo * (multiplier - 1)) : DESERT_AMMO_BONUS
        local newAmmo = currentAmmo + bonus

        if (newAmmo > 999) newAmmo = 999

        NetProps.SetPropIntArray(player, "m_iAmmo", newAmmo, ammoType)

        if (multiplier > 1) {
            this.Dbg("Desert ammo pickup bonus: " + bonus + " (total: " + newAmmo + ")")
        }
    }

    // ============================================================
    // CLEANUP
    // ============================================================
    function OnGameEvent_round_start(params) {
        this.Dbg("ENTER OnGameEvent_round_start")
        if (DESERT_RAMP_ENABLED || DESERT_FULLAUTO_ENABLED) {
            ScheduleDesertUpdate()
        }
        if (DESERT_RAMP_ENABLED) {
            ScheduleDesertAmmoCheck()
        }
        this.Dbg("EXIT OnGameEvent_round_start")
    }

    function OnGameEvent_round_end(params) {
        this.Dbg("ENTER OnGameEvent_round_end")
        // Cleanup timers (previenen fuga entre rondas)
        MaoLib.RemoveTimer("desert_ramp_update")
        MaoLib.RemoveTimer("desert_ammo_check")
        _BleedStacks = {}
        DesertStreaks = {}
        DesertShovePrevAttack.clear()

        // El DoT Subsystem de MaoLib limpia sus propios datos en round_end
        if ("StatusEffects" in ::MaoLib && "ClearAllDoTs" in ::MaoLib.StatusEffects)
            ::MaoLib.StatusEffects.ClearAllDoTs()

        if (RRLOGIC_DETECTED) {
            RestoreRRLogicDefaults()
        }
        this.Dbg("EXIT OnGameEvent_round_end")
    }

    function OnGameEvent_player_disconnect(params) {
        if (!("userid" in params)) return

        local player = GetPlayerFromUserID(params.userid)
        if (!player || !player.IsValid()) return

        if (player in DesertStreaks) {
            delete DesertStreaks[player]
            this.Dbg("Desert streak removed on disconnect for " + params.userid)
        }

        // Clean bleed tracking where this player was the attacker
        // (No op necesario — _BleedStacks se limpia en _CleanupExpiredBleeds y round_end)
    }
}

__CollectGameEventCallbacks(::L4CWI_RRLogic)
::L4CWI_Core.RegisterSystem("RRLogic", ::L4CWI_RRLogic)
printl("[L4CWI] RRLogic System v" + ::L4CWI_RRLogic.VERSION + " loaded")
