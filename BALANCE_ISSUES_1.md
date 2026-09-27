# BALANCE ISSUES REPORT #1

> **Mod:** Lost 4 Creed — L4D2 Modpack
> **Fecha:** 2026-07-02
> **Propósito:** Diagnóstico de 6 problemas de balance reportados por jugadores.
> **Tipo:** Solo diagnóstico — sin cambios aplicados.

---

## Índice

1. [IA de Supervivientes Tonta](#1-ia-de-supervivientes-tonta)
2. [Infectados Especiales Abruman](#2-infectados-especiales-abruman)
3. [Witch Invisible](#3-witch-invisible)
4. [Pacing Acelerado — Sin Pausas](#4-pacing-acelerado--sin-pausas)
5. [Primeros Mapas Demasiado Difíciles](#5-primeros-mapas-demasiado-difíciles)
6. [Tank Demasiado Fuerte](#6-tank-demasiado-fuerte)
7. [Resumen Comparativo](#7-resumen-comparativo-mod-vs-vanilla)
8. [Archivos Clave por Sistema](#8-archivos-clave-por-sistema)

---

## 1. IA de Supervivientes Tonta

### Sistema: MIA (Minimal Intervention AI)
**Archivo base:** `l4cCoreSurvivorGameplay/scripts/vscripts/survivor_ai_overhaul.nut`
**Filosofía:** Intervención mínima — solo corrige cuando la AI vanilla falla.

### Causas raíz

| Síntoma | Causa | Archivo:línea |
|---------|-------|:------:|
| Se atoran en geometría | `Unstick` prioridad **50/100** (baja media). Espera **3s** de inmovilidad antes de actuar. | `sa_detector.nut` |
| No responden a ataques SI | `Attack_SI` prioridad **70**, compite con tareas vanilla. `CommandCooldown = 0.3s` entre comandos. | `sa_detector.nut`, `sa_config.nut` |
| Mal posicionamiento | El detector es **reactivo**, no preventivo. Espera a que el bot esté en peligro para corregir. | `sa_detector.nut` |
| No shopean suficientes CI | `CommonShoveThreshold = 5` — necesita **5+ CI amasados** antes de shovear. | `sa_config.nut:9` |
| No esquivan ácido/spit | `Dodge` prioridad **99** pero depende del evento `spit_burst`. Si el evento falla, no esquivan. | `sa_detector.nut` |
| No rescatan rápido | `RescueTimeoutSmoker = 2.0s`, `Hunter = 3.0s`, `Jockey = 3.0s` — demasiado lentos. | `sa_config.nut` |
| No shopean tongue | Distancia 150u para shove de tongue — el bot deja que la víctima sea arrastrada casi hasta el smoker. | `sa_detector.nut` |

### Datos relevantes

```
BotThinkInterval   = 0.25s  (por bot)
CommandCooldown    = 0.3s
ShoveCooldown      = 0.8s
CommonDetectRadius = 100u
CommonShoveThreshold = 5+ CI
StuckThreshold     = 3.0s
TankKiteRange      = 800u
TankDangerRange    = 200u     ← demasiado cerca
VisionFOV          = 120°
VisionMaxDistance  = 600u
DeadstopRange      = 150u
```

### Nota
El sistema `sa_core.nut` limpia `m_afButtonForced` cada frame (`line 25`), lo que puede interferir con comandos encadenados. El pipeline es: Vision → Deadstop → Heal Interrupt → Task Detection → Execution.

---

## 2. Infectados Especiales Abruman

### Sistema: Infected Balance + Director Config
**Archivos:** `l4cInfectedGameplay/scripts/vscripts/infected_balance.nut`, `l4cCoreAddon/scripts/vscripts/director_base_addon.nut`

### Causas raíz

| Factor | Valor Mod | Vanilla | Impacto |
|--------|-----------|---------|:-------:|
| `MaxSpecials` | **7** (6 tipos + 1 flex) | 3-4 | **+100%** SI simultáneos |
| `SpecialRespawnInterval` | **30s** (coop) | ~45s | **+50%** más frecuente |
| SI HP | **+20%** (todos los tipos) | 100% base | Duran más = más daño acumulado |
| `z_throttle_hit_interval` | **0** (coop, todas dificultades) | 0.25-0.4 | **Sin pausa** entre golpes |
| `claw_swing_interval` | **1.60s** | 1.75s | +9% más ataques/segundo |
| `z_charge_duration` | **2.15s** | 2.5s | Carga **más rápida** y difícil de esquivar |
| `z_charger_allow_shove` | **0** | 1 | No se puede interrumpir carga |
| Custom commons | Butcher, Hellhound, Kamikaze (60%), CorpseEater (35%), SewerWorker (30%) | 0 | Presión de commons especiales constante |

### Custom Infected (l4cCustomInfected)

| Tipo | Chance | HP | Daño especial |
|------|:------:|:--:|---------------|
| Hellhound (reemplaza Jockey) | 55% | 400 | Bleed 6/tick × 5s, death explosion radius 150 |
| Butcher | variable | alto | Berserker, moscas, pool 2 partículas |
| Kamikaze | 60% | CI base | Explota 25 dmg radius 350 al morir |
| Corpse Eater | 35% | CI base | Bleed 10 por ataque |
| Sewer Worker | 30% | CI base | Bilea a survivor |

### Conclusión
La combinación **MaxSpecials=7 + +20% HP + hit throttle 0 + custom commons** crea presión constante sin ventanas de respiro. No hay diferenciación early-game vs late-game.

---

## 3. Witch Invisible

### Sistema: Cinematic Light + Dynamic Lights
**Archivos:** `l4cCoreVisuals/scripts/vscripts/director_base_addon.nut`, `l4cInfectedGameplay/scripts/vscripts/witch_system.nut`

### Causa raíz confirmada

**Luces cinemáticas prácticamente eliminadas:**
```
cl_cinematiclight_r  = 10      (l4cCoreVisuals/director_base_addon.nut:23)
cl_cinematiclight_g  = 0       (:22)
cl_cinematiclight_b  = 0       (:21)
cl_cinematiclight_scale = 8.0  (:24)
```
RGB en **10, 0, 0** → prácticamente negro. Aunque scale=8.0, el color base es casi invisible.

**Luces dinámicas eliminadas:**
```
// ⚠️ Dynamic lights REMOVIDOS: l4c_sal, l4c_sfl_mao
// Causaban inestabilidad y conflictos. Mantenemos solo efectos visuales sin luces dinámicas.
``` 
(`director_base_addon.nut:3-4`)

La Witch **no tiene luz que la ilumine** en zonas oscuras.

### Witch glow insuficiente
```
cl_witch_glow_idle_r   = 0.2   (custom_glow_coop.nut)
cl_witch_glow_idle_g   = 0.4
cl_witch_glow_idle_b   = 0.2   → verde muy oscuro
```

### Otros datos de witch
```
z_witch_health        = 3210   (+20% vs vanilla 2675)   [infected_balance.nut]
z_witch_anger_rate    = 0.01   (minimizado — VScript maneja anger)
z_witch_flashlight_range = 1   (casi 0)
DefaultSize           = 1.5x   (50% más grande)          [witch_damage.nut]
Shotgun anti-crown    = -70%   (AllowTakeDamage hook)
```

---

## 4. Pacing Acelerado — Sin Pausas

### Sistema: Director Options + Acoustic Terror
**Archivos:** `l4cCoreAddon/scripts/vscripts/director_base_addon.nut`, `l4cCoreAddon/scripts/vscripts/l4c_acoustic_terror.nut`

### Causas raíz

| Sistema | Valor | Efecto |
|---------|-------|--------|
| `director_threat_radius` | **1000** (coop, vanilla ~500) | Director detecta desde 2x distancia → spawns más temprano |
| `director_threat_min_separation` | **3250** (coop) | Spawnea a mayor distancia = más cobertura |
| `z_mob_min_notify_count` | 30 | Hordas se anuncian con 30+ CI (alto) |
| `SpecialRespawnInterval` | **30s** | Especiales reaparecen cada 30s constantemente |
| `MaxSpecials = 7` | 7 SI vivos posibles | Nunca hay menos de 3-4 SI simultáneos |
| `z_throttle_hit_interval_* = 0` | Sin throttle | Golpes continuos sin pausa |

### Acoustic Terror (hordas por ruido)
```
VOLUME_LIMIT       = 150000   Cap para trigger horda
HORDE_COOLDOWN     = 300s     Mínimo 5 min entre hordas automáticas
SHOT_VOLUME        = 600      Por disparo
GRENADE_VOLUME     = 3000     Por granada/molotov
PANIC_INCREMENT    = 25       +25% por horda
PANIC_DOUBLE_THRESHOLD = 75%  Doble horda en panic alto
```

Cada disparo suma volumen. El sistema encadena hordas por acumulación de ruido. Sin hit throttle + specials constantes = **nunca hay silencio**.

---

## 5. Primeros Mapas Demasiado Difíciles

### Sistema: No hay diferenciación early-game
**No existe** `c1m1_hotel.nut` ni ningún script que ajuste dificultad para mapas iniciales.

### Settings globales que aplican desde c1m1

| Setting | Valor | Problema |
|---------|-------|----------|
| `MaxSpecials` | **7** | Primer mapa con 7 specials posibles |
| `SpecialRespawnInterval` | **30s** | Sin progresión |
| SI HP | **+20%** | Desde el tile 0 |
| `z_health` (CI) | **60** | +20% desde el inicio |
| Normal `z_common_limit` | **25** (similar a Expert vanilla en Vanilla+ mods) |
| Normal `z_mega_mob_size` | **45** | Mega hordas en safe room exit |
| `director_super_weapon_density` | **1** | Pocas armas de calidad |
| `director_ammo_density` | **1** | Poca munición |

### Curva de dificultad
```
Vanilla:  [Facíl]─────[Media]─────[Difícil]───[Final]
L4C:      [Difícil]════════════════════════════[MUY Difícil]
         ↑ c1m1                                  ↑ Finales
```
No hay rampa. Primeros mapas usan misma configuración que finales.

---

## 6. Tank Demasiado Fuerte

### Sistema: Tank Core + Tank AI + Tank Combat
**Archivos:** `l4cInfectedGameplay/scripts/vscripts/tank_core.nut`, `tank_ai.nut`, `l4cCoreAddon/scripts/vscripts/tank_combat.nut`

### Comparativa numérica

| Aspecto | Vanilla ~ | Lost 4 Creed | Multiplicador |
|---------|:---------:|:------------:|:-------------:|
| HP base | ~6,000 | **12,000** | **2x** |
| HP máximo | ~6,000 | **20,000** | **3.3x** |
| HP scaling | No | +60/min | ∞ |
| Rock damage | ~250 | **800** | **3.2x** |
| Rock radius | ~100 | **150** | 1.5x |
| Speed (coop) | ~210 | **225** | +7% |
| Berserker speed (≤15% HP) | No existe | **1.5x (337.5)** | **NUEVO** |
| Fire speed boost | No existe | **1.25x** | **NUEVO** |
| Burn duration | 30-45s | **70s** | **+55-133%** |
| Crowd control | No | Knockback 200-400 + incap splash 15 | **NUEVO** |
| AI states | 2-3 básicos | **6 estados avanzados** | **MASSIVO** |

### Estados Berserker
```
wounded   (≤60% HP): speed 1.15x, daño +25%
enraged   (≤35% HP): speed 1.30x, daño +50%, rock interval 2.5s
berserker (≤15% HP): speed 1.50x, daño +100%, rock interval 1.8s, bunnyhop
```

### AI del Tank
```
ThinkInterval       = 0.2s
PredictionLead      = 1.2x
JumpChance          = 30%
PropScanRadius      = 400
ThrowMaxDist        = 1500
FlankCooldown       = 4.0s
FlankCheckRadius    = 600
ThrowCooldown       = 5.0s
ThrowRange          = 1200
Rock speed          = 800 u/s
Aim jitter          = RandomFloat × 1.25
```

### El combo letal
1. Tank spawnea con **12,000 HP** (mínimo)
2. Si le prenden fuego: **+25% speed** + fire trail que daña survivors
3. A medida que pierde HP: berserker states lo hacen **más rápido y más dañino**
4. Predice movimiento de survivors + flankea + lanza rocas con aim asistido
5. A ≤15% HP: **bunnyhop + 1.5x speed + +100% daño** — imparable

---

## 7. Resumen Comparativo: Mod vs Vanilla

| Métrica | Vanilla (Normal) | Lost 4 Creed (Normal) | Diferencia |
|---------|:----------------:|:---------------------:|:----------:|
| **Max specials** | 3-4 | **7** | **+100%** |
| **SI HP** | 100% | **120%** | **+20%** |
| **SI respawn** | ~45s | **30s** | **+50% frecuencia** |
| **Hit throttle** | 0.25s | **0s** | ∞ más golpes |
| **Tank HP** | ~6,000 | **12,000-20,000** | **2-3.3x** |
| **Tank rock dmg** | ~250 | **800** | **3.2x** |
| **Witch cinematic light** | Normal | **Casi 0** | **Invisible** |
| **Common HP** | 50 | **60** | **+20%** |
| **Witch HP** | 2,675 | **3,210** | **+20%** |
| **Curva dificultad** | Progresiva | **Plana** | Sin progresión |
| **Custom infected** | 0 | **5 tipos** | Presión extra constante |
| **Pacing breaks** | Sí (throttle) | **No** | Cero respiro |

### Tabla de dificultad percibida
```
Vanilla Easy     → L4C Normal (early)
Vanilla Normal   → L4C Hard
Vanilla Hard     → L4C Expert
Vanilla Expert   → L4C Expert+ (con custom infected)
```

---

## 8. Archivos Clave por Sistema

### Bot AI (Problema #1)
| Archivo | Ruta |
|---------|------|
| `survivor_ai_overhaul.nut` | `l4cCoreSurvivorGameplay/scripts/vscripts/` |
| `sa_config.nut` | `l4cCoreSurvivorGameplay/scripts/vscripts/` |
| `sa_core.nut` | `l4cCoreSurvivorGameplay/scripts/vscripts/` |
| `sa_detector.nut` | `l4cCoreSurvivorGameplay/scripts/vscripts/` |
| `sa_executor.nut` | `l4cCoreSurvivorGameplay/scripts/vscripts/` |
| `sa_vision.nut` | `l4cCoreSurvivorGameplay/scripts/vscripts/` |
| `sa_validator.nut` | `l4cCoreSurvivorGameplay/scripts/vscripts/` |

### Infected Balance (Problema #2)
| Archivo | Ruta |
|---------|------|
| `infected_balance.nut` | `l4cInfectedGameplay/scripts/vscripts/` |
| `director_base_addon.nut` (core) | `l4cCoreAddon/scripts/vscripts/` |
| `l4c_settings.nut` | `l4cCoreAddon/scripts/vscripts/` |
| `butcher.nut` | `l4cCustomInfected/scripts/vscripts/` |
| `hound.nut` | `l4cCustomInfected/scripts/vscripts/` |
| `kamikaze_mob.nut` | `l4cCustomInfected/scripts/vscripts/` |
| `corpse_mob.nut` | `l4cCustomInfected/scripts/vscripts/` |
| `sewer_mob.nut` | `l4cCustomInfected/scripts/vscripts/` |
| `common_system.nut` | `l4cInfectedGameplay/scripts/vscripts/` |

### Witch (Problema #3)
| Archivo | Ruta |
|---------|------|
| `director_base_addon.nut` (visuals) | `l4cCoreVisuals/scripts/vscripts/` |
| `witch_system.nut` | `l4cInfectedGameplay/scripts/vscripts/` |
| `witch_damage.nut` | `l4cInfectedGameplay/scripts/vscripts/` |
| `custom_glow_coop.nut` | `l4cCoreAddon/scripts/vscripts/` |

### Pacing (Problema #4)
| Archivo | Ruta |
|---------|------|
| `director_base_addon.nut` (core) | `l4cCoreAddon/scripts/vscripts/` |
| `l4c_acoustic_terror.nut` | `l4cCoreAddon/scripts/vscripts/` |
| `lost4creet_map_changes.nut` | `l4cCoreAddon/scripts/vscripts/` |

### First Map Difficulty (Problema #5)
| Archivo | Ruta |
|---------|------|
| `infected_balance.nut` | `l4cInfectedGameplay/scripts/vscripts/` |
| `l4c_settings.nut` | `l4cCoreAddon/scripts/vscripts/` |
| *(No existe `c1m1_hotel.nut`)* | |

### Tank (Problema #6)
| Archivo | Ruta |
|---------|------|
| `tank_core.nut` | `l4cInfectedGameplay/scripts/vscripts/` |
| `tank_ai.nut` | `l4cInfectedGameplay/scripts/vscripts/` |
| `tankaim.nut` | `l4cInfectedGameplay/scripts/vscripts/` |
| `tank_combat.nut` | `l4cCoreAddon/scripts/vscripts/` |

---

*Fin del reporte. Para correcciones, crear BALANCE_FIXES_1.md con cambios específicos.*
