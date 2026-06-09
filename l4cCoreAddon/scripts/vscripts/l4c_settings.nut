// ============================================================================
// l4c_settings.nut — Core Settings Module
// ============================================================================
// Fusiona: global_convars, item_density, melee_range, viewroll, l4c_entity_cleanup
// Tabla: ::L4C_Settings
// ============================================================================

::L4C_Settings <- {
    Debug = 1

    function Dbg(msg) {
        if (Debug) printl("[L4C_Settings][DEBUG] " + msg)
    }

    function DbgWarn(msg) {
        printl("[L4C_Settings][WARN] " + msg)
    }

    // ========================================================================
    // CONVARS
    // ========================================================================

    function ApplyConvars()
    {
        Dbg("ENTER ApplyConvars")

        // --- Shotgun & Physics ---
        Convars.SetValue("z_shotgun_bonus_damage_multiplier", 1)
        Convars.SetValue("sv_airaccelerate", 250)
        Convars.SetValue("z_gun_physics_force", "550")
        Convars.SetValue("survivor_push", "1")

        // --- Mouse / Pure ---
        Convars.SetValue("m_mousethread_sleep", 0)
        Convars.SetValue("sv_consistency", 0)
        Convars.SetValue("sv_pure_kick_clients", 0)

        // --- Fire / Inferno ---
        Convars.SetValue("inferno_damage", 200)
        Convars.SetValue("inferno_max_flames", 90)
        Convars.SetValue("inferno_max_range", 150)
        Convars.SetValue("inferno_child_spawn_max_depth", 6)
        Convars.SetValue("inferno_scorch_decals", 1)

        // --- Survivor Burn Factors ---
        Convars.SetValue("survivor_burn_factor_easy", 0.03)
        Convars.SetValue("survivor_burn_factor_normal", 0.07)
        Convars.SetValue("survivor_burn_factor_hard", 0.09)
        Convars.SetValue("survivor_burn_factor_expert", 0.12)

        // --- Vomitjar ---
        Convars.SetValue("vomitjar_duration_infected_bot", 20)
        Convars.SetValue("vomitjar_duration_infected_pz", 20)
        Convars.SetValue("vomitjar_duration_survivor", 20)
        Convars.SetValue("vomitjar_radius", 100)
        Convars.SetValue("vomitjar_radius_survivors", 50)

        // --- SI Claw Accuracy ---
        Convars.SetValue("z_claw_hit_yaw_min", "-8")
        Convars.SetValue("z_claw_hit_pitch_max", "8")

        // --- Survivor Stats ---
        Convars.SetValue("survivor_incapacitated_accuracy_penalty", "0.10")
        Convars.SetValue("survivor_incap_health", "200")
        Convars.SetValue("survivor_incap_decay_rate", "12")
        Convars.SetValue("survivor_speed", "185")
        Convars.SetValue("survivor_damage_speed_factor", "0.8")
        Convars.SetValue("survivor_sprint_multiplier", "1.35")
        Convars.SetValue("survivor_limp_health", "35")
        Convars.SetValue("survivor_limp_walk_speed", "30")
        Convars.SetValue("survivor_speed_boost_factor", "1.25")
        Convars.SetValue("survivor_revive_duration", "3.0")

        // --- Friendly Fire ---
        Convars.SetValue("survivor_friendly_fire_factor_easy", "0.1")
        Convars.SetValue("survivor_friendly_fire_factor_normal", "0.15")
        Convars.SetValue("survivor_friendly_fire_factor_hard", "0.2")
        Convars.SetValue("survivor_friendly_fire_factor_expert", "0.25")

        // --- Minigun / Mounted Gun ---
        Convars.SetValue("z_minigun_overheat_time", 999999)
        Convars.SetValue("z_minigun_cooldown_time", 0.1)
        Convars.SetValue("z_minigun_rate_of_fire", 50)
        Convars.SetValue("z_minigun_spin_up_speed", 10)
        Convars.SetValue("z_minigun_atomize", 1)
        Convars.SetValue("z_minigun_spread", 5)
        Convars.SetValue("mounted_gun_overheat_time", 999999)
        Convars.SetValue("mounted_gun_overheat_penalty_time", 0.1)
        Convars.SetValue("mounted_gun_cooldown_time", 0.1)
        Convars.SetValue("mounted_gun_rate_of_fire", 6)

        // --- Infected Scale ---
        Convars.SetValue("sv_infected_scale_max", "1.15")
        Convars.SetValue("sv_infected_scale_min", "0.95")

        // --- Defib / Medkit ---
        Convars.SetValue("defibrillator_use_duration", 3)
        Convars.SetValue("defibrillator_return_to_life_time", 2)
        Convars.SetValue("z_survivor_respawn_health", 75)
        Convars.SetValue("first_aid_kit_use_duration", 2.5)

        // --- Melee Range ---
        Convars.SetValue("melee_range", 95)

        // --- View Roll ---
        Convars.SetValue("sv_rollangle", "1.90")

        Dbg("EXIT ApplyConvars")
    }

    function ApplyItemDensity()
    {
        Dbg("ENTER ApplyItemDensity")

        Convars.SetValue("director_adrenaline_density", "2")
        Convars.SetValue("director_ammo_density", "1")
        Convars.SetValue("director_defibrillator_density", "1")
        Convars.SetValue("director_gas_can_density", "4")
        Convars.SetValue("director_melee_weapon_density", "2")
        Convars.SetValue("director_molotov_density", "2")
        Convars.SetValue("director_oxygen_tank_density", "9")
        Convars.SetValue("director_pain_pill_density", "2")
        Convars.SetValue("director_pipe_bomb_density", "2")
        Convars.SetValue("director_propane_tank_density", "7")
        Convars.SetValue("director_super_weapon_density", "1")
        Convars.SetValue("director_upgradepack_density", "3")
        Convars.SetValue("director_vomitjar_density", "3")
        Convars.SetValue("director_item_cluster_range", "200")
        Convars.SetValue("director_weapon_cluster_range", "200")
        Convars.SetValue("director_finale_item_cluster_count", "7")

        Dbg("EXIT ApplyItemDensity")
    }

    // ========================================================================
    // ENTITY CLEANUP
    // ========================================================================

    KNOWN_PREFIXES = ["mgbe_", "particle_", "pushThinker", "l4c_"]

    CLEANUP_CLASSES = [
        "info_target",
        "logic_timer",
        "light_dynamic",
        "env_projectedtexture",
        "info_particle_system",
        "ambient_generic"
    ]

    function DoCleanup()
    {
        Dbg("ENTER DoCleanup")
        local cleaned = 0

        foreach (classname in CLEANUP_CLASSES)
        {
            local ent = null
            while (ent = Entities.FindByClassname(ent, classname))
            {
                if (!ent || !ent.IsValid()) continue

                local name = ent.GetName()
                local shouldKill = false

                if (name && name.len() > 0)
                {
                    foreach (prefix in KNOWN_PREFIXES)
                    {
                        if (name.find(prefix) == 0)
                        {
                            shouldKill = true
                            break
                        }
                    }
                }

                if (classname == "info_particle_system" && (!name || name.len() == 0))
                    shouldKill = false

                if (classname == "light_dynamic" && (!name || name.len() == 0))
                    shouldKill = false

                if (shouldKill)
                {
                    Dbg("  Killing " + classname + " : " + name)
                    ent.Kill()
                    cleaned++
                }
            }
        }

        Dbg("EXIT DoCleanup — cleaned " + cleaned + " entities")
    }

    // ========================================================================
    // EVENT HANDLERS
    // ========================================================================

    function OnGameEvent_round_start_post_nav(params)
    {
        Dbg("ENTER OnGameEvent_round_start_post_nav")
        ApplyConvars()
        ApplyItemDensity()
        Dbg("EXIT OnGameEvent_round_start_post_nav")
    }

    function OnGameEvent_round_end(params)
    {
        Dbg("ENTER OnGameEvent_round_end")
        DoCleanup()
        Dbg("EXIT OnGameEvent_round_end")
    }

    function OnGameEvent_mission_lost(params)
    {
        Dbg("ENTER OnGameEvent_mission_lost")
        DoCleanup()
        Dbg("EXIT OnGameEvent_mission_lost")
    }

    // mission_restarted event does NOT exist in L4D2. Cleanup handled by mission_lost.
}

__CollectGameEventCallbacks(::L4C_Settings)

printl("[L4C_Settings] Module loaded — convars, item density, melee range, viewroll, entity cleanup")
