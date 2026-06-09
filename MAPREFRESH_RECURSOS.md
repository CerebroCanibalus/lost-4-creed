# 🗺️ l4cMapRefresh — Catálogo de Recursos Externos

**Propósito:** Repositorio central de mods, scripts, plugins y datasets que podemos minar para extraer coordenadas, mecánicas de eventos y funcionalidades para portar a l4cMapRefresh VScript.

---

## 📦 NIVEL 1 — ORO PURO (Prioridad Máxima)

### 🔥 CyberZoio/l4d2-stripper-events
**Link:** https://github.com/CyberZoio/l4d2-stripper-events  
**Tipo:** Stripper cfg events  
**104 commits | 40+ eventos custom | Activo**

Eventos por campaña listos para portar a VScript:

| Campaña | Mapas con eventos | Tipos de eventos |
|---------|-------------------|------------------|
| **C1 Dead Center** | c1m1, c1m2, c1m3, c1m4 | Elevator crash, Lobby explosion+Tank, F18 bomber, Gas tanker explosion+Tank, Kappels alarm, Teleport bug fix |
| **C2 Dark Carnival** | c2m1, c2m2, c2m3, c2m4, c2m5 | Heli escape+Tank, C130 bomber, Car refuel event, Barn Tank, Coaster Scavenger, Rain weather |
| **C3 Swamp Fever** | c3m1, c3m2, c3m3, c3m4 | Scavenger Ferry, Aircraft crash+Tank, F18 bomber village |
| **C4 Hard Rain** | c4m1, c4m2, c4m3, c4m4, c4m5 | Truck crash, Scavenger Elevator, Gas tank explosion+Tank, Boat run |
| **C5 The Parish** | c5m1, c5m2, c5m3, c5m4, c5m5 | Restaurant alarm, C130 bomber+Tank, Bus passing, Scavenger Tractor |
| **C8 No Mercy** | c8m1, c8m2, c8m3, c8m4, c8m5 | Tank spawn door break, Car crash+Tank, Parachutist Tank, Scavenger Lift, Heli passing |
| **C9 Crash Course** | c9m1, c9m2 | Tank spawn, Howitzer explosion slow-mo |
| **C10 Death Toll** | c10m1-c10m5 | Tunnel block, Scavenger Bridge, Church guy→Tank, Scavenger Forklift |
| **C11 Dead Air** | c11m1-c11m5 | Hotel alarm, Tank spawn window break, Scavenger Van+Tank, Plane crash slow-mo, Rain weather |

**Formato datos:** Stripper cfg (Valve KeyValues). Coordenadas exactas de entidades.
**Valor para l4cMapRefresh:** Alto — eventos ya diseñados, solo extraer coordenadas y reimplementar lógica en VScript con MaoLib.

---

### 🔥 fbef0102/L4D2-Unlimited-Map
**Link:** https://github.com/fbef0102/L4D2-Unlimited-Map  
**Tipo:** Stripper cfg + VScript  
**5,216 líneas VScript | 100 commits | 18 stars**

Contiene:
- `anv_mapfixes.nut` (226 KB, 5,216 líneas) — modificaciones VScript para TODOS los mapas
- Stripper configs para cada campaña (c1-c14)
- Eventos únicos: Gun Shop Gas Event (C1M2), Emergency Door Event (C2M2), Holdout Event (C2M3), Ticket Cola Event (C2M4), Gas Event (C8M2)
- `Modify_` carpeta con utilidades: entity type fix, remove CSS weapons, remove ragdolls, remove junks, fix doors, immovable props, collision fixes, remove environmental sounds, etc.

**Plugins relacionados del mismo autor:**
- https://github.com/fbef0102/L4D1_2-Plugins — Spawn props, ladder editor, etc.
- https://github.com/fbef0102/Sourcemod-Plugins — Plugins SourceMod generales
- https://github.com/fbef0102/Game-Private_Plugin — Plugins privados

**Valor para l4cMapRefresh:** Muy Alto — VScript directamente usable como referencia de implementación.

---

### 🔥 Tsuey/L4D2-Community-Update (OFICIAL)
**Link:** https://github.com/Tsuey/L4D2-Community-Update  
**Workshop:** https://steamcommunity.com/sharedfiles/filedetails/?id=1959405608  
**Tipo:** VScript oficial de la comunidad  
**3,606 entidades | 11,173 líneas de código | Update oficial de Valve**

El update oficial de L4D2 mantenido por Tsuey, Jacob, Rayman1103 y contribuciones de Kerry Davis (Valve).

**Archivos clave:**
| Archivo | Propósito |
|---------|-----------|
| `mapspawn.nut` | Entry point — detecta mapa, ejecuta fixes |
| `anv_functions.nut` | Framework de funciones: make_clip, make_ladder, make_prop, make_brush, make_navblock, etc. |
| `anv_mapfixes.nut` | Fixes específicos por mapa (3,606 entidades) |
| `anv_maptrigs.nut` | Exploit/bug fixes por mapa |
| `anv_versus.nut` | Fixes exclusivos de Versus |
| `anv_tankwarps.nut` | Tank spawn warps para balance |
| `community/functions.nut` | Funciones compartidas |
| `community/maps/*.nut` | Scripts por mapa |

**Changelog completo con coordenadas EXACTAS:**
https://pastebin.com/EXkuvEc8 (16,000+ líneas, 321 KB)
Incluye setpos_exact para cada clip, ladder, LOS brush, prop, decal y trigger.

**Valor para l4cMapRefresh:** Extremadamente Alto — código oficial de referencia con coordenadas precisas.

---

## 📦 NIVEL 2 — REFERENCIAS PRIMARIAS

### jeremyvillanuevar/vscripts_custom (TADM ORIGINAL)
**Link:** https://github.com/jeremyvillanuevar/vscripts_custom  
**Tipo:** VScript framework  
**33 commits | 5 stars | Framework TADM completo**

**El repo ORIGINAL del que adaptamos l4cMapRefresh.** Contiene:
- `scriptedmode_addon.nut` — entry point (usado por TACM también)
- `amap.nut` — lógica de JetSetWilly II (Alternate Difficulties Mod)
- `hooks.nut` — event hooks
- `coop.nut` — scripted mode setup
- `modifydirector.nut` — balanceo por jugadores/dificultad
- `aspawns.nut`, `aent.nut`, `aindice.nut`, `atfunc.nut` — TADM core scripts
- VSLib completa

**Event descriptions detalladas para C1-C14 en el README:**

| Campaña | Eventos descritos |
|---------|------------------|
| **C1 Dead Center** | Elevator holdout 40s + SMG spawn; Bridge explosion + flying cars; Hittable for Tank |
| **C2 Dark Carnival** | Hittable early Tank; Plane crash + horde; Van explosion; Scavenge cans (6); Bomb event Tunnel of Love; Tank helicopter drop UNCHIPPABLE |
| **C3 Swamp Fever** | Scavenge Ferry (6 cans); Military tank fire; Blow up houses |
| **C4 Hard Rain** | Gas leak explosion; Scavenge Elevator (6 cans); Holdout event; Burning airplane Tank (unchippable 4s) |
| **C5 The Parish** | Kitchen alarm holdout; Keycard for CEDA trailer; Toxic waste barrels; Airstrike car drop; Scavenge Tractor (6 cans) |
| **C6-C14** | More events detailed per map |

**Valor para l4cMapRefresh:** Fuente original — nuestras tablas de datos (tADMIT, mST*, mSFET*, mEOCT*) vienen de aquí.

---

### spumer/left_4_dead_2__decompiled_maps
**Link:** https://github.com/spumer/left_4_dead_2__decompiled_maps  
**Tipo:** VMF decompiled maps  
**37 stars | TODOS los mapas L4D2**

Mapas oficiales decompilados a .vmf (Valve Map Format / Hammer Editor):
- c1m1-c1m4, c2m1-c2m5, c3m1-c3m4, c4m1-c4m5
- c5m1-c5m5, c6m1-c6m3, c7m1-c7m3, c8m1-c8m5
- c9m1-c9m2, c10m1-c10m5, c11m1-c11m5
- c12m1-c12m5, c13m1-c13m4, c14m1-c14m2

**Valor para l4cMapRefresh:** Útil para entender geometría exacta de mapas y planificar spawns de props/eventos.

---

### spumer/vscripts
**Link:** https://github.com/spumer/vscripts  
**Tipo:** VScripts decompilados  
**9 stars**

VScripts nativos de L4D2 decompilados (.nuc → .nut):
- `scriptedmode.nut` — implementación del sistema de scripted mode
- Otros nativos decompilados del juego

**Valor para l4cMapRefresh:** Referencia de cómo funciona scripted mode internamente.

---

## 📦 NIVEL 3 — STRIPPER REFERENCE

### Derpduck/L4D2-Comp-Stripper-Rework
**Link:** https://github.com/Derpduck/L4D2-Comp-Stripper-Rework  
**Tipo:** Stripper cfg competitivo  
**Rework completo desde cero**

Stripper configs competitivos con:
- `cfg/stripper/maps/*.cfg` — configs por mapa
- Entity templates en `_Templates/`
- Changelog detallado de cambios

### Tabbernaut/L4D2-Stripper
**Link:** https://github.com/Tabbernaut/L4D2-Stripper  
**Tipo:** Stripper cfg  
**3 stars**

Configs por mapa + exploit blocks.

### Tabbernaut/L4D2-Random
**Link:** https://github.com/Tabbernaut/L4D2-Random  
**Tipo:** Config competitivo con Stripper

Contiene `_config/cfgogl/random/stripper/maps/*.cfg` con modificaciones por mapa.

### Stripper:Source Guide (Workshop)
**Link:** https://steamcommunity.com/sharedfiles/filedetails/?id=3145349625  
**Tipo:** Guía  
**Guía completa de Stripper**

Cómo modificar mapas con Stripper:Source. Ejemplos prácticos.

---

## 📦 NIVEL 4 — SOURCEMOD PLUGINS ÚTILES

### fbef0102 L4D1_2-Plugins
**Link:** https://github.com/fbef0102/L4D1_2-Plugins  
**Plugins destacados:**

| Plugin | Función |
|--------|---------|
| `l4d2_spawn_props` | Spawnear任何 objeto y guardar a cfg |
| `l4d2_ladder_editor` | Clonar y crear nuevas escaleras |

### Plugins de terceros (AlliedModders)
| Plugin | Link | Función |
|--------|------|---------|
| Footlocker Spawner | https://forums.alliedmods.net/showthread.php?p=1471101 | Auto-spawn footlockers |
| Mini Gun Spawner | https://forums.alliedmods.net/showthread.php?p=1622557 | Auto-spawn miniguns |
| Ammo Pile Spawner | https://forums.alliedmods.net/showthread.php?p=1993580 | Spawn ammo piles |
| Weapon Spawn | https://forums.alliedmods.net/showthread.php?p=2008483 | Spawn armas fijas |
| Weapon Crate | https://forums.alliedmods.net/showthread.php?p=2008482 | Weapon crates |
| Laser Box Spawner | https://forums.alliedmods.net/showthread.php?t=223012 | Laser sight boxes |
| Melee Weapon Spawner | https://forums.alliedmods.net/showthread.php?t=223020 | Melee spawn |
| Upgrade Pack Spawner | https://forums.alliedmods.net/showthread.php?t=223021 | Upgrade packs |
| Gun Cabinet | https://forums.alliedmods.net/showthread.php?t=222931 | Gun cabinets |
| Health Cabinet | https://forums.alliedmods.net/showthread.php?t=175154 | Health cabinets |
| Respawn Rescue Closet | https://forums.alliedmods.net/showthread.php?p=2009851 | Rescue closets |

---

## 📦 NIVEL 5 — WORKSHOP ITEMS

### Community Fixes and Improvements
**Link:** https://steamcommunity.com/sharedfiles/filedetails/?id=1186253777  
**Tipo:** Workshop addon  
Bug fixes y mejoras para L4D2 vanilla.

### Community Update Testing Initiative (Workshop mirror)
**Link:** https://steamcommunity.com/sharedfiles/filedetails/?id=1959405608  
**Tipo:** Workshop addon  
Mirror del Community Update en Workshop.

---

## 🗺️ MAPA DE CAMPAÑAS — Cobertura de Recursos

| Campaña | CyberZoio | Unlimited-Map | TADM (jeremy) | Community Update | TACM |
|---------|-----------|---------------|---------------|------------------|------|
| **C1 Dead Center** | ✅ 4 mapas | ✅ | ✅ | ✅ | ✅ 595 ent |
| **C2 Dark Carnival** | ✅ 5 mapas | ✅ | ✅ | ✅ | ✅ 561 ent |
| **C3 Swamp Fever** | ✅ 4 mapas | ✅ | ✅ | ✅ | ✅ |
| **C4 Hard Rain** | ✅ 5 mapas | ✅ | ✅ | ✅ | ✅ |
| **C5 The Parish** | ✅ 5 mapas | ❌ | ✅ | ✅ | ✅ 456 ent |
| **C6 The Passing** | ❌ | ❌ | ❌ | ✅ | ✅ |
| **C7 The Sacrifice** | ❌ | ❌ | ❌ | ✅ | ✅ |
| **C8 No Mercy** | ✅ 5 mapas | ✅ | ✅ | ✅ | ✅ 406 ent |
| **C9 Crash Course** | ✅ 2 mapas | ✅ | ❌ | ✅ | ✅ |
| **C10 Death Toll** | ✅ 5 mapas | ✅ | ✅ | ✅ | ✅ |
| **C11 Dead Air** | ✅ 5 mapas | ❌ | ✅ | ✅ | ✅ |
| **C12 Blood Harvest** | ❌ | ✅ | ✅ | ✅ | ✅ |
| **C13 Cold Stream** | ❌ | ❌ | ❌ | ✅ | ✅ |
| **C14 The Last Stand** | ❌ | ✅ | ❌ | ✅ | ✅ |

---

## 🎯 GUÍA DE EXTRACCIÓN

### Prioridades para portar a VScript

1. **🔴 INMEDIATO** — Bugs críticos de l4cMapRefresh (itemfinales.nut crashes)
2. **🔴 INMEDIATO** — Integrar itemfinales.nut al sistema de carga
3. **🟡 ALTA** — Portar eventos de CyberZoio a VScript (empezar por C1, C2, C8)
4. **🟡 ALTA** — Extraer coordenadas del Pastebin (16k líneas)
5. **🟡 ALTA** — Implementar mapas fantasma (c2m3, c5m1-c5m4, c8m4)
6. **🟢 MEDIA** — Portar eventos de Unlimited-Map (Gas Event, Holdout, etc.)
7. **🟢 MEDIA** — Implementar weather dinámico (CreateRainArea, CreateMistArea)
8. **🟢 MEDIA** — Añadir soporte multi-modo (mutations, realism)
9. **🔵 BAJA** — Portar scavenge events (cans, cola, gas)
10. **🔵 BAJA** — Implementar Tank spawns dinámicos con cutscenes

### Formato de extracción recomendado

```vscript
// Ejemplo: coord desde CyberZoio / Community Update
// Evento: C1M1 Elevator Crash
// Origen: CyberZoio c1m1_hotel-CALL-LEFT-ELEVATOR-CRASH
::MapRefresh.c1m1_Events <- [
    {
        name = "elevator_crash",
        trigger = "relay_left_elevator",
        type = "holdout",
        duration = 40,
        horde = true,
        tank = false,
        specials = false,
        description = "Left elevator breaks, must use right elevator"
    },
    {
        name = "lobby_explosion_tank",
        trigger = "lobby_explosion_relay",
        type = "tank_spawn",
        tank_unchippable = false,
        description = "Explosion in lobby activates Tank"
    }
]
```

---

*Última actualización: 3 Jun 2026*
