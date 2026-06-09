# l4cHordeMusic — "Música de Horda (Zombat)" v2.3

**Addon:** Lost 4 Creed — Horde Music & Mob Rules  
**Author:** Lost 4 Creed Team  
**Entry Point:** `scripts/vscripts/director_base_addon.nut`  
**Dependencias:** MaoLib (l4cCoreAddon) — indirecta  
**Tamaño:** ~8 MB (~9 archivos)

---

## 📋 Descripción

Addon de música de horda "Zombat" que añade nuevos instrumentos de horda y revisa las reglas de mobs del Director. La cantidad de comunes necesarios para activar la música dinámica de ataque escala con la dificultad.

---

## 🏗️ Estructura

```
director_base_addon.nut
├── scripts/vscripts/revised_mob_rules.nut  ← Reglas de mob escaladas
└── sound/music/
    ├── terror/mobrules.wav                 ← Reglas de mob
    └── zombat/                             ← 8 tracks de zombat:
        ├── gatesofhell.wav
        ├── horde_01.wav  ...  horde_04.wav
        └── snare_horde_01.wav ... snare_horde_04.wav
```

---

## 📜 Scripts

### `revised_mob_rules.nut` — Mob Rules Escaladas

**Namespace:** `::RevisedMobRules`

Ajusta el convar `music_dynamic_attack_CI_num` según la dificultad:

| Dificultad | Comunes para activar música |
|------------|---------------------------|
| Easy | 22 |
| Normal | 15 |
| Advanced | 12 |
| Expert | 8 |

**Eventos:**
- `player_connect_full` → Configura inicial
- `difficulty_changed` → Reconfigura al cambiar dificultad

⚠️ **Nota:** Usa `__CollectEventCallbacks` (API antigua, de VSLib). **Pendiente migrar a `__CollectGameEventCallbacks`** con tabla dedicada para eliminar dependencia de VSLib y evitar conflictos de eventos.

---

## 🎵 Contenido de Audio

### Zombat (8 tracks)
- `gatesofhell.wav` — Tema principal de horda intensa
- `horde_01.wav` a `horde_04.wav` — Variantes de horda
- `snare_horde_01.wav` a `snare_horde_04.wav` — Redobles de tambor

### Mob Rules
- `mobrules.wav` — Audio de reglas de mob

---

## 🔧 Dependencias

| Addon | Relación |
|-------|----------|
| l4cCoreAddon | Indirecta — MaoLib mencionado pero el script no lo usa directamente |

---

## ⚠️ Notas

- Usa `__CollectEventCallbacks` (patrón antiguo VSLib — pendiente migrar a `__CollectGameEventCallbacks`)
- Solo 1 script funcional + 9 assets de audio
- Las reglas de mob escalan automáticamente al cambiar dificultad en el lobby

---

*Last updated: 2026-05-30*
