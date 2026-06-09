# ⚠️ CRÍTICO: Diagnóstico Flashlight Dinámico L4C

**Fecha:** 2026-05-04  
**Estado:** RESUELTO — Requiere reescritura completa  
**Archivos afectados:** `l4cCoreVisuals/scripts/vscripts/l4c_dynamic_flashlight.nut`

---

## 🔴 Problema Principal

La linterna dinámica (`light_dynamic`) **no aparece en absoluto** para bots supervivientes ni jugadores.

## 🔍 Causa Raíz

### 1. `env_projectedtexture` está ROTO en L4D2
> **Wiki Source Entities confirma:** *"Bug: Does not work at all in L4D2"*  
> **Además:** *"Bug: Does not move correctly when parented in L4D2"*

**Consecuencia:** El approach original basado en SourceMod con `.dll` que usaba `env_projectedtexture` es inviable. La versión VScript del Workshop (Ptprost) admite explícitamente problemas de estabilidad.

### 2. El script actual NO usa `SetParent` (error crítico de arquitectura)
El SourceMod original de SilverShot (v2.34) usa:
```sourcemod
SetVariantString("!activator");
AcceptEntityInput(entity, "SetParent", client);
SetVariantString("grenade");
AcceptEntityInput(entity, "SetParentAttachment");
```

**Nuestro script intenta** actualizar posición manualmente con `SetOrigin()` + `SetAngles()` cada 0.05s mediante un thinker `info_target`. Esto es:
- Inestable (el thinker puede no ejecutarse)
- Ineficiente (overhead de VScript per-frame)
- Roto (si el thinker falla, la luz se queda en `0,0,0` o en el spawn)

### 3. Parámetros incorrectos de `light_dynamic`

| Parámetro | Valor actual | Valor correcto | Justificación (Wiki) |
|-----------|-------------|----------------|---------------------|
| `brightness` | **0.25** | **5-10+** | *"10 is probably much more than one will ever want"* |
| `_inner_cone` | **30** | **0** (omitir) | *"Affects nothing. [Confirmed]"* |
| `_cone` | **45** | **0** | *"Set this to 0 to have the light cast in all directions"* |
| `distance` | **600** | **750-1500** | Debe coincidir con `r_flashlightfar` |
| `spotlight_radius` | **40** | **200+** | Controla el círculo en brushes |

### 4. Conflicto de múltiples sistemas
`director_base_addon.nut` carga simultáneamente:
- `l4c_dymlight.nut` (proyectiles)
- `l4c_dynamic_flashlight.nut` (linternas jugadores)
- `flashlight_flickering.nut` (parpadeo global de convars)

El parpadeo modifica `r_flashlightbrightness` globalmente, afectando la percepción de la luz.

---

## ✅ Solución Aprobada

### Approach: Parent-Based (sin thinker)
Basado en el SourceMod original de SilverShot:

1. **Crear `light_dynamic` por jugador**
2. **Parentear al jugador** con `SetParent` + `SetParentAttachment`
3. **Eliminar el thinker** — el engine maneja el seguimiento
4. **Usar eventos del juego** para encender/apagar (no polling)
5. **Brightness mínimo 5** para visibilidad

### Integración con MaoLib
```squirrel
IncludeScript("maolib", getroottable());
// Usar: MaoLib.YieldSurvivors(), IsAlive(), etc.
```

### Posición del attachment
El SourceMod usa `"grenade"` (attachment del cinturón). Alternativas:
- `"weapon_bone"` — sigue el arma activa
- `"flashlight"` — attachment específico de algunos modelos
- `"ValveBiped.Bip01_R_Hand"` — mano derecha (fallback)

---

## 📋 Checklist de Implementación

- [ ] Eliminar thinker `info_target` y lógica de polling
- [ ] Implementar `SetParent` + `SetParentAttachment`
- [ ] Ajustar parámetros: brightness=5, _cone=0, distance=1500
- [ ] Integrar MaoLib (`YieldSurvivors`, `IsAlive`)
- [ ] Agregar modelo `prop_dynamic` opcional (como SourceMod)
- [ ] Manejar `m_fEffects` bit 4 para detectar linterna vanilla
- [ ] Forzar `sb_flashlight 1` para bots
- [ ] Testing en campaña con bots

---

## 🚫 Cosas que NO funcionan en L4D2 (memorizado)

- `env_projectedtexture` — Bug del engine, no usar
- `_inner_cone` en `light_dynamic` — No tiene efecto
- Thinkers per-frame con `info_target` — Inestables
- `brightness < 1` — Invisible en entornos oscuros

---

**Referencia cruzada:** Ver `l4cCoreVisuals/scripts/vscripts/l4c_dynamic_flashlight.nut` línea 1 para comentario de existencia de este documento.
