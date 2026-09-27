# SurvAI v3 — Utility AI con Blackboard (PLAN MAESTRO)

> **Estado:** PLANIFICADO (2026-08-09) | **Sistema:** `sa_*` (7 módulos, ~2,850 líneas) | **Addon:** l4cCoreSurvivorGameplay
> **Filosofía:** human-like, NO dioses. Bots competentes que también fallan, exploran, hacen chorradas y esperan al equipo. Un solo pipeline (sin modos separados), comportamientos repetibles: mismo estado → misma decisión.

---

## 1. PROBLEMA (por qué rediseñar)

El sistema actual es "Minimal Intervention" con **prioridades fijas** (`if` anidados: SURVIVE 100 → RESCUE 90 → ... → ADVANCE 30). Esto crea 2 modos implícitos:

- **Con humano:** vanilla AI sigue al humano; SurvAI solo interviene cuando falla. ✅ Funciona.
- **Sin humano (all-bot):** vanilla AI NO avanza (no hay a quien seguir). El parche `DetectAdvanceTask()` (prioridad 30, la más baja) NUNCA se alcanza porque `DetectTask()` devuelve `ATTACK_COMMON` (75) casi siempre (los commons se acumulan alrededor de bots estáticos). ❌ ROTO.

**Causa raíz:** el avance es una prioridad FIJA y BAJA, no una consideración DINÁMICA. El pipeline asume "no task = vanilla ok", pero en all-bot vanilla no hace nada.

**Fix:** Utility AI — el avance es UNA consideración más con score dinámico (sube en SAFE, baja en COMBAT). Un solo pipeline para ambos casos.

---

## 2. ARQUITECTURA — Utility AI con Blackboard

```
BotThink(bot)
├── 0. PERCEPCIÓN (caché 0.15s)
│   ├── VisionScan → amenazas visibles (LOS)
│   ├── TeamState → fase del equipo (SAFE/ALERT/COMBAT/EMERGENCY)
│   └── FlowState → flow del bot, del líder, del equipo
├── 1. BLACKBOARD (estado compartido, actualizado 1x/tick global)
│   ├── TeamPhase, Leader, AdvanceTarget, Threats, PointsOfInterest
├── 2. UTILITY SCORES (cada consideración devuelve 0-100)
│   ├── SURVIVE   score = f(distancia, tipo peligro)
│   ├── RESCUE    score = f(timeout pin, distancia)
│   ├── COMBAT    score = f(distancia SI, visibilidad)
│   ├── ADVANCE   score = f(flow gap, sin amenazas, quietud)  ← sube en SAFE
│   ├── EXPLORE   score = f(puntos de interés sin revisar, fase SAFE)
│   ├── REGROUP   score = f(separación del equipo)
│   └── ITEM      score = f(necesidad, distancia)
├── 3. ARBITER: gana la consideración con mayor score
├── 4. EXECUTE: ejecuta (executors actuales NO se tocan)
└── 5. DEBUG: blackboard visible (task, reason, score)
```

**Escalable:** añadir comportamiento = añadir 1 consideración con su score function. No tocar el pipeline.

**Módulos nuevos:**
| Archivo | Rol |
|---------|-----|
| `sa_team.nut` | TeamState (fases), FlowState, Leader dinámico, blackboard |
| `sa_utility.nut` | UtilityScores + Arbiter (elige consideración ganadora) |
| `sa_humanize.nut` | Humanización: reaction delay, fail chance, aim error, personality, idle behaviors |

**Módulos modificados:**
| Archivo | Cambio |
|---------|--------|
| `sa_core.nut` | BotThink usa arbiter en vez de ifs anidados |
| `sa_detector.nut` | Detectores → consideraciones (wrapper que devuelve score) |
| `sa_advance.nut` | GetNavAhead reescrito con flow gradient ascent |
| `sa_config.nut` | Constantes de scores, humanización, fases |

**Módulos intactos:** `sa_executor.nut`, `sa_validator.nut`, `sa_vision.nut`, `sa_items.nut`

---

## 3. INNOVACIONES — truquillos que NADIE usa

| # | Truco | Fuente | Impacto |
|---|-------|--------|---------|
| 1 | `NavMesh.NavAreaTravelDistance(a, b, max)` — distancia REAL por navmesh, -1 si no hay camino | l4d2node (binario) | **Flow distance nativo.** Avance por gradiente de flow, NO por mirada |
| 2 | `CTerrorPlayer.GetLastKnownArea()` — área nav actual del bot | l4d2node | Sin GetNearestNavArea por bot — más barato y preciso |
| 3 | Líder dinámico por flow (no Zoey/Nick fijo) | Diseño propio | El bot con mayor flow lidera. Si muere, otro toma el rol |
| 4 | Safety gate con `NavAreaTravelDistance`: verificar camino de VUELTA antes de avanzar | Buddy Bots (idea) | Fail-closed: nunca avanzar a zona sin retorno |
| 5 | `TerrorNavArea.IsCompletelyVisibleToTeam(team)` — visibilidad táctica SIN TraceLine | l4d2node | Posiciones de combate visibles desde el equipo, gratis |
| 6 | Cache de áreas por ID (`GetID()` + `GetNavAreaByID()`) | Diseño propio | Referencias como ints, sin handles muertos |
| 7 | Percepción retardada por bot (delay 0.1-0.4s aleatorio) | Buddy Bots | Humanización GRATIS + evita sincronización de postura |
| 8 | Combate mientras avanza: `CommandABot(cmd=1)` + `IN_ATTACK` forzado | Diseño propio | Disparan MIENTRAS caminan (no se puede combinar cmd=0+cmd=1) |
| 9 | TeamPhase compartido (SAFE/ALERT/COMBAT/EMERGENCY) | Buddy Bots | Unifica comportamiento con/sin humanos |
| 10 | Cvars vanilla como base (`sb_allow_leading 0`, `sb_separation_range`, `sb_threat_*_range`) | Improved Bots | Ajustar IA vanilla ANTES de intervenir |

**⚠️ CommandABot desactiva la IA vanilla del bot mientras está comandado** ("blindly follow the command until a new one is issued"). Implicación: re-comandar cada tick o el bot se queda parado al llegar. No combinar cmd=0+cmd=1 en un solo comando.

---

## 4. HUMANIZACIÓN — "human-like, NO dioses"

**REQUISITO DEL GENERAL:** bots buenos pero NO perfectos. Fallan como humanos. NO matan todo a lo terminator.

### 4.1 Mecánicas de fallo (sa_humanize.nut)
| Mecánica | Implementación | Config |
|----------|----------------|--------|
| **Reaction delay** | Cada bot tiene `reactionTime` aleatorio (0.1-0.4s) por acción — no reaccionan al instante | `ReactionDelayMin/Max` |
| **Dodge fail chance** | 5-15% de NO esquivar (configurable por dificultad) | `DodgeFailChance` |
| **Aim error** | Offset angular aleatorio en ataques (no siempre headshot) | `AimErrorDegrees` |
| **Decision noise** | 10% de veces elegir posición subóptima (no siempre la mejor) | `DecisionNoiseChance` |
| **Per-bot personality** | Seed por userid → bot "torpe" (más fallos) vs bot "fiable" (menos) | `GetPersonality(bot)` |

### 4.2 Idle behaviors — "chorradas" (sa_humanize.nut)
| Comportamiento | Descripción | Trigger |
|----------------|-------------|---------|
| **Point of interest** | Mirar escaparates, objetos, carteles (breve glance) | Fase SAFE, sin amenazas |
| **Check corners** | Revisar un rincón/habitación lateral antes de seguir | Fase SAFE, cerca de POI |
| **Crouch glance** | Agacharse brevemente (IN_DUCK 0.5s) como si mirara algo | Aleatorio en SAFE |
| **Wait for teammate** | Esperar si el equipo está lejos (hold position) | Separación > umbral |
| **Stretch/check weapon** | Pequeña pausa de "revisar arma" (sin acción, solo delay) | Aleatorio en SAFE |

**Budget:** máx 1 initiator + 1 joiner por idle (evitar que todo el equipo haga lo mismo a la vez).

### 4.3 Exploración por capas
- El **líder** avanza al waypoint principal (flow gradient).
- Los **seguidores** "barren" la zona: checkean POIs laterales antes de seguir.
- Un bot puede **quedarse atrás** revisando un área mientras el resto avanza.
- No todos avanzan en línea recta — exploran lateralmente (EXPLORE consideration).

### 4.4 Anti-dios (reglas duras)
- NO aim perfecto (error angular).
- NO reacción instantánea (delay).
- NO conocimiento omnisciente (percepción limitada por LOS).
- NO teleport como solución (solo unstuck visible, con cooldown).
- NO matar todo: a veces eligen cubrirse (COVER) en vez de pelear.
- NO usar `sb_vomit_blind_time 0` (eso es trampa — los bots deberían quedar ciegos).

---

## 5. FASES

### Fase 0 — Diagnóstico y baseline (opcional, 30min)
- [ ] Activar `DebugEnabled = true` en sa_config.nut
- [ ] Capturar logs actuales en all-bot (confirmar ATTACK_COMMON bloquea avance)
- [ ] Documentar comportamiento actual como baseline de regresión

### Fase 1 — Fundación: Utility AI + Blackboard (bajo riesgo) ✅ COMPLETADA (2026-08-09)
- [x] Crear `sa_team.nut`: TeamState (fases), FlowState, Leader dinámico, blackboard
- [x] Crear `sa_utility.nut`: UtilityScores + Arbiter
- [x] Modificar `sa_core.nut`: BotThink usa arbiter
- [x] Convertir detectores actuales → consideraciones (wrapper que devuelve score)
- [x] Executors intactos
- [x] Fix: cooldown de NADE movido al executor (el detector ya no gasta el cooldown de 30s si su task no gana)
- **Criterio:** regresión cero — mismo comportamiento que antes, pipeline nuevo ✅ (tiers replican la cascada; task conserva priority original para cooldown check)

### Fase 2 — Avance por flow (medio riesgo — el cambio clave) ✅ COMPLETADA (2026-08-09)
- [x] `GetBotFlow` real: `NavAreaTravelDistance(MapStartArea, area, 16384)` + cache por `area.GetID()` (patrón system_events_misc.nut L521)
- [x] `CacheMapStartArea()` en `round_start_post_nav` (área del primer survivor = inicio del mapa)
- [x] Líder dinámico por flow (`GetDynamicLeader`): mayor flow + histéresis `LeaderFlowHysteresis=200` (anti-flapping) + fallback Zoey>Nick si no hay flow info
- [x] `GetNavAhead` reescrito: **flow gradient ascent** — área con mayor flow alcanzable en `AdvanceNavSearchRadius` (600u), sin depender de la mirada
- [x] **Safety gate** (fail-closed): `NavAreaTravelDistance(best, currentNav)` — nunca avanzar a zona sin camino de VUELTA (solo para el mejor candidato, coste 1 A*)
- [x] Fallback flow (radio 2000u) también por mayor flow + safety gate
- [x] Early-exit en arbiter: `maxScore` por consideración — si `bestScore >= c.maxScore` break (correcto con scores dinámicos porque compara contra el MÁXIMO posible)
- [x] ADVANCE score dinámico: 350 SAFE, 250 ALERT, 150 COMBAT/EMERGENCY (COMBAT 600 gana igual — prepara Fase 3)
- [x] `HasNearbyThreats` en all-bot: solo SI/tank bloquean (ya hecho en fix 4)
- **Criterio:** en all-bot, los 4 bots avanzan por c1m1-c1m4 sin intervención — PENDIENTE VALIDAR EN JUEGO

### Fase 3 — Formación + combate-avance + PERCEPCIÓN CENTRALIZADA (medio riesgo)
- [ ] **Percepción centralizada** (movida de Fase 2 — el esqueleto Fase 1/2 deja los detectores escaneando; con +6 consideraciones en Fase 4 el coste crece): migrar detectores a LEER del blackboard (VisionScan + TeamState + FlowState alimentan 1x/0.15s; las consideraciones solo leen). PREREQUISITO de Fase 4
- [ ] Roles point/relay/rear/flex (rotativos por flow distance)
- [ ] Combate mientras avanza: `CommandABot(cmd=1)` + `IN_ATTACK` forzado
- [ ] Point se posiciona en high ground (`FindHighGround`), rear cubre choke points (`FindChokePoints`)
- **Criterio:** bots avanzan Y pelean simultáneamente

### Fase 4 — Humanización (medio riesgo)
- [ ] `sa_humanize.nut`: reaction delay, dodge fail, aim error, decision noise, personality
- [ ] Idle behaviors: POI glance, check corners, crouch glance, wait for teammate
- [ ] Exploración por capas (EXPLORE consideration)
- [ ] Anti-dios: COVER consideration, sin trampas
- **Criterio:** bots se sienten humanos, no terminator

### Fase 5 — Pulido (bajo riesgo)
- [ ] Debug blackboard (`hbot_dump`-style: task, reason, score por bot)
- [ ] Tuning de scores (balance por dificultad)
- [ ] Test completo: c1m1-c1m4 all-bot + con humano
- [ ] Actualizar `survivor_ai.md` (documentación técnica v3.0)
- **Criterio:** logs claros, sin crasheos, comportamiento consistente

---

## 6. CRITERIOS DE ÉXITO (honestos y reales)

1. **All-bot:** los 4 bots completan c1m1-c1m4 sin intervención humana.
2. **Con humano:** los bots siguen al humano (comportamiento actual NO se rompe).
3. **Humanización visible:** los bots fallan a veces, exploran, hacen pausas, esperan al equipo.
4. **Sin crasheos:** ningún error de sintaxis, method detachment, ni timer zombie.
5. **Logs claros:** `[SurvivorAI][ADVANCE]`, `[SurvivorAI][EXPLORE]`, `[SurvivorAI][HUMANIZE]` visibles con DebugEnabled.
6. **Rendimiento:** sin "think takes too much time" — cache de NavUtils + percepción 0.15s.

---

## 7. RIESGOS Y MITIGACIONES

| Riesgo | Mitigación |
|--------|------------|
| CommandABot desactiva vanilla AI | Re-comandar cada tick; no dejar bots "huerfanos" de comando |
| NavAreaTravelDistance costoso | Cachear por par de áreas (NavUtils ya cachea BuildPath) |
| Humanización rompe utilidad | Scores con noise acotado (10%), nunca > 30% del score |
| Fases rompen funcionalidad | Cada fase es incremental; Fase 1 = regresión cero |
| Timer zombie | Cleanup en round_end/mission_lost/map_transition (patrón estándar) |

---

## 8. REFERENCIAS

- **Buddy Bots (gxBBL4d2):** flow gradient ascent, formación point/relay/rear/flex, fases de equipo, percepción retardada, safety gate. [github.com/gxmst/gxBBL4d2](https://github.com/gxmst/gxBBL4d2)
- **Improved Bots (Advanced):** catálogo de cvars vanilla (`sb_allow_leading`, `sb_separation_range`, `sb_threat_*_range`, etc.)
- **Advanced Bot AI - Custom:** task scheduler + blackboard ("intent and task blackboard" — current task, reason, confidence, expiry, debug)
- **Left 4 Bots 2 (smilz0/Left4Bots):** fuente original del sistema actual
- **l4d2node:** 369 métodos recuperados del binario (NavAreaTravelDistance, GetLastKnownArea, IsCompletelyVisibleToTeam, etc.)
- **MaoLib.NavUtils:** BuildPath (A* cacheado), GetPathFlowDistance, GetFlowDistanceToSurvivors, IsAheadOfSurvivors, FindHighGround, FindChokePoints, FindFlankingRoutes

---

*Last updated: 2026-08-09*