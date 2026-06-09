Msg("Lost 4 Creed Weapons ENABLED\n");
Msg("Lost 4 Creed Weapons ENABLED\n");
Msg("Lost 4 Creed Weapons ENABLED\n");

// ============================================================
// L4CWI SYSTEMS v1.2 — Core + 10 Modular Systems
// ============================================================

// Core framework (config parser, debug, registry)
IncludeScript("core_system", getroottable());

// Balance convars + pain pills + SMG headshot + turnrate/shove
IncludeScript("convars_system", getroottable());

// Firearms: M60 stagger, SG552 zoom damage
IncludeScript("firearms_system", getroottable());

// Special Firearms: AWP explosive, auto-fire, rip_and_tear, shotgungib
IncludeScript("special_firearms_system", getroottable());

// Explosives: Atomic pipe bomb, bile slow, GL screenshake, nescius pipe, GL convars, AoE incendiary
IncludeScript("explosives_system", getroottable());

// Feedback: Kill sound/effect, hitmarker, LASC, clip empty, wound feedback
IncludeScript("feedback_system", getroottable());

// Items: Auto upgrade, held cans, ammo limits, adrenaline reload, overdose, disarm
IncludeScript("items_system", getroottable());

// Item Buffs: Equipment passive effects (medkit AoE heal, gnome ammo/adrenaline, etc.)
IncludeScript("item_buffs", getroottable());

// Melee Base: Real reload, breakable melees
IncludeScript("melee_base_system", getroottable());

// Melee Special: Bleed melee
IncludeScript("melee_special_system", getroottable());

// Mounted: Turret explosions, minigun gib, minigun shake
IncludeScript("mounted_system", getroottable());

// Riot Shield: Damage reduction + blocking
IncludeScript("riotshield_system", getroottable());

// RRLogic System: Hunting Bloodletter + Desert Rampage (rrlogic compat)
IncludeScript("rrlogic_system", getroottable());

printl("[L4CWI] Core + 12 systems loaded successfully");

// ============================================================
// EXTERNAL SYSTEMS (not migrated — complex or separated by design)
// ============================================================

// Recoil (keep separate by design)
IncludeScript("rrlogic", getroottable());
printl("[L4CWI] Recoil (rrlogic) loaded");

// Electric Axe — MAINTAINS ORIGINAL FUNCTIONALITY, do not modify
IncludeScript("electric_axe", getroottable());
printl("[L4CWI] Electric Axe (original) loaded");

// Item spawn world script (external)
IncludeScript("sgw_main_script", getroottable());
printl("[L4CWI] Item spawn world script loaded");

Convars.SetValue("z_gun_kick", 0.78);
printl("[L4CWI] All modules initialized");
