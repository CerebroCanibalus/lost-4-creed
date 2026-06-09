# l4cCustomInfected — "Infectados Custom" v2.3

**Addon:** Lost 4 Creed — Custom Infected  
**Author:** Lost 4 Creed Team  
**Entry Point:** `scripts/vscripts/director_base_addon.nut`  
**Dependencias:** MaoLib (l4cCoreAddon)  
**Tamaño:** ~3.2 MB (~12 archivos)

---

## 📋 Descripción

Añade infectados personalizados completamente nuevos que reemplazan specials existentes y agregan variedad a los comunes:

- **Leporitsa Berserker** → Reemplaza al Spitter
- **Hellhound** → Reemplaza al Jockey
- **3 tipos de Comunes Especiales** → Kamikaze, Corpse Eater, Sewer Worker

---

## 🏗️ Estructura

```
director_base_addon.nut
├── lepotitsa.nut              → Leporitsa Berserker (870 líneas)
├── hound.nut                   → Hellhound (424 líneas)
├── kamikaze_mob.nut            → Common Kamikaze (239 líneas)
├── corpse_mob.nut              → Common Corpse Eater (226 líneas)
├── sewer_mob.nut               → Common Sewer Worker (165 líneas)
├── kamikaze/common_anim_fix2.nut  → Fix animación kamikaze
├── corpse_eater/common_anim_fix4.nut → Fix animación corpse eater
└── sewer_worker/common_anim_fix5.nut → Fix animación sewer worker
```

---

## 🔥 Leporitsa Berserker

**Namespace:** `::LeporitsaBerserker`  
**Reemplaza:** Spitter  
**Spawn Chance:** 38%

Spitter transformado en un berserker cuerpo a cuerpo agresivo.

### Sistema de Furia

| Stack | Velocidad | Requisito |
|-------|-----------|-----------|
| Nivel 1 | +35% | Daño recibido |
| Nivel 2 | +70% | Más daño |
| Nivel 3 | +105% | Máxima furia |

### Habilidades

| Habilidad | Efecto |
|-----------|--------|
| **Golpe Demoledor** | Slow 35%, AoE 200u, 6 de daño |
| **Grito** | Stun 1.5s, radio 400u, cooldown 12s |

### Stats

| Stat | Valor |
|------|-------|
| HP | 4000 |
| Velocidad base | 100% |
| Velocidad furia máx | +105% |

---

## 🔥 Hellhound

**Namespace:** `::catbor_hellhound`  
**Reemplaza:** Jockey  
**Spawn Chance:** 42%

Jockey reemplazado por un perro infernal rápido y agresivo.

### Stats

| Stat | Valor |
|------|-------|
| HP | 400 |
| Velocidad | 1.75x normal |
| Velocidad (ardiendo) | 2.0x normal |
| Drop fire | Opcional (configurable) |

---

## 💥 Comunes Especiales

### Kamikaze Mob
**Namespace:** `::nanas_kamikaze`  
**Chance:** 60%

Common infected que explota al morir.

| Stat | Valor |
|------|-------|
| Daño de explosión | 25 |
| Radio | 350u |
| Chance dropear pipebomb | 45% |

### Corpse Eater
**Namespace:** `::nanas_corpse_eater`  
**Chance:** 35%

Common infected que sangra al golpear al jugador.

| Stat | Valor |
|------|-------|
| Daño de sangrado | 10 por tick |

### Sewer Worker
**Namespace:** `::nanas_sewer_worker`  
**Chance:** 30%

Common infected que aplica bile al golpear.

| Stat | Valor |
|------|-------|
| Probabilidad de bile | 1 de cada 3 golpes |

---

## 🔧 Dependencias

| Addon | Relación |
|-------|----------|
| l4cCoreAddon | **REQUERIDO** — Provee MaoLib (dependencia DURA, sin fallback) |

---

## ⚠️ Notas Críticas

1. **MaoLib es dependencia DURA:** No hay fallback. `l4cCoreAddon` debe cargar PRIMERO. Si MaoLib no está disponible, el script falla rápido con error visible — no hay modo zombie silencioso.
2. **Lepotitsa/Hound se cargan desde `l4cInfectedReplacements`:** Ese addon los carga temprano para prioridad de registro de eventos ANTES que GoreSystem.
3. **Animaciones:** Cada common custom tiene su propio fix de animación en subdirectorio
4. **Reemplazo:** Estos infectados REEMPLAZAN a los originales (Spitter → Leporitsa, Jockey → Hellhound)

---

*Last updated: 2026-05-30*
