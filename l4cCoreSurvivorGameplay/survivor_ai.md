# Survivor AI Overhaul — Documentación Técnica v2.0

## Sistema de IA de Supervivientes Minimal Intervention

**Archivo**: `l4cCoreSurvivorGameplay/scripts/vscripts/survivor_ai_overhaul.nut`
**Dependencias**: MaoLib, MaoLib.NavUtils
**Intervalo de Think**: 0.2s global / 0.25s por bot (per-bot think)

---

## Filosofía del Diseño

**Minimal Intervention**: El sistema NO reemplaza la IA vanilla de L4D2. Solo interviene cuando la IA vanilla falla visiblemente. El resto del tiempo, deja que el motor nativo maneje a los bots.

Pipeline de decisión por bot:
```
BotThink(bot) → VisionScan → Deadstop → HealCheck → DetectTask
                                                          ↓
                                              ┌─ SURVIVE (100)
                                              ├─ RESCUE (90)
                                              ├─ SHOVE_TONGUE (98)
                                              ├─ SHOOT_TONGUE (97)
                                              ├─ DODGE (98)
                                              ├─ FALL_WARP (100)
                                              ├─ COMBAT (80-55)
                                              ├─ POSITION (50-40)
                                              ├─ THROW_NADE (65-55)
                                              ├─ ITEM_PICKUP (35)
                                              ├─ ITEM_GIVE (25)
                                              └─ CLOSE_DOOR (35)
                                              → null = vanilla AI ok
```

Si `DetectTask()` devuelve null → vanilla AI maneja la situación → solo se checkean items y puertas.

Este enfoque es más estable que un GOAP completo porque:
- No compite con la IA vanilla (solo la complementa)
- Menos overhead computacional
- Más fácil de debuggear (intervenciones mínimas y rastreables)
- Si nuestro sistema crashea, los bots siguen funcionando con IA vanilla

---

## Arquitectura del Think Loop

Cada tick (0.25s) para cada bot vía **MaoLib.AddTimer** per-bot:

```
BotThink(bot)
├── 0. CLEANUP: Limpiar IN_ATTACK | IN_ATTACK2 de m_afButtonForced
├── 0. VISION SCAN: Escanear amenazas visibles (usa caché, intervalo 0.15s)
├── 0.5 DEADSTOP: Shove automático a Hunter/Jockey airborne en rango
├── 0.7 HEAL INTERRUPT: Si health ≥ 50 y está med/defib → cancelar
├── 1. DETECT: DetectTask(bot) — ¿IA vanilla necesita ayuda?
│   ├── PRIORIDAD 100: SURVIVE (tank punch/rock/close, charger charge, fire)
│   ├── PRIORIDAD 100: FALL_WARP (vel vertical < -750, teammate cerca)
│   ├── PRIORIDAD 98: DODGE (spit burst, death acid)
│   ├── PRIORIDAD 98: SHOVE_TONGUE (teammate smoker-pinned, < 150u)
│   ├── PRIORIDAD 97: SHOOT_TONGUE (teammate pinned, < 800u)
│   ├── PRIORIDAD 90: RESCUE (timeout por pin: smoker 2s, hunter/jockey 3s, charger 2s)
│   ├── PRIORIDAD 80: SHOVE (≥ 5 commons a < 100u)
│   ├── PRIORIDAD 70: ATTACK_SI (SI visible a < 800u)
│   ├── PRIORIDAD 65: ATTACK_CHARGER (Charger a rango óptimo)
│   ├── PRIORIDAD 65: THROW_NADE → TANK (bot tiene throwable, tank en rango)
│   ├── PRIORIDAD 60: KITE_TANK (tank a < 560u)
│   ├── PRIORIDAD 55: THROW_NADE → HORDE (≥ 10 commons a < 500u)
│   ├── PRIORIDAD 50: UNSTICK (sin movimiento ≥ 3s)
│   └── PRIORIDAD 40: REGROUP (separado > 600u del equipo)
│   
├── [si no hay tarea de combate]: DetectItemTask(bot)
│   ├── PRIORIDAD 35: ITEM_PICKUP (sin throwable, hay uno cerca en suelo)
│   └── PRIORIDAD 25: ITEM_GIVE (tiene throwable, humano cerca sin uno)
│
└── [si no hay tarea]: DetectCloseDoor(bot)
    └── PRIORIDAD 35: CLOSE_DOOR (puerta checkpoint abierta cerca)
```

### Per-Bot Think (NUEVO — 31 Mayo 2026)

Cada bot recibe su propio timer independiente vía `MaoLib.AddTimer`:
```squirrel
MaoLib.AddTimer("sa_bot_" + userid, BotThinkInterval, function() {
    ::SurvivorAI.BotThink(bot)
})
```

**Ventajas vs el viejo info_target global:**
- Distribución de carga entre frames (no todos los bots piensan simultáneamente)
- Cada bot puede tener su propio intervalo en el futuro
- No requiere entidades `info_target` ni `AddThinkToEnt`
- Auto-cleanup en round_end via `maolib_timers_cleanup`

---

## Módulos (7 archivos)

| Archivo | Rol | Líneas aprox |
|---------|-----|-------------|
| `sa_config.nut` | Configuración, constantes, runtime state, tablas de caché | ~195 |
| `sa_validator.nut` | Validación de navmesh, `GetSafePosition()`, `IsValidNavPos()` | ~250 |
| `sa_vision.nut` | Escaneo proactivo de amenazas (SI, Tanks, commons) | ~340 |
| `sa_detector.nut` | Detección de fallos de IA vanilla (6+ tipos de tarea) | ~825 |
| `sa_executor.nut` | Ejecución de intervenciones mínimas (15+ ejecutores) | ~770 |
| `sa_items.nut` | Sistema de items: pickup, give, throw con targeting inteligente | ~130 |
| `sa_core.nut` | BotThink per-bot, eventos, caché de entidades, cleanup | ~405 |

---

## Entity Cache System

### Problema original
Cada frame se escaneaban entidades con `FindByClassname`, `YieldSpecials()`, etc. múltiples veces por bot. Con 4 bots a 10Hz, era ~80 escaneos/segundo.

### Solución
Tablas de caché actualizadas por eventos del juego, NO por escaneo:

```squirrel
CachedSpecials = {}    // userid -> entity (SI no-tank: 1-6)
CachedTanks = {}       // userid -> entity (Tanks)
CachedSurvivors = {}   // userid -> entity (Survivors)
```

### Ciclo de vida
| Evento | Acción |
|--------|--------|
| `player_spawn` | Añade a caché según zombie class |
| `player_death` | Elimina de todas las cachés por userid |
| `round_start` | Limpia todas las cachés |

### Performance gain
- Antes: ~6-8 iteraciones de entidades por bot por tick
- Ahora: ~0-2 (solo commons via `FindByClassnameWithin`, no cacheable)
- ThinkInterval reducido de 10Hz → 5Hz per-bot

---

## Features Implementadas

### 1. PER-BOT THINK (31 Mayo 2026)
Cada bot tiene su propio timer MaoLib. Ya no hay un único `info_target` global.
- Timer por bot con intervalo `BotThinkInterval = 0.25s`
- Cleanup automático en `round_end`, `mission_lost`, `map_transition`
- Distribución natural de carga CPU entre frames

### 2. TONGUE RESCUE (31 Mayo 2026)
Rescata compañeros atrapados por Smoker:
- **SHOVE_TONGUE (98)**: Si distancia < 150u → mueve al bot hacia la víctima + fuerza IN_ATTACK2
- **SHOOT_TONGUE (97)**: Si distancia < 800u → apunta al Smoker + fuerza IN_ATTACK
- No shovea la lengua (no funciona) — ataca al smoker directamente

### 3. EVENT-DRIVEN DODGE (31 Mayo 2026)
Reacción instantánea a peligros mediante eventos:
| Evento | Peligro | Acción |
|--------|---------|--------|
| `spit_burst` | Puddle de spit | Flee perpendicular (> 300u) |
| `charger_charge_start` | Charger cargando | Dodge lateral (> 400u) |
| `spitter_killed` | Death acid | Flee (> 250u) |

Tablas de estado: `SpitBursts{}`, `ChargerCharges{}`, `DeathAcidPositions{}`
- Se limpian automáticamente tras 5s sin refresh
- Detectan en BotThink si el bot está cerca del peligro

### 4. FALL WARP (31 Mayo 2026)
Previene muertes por caídas fatales:
- Detecta velocidad vertical < -750 (Utility Fall)
- Busca compañero más cercano < 500u
- `SetOrigin()` directo a la posición del compañero
- Prioridad 100 — la más alta de todo el sistema

### 5. HEAL INTERRUPT (31 Mayo 2026)
Evita que bots desperdicien medkits/defibs:
- Si health ≥ 50 y el bot está usando medkit o defibrillator → cancelar
- `m_usingMedKit` / `m_usingDefibrillator` NetProps
- Force release via cleanup de botones

### 6. SAFEROOM DOOR CLOSE (31 Mayo 2026)
Cierra puertas de checkpoint:
- `DetectCloseDoor()`: Busca `prop_door_rotating_checkpoint` abierta
- `ExecuteCloseDoor()`: Mueve bot a posición segura → timer 1.5s → `DoEntFire("Close")`
- Prioridad baja (35) — solo cuando no hay threats activos

### 7. AUTO GRENADES (31 Mayo 2026)
Lanzamiento automático de throwables:
- **Pipe bomb**: Horda ≥ 10 commons o Tank (configurable via `UsePipeBomb: 0-3`)
- **Molotov**: Tank no burning o horda (configurable via `UseMolotov: 0-3`)
- **Bile jar**: SOLO humanos (`UseVomitjar: 0`) — demasiado peligrosa para bots
- Probabilidades: 25% tank, 30% horda
- SwitchToItem + IN_ATTACK forzado + release automático a los 0.1s
- Cooldown de 30s entre lanzamientos

### 8. ITEM SYSTEM (31 Mayo 2026)
Módulo auto-contenido `sa_items.nut`:
- **Pickup**: Bot sin throwable → escanea radio 150u → `DoEntFire("Use")` para recoger
- **Give**: Bot con throwable → humano cerca sin uno → `GiveItem()` + `EmitSoundOnClient`
- **Filtro por tipo**: `CanUseThrowable("PIPE"/"MOLOTOV"/"BILE", "HORDE"/"TANK")` respeta config
- Cooldown de 2s entre intentos de pickup
- No intrusivo — prioridad más baja que todo combate

### 9. ANTI-PIPEBOMB BUG (31 Mayo 2026)
Previene crash por pipebombs activas al cambiar de mapa:
- `OnGameEvent_map_transition`: Itera pipebombs activas, `Kill()` cada una
- `OnGameEvent_round_start`: Cleanup de todas las tablas de estado

---

## Detección de Peligros (Prioridades)

| Prioridad | Task | Trigger | Respuesta |
|-----------|------|---------|-----------|
| **100** | `FALL_WARP` | Vel vertical < -750 | SetOrigin al compañero |
| **100** | `SURVIVE_TANK_PUNCH` | Tank < 200u + anim 47/48 | Escape lateral + hacia atrás |
| **100** | `SURVIVE_TANK_CLOSE` | Tank < 150u | Escape radial |
| **100** | `SURVIVE_TANK_ROCK` | Roca < 800u, ang < 30° | Dodge perpendicular |
| **100** | `SURVIVE_CHARGER` | Charger cargando o < 200u | Dodge lateral |
| **100** | `SURVIVE_FIRE` | Bot en inferno | Escape en 8 direcciones |
| **98** | `DODGE_SPIT` | Spit puddle < 300u | Flee perpendicular |
| **98** | `DODGE_ACID` | Death acid < 250u | Flee |
| **98** | `SHOVE_TONGUE` | Teammate tongued < 150u | Move + IN_ATTACK2 |
| **97** | `SHOOT_TONGUE` | Teammate tongued < 800u | Aim smoker + IN_ATTACK |
| **95** | `INTERRUPT_HEAL` | Med/defib + health ≥ 50 | Cancel heal |
| **90** | `RESCUE` | Pin timeout (2-3s) | Move to attacker |
| **80** | `SHOVE` | ≥ 5 commons < 100u | IN_ATTACK2 |
| **70** | `ATTACK_SI` | SI visible < 800u | CommandABot |
| **65** | `THROW_NADE_TANK` | Throwable + tank < 800u | SwitchToItem + fire |
| **65** | `ATTACK_CHARGER` | Charger a rango óptimo | CommandABot + move |
| **60** | `KITE_TANK` | Tank < 560u | Retroceder a 800u |
| **55** | `THROW_NADE_HORDE` | ≥ 10 commons < 500u | SwitchToItem + fire |
| **50** | `UNSTICK` | Sin movimiento ≥ 3s | Nudge a nav válida |
| **40** | `REGROUP` | Separado > 600u | Move a team center |
| **35** | `ITEM_PICKUP` | Sin throwable + uno cerca | DoEntFire("Use") |
| **35** | `CLOSE_DOOR` | Puerta checkpoint abierta | Mover + timer + close |
| **25** | `ITEM_GIVE` | Tiene throwable + humano sin | GiveItem() |

---

## Configuración (sa_config.nut)

### Timing
| Variable | Default | Descripción |
|----------|---------|-------------|
| `ThinkInterval` | 0.2 | Think global (no usado, legacy) |
| `BotThinkInterval` | 0.25 | Think por bot (4Hz) |
| `CommandCooldown` | 0.3 | Min tiempo entre CommandABot |
| `ShoveCooldown` | 0.8 | Min tiempo entre shoves forzados |
| `StuckThreshold` | 3.0 | Segundos sin movimiento = stuck |
| `VisionScanInterval` | 0.15 | Min tiempo entre escaneos de visión |
| `ManualAttackInterval` | 0.05 | Intervalo de force fire |

### Distancias
| Variable | Default | Descripción |
|----------|---------|-------------|
| `CommonDetectRadius` | 100 | Radio para detectar commons |
| `CommonShoveThreshold` | 5 | Nº commons para shovear (antes 3) |
| `CommonShoveMax` | 10 | Count para horda |
| `TankDangerRange` | 200 | Distancia crítica al Tank |
| `TankKiteRange` | 800 | Distancia óptima al Tank |
| `SIAttackRange` | 800 | Rango para atacar SI |
| `RescueMaxDist` | 2000 | Máx distancia para rescatar |
| `TeamSeparationThreshold` | 600 | Máx separación del equipo |
| `VisionMaxDistance` | 600 | Distancia máxima de visión |
| `VisionCommonRadius` | 300 | Radio para detectar commons visibles |
| `DeadstopRange` | 150 | Rango para deadstop automático |

### Rescue Timeouts
| Variable | Default |
|----------|---------|
| `RescueTimeoutSmoker` | 2.0s |
| `RescueTimeoutHunter` | 3.0s |
| `RescueTimeoutJockey` | 3.0s |
| `RescueTimeoutCharger` | 2.0s |

### Tongue Rescue
| Variable | Default | Descripción |
|----------|---------|-------------|
| `TongueShoveRange` | 150 | Rango para shovear lengua |
| `ShootTongueRange` | 800 | Rango para disparar lengua |

### Dodge
| Variable | Default | Descripción |
|----------|---------|-------------|
| `SpitDodgeRange` | 300 | Distancia de huida de spit |
| `ChargerDodgeRange` | 400 | Distancia para dodge de charge |
| `DeathAcidDodgeRange` | 250 | Distancia de huida de ácido de muerte |

### Auto Grenades
| Variable | Default | Descripción |
|----------|---------|-------------|
| `TankNadeRange` | 800 | Rango para lanzar granada a tank |
| `TankNadeChance` | 0.25 | Probabilidad por tick vs tank |
| `HordeNadeRange` | 500 | Rango para lanzar granada a horda |
| `HordeNadeSize` | 10 | Mínimo de commons para granada |
| `HordeNadeChance` | 0.30 | Probabilidad por tick vs horda |
| `UsePipeBomb` | 3 | 0=no usar, 1=horde, 2=tank, 3=ambos |
| `UseMolotov` | 3 | 0=no usar, 1=horde, 2=tank, 3=ambos |
| `UseVomitjar` | 0 | 0=humans only (peligroso), 1=horde, 2=tank, 3=ambos |

### Fall Warp
| Variable | Default | Descripción |
|----------|---------|-------------|
| `FallWarpVelocity` | -750 | Umbral de velocidad vertical |
| `FallWarpDistance` | 500 | Máx distancia al compañero |

### Heal Interrupt
| Variable | Default | Descripción |
|----------|---------|-------------|
| `HealInterruptThreshold` | 50 | Health ≥ esto → cancelar heal |

### Item System
| Variable | Default | Descripción |
|----------|---------|-------------|
| `ItemPickupEnabled` | 1 | Bots recogen throwables del suelo |
| `ItemGiveEnabled` | 1 | Bots dan throwables a humanos |
| `ItemPickupRange` | 150 | Rango de pickup |
| `ItemGiveRange` | 200 | Rango para dar items |
| `ItemPickupCooldown` | 2.0 | Cooldown entre pickups |
| `MobSizeToThrow` | 6 | Mínimo de commons para tirar granada (config legacy) |

### Saferoom Door
| Variable | Default | Descripción |
|----------|---------|-------------|
| `DoorCloseRadius` | 400 | Rango de detección de puerta |
| `DoorCloseDelay` | 1.5 | Delay antes de cerrar |

---

## Debugging

Activar verbose logging:
```squirrel
// En sa_config.nut:
DebugEnabled = true
```

Esto mostrará en consola:
```
[SurvivorAI][SURVIVE] Bot 123: evading tank (dist: 150)
[SurvivorAI][NADE] Bot 125: throwing weapon_pipe_bomb at tank (dist: 450)
[SurvivorAI][DODGE] Bot 124: dodging spit burst (dir: perpendicular)
[SurvivorAI][TONGUE] Bot 126: shoving tongue off teammate 127 (dist: 80)
[SurvivorAI][WARP] Bot 128: warped to teammate (fatal fall prevented)
[SurvivorAI][ITEMS] Bot 129: gave weapon_molotov to human 130
[SurvivorAI][ITEMS] Bot 131: picking up weapon_pipe_bomb
```

---

## Event Handlers

El sistema usa una tabla registrada con `__CollectGameEventCallbacks`:

```squirrel
::SurvivorAI.Events <- { /* ... */ }
__CollectGameEventCallbacks(::SurvivorAI.Events)
```

Eventos escuchados (14 total):

| Evento | Propósito |
|--------|-----------|
| `round_start` | Cleanup + restart per-bot think |
| `round_end` | Cleanup state |
| `mission_lost` | Cleanup |
| `map_transition` | Anti-pipebomb bug |
| `player_spawn` | Entity cache |
| `player_death` | Entity cache |
| `player_hurt` | Cache (futuro uso) |
| `spit_burst` | Dodge state: guardar puddle position |
| `charger_charge_start` | Dodge state: guardar charge start |
| `charger_killed` | Dodge state: cleanup |
| `spitter_killed` | Dodge state: death acid position |
| `tongue_grab` | Tongue rescue state |
| `tongue_release` | Tongue rescue cleanup |
| `player_entered_checkpoint` | Door close flag (polling-based) |

---

## Integraciones

### Con MaoLib
- `MaoLib.AddTimer()` — Per-bot think timers
- `MaoLib.AddTimer()` — Throw fire/release timers
- `MaoLib.Probability()` — Auto nade chances
- `MaoLib.YieldSurvivors()` — StartPerBotThink
- `maolib_timers_cleanup` — Auto-cleanup en round_end/mission_lost/map_transition

### Con MaoLib.NavUtils
- `GetSafePosition()`: Valida navmesh + busca fallback si posición es inválida
- `IsNearFire()`: Evita ácido/fuego en pathfinding
- `HasLineOfSight()`: Para detección de amenazas via TraceLine

---

## Bugs Fixados (31 Mayo 2026)

### 1. TraceLine con 3 parámetros (CRÍTICO)
**Síntoma**: La detección de SI visibles (`ATTACK_SI`) nunca funcionaba.
**Causa**: `TraceLine(start, end, trace)` — 3 params, el engine espera 4.
**Fix**: `TraceLine(start, end, null, trace)`.

### 2. Botones forzados nunca se limpiaban (CRÍTICO)
**Síntoma**: Bots se quedaban shoveando/disparando indefinidamente.
**Causa**: `m_afButtonForced` bits nunca se limpiaban entre thinks.
**Fix**: Cleanup de `IN_ATTACK | IN_ATTACK2` al inicio de cada BotThink.

### 3. ThinkInterval demasiado agresivo (ALTO)
**Síntoma**: Spam "think takes too much time" en consola.
**Causa**: `ThinkInterval = 0.1` (10Hz) con escaneos de entidades cada frame.
**Fix**: Migrado a per-bot think a 0.25s (4Hz) + entity cache.

### 4. Method detachment en ExecuteCloseDoor (31 Mayo 2026)
**Síntoma**: `MaoLib.AddTimer` callback perdía `this`.
**Causa**: `AddTimer("name", 0.5, this.ExecuteCloseDoor)` — método detached.
**Fix**: Closure wrapper: `function() { ::SurvivorAI.ExecuteCloseDoor(...) }`.

### 5. Probability sin namespace (31 Mayo 2026)
**Síntoma**: Crash "the index 'Probability' does not exist".
**Causa**: `Probability(25)` en vez de `::MaoLib.Probability(25)`.
**Fix**: Namespace explícito en ambas llamadas.

### 6. foreach userid shadowing (31 Mayo 2026)
**Síntoma**: `userid` sobrescrito por loops foreach anidados.
**Causa**: `foreach (userid, si in ...)` dentro de función que ya tiene `userid`.
**Fix**: Renombrado a `siUid`, `tankUid`, `threatUid`, `chUid`.

---

## Limitaciones Conocidas

1. **Commons not cached**: Los common infected siguen escaneándose con `FindByClassnameWithin` porque no tienen eventos de spawn/death fiables.
2. **Force fire imperfecto**: `m_afButtonForced` + IN_ATTACK no siempre resulta en lanzamiento inmediato — depende del estado del bot.
3. **Tank Agro**: No garantizado al 100%.
4. **Dash Integration**: Placeholder. Requiere modificar dashing.nut para soportar bots.
5. **Item Sharing vía GiveItem**: Funciona para throwables; otros items no están soportados.
6. **Fall Warp**: SetOrigin directo es jarro pero previene muerte segura.
7. **vision.nut usa properties**: `VisionScan`, `IsChargerCharging`, etc. están definidas como properties en vez de métodos — funcional pero inconsistente.

---

## Referencia: Left 4 Bots 2

**Repo**: [smilz0/Left4Bots](https://github.com/smilz0/Left4Bots) (69★, 5+ años desarrollo)

### Features que L4B2 tiene y nosotros no (futuro roadmap):
| Característica | Prioridad | Estado |
|----------------|-----------|--------|
| Sistema de órdenes vía chat (follow, hold, lead) | 🟡 Media | No implementado |
| Settings externalizados + overrides por mapa | 🟡 Media | No implementado |
| Scavenge de gascans para finales | 🟢 Baja | No implementado |
| Flow distance para separación (vs euclidiana) | 🟡 Media | No implementado |
| Sistema de pausa (ceder control a vanilla AI) | 🟢 Baja | No implementado |

### Features implementadas (respecto a L4B2 reference):
| Feature | Status |
|---------|--------|
| Lanzamiento de granadas con target selection | ✅ Implementado |
| Pickup/Use failsafe | ✅ Implementado (items.nut) |
| Rescate de tongue/shove | ✅ Implementado |
| Dodge de spit/charge | ✅ Implementado |
| Per-bot think distribuido | ✅ Implementado |
| Anti-pipebomb bug | ✅ Implementado |
| Fall warp | ✅ Implementado |
| Saferoom door close | ✅ Implementado |

---

## Créditos

- **Inspiración GOAP**: Sistemas de IA modernos (F.E.A.R., The Sims)
- **Left 4 Bots 2**: Referencia principal para features de IA de bots
- **Bot Throw Grenade (kuro?bot)** : Referencia para sistema de items y lanzamiento
- **Implementación**: Nativo VScript, dependencias: MaoLib + MaoLib.NavUtils

---

## Changelog

### v2.0 (2026-05-31)
- **Nuevo:** Per-bot think via MaoLib timers (reemplaza info_target global)
- **Nuevo:** Tongue Rescue — SHOVE_TONGUE (98) + SHOOT_TONGUE (97)
- **Nuevo:** Event-driven dodge — spit burst, charger charge, death acid
- **Nuevo:** Fall Warp (prioridad 100) — previene muertes por caída
- **Nuevo:** Heal Interrupt — cancela med/defib si health ≥ 50
- **Nuevo:** Item system (`sa_items.nut`) — pickup, give, smart targeting
- **Nuevo:** Saferoom door close automático
- **Nuevo:** Anti-pipebomb bug en map_transition
- **Nuevo:** Auto nades con targeting por tipo (pipe→horde, molotov→tank, bile→humans)
- **Mejorado:** ExecuteThrowNade con SwitchToItem + forced fire + release
- **Mejorado:** Entity cache por eventos (mejor rendimiento, menos escaneos)
- **Corregido:** Method detachment en ExecuteCloseDoor
- **Corregido:** `Probability()` → `::MaoLib.Probability()` en detector
- **Corregido:** foreach `userid` shadowing en sa_detector.nut
- **Corregido:** Door check movido después de DetectTask

### v1.0 (2026-05-27)
- Versión inicial con think loop global, 4 prioridades, cache básico

---

*Last updated: 2026-05-31*
