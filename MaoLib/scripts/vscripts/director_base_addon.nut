// ============================================================================
// MaoLib — Standalone VScript Framework for L4D2
// Entry Point: director_base_addon.nut
// 
// Load this via addon VPK filesystem layering:
//   Place in: scripts/vscripts/director_base_addon.nut
//   L4D2 auto-executes it at map start.
//
// Or include from your own script:
//   IncludeScript("maolib", getroottable())
//
// ============================================================================
// WHAT YOU GET:
//
//   ::MaoLib                  - Core: timers, entity iterators, math, config parser
//   ::MaoLib.NavUtils          - Pathfinding: nav areas, LOS, high ground, chokes
//   ::MaoLib.PlayerState       - Per-player key-value state (auto-cleaned)
//   ::MaoLib.HUD               - Chat/center/hint/game_text messaging with throttle
//   ::MaoLib.Modifiers         - Speed/friction modifier stacking
//   ::MaoLib.AoE               - Area of Effect: selectors + applicators
//   ::MaoLib.StatusEffects     - DoT system + flat key-value registry
//   ::MaoLib.Mapper            - Prop spawning, director helpers, player utilities
//   ::MaoLib_VFX               - Particle system, explosions, impacts, screen FX
//   ::MaoLib_TimersCleanup     - Timer leak detection & console commands
// ============================================================================
// USAGE IN YOUR SCRIPTS:
//
//   1. Include MaoLib:
//      IncludeScript("maolib", getroottable())
//
//   2. Use namespaces:
//      MaoLib.AddTimer("my_timer", 1.0, function() { /* ... */ })
//      MaoLib.AoE.Select.Circle(origin, 500, { className = "infected" })
//      MaoLib.NavUtils.GetNearestNavArea(pos)
//      MaoLib.HUD.Notify(player, "Hello!", { mode = "chat" })
//      MaoLib.Modifiers.RegisterSpeed(player, 1.5, 5.0, "my_effect")
//      MaoLib.StatusEffects.ApplyDoT(victim, "bleed", 5.0, 3.0, attacker)
//      MaoLib_VFX.SpawnParticle(pos, "effect_name")
//
// ============================================================================

Msg("[MaoLib] Loading MaoLib Standalone Framework v2.2\n")

// ========================================================================
// CORE: maolib.nut (auto-loads submodules)
// ========================================================================
IncludeScript("maolib", getroottable())

// ========================================================================
// STATE: Per-player persistent state
// ========================================================================
IncludeScript("maolib_state", getroottable())

// ========================================================================
// HUD: Chat + game_text messaging system
// ========================================================================
IncludeScript("maolib_hud", getroottable())

// ========================================================================
// MODIFIERS: Speed/friction stacking
// ========================================================================
IncludeScript("maolib_modifiers", getroottable())

// ========================================================================
// AOE: Area of Effect (selectors + applicators)
// ========================================================================
IncludeScript("maolib_aoe", getroottable())

// ========================================================================
// STATUS EFFECTS: DoT system + flat key-value registry
// ========================================================================
IncludeScript("maolib_status", getroottable())

// ========================================================================
// MAPPER: Map utilities, prop spawning, player helpers
// ========================================================================
IncludeScript("maolib_mapper", getroottable())

// ========================================================================
// OPTIONAL MODULES (include if you need them):
//   IncludeScript("maolib_cooldowns", getroottable())  — cooldown manager
// ========================================================================

printl("[MaoLib] Standalone Framework v2.2 fully loaded")
printl("[MaoLib] Namespaces: MaoLib, MaoLib.NavUtils, MaoLib.PlayerState, MaoLib.HUD")
printl("[MaoLib]             MaoLib.Modifiers, MaoLib.AoE, MaoLib.StatusEffects, MaoLib.Mapper")
printl("[MaoLib]             MaoLib_VFX, MaoLib_TimersCleanup")
