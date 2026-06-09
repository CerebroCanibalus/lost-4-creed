if ( "__vslu_init_scmp_hooks" in getroottable())
    ::__vslu_init_scmp_hooks();

Msg("Lost 4 Creed Director Main ENABLED\n");
Msg("Lost 4 Creed Director Main ENABLED\n");
Msg("Lost 4 Creed Director Main ENABLED\n");

// Load MaoLib core (auto-loads submodules: timers_cleanup, vfx)
IncludeScript("maolib", getroottable());
IncludeScript("maolib_input", getroottable());
IncludeScript("maolib_state", getroottable());
IncludeScript("maolib_cooldowns", getroottable());
IncludeScript("maolib_hud", getroottable());
IncludeScript("maolib_modifiers", getroottable());
IncludeScript("maolib_aoe", getroottable());
IncludeScript("maolib_status", getroottable());
// maolib_status_hooks.nut — REMOVIDO (Fase 2 simplificación StatusEffects)
// Los hooks automáticos de daño han sido eliminados. Cada perk maneja sus propios eventos
// usando MaoLib.StatusEffects como registry de stacking rules.
IncludeScript("maolib_mapper", getroottable());

//Gamemode Changes

if(Director.GetGameMode() == "coop")
{
	IncludeScript("custom_glow_coop", getroottable());
	Convars.SetValue("survivor_allow_crawling", 1)
	Convars.SetValue("survivor_crawl_speed", 70)
	Convars.SetValue("survivor_max_incapacitated_count", "1");
	// sv_pure_kick_clients → l4c_settings.nut
	Convars.SetValue("director_threat_radius", "1000" );
	Convars.SetValue("director_threat_min_separation", "3250" );
	Convars.SetValue("z_hunter_limit", "1" );
	// z_spitter_limit → infected_balance.nut
	Convars.SetValue( "z_jockey_limit", "1" );
	Convars.SetValue( "z_boomer_limit", "1" );
	Convars.SetValue( "z_smoker_limit", "1" );
	Convars.SetValue( "z_charger_limit", "1" );
	Convars.SetValue( "z_friendly_fire_forgiveness", "1" );
	Convars.SetValue( "z_mob_min_notify_count", "30" );
	Convars.SetValue( "sv_disable_glow_survivors", "0" );
	Convars.SetValue( "sv_disable_glow_faritems", "0" );
	Convars.SetValue( "sv_rescue_disabled", "0" );
	Convars.SetValue( "z_throttle_hit_interval_easy", "0");
	Convars.SetValue( "z_throttle_hit_interval_normal", "0");
	Convars.SetValue( "z_throttle_hit_interval_hard", "0");
	Convars.SetValue( "z_throttle_hit_interval_expert", "0");
	Convars.SetValue( "director_convert_pills", "0");
	// survivor_damage_speed_factor → l4c_settings.nut
	Convars.SetValue( "z_max_stagger_duration", "7.5" );
	Convars.SetValue( "z_crouch_speed", "180" );
	Convars.SetValue( "SpecialRespawnInterval", "30" );
	DirectorOptions.MaxSpecials <- 7  // 6 SI types + 1 flex slot (was 5, prevented butcher/hellhound spawns)
	DirectorOptions.SpitterLimit <- 1
	DirectorOptions.SmokerLimit <- 1
	DirectorOptions.JockeyLimit <- 1
	DirectorOptions.HunterLimit <- 1
	DirectorOptions.ChargerLimit <- 1
	DirectorOptions.BoomerLimit <- 1
}

if(Director.GetGameMode() == "versus")
{
	IncludeScript("custom_glow_versus", getroottable());
	Convars.SetValue("survivor_allow_crawling", 1)
	Convars.SetValue("survivor_crawl_speed", 40)
	Convars.SetValue("survivor_max_incapacitated_count", "1");
	// sv_pure_kick_clients → l4c_settings.nut
	Convars.SetValue("director_threat_radius", "500" );
	Convars.SetValue("director_threat_min_separation", "1250" );
	Convars.SetValue("z_spawn_mobs_behind_chance", "25" );
	Convars.SetValue("z_hunter_limit", "1" );
	Convars.SetValue("z_spitter_limit", "2" );
	Convars.SetValue("z_jockey_limit", "1" );
	Convars.SetValue("z_boomer_limit", "1" );
	Convars.SetValue("z_smoker_limit", "1" );
	Convars.SetValue("z_charger_limit", "1" );
	Convars.SetValue("z_friendly_fire_forgiveness", "1" );
	Convars.SetValue("z_mob_min_notify_count", "30" );
	Convars.SetValue("sv_rescue_disabled", "0" );
	Convars.SetValue("z_throttle_hit_interval_easy", "0.4");
	Convars.SetValue("z_throttle_hit_interval_normal", "0.25");
	Convars.SetValue("z_throttle_hit_interval_hard", "0.4");
	Convars.SetValue("z_throttle_hit_interval_expert", "1");
	Convars.SetValue("director_convert_pills", "0");
	Convars.SetValue("z_max_stagger_duration", "2.5" );
	Convars.SetValue("z_crouch_speed", "180" );
	Convars.SetValue("vs_tank_damage", "35" );
	Convars.SetValue("vs_tiebreak_bonus", "100" );
	Convars.SetValue("vs_max_team_switches", "10" );
	Convars.SetValue("vs_defib_penalty", "150" );
	Convars.SetValue("vs_survivor_damage_reduction", "0.75" );
	Convars.SetValue( "SpecialRespawnInterval", "25" );
	
}

if(Director.GetGameMode() == "survival")
{
	IncludeScript("custom_glow_versus", getroottable());
	// sv_pure_kick_clients → l4c_settings.nut
	Convars.SetValue("survivor_allow_crawling", 1)
	Convars.SetValue("survivor_crawl_speed", 50)
	Convars.SetValue("survivor_max_incapacitated_count", "1");
	Convars.SetValue("director_threat_radius", "500" );
	Convars.SetValue("director_threat_min_separation", "1250" );
	Convars.SetValue("z_friendly_fire_forgiveness", "1" );
	Convars.SetValue("z_mob_min_notify_count", "30" );
	Convars.SetValue("sv_disable_glow_survivors", "0" );
	Convars.SetValue("sv_disable_glow_faritems", "0" );
	Convars.SetValue("sv_rescue_disabled", "1" );
	Convars.SetValue("z_boomer_limit", "2" );
	Convars.SetValue("z_throttle_hit_interval_easy", "0");
	Convars.SetValue("z_throttle_hit_interval_normal", "0");
	Convars.SetValue("z_throttle_hit_interval_hard", "0");
	Convars.SetValue("z_throttle_hit_interval_expert", "0");
	Convars.SetValue("survivor_max_incapacitated_count", "0");
	Convars.SetValue("director_convert_pills", "0");
	// survivor_damage_speed_factor → l4c_settings.nut
	Convars.SetValue("survival_max_specials", "5");
	Convars.SetValue( "z_max_stagger_duration", "6" );
}

// ========================================================================
// CORE MODULES (MaoLib + Settings + Director + World)
// ========================================================================

// Settings: convars, item density, melee range, viewroll, entity cleanup
IncludeScript("l4c_settings", getroottable());

// Bleeding: infected blood effects
// DESACTIVADO 4 Jun 2026 — ZPoison legacy: API obsoleta (__CollectEventCallbacks),
// AddThinkToEnt (entity leak), redundante con DoT Subsystem de MaoLib.
// IncludeScript("bleeding", getroottable());

Msg("Base Module Active\n");

// ========================================================================
// RAGDOLLS + FX
// ========================================================================

IncludeScript("vscript_defib_ragdoll", getroottable());
IncludeScript("ragdoll_magnitude", getroottable());
Msg("Ragdoll Module Active\n");

// ========================================================================
// DIRECTOR + WORLD
// ========================================================================

// Acoustic Terror: ruido atrae hordas (reemplaza gunshots_horde)
IncludeScript("l4c_acoustic_terror", getroottable());
IncludeScript("sound_proxy_window", getroottable());
IncludeScript("sound_proxy_prop", getroottable());
Msg("Director Module Active\n");

// ========================================================================
// MAP SYSTEMS (will migrate to l4cMapRefresh in future)
// ========================================================================

// IncludeScript("itemfinales", getroottable()); // Desactivado - pendiente migración a l4cMapRefresh
IncludeScript("item_crates", getroottable());
IncludeScript("chch_crowpiles", getroottable());
Msg("Map Module Active\n");

// ========================================================================
// INFECTED RULES
// ========================================================================

// IncludeScript("fallenspawn", getroottable()); // eliminado — se migrará a sistema más grande
Msg("Infected Module Active\n");

// ========================================================================
// FUN / MISC
// ========================================================================

IncludeScript("eatpeople", getroottable());
IncludeScript("poltergeists", getroottable());
IncludeScript("l4c_easter_eggs", getroottable());
printl("[CoreAddon] Easter Eggs system loaded");
IncludeScript("specialdoors", getroottable());
Msg("Fun Module Active\n");

Msg("No more VSLib, fuck VSLIB, I'm sorry!\n");

// ========================================================================
// NOTE: Survivor gameplay scripts moved to l4cCoreSurvivorGameplay
// (anti-bunnyhop removed — bunnyhop is fun!)
// ========================================================================

