# l4cMapRefresh — Lost 4 Creed Map Refresh

> VScript-based map events and props for Left 4 Dead 2.
> Replaces Stripper:Source events with native VScript + MaoLib.
> Part of the Lost 4 Creed modpack.

---

## 📋 What It Does

Each campaign gets scripted cinematic events beyond what the vanilla Director provides. Think crashing helicopters, exploding fuel trucks, aircraft crashes, barricade breaches, Tank ambushes — all triggered by survivor proximity.

Events are **non-intrusive**: they trigger once, don't block progress, and add replayability without feeling scripted.

Additionally, **ambient decoration** (props, particles, atmospheric effects) is spawned procedurally from TACM map data to make each run feel fresh.

---

## 🗺️ Map Progress

### ✅ C1 Dead Center — DONE

| Map | Event | Status | Description |
|-----|-------|:------:|-------------|
| **c1m1_hotel** | Lobby Tank | ✅ | Tank bursts from saferoom lobby with cinematic entry |
| **c1m1_hotel** | Elevator Crash | ✅ | Proximity trigger near elevators → cable snap sound + explosion + fire + horde |
| c1m1_hotel | ~~Sky Elevator~~ | ❌ REMOVED | Depended on `relay_top_button` / `relay_bottom_button` (Stripper-only brush entities) |
| **c1m2_streets** | Gas Tanker | ✅ | Fuel truck explodes → fire + screen shake + heartbeat sound + Tank |
| c1m2_streets | ~~Gunshop Ambush~~ | ❌ REMOVED | Fake event (no actual trigger entity in vanilla) |
| c1m2_streets | ~~F18 Bomber~~ | ❌ REMOVED | Skipped by design (too complex, General veto) |
| c1m3_mall | — | 🚫 SKIP | Too saturated with content already |
| c1m4_atrium | — | 🚫 SKIP | Teleport bug fixed in Last Stand |

### ✅ C2 Dark Carnival — DONE

| Map | Event | Status | Description |
|-----|-------|:------:|-------------|
| **c2m1_highway** | Heli Hotel | ✅ | Helicopter overhead for 25s → engine fails → crash explosion + Tank + slow-mo + fire |
| **c2m2_fairgrounds** | Wood Barricade | ✅ | Gascan prop blocks path → shoot it → chain explosion + fire 60s + damage zone + Tank |
| **c2m2_fairgrounds** | Tank Spawn | ✅ | Trigger zone near wooden door → Tank smashes through |
| c2m3_coaster | — | 🚫 SKIP | Scavenger mode (General hates it) |
| **c2m4_barns** | Barn Tank | ✅ | Hold-zone system: survivors must stand near door 10s → Tank spawns. Back-up door at 5s. Ambient Tank sounds build tension |
| c2m5_concert | — | 🚫 SKIP | Finale not modified |

### ✅ C3 Swamp Fever — DONE

| Map | Event | Status | Description |
|-----|-------|:------:|-------------|
| c3m1_plankcountry | — | 🚫 SKIP | Tank too early in campaign |
| **c3m2_swamp** | Aircraft Crash | ✅ | Plane flies overhead 5s → mid-air explosion (shake + slow-mo) → crash (debris + fire + Tank + panic + damage zone 60s) |
| **c3m3_shantytown** | Tank Spawn | ✅ | Survivors enter warehouse corridor → explosion + fire + slow-mo + Tank + damage zone 60s |
| c3m4_plantation | — | 🚫 SKIP | Stripper-only changes |

### 🟡 C8 No Mercy — Props Only

| Map | Status | Notes |
|-----|:------:|-------|
| c8m1_apartment | 🟡 | Props + particles only, no events |
| c8m2_subway | 🟡 | Props + particles only, no events |
| c8m3_sewers | 🟡 | Props + particles only, no events |
| c8m4_interior | 🟡 | Props + particles only, no events |
| c8m5_rooftop | 🟡 | Props + particles only, no events |

### ⏳ Future Campaigns

| Campaign | Priority |
|----------|:---------:|
| C4 Hard Rain | ⬜ |
| C5 The Parish | ⬜ |
| C6 The Passing | ⬜ |
| C7 The Sacrifice | ⬜ |
| C9—C14 | ⬜ |

---

## 🏗️ Architecture

```
l4cMapRefresh/
└── scripts/vscripts/
    ├── director_base_addon.nut      # Entry point (loads maprefresh_main)
    ├── maprefresh_main.nut          # Core loader + event registration
    ├── maprefresh_utils.nut         # Spawn helpers + PropTypes integration
    ├── maprefresh_proptypes.nut     # 60+ prop/particle categories mapped to L4D2 models
    ├── maprefresh_refdata.nut       # Verified coordinates (from TACM + original repo)
    ├── _extract_tacm.ps1            # PowerShell extractor: TACM .txt → refdata format
    │
    ├── c1m1_hotel.nut               # Lobby Tank + Elevator Crash + ambiance
    ├── c1m2_streets.nut             # Gas Tanker + ambiance
    ├── c2m1_highway.nut             # Heli Hotel + props
    ├── c2m2_fairgrounds.nut         # Wood Barricade + Tank Spawn
    ├── c2m4_barns.nut               # Barn Tank (hold-zone system)
    ├── c3m2_swamp.nut               # Aircraft Crash + Tank
    └── c3m3_shantytown.nut          # Tank Spawn
```

### Dependencies (hard)

- **l4cCoreAddon** → `MaoLib`, `MaoLib.Mapper`, `MaoLib_VFX`, `MaoLib.HUD`, `MaoLib.AoE`
- Loaded via `director_base_addon.nut` chain
- No VSLib, no Stripper — pure native VScript

### Load Chain

```
director_base_addon.nut
  └─ IncludeScript("maprefresh_main", getroottable())
       ├─ Loads utils / proptypes / refdata
       ├─ Detects map via Director.GetMapName()  (was SessionState.MapName — BROKEN)
       ├─ IncludeScript("cXmY_mapname", getroottable())
       └─ ::MapRefresh.cXmY_mapname.Init()
```

### Key Architectural Decisions

| Decision | Rationale |
|----------|-----------|
| **Timer proximity** instead of `func_button` | Brush entities (`func_button`, `func_breakable`) require BSP geometry — **not spawnable via VScript**. Replaced by `MaoLib.AddTimer` polling survivor distance. |
| **No `func_timescale`** | `func_timescale` entity does **not** work when spawned via VScript in L4D2. Slow-motion is simulated via screen shake + heartbeat sound only. |
| **No `ConnectOutput` with `::`** | `ConnectOutput` resolves callback names in `getroottable()` by exact string match. `"::Table.Method"` does **not** resolve. Use global function names like `"MapRefresh_c2m2_OnBarricadeBroken"`. |
| **Fail-fast, no zombie guards** | `if (!("MapRefresh" in getroottable())) return` creates **zombie scripts** (load silently, do nothing). Removed from all scripts. If MaoLib is missing, the script crashes loud and clear. |
| **TACM as reference, not dependency** | Extracted prop coordinates and particle names from TACM (125k+ entities across 57 maps) but use our own spawn system with density control and MaoLib_VFX. |

---

## 🎮 Event Mechanics

All events follow a consistent pattern:

1. **Proximity Timer** — `MaoLib.AddTimer` polls survivor distance every 1s
2. **Trigger** — First survivor enters radius → lock trigger (one-shot)
3. **HUD hint** — `MaoLib.HUD.NotifyAll` center text
4. **Effects** — Explosion particles, fire, screen shake (`MaoLib_VFX`)
5. **Tank** — `info_zombie_spawn` with `offer_tank=1`
6. **Panic** — `Director.ForcePanicEvent()` 3s after Tank
7. **Damage zone** — `script_trigger_hurt` for 60s
8. **Cleanup** — `round_end` event kills timers + orphans

### Key VScript Patterns Used

```vscript
// ✅ Timer-based proximity trigger (no brush entities)
MaoLib.AddTimerAuto("check", 1.0, function() {
    foreach (s in MaoLib.YieldSurvivors()) {
        if (MaoLib.IsAlivePlayer(s) &&
            MaoLib.DistanceBetween(s.GetOrigin(), TRIGGER_POS) < RADIUS)
            _OnTrigger()
    }
})

// ✅ Tank spawn + cleanup
local tankSpawn = SpawnEntityFromTable("info_zombie_spawn", {
    targetname = "tank_" + UniqueString(),
    population = "river_docks_trap",
    offer_tank = 1, AttackOnSpawn = 1
})
tankSpawn.ConnectOutput("OnSpawnTank", "MyGlobal_OnSpawnTank")

// ✅ Ambient particles (persistent, cleaned on round_end)
local particle = SpawnEntityFromTable("info_particle_system", {
    targetname = "amb_" + UniqueString(),
    origin = pos,
    effect_name = "env_fire_tiny_smoke",
    start_active = 1
})
MaoLib_VFX.SafeKill(particle, 300.0)  // 5min lifetime
```

---

## 🎨 Ambient Decoration (New)

Each map now spawns **ambient props** and **persistent particles** for atmosphere:

- **Props**: Trash, barriers, tires, wheelchairs, gurneys, sleeping bags, mailboxes, buckets, luggage, dead bodies, crows, etc.
- **Particles**: Smoke, fire embers, bugs, falling leaves, paper debris, rising smoke
- **Density**: 0.5 (50% of reference data spawns per round)
- **No decals**: Disabled by design (General preference)
- **Source**: Extracted from TACM reference data (`_extract_tacm.ps1`)

| Map | Props | Particles |
|-----|-------|-----------|
| c1m1_hotel | ~15 | 4 (bugs, fire, skybox burning, subway smoke) |
| c1m2_streets | ~138 | 5 (paper, leaves, embers, exhaust smoke, riverboat smoke) |
| c2m1_highway | ~50 | 3 |
| c2m2_fairgrounds | ~80 | 4 |
| c3m2_swamp | ~40 | 6 |
| c3m3_shantytown | ~35 | 3 |

---

## 🐛 Known Issues

| Issue | Status | Notes |
|-------|--------|-------|
| c1m2 Gunshop Ambush | ❌ REMOVED | Fake event — no trigger entity in vanilla maps |
| c1m2 F18 Bomber | ❌ REMOVED | Skipped by design (too complex) |
| c1m1 Sky Elevator | ❌ REMOVED | Depended on Stripper-only brush entities |
| c1m4 Teleport Bug | 🟢 Fixed by Last Stand update |
| c2m3 Scavenger events | 🔴 Won't implement (General hates Scavenger) |
| c3m1 Tank too early | 🔴 Skipped by design |
| c8m* placeholder scripts | 🟡 Props + particles only, no events |

---

## 🔧 Development

### Creating a new map event

1. Add map to `SupportedMaps` in `maprefresh_main.nut`
2. Create `cXmY_mapname.nut` with `::MapRefresh.cXmY_mapname <- { Init(), ... }`
3. Follow the debug pattern (`Dbg/DbgWarn` functions)
4. Use `MaoLib.AddTimer` for delays (never `logic_timer` or `AddThinkToEnt`)
5. Register events table with `__CollectGameEventCallbacks`
6. Run Keith verification before PR

### Extracting TACM data for props

```powershell
# Extract prop coordinates from TACM .txt to refdata format
.\scripts\vscripts\_extract_tacm.ps1 -MapName "c5m2_park" -Mode "coop"
```

### Conventions

- **Timers**: `MaoLib.AddTimer` (never raw `AddThinkToEnt`)
- **Events**: dedicated table with `__CollectGameEventCallbacks`
- **Debug**: `Dbg()` / `DbgWarn()` methods mandatory on every public function
- **Callbacks**: closures with `::Table._method()`, never `Table.Method` raw
- **Cleanup**: `OnGameEvent_round_end` kills all timers + orphans
- **No MaoLib check**: hard dependency, assume it exists (fail-fast)
- **No func_button**: brush entities are not spawnable via VScript — use timer proximity
- **No `::` in ConnectOutput**: use global function name strings

---

## 📊 Stats

| Metric | Value |
|--------|-------|
| Active scripts | 10 |
| Events implemented | 7 |
| Lines of code | ~2,900 (this addon only) |
| Maps covered | 10 |
| Maps with events | 7 |
| Maps with props + particles | 10 |
| Prop categories | 60+ |
| TACM entities referenced | ~1,500+ |
| Keith verifications | ✅ PASS (all scripts) |

---

## 📝 Changelog

### 2026-06-04 — Stripper→VScript Port Complete
- **C1 Rewritten**: c1m1_hotel (Lobby Tank + Elevator Crash), c1m2_streets (Gas Tanker)
- **Removed**: Sky Elevator (brush dependency), Gunshop Ambush (fake event), F18 Bomber
- **C2 Cleaned**: Removed redundant per-map event registrations, fixed closure bare-name bug in c2m1
- **C3 Cleaned**: Removed zombie guards (`if (!MapRefresh) return`), simplified round_end handlers
- **Decoration**: Populated C1 with TACM reference data (15 props c1m1, 138 props c1m2, 4-5 particles each)
- **maprefresh_main v3**: `Director.GetMapName()` (fixes broken `SessionState.MapName`), try/catch chain, `_initialized` per session
- **New tool**: `_extract_tacm.ps1` for parsing TACM .txt → refdata

### 2026-06-03 — Architecture Audit
- Removed per-map redundant event registrations from C1, C2, C3
- Fixed `ConnectOutput` callback resolution (no `::` prefix)
- Confirmed `func_button` / `func_timescale` not spawnable via VScript
- Documented all root causes in AGENTS.md

### Earlier
- Initial port from jeremyvillanuevar/vscripts_custom (TADM mod)
- MaoLib integration (timers, VFX, HUD, AoE, NavUtils)
- VSLib dependency removed
