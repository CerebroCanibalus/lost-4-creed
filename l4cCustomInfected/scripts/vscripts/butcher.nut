// ===================================================================
// L4C Butcher Berserker — "El Desgarrador"
// Lost 4 Creed Modpack
//
// Rework completo: Furia + Slow/AoE melee + Grito activable (reemplaza vomit)
// ===================================================================

::ButcherBerserker <-
{
    // ============================================================
    // SETTINGS
    // ============================================================
    settings =
    {
        spawn_chance = 38,          // 38% de probabilidad (porcentaje)
        health = 2960,              // VIDA (-26% de 4000)
        base_speed = 0.65,          // MUY LENTO BASE (compensado por furia)
        
        // Furia: sistema de carga por daño recibido (Opción B)
        fury_thresholds = [200, 400, 600],  // Daño acumulado para stack 1/2/3
        fury_charge_decay = 30,     // Pierde 30 de carga por segundo sin recibir daño
        fury_charge_decay_delay = 2.0,  // Espera 2s tras último hit antes de decaer
        fury_speed_bonus = [0.35, 0.70, 1.10],  // +35%, +70%, +110% (progresivo pero controlado)
        
        // Golpe Demoledor: Slow + AoE (poco daño, el poder es el control)
        slow_amount = 0.35,         // Survivor a 35% de velocidad
        slow_duration = 1.25,       // Segundos
        aoe_radius = 200,           // Unidades de radio (antes 120)
        aoe_damage = 6,             // MUY poco daño (survivors = 100HP)
        combo_bonus_damage = 8,     // Daño extra del 4to golpe
        
        // Grito (reemplaza vomit)
        roar_radius = 300,          // Rango reducido
        roar_stun_duration = 1.5,   // Duración del stagger animación
        roar_damage = 5,            // MUY poco daño
        roar_cooldown = 12.0,       // Segundos entre gritos
        roar_bot_range = 350,       // Bots gritan cuando survivor está a esta distancia (muy reducido)
        roar_telegraph = 0.76,      // Segundos de telegrafiado antes del grito
        
        // Partículas
        fury_particle = "charger_motion_blur",         // Efecto velocidad al subir furia
        roar_particle = "impact_sand",                 // Onda expansiva del grito
        roar_wave_particle = "impact_ricochet",        // Explosión secundaria del grito
        roar_shockwave_particle = "flame_blue",        // Llama azul a nivel del suelo
        roar_telegraph_particle = "charger_motion_blur", // Anillo de advertencia veloz
        impact_particle = "impact_asphalt",            // Impacto seco contra suelo
        fall_shockwave = "flame_blue",                 // Llama azul al caer
        fall_debris = "impact_asphalt",                // Escombros de caída
    },
    
    // Sonidos
    sounds =
    {
        fury = "Player.Tank.Attack",
        melee_aoe = "Melee.ImpactFlesh",
        combo = "Player.Tank.Pound",            // Sonido del combo (4to golpe)
        roar = "HunterZombie.Pounce",           // Grito del Hunter (más aterrador)
        roar_telegraph = "ChargerZombie.Charge", // Sonido de carga antes del grito
        roar_pitch_min = 70,                     // Pitch mínimo (grave, audible)
        roar_pitch_max = 100,                    // Pitch máximo (normal)
    },
    
    // Delay antes de conversión (compatibilidad con otros scripts)
    convertDelay = 0.18,
    
    // ============================================================
    // EVENTOS
    // ============================================================
    
    function OnGameEvent_round_start(params)
    {
        printl("[BUT-DEBUG] === round_start FIRED ===")
        
        if (!IsModelPrecached("models/infected/butcher.mdl"))
        {
            PrecacheModel("models/infected/butcher.mdl")
            printl("[BUT-DEBUG] Precaching butcher model...")
        }
        else
        {
            printl("[BUT-DEBUG] Model already precached")
        }
        
        // Precache sonidos (todos los strings válidos: sound scripts Y archivos raw)
        foreach (name, path in sounds)
        {
            if (typeof(path) == "string" && path.len() > 0)
            {
                if (!IsSoundPrecached(path))
                    PrecacheSound(path)
            }
        }
        
        // Thinker global via MaoLib (SIEMPRE disponible — cargado por l4cCoreAddon)
        // ⚠️ NUNCA usar if("MaoLib" in getroottable()) — es dependencia dura, no opcional
        if (MaoLib.IsTimerActive("butcher_global_think"))
        {
            printl("[BUT-DEBUG] Removing old timer")
            MaoLib.RemoveTimer("butcher_global_think")
        }
        
        // INTERVALO 0.3s — suficiente para AI sin spamear CommandABot
        MaoLib.AddTimer("butcher_global_think", 0.3, function() {
            ::ButcherBerserker.GlobalThinker()
        })
        
        printl("[BUT-DEBUG] Timer active: " + MaoLib.IsTimerActive("butcher_global_think"))
    }
    
    function OnGameEvent_player_spawn(params)
    {
        if (!("userid" in params)) 
        {
            printl("[BUT-DEBUG] player_spawn: no userid")
            return
        }
        
        local player = GetPlayerFromUserID(params.userid)
        if (!player || !player.IsValid()) 
        {
            printl("[BUT-DEBUG] player_spawn: invalid player")
            return
        }
        
        local ztype = player.GetZombieType()
        local isBot = IsPlayerABot(player)
        
        printl("[BUT-DEBUG] player_spawn: userid=" + params.userid + " ztype=" + ztype + " isBot=" + isBot)
        
        // Solo boomers bots
        if (ztype == 2 && isBot)
        {
            local shouldConvert = false
            
            // Debug force: override random chance
            if ("debug_force_next" in this && this.debug_force_next)
            {
                if (Time() < this.debug_force_timeout)
                {
                    shouldConvert = true
                    this.debug_force_next = false
                    printl("[BUT-DEBUG] DEBUG FORCE: Converting this boomer!")
                }
                else
                {
                    this.debug_force_next = false
                    printl("[BUT-DEBUG] DEBUG FORCE expired")
                }
            }
            
            if (!shouldConvert)
            {
                local roll = RandomInt(1, 100)
                shouldConvert = (roll <= settings.spawn_chance)
                printl("[BUT-DEBUG] Boomer bot spawned! Roll=" + roll + "/100 chance=" + settings.spawn_chance + "% convert=" + shouldConvert)
            }
            
            if (shouldConvert)
            {
                local player_idx = player.GetEntityIndex()
                printl("[BUT-DEBUG] CONVERTING! entidx=" + player_idx)
                
                if (player_idx > 0 && player_idx < 65536)
                {
                    EntFire("worldspawn", "RunScriptCode",
                        "::ButcherBerserker.DelayedConvert(" + player_idx + ")",
                        convertDelay, null)
                    printl("[BUT-DEBUG] DelayedConvert scheduled")
                }
                else
                {
                    printl("[BUT-DEBUG] ERROR: Invalid entity index " + player_idx)
                }
            }
            else
            {
                printl("[BUT-DEBUG] Roll failed, staying as boomer")
            }
        }
    }
    
    // ============================================================
    // DAÑO — FURIA (recibir) + GOLPE DEMOLEDOR (causar)
    // ============================================================
    
    function OnGameEvent_player_hurt(params)
    {
        HandlePlayerHurt(params)
    }
    
    function HandlePlayerHurt(params)
    {
        local victim = GetPlayerFromUserID(params.userid)
        if (!victim || !victim.IsValid()) return
        
        // Calcular posición estimada del impacto
        local impact_pos = victim.GetOrigin() + Vector(0, 0, 48)
        if ("attacker" in params && params.attacker > 0)
        {
            local attacker = GetPlayerFromUserID(params.attacker)
            if (attacker && attacker.IsValid())
            {
                // Punto intermedio entre atacante y víctima, más cerca de la víctima
                local dir = victim.GetOrigin() - attacker.GetOrigin()
                dir.Norm()
                impact_pos = victim.GetOrigin() - (dir * 20) + Vector(0, 0, 48)
            }
        }
        
        // ---- CASO 1: Butcher RECIBE daño → FURIA + Partículas + Lifesteal ----
        if (IsButcher(victim))
        {
            local dmg = ("dmg_health" in params) ? params.dmg_health : ("damage" in params ? params.damage : 10)
            
            // Furia: acumular daño recibido
            AddFuryCharge(victim, dmg)
            
        // Partículas de impacto: humo de esporas + efecto podrido
        local imp_name1 = "but_imp1_" + victim.GetEntityIndex() + "_" + Time()
        local impact1 = SpawnEntityFromTable("info_particle_system", {
            targetname = imp_name1,
            origin = impact_pos,
            effect_name = settings.impact_particle,
            start_active = 1
        })
        if (impact1 && impact1.IsValid()) EntFire(imp_name1, "Stop", "", 0.6)
        if (impact1 && impact1.IsValid()) EntFire(imp_name1, "Kill", "", 1.0)
        
        // Lifesteal al recibir daño: más stacks = más curación
        local sc = victim.GetScriptScope()
        local stack = ("but_fury_stack" in sc) ? sc.but_fury_stack : 0
        local lifesteal_pct = 0.10 + (stack * 0.10)  // 10%, 20%, 30%, 40%
        local heal = (dmg * lifesteal_pct).tointeger()
        
        if (heal > 0)
        {
            local new_hp = victim.GetHealth() + heal
            local max_hp = victim.GetMaxHealth()
            if (new_hp > max_hp) new_hp = max_hp
            victim.SetHealth(new_hp)
            
            // Partícula de curación (chispas controladas)
            local spark_name = "but_spark_" + victim.GetEntityIndex() + "_" + Time()
            local spark = SpawnEntityFromTable("info_particle_system", {
                targetname = spark_name,
                origin = victim.GetOrigin() + Vector(0, 0, 64),
                effect_name = "impact_spark_spray",
                start_active = 1
            })
            if (spark && spark.IsValid()) EntFire(spark_name, "Stop", "", 0.3)
            if (spark && spark.IsValid()) EntFire(spark_name, "Kill", "", 0.6)
        }
            
            return
        }
        
        // ---- CASO 2: Butcher ATACA → Slow + AoE ----
        local attacker = null
        if ("attacker" in params && params.attacker > 0)
            attacker = GetPlayerFromUserID(params.attacker)
        
        if (!attacker || !IsButcher(attacker)) return
        
        // Detectar golpe melee (boomer_claw)
        if (params.weapon != "boomer_claw") return
        
        ProcessMeleeHit(attacker, victim)
    }
    
    // ============================================================
    // MUERTE — Prevenir explosión boomer
    // ============================================================
    
    function HandlePlayerDeath(params)
    {
        if (!("userid" in params)) return
        
        local player = GetPlayerFromUserID(params.userid)
        if (!player || !IsButcher(player)) return
        
        // DESTRUIR entidades de grito pendientes (evita que aparezcan después de morir)
        local sc = player.GetScriptScope()
        if (sc && "active_roar_entities" in sc)
        {
            foreach (ent in sc.active_roar_entities)
            {
                if (ent && ent.IsValid())
                    ent.Kill()
            }
            sc.active_roar_entities = []
        }
        
        // Guardar valores originales y prevenir explosión boomer
        local inner_orig = Convars.GetFloat("z_exploding_inner_radius")
        local outer_orig = Convars.GetFloat("z_exploding_outer_radius")
        Convars.SetValue("z_exploding_inner_radius", 0)
        Convars.SetValue("z_exploding_outer_radius", 0)
        EntFire("worldspawn", "RunScriptCode",
            "Convars.SetValue(\"z_exploding_inner_radius\", " + inner_orig + "); Convars.SetValue(\"z_exploding_outer_radius\", " + outer_orig + ");",
            0.2, null)
    }
    
    function OnGameEvent_round_end(params)
    {
        MaoLib.RemoveTimer("butcher_global_think")
    }
    
    // ============================================================
    // CONVERSIÓN
    // ============================================================
    
    function DelayedConvert(player_idx)
    {
        printl("[BUT-DEBUG] DelayedConvert called for idx=" + player_idx)
        
        local player = EntIndexToHScript(player_idx)
        if (!player || !player.IsValid()) 
        {
            printl("[BUT-DEBUG] DelayedConvert: Player invalid or dead")
            return
        }
        
        if (player.GetZombieType() != 2) 
        {
            printl("[BUT-DEBUG] DelayedConvert: Not a boomer anymore (ztype=" + player.GetZombieType() + ")")
            return
        }
        
        if (!IsPlayerABot(player)) 
        {
            printl("[BUT-DEBUG] DelayedConvert: Not a bot anymore")
            return
        }
        
        try { player.ValidateScriptScope() } catch (e) {}
        local sc = player.GetScriptScope()
        
        if (sc)
        {
            if ("IsScreamer" in sc || "IsBomber" in sc || "IsButcher" in sc || "IsHellhound" in sc)
            {
                printl("[BUT-DEBUG] DelayedConvert: Already converted to another special")
                return
            }
        }
        
        printl("[BUT-DEBUG] DelayedConvert: Proceeding with conversion")
        ConvertButcher(player)
    }
    
    function ConvertButcher(player)
    {
        printl("[BUT-DEBUG] === CONVERTING TO BUTCHER ===")
        
        // Stats
        player.SetMaxHealth(settings.health)
        player.SetHealth(settings.health)
        // Mismo source que fury stacks ("butcher_fury") — reemplaza, no multiplica
        MaoLib.Modifiers.RegisterSpeed(player, settings.base_speed, -1, "butcher_fury")
        
        printl("[BUT-DEBUG] HP set to " + settings.health)
        
        // Tag
        player.ValidateScriptScope()
        local sc = player.GetScriptScope()
        sc["IsButcher"] <- 1
        
        // Nombre
        SetFakeClientConVarValue(player, "name", "El Desgarrador")
        
        // Modelo (ruta custom para no reemplazar boomer vanilla)
        player.SetModel("models/infected/butcher.mdl")
        printl("[BUT-DEBUG] Model set to infected/butcher.mdl. Current: " + NetProps.GetPropString(player, "m_ModelName"))
        
        // Cooldown inicial del grito
        sc["but_roar_ready"] <- Time() + 3.0
        
        // Sonido spawn
        MaoLib_VFX.EmitSound(player, sounds.fury, 1.0, 100)
        
        // Desactivar vómito completamente
        for (local vomit; vomit = Entities.FindByClassname(vomit, "ability_vomit"); )
        {
            local owner = NetProps.GetPropEntity(vomit, "m_hOwnerEntity")
            if (owner == player)
            {
                NetProps.SetPropFloatArray(vomit, "m_nextActivationTimer", 999999, 0)
                NetProps.SetPropFloatArray(vomit, "m_nextActivationTimer", Time() + 999999, 1)
                NetProps.SetPropInt(vomit, "m_hasBeenUsed", 1)
            }
        }
        
        printl("[BUT-DEBUG] === CONVERSION COMPLETE ===")
    }
    
    // ============================================================
    // MECÁNICA 1: FURIA SANGRIENTA — Sistema de carga por daño (Opción B)
    // ============================================================
    
    function AddFuryCharge(but, damage_received)
    {
        local sc = but.GetScriptScope()
        local now = Time()
        
        // Inicializar carga si es primer hit
        if (!("but_fury_charge" in sc))
        {
            sc.but_fury_charge <- 0
            sc.but_fury_stack <- 0
        }
        
        // Acumular daño recibido
        sc.but_fury_charge += damage_received
        sc.but_fury_last_hit <- now
        
        // Calcular stack basado en carga
        UpdateFuryStack(but)
    }
    
    function UpdateFuryStack(but)
    {
        local sc = but.GetScriptScope()
        local charge = sc.but_fury_charge
        local old_stack = sc.but_fury_stack
        
        // Determinar nuevo stack basado en umbrales
        local new_stack = 0
        if (charge >= settings.fury_thresholds[2]) new_stack = 3
        else if (charge >= settings.fury_thresholds[1]) new_stack = 2
        else if (charge >= settings.fury_thresholds[0]) new_stack = 1
        
        // Si subió de stack, feedback visual/sonoro
        if (new_stack > old_stack)
        {
            // Partícula de furia: anillo expansivo de gore
            // El radio y la cantidad de partículas crecen con el stack
            local fury_particles = MaoLib_VFX.SpawnRing(
                but.GetOrigin() + Vector(0, 0, 32),
                50 + (new_stack * 25),  // Radio crece con stack
                4 + (new_stack * 2),    // Más partículas con stack
                settings.fury_particle,
                {
                    expand = true,
                    duration = 1.5,
                    priority = "gameplay"
                }
            )
            // Auto-cleanup via SpawnRing (particles have lifetime)
            
            // Sonido
            MaoLib_VFX.EmitSound(but, sounds.fury, 0.9, RandomInt(95, 105))
        }
        
        sc.but_fury_stack = new_stack
        
        // Aplicar velocidad basada en stack actual
        local speed = settings.base_speed
        if (new_stack > 0 && new_stack <= settings.fury_speed_bonus.len())
            speed = settings.base_speed * (1.0 + settings.fury_speed_bonus[new_stack - 1])
        
        // Modifiers aplica automáticamente (think 0.3s)
        MaoLib.Modifiers.RegisterSpeed(but, speed, -1, "butcher_fury")
    }
    
    function DecayFuryCharge(but)
    {
        local sc = but.GetScriptScope()
        if (("but_fury_charge" in sc) && sc.but_fury_charge <= 0) return
        
        local now = Time()
        local time_since_hit = now - sc.but_fury_last_hit
        
        // Solo decaer si pasó el delay sin recibir daño
        if (time_since_hit > settings.fury_charge_decay_delay)
        {
            // Decay por tick (thinker corre cada 0.3s)
            sc.but_fury_charge -= settings.fury_charge_decay * 0.3
            if (sc.but_fury_charge < 0) sc.but_fury_charge = 0
            
            // Recalcular stack
            UpdateFuryStack(but)
        }
    }
    
    // ============================================================
    // MECÁNICA 2: GOLPE DEMOLEDOR (Slow + AoE)
    // ============================================================
    
    function ProcessMeleeHit(attacker, victim)
    {
        local sc = attacker.GetScriptScope()
        local now = Time()
        
        // ---- COMBO SALVAJE ----
        // Golpear al mismo survivor 3 veces en 3s → 4to golpe es MASIVO
        if (!("but_combo_target" in sc) || sc.but_combo_target != victim || (now - sc.but_combo_time) > 3.0)
        {
            // Nuevo combo o reset
            sc["but_combo_target"] <- victim
            sc["but_combo_count"] <- 1
            sc["but_combo_time"] <- now
        }
        else
        {
            // Mismo target, dentro de tiempo
            sc.but_combo_count++
            sc.but_combo_time = now
            
            // 4to golpe consecutivo = COMBO COMPLETADO
            if (sc.but_combo_count >= 4)
            {
                // Daño extra concentrado en la víctima
                victim.TakeDamage(settings.combo_bonus_damage, (1 << 2), attacker)
                
                // ---- KNOCKBACK: Repulsión desde la víctima (estilo Tank punch) ----
                local combo_radius = 80
                local victim_origin = victim.GetOrigin()
                local aoe_hits = 0
                
                for (local surv; surv = Entities.FindByClassnameWithin(surv, "player", victim_origin, combo_radius); )
                {
                    if (surv.IsValid() && surv.IsSurvivor() && NetProps.GetPropInt(surv, "m_lifeState") == 0)
                    {
                        if (surv != victim)
                        {
                            // Knockback: empujar desde la víctima hacia afuera
                            local dir = surv.GetOrigin() - victim_origin
                            dir.Norm()
                            dir.z = 0
                            dir.Norm()
                            
                            local dist = (surv.GetOrigin() - victim_origin).Length()
                            // Fuerza decrece con distancia: 350 cercano → 150 lejano
                            local force = 350 - ((dist / combo_radius) * 200)
                            
                            local impulse = dir * force
                            impulse.z = 120  // Componente vertical
                            
                            // Aplicar knockback + daño combo
                            try { surv.ApplyAbsVelocityImpulse(impulse) } catch (e) {}
                            surv.TakeDamage(6, (1 << 2), attacker)
                            aoe_hits++
                        }
                    }
                }
                
                // Knockback también en la víctima principal
                local victimDir = victim.GetOrigin() - attacker.GetOrigin()
                victimDir.Norm()
                victimDir.z = 0
                victimDir.Norm()
                local victimImpulse = victimDir * 280
                victimImpulse.z = 150
                try { victim.ApplyAbsVelocityImpulse(victimImpulse) } catch (e) {}
                
                // ---- PARTÍCULAS: Círculo de sangre en el suelo ----
                local combo_particles = MaoLib_VFX.SpawnCircleFilled(
                    victim.GetOrigin(),
                    combo_radius,
                    {
                        effect = "blood_impact_red_01",
                        count = 14,
                        duration = 1.2,
                        priority = "gameplay"
                    }
                )
                
                // Efectos visuales y sonido
                MaoLib_VFX.ScreenShake(victim.GetOrigin(), 8, 15, 0.5, 200)
                MaoLib_VFX.EmitSound(victim, sounds.combo, 1.0, 100)
                
                // Resetear combo
                sc.but_combo_count = 0
                
                printl("[BUT-DEBUG] COMBO SALVAJE en survivor idx=" + victim.GetEntityIndex() + " (knockback hits: " + aoe_hits + ")")
            }
        }
        
        // ---- SLOW SEVERO a la víctima principal (en TODOS los golpes) ----
        // Modifiers aplica + cleanup automático al expirar
        MaoLib.Modifiers.RegisterSpeed(victim, settings.slow_amount, settings.slow_duration, "butcher_melee")
        
        // ---- DAÑO EN ÁREA: Golpes normales 1-3 (pequeño, 80u, 3 daño) ----
        // No aplicar en golpe 4 (combo tiene su propio AoE)
        local isComboHit = ("but_combo_count" in sc) && sc.but_combo_count >= 4
        if (!isComboHit)
        {
            local normal_aoe_radius = 80
            local victim_origin = victim.GetOrigin()
            for (local surv; surv = Entities.FindByClassnameWithin(surv, "player", victim_origin, normal_aoe_radius); )
            {
                if (surv.IsValid() && surv.IsSurvivor() && NetProps.GetPropInt(surv, "m_lifeState") == 0)
                {
                    if (surv != victim)
                    {
                        surv.TakeDamage(3, (1 << 2), attacker)
                    }
                }
            }
        }
        
        // Sonido impacto
        MaoLib_VFX.EmitSound(victim, sounds.melee_aoe, 0.8, RandomInt(90, 110))
    }
    
    // ============================================================
    // MECÁNICA 4: GRITO (Roar) — Reemplaza vómito
    // ============================================================
    
    function PerformRoar(but)
    {
        // CRITICAL: Verificar que sigue vivo
        if (!but || !but.IsValid() || NetProps.GetPropInt(but, "m_lifeState") != 0)
            return
        
        local origin = but.GetOrigin()
        local now = Time()
        local but_idx = but.GetEntityIndex()
        local sc = but.GetScriptScope()
        
        // Guardar entidades activas para cleanup en muerte
        if (!("active_roar_entities" in sc))
            sc.active_roar_entities <- []
        
        // Limpiar entidades de roars anteriores (evita leak si grita antes de 4s)
        foreach (ent in sc.active_roar_entities)
        {
            if (ent && ent.IsValid())
                ent.Kill()
        }
        sc.active_roar_entities = []
        
        // ---- TELEGRAFIADO: Anillo pulsante de advertencia ----
        // Anillo que se expande rápidamente durante la carga
        // NOTA: SpawnRing usa partículas pooled con auto-cleanup; NO añadir a active_roar_entities
        MaoLib_VFX.SpawnRing(
            origin + Vector(0, 0, 16),
            settings.roar_radius * 0.3,
            8,
            settings.roar_telegraph_particle,
            {
                expand = true,
                duration = settings.roar_telegraph + 0.5,
                priority = "gameplay"
            }
        )
        
        // Sonido de carga (pitch normal-grave, audible)
        PlaySoundWithPitch(but, sounds.roar, 0.6, RandomInt(70, 100))
        
        // RALENTIZAR drásticamente durante carga (Modifiers restaura automáticamente)
        MaoLib.Modifiers.RegisterSpeed(but, 0.15, settings.roar_telegraph, "butcher_roar_charge")
        
        // Delay para ejecutar el grito real — EntFire más robusto que DelayCall
        EntFire("worldspawn", "RunScriptCode",
            "::ButcherBerserker.PerformRoarActual(" + but_idx + ")",
            settings.roar_telegraph, null)
    }
    
    function PerformRoarActual(but_idx)
    {
        local but = EntIndexToHScript(but_idx)
        // Verificar que sigue vivo y sigue siendo Butcher
        if (!but || !but.IsValid() || NetProps.GetPropInt(but, "m_lifeState") != 0 || !IsButcher(but))
            return
        
        local origin = but.GetOrigin()
        local now = Time()
        local sc = but.GetScriptScope()
        
        // Velocidad restaurada automáticamente por Modifiers (expira timer butcher_roar_charge)
        
        // ---- SCREEN SHAKE ----
        local shake_name = "but_shake_" + but_idx + "_" + now
        local shake = SpawnEntityFromTable("env_shake", {
            targetname = shake_name,
            amplitude = 16,
            duration = settings.roar_stun_duration,
            frequency = 40,
            radius = settings.roar_radius,
            origin = origin
        })
        if (shake && shake.IsValid())
        {
            sc.active_roar_entities.append(shake)
            EntFire(shake_name, "StartShake", "", 0)
            EntFire(shake_name, "Kill", "", settings.roar_stun_duration + 0.5)
        }
        
        // ---- SONIDO con PITCH MODIFICADO ----
        local pitch = RandomInt(sounds.roar_pitch_min, sounds.roar_pitch_max)
        PlaySoundWithPitch(but, sounds.roar, 1.0, pitch)
        
        // ---- PARTÍCULA: Onda expansiva ----
        local wave_name = "but_wave_" + but_idx + "_" + now
        local wave = SpawnEntityFromTable("info_particle_system", {
            targetname = wave_name,
            effect_name = settings.roar_wave_particle,
            origin = origin + Vector(0, 0, 32),
            start_active = 1
        })
        if (wave && wave.IsValid())
        {
            sc.active_roar_entities.append(wave)
            EntFire(wave_name, "Kill", "", 2.0)
        }
        
        // ---- PARTÍCULA: Shockwave ----
        local shock_name = "but_shock_" + but_idx + "_" + now
        local shock = SpawnEntityFromTable("info_particle_system", {
            targetname = shock_name,
            effect_name = settings.roar_shockwave_particle,
            origin = origin + Vector(0, 0, 16),
            start_active = 1
        })
        if (shock && shock.IsValid())
        {
            sc.active_roar_entities.append(shock)
            EntFire(shock_name, "Kill", "", 1.5)
        }
        
        // ---- PARTÍCULAS: Anillo expansivo de gas (onda de choque) ----
        // Ring animado que crece desde el centro hasta el borde del radio de efecto
        // NOTA: SpawnRing usa partículas pooled con auto-cleanup; NO añadir a active_roar_entities
        local circle_radius = settings.roar_radius * 0.85
        MaoLib_VFX.SpawnRing(
            origin + Vector(0, 0, 8),
            circle_radius,
            10,  // 10 partículas (más denso que el telegraph)
            settings.roar_particle,
            {
                expand = true,
                duration = 2.5,
                priority = "gameplay"
            }
        )
        
        // ---- KNOCKBACK + SLOW + DAÑO + LIFESTEAL ----
        // ApplyAbsVelocityImpulse con delay incremental (evita race condition)
        // Basado en survivor_friendly_shove.nut — fuerza MUCHO menor que shove
        local affected_count = 0
        local stack = ("but_fury_stack" in sc) ? sc.but_fury_stack : 0
        local lifesteal_per_survivor = 15 + (stack * 10)  // Base 15 + 10 por stack de furia
        local knockback_delay = 0.0
        
        for (local surv; surv = Entities.FindByClassnameWithin(surv, "player", origin, settings.roar_radius); )
        {
            if (surv.IsValid() && surv.IsSurvivor() && NetProps.GetPropInt(surv, "m_lifeState") == 0)
            {
                local surv_idx = surv.GetEntityIndex()
                
                // 1. Knockback: empujar hacia afuera del butcher
                EntFire("worldspawn", "RunScriptCode",
                    "::ButcherBerserker.ApplyRoarKnockback(" + but_idx + "," + surv_idx + ")",
                    knockback_delay, null)
                
                // 2. Slow: ralentizar movimiento (aplicar justo después del knockback)
                EntFire("worldspawn", "RunScriptCode",
                    "::ButcherBerserker.ApplyRoarSlow(" + surv_idx + ")",
                    knockback_delay + 0.02, null)
                
                knockback_delay += 0.05
                
                // Daño leve
                surv.TakeDamage(settings.roar_damage, (1 << 1), but)
                
                affected_count++
            }
        }
        
        // Lifesteal: curarse por cada survivor afectado
        if (affected_count > 0)
        {
            local heal = affected_count * lifesteal_per_survivor
            local new_hp = but.GetHealth() + heal
            local max_hp = but.GetMaxHealth()
            if (new_hp > max_hp) new_hp = max_hp
            but.SetHealth(new_hp)
            
            printl("[BUT-ROAR] Lifesteal: " + affected_count + " survivors affected, healed " + heal + " HP (stack=" + stack + ")")
        }
        
        // Cleanup programado
        EntFire("worldspawn", "RunScriptCode",
            "::ButcherBerserker.CleanupRoarEntities(" + but_idx + ")",
            4.0, null)
    }
    
    // ============================================================
    // ROAR KNOCKBACK + SLOW (reemplaza Stagger — evita crash)
    // Basado en survivor_friendly_shove.nut — fuerza MUCHO menor
    // ============================================================
    
    ROAR_KNOCKBACK_FORCE = 180.0   // Shove usa 350 — roar es ~50%
    ROAR_UP_FORCE        = 70.0    // Shove usa 120 — roar es ~60%
    ROAR_SLOW_FACTOR     = 0.35    // Velocidad reducida a 35%
    ROAR_SLOW_DURATION   = 2.5     // Segundos de ralentización
    
    function ApplyRoarKnockback(butcher_idx, victim_idx)
    {
        local butcher = EntIndexToHScript(butcher_idx)
        local victim  = EntIndexToHScript(victim_idx)
        
        if (!butcher || !butcher.IsValid()) return
        if (!victim  || !victim.IsValid())  return
        if (!victim.IsSurvivor()) return
        if (NetProps.GetPropInt(victim, "m_lifeState") != 0) return
        
        // Dirección desde butcher hacia victim (empujar hacia AFUERA)
        local dir = victim.GetOrigin() - butcher.GetOrigin()
        dir.z = 0  // Solo horizontal para la base
        dir.Norm()
        
        // Impulso: hacia afuera + arriba
        local impulse = dir * ROAR_KNOCKBACK_FORCE + Vector(0, 0, ROAR_UP_FORCE)
        
        printl("[BUT-DEBUG] RoarKnockback: victim=" + victim.GetEntityIndex() 
            + " impulse=" + impulse)
        
        try {
            victim.ApplyAbsVelocityImpulse(impulse)
        } catch (e) {
            printl("[BUT-WARN] RoarKnockback failed: " + e)
        }
    }
    
    function ApplyRoarSlow(victim_idx)
    {
        local victim = EntIndexToHScript(victim_idx)
        if (!victim || !victim.IsValid()) return
        if (!victim.IsSurvivor()) return
        if (NetProps.GetPropInt(victim, "m_lifeState") != 0) return
        
        // Modifiers aplica + cleanup automático al expirar
        MaoLib.Modifiers.RegisterSpeed(victim, ROAR_SLOW_FACTOR, ROAR_SLOW_DURATION, "butcher_roar")
        
        printl("[BUT-DEBUG] RoarSlow: victim=" + victim.GetEntityIndex() 
            + " factor=" + ROAR_SLOW_FACTOR + " duration=" + ROAR_SLOW_DURATION)
    }
    
    function CleanupRoarEntities(but_idx)
    {
        local but = EntIndexToHScript(but_idx)
        if (!but || !but.IsValid()) return
        
        local sc = but.GetScriptScope()
        if (!("active_roar_entities" in sc)) return
        
        // Limpiar entidades que ya no son válidas
        local cleaned = []
        foreach (ent in sc.active_roar_entities)
        {
            if (ent && ent.IsValid())
                cleaned.append(ent)
        }
        sc.active_roar_entities = cleaned
    }
    
    // ============================================================
    // THINKER GLOBAL
    // ============================================================
    
    function GlobalThinker()
    {
        // CRITICAL DEBUG: Confirmar que GlobalThinker se ejecuta
        local think_start = Time()
        local now = think_start
        local butCount = 0
        
        try
        {
        // ---- Procesar cada Butcher ----
        for (local but; but = Entities.FindByClassname(but, "player"); )
        {
            if (!but.IsValid()) continue
            if (!IsButcher(but)) continue
            if (NetProps.GetPropInt(but, "m_lifeState") != 0) continue
            
            butCount++
            local sc = but.GetScriptScope()
            local but_idx = but.GetEntityIndex()
            
            // ---- Decay Furia (sistema de carga por daño — Opción B) ----
            if ("but_fury_charge" in sc && sc.but_fury_charge > 0)
            {
                DecayFuryCharge(but)
            }
            
            // ---- INMUNIDAD A EMPUJONES (Shove Immunity) ----
            // Setea m_staggerTimer[1] a -1.0 constantemente para prevenir stagger
            // Confirmado: este NetProp existe en L4D2 (usado por staggercancelfix.nut)
            try {
                NetProps.SetPropFloatArray(but, "m_staggerTimer", -1.0, 1)
            } catch (e) {}
            
            // ---- Chase AI con NavUtils (persecución al survivor más cercano) ----
            local nearest = null
            local nearestDist = 999999.0
            for (local s; s = Entities.FindByClassname(s, "player"); )
            {
                if (!s.IsValid() || !s.IsSurvivor()) continue
                if (NetProps.GetPropInt(s, "m_lifeState") != 0) continue
                local d = (but.GetOrigin() - s.GetOrigin()).LengthSqr()
                if (d < nearestDist)
                {
                    nearest = s
                    nearestDist = d
                }
            }
            
            if (nearest)
            {
                // Inicializar datos de path si no existen
                if (!("but_path" in sc))
                {
                    sc.but_path <- []
                    sc.but_path_idx <- 0
                    sc.but_path_rebuild_time <- 0
                }
                
                // Reconstruir path periódicamente (cada 2s)
                if (sc.but_path.len() == 0 || (now - sc.but_path_rebuild_time) > 2.0)
                {
                    if ("NavUtils" in ::MaoLib)
                    {
                        local startNav = ::MaoLib.NavUtils.GetNearestNavArea(but.GetOrigin(), 9999, false)
                        local endNav = ::MaoLib.NavUtils.GetNearestNavArea(nearest.GetOrigin(), 9999, false)
                        
                        if (startNav && endNav)
                        {
                            sc.but_path = ::MaoLib.NavUtils.BuildPath(startNav, endNav, 3)
                            sc.but_path_idx = 0
                            sc.but_path_rebuild_time = now
                        }
                    }
                }
                
                // Seguir waypoints del path
                local moved = false
                now = Time()  // Reasignar outer variable (no declarar nueva)
                
                // Cooldown de comando: no spamear CommandABot (causa "pasitos")
                if (!("but_cmd_cooldown" in sc))
                    sc.but_cmd_cooldown <- 0
                
                if (sc.but_path.len() > 0 && sc.but_path_idx < sc.but_path.len())
                {
                    local targetNav = sc.but_path[sc.but_path_idx]
                    local targetPos = targetNav.GetCenter()
                    local dist = (but.GetOrigin() - targetPos).Length()
                    
                    if (dist < 60)
                    {
                        // Llegó al waypoint, pasar al siguiente
                        sc.but_path_idx++
                    }
                    
                    if (sc.but_path_idx < sc.but_path.len())
                    {
                        targetNav = sc.but_path[sc.but_path_idx]
                        targetPos = targetNav.GetCenter()
                        
                        // Solo enviar comando si pasó el cooldown o cambió de waypoint
                        if (now >= sc.but_cmd_cooldown)
                        {
                            CommandABot({ bot = but, cmd = 1, pos = targetPos })
                            sc.but_cmd_cooldown = now + 0.5
                            moved = true
                        }
                    }
                }
                
                // Fallback: mover directamente al survivor si no hay path disponible
                if (!moved && now >= sc.but_cmd_cooldown)
                {
                    CommandABot({ bot = but, cmd = 1, pos = nearest.GetOrigin() })
                    sc.but_cmd_cooldown = now + 0.5
                }
                
                sc.but_last_move_target <- nearest.GetOrigin()
                sc.but_last_move_time <- now
            }
            else
            {
                // FALLBACK: No hay survivors visibles — patrullar o desatascar
                
                // Anti-stuck: Verificar si se ha movido recientemente
                if (!("but_last_pos" in sc))
                {
                    sc.but_last_pos <- but.GetOrigin()
                    sc.but_last_pos_time <- now
                }
                
                local pos = but.GetOrigin()
                local dist_moved = (pos - sc.but_last_pos).Length()
                
                // Si no se ha movido en 2 segundos, forzar movimiento (con cooldown)
                if (dist_moved < 50 && (now - sc.but_last_pos_time) > 2.0 && now >= sc.but_cmd_cooldown)
                {
                    // Intentar mover hacia último objetivo conocido
                    if ("but_last_move_target" in sc)
                    {
                        CommandABot({ bot = but, cmd = 1, pos = sc.but_last_move_target })
                    }
                    else
                    {
                        // No hay objetivo conocido — mover en dirección aleatoria
                        local angles = but.EyeAngles()
                        local yaw = angles.y + RandomInt(-45, 45)
                        local rad = yaw * 0.0174533  // PI/180
                        local nudge = Vector(cos(rad) * 200, sin(rad) * 200, 0)
                        CommandABot({ bot = but, cmd = 1, pos = pos + nudge })
                    }
                    
                    sc.but_cmd_cooldown = now + 0.5
                    // Reset timer
                    sc.but_last_pos = pos
                    sc.but_last_pos_time = now
                }
                else if (dist_moved >= 50)
                {
                    // Se movió suficiente, actualizar tracking
                    sc.but_last_pos = pos
                    sc.but_last_pos_time = now
                }
            }
            
            // ---- GOLPE DIRECTO (Forzar melee) ----
            // ELIMINADO: el boomer ya tiene garras hardcodeadas (boomer_claw)
            // que rasguñan naturalmente. HandlePlayerHurt detecta boomer_claw
            // via player_hurt y aplica slow + AoE. Forzar melee aquí causaba
            // redundancia y posible doble daño.
            
            // ---- CAÍDA DE ALTURA → Ataque en área ----
            if (!("but_last_z" in sc))
            {
                sc.but_last_z <- but.GetOrigin().z
                sc.but_falling <- false
                sc.but_fall_start_z <- 0
            }
            
            local current_z = but.GetOrigin().z
            local z_diff = sc.but_last_z - current_z
            
            // Detectar caída rápida (más de 50 unidades por think = ~150-200 u/s)
            if (z_diff > 50 && !sc.but_falling)
            {
                sc.but_falling = true
                sc.but_fall_start_z = sc.but_last_z
            }
            
            // Aterrizaje: estaba cayendo y ahora la diferencia es pequeña o subió
            if (sc.but_falling && z_diff < 10)
            {
                local fall_height = sc.but_fall_start_z - current_z
                
                // Solo si cayó más de 100 unidades (~3 metros)
                if (fall_height > 100)
                {
                    local origin = but.GetOrigin()
                    local damage = (fall_height * 0.3).tointeger()  // 30% de la altura como daño
                    if (damage > 50) damage = 50  // Cap máximo
                    
                    // Partícula: onda expansiva
                    local fall_wave_name = "but_fallw_" + but_idx + "_" + now
                    local wave = SpawnEntityFromTable("info_particle_system", {
                        targetname = fall_wave_name,
                        origin = origin + Vector(0, 0, 8),
                        effect_name = settings.fall_shockwave,
                        start_active = 1
                    })
                    if (wave && wave.IsValid()) EntFire(fall_wave_name, "Kill", "", 1.5)
                    
                    // Partícula: escombros
                    local fall_deb_name = "but_falld_" + but_idx + "_" + now
                    local debris = SpawnEntityFromTable("info_particle_system", {
                        targetname = fall_deb_name,
                        origin = origin + Vector(0, 0, 16),
                        effect_name = settings.fall_debris,
                        start_active = 1
                    })
                    if (debris && debris.IsValid()) EntFire(fall_deb_name, "Kill", "", 2.0)
                    
                    // Screen shake
                    local shake_name = "but_fall_" + but_idx + "_" + now
                    local shake = SpawnEntityFromTable("env_shake", {
                        targetname = shake_name,
                        amplitude = 8,
                        duration = 0.5,
                        frequency = 30,
                        radius = 400,
                        origin = origin
                    })
                    if (shake && shake.IsValid())
                    {
                        EntFire(shake_name, "StartShake", "", 0)
                        EntFire(shake_name, "Kill", "", 1.0)
                    }
                    
                    // Daño en área a survivors
                    for (local surv; surv = Entities.FindByClassnameWithin(surv, "player", origin, 250); )
                    {
                        if (surv.IsValid() && surv.IsSurvivor() && NetProps.GetPropInt(surv, "m_lifeState") == 0)
                        {
                            surv.Stagger(origin)
                            surv.TakeDamage(damage, (1 << 2), but)
                        }
                    }
                    
                    printl("[BUT-FALL] Ground slam! Height=" + fall_height + " Damage=" + damage)
                }
                
                sc.but_falling = false
                sc.but_fall_start_z = 0
            }
            
            sc.but_last_z = current_z
            
            // ---- GRITO (Roar) ----
            if (!("but_roar_ready" in sc))
                sc.but_roar_ready <- now + 3.0
            
            if (sc.but_roar_ready > now) continue
            
            local should_roar = false
            
            // HUMANOS: detectar botón de habilidad (IN_ATTACK2 = 2048)
            if (!IsPlayerABot(but))
            {
                local pressed = NetProps.GetPropInt(but, "m_afButtonPressed")
                if (pressed & 2048)
                    should_roar = true
            }
            // BOTS: auto-cast cuando survivor cercano
            else
            {
                for (local s; s = Entities.FindByClassnameWithin(s, "player", but.GetOrigin(), settings.roar_bot_range); )
                {
                    if (s.IsValid() && s.IsSurvivor() && NetProps.GetPropInt(s, "m_lifeState") == 0)
                    {
                        should_roar = true
                        break
                    }
                }
            }
            
            if (should_roar)
            {
                printl("[BUT-DEBUG] ROAR triggered at " + now + " for but " + but_idx)
                PerformRoar(but)
                sc.but_roar_ready = now + settings.roar_cooldown
            }
        }
        
        // Debug: Solo reportar si cambió el conteo
        if (butCount != ("but_last_report" in this ? this.but_last_report : -1))
        {
            this.but_last_report <- butCount
            printl("[BUT-DEBUG] Active Butchers: " + butCount)
        }
        }
        catch (e)
        {
            printl("[BUT-ERROR] GlobalThinker CRASH: " + e + " (runtime=" + (Time() - think_start) + "s)")
        }
    }
    
    // ============================================================
    // DEBUG SPAWN
    // Uso: script ::ButcherBerserker.DebugSpawn()
    // Convierte un boomer bot existente en Butcher, o prepara el próximo spawn
    // ============================================================
    
    function DebugSpawn()
    {
        printl("[BUT-DEBUG] === DEBUG SPAWN ===")
        
        // Buscar boomer bot existente y convertirlo
        for (local p; p = Entities.FindByClassname(p, "player"); )
        {
            if (!p.IsValid() || !IsPlayerABot(p)) continue
            if (p.GetZombieType() != 2) continue
            
            local idx = p.GetEntityIndex()
            if (idx > 0 && idx < 65536)
            {
                printl("[BUT-DEBUG] DebugSpawn: Converting boomer " + idx)
                EntFire("worldspawn", "RunScriptCode",
                    "::ButcherBerserker.DelayedConvert(" + idx + ")",
                    convertDelay, null)
                return "[BUT] Spawning Butcher on boomer " + idx
            }
        }
        
        // No hay boomer vivo, armar flag para el próximo spawn
        this.debug_force_next <- true
        this.debug_force_timeout <- Time() + 30.0
        printl("[BUT-DEBUG] DebugSpawn armed: next boomer bot spawn will convert")
        printl("[BUT-DEBUG] Tip: Use 'z_spawn boomer' (requires sv_cheats) or wait for natural spawn")
        return "[BUT] Armed. Next boomer bot will be a Butcher"
    }
    
    // ============================================================
    // HELPERS
    // ============================================================
    
    function IsButcher(player)
    {
        if (!player || !player.IsValid()) return false
        try { player.ValidateScriptScope() } catch (e) {}
        return ("IsButcher" in player.GetScriptScope())
    }
    
    // Emitir sonido con pitch custom usando nativo EmitAmbientSoundOn
    // ambient_generic NO soporta sound scripts con PlaySound; EmitAmbientSoundOn sí
    function PlaySoundWithPitch(entity, sound, volume, pitch)
    {
        if (!entity || !entity.IsValid()) return
        if (!sound || sound == "") return
        
        local dummy = SpawnEntityFromTable("info_target", {
            origin = entity.GetOrigin(),
            targetname = "but_snd_" + UniqueString()
        })
        if (dummy && dummy.IsValid())
        {
            EmitAmbientSoundOn(sound, volume, 0, pitch, dummy)
            EntFire(dummy.GetName(), "Kill", "", 3.0)
        }
    }
    
    // ============================================================
    // SETTINGS SYSTEM
    // ============================================================
    
    function SaveSettings()
    {
        local path = "butcher/settings.cfg"
        local data = "{\n"
        foreach (k, v in settings)
        {
            local val_str
            if (typeof(v) == "array")
            {
                val_str = "["
                for (local i = 0; i < v.len(); i++)
                {
                    val_str += v[i].tostring()
                    if (i < v.len() - 1) val_str += ", "
                }
                val_str += "]"
            }
            else if (typeof(v) == "string")
                val_str = "\"" + v + "\""
            else
                val_str = v.tostring()
            
            data += "\t" + k + " = " + val_str + "\n"
        }
        data += "}"
        StringToFile(path, data)
    }
    
    function LoadSettings()
    {
        local path = "butcher/settings.cfg"
        local content = FileToString(path)
        
        if (!content)
        {
            SaveSettings()
            return
        }
        
        try
        {
            local t = compilestring("return " + content)()
            foreach (k, v in t)
                if (k in settings) settings[k] = v
        }
        catch (e)
        {
            printl("[BUT-BERSERKER] LoadSettings error: " + e)
            SaveSettings()
        }
    }

    function OnGameEvent_player_hurt(params) { HandlePlayerHurt(params); }
    function OnGameEvent_player_death(params) { HandlePlayerDeath(params); }
}

// Registro directo con __CollectGameEventCallbacks
::ButcherBerserker.LoadSettings()

printl("[BUT-DEBUG] About to register callbacks...")
__CollectGameEventCallbacks(::ButcherBerserker)
printl("[BUT-DEBUG] Callbacks registered successfully")

printl("[BUT-BERSERKER] El Desgarrador cargado — Lost 4 Creed")
printl("[BUT-DEBUG] Script loaded. Settings: health=" + ::ButcherBerserker.settings.health + " spawn_chance=" + ::ButcherBerserker.settings.spawn_chance)
