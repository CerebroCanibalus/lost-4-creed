# MaoLib — L4D2 VScript Framework

**Version 2.2** — Originally part of the *Lost 4 Creed* modpack, now available as a standalone library for the L4D2 modding community.

---

## What is MaoLib?

MaoLib is a **pure VScript framework** for Left 4 Dead 2 that provides everything a modder needs to create gameplay systems without reinventing the wheel. No VSLib, no Lua, no external dependencies — just native Squirrel VScript + the power of L4D2's engine APIs.

**Zero bloat. Zero VSLib. Zero Lua. Pure VScript.**

---

## Modules

| Module | Namespace | Purpose |
|--------|-----------|---------|
| **Core** | `::MaoLib` | Timers, entity iterators, math, config parser, button controls |
| **NavUtils** | `MaoLib.NavUtils` | Pathfinding, nav areas, LOS, high ground, choke points |
| **PlayerState** | `MaoLib.PlayerState` | Per-player key-value state (auto-cleaned on disconnect/round end) |
| **HUD** | `MaoLib.HUD` | Chat/center/hint/game_text messaging with throttle, queue, colors |
| **Modifiers** | `MaoLib.Modifiers` | Speed/friction modifier stacking with auto-expiry |
| **AoE** | `MaoLib.AoE` | Area of Effect: selectors (circle/cone/line/wave) + applicators (damage/heal/stagger/push) |
| **StatusEffects** | `MaoLib.StatusEffects` | DoT system + flat key-value buff/debuff registry |
| **Mapper** | `MaoLib.Mapper` | Prop spawning, director helpers, player utilities |
| **VFX** | `::MaoLib_VFX` | Particles, explosions, impacts, screenshake, screen effects |
| **TimersCleanup** | `::g_TimersCleanup` | Timer leak detection + console commands (`DumpTimers()`) |

---

## Quick Start

### Option 1: Drop-in VPK (easiest)
Place the VPK in your `addons/` folder. MaoLib auto-loads on map start.

### Option 2: Include from your script
```squirrel
IncludeScript("maolib", getroottable())

// Now use any MaoLib API:
MaoLib.AddTimer("my_timer", 1.0, function() {
    printl("Tick!")
})

MaoLib.HUD.NotifyAll("Hello survivors!", { mode = "chat", throttle = 5.0 })

local targets = MaoLib.AoE.Select.Circle(origin, 500, { className = "infected" })
MaoLib.AoE.Apply.Damage(targets, 50, attacker, (1 << 1))
```

### Option 3: Manual module loading
```squirrel
IncludeScript("maolib", getroottable())          // Core + VFX + NavUtils + TimersCleanup
IncludeScript("maolib_state", getroottable())     // PlayerState
IncludeScript("maolib_hud", getroottable())       // HUD
IncludeScript("maolib_modifiers", getroottable()) // Modifiers
IncludeScript("maolib_aoe", getroottable())       // AoE
IncludeScript("maolib_status", getroottable())    // StatusEffects
IncludeScript("maolib_mapper", getroottable())    // Mapper
```

---

## Key Features

### ⏱️ Timer Manager (use this, NOT logic_timer!)
```squirrel
MaoLib.AddTimer("name", interval_seconds, callback_fn)     // Recurring
MaoLib.DelayCall(function() { ... }, delay_seconds)        // One-shot
MaoLib.RemoveTimer("name")
MaoLib.PauseTimer("name") / MaoLib.ResumeTimer("name")
MaoLib.ClearAllTimers()    // Call on round_end
```
Never use `AddThinkToEnt` or `logic_timer` directly. The timer manager uses a single `logic_timer` entity that dispatches to all registered callbacks — immune to think overwrites.

### 💬 HUD Messaging
```squirrel
MaoLib.HUD.Notify(player, "Hello!", { mode = "chat" })
MaoLib.HUD.NotifyAll("Warning!", { mode = "hint", throttle = 10.0, sound = "ui/beep01.wav" })
MaoLib.HUD.ColorGreen("text")  // Chat color helper
```
Supported modes: `chat`, `center`, `hint`, `game_text`. Built-in throttle, queue, priority system, and color helpers.

### 🎯 AoE System
```squirrel
// Select → Apply pipeline
local targets = MaoLib.AoE.Select.Circle(origin, radius, { className = "player" })
local hits = MaoLib.AoE.Apply.Damage(targets, damage, attacker, dmgType, {
    falloff = "linear", origin = origin, radius = radius
})
```
Selectors: `Circle`, `Cone`, `Line`, `ExpandingCircle` (progressive wave).  
Applicators: `Damage`, `Heal`, `HealTemp`, `Stagger`, `Push`, `ModifierSpeed`, `ModifierFriction`, `Callback`.

### 🧭 NavUtils
```squirrel
MaoLib.NavUtils.GetNearestNavArea(pos, maxDist)
MaoLib.NavUtils.FindHighGround(center, radius, minHeight)
MaoLib.NavUtils.FindChokePoints(center, radius)
MaoLib.NavUtils.FindFlankingRoutes(target, radius)
MaoLib.NavUtils.HasLineOfSight(start, end)
```
Full pathfinding, area analysis, high ground/choke/flank detection, LOS checks, flow distance, and hittable prop finding.

---

## For Developers

### Architecture
- All modules are tables merged into `::MaoLib` or registered as globals (`::MaoLib_VFX`, `::MaoLib_TimersCleanup`)
- Hard dependency: `maolib.nut` must load first (provides `::MaoLib`)
- Submodules check for `::MaoLib` existence before loading
- Event callbacks use `__CollectGameEventCallbacks(table)` — NEVER `getroottable()`

### Known Source Engine Limitations
- `info_particle_system` requires `effect_name` at spawn time — setting it via `__KeyValueFromString` after spawn DOES NOT work
- `ambient_generic.SetParent()` is NOT supported — use `SourceEntityName` keyvalue pointing to `info_target`
- `LookupBone` on "infected" class CRASHES the engine — use `GetEffectPosition()` instead
- `light_dynamic.SetOrigin()` while lit does NOT update position — toggle `TurnOff`/`TurnOn`
- `AddThinkToEnt` supports only ONE think function per entity — use `MaoLib.AddTimer()` instead

### Timer Pitfalls
- `AddTimer` = **recurring** (never stops on its own). For one-shot: use `DelayCall()`
- Always clean up timers in `round_end` / `mission_lost`:
  ```squirrel
  function OnGameEvent_round_end(params) {
      MaoLib.RemoveTimer("my_timer")
  }
  ```
- Use `MaoLib.GetTimerDebugInfo()` or console command `script ::DumpTimers()` to inspect active timers

### ⚠️ CRITICAL: Damage Recursion Guard
If you call `TakeDamage()` or `AoE.Apply.Damage()` from inside a `player_hurt` or `infected_hurt` handler, you MUST guard against infinite recursion:
```squirrel
_processingDamageEvent = false
function OnGameEvent_player_hurt(params) {
    if (_processingDamageEvent) return
    _processingDamageEvent = true
    // ... your damage logic ...
    _processingDamageEvent = false
}
```

### Method Detachment
Squirrel pitfall: passing a method as a callback loses `this`.
```squirrel
// ❌ Broken
MaoLib.AddTimer("t", 0.5, Table.Method)

// ✅ Correct
MaoLib.AddTimer("t", 0.5, function() { Table.Method() })

## Credits

- **Beria** — Lead developer, MaoLib architecture
- **Richardhaifer** — Co-developer, testing, mapping
- **Lost 4 Creed Team** — Original modpack development

Originally part of the *Lost 4 Creed* horror/coop modpack. Released standalone for the modding community. FREE OF CHARGE, DON'T CREDIT ME
