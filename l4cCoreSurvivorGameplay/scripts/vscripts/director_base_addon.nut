// MaoLib cargado exclusivamente por l4cCoreAddon
// Survivor gameplay modules — loaded AFTER CoreAddon

// ========================================================================
// CHARACTER FRAMEWORK (Unified)
// ========================================================================
// system_perks_simple.nut — 8 passive perks, 0 active abilities
// system_attributes.nut — speed/weight/friction engine
// system_dash.nut — dash + input handling
// IncludeScript("system_perks_simple", getroottable());
IncludeScript("system_attributes", getroottable());
IncludeScript("system_dash", getroottable());
printl("[SurvivorGameplay] Character framework loaded (unified)");

// ========================================================================
// COMBAT
// ========================================================================
IncludeScript("system_combat", getroottable());
printl("[SurvivorGameplay] Combat system loaded");

// ========================================================================
// AI OVERHAUL (MIA)
// ========================================================================
IncludeScript("survivor_ai_overhaul", getroottable());
printl("[SurvivorGameplay] Survivor AI Overhaul (MIA) loaded");

// ========================================================================
// PERKS (8 personajes + equipment) — system_perks_unified.nut
// ========================================================================
printl("[SurvivorGameplay] Perks loaded (unified)");

// ========================================================================
// EVENTS + MISC
// ========================================================================
IncludeScript("system_events_misc", getroottable());
IncludeScript("weird_ai", getroottable());
printl("[SurvivorGameplay] Events + Misc loaded");

// ========================================================================
// NOTAS / SCRIPTS BORRADOS (consolidados en unified)
// ========================================================================
// BORRADOS (reemplazados por system_perks_unified.nut):
//   sp_brock.nut, sp_jaime.nut, sp_jason.nut, sp_sean.nut,
//   sp_jerry.nut, sp_brenda.nut, sp_chris.nut, sp_phil.nut,
//   system_character.nut, system_perks.nut, sp_config.nut,
//   system_movement.nut, system_movement.nut.backup
//
// Scripts migrados a sistemas consolidados:
// - dashing.nut               → system_dash.nut
// - tacticalmovement.nut      → system_attributes.nut
// - item_buffs.nut            → system_perks_unified.nut (SECTION 4.5 Equipment Effects)
// - l4c_combat_fx.nut         → system_combat.nut
// - l4c_combat_util.nut       → system_combat.nut
// - survivor_friendly_shove   → system_combat.nut
// - jumpscare.nut             → system_events_misc.nut
// - eventsnd.nut              → system_events_misc.nut
// - l4c_easter_eggs.nut       → MOVED to l4cCoreAddon (ACTIVE)
//
// Additional survivor scripts still in CoreAddon (pending migration):
// - water_slowdown_reduction.nut
// - immersive_fall_dmg.nut
// - grief.nut (Second Chance system)
// - tank_heal.nut
// - incap_warning.nut
// - restore_crawlanim.nut
// - incap_pills.nut
// - incap_adrenaline.nut
// - shoescuff.nut / ctsh.nut / ladder_sounds.nut
// - simple_first_person_timed_button.nut
// ========================================================================
