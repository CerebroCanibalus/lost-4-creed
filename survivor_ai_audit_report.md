# Survivor AI Audit Report — sa_* System

> **Fecha:** 2026-07-13 | **Sistema:** `sa_config/validator/vision/detector/executor/core/items` (7 módulos, ~2,850 líneas)

---

## ~~🔴 CRITICAL: Netprops que NO existen~~ (FIXED 2026-07-13)

### ~~`m_usingMedKit` / `m_usingDefibrillator` — sa_core.nut:59-60, 125-126~~
**FIX:** Heal Interrupt eliminado (vanilla ya lo maneja vía `sb_toughness`). Guard de `BotIncapThink` reemplazado con `m_reviveOwner > 0` (netprop real de DT_TerrorPlayer).

---

## 🟡 HIGH: Arquitectura

### Properties en vez de Methods — sa_vision.nut
```vscript
getroottable().SurvivorAI.VisionScan <- function(bot)  // ❌ property
```
VisionScan, IsChargerCharging, GetVisibleThreats, etc. son properties, no methods. Si se pasan como callback suelto → pierden `this`. Documentado como "known limitation" pero sigue siendo frágil.

### Limpieza duplicada en round_end
- `sa_core.nut` events: hace `Cleanup()` que vacía `BotLastCommandTime = {}`
- `sa_executor.nut` `SurvivorAI_Cleanup`: trata de iterar `BotLastCommandTime` pero ya está vacío → código muerto.

### Timer race en CloseDoor — sa_executor.nut:794
```vscript
MaoLib.AddTimer("close_door_" + userid, 0.5, function() { ... })
```
Timer nombrado por `userid`. Si un bot intenta cerrar 2 puertas (entrada+salida), segundo timer pisa al primero (AddTimer warning).

### `PI` y `IN_*` redefinidos — sa_config.nut:200-210
`PI` no existe en engine (bien definirlo). `IN_ATTACK`, `IN_ATTACK2`, etc. SÍ son built-in → redefinir es ruidoso e inofensivo, pero confunde al LSP.

---

## 🟡 MEDIUM: Gaps vs comunidad (quejas de usuarios)

| Queja | Estado | Nota |
|-------|--------|------|
| Bots curan con temp health alta | 🔴 ROTO | Heal Interrupt sin efecto |
| Bots reviven durante tank fight | ❌ Ausente | Sin priorización combat > revive |
| Bots no coronan/evitan Witch | ❌ Ausente | Zero witch awareness |
| Bots jalan armas de incapped | ❌ Ausente | Sin protección inventario |
| Bots se congelan con múltiples víctimas | 🟡 Parcial | Rescue itera pero sin priorización |
| Bots se agrupan muy junto | ❌ Ausente | Sin separación mínima entre bots |
| Bots miran fijo mientras SI mata | ✅ | Tongue rescue + Rescue task |
| Bots no esquivan fuego/ácido/rocks | ✅ | DODGE + SURVIVE tasks |
| Bots no tiran granadas | ✅ | Pipe→horda, Molotov→tank, Bile→humans |
| Bots stuck en geometría | ✅ | Unstick con spiral search |
| Bots no matan Charger a distancia | ✅ | Optimal range combat |
| Bots se separan demasiado | ✅ | Regroup si >600u |

**8.5/15 cubiertas.** El más doloroso: Heal Interrupt prometido pero roto.

---

## ✅ CONFIRMADO VÁLIDO (no alucinación)

| Item | Fuente |
|------|--------|
| `Entities.FindByClassnameNearest()` | LeeLand FAQ — método nativo CEntities |
| `GetZombieType() == 9` para survivors | VDC "Survivor = 9"; decrypted mutations lo usan |
| `spit_burst` event (params: userid, x, y, z, entid) | AlliedModders + VDC |
| `charger_charge_start` event (params: userid) | VDC L4D2 Game Events |
| `player_entered_checkpoint` (params: userid) | AlliedModders (múltiples plugins) |
| `m_hThrower` en `tank_rock` | VDC decrypted mutations |
| `m_customAbility`, `m_humanSpectatorUserID`, `m_pummelAttacker`, etc. | L4D2node SendTables |
| `tank_rock`, `prop_door_rotating_checkpoint`, `inferno` | Classnames L4D2 reales |
| `CommandABot()`, `SwitchToItem()`, `GiveItem()`, `EmitSoundOnClient()` | VDC Script Functions |

---

## 🔥 Factor "Wow" — vs Left 4 Bots 2

| Feature | L4B2 | Nosotros |
|---------|:----:|:--------:|
| Órdenes por voz/chat (follow, hold, lead) | ✅ | ❌ |
| Preferencias de armas por survivor | ✅ | ❌ |
| Scavenge gascans en finales | ✅ | ❌ |
| Flow distance pathfinding | ✅ | ❌ (Euclidiana) |
| Manejo de Witch | ✅ | ❌ |
| Priorizar combat sobre revive en tank | ✅ | ❌ |
| Bot difficulty settings | ✅ | ❌ |
| Bot personality / individual traits | ✅ | ❌ |
| Deadstop hunter/jockey | ✅ | ✅ |
| Auto-grenades configurables | ✅ | ✅ |
| Rescue de SI pins | ✅ | ✅ |
| Saferoom door close | ❌ | ✅ |
| Incap bleedout panic mode | ❌ | ✅ |
| Fall warp | ❌ | ✅ |
| Entity cache event-driven | ❌ | ✅ |

**Conclusión:** Sistema competente pero sin personalidad. Cumple "Minimal Intervention" pero no sorprende. Faltan capas de personalidad, órdenes, y contexto situacional (witch, flow, tank-priorities).

---

## Resumen de módulos

| Archivo | Líneas | Hallazgos |
|---------|:------:|-----------|
| `sa_config.nut` | 225 | PI/IN_* redefiniciones ruidosas |
| `sa_validator.nut` | 237 | ✅ Sólido |
| `sa_vision.nut` | 380 | ⚠️ Properties vs methods |
| `sa_detector.nut` | 826 | ✅ El módulo más completo |
| `sa_executor.nut` | 834 | 🔴 Heal Interrupt roto; ⚠️ timer race |
| `sa_core.nut` | 580 | 🔴 m_usingMedKit alucinado |
| `sa_items.nut` | 288 | ✅ Sólido |

**2 bugs críticos** (Heal Interrupt no funcional), **1 gap arquitectónico** (properties vs methods), **7 gaps vs comunidad** (witch, flow, commands, weapon prefs, revive-priority, multiple-victims, spacing).
