# 📋 Lista de Descubrimientos y Correcciones — Actualización Agentes .md

**Fecha:** 2026-05-04  
**Sesión:** Diagnóstico y reescritura del sistema de linterna dinámica L4C  
**Archivos a actualizar:** `ellis.md`, `keith.md`

---

## 🔴 CORRECCIONES CRÍTICAS (Errores en documentación actual)

### 1. `__CollectGameEventCallbacks` SÍ ES NATIVO
**Estado actual:** Ambos .md dicen "NO EXISTE en nativo"  
**Realidad:** `__CollectGameEventCallbacks(table)` es nativo de L4D2 y funciona correctamente. Se usa en decenas de scripts del proyecto.  
**Acción:** Corregir en ambos archivos. Mover de "VSLib fantasmas" a "Nativo confirmado".

**Ubicaciones a corregir:**
- `ellis.md` línea 179: "`__CollectGameEventCallbacks(table)` // NO EXISTE en nativo"
- `keith.md` línea 103: "`__CollectGameEventCallbacks` NO existe en nativo"

---

## 🟡 ADICIONES NECESARIAS

### 2. `env_projectedtexture` — BUG CRÍTICO en L4D2
**Descubrimiento:** Wiki Source Entities confirma: *"Bug: Does not work at all in L4D2"* y *"Bug: Does not move correctly when parented in L4D2"*  
**Impacto:** Cualquier script que use `env_projectedtexture` está roto por diseño del engine.  
**Acción:** Agregar sección "Entidades rotas en L4D2" en ambos .md

### 3. `light_dynamic` — Parámetros correctos
**Descubrimientos wiki-verificados:**
- `_inner_cone`: **"Affects nothing. [Confirmed]"** — No tiene efecto
- `_cone = 0`: **NO es omnidireccional**. Es un spot muy concentrado (0 grados = láser). Valor recomendado: 25-45
- `brightness`: Wiki dice *"10 is probably much more than one will ever want"*. Valor mínimo visible: 5
- `spotlight_radius`: Controla el círculo en brushes. Valor muy bajo (40) = punto minúsculo. Recomendado: 200+
- `distance`: Debe sincronizarse con `r_flashlightfar` para consistencia visual

**Acción:** Agregar sección "light_dynamic — parámetros verificados" en ambos .md

### 4. `SetParent` + `SetParentAttachment` — Approach correcto para entidades móviles
**Descubrimiento:** El SourceMod original (SilverShot v2.34) usa `SetParent` + `SetParentAttachment` con attachment `"grenade"` para linternas dinámicas.  
**Ventaja:** El engine maneja el seguimiento automáticamente, sin necesidad de thinker per-frame.  
**Acción:** Agregar como patrón arquitectónico recomendado en ambos .md

### 5. `sb_flashlight` — Forzar linterna de bots
**Descubrimiento:** `Convars.SetValue("sb_flashlight", "1")` fuerza a los bots a mantener la linterna encendida.  
**Uso:** Esencial para modpacks oscuros donde los bots necesitan iluminación.  
**Acción:** Agregar a "Convars críticas" en ambos .md

### 6. Timer nativo sin `AddThinkToEnt`
**Descubrimiento:** Se puede usar `logic_timer` + `EntityOutputs.AddOutput` para polling periódico sin el overhead/inestabilidad de `AddThinkToEnt` con `info_target`.  
**Patrón:**
```squirrel
local timer = SpawnEntityFromTable("logic_timer", {
    targetname = "mi_timer",
    RefireTime = 0.5,
    spawnflags = 0
});
EntityOutputs.AddOutput(timer, "OnTimer", "!self", "RunScriptCode",
    "::MiTabla.MiFunc()", 0, -1);
DoEntFire("!self", "Enable", "", 0, null, timer);
```
**Acción:** Agregar como "Patrones VScript válidos" en `ellis.md`

### 7. No hay evento para tecla F (linterna)
**Descubrimiento:** L4D2 no emite evento de juego cuando un jugador enciende/apaga la linterna con la tecla F.  
**Solución:** Usar timer de polling (0.5s) leyendo `NetProps.GetPropInt(player, "m_fEffects") & 4`  
**Acción:** Documentar esta limitación en ambos .md

### 8. `player_team` event
**Descubrimiento:** Evento nativo útil para detectar cambios de equipo. Campos: `userid`, `team`, `oldteam`.  
**Uso:** Crear/destruir luces, ajustar permisos, etc. cuando un jugador cambia de equipo.  
**Acción:** Agregar a lista de eventos útiles en `ellis.md`

### 9. `EntityOutputs.AddOutput` como timer
**Descubrimiento:** Además de triggers, `EntityOutputs.AddOutput` funciona con cualquier entidad que emita outputs (incluyendo `logic_timer`).  
**Patrón documentado en `ellis.md` solo para triggers.** Expandir para timers.  
**Acción:** Actualizar sección de patrones en `ellis.md`

---

## 🟢 MEJORAS MENORES

### 10. `flashlight_flickering.nut` — Conflicto conocido
**Descubrimiento:** Modifica `r_flashlightbrightness` globalmente 20 veces/segundo, afectando a TODOS los jugadores.  
**Solución:** Usar `style = 6` en `light_dynamic` individual (flickering por entidad) en vez de convar global.  
**Acción:** Agregar como "Conflicto típico conocido" en `keith.md`

### 11. Attachment `"grenade"`
**Descubrimiento:** Existe en todos los modelos vanilla de superviviente. Es el attachment del cinturón.  
**Uso:** Ideal para `SetParentAttachment` de objetos que deben seguir al jugador.  
**Nota:** Modelos custom pueden no tenerlo.  
**Acción:** Agregar a lista de attachments útiles.

---

## 📁 ARCHIVOS DE REFERENCIA DE ESTA SESIÓN

- `FLASHLIGHT_DIAGNOSTICO_CRITICO.md` — Documentación completa del diagnóstico
- `l4cCoreVisuals/scripts/vscripts/l4c_dynamic_flashlight.nut` — Implementación v2.0
- `l4cCoreVisuals/scripts/vscripts/director_base_addon.nut` — Actualizado

---

## ✅ CHECKLIST DE ACTUALIZACIÓN

### ellis.md
- [ ] Corregir `__CollectGameEventCallbacks` (mover a nativo)
- [ ] Agregar sección "Entidades rotas en L4D2" (env_projectedtexture)
- [ ] Agregar sección "light_dynamic — parámetros verificados"
- [ ] Agregar patrón SetParent + SetParentAttachment
- [ ] Agregar patrón logic_timer + EntityOutputs.AddOutput
- [ ] Agregar limitación: "No hay evento para tecla F"
- [ ] Agregar evento player_team
- [ ] Agregar convar sb_flashlight
- [ ] Actualizar EntityOutputs.AddOutput para incluir timers

### keith.md
- [ ] Corregir `__CollectGameEventCallbacks` (mover a nativo)
- [ ] Agregar sección "Entidades rotas en L4D2"
- [ ] Agregar sección "light_dynamic — parámetros verificados"
- [ ] Agregar patrón SetParent + SetParentAttachment como approach válido
- [ ] Agregar conflicto típico: flickering global vs per-entidad
- [ ] Agregar attachments útiles (grenade, weapon_bone, flashlight)
- [ ] Agregar limitación: "No hay evento para tecla F"
