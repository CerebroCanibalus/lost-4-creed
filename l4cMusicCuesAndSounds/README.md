# l4cMusicCuesAndSounds — "Banda Sonora Completa" v3.0

**Addon:** Lost 4 Creed — Music, Cues & Sound Effects  
**Author:** Lost 4 Creed Team  
**Entry Point:** `scripts/vscripts/mapspawn_addon.nut`  
**Dependencias:** MaoLib (vía l4cCoreAddon)  
**Tamaño:** ~200+ archivos de audio

---

## 📋 Descripción

La banda sonora completa del modpack Lost 4 Creed. Incluye temas de terror para witch, tank, finales, hordas, música de campaña, UI, sonidos de impacto, y efectos especiales.

También incluye un fix de cámara lenta al perder ronda (por Nescius).

---

## 🏗️ Estructura

```
mapspawn_addon.nut (entry point)
├── l4c_music_tracks.nut     ← Catálogo de tracks custom
├── l4c_music_core.nut       ← Core: estados, crossfade, prioridad, cooldowns
└── l4c_music_events.nut     ← Handlers de game events (registra callbacks)

sound/
├── music/
│   ├── custom/              ← 🔥 TUS TRACKS CUSTOM AQUÍ (directorio plano)
│   ├── l4d2/                ← Temas PC de campañas (c1_pc.mp3 a c5_pc.mp3)
│   ├── pzattack/            ← 6 tracks de ataque SI (reemplazos vanilla)
│   ├── safe/                ← Safe room (reemplazos vanilla)
│   ├── tank/                ← 3 tracks (reemplazos vanilla)
│   ├── terror/              ← Tracks generales (reemplazos vanilla)
│   ├── the_end/             ← Finales (reemplazos vanilla)
│   ├── witch/               ← 14+ tracks witch (reemplazos vanilla)
│   ├── zombiechoir/         ← 7 tracks coro zombie (reemplazos vanilla)
│   ├── tags/                ← Left 4 Death Hit (reemplazos vanilla)
│   ├── undeath/             ← death, leftfordeath (reemplazos vanilla)
│   ├── unalive/             ← themonsterswithin (reemplazos vanilla)
│   ├── flu/concert/         ← The Passing (reemplazos vanilla)
│   └── flu/jukebox/         ← The Passing (reemplazos vanilla)
├── player/                  ← damage1-2, jumplanding1-4
├── physics/                 ← Impactos (concreto, metal, arena, baldosa, madera)
├── items/                   ← itempickup.wav
├── ui/                      ← buttonclick, menu_accept/back/focus/invalid
└── animation/               ← Explosiones de finales (bridge_destruct, plantation, etc.)
```

---

## 🎵 Catálogo Musical

### Música por Campaña
| Archivo | Campaña |
|---------|---------|
| `c1_pc.mp3` | Dead Center |
| `c2_pc.mp3` | Dark Carnival |
| `c3_pc.mp3` | Swamp Fever |
| `c4_pc.mp3` | Hard Rain |
| `c5_pc.mp3` | The Parish |

### Special Infected (PZ Attack)
| Track | Tema |
|-------|------|
| asphyxiation | Smoker |
| contusion | — |
| enzymicide | Spitter |
| eviscerator | — |
| incapacitator | — |
| recompense | — |

### Tank (3 tracks)
taank, tank, tank_metal

### Witch (14+ tracks)
lost_little_witch, angry_little_witch, psychowitch, witchencroacher, witchroast, y más.

### Finales
- final nail, skin on our teeth, snowball in hell, your own funeral

### Otros
- Zombie Choir (7 tracks con variantes L4D1)
- Coro zombie estéreo
- Safe room: "The Monsters Without"

---

## 🎵 L4C VScript Music Manager v1.0

Sistema VScript que reproduce **tracks custom** durante eventos del juego.
Los tracks van en `sound/music/custom/` (directorio plano — todos los .wav juntos).

### Archivos del Sistema

| Archivo | Rol |
|---------|-----|
| `mapspawn_addon.nut` | Entry point — carga los 3 módulos |
| `l4c_music_tracks.nut` | Catálogo de tracks por categoría (`::L4C_Music.Tracks`) |
| `l4c_music_core.nut` | Core: crossfade, prioridad, cooldowns, estados |
| `l4c_music_events.nut` | Handlers de ~12 game events + registro de callbacks |

### Namespace: `::L4C_Music`

| Propiedad | Tipo | Descripción |
|-----------|------|-------------|
| `Debug` | int | 0=silencio, 1=info, 2=verbose |
| `CurrentState` | STATE enum | SAFE, AMBULATORY, COMBAT, BOSS, DEATH, SILENCE |
| `CurrentPriority` | int | Prioridad del track actual |
| `TriggerEvent(cat, prio, cd)` | function | Punto de entrada único |

### Eventos Implementados (11)

| ID | Evento | Gatillo | Prioridad |
|----|--------|---------|-----------|
| E01 | HordeTrack | create_panic_event (30% prob) | HIGH |
| E02 | LastManStanding | 3 survivors muertos, 1 alive | CRITICAL |
| E03 | DefibRevive | defibrillator_used | MEDIUM |
| E04 | LowHealth | HP < 15 en player_hurt | HIGH |
| E05 | BossWave | 2+ tanks activos | CRITICAL |
| E06 | WitchKilledNoRage | witch_killed sin rage | MEDIUM |
| E07 | FirstAidUsed | heal_success | MEDIUM |
| E08 | BoomerBileTank | vomit_bomb_tank | MEDIUM |
| E09 | RescueCloset | saferoom final abierto | LOW |
| E10 | Silence | 50s sin combate tras horda | LOW |
| E11 | NearDeath | 2+ survivors incapped | HIGH |

### Cómo Agregar Tracks Custom

1. Pon tus archivos .wav en `sound/music/custom/` (nombres únicos)
2. Abre `l4c_music_tracks.nut`
3. Agrega los paths a la categoría correspondiente:
```squirrel
Tank = [
    "music/custom/mi_tank_epico.wav",
    "music/custom/mi_tank_metal.wav",
],
```

---

## 🔧 Dependencias

**MaoLib** (vía l4cCoreAddon) — para timers (`AddTimer`, `RemoveTimer`)

---

## ⚠️ Notas

- **No usa `director_base_addon.nut`** — usa `mapspawn_addon.nut` (carga más temprana)
- **Tracks custom SOLO en `sound/music/custom/`** — directorio plano
- Los reemplazos vanilla en subcarpetas (`tank/`, `witch/`, etc.) se manejan solos
- Compatible con todos los modos de juego

---

*Last updated: 2026-05-30*
