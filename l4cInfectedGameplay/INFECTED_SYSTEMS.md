# L4C INFECTED SYSTEMS

## MAOLIB - Central Compatibility Library

**Location**: `l4cCoreAddon/scripts/vscripts/maolib.nut`

MaoLib (formerly HeavyUtils) is the **core native VScript library** for the L4C modpack. Named in honor of Mao Zedong, it provides stable, dependency-free utilities that work across all L4D2 versions without requiring VSLib or SourceMod.

### Philosophy
- **Native-only**: Uses only documented VScript APIs
- **Zero external dependencies**: No VSLib, no plugins
- **Cross-addon compatibility**: Available to all 4 addon folders
- **Stability first**: Graceful fallbacks, no crashes

### Key Functions
- **Entity Iterators**: `YieldSurvivors()`, `YieldSpecials()`, `YieldPlayers()`, `YieldWitches()`
- **Validation**: `IsAlive()`, `IsAlivePlayer()`, `IsReal()`, `GetScope()`
- **AI Manipulation**: `GetTarget()`, `ForceTarget()`, `GetTargetMisc()`
- **Think Hooks**: `AddMonitor()`, `RemoveMonitor()` - attach logic to any entity
- **Button Control**: `DisableKey()`, `EnableKey()`, `StartKey()`, `EndKey()`
- **Math**: `min()`, `max()`, `clamp()`, `DistanceBetween()`, `VectorAngle()`
- **Config**: `SaveOptionsFmt()`, `GetOptions()`, `InitOptions()`
- **Timing**: `DelayCall()`, `DelayCallOpt()`
- **Utilities**: `Probability()`, `FileExists()`, `Replace()`, `printf()`
- **Tank Speed Coordination**: `ApplyTankSpeed()` — shared system for multi-script speed modifiers (berserker + fire)

### NavUtils (`maolib_navutils.nut`) — Global Pathfinding
**Location**: `l4cCoreAddon/scripts/vscripts/maolib_navutils.nut`

Reusable navigation system for **ALL Special Infected** (not just Tank). Extracted and enhanced from PassiveTank.

- **High Ground**: `FindHighGround(center, radius, minHeight)` — for Tank rocks, Hunter pounces, Spitter shots
- **Choke Points**: `FindChokePoints(center, radius)` — narrow corridors for any SI
- **Flanking Routes**: `FindFlankingRoutes(target, radius, side)` — side attacks for any SI
- **Hittable Props**: `FindHittableProps(center, radius)` — cars, dumpsters, barrels for Tank
- **Rock Spots**: `FindRockSpots(tank, survivors, radius)` — elevated positions with line of sight
- **Path Building**: `BuildPathToTarget(entity, target, team)`, `GetPathDistance(path)`
- **Area Analysis**: `IsOpenArea(nav)`, `IsChokePoint(nav)`, `IsAreaValid(nav)`
- **Survivor Analysis**: `FindMostVulnerableSurvivor(survivors)`, `AreSurvivorsGrouped(survivors, maxDist)`
- **Environment**: `IsNearFire(entity, radius)`, `HasLineOfSight(start, end)`

### Used By
- `tankaim.nut` - Bot Tank rock targeting
- `tank_aggressive_ai.nut` - Tank AI navigation
- `hunter_lead.nut` - Hunter lead prediction
- `witchprops.nut` - Witch anger system
- `specialdoors.nut` - Door breaking AI
- `poltergeists.nut` - Poltergeist events
- `eventsnd.nut` - Event sound system

---

## GLOBAL

### Base Stats (`infected_convars.nut`)
- **Boomer**: HP 70 | speed 170 | vomit range 300 | interval 35s | female chance 50%
- **Hunter**: HP 200 | speed 390 | lunge dist 1000 | pounce dmg interval 0.3s | max bonus dmg 75
- **Jockey**: HP 485 | speed 230 | leap range 250 | ride dmg 1.0 | control max 1.0
- **Smoker**: HP 700 | speed 190 | tongue range **1800** | choke dmg **5/2.0s** | break dmg **110** | fly speed **520** | drag speed **240** | escape range **450**
- **Spitter**: HP 160 | speed 300 | spit velocity 1100 | range 950 | interval 15s
- **Charger**: HP 870 | charge speed 460→860 | duration 3.5s | pound dmg 10 | interval 6s
- **Witch**: HP 4000 | speed 185→260 injured | burn time 16s | dmg 40 | wander time 10s
- **Tank**: HP 6000-9000 (time-scaled) | speed **180** | rock radius 150 | throw force 1500 | swing interval 1.75s | burn duration 70s

### Regen (`infected_regen.nut`)
- All specials regen HP after combat
- Rate: 5 HP/s (charger,jockey,hunter,smoker,spitter) | 3 HP/s (boomer)
- Delay post-damage: 1.5s (boomer 2.5s)
- Fire blocks regen unless `allow_regen_on_fire=1`
- Config file: `special_infected_regen/settings.txt`

### Disarm (`infected_disarm.nut`)
- Infected melee hit (type 128) → chance survivor drops primary weapon
- Healthy: 1/X chance (X=`default_chance`, default 15)
- Low HP: 1/Y chance (Y=`low_health_chance`, default 45)
- Config file: `infected_disarm/disarm.txt`

### Music (`infected_music.nut`)
- Hunter pounce → "Event.HunterPounce" sound
- Smoker drag → "Event.SmokerDrag" | choke → "Event.SmokerChoke"
- Jockey ride → "Event.JockeyRide"
- Charger carry → "Event.ChargerSmash" | pummel → "Event.ChargerSlam"
- Sounds stop on event end

### Fire Spread (`fire_spreads_geeb.nut`)
- Infected on fire → area fire around it
- Fire spreads to nearby infected
- Chain reaction mechanic

---

## SMOKER

### Poison Tongue (`smokerpoison.nut`)
- Choke dmg scales with capture distance
- Longer tongue = more dmg per choke tick

### Momentum Tongue (`smoker_momentum_tongue.nut`)
- **Base speed reduced**: drag starts at 240 (was 470), fly speed 520 (was 760)
- **Gradual acceleration**: impulse formula = 2.0 + (elapsed_time * 1.2) + (initial_distance / 250)
- Applied every 0.1s via `ApplyAbsVelocityImpulse` toward smoker
- Longer distance = faster acceleration cap (max impulse 25)
- Tongue more fragile: break dmg 110 (was 350), range 1800 (was 1500)
- Preserves `tongue_start_pull_delay = 1.38` for suspense moment
- Auto-cleans on death/tongue release

### Fly Bomb (`smoker_fly_bomb.nut`)
- **Secondary ability**: Hold R for 1.25s to charge, release early to cancel
- Projectile with ballistic arc (700 speed, 40 gravity)
- On impact: creates gas cloud (300 radius, 10s duration)
- **Survivor effects**: 1 DPS poison, screen shake, fly particles (`Spitter_Bugged`), cough sounds
- **Infected healing**: Comuns +5HP/2s, Specials +2HP/2s, Smoker +3HP/2s
- **Common spawn**: 1-2 commons every 3s inside cloud
- **Bot AI**: Evaluates every 15s, 25% chance if survivors in 300-1500u range
- **Reusable**: `CreateFlyCloud()` function usable for death explosion (Last Breath)
- 20s cooldown with center-screen messages

### Last Breath (`smoker_last_breath.nut`)
- **Death explosion**: Auto-triggers when any Smoker dies
- **Toxic cloud**: 350 radius, 6s duration, 5 DPS (no healing)
- **Effects**: Screen shake (amp 6), cough sounds, `Spitter_Bugged` particles on survivors (3s)
- **Visuals**: Darker green smoke (`40 120 20`), dense fly swarm, explosion sound
- **Timer**: Runs only when clouds active (1.0s tick), auto-stops when empty
- No player input required - purely event-driven via `player_death`

---

## SPITTER

### Acid Slow (`spitterslow.nut`)
- Survivors in acid pool → slow + particle FX + hint text

### Acid Destroy (`spitter_destroy.nut`)
- Acid destroys explosive props (gascan, propane, fuel barrel)
- Exposure time required

---

## HUNTER

### Critical Pounce (`hunter_pounce.nut`)
- Successful pounce landing → bonus crit dmg + impact sound

### Air Dash (`hunter_jump.nut`)
- Hunter gets mid-air dash ability
- Dash-hit survivor → stagger + bonus dmg

### Lead Targeting (`hunter_lead.nut`)
- Bot Hunter calculates survivor future position
- Auto-aims to intercept point before pounce

---

## CHARGER

### Bounce (`charger_bounce.nut`)
- Survivor hit by Charger → launched random direction + vertical lift

---

## WITCH

### Size Random (`witch_size.nut`)
- Cvar `witch_size` controls scale
- Value 666 → random 0.5x-2.5x per spawn

### Damage Nerf (`witchdamage.nut` + `witchmulti.nut`)
- Witch melee dmg to survivors = 30% of normal

### Horde Call (`witch_horde.nut`)
- Witch disturbed → Director panic event + horde spawn

### Spawn Fix (`witchspawn.nut`)
- Witch too close to main path → auto-relocate to valid nav point

### Props Anger (`witchprops.nut`)
- Props thrown near Witch with enough velocity → progressive rage
- Witch chases prop thrower

### Flashlight Rage (`flashlight_witch.nut`)
- Survivor flashlight on Witch → detection range up + rage up
- Trailer-style mechanic

---

## BOOMER

### Fire Boom (`boomer_mechanics.nut`)
- Burning Boomer explodes → fire spreads to infected/witches/props
- Triggers car alarms in radius
- Reacts Witches in radius (stun/alert)

### Fall Explode (`boomer_fall.nut`)
- Bot Boomer falls >400 units → explodes on impact

### Damage Nerf (`boomer_exp.nut`)
- Boomer explosion dmg to survivors = 10
- Forces bot Boomer to vomit immediately

---

## TANK

### Aggressive AI (`tank_aggressive_ai.nut`)
- **Pro versus-style Tank AI** — aggressive, not passive
- **State machine**: ASSESS → PRESSURE → COMMIT → ROLLBACK → THROW → FLANK → BERSERK
- **Strategies from pro players**:
  - **Hit-and-run**: Punch 1-2 times, rollback to safety, repeat
  - **Target prioritization**: Molotov carriers > low HP > incapacitated > others
  - **High ground**: Finds elevated positions for rock throws
  - **Choke pressure**: Funnels survivors into narrow spaces
  - **Flanking**: Attacks from side angles when team is grouped
  - **Hittable usage**: Prioritizes cars/props when nearby
- **Integration with Berserker**: At 15% HP, enters BERSERK mode — no retreat, attacks until death
- **No callback conflicts**: Uses Think-loop detection instead of `OnGameEvent_tank_spawn`
- Uses **MaoLib.NavUtils** for all navigation queries

### Melee Effect (`tank_melee.nut`)
- Survivor melee hits Tank → red screen flash on Tank

### Rock Aim (`tankaim.nut`)
- Bot Tank rock throw → predictive arc + slight randomness

### Model Random (`tank_model.nut`)
- Random Tank model per spawn (L4D1/L4D2 variants)

### Base Config (`tank_base.nut`)
- HP scales with mission time: base 6000 + 7.5/s (450/min), max 9000
- All core convars applied (speed, range, swing timings)
- **BUGFIX**: Removed 60% damage nerf in Expert (was making Tank a "sponge")
- Uses `EntIndexToHScript()` (native) instead of `Ent()` (VSLib-only)

### Berserker Rage (`tank_berserker.nut`)
- Tank enters rage states as HP drops:
  - **Wounded** (60% HP): +15% speed, +25% dmg, red particles
  - **Enraged** (35% HP): +30% speed, +50% dmg, screen shake, faster rocks
  - **Berserker** (15% HP): +50% speed, +100% dmg, fire immunity, no stagger
- Speed via `m_flLaggedMovementValue`, dmg via bonus `TakeDamage`
- Global messages on state change

### Fire Rework (`tank_fire_rework.nut`)
- **FIXED**: Fire no longer heals the Tank (old `tankfire.nut` bug)
- Tank on fire: +25% speed, leaves burning trail
- Fire trail: 2 DPS to survivors in radius, lasts 4s
- Tank extinguishes naturally (no self-heal)

### Crowd Control (`tank_crowd_control.nut`)
- **Anti-Celebration**: Cancels rampage animation after punch (no "Tank Burger")
- **Aoe Knockback**: Punch pushes nearby survivors (150u radius, 200-400 force)
- **Incap Splash**: Punching incapacitated survivor damages nearby ones (15 dmg, 200u radius)

### Death Spectacle (`tank_death_spectacle.nut`)
- **Screen Shake**: Massive 16-amplitude shake in 1500u radius, 2.5s duration
- **Blood Explosion**: 6 simultaneous particle systems (`blood_impact_tank_01`, `gore_wound_arterial_spray_*`, `gore_wound_brain`)
- **Flying Gibs**: 12-16 physical organs spawned with explosive velocity (brains, heart, steaks)
- **Blood Decals**: 8 blood splatter decals on ground around death point
- **Explosion Sound**: `Player.TankDie` sound effect
- **Shockwave**: Damages and pushes nearby infected (400u radius, 50 blast damage, 300-600 force)
- **Gib Lifetime**: 8-12 seconds before cleanup

### Punch Incap (`rotpi.nut`)
- Tank punch keeps incap animation state
- Fixes punch→incap transition

---

## HORDES

### Rush Incap (`rush_incap.nut`)
- Survivor incapacitated → commons rush aggressively
- Reduced reaction distance

### Dynamic Scaling (`custom_ml.nut`)
- Horde size / common limit / wanderer density scales with difficulty

### Uncommons (`chch_uncommons.nut`)
- CEDA: burn on hit
- Clown: attracts horde
- Mud: more dmg in water
- Worker: cannot be shoved
- All uncommons: +HP

---

## VISUALS

### Boss Warning (`boss_warning.nut`)
- Tank/Witch spawn → red icon + sound alert to all players

### CI Death Fix (`ci_death_fix.nut`)
- Fixes common infected stuck in "down but not dead"
- Forces death on fatal wound or timeout

---

## FILE MAP

| File | System |
|------|--------|
| `infected_convars.nut` | Base stats |
| `infected_regen.nut` | HP regen |
| `infected_music.nut` | SFX |
| `infected_disarm.nut` | Weapon drop |
| `fire_spreads_geeb.nut` | Fire chain |
| `smokerpoison.nut` | Smoker poison |
| `spitterslow.nut` | Spitter slow |
| `spitter_destroy.nut` | Acid destroy |
| `hunter_pounce.nut` | Crit pounce |
| `hunter_jump.nut` | Air dash |
| `hunter_lead.nut` | Lead aim |
| `charger_bounce.nut` | Bounce launch |
| `witch_size.nut` | Size random |
| `witchdamage.nut` | Dmg nerf |
| `witchmulti.nut` | Dmg nerf dup |
| `witch_horde.nut` | Horde call |
| `witchspawn.nut` | Spawn fix |
| `witchprops.nut` | Prop anger |
| `flashlight_witch.nut` | Light rage |
| `boomer_mechanics.nut` | Fire boom |
| `boomer_fall.nut` | Fall explode |
| `boomer_exp.nut` | Dmg nerf |
| `passivetank_*.nut` | ~~Tank AI~~ (extracted to aggressive_ai + navutils) |
| `tank_base.nut` | Convars + HP |
| `tank_berserker.nut` | Rage states |
| `tank_fire_rework.nut` | Fire rework |
| `tank_crowd_control.nut` | Anti-celebration |
| `tank_aggressive_ai.nut` | Aggressive pro-style AI |
| `tank_death_spectacle.nut` | Gore explosion on death |
| `maolib_navutils.nut` | Global pathfinding (all SI) |
| `tank_melee.nut` | Red flash |
| `tankaim.nut` | Rock aim |
| `tank_model.nut` | Model rand |
| `tank_expert.nut` | ~~Scaling~~ (obsolete) |
| `tankfire.nut` | ~~L4D1 fire~~ (obsolete) |
| `rotpi.nut` | Punch fix |

---

## PENDING — Special Infected AI Reworks

Using **MaoLib.NavUtils**, the following SI AIs should be reworked for aggressive, pro-style behavior:

- [ ] **Hunter**: Predictive pounce + high-ground ambush + leap-bomb combo
- [ ] **Smoker**: Drag into choke points + coordinate with Tank for pins
- [ ] **Charger**: Slam into environmental hazards + chain-bounce survivors into hordes
- [ ] **Jockey**: Steer survivors into fire/acid + ride-and-drag into corners
- [ ] **Spitter**: Pre-aim acid pools on escape routes + combo with Charger slam
- [ ] **Boomer**: Proximity pop timing + bile-on-incap for horde focus

**Status**: Deferred. Focus shifted to Survivor AI overhaul (see l4cCoreSurvivorGameplay).
| `rush_incap.nut` | Rush down |
| `custom_ml.nut` | Horde scale |
| `chch_uncommons.nut` | Uncommon buff |
| `smoker_momentum_tongue.nut` | Momentum drag |
| `smoker_fly_bomb.nut` | Fly bomb ability |
| `boss_warning.nut` | Boss alert |
| `ci_death_fix.nut` | Death fix |

---

## NATIVE VSCRIPT DISCOVERIES

Verified functions **without VSLib**:

| Function | Source |
|----------|--------|
| `GetPlayerButtons()` | Player method (IN_RELOAD = 8192) |
| `ClientPrint(player, 4, msg)` | HUD_PRINTCENTER = 4 |
| `NetProps.SetPropFloat()` | Seen in spitterslow.nut (modern L4D2) |
| `SetFriction(value)` | Player method |
| `StopSoundOn(name, ent)` | Native |
| `EmitSoundOn(name, ent)` | Native |
| `DoEntFire()` | Native entity input |
| `info_particle_system` | + SetParent + Start works natively |
| `Spitter_Bugged` | Native fly particle (from insect_fx.pcf) |
| `farm.flies_loop` | Native fly buzzing sound |
| `env_instructor_hint` | Native hint system |
| `ApplyAbsVelocityImpulse()` | Native physics method |

---

## KNOWN CONFLICTS & NOTES

### PassiveTank System (Latent Conflict)
- **Files**: `passivetank_*.nut` (13 scripts in l4cInfectedGameplay)
- **Status**: NOT currently included in `director_base_addon.nut`
- **Risk**: If activated, convar conflicts with `tank_base.nut`:
  - `tank_throw_lead_time_factor`: passivetank sets `0` vs our `0.8`
  - `tank_throw_loft_rate`: passivetank sets `0.015` vs our `.01`
  - `tank_throw_max_loft_angle`: passivetank sets `45` vs our `30`
- **Action**: Integrate or obsolete during future Tank AI rework

### TacticalMovement Speed Migration (Resolved)
- **Old**: `tacticalmovement.nut` (l4cCoreSurvivorGameplay) modified all infected speeds
- **New**: Infected speeds moved to `infected_convars.nut` (l4cInfectedGameplay)
- **Tank speed**: Now consistently `180` across all scripts
- **Survivor speeds**: Still managed by `tacticalmovement.nut`

---

## AVAILABLE GORE PARTICLES (for Tank death spectacle)

From `l4cInfectedReplacements` addon:

### Tank-Specific
- `blood_impact_tank_01` — Large blood burst
- `blood_impact_red_01_backspray_shotgun` — Directional spray
- `blood_impact_red_01_chunk_shotgun` — Chunky debris

### General Gore
- `gore_wound_arterial_spray_1/2/3` — High-pressure blood spray
- `gore_wound_brain` — Brain matter
- `gore_wound_jaw` — Jaw destruction
- `gore_wound_belly_right/left` — Torso wounds
- `gore_wound_fullbody_1` — Full body blood
- `gore_wound_back_lower/back` — Back wounds
- `gore_wound_groin/groin_2` — Lower body

### Models Available
- `models/infected/limbs/brain_01/02/03.mdl`
- `models/infected/limbs/heart_veins.mdl`
- `models/infected/limbs/steak1/2/3.mdl`
