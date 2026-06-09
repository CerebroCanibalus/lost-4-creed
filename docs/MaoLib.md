# MaoLib — Auditoría de APIs y Plan de Modernización

**Fecha:** 3 Junio 2026  
**Fuente:** L4D2node (vscript.l4d2node.org) — 22 clases, 369 métodos, 166 constantes extraídos del binario L4D2  
**Código analizado:** MaoLib (~1154L), MaoLib_VFX (~1059L), MaoLib.NavUtils (~583L), MaoLib.Modifiers, MaoLib.AoE, MaoLib.Input, MaoLib.HUD, MaoLib.StatusEffects, MaoLib.Cooldowns, MaoLib.PlayerState  
**Total scripts cliente de MaoLib en el codebase:** ~20 archivos .nut

---

## Resumen Ejecutivo

| Categoría | Count |
|-----------|-------|
| 🔴 Crítico (seguridad/estabilidad) | 3 |
| 🟡 Alto valor (nuevos natives) | 25+ |
| 🟢 Optimizaciones de código | 5 |
| 🆕 Nuevas capacidades posibles | 7 |
| 🗑️ Deprecable (solapante) | 2 |

---

## 🔴 CRÍTICO — Intervención Inmediata

### 1. `compilestring()` en `DelayCall()` — RCE Vector

**Archivo:** `maolib.nut` L719  
**Código:**
```squirrel
// DelayMonitor — ejecuta código arbitrario
compilestring( "return " + selfScope.func )()
```

**Riesgo:** El string `func` se pasa desde `DelayCall("stringCode", delay)`. Si alguien inyecta código malicioso en ese string, `compilestring` lo ejecuta. Aunque los scripts son first-party, es mal patrón.

**Usos activos en el codebase (todos con strings):**
| Script | Línea | Código |
|--------|-------|--------|
| `smoker_system.nut` | 546 | `MaoLib.DelayCall("SmokerSystem.CleanupChargeSprite(" + idx + ")", 0.5)` |
| `system_movement.nut` | 445 | `MaoLib.DelayCall("::SystemMovement.Tactical.SettingsLog()", 0.3)` |
| `rotpi.nut` | 32 | `MaoLib.DelayCall(function() { ... })` ⚠️ ¡Este pasa closure! |

**Nota:** `rotpi.nut` pasa closure, NO string. Pero `DelayCall` guarda `func` como string en script scope y luego hace `compilestring("return " + func)()` — si `func` es una closure, `compilestring` falla silenciosamente porque no puede serializar una closure a string. **Este callback NUNCA se ejecuta.**

✅ **Solución:**
```squirrel
// Nuevo DelayCall con closure seguro
function DelayCall(callback, delay) {
    local name = "delaycall_" + UniqueString()
    AddTimer(name, delay, function() {
        try { callback() } catch(e) { /* log */ }
        RemoveTimer(name)
    })
    return name
}
```

---

### 2. `compilestring()` en `GetOptions()` — Config RCE

**Archivo:** `maolib.nut` L688  
**Código:**
```squirrel
function GetOptions( path ) {
    local file = FileToString( path )
    // ... sanitización de caracteres ...
    return compilestring( "return " + file )();  // ¡Compila el archivo!
}
```

**Riesgo:** Aunque hay sanitización de caracteres, el patrón es inherentemente peligroso. Cualquier bug en la sanitización permite ejecución de código arbitrario.

✅ **Solución:** Migrar a formato JSON nativo o usar formato KeyValues de Valve con parser manual.

---

### 3. `AddThinkToEnt()` en `AddMonitor()` — Patrón Frágil

**Archivo:** `maolib.nut` L371  
**Código:**
```squirrel
local relay = SpawnEntityFromTable( "info_target", { } )
AddThinkToEnt( relay, name )  // Sobrescribible por cualquier otro AddThinkToEnt
```

**Riesgo:** Cualquier script que llame `AddThinkToEnt` con la misma entidad sobreescribe el think anterior. Además, `info_target` es una entidad vacía que satura el engine.

**Usos activos de AddMonitor (5 scripts):**
| Script | Propósito |
|--------|-----------|
| `witch_system.nut` | Monitoreo de props de witch |
| `tankaim.nut` | Think de tank AI |
| `poltergeists.nut` | Físicas de poltergeist |
| `specialdoors.nut` | Puertas especiales |
| `hunter_system.nut` | Hunter lead behavior |

✅ **Solución:** Migrar todos los `AddMonitor` a `MaoLib.AddTimer` con guards de entidad viva.

---

## 🟡 ALTO VALOR — Nativos que MaoLib no aprovecha

### Director (CDirector) — 56 métodos, MaoLib usa ~5

| Función Nativa | Firma | Reemplaza | Prioridad |
|---------------|-------|-----------|-----------|
| `GetRandomSurvivor()` | → hscript | `YieldSurvivors()` + RandomInt | 🟡 Alta |
| `GetHighestFlowSurvivor()` | → hscript | Flow calc manual | 🟡 Alta |
| `GetLowestFlowSurvivor()` | → hscript | Flow calc manual | 🟡 Alta |
| `GetClosestSurvivor(pos, alive?, infected?)` | V→ hscript | `DistanceBetween` loops | 🟡 Alta |
| `GetCommonInfectedCount()` | → int | `Entities.FindByClassname` count | 🟡 Alta |
| `GetPendingMobCount()` | → int | No existe en MaoLib | 🟡 Media |
| `IsTankInPlay()` | → bool | NetProps checks | 🟡 Alta |
| `HasAnySurvivorLeftSafeArea()` | → bool | Iteración manual | 🟡 Alta |
| `AreAllSurvivorsInBattlefield()` | → bool | No existe | 🟡 Media |
| `IsAnySurvivorInCombat()` | → bool | No existe | 🟡 Media |
| `GetTimeSinceSpecialZombieKilled(type)` | int→float | No existe | 🟢 Baja |
| `ForceNextStage()` | → void | Finale scripting | 🟢 Baja |
| `WarpAllSurvivorsToBattlefield()` | → void | Evento de crescendo | 🟢 Baja |
| `RegisterForbiddenTarget(entity)` | → void | Target blacklist | 🟡 Media |
| `UnregisterForbiddenTarget(entity)` | → void | Target blacklist | 🟡 Media |
| `GetAveragedSurvivorSpeed()` | → float | Ya se usa | ✅ |
| `GetAveragedSurvivorSpan()` | → float | Ya se usa | ✅ |

### CTerrorPlayer — 50 métodos, MaoLib usa ~8 vía NetProps

| Función Nativa | Firma | Reemplaza NetProps | Prioridad |
|---------------|-------|-------------------|-----------|
| **`IsStaggering()`** | → bool | `m_isStaggering` | 🔴 Alta |
| **`IsOnFire()`** | → bool | `m_isBurning` | 🔴 Alta |
| **`IsHangingFromLedge()`** | → bool | `m_isHangingFromLedge` | 🟡 Alta |
| **`IsDominatedBySpecialInfected()`** | → bool | NetProps | 🟡 Alta |
| `IsIT()` | → bool | Bile state tracking | 🟡 Alta |
| `IsAdrenalineActive()` | → bool | Timer tracking | 🟡 Alta |
| `GetAliveDuration()` | → float | Timer tracking | 🟡 Alta |
| `GetButtonMask()` | → int | `MaoLib.Input` timer | 🟡 Alta |
| `GetHealthBuffer()` | → float | `m_healthBuffer` | 🟡 Alta |
| `GetActiveWeapon()` | → hscript | FindByClassname + owner | 🟡 Alta |
| **`Stagger(Vector)`** | → void | Implementaciones custom | 🔴 Alta |
| **`UseAdrenaline(float)`** | → void | Simulaciones manuales | 🟡 Alta |
| **`SetHealthBuffer(float)`** | → void | NetProps | 🟡 Alta |
| `ReviveByDefib()` | → void | No existe | 🟢 Baja |
| `ReviveFromIncap()` | → void | No existe | 🟢 Baja |
| `DropItem(name)` | → void | Entity spawn | 🟡 Media |
| `GiveItem(name)` | → void | SpawnEntityFromTable | 🟡 Media |
| `GiveUpgrade(id)` | → void | No existe | 🟡 Media |
| `RemoveUpgrade(id)` | → void | No existe | 🟢 Baja |
| `TryGetPathableLocationWithin(radius)` | → Vector | No existe | 🟡 Media |
| `GetLastKnownArea()` | → hscript | No existe | 🟡 Media |
| `GetZombieType()` | → int | `m_zombieClass` | 🟡 Alta |
| `SnapEyeAngles(QAngle)` | → void | NetProps | 🟡 Media |
| `GetPlayerUserId()` | → int | Ya se usa | ✅ |
| `EyeAngles()` / `EyePosition()` | → QAngle/Vector | Ya se usa | ✅ |
| `IsSurvivor()` | → bool | Ya se usa | ✅ |

### CBaseEntity — 53 métodos (nuevos relevantes)

| Función Nativa | Firma | Beneficio | Prioridad |
|---------------|-------|-----------|-----------|
| **`TakeDamage(dmg, type, attacker)`** | (float,int,hscript) | Daño nativo para AoE | 🔴 Alta |
| **`TakeDamageEx(...)`** | (7 params) | Daño avanzado | 🟡 Media |
| **`OverrideFriction(duration, value)`** | (float,float) | Fricción temporal nativa | 🔴 Alta |
| **`SetContext(name, val, duration)`** | → void | Entity KV store | 🟡 Alta |
| **`GetContext(name)`** | → unknown | Lectura de contexto | 🟡 Alta |
| **`SetContextNum(name, val, duration)`** | → void | Versión numérica | 🟡 Alta |
| `SetFriction(float)` | → void | Fricción directa | 🟡 Media |
| `SetGravity(float)` | → void | Gravedad directa | 🟡 Media |
| `GetCenter()` | → Vector | World center | 🟢 Baja |
| `PrecacheModel(model)` | → int | Precaching nativo | 🟡 Media |
| `PrecacheScriptSound(sound)` | → void | Precaching nativo | 🟡 Media |
| `ConnectOutput(output, func)` | → void | Entity outputs a script | 🟡 Media |
| `DisconnectOutput(output, func)` | → void | Remover output | 🟢 Baja |

### CBaseAnimating — 24 métodos

| Función Nativa | Firma | Beneficio | Prioridad |
|---------------|-------|-----------|-----------|
| **`SetModelScale(scale, duration)`** | (float,float) | Escala animada | 🟡 Alta |
| `LookupAttachment(name)` | → int | ID de attachment | 🟡 Media |
| `GetAttachmentOrigin(id)` | → Vector | Posición attachment | 🟡 Media |
| `GetAttachmentAngles(id)` | → QAngle | Ángulos attachment | 🟡 Media |
| `SetBodygroup(id, value)` | → void | Model customization | 🟡 Media |
| `LookupBone(name)` | → int | ID de hueso | 🟡 Media |
| `GetBoneOrigin(id)` | → Vector | Posición de hueso | 🟡 Media |
| `IsSequenceFinished()` | → bool | Estado animación | 🟢 Baja |

### CEntities — 11 métodos

| Función Nativa | Firma | Beneficio | Prioridad |
|---------------|-------|-----------|-----------|
| **`FindByClassnameNearest(class, pos, radius)`** | → hscript | Búsqueda optimizada | 🟡 Alta |
| `FindByNameNearest(name, pos, radius)` | → hscript | Búsqueda optimizada | 🟢 Baja |
| `FindInSphere(null, pos, radius)` | → hscript | Iteración radial | 🟡 Media |

### CNavMesh — 20 métodos

| Función Nativa | Firma | Reemplaza | Prioridad |
|---------------|-------|-----------|-----------|
| **`GetNavAreasFromBuildPath(table, start, end, goal, maxDist, team, blockers)`** | → bool | `BuildPath()` manual + GetParent loop | 🔴 Alta |
| **`NavAreaTravelDistance(start, end, maxDist)`** | → float (-1 si fail) | `GetPathDistance()` manual | 🟡 Alta |
| `GetAreasWithAttributes(bits, table)` | → void | Filtro manual | 🟡 Media |
| `FindNavAreaAlongRay(start, end, ignoreID)` | → hscript | LOS area finding | 🟡 Media |
| `RegisterAvoidanceObstacle(entity)` | → void | Obstáculos dinámicos | 🟡 Media |
| `GetObstructingEntities(table)` | → void | Obstáculos existentes | 🟢 Baja |

### TerrorNavArea — 67 métodos

| Función Nativa | Firma | Reemplaza | Prioridad |
|---------------|-------|-----------|-----------|
| **`IsBottleneck()`** | → bool | `IsChokePoint()` size manual | 🔴 Alta |
| `FindRandomSpot()` | → Vector | Random point en área | 🟡 Media |
| `GetPlayerCount(team)` | → int | Player count en área | 🟡 Media |
| `IsCleared(player)` | → bool | Estado cleared | 🟡 Media |
| `MarkAsDamaging(duration)` | → void | Daño área nativo | 🟡 Media |
| `GetCorner(id)` | → Vector | Puntos esquina | 🟢 Baja |
| `IsPotentiallyVisibleToTeam(team)` | → bool | Visibilidad avanzada | 🟡 Media |
| `IsCompletelyVisibleToTeam(team)` | → bool | Visibilidad avanzada | 🟡 Media |
| `GetDoor()` | → hscript | Puertas en área | 🟢 Baja |
| `GetElevator()` | → hscript | Ascensores | 🟢 Baja |
| `GetTimeSinceCleared()` | → float | Timing | 🟢 Baja |

### CTerrorWeapon — 10 métodos

| Función Nativa | Firma | Prioridad |
|---------------|-------|-----------|
| `Clip1()` / `Clip2()` | → int | 🟡 Media |
| `GetDefaultClip1()` / `GetDefaultClip2()` | → int | 🟢 Baja |
| `GetMaxClip1()` / `GetMaxClip2()` | → int | 🟢 Baja |
| `SetClip1()` / `SetClip2()` | → void | 🟢 Baja |
| `Reload()` | → bool | 🟢 Baja |
| `GiveDefaultAmmo()` | → void | 🟡 Media |

### Convars — 4 métodos

| Función Nativa | Firma | Prioridad |
|---------------|-------|-----------|
| `SetValue(name, value)` | → void | 🟡 Media |
| `GetFloat(name)` | → float | 🟢 Baja |
| `GetStr(name)` | → string | 🟢 Baja |
| `GetClientConvarValue(name, entindex)` | → string | 🟢 Baja |

---

## 🟢 OPTIMIZACIONES — Código más eficiente

### 1. `startswith()` usa regexp (maolib.nut L255-260)

```squirrel
// ACTUAL — regexp pesado, desproporcionado para prefix check
function startswith(str, pattern) {
    local pm = regexp("^" + pattern)
    local result = pm.search(str)
    return result != null && ("begin" in result)
}

// OPTIMIZADO — string slicing (~10-50x más rápido)
function startswith(str, prefix) {
    if (prefix.len() > str.len()) return false
    return str.slice(0, prefix.len()) == prefix
}
```

**Impacto:** Bajo (solo se usa en config I/O). Pero el regexp es desproporcionado.

### 2. `Replace()` usa regexp (maolib.nut L444-458)

```squirrel
// ACTUAL — recrea el regexp en cada iteración del loop
function Replace(str, pattern, replacement) {
    for (; true; ) {
        local pm = regexp(pattern)  // ← recreado cada iteración
        local result = pm.search(str)
        if (result == null) break
        str = str.slice(0, result.begin) + replacement + str.slice(result.end, str.len())
    }
    return str
}

// OPTIMIZADO — regexp creado una vez
function Replace(str, pattern, replacement) {
    local pm = regexp(pattern)  // ← una sola vez
    for (; true; ) {
        local result = pm.search(str)
        if (result == null) break
        str = str.slice(0, result.begin) + replacement + str.slice(result.end, str.len())
    }
    return str
}
```

**Impacto:** Medio si se usa en loops grandes con muchos replaces.

### 3. `YieldSpecials()` filtra desde todos los players (maolib.nut L113-127)

```squirrel
// ACTUAL — itera 8 survivors + 4 SI = 12 iteraciones para 4 resultados
function YieldSpecials() {
    foreach(player in YieldPlayers()) {
        if (player.IsSurvivor()) continue
        yield player
    }
}

// OPTIMIZADO — itera solo infected (classname "infected")
function YieldSpecials() {
    for(local si = null; si = Entities.FindByClassname(si, "infected");) {
        if (si && si.IsValid()) yield si
    }
}
```

**Impacto:** Medio. Reduce iteraciones ~60% para obtener SI.

### 4. `LookupAttachment()` por ID numérico en VFX

```squirrel
// ACTUAL — SetParent con string de attachment
particle.SetParent(entity, attachment)  // attachment = string

// OPTIMIZADO — LookupAttachment devuelve int (más rápido)
local attID = entity.LookupAttachment(attachment)
if (attID > 0) particle.SetParent(entity, attID)
```

**Impacto:** Bajo. SetParent con int vs string es marginalmente más rápido.

### 5. `FindByClassnameWithin` + `DistanceBetween` manual en AoE

```squirrel
// ACTUAL — FindByClassnameWithin usa bounding box, necesita filtro extra
while (ent = Entities.FindByClassnameWithin(ent, className, origin, radius)) {
    local dist = (ent.GetOrigin() - origin).Length()
    if (dist > radius) continue  // Filtro manual
}

// MEJOR — FindByClassnameNearest es más preciso
local ent = Entities.FindByClassnameNearest(className, origin, radius)
```

**Impacto:** Alto para el caso de búsqueda del nearest. Las iteraciones con `FindByClassnameWithin` son correctas para múltiples resultados.

---

## 🆕 NUEVAS CAPACIDADES POSIBLES

### 1. Entity Context System

```squirrel
// Wrapper sobre SetContext/GetContext/SetContextNum nativos
// Más robusto que script scope (no requiere ValidateScriptScope)
// Persiste mientras la entidad exista

MaoLib.SetEntityContext(entity, "key", "value", -1)  // -1 = forever
MaoLib.GetEntityContext(entity, "key")                // → "value"
MaoLib.SetEntityContextNum(entity, "key", 42, -1)    // Numérico
MaoLib.ClearEntityContext(entity, "key")
```

**Reemplazaría:** Parte de `MaoLib.PlayerState` para datos asociados a entidad.

### 2. Native Damage Wrapper (para MaoLib.AoE)

```squirrel
// Wrapper sobre TakeDamage nativo
MaoLib.ApplyDamage(target, damage, type, attacker) {
    target.TakeDamage(damage, type, attacker)
}
```

### 3. Native Stagger Wrapper

```squirrel
// Wrapper sobre Stagger(Vector) nativo de CTerrorPlayer
MaoLib.StaggerPlayer(player, fromOrigin) {
    player.Stagger(fromOrigin)
}
```

### 4. Native Item Giving

```squirrel
MaoLib.GiveItem(player, "weapon_rifle_m60")
MaoLib.GiveUpgrade(player, UPGRADE_LASER_SIGHT)
MaoLib.GiveAmmo(player, 100)
MaoLib.DropItem(player, "weapon_pistol")
```

### 5. Native Pathfinding (NavUtils upgrade)

```squirrel
// Alternativa nativa a BuildPath manual
MaoLib.NavUtils.BuildPathNative(startNav, endNav, team = 3) {
    local areas = {}
    if (NavMesh.GetNavAreasFromBuildPath(areas, startNav, endNav, endNav.GetCenter(), 0, team, false)) {
        return areas  // Tabla llena directamente por el engine
    }
    return null
}

MaoLib.NavUtils.TravelDistance(startNav, endNav, maxDist = 0) {
    return NavMesh.NavAreaTravelDistance(startNav, endNav, maxDist)
}
```

### 6. Native Input Wrapper

```squirrel
// Alternativa a MaoLib.Input polling con GetButtonMask() nativo
MaoLib.GetPlayerButtons(player) {
    return player.GetButtonMask()
}
MaoLib.IsButtonPressed(player, button) {
    return (player.GetButtonMask() & button) != 0
}
```

### 7. Native Adrenaline/HealthBuffer

```squirrel
MaoLib.UseAdrenaline(player, duration) {
    player.UseAdrenaline(duration)
}
MaoLib.SetTempHealth(player, amount) {
    player.SetHealthBuffer(amount)
}
MaoLib.GetTempHealth(player) {
    return player.GetHealthBuffer()
}
```

---

## 🗑️ DEPRECABLE — Funcionalidad solapante

### AddMonitor (maolib.nut L338) — SOLAPANTE CON AddTimer

**Análisis de uso real (5 scripts activos):**

| Script | ¿Reemplazable por AddTimer? | Dificultad |
|--------|---------------------------|------------|
| `witch_system.nut` | Sí — `AddTimer` + guard de entidad viva | Baja |
| `tankaim.nut` | Sí — `AddTimer` + guard de tank vivo | Baja |
| `poltergeists.nut` | Sí — `AddTimer` + guard de player vivo | Baja |
| `specialdoors.nut` | Sí — `AddTimer` + guard de entidad | Baja |
| `hunter_system.nut` | Sí — `AddTimer` + guard de hunter | Baja |

**Conclusión:** `AddMonitor` NO aporta valor sobre `AddTimer` porque:

1. **NO tiene auto-cleanup real** — El `info_target` spawneado NO se destruye cuando la entidad monitoreada muere. El think sigue ejecutándose con un relay huérfano.
2. **Spawnea entidades innecesarias** — Cada monitor crea un `info_target` que satura el engine.
3. **Usa `AddThinkToEnt` frágil** — Sobrescribible por cualquier otro script.
4. **Es más complejo** — Requiere `RemoveMonitor` explícito, script scope management, etc.
5. **AddTimer es superior** — Sin entidades, closures nativas, single `logic_timer` central.

✅ **Acción:** Deprecar `AddMonitor`. Migrar los 5 usos activos a `AddTimer`. Mantener `AddMonitor` como wrapper legacy que internamente use `AddTimer`.

### DelayCall (maolib.nut L736) — SOLAPANTE CON AddTimer (ONE-SHOT)

`DelayCall` es un `AddMonitor` que se ejecuta una vez y se auto-destruye. Es exactamente un `AddTimer` de una ejecución.

✅ **Acción:** Reemplazar con `AddTimer` + auto-remove pattern:
```squirrel
MaoLib.AddTimer("delay_x", 0.5, function() {
    callback()
    MaoLib.RemoveTimer("delay_x")
})
```

---

## 📊 PLAN DE ACCIÓN POR FASES

### Fase 1 — Crítica (Seguridad y Estabilidad)
| # | Tarea | Archivos afectados | Esfuerzo | Riesgo |
|---|-------|-------------------|----------|--------|
| 1 | Eliminar `compilestring` de `DelayCall` → closures | `maolib.nut` + 3 scripts | 2h | 🔴 Ninguno si se hace bien |
| 2 | Eliminar `compilestring` de `GetOptions` → JSON/KeyValues | `maolib.nut` | 3h | 🟡 Cambio de formato de config |
| 3 | Migrar AddMonitor a wrapper sobre AddTimer | `maolib.nut` + 5 scripts | 4h | 🟡 Requiere test de cada script |

### Fase 2 — Alto Valor (Nuevos Natives)
| # | Tarea | Archivos afectados | Esfuerzo |
|---|-------|-------------------|----------|
| 4 | Agregar `TakeDamage()` wrapper en `MaoLib.AoE` | `maolib_aoe.nut` | 1h |
| 5 | Agregar `Stagger()` wrapper nativo | `maolib.nut` o `maolib_aoe.nut` | 0.5h |
| 6 | Agregar `GetNavAreasFromBuildPath()` en NavUtils | `maolib_navutils.nut` | 1h |
| 7 | Agregar `IsBottleneck()` → `NavUtils.IsBottleneck()` | `maolib_navutils.nut` | 0.5h |
| 8 | Agregar `OverrideFriction()` en Modifiers | `maolib_modifiers.nut` | 1h |
| 9 | Agregar `GetButtonMask()` wrapper en Input | `maolib_input.nut` | 0.5h |
| 10 | Agregar `Director` wrappers (GetRandomSurvivor, etc.) | `maolib.nut` | 1h |
| 11 | Agregar `CTerrorPlayer` wrappers (IsOnFire, IsStaggering, etc.) | `maolib.nut` | 1h |

### Fase 3 — Optimizaciones
| # | Tarea | Esfuerzo |
|---|-------|----------|
| 12 | Optimizar `startswith()` → string slicing | 0.2h |
| 13 | Optimizar `Replace()` → regexp cacheado | 0.3h |
| 14 | Optimizar `YieldSpecials()` → directo de "infected" | 0.3h |
| 15 | `LookupAttachment()` por ID numérico en VFX | 0.5h |

### Fase 4 — Nuevas Capacidades
| # | Tarea | Esfuerzo |
|---|-------|----------|
| 16 | Entity Context wrapper (SetContext/GetContext) | 1h |
| 17 | Native item giving (GiveItem, GiveUpgrade, GiveAmmo) | 1h |
| 18 | Native adrenaline (UseAdrenaline, SetHealthBuffer) | 0.5h |
| 19 | `FindByClassnameNearest` wrapper | 0.3h |

---

## 📋 CHECKLIST DE SCRIPTS A MIGRAR

### AddMonitor → AddTimer (5 scripts)
- [ ] `witch_system.nut` — `AddMonitor(prop, "witchprops_monitor", ...)`
- [ ] `tankaim.nut` — `AddMonitor(tank, "tankaim_monitor", ...)`
- [ ] `poltergeists.nut` — `AddMonitor(player, "poltergeists_physmonitor", ...)`
- [ ] `specialdoors.nut` — `AddMonitor(special, "specialdoors_monitor", ...)`
- [ ] `hunter_system.nut` — `AddMonitor(hunter, "hunter_lead", ...)`

### DelayCall string → closure (3 scripts)
- [ ] `smoker_system.nut` L546 — string → closure
- [ ] `system_movement.nut` L445 — string → closure
- [ ] `rotpi.nut` L32 — pasa closure pero DelayCall lo trata como string (BUG: nunca ejecuta)

---

## ANÁLISIS DETALLADO: AddMonitor vs AddTimer

### ¿Qué hace AddMonitor?

```squirrel
AddMonitor(entity, name, func, opts):
  1. Spawnea info_target (entidad vacía)
  2. Asocia name→info_target en script scope de entity
  3. Asocia name→func en script scope del info_target
  4. Guarda opts en script scope del info_target
  5. AddThinkToEnt(info_target, name)  ← think periódico
```

**La función `func` recibe:**
- `self` = el `info_target` (no la entidad original)
- Opciones vía `selfScope.optsName` (script scope del relay)

### ¿Qué hace AddTimer?

```squirrel
AddTimer(name, interval, callback):
  1. NO spawnea entidades
  2. Almacena {callback, interval, nextRun, active} en tabla `Timers`
  3. Un solo logic_timer central ejecuta todos los callbacks
```

**El callback recibe:**
- Solo los parámetros que le pases en la closure
- Sin entidades intermedias

### Comparativa Directa

| Aspecto | AddMonitor | AddTimer |
|---------|-----------|----------|
| **Entidades** | Spawnea 1 `info_target` por monitor | 0 entidades |
| **Mecanismo** | `AddThinkToEnt` (frágil) | `logic_timer` (engine-managed) |
| **Auto-cleanup** | ❌ No (info_target huérfano si entidad muere) | ❌ No (hay que llamar RemoveTimer) |
| **Asociación a entidad** | ✅ Por nombre en script scope | ❌ Global por nombre |
| **Paso de opciones** | Via script scope del relay | Via closure |
| **Seguridad** | `compilestring` en DelayMonitor | Closures nativas |
| **Complejidad** | Alta (info_target, scope management) | Baja (solo closure) |
| **Rendimiento** | Una entidad más en el engine | 0 entidades extra |
| **Resistencia a overwrites** | Baja (AddThinkToEnt) | Alta (logic_timer) |

### Veredicto

**AddMonitor es COMPLETAMENTE SOLAPANTE con AddTimer y además INFERIOR en todos los aspectos.**

La única funcionalidad que AddMonitor ofrece y AddTimer no tiene es la **asociación nombre→entidad** (saber qué monitor pertenece a qué entidad). Pero esto se soluciona con una simple convención de nombres:
```squirrel
AddTimer("hunter_lead_" + hunter_entindex, 0.1, callback)
// vs
AddMonitor(hunter, "hunter_lead", callback)  // asociación implícita
```

La diferencia es puramente cosmética. La tabla `Timers` de AddTimer es igualmente consultable.

**Acción recomendada:** 
1. Mantener `AddMonitor` como wrapper legacy que internamente cree un `AddTimer` con nombre basado en entindex
2. Marcar como `@deprecated`
3. Migrar los 5 usos activos gradualmente
