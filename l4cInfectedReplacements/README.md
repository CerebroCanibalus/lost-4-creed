# l4cInfectedReplacements — "Ultra Gore System" v2.3

**Addon:** Lost 4 Creed — Gore & Infected Replacements  
**Author:** Lost 4 Creed Team  
**Entry Point:** `scripts/vscripts/director_base_addon.nut`  
**Dependencias:** MaoLib (l4cCoreAddon), l4cCustomInfected (lepotitsa/hound)  
**Tamaño:** ~876 líneas de VScript + texturas

---

## 📋 Descripción

Addon de gore extremo que implementa un sistema completo de desmembramiento, gibs y partículas de sangre. Reemplaza las vísceras vanilla con modelos de alta calidad y efectos visuales por hitgroup.

También carga **lepotitsa** y **hound** desde l4cCustomInfected con prioridad temprana para asegurar registro correcto de eventos.

---

## 🏗️ Estructura

```
director_base_addon.nut ← Sistema Ultra Gore (876 líneas)
├── Carga lepotitsa.nut (EARLY - prioridad de eventos)
├── Carga hound.nut (EARLY - prioridad de eventos)
└── ::GoreSystem completo
```

---

## 🩸 GoreSystem

**Namespace:** `::GoreSystem`

### Sistema de Gibs

| Propiedad | Límite |
|-----------|--------|
| Gibs totales máximos | 30 |
| Gibs por kill | 8 |
| Lifetime gibs | 3s (tank 5s) |
| Fuerza de lanzamiento | Variable por hitgroup |

### ParticleMap por Hitgroup

| Hitgroup | Partícula |
|----------|-----------|
| Head | Partículas de cráneo/ cerebro |
| Chest | Partículas de pecho |
| Arms | Partículas de brazo |
| Groin | Partículas de ingle |
| Back | Partículas de espalda |

### Dirección de Impacto

- **Front:** Partículas frontales
- **Back:** Partículas traseras con diferente ángulo

### Modelos de Gibs

- Brains, heart, steaks
- Betterbile (bilis mejorada)
- Bloodmap (mapeo de sangre)
- Boomer_exploded (explosión de boomer)
- rgib_p1, strider_brain

Con precache automático al inicio de ronda.

### Tank Treatment

- Más gibs que infectados normales
- Más fuerza en gibs
- Partículas extra especiales

### Eventos

| Evento | Acción |
|--------|--------|
| `round_start` | Precache de modelos y texturas |
| `player_hurt` | Partículas de sangre por hitgroup |
| `player_death` | Gibs y desmembramiento |
| `witch_killed` | Partículas especiales de witch |

### Cleanup

Limpieza periódica de gibs viejos para evitar acumulación.

---

## 🔧 Dependencias

| Addon | Relación |
|-------|----------|
| l4cCoreAddon | **REQUERIDO** — Provee MaoLib (usado indirectamente) |
| l4cCustomInfected | Proporciona lepotitsa.nut y hound.nut (cargados temprano) |

---

## ⚠️ Notas

1. **Prioridad de eventos:** Lepotitsa y Hound se cargan desde aquí EARLY para asegurar que sus eventos se registren antes que otros scripts
2. **Script único:** Todo el GoreSystem está en `director_base_addon.nut` (876 líneas)
3. **Patrón de eventos:** Usa `__CollectGameEventCallbacks(::GoreSystem)` — tabla dedicada
4. **Modelos:** Los gibs se almacenan en `materials/models/gibs/`

---

*Last updated: 2026-05-30*
