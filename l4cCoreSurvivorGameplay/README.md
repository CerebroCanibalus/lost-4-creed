# l4cCoreSurvivorGameplay — "Gameplay de Supervivientes" v3.3

**Addon:** Lost 4 Creed — Survivor Gameplay  
**Author:** Lost 4 Creed Team  
**Entry Point:** `scripts/vscripts/director_base_addon.nut`  
**Dependencias:** MaoLib (l4cCoreAddon)  
**Tamaño:** ~512 KB (~25 scripts)

---

## 📋 Descripción

Addon de gameplay centrado en los supervivientes: mecánicas de **dash**, **perks por personaje únicos** (system_perks), sistema de **IA de bots** (MIA - Minimal Intervention AI), movimiento táctico, sustos, y sonidos de eventos.

---

## 🏗️ Estructura

```
director_base_addon.nut
├── system_perks_unified.nut         → Perks monolítico (8 chars + equipment + events)
├── system_attributes.nut            → Speed/weight/friction engine
├── system_dash.nut                  → Dash + input handling
├── system_combat.nut                → FX + Util + FriendlyShove
├── survivor_ai_overhaul.nut         → MIA - IA de bots
├── sa_config.nut                    → Config de SurvivorAI
├── sa_items.nut                     → Sistema de items (recoger/usar/dar)
├── sa_core.nut                      → Loop principal de IA (per-bot think)
├── sa_detector.nut                  → Detecta fallos de IA vanilla
├── sa_executor.nut                  → Ejecuta intervenciones mínimas
├── sa_validator.nut                 → Validación de navmesh
├── sa_vision.nut                    → Sistema de visión proactivo
├── system_events_misc.nut           → Eventos + Sustos + Sonidos
└── weird_ai.nut                     → Comportamiento "raro" de bots
```

---

## 💨 Dashing System

**Namespace:** `::RespireSurvivorDash`

Sistema de dash (carrera/evasión) para supervivientes:

| Propiedad | Valor |
|-----------|-------|
| Cargas máximas | 2 |
| Impulse force | 340 |
| Duración | 0.8s |
| Recarga entre cargas | 2.6s |

- Usa técnica `SetOrigin` + `SetVelocity` (bypassea fricción del suelo)
- **Nota:** Algunos personajes modifican o reemplazan el dash (ver Perks)

---

## ⭐ Survivor Perks — system_perks v3.0

**Namespace:** `::SystemPerks`

Sistema modular de **8 perks únicos**, uno por personaje del cast custom. Los 8 supervivientes originales son reemplazados por el cast custom (ver `l4cSurvivorsCast`).

### 🎭 Mapeo de Personajes

| Modelo (mdl) | Personaje Custom | Rol | Equipo |
|-------------|-----------------|-----|--------|
| `survivor_teenangst.mdl` (Zoey) | **Brenda** | Líder A / Explosivos | A |
| `survivor_gambler.mdl` (Nick) | **Jason** | Líder B / Precisión | B |
| `survivor_namvet.mdl` (Bill) | **Chris** | Curandero / Veterano | A |
| `survivor_manager.mdl` (Louis) | **Jerry** | Spray & Pray / Artillero | A |
| `survivor_biker.mdl` (Francis) | **Phil** | Policía / Tanque | B |
| `survivor_mechanic.mdl` (Ellis) | **Sean** | Escucha / Scout | A |
| `survivor_coach.mdl` (Coach) | **Brock** | Tanque CEDA | B |
| `survivor_producer.mdl` (Rochelle) | **Jaime** | Glass Cannon | B |

### 🔥 Perks por Personaje

#### 1. BRENDA — Demolitions Expert
**Passive:** +30% bomb/fire damage for 5s after throwing explosive. Immune to self-fire.
**Active (Hold E):** Launch a **bomb gnome** that explodes after 2s (improved molotov). CD: 45s. Max 2 active.
**Trade-off:** 90 max HP +20% incoming damage.

#### 2. JASON — The Sharpshooter
**Passive:** +15% rifle damage. Headshots +25%.
**Active (SHIFT):** 3s of **zero recoil**. Each kill during Perfect Aim grants +2 temp HP (max 20). CD: 25s.
**Trade-off:** **No dash**. 15% slower movement speed.

#### 3. CHRIS — Combat Medic
**Passive:** Medkits heal +15 temp HP extra to target. Pills +15 temp HP to Chris. Revive: +10 temp HP to both.
**Active (E / IN_USE on ally in crosshair):** +25 temp HP +10% speed (5s). 5 recoil dmg on speed expire. CD: 45s. Requires direct LOS (trace line 200u).
**Trade-off:** Per nearby ally death within 300u: -3% max HP and speed (stacking).

#### 4. JERRY — Spray and Pray
**Passive:** +25% fire rate. +20% reload on automatics. Every 100 damage dealt = ammo to reserve.
**Active (R during reload):** Overcharge — reload instantly. Next magazine +50% ammo. CD: 35s.
**Trade-offs:** 33% double ammo consumption. +25% recoil on automatics. +15% SMG/shotgun damage.

#### 5. PHIL — Riot Cop
**Passive:** Starts with nightstick. +20% melee damage. Shoves stagger 50% more (re-stagger after 0.8s). -20% incoming common damage.
**Dash enhanced:** Kills commons on contact. Staggers SI. Area damage at end.
**Active (Mouse2 while grabbed):** Break free from SI. CD: 90s.
**Trade-off:** **Cannot be incapacitated** — dies instantly at 0 HP.

#### 6. SEAN — The Listener
**Passive:** Detects SI spawning within 500u (audio + HUD notification).
**Active (Crouch + stay still — progressive):** 1-6s reveals threats within 200-500u. 4 stages: proximity → medium → long range → direction only.
**Trade-off:** +15% reload speed penalty. 80 max HP. -30% SI damage resist / -20% weapon damage.

#### 7. BROCK — The CEDA Wall
**Passive:** Fire immune. -15% incoming damage. Allies within 200u: -10% common damage (aura).
**Active (SHIFT):** CEDA Protocol — 5s stagger immunity + -40% incoming damage + dash. CD: 35s.
**Trade-offs:** +1 shove penalty. -30% melee swing speed.

#### 8. JAIME — Glass Cannon
**Passive:** Stacks per infected killed (max 10). Each stack +5% damage. 0 stacks = -15% damage penalty. 5 stacks: milestone notify. 8+ stacks: 1 HP/s self-damage warning. Stacks decay if no kill in 10s.
**Active (SHIFT):** Consume all stacks. Lifesteal 20% (5s) +15% speed.
**Trade-off:** 100 max HP. **No dash**.

### ⚙️ Configuración

La configuración está **hardcodeada** en `BaseAttributes` dentro de `system_perks_unified.nut`.
No se usa archivo externo.

Para modificar valores, editar directamente `BaseAttributes` en `system_perks_unified.nut`:
```vscript
BaseAttributes = {
    brenda = { hpMax = 90, speedMult = 1.0, damageIn = 1.2 },
    jason  = { hpMax = 100, speedMult = 0.85 },
    // ... etc
}
```

---

## 🤖 MIA — Minimal Intervention AI v2.0

**Namespace:** `::SurvivorAI` · **7 módulos** · **Per-bot think via MaoLib timers** · **15+ tasks**

Filosofía: **solo interviene cuando la IA vanilla falla**. No toca bots que funcionan bien.

### Pipeline (por bot, cada 0.25s)

```
DetectTask → SURVIVE(100) → RESCUE(90) → COMBAT(80-55) → POSITION(50-40)
       ↓ null
DetectItemTask → ITEM_PICKUP(35) → ITEM_GIVE(25)
       ↓ null
DetectCloseDoor → CLOSE_DOOR(35)
```

### Features implementadas (Mayo 2026)

| Feature | Prioridad | Descripción |
|---------|-----------|-------------|
| **Per-bot think** | — | Cada bot con timer independiente MaoLib (vs 1 global) |
| **Entity cache** | — | Cachés de SI/Tanks vía eventos, no escaneo |
| **Tongue rescue** | 98-97 | Shove (150u) o shoot (800u) a Smoker que estrangula |
| **Event dodge** | 98 | Reacción a `spit_burst`, `charger_charge_start`, death acid |
| **Fall warp** | **100** | Teleport a compañero si vel vertical < -750 |
| **Heal interrupt** | 95 | Cancela med/defib si health ≥ 50 |
| **Auto nades** | 65-55 | Pipe→horda, molotov→tank, bile→humanos solo |
| **Item pickup** | 35 | Bot recoge throwables del suelo |
| **Item give** | 25 | Bot da throwable a humano sin uno |
| **Door close** | 35 | Cierra puertas checkpoint automáticamente |
| **Anti-pipebomb** | — | Kill pipebombs activas en map_transition |

### Módulos (7)

| Archivo | Rol |
|---------|-----|
| `sa_config.nut` | Config + constantes + runtime state |
| `sa_validator.nut` | Navmesh validation + safe positions |
| `sa_vision.nut` | Escaneo proactivo de amenazas |
| `sa_detector.nut` | Detecta fallos de IA vanilla |
| `sa_executor.nut` | Ejecuta intervenciones mínimas (15+ tasks) |
| `sa_items.nut` | **Nuevo** — Sistema de items auto-contenido |
| `sa_core.nut` | Per-bot think loop + eventos + cleanup |

### Config destacada

| Variable | Default | Qué hace |
|----------|---------|----------|
| `BotThinkInterval` | 0.25 | Think por bot (4Hz) |
| `UsePipeBomb` | 3 | 0=off, 1=horde, 2=tank, 3=ambos |
| `UseVomitjar` | **0** | Solo humanos — bile atrae horda |
| `FallWarpVelocity` | -750 | Umbral de caída fatal |
| `HealInterruptThreshold` | 50 | Cancela heal si salud ≥ esto |

[Ver documentación completa →](survivor_ai.md)

---

## 🎯 Movimiento Táctico

**Namespace:** `system_attributes.nut`

- Speed/weight/friction engine reemplaza tactical movement legacy
- Integrado con `MaoLib.Modifiers` para stacking automático
- Configuración hardcodeada en `BaseAttributes`

---

## 👻 Efectos Adicionales

| Script | Función |
|--------|---------|
| `jumpscare.nut` | Sustos aleatorios para los jugadores |
| `eventsnd.nut` | Sonidos contextuales en eventos |
| `weird_ai.nut` | Comportamiento impredecible de bots |

---

## 🔧 Dependencias

| Addon | Relación |
|-------|----------|
| l4cCoreAddon | **REQUERIDO** — Provee MaoLib (timers, utilidades) |
| l4cSurvivorsCast | **REQUERIDO** — Modelos y nombres de personajes custom |
| l4cWeaponItemScripts | **RECOMENDADO** — Compatibilidad con weapon scripts (Jason) |

---

## ⚠️ Notas Técnicas

### Integración con Dash
- Jason y Jaime **pierden dash completamente** (SHIFT = activa).
- Brock **reemplaza dash** con Protocolo CEDA (SHIFT = activa).
- Phil **mantiene dash** pero con efectos adicionales (mata commons + stagger).

### Hooks de Daño
- L4D2 VScript **no tiene hooks de daño pre-aplicación**.
- Las modificaciones de daño (+/- %) se aplican post-facto mediante `TakeDamage()` adicional o curación retroactiva.
- Esto es una limitación del engine, no del script.

### ⚠️ REGLAS CRÍTICAS DE EVENTOS L4D2

Basado en bugs encontrados en auditoría (2026-06-01):

| Evento | Campo daño | Tipo attacker | Bug común |
|--------|-----------|---------------|-----------|
| `player_hurt` | **`dmg_health`** (NO `damage`) | userid (`GetPlayerFromUserID`) | Usar `params.damage` → código muerto |
| `infected_hurt` | **`amount`** (NO `damage`) | userid (`GetPlayerFromUserID`) | Usar `params.damage` |
| `infected_death` | — | **entindex** (`EntIndexToHScript`) — EXCEPCIÓN | Usar `GetPlayerFromUserID` |

**Reglas de oro:**
1. `params.damage` **NO EXISTE** en ningún evento de L4D2
2. `player_hurt`: usar `params.dmg_health`, verificar con `!("dmg_health" in params)`
3. `infected_hurt`: usar `params.amount`, verificar con `!("amount" in params)`
4. Siempre null-check: `local p = GetPlayerFromUserID(params.userid); if (!p) return;`
5. `infected_death.attacker` = entindex — USAR `EntIndexToHScript`, NO `GetPlayerFromUserID`
6. `MaoLib.AddTimer` es **REPETITIVO** — usar `DelayCall(string, secs)` para one-shot
7. `MaoLib.AddTimer` NO sobrescribe duplicados — usar `AddTimerForce`

**Referencia:** [AlliedModders L4D2 Events](https://wiki.alliedmods.net/Left_4_Dead_2_events)

### Compatibilidad
- **rrlogic:** Jason y Jerry requieren compatibilidad con rrlogic para weapon scripts.
- **system_attributes:** Usa `MaoLib.Modifiers` para stacking automático de velocidad. No conflictúa con otros sistemas que también usen Modifiers.

### Legacy
- Scripts antiguos (`chch_survivor_perks.nut`, `bill_perk.nut`, `zoey_perk.nut`, `rochelle_perk.nut`) han sido **reemplazados**.
- Los 8 scripts `sp_*.nut` individuales fueron consolidados en `system_perks_unified.nut` (2026-06-07).
- `system_character.nut`, `system_perks.nut`, `sp_config.nut`, `system_movement.nut` eliminados.

---

## 📢 Sistema de Notificaciones

**Usa `MaoLib.HUD.Notify()`** (`mode = "center"`) para todo feedback de perks.

**Filosofía (Jun 2026):**
- **3 toques por habilidad:** Ready · Activated · Expired — nada más
- **Spawn message** una vez por vida: `"PERK NAME — Role tagline"`
- **Duración:** 0.8-1.5s máx — nada persistente
- **Modo:** solo `"center"` — nada de `"chat"` (spam), nada de `env_instructor_hint` (buggy, reemplazado)
- **Anti-spam:** `throttle` en todo mensaje repetible. `priority = "high"` solo para crítico
- **Sonido + partícula** como feedback primario — el texto refuerza, no reemplaza
- **Jason:** Se eliminó el countdown "PERFECT AIM X.Xs" cada 1s — el jugador siente el 0 recoil

### Mapa de notificaciones

| Perk | Spawn | Ready | Activación | Expiración | Umbral |
|------|-------|-------|------------|------------|--------|
| Brock | ✅ | ✅ CEDA PROTOCOL READY | ✅ CEDA PROTOCOL ACTIVE (5s) | ✅ CEDA PROTOCOL EXPIRED | — |
| Chris | ✅ | ✅ FIELD THERAPY READY | ✅ Applied therapy: +25 HP | ✅ Therapy wear-off: -5 HP | — |
| Brenda | ✅ | ✅ GNOME READY — Press [R] | ✅ Gnome away! | — | — |
| Jerry | ✅ | ✅ OVERCHARGE READY | ✅ OVERCHARGE: +X rounds | — | — |
| Jason | ✅ | — | ✅ PERFECT AIM — ZERO RECOIL | ✅ PERFECT AIM EXPIRED (25s CD) | — |
| Phil | ✅ | ✅ BREAK FREE READY | ✅ GRABBED — RMB to break free! | — | — |
| Jaime | ✅ | ✅ FOCUS FIRE READY | ✅ FOCUS FIRE ACTIVE (Xs) | — | ✅ ×5 stacks / ×8 self-damage |
| Sean | ✅ | — | ✅ SEAN: X special(s) detected | — | — |

---

## 🔄 Changelog

### v3.4 (2026-06-07)
- **Nuevo (SISTEMA):** `system_perks_unified.nut` — Sistema monolítico unificado. Consolida 12 scripts en 1: 8 perks individuales (`sp_*.nut`) + `system_character.nut` + `system_perks.nut` + `sp_config.nut` + `system_movement.nut`
- **Eliminados:** 13 scripts muertos (8 sp_*.nut, system_character.nut, system_perks.nut, sp_config.nut, system_movement.nut, system_movement.nut.backup)
- **Configuración:** Hardcodeada en `BaseAttributes` — ya no depende de `sp_config.nut`
- **Eventos:** UNA tabla de eventos → CERO race conditions. 13 handlers unificados
- **Notificaciones:** Spawn message "PERK NAME — Role tagline" + 3 líneas concisas (Passive/Active/Trade-off)
- **Balance:** Títulos corregidos (sin "The" al inicio). Textos en inglés

### v3.3 (2026-06-02)
- **Nuevo (SISTEMA):** Sistema de notificaciones unificado vía `MaoLib.HUD.Notify` — todos los perks ahora usan `mode = "center"`, duración 0.8-1.5s, y throttle configurable
- **Nuevo (SISTEMA):** Spawn message "PERK NAME — Role tagline" una vez por vida para los 8 perks
- **Nuevo (SISTEMA):** Callbacks de expiración vía `MaoLib.StatusEffects.RegisterCallback` (Brock CEDA Protocol)
- **Nuevo (Brock):** Notificación "CEDA PROTOCOL EXPIRED" al terminar la inmunidad
- **Nuevo (Chris):** Confirmación "Applied therapy: +25 HP" al curar aliado + "Therapy wear-off: -5 HP" al expirar speed
- **Nuevo (Brenda):** Confirmación "Gnome away!" al lanzar gnomo
- **Nuevo (Jason):** Perfect Aim — 3s duración, 25s CD, zero recoil via rrlogic, +2 temp HP por kill durante activo. Eliminado countdown spam "PERFECT AIM X.Xs" cada 1s
- **Nuevo (Jaime):** Notificaciones de umbral: ×5 stacks (+25% damage) y ×8 stacks (self-damage warning)
- **Nuevo (Sean):** Reemplazo completo de `env_instructor_hint` (buggy, entity leak) por `MaoLib.HUD.Notify` + sonidos. Nueva función `NotifySean()` y `CountTargets()`
- **Corregido (Jerry):** AutoNotify cambiado de `"chat"` a `"center"` — consistencia global
- **Corregido (Jaime):** AutoNotify cambiado de `"chat"` a `"center"`
- **Corregido (Phil):** `player_death` ahora usa `PlayerState.Clear` en vez de deletes parciales — incluye limpieza del flag `phil_welcomed`
- **Corregido (Jerry):** Cooldown message cambiado de `"chat"` a `"center"` con `throttle = 2.0`
- **Traducido:** Todos los textos de HUD/perks de español a inglés (mod para audiencia global)
- **Balance (Phil):** +40% → +20% daño melee
- **Balance (Jaime):** +8% → +5% daño por stack (máx 80% → 50%)
- **Balance (Jason):** Rifle +25% → +15%, Headshot +50% → +25%
- **Balance (Jerry):** +30% → +15% daño SMG/shotgun. Nuevo: +25% recoil penalty en automáticas
- **Balance (Chris):** Speed boost 1.15×8s → 1.10×5s. Nuevo: 5 recoil dmg al expirar. Trace line check para apuntar a aliado
- **Keith verified:** Todos los cambios pasan verificación. 0 bugs funcionales.

### v3.2 (2026-06-01)
- **Corregido (CRÍTICO):** `system_movement.nut` — SettingsLog spameaba cada 0.3s. `AddTimer` es REPETITIVO, no one-shot. Reemplazado por `DelayCall`.
- **Corregido (CRÍTICO):** `sp_jason.nut` — Código 100% muerto: guard `!("damage" in params)` SIEMPRE true porque `damage` no existe en `player_hurt`. Fix: `dmg_health`. Jason nunca aplicaba bonus de daño.
- **Corregido (CRÍTICO):** `sp_brenda.nut` — Mismo bug: 2 usos de `params.damage` + guard inválido. Brenda nunca aplicaba trade-off ni pasiva.
- **Corregido (CRÍTICO):** `system_events_misc.nut` — 3 null crashes: `GetPlayerFromUserID` sin null check en `door_open`, `player_say`, `weapon_reload`.
- **Corregido (ALTO):** `system_perks.nut` — `ShowCharacterInfo` nunca se invocaba. No había feedback en chat al spaw near. Agregado evento `player_spawn`.
- **Corregido (MEDIO):** `system_movement.nut` — `round_start` usaba `AddTimer` para recrear timer existente (fallaba silenciosamente). Cambiado a `AddTimerForce`.
- **Corregido (BAJO):** `system_movement.nut` — `round_end` reseteaba `init_guard` innecesariamente. Eliminado.
- **Auditoría:** 25 archivos auditados, 0 bugs restantes. Keith verified.

### v3.1 (2026-05-31)
- **Nuevo:** Per-bot think distribuido (MaoLib timers) — reemplaza info_target global
- **Nuevo:** Tongue Rescue — shove/shoot a Smoker que estrangula compañero
- **Nuevo:** Event-driven dodge — reacción a `spit_burst`, `charger_charge`, death acid
- **Nuevo:** Auto nades con targeting inteligente — pipe→horda, molotov→tank, bile→humanos solo
- **Nuevo:** Fall warp — teleport a compañero en caída fatal
- **Nuevo:** Heal interrupt — cancela med/defib si health ≥ 50
- **Nuevo:** Item system (`sa_items.nut`) — pickup del suelo + give a humanos
- **Nuevo:** Saferoom door close automático
- **Nuevo:** Anti-pipebomb bug en map_transition
- **Mejorado:** Entity cache por eventos (menos escaneos, más rendimiento)
- **Mejorado:** ExecuteThrowNade usa SwitchToItem + fire/release
- **Corregido:** Method detachment en ExecuteCloseDoor
- **Corregido:** Probability() con namespace `::MaoLib.Probability()`
- **Corregido:** foreach userid shadowing en detectores
- **Corregido:** Door check ahora después de DetectTask (no antes)

### v3.0 (2026-05-30)
- **Nuevo:** Sistema modular `system_perks/` con 8 perks únicos
- **Corregido:** Mapeo de personajes corregido según SurvivorCast
- **Eliminado:** Scripts legacy de perks individuales
- **Mejorado:** Estructura consolidada de movement/combat

### v2.3 (2026-05-28)
- Consolidación de scripts dispersos en `system_movement.nut` y `system_combat.nut`
- Migración de dashing, tactical movement, FX, utilidades

---

*Last updated: 2026-06-07*
