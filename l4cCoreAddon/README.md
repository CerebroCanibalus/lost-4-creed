# l4cCoreAddon — "Núcleo del Sistema" v2.3

**Addon:** Lost 4 Creed — Core Engine  
**Author:** Lost 4 Creed Team  
**Entry Point:** `scripts/vscripts/director_base_addon.nut`  
**Dependencias:** Ninguna (es el proveedor de todas las dependencias)  
**Tamaño:** ~1.2 MB (~13 scripts activos)
**Survivor scripts:** Migrados a `l4cCoreSurvivorGameplay`

---

## 📋 Descripción

El corazón del modpack. Provee la librería central **MaoLib** (timers, VFX, pathfinding, utilidades), configura convars globales por modo de juego, y orquesta los sistemas de gameplay a través de **módulos encapsulados**. **Debe cargar PRIMERO** en el orden de VPKs — sin este addon, ningún otro funciona.

---

## 🏗️ Arquitectura Modular

### Entry Point

```
director_base_addon.nut
├── Librerías (4 archivos)
│   ├── maolib.nut                    → ::MaoLib (librería central + auto-carga submodulos)
│   ├── maolib_navutils.nut           → ::MaoLib.NavUtils (pathfinding A*)
│   ├── maolib_vfx.nut                → ::MaoLib_VFX (partículas, sonidos, efectos)
│   └── maolib_timers_cleanup.nut     → Cleanup automático de timers
│
├── Módulos Core (cargados por director_base_addon.nut)
│   ├── l4c_settings.nut              → Convars, densidad, cleanup
│   ├── bleeding.nut                  → Sangrado de infectados
│   ├── custom_glow_coop/versus.nut   → Glows (por modo de juego)
│   ├── l4c_acoustic_terror.nut       → Ruido atrae hordas (reemplaza gunshots_horde)
│   ├── ragdoll_magnitude.nut         → Magnitud de ragdolls
│   ├── sound_proxy_window.nut        → Proxies de sonido (ventanas)
│   ├── sound_proxy_prop.nut          → Proxies de sonido (props)
│   ├── item_crates.nut               → Cajas de items
│   ├── chch_crowpiles.nut            → Pilas de cuervos
│   ├── fallenspawn.nut               → Spawning de fallen/uncommon
│   ├── vscript_defib_ragdoll.nut     → Defibrilador + ragdoll
│   ├── eatpeople.nut                 → Comportamiento eating
│   ├── poltergeists.nut              → Eventos poltergeist
│   └── specialdoors.nut              → Puertas especiales
│
└── No cargados actualmente
    ├── itemfinales.nut               → Desactivado — pendiente migración a l4cMapRefresh
    └── gunshots_horde.nut            → Reemplazado por l4c_acoustic_terror
```

### Scripts de Survivor — Movidos a `l4cCoreSurvivorGameplay`

Los siguientes sistemas ya NO están en `l4cCoreAddon`. Se migraron a `l4cCoreSurvivorGameplay/scripts/vscripts/`:

| Módulo | Archivos Fusionados |
|--------|---------------------|
| `l4c_combat_fx.nut` | shove_gib + staggercancelfix + easy_item_ping_geeb + hgf + hvsc + lhvc |
| `l4c_combat_util.nut` | carryff + grab_warning |

**Scripts sueltos pendientes de migrar (origen en scripts sueltos):**
- `water_slowdown_reduction.nut` → Movimiento en agua (en l4cCoreSurvivorGameplay)
- `immersive_fall_dmg.nut` → Daño por caída con FX (en l4cCoreSurvivorGameplay)
- `grief.nut` → Second Chance system (en l4cCoreSurvivorGameplay)
- `tank_heal.nut` → Heal al matar tank (en l4cCoreSurvivorGameplay)
- `incap_warning.nut` → Alerta de incap (en l4cCoreSurvivorGameplay)
- `restore_crawlanim.nut` → Restaurar crawl (en l4cCoreSurvivorGameplay)
- `incap_pills.nut` / `incap_adrenaline.nut` → Usar items mientras incap (en l4cCoreSurvivorGameplay)
- `shoescuff.nut` / `ctsh.nut` / `ladder_sounds.nut` → Sonidos de paso (en l4cCoreSurvivorGameplay)
- `simple_first_person_timed_button.nut` → Cámara FP (en l4cCoreSurvivorGameplay)

**Eliminados:**
- `anti_bunnyhop.nut` — El bunnyhop es diversión pura 🐰

### Filosofía del Mergeo

- **Sin subcarpetas:** Todo permanece en `scripts/vscripts/`
- **Una tabla por módulo:** Cada módulo registra sus eventos vía `__CollectGameEventCallbacks(::L4C_Modulo)`
- **Scripts grandes = solos:** `fallen_spawn` (765 líneas), `defib_ragdoll` (967 líneas) permanecen como módulos individuales
- **Scripts pequeños = agrupados:** Settings, footstep sounds, FX se fusionan por categoría funcional
- **Sin mapas:** Scripts por mapa (`c1m4_`, `c2m5_`, etc.) se migran a `l4cMapRefresh`
- **Variables encapsuladas:** No más variables sueltas en `getroottable()`; todo vive dentro de la tabla del módulo

---

## 📚 Librerías Centrales (Intactas)

### MaoLib — `::MaoLib`

**Timers (SIEMPRE usar estos, NUNCA logic_timer)**

| Función | Descripción |
|---------|-------------|
| `AddTimer(name, interval, func)` | Registra timer |
| `AddTimerForce(name, interval, func)` | Sobrescribe si existe |
| `AddTimerSafe(name, interval, func)` | Con validación |
| `AddTimerAuto(name, interval, func)` | Auto-naming |
| `RemoveTimer(name)` | Elimina timer |
| `PauseTimer(name)` / `ResumeTimer(name)` | Pausa/Reanuda |
| `ClearAllTimers()` | Limpia todos los timers |

Auto-cleanup en `round_end`, `mission_lost`, `map_transition`.

**Iteradores**

```squirrel
foreach (s in MaoLib.YieldSurvivors()) { }
foreach (si in MaoLib.YieldSpecials()) { }
foreach (w in MaoLib.YieldWitches()) { }
foreach (p in MaoLib.YieldPlayers()) { }
```

**Entity Utils**

`GetScope(e)`, `IsReal(e)`, `IsAlive(e)`, `IsAlivePlayer(p)`, `IsEnabled(e)`, `GetAbility(p)`, `FileExists(p)`, `DistanceBetween(p1,p2)`, `Probability(25)`, `VectorAngle(dest)` → QAngle

**Witch & Target**

`SetWitchAnger(w, 0.5)`, `GetWitchAnger(w)`, `ForceTarget(e, target)`, `GetTarget(e)`

**Keys/Buttons (Force Input)**

`DisableKey(s,k)`, `EnableKey(s,k)`, `StartKey(s,k)`, `EndKey(s,k)`, `IsPressingKey(s,k)`

---

## 🧭 MaoLib.NavUtils — Pathfinding

**Namespace:** `::MaoLib.NavUtils`

| Función | Descripción |
|---------|-------------|
| `GetNearestNavArea(pos, maxDist, blocked)` | Área nav más cercana |
| `BuildPath(start, end, team)` | A* → array CNavArea |
| `GetPathDistance(path)` | Distancia total |
| `HasLineOfSight(start, end, ignoreEnt)` | Línea de visión |
| `CanSeeEntity(viewer, target)` | Visión ojo-a-ojo |
| `FindHighGround(center, radius)` | Terreno alto |
| `FindChokePoints(center, radius)` | Puntos estrechos |
| `FindHittableProps(center, radius)` | Props golpeables |
| `FindRockSpots(tank, survivors, R)` | Posiciones de roca |
| `AreSurvivorsGrouped(survivors, maxD)` | ¿Agrupados? |
| `FindMostVulnerableSurvivor(survivors)` | Más vulnerable |

---

## ✨ MaoLib_VFX — Efectos Visuales v2.2

**Namespace:** `::MaoLib_VFX`

### Partículas (Core)
| Función | Descripción |
|---------|-------------|
| `SpawnParticle(pos, effect, life, priority)` | Partícula en posición → handle |
| `SpawnParticleOnEntity(e, effect, attach, life, priority)` | Partícula en entidad |
| `SpawnTrail(e, trail, attach, priority)` | Trail sobre entidad → handle |
| `StopParticle(part, fade)` | Detener trail |

### Partículas Geométricas (v2.2)
| Función | Descripción |
|---------|-------------|
| `SpawnRing(center, radius, count, effect, opts)` | Anillo circular |
| `SpawnSpiral(center, opts)` | Espiral 3D ascendente |
| `SpawnWave(start, end, opts)` | Onda sinusoidal 2D |
| `SpawnCurve(start, end, opts)` | Arco Bézier cuadrático |
| `SpawnCircleFilled(center, radius, opts)` | Círculo macizo (sunflower) |

**Opciones:** `duration`, `expand`, `vertical`, `count`, `priority`, `effect`, etc.
**Retorno:** `array` de particle handles. Auto-cleanup incluido.

### Explosiones, Impactos, Decals
| Función | Descripción |
|---------|-------------|
| `SpawnExplosion(pos, size)` | Explosión visual ("small/medium/large") |
| `SpawnImpact(pos, normal, type)` | Impacto (blood, concrete, metal, etc.) |
| `SpawnDecal(pos, normal, type)` | Decal (blood, scorch, bullet, etc.) |

### Sonido y Screen
| Función | Descripción |
|---------|-------------|
| `EmitSound(entity, path, vol, pitch)` | Sonido desde entidad |
| `EmitSoundAt(pos, path, vol, pitch)` | Sonido en posición |
| `EmitSoundOnClient(player, path)` | Sonido solo para un jugador |
| `ScreenShake(pos, amp, freq, dur, R)` | Screen shake |
| `ScreenEffect(players, effect, dur)` | Efecto de pantalla (blood, mud, etc.) |

### Keyframes (v2.2)
| Función | Descripción |
|---------|-------------|
| `Keyframes.Animate(entity, prop, keyframes, dur)` | Animación por keyframes |
| `Keyframes.AnimateRing(particles, ctr, rad, dur, vert)` | Expansión de anillo (uso interno) |
| `Keyframes.LerpVector(a, b, t, ease)` | Interpola vectores con easing |
| `Keyframes.LerpFloat(a, b, t, ease)` | Interpola floats con easing |

**Easing:** `linear`, `easeInSine`, `easeOutSine`, `easeInOutSine`, `easeInQuad`,
`easeOutQuad`, `easeInOutQuad`, `easeOutBack`, `easeOutElastic`, `easeOutBounce`.

⚠️ **CRÍTICO:** NO usar `LookupBone` en "infected" (common infected). Usar `GetEffectPosition(entity)`.

### Utilidades
| Función | Descripción |
|---------|-------------|
| `GetEffectPosition(entity)` | Posición segura (EyePosition en players, GetOrigin en CI) |
| `SafeKill(entity, delay)` | Kill con validación y delay opcional |
| `IsValidPosition(pos)` | Verifica que no sea Vector(0,0,0) |
| `Init(cleanup_interval)` | Inicializa sistema (llamar en round_start). `Init(60)` = cleanup cada 60s |

### Budget
- `critical`: 8 partículas/segundo (explosiones, gameplay crítico)
- `gameplay`: 12/s (default — sangre, trails, debris)
- `ambient`: 4/s (humo, ambiente)
- Hard cap: **8 partículas/frame**

---

## ⚙️ Módulos de Gameplay

> ⚠️ **Nota sobre módulos listados:** Esta sección describe la arquitectura *planeada* del sistema modular. Varios módulos (`l4c_movement`, `l4c_fall_damage`, `l4c_incap`, etc.) fueron fusionados en otros archivos o migrados a `l4cCoreSurvivorGameplay`. Para ver la lista exacta de scripts cargados, consultar [`director_base_addon.nut`](#-orden-de-carga-en-director_base_addonnut).

### `l4c_settings.nut` — Configuración Base (~160 líneas)

| Origen | Función |
|--------|---------|
| `global_convars.nut` | Convars globales de gameplay |
| `item_density.nut` | Densidad de objetos en el mapa |
| `melee_range.nut` | Rango de melee (convar) |
| `viewroll.nut` | Roll de cámara (convar) |
| `l4c_entity_cleanup.nut` | Limpieza de entidades huérfanas |

**Tabla:** `::L4C_Settings`

---

### `l4c_movement.nut` — Movimiento y Física (~510 líneas)

| Origen | Función |
|--------|---------|
| `anti_bunnyhop.nut` | Limita velocidad en el aire |
| `water_slowdown_reduction.nut` | Reduce slow en agua |

**Tabla:** `::L4C_Movement`

---

### `l4c_fall_damage.nut` — Daño por Caída (~271 líneas)

| Origen | Función |
|--------|---------|
| `immersive_fall_dmg.nut` | Daño por caída con animaciones, screen shake, sonidos |

**Tabla:** `::L4C_FallDamage`

---

### `l4c_incap.nut` — Sistema de Incapacitación (~510 líneas)

| Origen | Función |
|--------|---------|
| `incap_warning.nut` | Alerta de incapacitación |
| `incap_pills.nut` | Pills mientras incapacitado |
| `incap_adrenaline.nut` | Adrenalina mientras incapacitado |
| `restore_crawlanim.nut` | Restaura animación de crawl |
| `tank_heal.nut` | Heal al equipo al matar tank |

**Tabla:** `::L4C_Incap`

---

### `l4c_grief.nut` — Friendly Fire y Warns (~400 líneas)

| Origen | Función |
|--------|---------|
| `grief.nut` | Friendly fire mechanics |
| `carryff.nut` | FF reduction durante charger carry |
| `grab_warning.nut` | Alerta de grabs |

**Tabla:** `::L4C_Grief`

---

### `l4c_combat_fx.nut` — Combate y FX Visuales (~680 líneas)

| Origen | Función |
|--------|---------|
| `shove_gib.nut` | Gibs al empujar |
| `staggercancelfix.nut` | Fix de stagger cancel |
| `easy_item_ping_geeb.nut` | Ping automático de items |
| `hgf.nut` | Healing green fade effect |
| `hvsc.nut` | Healing visual cue (azul) |
| `lhvc.nut` | Low health visual cue (rojo) |

**Bugfix incluido:** `hgf.nut` y `hvsc.nut` tenían la **misma tabla global** (`HEALING_GREEN_FADE_EFFECT`), causando que el segundo en cargar anulara al primero. En el módulo consolidado ambos efectos coexisten.

**Tabla:** `::L4C_CombatFX`

---

### `l4c_bleeding.nut` — Sangrado de Infectados (~95 líneas)

| Origen | Función |
|--------|---------|
| `bleeding.nut` | Sangrado de infectados |

**Tabla:** `::L4C_Bleeding`

---

### `l4c_fallen_spawn.nut` — Spawning de Fallen/Uncommon (~765 líneas)

| Origen | Función |
|--------|---------|
| `fallenspawn_.nut` | Spawning de fallen/uncommon infected |

**Tabla:** `::L4C_FallenSpawn`

---

### `l4c_eat_people.nut` — Comportamiento Eating (~47 líneas)

| Origen | Función |
|--------|---------|
| `eatpeople.nut` | Infected eating behavior |

**Tabla:** `::L4C_EatPeople`

---

### `l4c_gunshots_horde.nut` — Disparos Atraen Hordas (~206 líneas)

| Origen | Función |
|--------|---------|
| `gunshots_horde.nut` | Sistema de volumen acumulado que dispara hordas |

**Tabla:** `::L4C_GunshotsHorde`

---

### `l4c_sound_proxy.nut` — Proxies de Sonido (~202 líneas)

| Origen | Función |
|--------|---------|
| `sound_proxy_window.nut` | Proxies de sonido en ventanas |
| `sound_proxy_prop.nut` | Proxies de sonido en props |

**Tabla:** `::L4C_SoundProxy`

---

### `l4c_poltergeist.nut` — Eventos Poltergeist (~291 líneas)

| Origen | Función |
|--------|---------|
| `poltergeists.nut` | Eventos de poltergeist |

**Tabla:** `::L4C_Poltergeist`

---

### `l4c_special_doors.nut` — Puertas Especiales (~251 líneas)

| Origen | Función |
|--------|---------|
| `specialdoors.nut` | Puertas especiales |

**Tabla:** `::L4C_SpecialDoors`

---

### `l4c_crow_piles.nut` — Pilas de Cuervos (~556 líneas)

| Origen | Función |
|--------|---------|
| `chch_crowpiles.nut` | Pilas de cuervos |

**Tabla:** `::L4C_CrowPiles`

---

### `l4c_uncommons.nut` — Uncommon Infected (~267 líneas)

| Origen | Función |
|--------|---------|
| `chch_uncommons.nut` | Uncommon infected spawns |

**Tabla:** `::L4C_Uncommons`

---

### `l4c_item_crates.nut` — Cajas de Items (~301 líneas)

| Origen | Función |
|--------|---------|
| `item_crates.nut` | Cajas de items |

**Tabla:** `::L4C_ItemCrates`

---

### `l4c_event_alarm.nut` — Eventos de Alarma (~33 líneas)

| Origen | Función |
|--------|---------|
| `event_alarme.nut` | Eventos de alarma |

**Tabla:** `::L4C_EventAlarm`

---

### `l4c_glow.nut` — Glows Personalizados (~140 líneas)

| Origen | Función |
|--------|---------|
| `custom_glow_coop.nut` | Glow personalizado (coop) |
| `custom_glow_versus.nut` | Glow personalizado (versus) |

**Fusionados:** Branch-aware por modo de juego en una sola tabla.

**Tabla:** `::L4C_Glow`

---

### `l4c_defib_ragdoll.nut` — Defibrilador con Ragdoll (~967 líneas)

| Origen | Función |
|--------|---------|
| `vscript_defib_ragdoll.nut` | Lógica principal de defib ragdoll |
| `vscript_defib_ragdoll_think.nut` | Think del ragdoll de defib |

**Tabla:** `::L4C_DefibRagdoll`

---

### `l4c_ragdoll_magnitude.nut` — Magnitud de Ragdolls (~34 líneas)

| Origen | Función |
|--------|---------|
| `ragdoll_magnitude.nut` | Magnitud de ragdolls |

**Tabla:** `::L4C_RagdollMagnitude`

---

### `l4c_footstep_sounds.nut` — Sonidos de Paso (~200 líneas)

| Origen | Función |
|--------|---------|
| `shoescuff.nut` | Sonidos de paso adicionales |
| `ctsh.nut` | Sonidos de escalada |
| `ladder_sounds.nut` | Sonidos de escalera |

**Tabla:** `::L4C_FootstepSounds`

---

### `l4c_fp_camera.nut` — Cámara First-Person (~588 líneas)

| Origen | Función |
|--------|---------|
| `simple_first_person_timed_button.nut` | Cámara first-person timed |

**Tabla:** `::L4C_FPCamera`

---

## ⚙️ Configuración por Modo de Juego

Configurada en `director_base_addon.nut` antes de cargar módulos.

### Cooperativo
- 1 de cada Special Infected
- Crawl speed: 70
- Incap count: 1
- Max Specials: 5
- Stagger: 7.5s

### Versus
- Spitter limit: 2
- SI con penalidades versus
- Stagger: 2.5s

### Survival
- Incap count: 0
- Crawl speed: 50
- Stagger: 6s
- Rescue disabled

---

## 📦 Orden de Carga en `director_base_addon.nut`

```vscript
// 1. Librerías
IncludeScript("maolib", getroottable());
// maolib auto-carga: maolib_timers_cleanup, maolib_vfx

// 2. Modo de juego → setea convars + glows
//   coop   → custom_glow_coop
//   versus → custom_glow_versus + penalidades versus
//   survival → custom_glow_versus + rescue disabled

// 3. Módulos Core
IncludeScript("l4c_settings", getroottable());      // Convars, densidad, cleanup
IncludeScript("bleeding", getroottable());            // Sangrado de infectados

// 4. Ragdolls + FX
IncludeScript("vscript_defib_ragdoll", getroottable());  // Defibrilador + ragdoll
IncludeScript("ragdoll_magnitude", getroottable());       // Magnitud de ragdolls

// 5. Director + World
IncludeScript("l4c_acoustic_terror", getroottable());  // Ruido atrae hordas
IncludeScript("sound_proxy_window", getroottable());    // Proxies de sonido (ventanas)
IncludeScript("sound_proxy_prop", getroottable());      // Proxies de sonido (props)

// 6. Map Systems (pendientes migración a l4cMapRefresh)
// IncludeScript("itemfinales", getroottable());  // Desactivado
IncludeScript("item_crates", getroottable());          // Cajas de items
IncludeScript("chch_crowpiles", getroottable());        // Pilas de cuervos

// 7. Infected Rules
IncludeScript("fallenspawn", getroottable());           // Spawning de fallen/uncommon

// 8. Fun / Misc
IncludeScript("eatpeople", getroottable());             // Comportamiento eating
IncludeScript("poltergeists", getroottable());           // Eventos poltergeist
IncludeScript("specialdoors", getroottable());          // Puertas especiales

// 9. Survivor gameplay → l4cCoreSurvivorGameplay (se carga después)
```

---

## 🗺️ Scripts por Mapa — Migrados a `l4cMapRefresh`

Los siguientes scripts ya NO están en `l4cCoreAddon`. Se migran a `l4cMapRefresh` para mejor organización:

- `c1m4_atrium.nut`, `c1m4_atrium_finale.nut`
- `c2_fairgrounds_onslaught.nut`, `c2m4_barns_onslaught.nut`, `c2m4_barns_onslaught2.nut`, `c2m4_finale_onslaught.nut`, `c2m5_concert_finale.nut`
- `c3m4_plantation_finale.nut`
- `c4m5_milltown_escape_finale.nut`
- `c5m2_mob_from_front.nut`, `c5m5_bridge.nut`
- `c6m2_minifinale.nut`, `c6m3_port.nut`, `c6m3_port_finale.nut`, `c6m3_quiet.nut`
- `c7m1_docks.nut`, `c7m2_barge.nut`, `c7m3_port_finale.nut`
- `c8m3_sewers_coop.nut`, `c8m5_rooftop_finale.nut`
- `c9m1_alleys.nut`, `c9m1_minifinale.nut`, `c9m2_lots_finale.nut`
- `c10m3_church.nut`, `c10m3_church_minifinale.nut`, `c10m4_onslaught.nut`, `c10m5_houseboat_finale.nut`
- `c11m2_offices.nut` (coop, minifinale, onslaught, realism), `c11m3_garage.nut` (coop, minifinale, realism), `c11m4_onslaught.nut`, `c11m5_runway_finale.nut`
- `c12m5_cornfield_finale.nut`
- `c14m2_gauntlet.nut`, `c14m2_lighthouse_finale.nut`

---

## 🔧 Dependencias

| Addon | Relación |
|-------|----------|
| `l4cCoreAddon` | — Proveedor de MaoLib y módulos |
| Todos los demás l4c* | **REQUIEREN** este addon |

---

## ⚠️ Notas Críticas

1. **Orden de carga:** Este addon debe cargar PRIMERO (orden de VPKs determina orden de `director_base_addon.nut`)
2. **No uses eventos globales:** Todo va a tablas registradas con `__CollectGameEventCallbacks(tabla)`
3. **MaoLib NO tiene sistema de eventos propio:** `maolib_events.nut` fue eliminado (23/05/2026)
4. **Timer Manager:** Siempre usar `MaoLib.AddTimer*()` — NUNCA `logic_timer` o `AddThinkToEnt`
5. **Method Detachment:** Todo callback pasado a `AddTimer` o `ScriptedMode_AddUpdate` debe ser closure wrapper: `function() { Tab.Method(); }`
6. **Scope:** Variables en `getroottable()` via `IncludeScript`; NUNCA usar `DirectorScript.X` para variables propias

---

## 🗑️ Scripts Deprecados/Removidos

| Script | Razón |
|--------|-------|
| `extended_fall_death.nut` | Archivo vacío |
| `botimprovements.nut` | Reemplazado por `survivor_ai_overhaul` (ya no se carga) |
| `test_lsp.nut` | Archivo de testing, no para producción |
| Backups (`.bak`, `.backup`) | No se cargan en VPK |
| Todos los scripts `cXmY_*.nut` | Migrados a `l4cMapRefresh` |

---

## 📚 Script Functions Reference

> Nativas confirmadas por VDC Wiki + código fuente L4D2. Útil para scripting de addons dependientes.

### Core Entity
```vscript
entity.IsValid()           entity.Kill()
entity.GetClassname()      entity.GetOrigin()
entity.GetAngles()         entity.SetOrigin(pos)
entity.SetAngles(qangle)   entity.GetForwardVector()
entity.GetHealth()         entity.GetMaxHealth()
entity.SetHealth(n)        entity.SetMaxHealth(n)
entity.GetName()           entity.SetParent(other, attach="")
entity.GetModelName()      entity.GetEntityIndex()
entity.ApplyAbsVelocityImpulse(vec)
```

### Player (CTerrorPlayer extends CBaseCombatCharacter)
```vscript
player.IsPlayer()          player.IsSurvivor()
player.IsBot()             player.IsAlive()
player.GetHealthBuffer()   player.SetHealthBuffer(n)
player.EyePosition()       player.EyeAngles()
player.GetActiveWeapon()   player.GetZombieType()  // 1-8
player.Stagger(pos)        player.IsIncapacitated()
player.IsDominatedBySpecialInfected()
player.GetPlayerName()     player.GetPlayerUserId()
player.GetSurvivorSlot()   player.DropItem(classname)
player.GiveItem(name)      player.SwitchToItem(classname)
player.UseAdrenaline(sec)  player.Extinguish()
```

### Weapon (CTerrorWeapon)
```vscript
wep.Clip1()                wep.Clip2()
wep.GetMaxClip1()          wep.SetClip1(n)
wep.Reload()               wep.GiveDefaultAmmo()
```

### Director
```vscript
Director.GetGameMode()              Director.GetMapName()
Director.ResetMobTimer()            Director.ResetSpecialTimers()
Director.IsSinglePlayerGame()       Director.IsCoopMode()
Director.IsVersusMode()             Director.IsTankInPlay()
Director.GetCommonInfectedCount()   Director.GetRandomSurvivor()
Director.GetAveragedSurvivorSpan()  Director.GetAveragedSurvivorSpeed()
Director.HasAnySurvivorLeftSafeArea()
```

### NavMesh
```vscript
NavMesh.GetNearestNavArea(pos, maxDist, LOS, ground)
NavMesh.NavAreaBuildPath(start, end, goal, maxDist, team, ignoreBlockers)
NavMesh.GetNavAreasInRadius(center, radius, table)
NavMesh.GetAllAreas(table)          NavMesh.GetNavAreaCount()
NavMesh.FindNavAreaAlongRay(start, end, ignore)
```

### Visual / Sound
```vscript
ScreenShake(center, amp, freq, dur, radius, cmd, air)
ScreenFade(player, r, g, b, a, fadeTime, fadeHold, flags)
DebugDrawLine(s, e, r, g, b, zTest, dur)
DebugDrawBox(origin, min, max, r, g, b, alpha, dur)
EmitSoundOn(soundScript, entity)                        // 2 params
EmitAmbientSoundOn(sound, vol, soundlevel, pitch, ent)  // 5 params
EmitSoundOnClient(soundScript, player)
StopAmbientSoundOn(sound, entity)
StopSoundOn(soundScript, entity)
```

### Spawning / Utils
```vscript
SpawnEntityFromTable(classname, kv_table)   // → handle
SpawnEntityGroupFromTable(table)            // → bool
PrecacheEntityFromTable(table)              // → bool
PrecacheModel(filename)                     // → index
PrecacheSound(soundname)
GetPlayerFromUserID(userid)                 // → handle
EntIndexToHScript(index)                    // → handle
PlayerInstanceFromIndex(idx)                // → CTerrorPlayer
IsPlayerABot(player)                        // → bool
Time()                                      // → float
UniqueString(prefix="")                     // → string
RandomInt(min, max)                         // inclusive
RandomFloat(min, max)                       // inclusive
```

### Event Registration
```vscript
__CollectGameEventCallbacks(table)          // Registra OnGameEvent_*
RegisterScriptGameEventListener(eventName)  // Bajo nivel
```

### NetProps
```vscript
NetProps.GetPropType(ent, name)
NetProps.HasProp(ent, name)
NetProps.GetPropInt/Float/String/Vector/Entity(ent, name)
NetProps.SetPropInt/Float/String/Vector/Entity(ent, name, value)
```

---

*Last updated: 2026-05-30 — v2.3*
