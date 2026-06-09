# Lost 4 Creed — Gunplay Addon

**Versión:** 2.4  
**Author:** Beria & Richardhaifer  
**Addon:** `l4cWeaponItemScripts`

Addon de gameplay que reworkea armas, items, mecánicas de combate y físicas en Left 4 Dead 2.

---

## Índice

- [Arquitectura](#arquitectura)
- [Sistemas Principales](#sistemas-principales)
  - [RRLogic System](#rrlogic-system)
- [Scripts de Balance Global](#scripts-de-balance-global)
- [Armas de Fuego](#armas-de-fuego)
- [Escopetas](#escopetas)
- [Rifles y SMGs](#rifles-y-smgs)
- [Granadas y Explosivos](#granadas-y-explosivos)
- [Armas Cuerpo a Cuerpo](#armas-cuerpo-a-cuerpo)
- [Miniguns y Torretas](#miniguns-y-torretas)
- [Items y Consumibles](#items-y-consumibles)
- [Sistemas de Combate](#sistemas-de-combate)
- [Visuales y Sonido](#visuales-y-sonido)
- [Mecánicas de Infectados](#mecánicas-de-infectados)
- [Sistema de Overdosis de Píldoras](#sistema-de-overdosis-de-píldoras)
- [Single Grab Weapons](#single-grab-weapons)
- [Weapon Data Overrides (.txt)](#weapon-data-overrides-txt)
- [Dependencias](#dependencias)
- [Desarrollo](#desarrollo)
- [Changelog](#changelog)

---

## Arquitectura

### Entry Point

`scripts/vscripts/director_base_addon.nut` — Carga todos los scripts por categorías mediante `IncludeScript()`. Es el primer archivo que ejecuta el motor dentro de este addon.

### Orden de Carga (v2.3+)

```
director_base_addon.nut
├── core_system.nut          (Config parser, debug, registry)
├── convars_system.nut       (Balance convars + pills + SMG headshot + turnrate)
├── firearms_system.nut      (M60 stagger, SG552 zoom damage)
├── special_firearms_system.nut  (AWP explosive, auto-fire pistols/snipers, rip_and_tear, shotgun gib)
├── explosives_system.nut    (Atomic pipe, bile slow, GL screenshake, AoE incendiary)
├── feedback_system.nut      (Kill sound/effect, hitmarker, LASC, clip empty, wound feedback)
├── items_system.nut         (Auto upgrade, held cans, ammo limits, adrenaline reload, item buffs, overdose)
├── melee_base_system.nut    (Real reload, breakable melees)
├── melee_special_system.nut (Bleed melee)
├── mounted_system.nut       (Turret explosions, minigun gib, minigun shake)
├── riotshield_system.nut    (Damage reduction + blocking)
├── flamethrower_system.nut  (Fuel-based melee with fire effects)
├── rrlogic_system.nut       (Hunting Bloodletter + Desert Rampage)
├── rrlogic.nut              (Recoil system — external)
├── electric_axe.nut         (Electric axe — original)
└── sgw_main_script.nut      (Item spawn world script)
```

### Sistemas Modulares (v2.3+)

A partir de v2.3, todos los scripts se organizan en **sistemas modulares** registrados vía `::L4CWI_Core.RegisterSystem()`. Cada sistema:
- Tiene su propio namespace (`::L4CWI_*`)
- Carga configuración desde archivos `.cfg` en `l4cwi_config/`
- Recibe debug helpers (`_Dbg`, `_DbgWarn`, `_DbgError`)
- Puede implementar `Init()`, `Cleanup()`, `OnRoundStart()`, `OnRoundEnd()`

### Scripts Adicionales

- `mapspawn_addon.nut` — Se ejecuta al cargar el mapa. Spawnea entidades para `item_buffs` y `sgw_main_script`.
- `sgw_main_script.nut` — Asignado como vscript de `logic_versus_random` (single grab weapons).

---

## Sistemas Principales

### RRLogic System

**Script:** `rrlogic_system.nut`  
**Namespace:** `::L4CWI_RRLogic`  
**Versión:** 2.0

Sistema de habilidades avanzadas para dos rifles específicos, con integración al sistema de recoil externo (`rrlogic.nut`).

#### 1. Hunting Rifle — Bloodletter (Sangrado AoE Acumulable)

Cuando un survivor dispara a un infected (común, special o witch) con la **Hunting Rifle**, el target sufre **sangrado acumulable**:

- **Daño directo:** Cada tick aplica `stacks × dmg_per_stack` al target.
- **Daño en área:** Cada tick aplica `stacks × dmg_per_stack × 0.5` a todos los enemies dentro del radio, con **falloff lineal** (menor daño en el borde).
- **Stacks:** Se acumulan hasta un máximo. Cada nuevo hit reinicia la duración.
- **Visual:** A partir de 3 stacks, aparece partícula de sangre en el target.

**Técnica (v2.0 — MaoLib.AoE refactor):**
En lugar de búsquedas manuales con `Entities.FindByClassnameWithin`, el sistema usa el patrón **Selector → Aplicador** de `MaoLib.AoE`:

```vscript
// Selector: busca enemies en radio
local targets = MaoLib.AoE.Select.Circle(origin, radius, {
    className = "infected",
    ignoreEnt = victim,
    aliveOnly = true
})

// Aplicador: aplica daño con falloff lineal
MaoLib.AoE.Apply.Damage(targets, dmg, attacker, 131072, {
    falloff = "linear",
    origin = origin,
    radius = radius
})
```

**Configuración** (`l4cwi_config/rrlogic_system.cfg`):

| Variable | Default | Descripción |
|----------|---------|-------------|
| `hunting_bleed_enabled` | `true` | Activar/desactivar Bloodletter |
| `hunting_bleed_radius` | `120` | Radio del daño en área |
| `hunting_bleed_dmg_per_stack` | `6` | Daño base por stack por tick |
| `hunting_bleed_max_stacks` | `5` | Máximo de stacks acumulables |
| `hunting_bleed_tick_interval` | `0.8` | Segundos entre ticks |
| `hunting_bleed_duration` | `4.0` | Segundos de duración del sangrado |
| `hunting_damage_mult` | `0.75` | Multiplicador de daño directo (el resto se convierte en DoT) |

#### 2. Desert Rifle — Rampage (Full-Auto Burst + Fire Rate Progresivo)

Convierte la **Desert Rifle (SCAR)** en un arma de **ráfaga automática continua** con fire rate que aumenta mientras se dispara:

- **Full-Auto real:** El jugador mantiene click y el arma dispara ráfagas continuamente sin soltar.
- **Fire rate progresivo:** El intervalo entre ráfagas disminuye linealmente desde `start_interval` hasta `max_interval` durante `accel_time` segundos.
- **Daño bonus:** Cada hit hace `×1.3` de daño.
- **Recoil dinámico:** Si `rrlogic.nut` está cargado, el recoil base se multiplica progresivamente (1.0× → 3.0×) según el tiempo de disparo continuo.
- **Munición:** Al recoger munición con la Desert Rifle equipada, recibe `×3` de bonus. Si la munición baja de `threshold`, se recarga automáticamente.

**Técnica (v2.0 — Full-auto real):**

El motor de L4D2 requiere que el jugador "suelte" el botón de ataque (`m_isHoldingFireButton = 0`) para iniciar una nueva ráfaga. El sistema usa un **timer a 100Hz** (`0.01s`) que:

1. Detecta cuando el jugador mantiene click (`m_nButtons & 1`)
2. Cuando el arma está lista para disparar (`m_flNextPrimaryAttack <= Time()`), fuerza `m_isHoldingFireButton = 0`
3. Esto engaña al motor haciéndole creer que el jugador soltó el botón, iniciando la siguiente ráfaga inmediatamente
4. Simultáneamente, reduce `m_flNextPrimaryAttack` para acelerar el fire rate según el streak time

**Ventaja sobre soluciones tipo "auto-scar":** No hardcodea animaciones, cycletimes ni netprops de gesture. Funciona con cualquier valor de `CycleTime` configurado en `weapon_rifle_desert.txt`.

**Configuración** (`l4cwi_config/rrlogic_system.cfg`):

| Variable | Default | Descripción |
|----------|---------|-------------|
| `desert_ramp_enabled` | `true` | Activar/desactivar Rampage |
| `desert_ramp_start_interval` | `0.12` | Intervalo inicial entre ráfagas (s) |
| `desert_ramp_max_interval` | `0.05` | Intervalo máximo (fire rate más alto) |
| `desert_ramp_accel_time` | `2.0` | Segundos para alcanzar fire rate máximo |
| `desert_damage_mult` | `1.3` | Multiplicador de daño bonus |
| `desert_ammo_mult` | `3` | Multiplicador de munición al recoger |
| `desert_ammo_bonus` | `30` | Munición bonus en check automático |
| `desert_ammo_threshold` | `150` | Umbral para recarga automática |
| `desert_rrlogic_recoil_start` | `1.0` | Multiplicador de recoil inicial |
| `desert_rrlogic_recoil_max` | `3.0` | Multiplicador de recoil máximo |

#### Debug

El sistema incluye debug exhaustivo (`Debug = 1` por defecto):
- `ENTER/EXIT` en cada función pública
- `ABORT` en returns tempranos con razón
- Valores clave logueados en cada tick (stacks, hits, streak time, interval, recoil mult)
- `try/catch` en todos los callbacks de timers para evitar crashes silenciosos

---

## Scripts de Balance Global

### `rrlogic.nut` — Reworked Recoil System
**Namespace:** `::YsReworkedRecoil` + `::RRConfigManager`

Sistema completo de recoil reworkeado con:
- Recoil base por arma (configurable)
- Multiplicadores globales de recoil
- Modificadores al agacharse, caminar, usar láser
- Sistema de smoothing
- Soporte de archivo de configuración y comandos por chat

### `turnrate_shove.nut` — Turn Rate + Shove
Ajusta convars de velocidad de rotación de infectados y desactiva las penalidades por gun swing al ser golpeado:
- `mp_facefronttime` = 3
- `z_gun_swing_*_penalty` = 999999999 (desactivado)

### `automatic_stuff.nut` — Full Auto para Pistolas
**Namespace:** `RF_AUTOGUNS`

Permite disparo automático completo para pistolas y sniper militar al limpiar el flag `m_isHoldingFireButton` en cada disparo.

### `fullclip_reload.nut` — Tactical Reload
**Namespace:** `RF_RealMag`

Sistema de recarga táctica: las armas cargan un cargador nuevo completo en vez de "rellenar" bala por bala. Los tiempos de recarga varían según el arma:
- Pistola: 1.19s
- Hunting Rifle: 2.6s
- Shotguns: 0.37s–0.45s
- SMGs: 1.8s–2.1s
- Rifles: 1.9s–2.36s

### `chch_realreload.nut` — Realistic Reload
**Namespace:** `ChCh_ChCh_RealReload`

Recargar consume TODA la munición de reserva restante (excepto escopetas y motosierra). Simula un "mag dump" realista.

### `chch_breakablemelees.nut` — Durabilidad de Melees
**Namespace:** `meleebreaking`

Las armas cuerpo a cuerpo tienen durabilidad por tipo (fireaxe=30, katana=75, machete=35, etc.) y pueden romperse con efectos de sonido. Opcionalmente sueltan una pistola al romperse.

### `difficultylimitedammo.nut` — Munición Limitada por Dificultad
**Namespace:** `::g_DifficultyLimitedAmmo`

Los piles de munición tienen usos limitados según dificultad:
- Easy: 3 usos
- Normal: 2 usos
- Advanced: 1 uso
- Expert: 1 uso

---

## Armas de Fuego

### `firearms_system.nut` — Firearms Effects
**Namespace:** `::L4CWI_Firearms`

Sistema modular que fusiona `m60_stagger` y `sg_extradamage`:

- **M60 Stagger:** 15% de probabilidad de staggerear Chargers (zombie type 6) y Tanks (type 8) en cada impacto.
- **SG552 Zoom Bonus:** El rifle SG552 hace 66% de daño bonus a especiales y comunes cuando está apuntando (zoomeado).

### `special_firearms_system.nut` — Special Firearms Effects
**Namespace:** `::L4CWI_SpecialFirearms`

Sistema modular que fusiona `awp_explosive`, `automatic_stuff`, `rip_and_tear` y `shotgungib`:

- **AWP Explosive:** Los rifles AWP causan daño explosivo (radio 140) en **cada disparo, siempre**. 
  
  **Técnica:** Usa `TraceLine` desde el ojo del jugador (`EyePosition()` + `EyeAngles()`) para obtener el punto de impacto estimado. Esto garantiza que la explosión ocurra incluso si el disparo no impacta en nada (disparo al aire, mapa abierto).
  
  **AoE refactorizado (v2.4):** Reemplaza búsquedas manuales con `MaoLib.AoE`:
  ```vscript
  // Commons (daño 250, DMG_BLAST | DMG_ALWAYSGIB)
  MaoLib.AoE.Select.Circle(pos, 140, { className = "infected" })
  
  // Witch (daño 75)
  MaoLib.AoE.Select.Circle(pos, 140, { className = "witch" })
  
  // Special Infected (daño 75)
  MaoLib.AoE.Select.Circle(pos, 140, { className = "player", filter = !IsSurvivor })
  ```
  
  Usa `MaoLib_VFX` para partículas, screen shake y sonidos.
- **Auto-Fire:** Pistolas (`weapon_pistol`) y Sniper Military (`weapon_sniper_military`) disparan en modo automático al limpiar `m_isHoldingFireButton` en cada disparo.
- **Rip and Tear:** Los rifles de asalto (AK47, SG552, M16, Combat Rifle) hacen gib a los comunes al matarlos. Mecánica de mag-dump tracking con timer a 0.1s.
- **Shotgun Gib:** Los comunes muertos por escopeta (dentro de 100 unidades) sufren desmembramiento con sets de heridas por tipo de zombie.

### `rrlogic_system.nut` — RRLogic Integration
(Sistema de habilidades avanzadas — ver [Sistemas Principales](#sistemas-principales))

---

## Escopetas

### `special_firearms_system.nut` — Shotgun Gibs
**Namespace:** `::L4CWI_SpecialFirearms`

Los comunes muertos por escopeta (dentro de 100 unidades) sufren desmembramiento. Sets de heridas por tipo de zombie:
- CEDA: 1–9
- Riot: 3–5
- Normal: 22–25

---

## Rifles y SMGs

### `firearms_system.nut` — Firearms Effects
(Visto en [Armas de Fuego](#armas-de-fuego))

### `special_firearms_system.nut` — Special Firearms Effects
(Visto en [Armas de Fuego](#armas-de-fuego))

### `rrlogic_system.nut` — RRLogic Integration
(Visto en [Sistemas Principales](#sistemas-principales))

---

## Granadas y Explosivos

### `atomic_pipe.nut` — Pipe Bomb Atómica
**Namespace:** `kuro_atomic_pipe_bomb`

Configuración mejorada de pipe bombs:
- Fuse duration: 2s
- Shake radius: 2000
- Beep interval progresivo (0.35 → 0.08)
- Compatible con todos los modos de juego

### `brutal_pipebomb.nut` — Pipe Bomb Brutal
**Namespace:** `::BrutalPipebomb`

Mientras un jugador humano tiene una pipe bomb activa, los bots sobrevivientes no disparan (para evitar que maten a specials antes de la explosión). Se re-habilitan al detonar o cuando un special ataca.

### `nescius_pipe_damage_de.nut` — Pipe Bomb Damage Amplificado
**Namespace:** `::NesciusPipeDamage`

El daño de pipe bombs contra special infected se amplifica masivamente:
- Si el daño base ≥ 10: 1500 damage
- Si no: 50× el daño base

### `glauncher.nut` — Grenade Launcher Config
Configura convars del lanzagranadas:
- Velocidad: 900
- Radio kill: 140
- Radio stumble: 200
- Daño: 1500
- Friendly fire: 0.06 (otros), 0.18 (self)

### `gl_screenshake.nut` — Explosion Shake para GL
**Namespace:** `GL_SCREENSHAKE`

Rastrea los proyectiles del lanzagranadas y aplica screen shake en su explosión. Maneja bot replacement para transferir datos de tracking.

### `m60_stagger.nut` — M60 Stagger
**Namespace:** `ChCh_M60Staggorzz`

La M60 tiene 15% de probabilidad de staggerear Chargers (zombie type 6) y Tanks (type 8) en cada impacto.

### `bile_slow.nut` — Bile Frena Specials
**Namespace:** `ChCh_SlowSpecials`

Los special infected cubiertos de bile (vomit jar) reducen su velocidad en un 75%.

---

## Armas Cuerpo a Cuerpo

### `bleed_melee.nut` — Sangrado con Melees Sharp
**Namespace:** `ChCh_BleedSharps`

> ⚠️ **Bug conocido:** Este script tiene los handlers `HandlePlayerHurt`/`HandleInfectedHurt` pero NO están conectados a eventos. `__CollectGameEventCallbacks` no encuentra `OnGameEvent_*` methods, por lo que el sangrado nunca se aplica. Pendiente de fix.

Intención original: armas sharp (fireaxe, crowbar, machete, knife, katana, pitchfork) causan daño por sangrado (damage over time) a specials y comunes.

### `okkg_riotshieldbuff.nut` — Riot Shield Bloquea Specials
**Namespace:** `okkg_RiotShieldBuff`

El riot shield bloquea habilidades de special infected si el survivor está mirando hacia el atacante:
- ✅ Smoker tongue
- ✅ Hunter pounce/lunge
- ✅ Jockey ride
- ✅ Charger charge/impact
- ✅ Boomer vomit
- ✅ Tank rock
- ❌ NO bloquea spitter acid (no implementado)

Incluye efectos de sonido (sonidos personalizados en `sound/weapons/riotshield/`).

### `riotshield_henrietta_.nut` — Riot Shield Damage Reduction
**Namespace:** `HenriettaRiotReduction`

El riot shield otorga:
- 40% reducción de daño desde el frente
- 1.3× daño desde atrás
- Daño por tipo de infected configurable al ser incapacitado
- Soporte de archivo de configuración

### `electric_axe.nut` — Hacha Eléctrica
**Namespace:** `kuro_UnderSG_melee`

Sistema de hacha cuerpo a cuerpo con efectos eléctricos/rayo:
- Muzzle flash y partículas de tracer
- Efectos de lightning strike en impactos
- Daño celestial configurable (1000)
- Conteo de swings
- Comandos por chat
- Precarga de partículas y sonidos

---

## Miniguns y Torretas

### `mounted_system.nut` — Mounted Weapons System
**Namespace:** `::L4CWI_Mounted`

Sistema modular que fusiona `minigungib`, `mountedgunbulletsexplode` y `minigun_shake`:

- **Minigun Gibs:** Los comunes muertos por la minigun montada sufren desmembramiento con sets de heridas por tipo de zombie.
- **Torreta Explosiva:** Las balas de la torreta montada L4D2 (`prop_minigun`) explotan al impactar. **Refactorizado a MaoLib.AoE** (v2.4). Ahora afecta a **todos los tipos de entidad**: commons (`infected`), special infected (`player`), y `witch`. Daño configurable, radio 300, stagger probabilístico, partículas y screen shake. Preserva lógica original: falloff manual por distancia, friendly fire para survivors, stagger probabilístico para SI.
- **Minigun Shake:** Screen shake al disparar la minigun L4D1 (`prop_minigun_l4d1`).

---

## Items y Consumibles

### `pain_pills.nut` — Config de Píldoras
Ajusta `pain_pills_decay_rate = 0.24` para controlar la velocidad de degradación del health temporal.

### `overdose_pills.nut` — Sistema de Overdosis
**Namespace:** `::OverdosingAddon` + `::OverdosePlayers`

Cada uso de píldoras reduce la vida máxima en 10 HP. Después de 5 píldoras (configurable via `::L4COV_MaxOverdosePillsLimit`), el jugador muere instantáneamente. El contador persiste entre rondas.

### `savelogicpills.nut` — Config Loader para Pills
**Namespace:** `::SaveOptionsPills`

Carga/configura archivo `sharepills_config.txt` con valores `healRadius` y `tempHealth` para el sistema de curación compartida.

### `fasterreload_syr.nut` — Recarga Rápida con Adrenalina
**Namespace:** `ChCh_AdrenReloads`

La velocidad de recarga aumenta 50% mientras el jugador tiene adrenalina activa.

### `auto_upgrade.nut` — Compartir Upgrade Packs
**Namespace:** `::UpgradeShare`

Cuando un jugador usa un pack de upgrade (munición incendiaria/explosiva), el upgrade se comparte con TODOS los survivors vivos. El pack entity se despawna.

### `aoe_incendiary.nut` — Fuego en Impacto Incendiario
**Namespace:** `aoe_incendiary_geeb`

Los disparos con munición incendiaria crean parches de fuego AoE al impactar el suelo. Configurable via archivo (`overheat_chance`).

### `heldcans.nut` — Carried Props Explotables
**Namespace:** `heldcans`

Los objetos que los survivors llevan en manos (gascan, propanetank, oxygentank, firework crate, gnome, cola bottles) pueden ser disparados por friendly fire, causando explosiones, fuego y efectos especiales.

### `item_buffs.nut` — Buffs de Items
**Namespace:** `::g_ItemBuffs`

- Los medikits curan a survivors cercanos (radio 110) con 1 HP por tick (cada 10s)
- El gnome hace daño especial al ser lanzado
- Otros buffs de items

---

## Sistemas de Combate

### `woundfeedback.nut` — Wound/Bleed Damage System
**Namespace:** `::WoundFeedback`

Sistema de heridas y daño por sangrado:
- Impactos de bala causan ticks de herida que dañan con el tiempo
- Heridas en infected activan efecto de timescale (cámara lenta)
- Usa `func_timescale` para slow-motion
- Rastrea heridas por entidad

### `hitmarker.nut` — Audio Hitmarker
**Namespace:** `::hitMarker`

Sistema de hitmarker auditivo:
- Reproduce sonidos al golpear special infected
- Configurable para comunes y bots
- Cooldown de sonido anti-spam
- Estado por jugador

### `killsound.nut` — Headshot/Fatal Kill Sounds
**Namespace:** `KillSound`

Reproduce sonidos de kill/headshot cuando survivors incapacitan o matan special infected. Cooldown para evitar spam.

### `killeffect.nut` — Headshot Kill Effects
**Namespace:** `::KillEffect`

- Headshots matan con efecto de partículas fan
- Reduce health de infected a 1 en headshots para forzar efectos de gib
- Selección de partículas por arma
- Setea `r_particle_timescale = 0.9375`

### `clipempty.nut` — Clip Empty Sound
**Namespace:** `::ClipEmpty`

Reproduce sonido de "clip vacío" (`clipempty_rifle.wav` / `clipempty_pistol.wav`) cuando un survivor dispara con el cargador vacío. Tiene cooldown y usa timer periódico.

### `lasc.nut` — Low Ammo Sound Cue
**Namespace:** `::LASC`

Reproduce un sonido "click.wav" cuando la munición del arma baja de ~20-30% del cargador máximo, como advertencia de poca munición. Ignora la minigun montada (weaponid 54).

---

## Visuales y Sonido

### Sonidos Personalizados

| Archivo | Uso |
|---------|-----|
| `sound/weapons/clipempty_rifle.wav` | Clip vacío rifles |
| `sound/weapons/clipempty_pistol.wav` | Clip vacío pistolas |
| `sound/weapons/riotshield/riotshield_block1-5.mp3` | Bloqueo de shield |

### Materiales HUD

| Archivo | Uso |
|---------|-----|
| `materials/vgui/hud/gascan.vmt/vtf` | Icono HUD gascan |
| `materials/vgui/hud/propane.vmt/vtf` | Icono HUD propane |
| `materials/vgui/hud/oxytank.vmt/vtf` | Icono HUD oxytank |
| `materials/vgui/hud/gnome.vmt/vtf` | Icono HUD gnome |
| `materials/vgui/hud/fireworks.vmt/vtf` | Icono HUD fireworks |
| `materials/vgui/hud/cola.vmt/vtf` | Icono HUD cola |
| `materials/vgui/hud/doublebarrel.vmt/vtf` | Icono HUD double barrel |

### `propdata.txt`
Define clases de datos para props físicos con modificadores de daño (balas, clubs, explosivos), blockLOS y AIWalkable settings. 881 líneas de datos de props.

---

## Mecánicas de Infectados

### `infected_disarm.nut` — Infectados Desarman
**Namespace:** `infecteddisarm`

Los infectados tienen probabilidad configurable de desarmar (knockear el arma) a survivors al golpearlos:
- Probabilidad normal: 1/15 (~6.6%)
- Probabilidad low health (<20 HP): 1/45 (~2.2%)

### `bile_slow.nut` — Bile Frena Specials
(Visto en [Granadas y Explosivos](#granadas-y-explosivos))

---

## Sistema de Overdosis de Píldoras

### `overdose_pills.nut` — Sistema Completo
**Namespace:** `::OverdosingAddon`

- Cada píldora usada reduce la vida máxima en 10 HP permanente
- Límite de 5 píldoras (configurable via `::L4COV_MaxOverdosePillsLimit`)
- Al exceder el límite: muerte instantánea con la leyenda "OVERDOSE"
- El contador persiste entre rondas (no resetea en round_start)
- Resetea solo en new map o campaign start
- Compatible con pain_pills y adrenaline

**Variables Globales:**
| Variable | Default | Descripción |
|----------|---------|-------------|
| `::L4COV_MaxOverdosePillsLimit` | 5 | Máx píldoras antes de overdose |
| `::OverdosePlayers` | `{}` | Estado de overdose por jugador |

---

## Single Grab Weapons

### `sgw_main_script.nut` — Single Grab Weapons System
**Namespace:** `::g_SGW_Main`

Asignado como vscript de entidad `logic_versus_random`. Maneja:
- **`OnGameEvent_weapon_drop`:** Cuando se suelta un arma con `m_upgradeBitVec == 0`, fuerza `m_upgradeBitVec = 1` temporalmente (previene pickup infinito de upgrades)
- **`OnGameEvent_spawner_give_item`:** Limpia modelos duplicados de items, despawnando el spawner después de dar el item
- **`OnGameEvent_round_start`:** Limpieza inicial de entidades

### `mapspawn_addon.nut` — Spawneo de Entidades
Spawnea al cargar el mapa:
- `env_soundscape_triggerable` con vscripts `item_buffs`
- `logic_versus_random` con vscripts `sgw_main_script`
- Cleanup en `round_end`

---

## Weapon Data Overrides (.txt)

### Armas Primarias (Tier 2)

| Archivo | Arma | Punch/Spread |
|---------|------|-------------|
| `weapon_rifle.txt` | M16 | Punch 3.9, Spread 6.0→20, Decay 7.95 |
| `weapon_rifle_ak47.txt` | AK-47 | Punch 1.26, Spread 1.18→50, Decay 9 |
| `weapon_rifle_desert.txt` | Combat Rifle (SCAR) | Punch 1.78, Spread 2.0→20 |
| `weapon_smg.txt` | Uzi | Punch 0.0, Spread 0.94→35, Decay 6 |
| `weapon_smg_mp5.txt` | MP5 | Punch 2.90, Spread 3.15→30 |
| `weapon_autoshotgun.txt` | Auto Shotgun | Punch 3.65, Spread 40→120 |
| `weapon_shotgun_spas.txt` | SPAS-12 | Punch 3.38, Spread 0.10→10, Decay 15 |
| `weapon_hunting_rifle.txt` | Hunting Rifle | Punch 6.5, Spread 20→50, Decay 10 |

### Armas Primarias (Tier 1)

| Archivo | Arma | Punch/Spread |
|---------|------|-------------|
| `weapon_rifle_sg552.txt` | SG552 | Punch 2.95, Spread 0.85→15, Decay 2.5 |
| `weapon_smg_silenced.txt` | Silenced SMG | Punch 1.95, Spread 1.75→16 |
| `weapon_pumpshotgun.txt` | Pump Shotgun | Punch 9.21, Spread 20→120 |
| `weapon_shotgun_chrome.txt` | Chrome | Punch 3, Spread 80→80 |
| `weapon_sniper_scout.txt` | Scout | Punch 1.5, Spread 9.80→20 |

### Armas Especiales (Tier 0)

| Archivo | Arma | Punch/Spread |
|---------|------|-------------|
| `weapon_rifle_m60.txt` | M60 | Punch 1.75, Spread 30→60 |
| `weapon_sniper_military.txt` | Military Sniper | Punch 1.15, Spread 6.85→25 |
| `weapon_sniper_awp.txt` | AWP | Punch 10, Spread 30→60 (CSWeapon) |
| `weapon_grenade_launcher.txt` | GL | Punch 5, Spread 18→50 |

### Pistolas

| Archivo | Arma | Punch/Spread |
|---------|------|-------------|
| `weapon_pistol.txt` | Pistol | Punch 4.1, Spread 0.9→24 |
| `weapon_pistol_magnum.txt` | Magnum | Punch 5.45, Spread 20→36 |

### Carried Props

| Archivo | Arma | Notas |
|---------|------|-------|
| `weapon_gascan.txt` | Gas Can | MaxSpeed 250, carried_prop |
| `weapon_propanetank.txt` | Propane Tank | Modelo personalizado |
| `weapon_oxygentank.txt` | Oxygen Tank | Modelo personalizado |
| `weapon_gnome.txt` | Gnome | Damage 50, Range 4096 |
| `weapon_cola_bottles.txt` | Cola | Deploy rápido 0.001s |
| `weapon_fireworkcrate.txt` | Fireworks | carried_prop |

### Melee

| Archivo | Arma | Daño | Refire Delay |
|---------|------|------|-------------|
| `melee/fireaxe.txt` | Fire Axe | 200 | 1.2s |
| `melee/frying_pan.txt` | Frying Pan | 70 | 0.75s |
| `melee/shovel.txt` | Shovel | 80 | 1.0s |
| `melee/tonfa.txt` | Tonfa | 50 | 0.75s |
| `melee/electric_guitar.txt` | Electric Guitar | 200 | 1.0s |

### Items

| Archivo | Item |
|---------|------|
| `weapon_pain_pills.txt` | Pain Pills (weaponType=pistol) |
| `weapon_adrenaline.txt` | Adrenaline (weaponType=pistol) |
| `weapon_defibrillator.txt` | Defibrillator (weaponType=healing) |
| `weapon_chainsaw.txt` | Chainsaw (Tier 2, MaxSpeed 210) |

---

## Dependencias

- **MaoLib** (librería central de Lost 4 Creed) — Requerida para `maolib_vfx` (partículas, sonidos, screen shake). Auto-cargada via `IncludeScript("maolib", getroottable())` en `director_base_addon.nut`.
- **maolib_vfx** — Cargada automáticamente desde `maolib.nut`.

---

## Desarrollo

### Estructura de Archivos

```
l4cWeaponItemScripts/
├── addoninfo.txt
├── README.md
├── scripts/
│   ├── weapon_*.txt          (30+ weapon data overrides)
│   ├── melee/
│   │   └── *.txt             (5 melee data overrides)
│   ├── riotshield.txt
│   ├── melee_manifest.txt
│   └── vscripts/
│       ├── director_base_addon.nut   (entry point)
│       ├── mapspawn_addon.nut        (early load)
│       ├── core_system.nut           (framework base)
│       └── *_system.nut              (12 sistemas modulares)
├── sound/
│   ├── weapons/clipempty_*.wav
│   └── weapons/riotshield/*.mp3
└── materials/
    └── vgui/hud/*.vmt/vtf
```

### Scripts Sin Eventos (convar-only)
Estos scripts no registran callbacks — solo setean convars al cargar:
- `glauncher.nut` (dentro de explosives_system)
- `pain_pills.nut` (dentro de convars_system)
- `smg_headshot_wound.nut` (dentro de convars_system)
- `turnrate_shove.nut` (dentro de convars_system)

### Bugs Conocidos

1. **`melee_special_system.nut` (bleed melee):** Los handlers existen pero no están conectados a eventos. Falta agregar `OnGameEvent_*` methods o cambiar el patrón de registro.

---

## Changelog

### v2.4 — RRLogic System Refactor (2026-06-01)

**`rrlogic_system.nut` v1.2 → v2.0**

#### Desert Rifle — Rampage (Full-Auto Real)
- **Fix crítico:** El sistema anterior no hacía el arma automática. Solo reducía `m_flNextPrimaryAttack` pero el jugador seguía teniendo que hacer click manualmente para cada ráfaga.
- **Nueva técnica:** Timer a 100Hz que fuerza `m_isHoldingFireButton = 0` cuando el arma está lista y el jugador mantiene click. Esto engaña al motor iniciando la siguiente ráfaga inmediatamente.
- **Fire rate progresivo:** Intervalo entre ráfagas interpola linealmente de `0.12s` → `0.05s` durante `2.0s` de disparo continuo.
- **Ventaja sobre auto-scar de referencia:** No hardcodea animaciones ni cycletimes. Funciona con cualquier `CycleTime` configurado en `weapon_rifle_desert.txt`.
- **Integración RRLogic:** Recoil base se multiplica progresivamente (1.0× → 3.0×) según streak time.

#### Hunting Rifle — Bloodletter (MaoLib.AoE Refactor)
- **Refactor completo** del sangrado en área al sistema `MaoLib.AoE` (Selector → Aplicador).
- **Antes:** Búsquedas manuales con `Entities.FindByClassnameWithin` + daño plano.
- **Ahora:** `MaoLib.AoE.Select.Circle()` + `MaoLib.AoE.Apply.Damage()` con **falloff lineal**.
- Selecciona por separado: `infected`, `player` (filter `!IsSurvivor`), y `witch`.

#### Sistema de Debug Exhaustivo
- Añadido `Debug = 1` por defecto con logs `ENTER/EXIT/ABORT` en cada función.
- Valores clave logueados: stacks de bleed, hits de AoE, streak time, intervalo actual, recoil mult.
- `try/catch` en todos los callbacks de timers para evitar crashes silenciosos.

#### Limpieza y Robustez
- Cleanup de `DesertStreaks` y `HuntingBleeds` en `player_disconnect`.
- Uso de `::MaoLib.IsReal()` para validación de entidades.
- Closures correctos en todos los `AddTimerForce` (sin method detachment).

**`special_firearms_system.nut` — AWP Explosive Refactor**
- **Explosión garantizada:** La AWP ahora explota **siempre** al disparar, incluso si no impacta en nada (disparo al aire). Usa `TraceLine` desde el ojo del jugador para obtener el punto de impacto estimado.
- **Refactor a MaoLib.AoE:** Búsquedas manuales reemplazadas por `MaoLib.AoE.Select.Circle()` + `MaoLib.AoE.Apply.Damage()`.
- Afecta a: commons (`infected`), special infected (`player` !survivor), y `witch`.

**`mounted_system.nut` — Torreta Explosiva Refactor**
- **Refactor a MaoLib.AoE:** El daño en área de la torreta montada ahora usa `MaoLib.AoE.Select.Circle()` para seleccionar targets.
- **Afecta a todos los tipos:** Ahora daña commons (`infected`), special infected (`player`), y `witch` (antes solo afectaba a `player`).
- Preserva lógica original: falloff manual, friendly fire para survivors, stagger probabilístico para SI.

---

### v2.3 — Modular Architecture (2026-05-30)

- **Reestructuración completa:** 45+ scripts antiguos fusionados en 12 sistemas modulares:
  - `core_system.nut` — Framework base (config parser, debug, registry)
  - `firearms_system.nut` — M60 stagger + SG552 zoom
  - `special_firearms_system.nut` — AWP explosive + auto-fire + rip_and_tear + shotgun gib
  - `explosives_system.nut` — Atomic pipe + bile slow + GL screenshake + AoE incendiary
  - `feedback_system.nut` — Kill sounds + hitmarker + LASC + clip empty + wound feedback
  - `items_system.nut` — Auto upgrade + held cans + ammo limits + adrenaline + item buffs + overdose
  - `melee_base_system.nut` — Real reload + breakable melees
  - `melee_special_system.nut` — Bleed melee
  - `mounted_system.nut` — Minigun gib + turret explosions + minigun shake
  - `riotshield_system.nut` — Damage reduction + blocking
  - `flamethrower_system.nut` — Fuel-based melee with fire
  - `rrlogic_system.nut` — Hunting Bloodletter + Desert Rampage
- **Nuevo sistema de configuración:** Archivos `.cfg` en `l4cwi_config/` con parser unificado.
- **Debug centralizado:** `::L4CWI_Core.Dbg()` con prefix por sistema.

*Last updated: 2026-06-01*
