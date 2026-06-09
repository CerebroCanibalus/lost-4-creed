// ============================================================
// L4CWI — Electric Axe (Chain Lightning) v3.0
// Melee con 33% chance de chain lightning por golpe
// Pellets reducidos a 6, cada uno puede saltar hasta 3 veces
// ============================================================

::L4CWI_ElectricAxe <- {
    CONFIG_PATH = "l4cwi_config/electric_axe.cfg"
    
    // === CONFIGURABLE ===
    ENABLED = true
    TRIGGER_CHANCE = 33           // % chance por swing
    DAMAGE_PER_PELLET = 20        // Daño base por pellet (hit directo)
    MAX_PELLETS = 6               // Pellets de origen (antes 26)
    GORE_MODE = true              // Destroza commons
    BURNING_LIGHTNING = true      // Daño tipo fuego
    MAX_RANGE = 200               // Alcance del rayo (reducido 30%, era 280)
    CHAIN_RADIUS = 125            // Radio de salto entre infectados (reducido 30%, era 180)
    CHAIN_JUMPS = 3               // Máximo saltos por cadena
    CHAIN_FALLOFF = 0.6           // Multiplicador de daño por salto (0.6 = 60%)
    
    // === CONSTANTES ===
    DMG_BURN = 13
    DMG_BUCKSHOT = 6 + (1 << 25)  // 33554438
    
    function Init() {
        local defaults = {
            enabled = true,
            trigger_chance = 33,
            damage_per_pellet = 20,
            max_pellets = 6,
            gore_mode = true,
            burning_lightning = true,
            max_range = 200,
            chain_radius = 125,
            chain_jumps = 3,
            chain_falloff = 0.6,
        }
        
        local cfg = ::L4CWI_Core.ParseConfig(CONFIG_PATH, defaults)
        ENABLED = cfg.enabled
        TRIGGER_CHANCE = cfg.trigger_chance
        DAMAGE_PER_PELLET = cfg.damage_per_pellet
        MAX_PELLETS = cfg.max_pellets
        GORE_MODE = cfg.gore_mode
        BURNING_LIGHTNING = cfg.burning_lightning
        MAX_RANGE = cfg.max_range
        CHAIN_RADIUS = cfg.chain_radius
        CHAIN_JUMPS = cfg.chain_jumps
        CHAIN_FALLOFF = cfg.chain_falloff
        
        this._Dbg("Electric Axe init — chance: " + TRIGGER_CHANCE + 
                  "%, dmg/pellet: " + DAMAGE_PER_PELLET +
                  ", pellets: " + MAX_PELLETS +
                  ", chain: " + CHAIN_JUMPS + " jumps @ " + CHAIN_RADIUS + "u")
    }
    
    // ============================================================
    // TRIGGER: Cada swing de melee
    // ============================================================
    function OnGameEvent_weapon_fire(params) {
        // Filtros tempranos — silenciosos (weapon_fire se dispara para TODAS las armas)
        if (!ENABLED) return
        if (!("weapon" in params) || params.weapon != "melee") return
        if (!("userid" in params)) return
        
        local player = GetPlayerFromUserID(params.userid)
        if (!player || !player.IsValid() || !player.IsSurvivor()) return
        if (NetProps.GetPropInt(player, "m_lifeState") != 0) return
        
        // Solo fireaxe
        if (!IsFireAxe(player)) return
        
        // 33% chance
        local roll = RandomInt(0, 99)
        if (roll >= TRIGGER_CHANCE) {
            this._Dbg("ABORT: roll failed (" + roll + "/" + TRIGGER_CHANCE + ")")
            return
        }
        
        this._Dbg("Electric blast triggered by " + player.GetEntityIndex())
        ShootElectricBlast(player)
    }
    
    function IsFireAxe(player) {
        local weapon = player.GetActiveWeapon()
        if (!weapon || !weapon.IsValid()) return false
        
        local model = NetProps.GetPropString(weapon, "m_ModelName")
        return model != null && model.find("fireaxe") != null
    }
    
    // ============================================================
    // DISPARO ELÉCTRICO
    // ============================================================
    function ShootElectricBlast(player) {
        this._Dbg("ENTER ShootElectricBlast")
        
        // Obtener posición del arma (fireaxe) en vez de usar EyePosition
        local weapon = player.GetActiveWeapon()
        local origin = player.EyePosition()  // fallback
        if (weapon && weapon.IsValid()) {
            local wepPos = weapon.GetOrigin()
            if (wepPos && wepPos != Vector(0, 0, 0)) {
                origin = wepPos + Vector(0, 0, 8)  // weapon origin + pequeño nudge up
            } else {
                // Fallback manual: offset desde ojo a mano/arma
                origin = player.EyePosition() + Vector(20, -8, -25)
            }
        } else {
            origin = player.EyePosition() + Vector(20, -8, -25)
        }
        
        local eyeAngles = player.EyeAngles()
        
        // Efectos visuales — ahora desde el arma, no desde los ojos
        ::MaoLib_VFX.SpawnParticle(origin, "electrical_jacobs_ladder", 0.5)
        ::MaoLib_VFX.SpawnParticle(origin, "particle_glow_04_additive", 0.3)
        EmitSoundOn("ambient.electrical_random_zap_1", player)
        
        // Trace pellets (origen de chains)
        TraceElectricPellets(player, origin, eyeAngles)
        this._Dbg("EXIT ShootElectricBlast")
    }
    
    // ============================================================
    // TRACE PELLETS + CHAIN LIGHTNING
    // ============================================================
    function TraceElectricPellets(player, origin, baseAngles) {
        this._Dbg("ENTER TraceElectricPellets — pellets=" + MAX_PELLETS + " dmg=" + DAMAGE_PER_PELLET)
        
        // visited[ent] = true — previene doble daño en la misma ráfaga
        local visited = {}
        local entDamage = {}
        
        for (local i = 0; i < MAX_PELLETS; i++) {
            // Spread circular
            local radius = 4 * sqrt(RandomFloat(0, 1))
            local ang = RandomFloat(0, 360)
            local spread = QAngle(radius * sin(ang), radius * cos(ang), 0)
            local pelletAng = RotateOrientation(baseAngles, spread)
            
            local traceParams = {
                start = origin
                end = origin + VectorFromQAngle(pelletAng, MAX_RANGE)
                ignore = player
            }
            
            local penetrations = 0
            while (TraceLine(traceParams) && traceParams.hit) {
                local penMult = (penetrations > 0) ? 0.99 : 1.0
                
                if (("enthit" in traceParams) && traceParams.enthit && traceParams.enthit.GetEntityIndex() > 0) {
                    local entClass = traceParams.enthit.GetClassname()
                    local ent = traceParams.enthit
                    
                    // ¿Es objetivo válido?
                    local isValidTarget = false
                    if (entClass == "player" && !ent.IsSurvivor()) {
                        isValidTarget = true
                    } else if (entClass == "infected" || entClass == "witch") {
                        isValidTarget = true
                    }
                    
                    if (isValidTarget) {
                        // Marcar visitado y acumular daño
                        if (!(ent in visited)) {
                            visited[ent] <- true
                            entDamage[ent] <- 0
                        }
                        entDamage[ent] += DAMAGE_PER_PELLET * penMult
                        
                        // FX de impacto directo
                        ::MaoLib_VFX.SpawnParticle(traceParams.pos, "electrical_arc_01", 0.4)
                        ::MaoLib_VFX.SpawnParticle(traceParams.pos, "particle_glow_04_additive", 0.3)
                        
                        // CHAIN LIGHTNING: saltar a cercanos
                        ProcessChainLightning(ent, player, visited, entDamage, 1)
                    } else {
                        // Props, etc. — daño simple sin chain
                        if (!(ent in entDamage)) entDamage[ent] <- 0
                        entDamage[ent] += DAMAGE_PER_PELLET * penMult
                        
                        // Impulso físico en props
                        if (penetrations == 0 && (entClass == "func_physbox" || entClass == "prop_ragdoll")) {
                            local impulse = AnglesToForward(pelletAng) * 500
                            try {
                                ent.ApplyAbsVelocityImpulse(impulse)
                            } catch (e) {}
                        }
                    }
                } else {
                    // Hit mundo
                    ::MaoLib_VFX.SpawnParticle(traceParams.pos, "electrical_arc_01", 0.3)
                    ::MaoLib_VFX.SpawnParticle(traceParams.pos, "particle_glow_04_additive", 0.2)
                }
                
                if (++penetrations > 5) break
                
                traceParams.start = traceParams.pos + VectorFromQAngle(pelletAng, 32)
                if (("enthit" in traceParams) && traceParams.enthit) {
                    traceParams.ignore = traceParams.enthit
                }
            }
        }
        
        // Aplicar daño acumulado
        ApplyDamageToEntities(entDamage, player)
        
        this._Dbg("EXIT TraceElectricPellets")
    }
    
    // ============================================================
    // CHAIN LIGHTNING
    // Salta de entidad a entidad cercana, aplicando daño escalonado
    // ============================================================
    function ProcessChainLightning(sourceEnt, player, visited, entDamage, jumpCount) {
        if (jumpCount > CHAIN_JUMPS) return
        
        local sourcePos = sourceEnt.GetOrigin()
        local playerOrigin = player.GetOrigin()
        local bestTarget = null
        local bestDist = CHAIN_RADIUS + 1
        
        // Helper inline: filtrar candidatos fuera de MAX_RANGE del player
        // (la cadena no debe superar el rango máximo del arma)
        local IsInPlayerRange = function(candidate) {
            return MaoLib.DistanceBetween(playerOrigin, candidate.GetOrigin()) <= MAX_RANGE
        }
        
        // Buscar el infectado más cercano no visitado
        foreach (candidate in MaoLib.YieldSpecials()) {
            if (candidate == sourceEnt) continue
            if (candidate in visited) continue
            if (!MaoLib.IsAlive(candidate)) continue
            if (!IsInPlayerRange(candidate)) continue  // ← filtro de rango
            
            local dist = MaoLib.DistanceBetween(sourcePos, candidate.GetOrigin())
            if (dist < bestDist) {
                bestDist = dist
                bestTarget = candidate
            }
        }
        
        // También buscar commons
        if (!bestTarget) {
            local ent = null
            while ((ent = Entities.FindByClassname(ent, "infected")) != null) {
                if (ent == sourceEnt) continue
                if (ent in visited) continue
                if (NetProps.GetPropInt(ent, "m_lifeState") != 0) continue
                if (!IsInPlayerRange(ent)) continue  // ← filtro de rango
                
                local dist = MaoLib.DistanceBetween(sourcePos, ent.GetOrigin())
                if (dist < bestDist) {
                    bestDist = dist
                    bestTarget = ent
                }
            }
        }
        
        // También buscar witches
        if (!bestTarget) {
            local ent = null
            while ((ent = Entities.FindByClassname(ent, "witch")) != null) {
                if (ent == sourceEnt) continue
                if (ent in visited) continue
                if (NetProps.GetPropInt(ent, "m_lifeState") != 0) continue
                if (!IsInPlayerRange(ent)) continue  // ← filtro de rango
                
                local dist = MaoLib.DistanceBetween(sourcePos, ent.GetOrigin())
                if (dist < bestDist) {
                    bestDist = dist
                    bestTarget = ent
                }
            }
        }
        
        if (!bestTarget) return
        
        // Calcular daño escalado
        local dmgMult = 1.0
        for (local j = 0; j < jumpCount; j++) {
            dmgMult *= CHAIN_FALLOFF
        }
        local chainDamage = DAMAGE_PER_PELLET * dmgMult
        
        // Marcar visitado y acumular daño
        visited[bestTarget] <- true
        if (!(bestTarget in entDamage)) entDamage[bestTarget] <- 0
        entDamage[bestTarget] += chainDamage
        
        // FX de salto
        local targetPos = bestTarget.GetOrigin()
        ::MaoLib_VFX.SpawnParticle(targetPos, "electrical_arc_01", 0.4)
        ::MaoLib_VFX.SpawnParticle(targetPos, "particle_glow_04_additive", 0.3)
        
        // Sonido de arco (más suave cada salto)
        local volume = 1.0 - (jumpCount * 0.25)
        ::MaoLib_VFX.EmitSound(bestTarget, "ambient.electrical_random_zap_1", volume)
        
        this._Dbg("Chain jump " + jumpCount + ": " + sourceEnt.GetEntityIndex() + 
                  " -> " + bestTarget.GetEntityIndex() + " dmg=" + chainDamage)
        
        // Recursión para siguiente salto
        ProcessChainLightning(bestTarget, player, visited, entDamage, jumpCount + 1)
    }
    
    // ============================================================
    // APLICAR DAÑO
    // ============================================================
    function ApplyDamageToEntities(entDamage, player) {
        local dmgType = BURNING_LIGHTNING ? DMG_BURN : DMG_BUCKSHOT
        local totalEntities = 0
        local totalDamage = 0
        
        foreach (entity, damage in entDamage) {
            if (damage <= 0) continue
            if (!entity || !entity.IsValid()) continue
            if (NetProps.GetPropInt(entity, "m_lifeState") != 0) continue
            
            totalEntities++
            totalDamage += damage
            
            local entClass = entity.GetClassname()
            
            if (entClass == "player" || entClass == "infected" || entClass == "witch") {
                entity.TakeDamage(damage, dmgType, player)
                
                // Gore mode: destroza commons muertos por rayo
                if (GORE_MODE && entClass == "infected") {
                    if (entity.GetHealth() - damage <= 0) {
                        if (NetProps.GetPropInt(entity, "m_iRequestedWound1") == -1) {
                            NetProps.SetPropInt(entity, "m_iRequestedWound1", 22)
                        }
                    }
                }
            }
        }
        
        this._Dbg("Damage applied — entities=" + totalEntities + " totalDmg=" + totalDamage)
    }
    
    // ============================================================
    // HELPERS
    // ============================================================
    function VectorFromQAngle(angles, radius) {
        local yaw = angles.Yaw() * (3.14159265 / 180.0)
        local pitch = -angles.Pitch() * (3.14159265 / 180.0)
        local cp = cos(pitch)
        return Vector(cos(yaw) * cp * radius, sin(yaw) * cp * radius, sin(pitch) * radius)
    }
    
    function AnglesToForward(angles) {
        local yaw = angles.y * (3.14159265 / 180.0)
        local pitch = angles.x * (3.14159265 / 180.0)
        local cp = cos(pitch)
        return Vector(cos(yaw) * cp, sin(yaw) * cp, -sin(pitch))
    }
}

__CollectGameEventCallbacks(::L4CWI_ElectricAxe)
::L4CWI_Core.RegisterSystem("ElectricAxe", ::L4CWI_ElectricAxe)
printl("[L4CWI] Electric Axe System v3.0 loaded")
