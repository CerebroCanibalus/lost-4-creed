# l4cInfectedGameplay - Infected Gameplay Addon

## Overview

This addon modifies the behavior and mechanics of all Special Infected (SI) and Common Infected (CI) in Left 4 Dead 2. It enhances AI, adds new mechanics, and rebalances combat for a more challenging and dynamic experience.

**Author:** Lost 4 Creed Team  
**Dependencies:** l4cCoreAddon (maolib, maolib_vfx, maolib_navutils)  
**Game Mode:** All modes (Campaign, Versus, Survival)

---

## Architecture

### Event Registration Pattern

All scripts in this addon use the **vanilla VScript pattern**:

```squirrel
::MyScript <- {
    function OnGameEvent_player_hurt(params) { /* ... */ }
    function OnGameEvent_round_start(params) { /* ... */ }
}
__CollectGameEventCallbacks(::MyScript)
```

**Important:** Do NOT use `MaoLib.Events.Register()` — the centralized event system was removed. Each script manages its own event callbacks.

### Script Loading

All scripts are explicitly loaded by `director_base_addon.nut` via `IncludeScript()`. There is no alphabetical loading — the order is defined in the director script.

---

## Table of Contents

1. [Consolidation Summary](#consolidation-summary)
2. [Witch System](#witch-system)
3. [Smoker System](#smoker-system)
4. [Hunter System](#hunter-system)
5. [Boomer System](#boomer-system)
6. [Spitter System](#spitter-system)
7. [Common Infected System](#common-infected-system)
8. [Infected Balance](#infected-balance)
9. [Tank System](#tank-system)
10. [Configuration](#configuration)
11. [Script Inventory](#script-inventory)
12. [Troubleshooting](#troubleshooting)

---

## Consolidation Summary

This addon was refactored from 35+ individual scripts into focused, consolidated modules:

| System | Before | After | Removed |
|--------|--------|-------|---------|
| **Witch** | 7 scripts | `witch_system.nut` + `witch_damage.nut` | `witchmulti` (duplicate) |
| **Smoker** | 4 scripts | `smoker_system.nut` | `last_breath` (mechanic) |
| **Hunter** | 3 scripts | `hunter_system.nut` | — |
| **Boomer** | 3 scripts | `boomer_system.nut` | `fall` (mechanic) |
| **Spitter** | 2 scripts | `spitter_system.nut` | — |
| **Common** | 5 scripts | `common_system.nut` | — |
| **Balance** | 4 scripts | `infected_balance.nut` | — |
| **Tank** | 8 scripts | `tank_core` + `tank_combat` + `tank_death` + `tank_ai` | `tank_expert` (obsolete) |

**Total reduction:** ~38 scripts → 18 scripts (53% reduction)

### Status
- ✅ **Completed:** Witch, Smoker, Hunter, Boomer, Spitter, Common, Balance, Tank
- ⏳ **Pending:** Testing in-game

---

## Witch System

**Files:** `witch_system.nut`, `witch_damage.nut`

### witch_system.nut — Dynamic Behavior

**1. Spawn Relocation**
- Witches spawning too close to main path (<150u) are relocated
- Configurable via `witches_spawn_off_path/Settings.cfg`
- Respects wandering witches and bride witch

**2. Prop Anger**
- Witches get angry when props (gascans, etc.) are thrown near them
- Distance-based anger calculation
- Max 50% anger from props alone
- Configurable via `witchprops/options.cfg`

**3. Flashlight Rage**
- Witches detect flashlights pointed at them
- Dynamically switches between calm and angry CVar sets
- Configurable via `flashlight_witches_v2/settings.txt`

**4. Horde Trigger**
- Provoking a witch forces a panic event
- Commons rush the provoker

### witch_damage.nut — Combat Scaling

**1. Damage Reduction (scaled by difficulty)**
- Easy: 30% of original damage
- Normal: 45% of original damage
- Advanced: 60% of original damage
- Expert: 75% of original damage
- Realism: 100% (vanilla)

**2. Size Customization**
- Default: 1.5x scale
- CVar: `kuro_witch_size`
- Random mode: Set to `666` for random sizes (0.5x to 2.5x)

---

## Smoker System

**File:** `smoker_system.nut`

**Consolidated from:** `smoker_momentum_tongue` + `smoker_fly_bomb` + `smokerpoison`
**Removed:** `smoker_last_breath` (post-death gas cloud)

### Features

**1. Momentum Tongue**
- Drag speed accelerates over time
- Formula: impulse = 2.0 + (time × 1.2) + (distance / 250)
- Long-range snipes pull harder

**2. Fly Bomb (Hold R)**
- Hold Reload for 1.25s to charge, release to launch
- Creates poison cloud on impact (10s duration)
- Cloud damages survivors, heals infected, spawns commons
- Visual charge indicator (sprite changes color)
- 20s cooldown

**3. Poison DoT**
- Choke damage converted to Damage over Time
- 5 ticks over 5 seconds
- Damage scales with initial grab distance

---

## Hunter System

**File:** `hunter_system.nut`

**Consolidated from:** `hunter_lead` + `hunter_jump` + `hunter_pounce`

### Features

**1. Lead Prediction (Bots only)**
- Bot hunters predict survivor movement
- Calculates intercept trajectory
- Updates aim every 0.1s

**2. Charged Jump**
- Hold Crouch to charge jump power
- Charge time: 0-3 seconds
- Min impulse: Up 400 / Forward 450
- Max impulse: Up 800 / Forward 900
- Visual charge indicator (sprite above head)
- Sound cue when fully charged
- **5 second cooldown** between jumps
- Offense mode: R+M1 for forward-focused jump

**3. Pounce Damage**
- +10 bonus damage on successful pounce
- Aerial hit bonus: +14 damage + stagger

---

## Boomer System

**File:** `boomer_system.nut`

**Consolidated from:** `boomer_mechanics` + `boomer_exp`
**Removed:** `boomer_fall` (fall explosion)

### Features

**1. Burning Explosion**
- Boomer death while burning spreads fire
- Radius: 225u, Damage: 25
- Ignites nearby infected, witches, and props

**2. Witch Alert**
- Boomer explosions alert nearby witches
- Burning boomers make witches instantly aggressive

**3. Car Alarm Trigger**
- Boomer explosions trigger car alarms within 250u

**4. Vomit Chain**
- Vomiting an already-vomited survivor expands the effect
- Nearby survivors within 400u also get vomited
- Extended duration for chain targets

**5. Vomit Damage**
- +10 damage when vomited

---

## Spitter System

**File:** `spitter_system.nut`

**Consolidated from:** `spitter_destroy` + `spitterslow`

### Features

**1. Acid Destruction**
- Spit destroys/ignites explosive props over time
- Checks every 1 second (migrated from `ScriptedMode_AddUpdate`)
- Affected props: gascans, propane, oxygen, explosive boxes, fuel barrels

**2. Survivor Slow**
- Players in spit are slowed (friction 1.85)
- Visual fly particles
- Instructor hint for new players
- Effect lasts 5 seconds after leaving spit

---

## Common Infected System

**File:** `common_system.nut`

**Consolidated from:** `infected_regen` + `fire_spreads_geeb` + `rush_incap` + `chch_rngcommonwounds` + `ci_death_fix`

### Features

**1. SI Regeneration**
- Out-of-combat HP regen for all special infected
- Configurable per class (rate, delay, fire behavior)
- Only regenerates when not taking damage

**2. Fire Spread**
- Burning commons ignite nearby infected (100u radius)
- Checked every 0.5 seconds

**3. Rush Incap**
- Commons rush incapacitated survivors within 800u
- Checked every 1 second

**4. Random Wounds**
- 1/8 chance for visual wounds on common spawn
- Applied via bodygroup variation

**5. Death Fix**
- Fixes frozen common infected that refuse to die
- Checked every 2 seconds

---

## Infected Balance

**File:** `infected_balance.nut`

**Consolidated from:** `infected_convars` + `custom_ml` + `nocrowning` + `boss_warning`

### Features

**1. Convars Configuration**
- All infected-related Convars set on round start
- Covers: Boomer, Smoker, Hunter, Charger, Spitter, Jockey, Commons

**2. Difficulty Scaling**
- Mob sizes scale with difficulty:
  - Easy: 20 common limit, 30 mega mob
  - Normal: 25 common limit, 45 mega mob
  - Advanced: 30 common limit, 60 mega mob
  - Expert: 35 common limit, 75 mega mob

**3. No Crowning**
- Removes shotgun bonus damage to witches
- `z_shotgun_bonus_damage_multiplier = 1`

**4. Boss Warnings**
- Visual hint + sound when Tank or Witch spawns
- "⚠️ TANK DETECTED - Start Praying..."
- "⚠️ WITCH NEARBY - Lights out..."

---

## Tank System (Consolidated)

**Consolidated from:** 8 scripts → 4 scripts

| Script | Purpose | Original Scripts |
|--------|---------|------------------|
| `tank_core.nut` | Base config + HP scaling + Expert modifier + Model + Melee alert | `tank_base` + `tank_expert` + `tank_model` + `tank_melee` |
| `tank_combat.nut` | Fire rework + Berserker states + Crowd control | `tank_fire_rework` + `tank_berserker` + `tank_crowd_control` |
| `tank_death.nut` | Epic death sequence | `tank_death_spectacle` |
| `tank_ai.nut` | Aggressive AI state machine | `tank_aggressive_ai` |
| `tankaim.nut` | Rock aimbot for bot tanks | *(standalone)* |
| `rotpi.nut` | Fixes tank punch knockback on incap | *(standalone)* |

### HP Scaling (Buffed)

| Stat | Old Value | New Value |
|------|-----------|-----------|
| Base HP | 7500 | **9000** |
| HP per minute | 9 (0.15/s) | **30 (0.5/s)** |
| Max HP | 12000 | **15000** |
| Director Health | 8000 | **9000** |

### Damage Modifier by Difficulty

| Difficulty | Coop/Realism | Versus |
|------------|-------------|--------|
| Easy/Normal/Advanced | **150%** (more damage) | 100% |
| Expert | **60%** (no instakill) | 100% |

### tank_core.nut Features

**1. Base Configuration**
- All tank convars set on load
- Speed: 225 (coop), 235 (versus)
- Rock radius: 150
- Burn duration: 70s (normal), 60s (expert)

**2. Random Model**
- 3 variants: hulk, hulk_dlc3, hulk_l4d1
- Randomized on `spawned_as_tank`

**3. Melee Alert**
- Red screen flash when survivor melee attacks tank
- Configurable via `tma/tma_config.txt`

**4. Expert Damage Modifier**
- Only applies in coop/realism
- Prevents instakill on Expert difficulty

### tank_combat.nut Features

**1. Fire Rework**
- Tank on fire: +25% speed
- Leaves fire trail (2 DPS to survivors)
- Can extinguish by breaking water props
- No self-heal from fire

**2. Berserker States**
| State | HP% | Speed | Damage Bonus |
|-------|-----|-------|--------------|
| Wounded | 60% | +15% | +25% |
| Enraged | 35% | +30% | +50% |
| Berserker | 15% | +50% | +100% |

- Visual particles, screen shake, sound cues
- Faster rock throw in enraged/berserker states

**3. Crowd Control**
- Anti-celebration: Cancels punch animation
- AOE knockback: Pushes nearby survivors on punch
- Incap splash: Punching incapacitated survivor damages nearby survivors

### tank_death.nut Features

- Progressive blood explosions (0s to 2.8s)
- Flying gibs (brains, heart, steaks)
- Blood decals on ground
- Shockwave pushes/damages nearby infected
- Screen shake for all players

### tank_ai.nut Features

**State Machine** (ThinkInterval=0.15s, MaoLib timer):
- `ASSESS` → Evaluate situation (LOS check, fire avoidance, flank opportunities)
- `PRESSURE` → Move toward target with **trajectory prediction** + occasional jumps
- `COMMIT` → Melee attack + **environment destruction** (breakable props only)
- `ROLLBACK` → Retreat to high ground/cover
- `THROW` → Rock throw with **target switching every 1.5s** (unpredictable aim)
- `FLANK` → Attack from side angle (**cooldown 4s**, tries both sides, high ground fallback)
- `BERSERK` (<15% HP) → **Bunnyhop mode** (bots only, 0.06s timer, 225 speed)

**Bugs fixed (2 Jun 2026):**
- State initialization: `DetectNewTanks()` usaba `-1` en `*Start` fields, pero las states esperaban `== 0`. **Esto impedía que COMMIT/THROW/FLANK se inicializaran correctamente.**
- `FindRollbackPosition` pasaba Vector a `IsNearFire()` (espera entidad) — runtime crash potencial.

**Technical Debt (pendiente):**
- **COMMIT target switching**: El Tank se enfoca en un solo survivor durante COMMIT. No cambia de target si el survivor actual se aleja/incapacita.
- **Zoning/area denial**: El Tank no bloquea caminos activamente ni se posiciona en chokepoints para controlar el movimiento de los survivors.
- **SI coordination**: No hay awareness de hordas/SI aliados para timing de ataques coordinados.

---

## Configuration

### File Locations

All configuration files are stored in the L4D2 `left4dead2/` directory:

| Script | Config Path | Description |
|--------|-------------|-------------|
| `witch_system.nut` | `witches_spawn_off_path/Settings.cfg` | Spawn relocation settings |
| `witch_system.nut` | `witchprops/options.cfg` | Prop anger mechanics |
| `witch_system.nut` | `flashlight_witches_v2/settings.txt` | Flashlight CVar overrides |
| `witch_damage.nut` | `kuro_witch_size` cvar | Model scale (1.5 default, 666=random) |
| `smoker_system.nut` | `smoker_system/Settings.cfg` | All smoker settings |
| `tank_melee.nut` | `tma/tma_config.txt` | Melee alert settings |

### Config Format

Most configs use simple key-value pairs:
```
key = value
key2 = "string value"
```

If a config file is missing, the script auto-generates it with default values on first run.

---

## Script Inventory

### Current Files (After Full Consolidation)

| File | Size | Purpose | Events Used |
|------|------|---------|-------------|
| `witch_system.nut` | Large | Spawn, props, flashlight, horde | witch_spawn, round_start, round_start_post_nav, weapon_drop, weapon_drop_to_prop, witch_harasser_set |
| `witch_damage.nut` | Small | Damage scaling, size | witch_spawn, AllowTakeDamage |
| `smoker_system.nut` | Large | Tongue momentum, poison DoT, fly bomb | tongue_grab, tongue_release, choke_start, player_death, round_start_post_nav |
| `hunter_system.nut` | Large | Lead prediction, charged jump, pounce damage | player_spawn, player_death, lunge_pounce, player_hurt |
| `boomer_system.nut` | Medium | Fire spread, witch alert, car alarms, vomit chain | boomer_exploded, player_now_it |
| `spitter_system.nut` | Medium | Acid destruction, survivor slow | round_start, entered_spit, player_bot_replace |
| `common_system.nut` | Medium | Regen, fire spread, rush incap, wounds, death fix | round_start, player_hurt, infected_spawn |
| `infected_balance.nut` | Medium | Convars, difficulty scaling, no crowning, boss warnings | round_start_post_nav, difficulty_changed, tank_spawn, witch_spawn |
| `charger_bounce.nut` | Small | Bounce physics | player_hurt |
| `tank_core.nut` | Medium | Base config + Model + Melee + Expert modifier | tank_spawn, spawned_as_tank, difficulty_changed |
| `tank_combat.nut` | Large | Fire + Berserker + Crowd Control | player_hurt, player_incapacitated, revive_success, tank_spawn, round_start_post_nav |
| `tank_death.nut` | Large | Death sequence | player_death |
| `tank_ai.nut` | Large | AI state machine | *(think-based, no events)* |
| `tankaim.nut` | Medium | Rock aimbot | tank_spawn |
| `rotpi.nut` | Small | Punch knockback fix | player_death |
| `chch_uncommons.nut` | Small | Uncommon infected variants | round_start |
| `infected_music.nut` | Small | Music triggers | round_start |
| `director_base_addon.nut` | Medium | Director control, script loader | Various |

---

## Troubleshooting

### "Script errors in console"
- Verify `l4cCoreAddon` is loaded (provides maolib)
- Check that `maolib.nut` loads before this addon
- Look for system prefix in errors: `[WitchSystem]`, `[SmokerSystem]`, etc.

### "Witch not relocating"
- Check `witches_spawn_off_path/Settings.cfg` exists
- Verify NavMesh is valid for the map

### "Flashlight mod not working"
- Verify `flashlight_witches_v2/settings.txt` exists
- Check that no other addon overrides `z_witch_*` CVars

### "Tank fire mechanics conflict"
- Only `tank_fire_rework.nut` is loaded (not `tankfire.nut`)
- If you want the old system, edit `director_base_addon.nut`

### "Smoker fly bomb not working"
- Ensure key bindings allow Reload (R) for Smoker
- Check cooldown: 20 seconds between uses

### "Hunter charged jump feels weak"
- Hold crouch longer! Max charge takes 3 seconds
- Check cooldown: 5 seconds for humans, 2 for bots

---

## Migration Notes

### From Old Scripts

If you have references to old script names:

| Old Script | New Script | Status |
|------------|------------|--------|
| `witchspawn.nut` | `witch_system.nut` | Merged |
| `witchprops.nut` | `witch_system.nut` | Merged |
| `flashlight_witch.nut` | `witch_system.nut` | Merged |
| `witch_horde.nut` | `witch_system.nut` | Merged |
| `witchdamage.nut` | `witch_damage.nut` | Merged |
| `witchmulti.nut` | `witch_damage.nut` | Duplicate, removed |
| `witch_size.nut` | `witch_damage.nut` | Merged |
| `smoker_momentum_tongue.nut` | `smoker_system.nut` | Merged |
| `smoker_fly_bomb.nut` | `smoker_system.nut` | Merged |
| `smokerpoison.nut` | `smoker_system.nut` | Merged |
| `smoker_last_breath.nut` | — | Removed |
| `hunter_lead.nut` | `hunter_system.nut` | Merged |
| `hunter_jump.nut` | `hunter_system.nut` | Merged |
| `hunter_pounce.nut` | `hunter_system.nut` | Merged |
| `boomer_mechanics.nut` | `boomer_system.nut` | Merged |
| `boomer_exp.nut` | `boomer_system.nut` | Merged |
| `boomer_fall.nut` | — | Removed |
| `spitter_destroy.nut` | `spitter_system.nut` | Merged |
| `spitterslow.nut` | `spitter_system.nut` | Merged |
| `infected_regen.nut` | `common_system.nut` | Merged |
| `fire_spreads_geeb.nut` | `common_system.nut` | Merged |
| `rush_incap.nut` | `common_system.nut` | Merged |
| `chch_rngcommonwounds.nut` | `common_system.nut` | Merged |
| `ci_death_fix.nut` | `common_system.nut` | Merged |
| `infected_convars.nut` | `infected_balance.nut` | Merged |
| `custom_ml.nut` | `infected_balance.nut` | Merged |
| `nocrowning.nut` | `infected_balance.nut` | Merged |
| `boss_warning.nut` | `infected_balance.nut` | Merged |
| `tank_base.nut` | `tank_core.nut` | Merged |
| `tank_expert.nut` | `tank_core.nut` | Merged |
| `tank_model.nut` | `tank_core.nut` | Merged |
| `tank_melee.nut` | `tank_core.nut` | Merged |
| `tank_berserker.nut` | `tank_combat.nut` | Merged |
| `tank_fire_rework.nut` | `tank_combat.nut` | Merged |
| `tank_crowd_control.nut` | `tank_combat.nut` | Merged |
| `tank_death_spectacle.nut` | `tank_death.nut` | Merged |
| `tank_aggressive_ai.nut` | `tank_ai.nut` | Merged |

---

*Last updated: 2026-06-02*  
*Consolidation: ~38 scripts → 18 scripts (53% reduction)*  
*Tank HP Buff: 9000 base / 15000 max / +30 HP/min*
*Tank AI: ThinkInterval 0.15s (MaoLib), +trajectory predictiva, +env destruction, +target switching, +bunnyhop BERSERK*
