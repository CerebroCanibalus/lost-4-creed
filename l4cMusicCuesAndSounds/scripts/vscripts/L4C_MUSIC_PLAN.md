# 🎵 L4C VScript Music Manager — Plan de Arquitectura

## 📋 Descripción

Sistema VScript que reproduce música custom durante eventos del juego en L4D2.
Los tracks custom van en `sound/music/custom/` (directorio plano).
El sistema reemplaza intensifica momentos existentes y añade música a momentos que no la tienen.

## 📁 Archivos del Sistema

| Archivo | Rol |
|---------|-----|
| `mapspawn_addon.nut` | Entry point — Carga el manager al iniciar la partida |
| `l4c_music_core.nut` | Núcleo — Estados, crossfade, cola de prioridad, cooldowns, 2 entidades ambient_generic |
| `l4c_music_events.nut` | Eventos — Handlers de ~15 game events que disparan música |
| `l4c_music_tracks.nut` | Catálogo — Tabla de tracks custom por categoría con paths a `music/custom/` |

## ⚙️ Arquitectura del Core

```
2 ambient_generic entities:
  ┌──────────────┐     ┌──────────────┐
  │  ambActive    │     │  ambStandby  │
  │  (reproduciendo)│    │  (silente)   │
  └──────┬───────┘     └──────┬───────┘
         │                    │
         ▼                    ▼
    Crossfade: FadeOut(active) → Cambiar wave → FadeIn(standby) → Swap
```

### Namespace: `::L4C_Music`
- `State` — enum: SAFE, AMBULATORY, COMBAT, BOSS, DEATH, SILENCE
- `CurrentPriority` — int (0-100)
- `CurrentTrack` — string path actual
- `Cooldowns` — table { eventName: nextTime }
- `Debug` — int (0=quiet, 1=info, 2=verbose)

### Sistema de Prioridades

| Nivel | Valor | Interrumpe | Eventos |
|-------|-------|------------|---------|
| CRITICAL | 100 | Todo | LastManStanding, BossWave, Tank |
| HIGH | 80 | MED/LOW | HordeTrack, NearDeath, LowHealth |
| MEDIUM | 60 | LOW | DefibRevive, BoomerBileTank, FirstAidUsed |
| LOW | 40 | Nada | RescueCloset, Silence, SafeRoom |
| AMBIENT | 20 | Nada | SafeAtmosphere, loops de fondo |

### Pipeline de Decisión

```
GameEvent → handler en events.nut
  ├─ ¿Cooldown activo? → DESCARTAR (printl debug)
  ├─ ¿Priority > CurrentPriority? → INTERRUMPIR con crossfade
  ├─ ¿Priority == CurrentPriority? → ENCOLAR (reemplazar si misma categoría)
  └─ ¿Priority < CurrentPriority? → DESCARTAR
        │
        ▼
  tracks.nut: GetRandomTrack(categoría) → "music/custom/mi_track.wav"
        │
        ▼
  core.nut: Crossfade()
    ├─ FadeOut(ambActive, 1.5s)
    ├─ __KeyValueFromString("message", newPath) en ambStandby
    ├─ PlaySound(ambStandby)
    └─ Swap(ambActive ↔ ambStandby)
        │
        ▼
  Cooldown: 60-120s (según categoría) antes de re-trigger
```

## 🎯 Eventos Implementados (11)

| ID | Evento | Gatillo | Prioridad | Cooldown |
|----|--------|---------|-----------|----------|
| E01 | HordeTrack | create_panic_event (30% prob) | HIGH | 120s |
| E02 | LastManStanding | 3 survivors dead/incap | CRITICAL | 0s (reemplaza todo) |
| E03 | DefibRevive | defibrillator_used | MEDIUM | 60s |
| E04 | LowHealth | player_hurt con HP<15 | HIGH | 90s |
| E05 | BossWave | 2+ tanks activos | CRITICAL | 0s |
| E06 | WitchKilledNoRage | witch_killed sin rage previo | MEDIUM | 60s |
| E07 | FirstAidUsed | heal_success | MEDIUM | 60s |
| E08 | BoomerBileTank | vomit_bomb_tank | MEDIUM | 90s |
| E09 | RescueCloset | survivors en saferoom final, puerta abierta | LOW | 0s (hasta que cierre) |
| E10 | Silence | 50s sin combate tras horda | LOW | 0s |
| E11 | NearDeath | 2+ survivors incapped simultáneo | HIGH | 120s |

## 🎹 Catálogo de Tracks (tracks.nut)

Cada categoría tiene un array de paths a `music/custom/`:

```squirrel
Categories = {
    tank = ["music/custom/mi_tank_track_1.wav", ...]
    witch = ["music/custom/mi_witch_track_1.wav", ...]
    horde = ["music/custom/mi_horda_track_1.wav", ...]
    last_stand = ["music/custom/mi_last_stand.wav", ...]
    defib = ["music/custom/mi_defib.wav", ...]
    heal = ["music/custom/mi_heal.wav", ...]
    bile = ["music/custom/mi_bile.wav", ...]
    rescue = ["music/custom/mi_rescue.wav", ...]
    silence = []  // Vacío = silencio programado
    near_death = ["music/custom/mi_near_death.wav", ...]
    boss_wave = ["music/custom/mi_boss_wave.wav", ...]
    low_health = ["music/custom/mi_low_health.wav", ...]
    witch_kill = ["music/custom/mi_witch_kill.wav", ...]
}
```

Cuando el General agregue tracks a `sound/music/custom/`, solo necesita actualizar `tracks.nut`.

## 🐛 Limitaciones Conocidas

- ambient_generic no soporta SetParent() para posición (no importa, es música global)
- FadeOut en ambient_generic requiere la flag "is NOT looped" DESACTIVADA
- .mp3 puede tener bugs con loops largos — preferir .wav
- La música global (CHAN_STATIC) se escucha en todo el mapa
