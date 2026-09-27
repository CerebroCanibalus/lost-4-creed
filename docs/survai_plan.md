# SurvAI — BOT IMPROVEMENT PLAN v1.0

> Fuente: Left 4 Bots 2 (smilz0/Left4Bots) + AI Improver (Emana202). Filosofía: **human-like, NO dioses**. Bots competentes que también fallan (factor de aleatoriedad). No reemplazar vanilla AI — intervenir solo cuando falla (Minimal Intervention).

> ⚠️ **SHIFT (Caminar) = Dash en este modpack.** El bit `IN_SPEED` (131072) está remapeado a DASH (`::DASH_IN_SPEED`), y los botones de movimiento son `DASH_MOVE_FWD/BACK/LEFT/RIGHT`. **NUNCA usar `IN_SPEED` para "caminar lento"** — eso dispara el dash. Para movimiento lento (witch slowwalk) usar **`IN_DUCK` (agacharse)**.

## ✅ YA TENEMOS (NO rehacer)
Dodge spit/rock/charger/fire (con dash), SHOOT_TONGUE, RESCUE con timeouts, SHOVE probabilístico, ATTACK_SI, KITE_TANK, UNSTICK, REGROUP, FALL_WARP, throwables pickup/give, MAP ADVANCE, close_door, dash dodge, vision system (sa_vision), **Incap block near tank** (DetectIncapBlockTask), **Witch slowwalk** (IN_DUCK crouch), **Tank rock shooting** (DetectRockShootTask).

## 🎯 PRIORIDAD 1 — COPIA REALISTA (alto impacto, fácil)
| Feature | Fuente | Implementación |
|---------|--------|----------------|
| **Defib dead players** | L4B2 | Bot con defib + compañero muerto cerca → ir a revivir (CommandABot move + Use). Detectar defib en inventario (`GetInvTable` slot3). |
| **Heal interrupt** | L4B2 `heal_interrupt_minhealth=50` | Bot NO se cura con medkit si HP ≥ 50 (salvo que no haya humanos o sobren medkits). Reintroducir BIEN (el anterior se removió por bug de detección). |

## 🎯 PRIORIDAD 2 — MEDIO (más lógica)
| Feature | Implementación |
|---------|----------------|
| **Charger dodge timing** | Esquivar en último momento: `timeToImpact = dist/vel`; dodge si < 0.3s (L4B2 `dodge_charger_distdelay_factor`). |
| **Horde nades** | Pipe bomb si horda ≥ 10 en radio 450 (L4B2 `horde_nades_size`). Ya hay DetectNadeTask — verificar umbrales. |
| **Tank molotov** | Molotov a Tank si HP > 1500, dist 200-1300, cooldown 4s entre bots. |
| **Heal teammates** | Bot con medkit cura a compañero con HP < 30 (prioridad sobre self-heal). |
| **Team item quotas** | Mínimo 2 medkits / 1 shotgun / 1 molotov en equipo; bot swap si falta. |
| **Bot-to-bot item give** | Extender ITEM_GIVE a bots (no solo humanos). |

## 🎯 PRIORIDAD 3 — HUMANIZACIÓN (factor de aleatoriedad)
**REQUISITO DEL GENERAL:** bots buenos pero NO perfectos. Fallan como humanos.
- **Reaction delay**: cada bot tiene `reactionTime` aleatorio (0.1-0.4s) por acción — no reaccionan al instante.
- **Dodge fail chance**: 5-15% de NO esquivar (configurable por dificultad).
- **Aim error**: offset angular aleatorio en ataques (no siempre headshot).
- **Decision noise**: 10% de veces elegir posición subóptima (no siempre la mejor).
- **Per-bot personality**: seed por userid → bot "torpe" (más fallos) vs bot "fiable" (menos).
- Implementar como helpers en sa_config: `RollFail(bot, baseChance)`, `GetReactionDelay(bot)`.

## 🚫 NO COPIAR (no realista/mantenible)
- **Automation scripts por campaña** (data-heavy, 10+ campañas) — solo si un mapa lo pide explícitamente.
- **Vocalizer/chat commands** (sistema de órdenes por voz — demasiado UI).
- **Weapon preferences per survivor** (no podemos forzar swap confiablemente).
- **Crown witch perfecto** (timing de animación sin hooks).
- **Headshot preciso** (no control de aim fino).
- **Ammo type override** (netprops read-only).
- **Bot orders queue** (follow/goto/heal commands — UI pesada).
- **L4D1 survivors handling** (edge case de The Passing).

## 📁 DÓNDE VA CADA COSA
- `sa_detector.nut` → nuevas detecciones (Defib, HealInterrupt, WitchSlow, IncapBlock, RockShoot)
- `sa_executor.nut` → nuevos executors (ExecuteDefib, ExecuteHealTeammate, ExecuteWitchSlow)
- `sa_items.nut` → item quotas, bot-to-bot give
- `sa_config.nut` → todas las constants + humanización (reaction, fail chance, personality)
- `sa_vision.nut` → aim offset, LOS checks
