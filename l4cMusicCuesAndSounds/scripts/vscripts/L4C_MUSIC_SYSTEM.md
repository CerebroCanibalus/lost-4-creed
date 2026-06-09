# L4C VScript Music Manager — Sistema de Música Dinámica

## Overview

Sistema de música dinámica para L4D2 que reproduce tracks personalizados
en respuesta a eventos del juego. Usa **2 ambient_generic** para crossfade
suave entre pistas, un sistema de prioridades para interrupción, y
cooldowns por categoría para evitar spam.

**Namespace:** `::L4C_Music` (core) + `::L4C_Music_Events` (handlers)  
**Entry Point:** `scripts/vscripts/mapspawn_addon.nut`  
**Dependencia:** `l4cCoreAddon` (MaoLib)

---

## Archivos

| Archivo | Rol |
|---------|-----|
| `mapspawn_addon.nut` | Entry point. IncludeScript de los 3 módulos en orden |
| `l4c_music_tracks.nut` | Catálogo de tracks por categoría + `GetTrack()` |
| `l4c_music_core.nut` | Motor: crossfade, prioridades, cooldowns, estados, Init/Reset |
| `l4c_music_events.nut` | Handlers de 11 eventos + registro `__CollectGameEventCallbacks` |

**Orden de carga:** `tracks → core → events`

---

## Cómo Agregar Tracks

### 1. Poner el .wav

Colocá el archivo `.wav` (mono o stereo, 44100 Hz recomendado) en:

```
sound/music/custom/mi_track.wav
```

**Directorio plano** — todos los tracks juntos, sin subcarpetas.

### 2. Registrar en `l4c_music_tracks.nut`

Agregá el path a la categoría correspondiente:

```squirrel
Tank = [
    "music/custom/mi_tank_01.wav",       // ← descomentar
    // "music/custom/mi_tank_02.wav",
],
```

El motor elige **uno aleatorio** de la categoría cada vez que se dispara el evento.

### 3. (Opcional) Regenerar sound.cache

Si L4D2 no lo detecta automáticamente, borrá `sound.cache` del addon.

---

## Catálogo de Eventos

| ID | Categoría | Evento | Prioridad | Cooldown | Cuándo suena |
|----|-----------|--------|-----------|----------|-------------|
| E01 | `Horde` | `create_panic_event` (12%) | HIGH (80) | 120s | Horda, 12% de probabilidad |
| E02 | `LastManStanding` | `player_death` | CRITICAL (100) | — | Queda 1 solo survivor vivo |
| E03 | `DefibRevive` | `defibrillator_used` | MEDIUM (60) | 60s | Reviven con desfibrilador |
| E04 | `LowHealth` | `player_hurt` (HP < 15) | HIGH (80) | 90s | Survivor al borde de la muerte |
| E05 | `BossWave` | `tank_spawn` (2+ tanks) | CRITICAL (100) | — | Múltiples Tanks simultáneos |
| E06 | `WitchKill` | `witch_killed` (sin rage) | MEDIUM (60) | 60s | Matas la Witch sin enfadarla |
| E07 | `FirstAidUsed` | `heal_success` | MEDIUM (60) | 60s | Usan botiquín exitosamente |
| E08 | `BoomerBileTank` | `boomer_exploded` (Tank cerca) | MEDIUM (60) | 90s | Boomer explota cerca de un Tank |
| E09 | `RescueCloset` | `rescue_door_open` (finale) | LOW (40) | — | Saferoom final se abre |
| E10 | `Silence` | Timer 50s tras horda | LOW (40) | — | 50s sin combate, silencio programado |
| E11 | `NearDeath` | `player_incapacitated` (2+) | HIGH (80) | 120s | 2+ survivors incapped |

### Notas por evento

- **E01 (Horde):** Solo 12% de probabilidad por horda. Cooldown de 120s.
- **E02 (LastMan):** Si revive alguien, se cancela. Los contadores se actualizan en `revive_success`.
- **E04 (LowHealth):** Efecto local/auditivo para el jugador herido (no global).
- **E06 (Witch):** `witch_harasser_set` marca si alguien enfadó a la witch. Si `witch_killed` ocurre sin esa marca → sneaky kill.
- **E08 (Bile):** No existe evento `vomit_bomb_tank` en VScript. Se usa `boomer_exploded` + distance check (500 units) para detectar si hay un Tank cerca.
- **E09 (Rescue):** Solo en mapas finale (detecta `trigger_finale`). La puerta del saferoom final se abrió pero los survivors están adentro.
- **E10 (Silence):** Timer de 50s. Se cancela si ocurre `create_panic_event` antes.
- **E11 (NearDeath):** Por "sorpresa" — 2 incapped simultáneos sin previo aviso.

---

## Sistema de Prioridades

| Prioridad | Valor | Se interrumpe por... |
|-----------|-------|---------------------|
| CRITICAL | 100 | Nada (solo otro CRITICAL) |
| HIGH | 80 | CRITICAL |
| MEDIUM | 60 | CRITICAL, HIGH |
| LOW | 40 | CRITICAL, HIGH, MEDIUM |
| AMBIENT | 20 | Cualquier cosa |

**Regla:** Una pista en reproducción NO se interrumpe si la nueva tiene
menor o igual prioridad. CRITICAL interrumpe TODO.

---

## Cooldowns por Categoría

| Categoría | Cooldown |
|-----------|----------|
| Horde | 120s |
| LastManStanding | 0 (sin cooldown) |
| DefibRevive | 60s |
| LowHealth | 90s |
| BossWave | 0 (sin cooldown) |
| WitchKill | 60s |
| FirstAidUsed | 60s |
| BoomerBileTank | 90s |
| RescueCloset | 0 (sin cooldown) |
| Silence | 0 (sin cooldown) |
| NearDeath | 120s |

---

## Crossfade (Técnico)

El motor usa **2 entidades `ambient_generic`**:

```
[Activo]  → suena track actual
[Standby] → prepara el nuevo track
```

**Proceso:**
1. `FadeOut` en activo (1.5s)
2. Esperar 0.3s
3. Setear `message` en standby con el nuevo track
4. `PlaySound` + `Volume 1.0` en standby (0.2s delay)
5. Esperar 2.0s
6. `StopSound` en el anterior
7. Intercambiar referencias `ambActive ↔ ambStandby`

**Riesgo conocido:** Si ocurre un evento de alta prioridad durante el
crossfade (~2.3s), las referencias pueden entremezclarse. No crítico
porque ambos ambient_generic son idénticos, pero considerar añadir
flag `_isCrossfading` si aparecen problemas.

---

## Estados del Sistema

| Estado | Valor | Cuándo |
|--------|-------|--------|
| OFF | 0 | Antes de Init / después de Reset |
| SAFE | 1 | En saferoom / Rescue |
| AMBULATORY | 2 | Explorando, sin combate |
| COMBAT | 3 | Horda, NearDeath |
| BOSS | 4 | Tank, BossWave |
| DEATH | 5 | LastManStanding, LowHealth |
| SILENCE | 6 | Silence programado |

---

## Debug

En `l4c_music_core.nut`:

```squirrel
::L4C_Music.Debug <- 1   // 0=quiet, 1=info, 2=verbose
```

- **0:** Silencioso (producción)
- **1:** Eventos disparados, errores, crossfades
- **2:** Todo (cooldowns, contadores, cada player_death)

Prefijo en consola: `[L4C_Music]`

---

## Cleanup (Round End)

En `round_end`, `mission_lost`, `map_transition`:

- `Reset()` → limpia contadores, cooldowns, timers
- RemoveTimer de `l4c_music_silence`, `l4c_music_swap`, `l4c_music_swap_commit`
- Las entidades ambient_generic se destruyen automáticamente con `StopAll`

---

## Troubleshooting

| Síntoma | Causa probable | Solución |
|---------|---------------|----------|
| No suena nada | Falta track en categoría | Agregar .wav y descomentar en tracks.nut |
| No suena nada | ambient_generic no spawn | Verificar `[L4C_Music]` en consola |
| No suena E08 | Boomer lejos del Tank | Buscar boomer_exploded + Tank cerca |
| No suena E09 | No es mapa finale | rescue_door_open solo dispara en finale |
| Se corta el audio | Crossfade en progreso | Normal, esperar ~2.3s |
| Se pisa la música | Alta prioridad interrumpe | Comportamiento esperado |
| Error en consola | Falta MaoLib | Verificar l4cCoreAddon cargado |

---

## Categorías Sin Evento (Precargadas)

Estas categorías existen en `Tracks` pero **no están conectadas a ningún evento**.
Están listas para cuando se quieran agregar:

| Categoría | Evento posible |
|-----------|---------------|
| `Witch` | witch_harasser_set (witch aggro) |
| `PZAttack` | Evento de Specials |
| `SafeRoom` | round_start |

Para activarlas, crear el handler en `l4c_music_events.nut`.

---

## Modo de Uso (FLUJO)

```
1. Ponés .wav en sound/music/custom/
2. Descomentás el path en l4c_music_tracks.nut
3. Iniciás el juego
4. round_start → Init() crea 2 ambient_generic
5. Evento → TriggerEvent() → GetTrack() → Crossfade()
6. round_end → Reset() limpia todo
```
