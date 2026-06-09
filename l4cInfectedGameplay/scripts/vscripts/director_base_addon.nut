Msg("Lost 4 Creed Infected ENABLED\n");
Msg("Lost 4 Creed Infected ENABLED\n");
Msg("Lost 4 Creed Infected ENABLED\n");

// MaoLib + submodulos cargados exclusivamente por l4cCoreAddon

// ================================================================
// INFECTED BALANCE & CONFIGURATION
// ================================================================
IncludeScript("infected_balance", getroottable());  // Consolidated: convars + difficulty scaling + nocrowning + boss warnings

// ================================================================
// COMMON INFECTED SYSTEM
// ================================================================
IncludeScript("common_system", getroottable());     // Consolidated: regen + fire_spreads + rush_incap + wounds + death_fix

// ================================================================
// SPECIAL INFECTED SYSTEMS (Consolidated)
// ================================================================

// Smoker (momentum_tongue + fly_bomb + poison, removed: last_breath)
IncludeScript("smoker_system", getroottable());

// Hunter (lead + jump + pounce, with charged jump mechanic)
IncludeScript("hunter_system", getroottable());

// Boomer (mechanics + vomit_chain + damage, removed: fall)
IncludeScript("boomer_system", getroottable());

// Spitter (destroy + slow, fixed ScriptedMode)
IncludeScript("spitter_system", getroottable());

// Charger (standalone)
IncludeScript("charger_bounce", getroottable());

// ================================================================
// WITCH SYSTEM (consolidated)
// ================================================================
IncludeScript("witch_system", getroottable());      // Spawn, props, flashlight, horde
IncludeScript("witch_damage", getroottable());      // Damage scaling, size

// ================================================================
// TANK SYSTEM (consolidated: 8 scripts → 4 scripts)
// ================================================================
IncludeScript("tank_core", getroottable());         // Base config + Expert modifier + HP scaling (buffed) + Model + Melee alert
IncludeScript("tank_combat", getroottable());       // Fire rework + Berserker states + Crowd control
IncludeScript("tank_death", getroottable());        // Epic death sequence (gibs, particles, shockwave)
IncludeScript("tank_ai", getroottable());           // Aggressive AI state machine
IncludeScript("tankaim", getroottable());           // Rock aimbot for bots
IncludeScript("rotpi", getroottable());             // Tank punch knockback fix

// ================================================================
// UNCOMMON INFECTED (migrado a l4cCoreAddon)
// ================================================================

// ================================================================
// VISUAL & AUDIO EFFECTS
// ================================================================
IncludeScript("infected_music", getroottable());

printl("========================================");
printl("Lost 4 Creed Infected Addon FULLY LOADED");
printl("Consolidated: Witch(7→2), Smoker(4→1), Hunter(3→1), Boomer(3→1)");
printl("Consolidated: Spitter(2→1), Common(5→1), Balance(4→1), Tank(8→4)");
printl("Tank HP Buff: 9000 base / 15000 max / +30 HP/min");
printl("========================================");
