# PLAN: system_perks_unified.nut — Unified Perk System v1.3

## 🎯 OBJETIVO

Sistema monolítico unificado de perks para 8 personajes + efectos de equipamiento.
- **8 perks únicos**, uno por personaje
- **Mecánicas profundas con trade-offs reales**
- **Configuración hardcodeada** en `BaseAttributes` (no archivo externo)
- **UNA tabla de eventos** → UNA fuente de verdad → CERO race conditions

---

## 🎭 MAPEO DE PERSONAJES

| Modelo (mdl) | Personaje | Rol | Equipo |
|-------------|-----------|-----|--------|
| `survivor_teenangst.mdl` | **Brenda** | Líder A / Explosivos | A |
| `survivor_gambler.mdl` | **Jason** | Líder B / Precisión | B |
| `survivor_namvet.mdl` | **Chris** | Curandero / Veterano | A |
| `survivor_manager.mdl` | **Jerry** | Spray & Pray / Artillero | A |
| `survivor_biker.mdl` | **Phil** | Policía / Tanque | B |
| `survivor_mechanic.mdl` | **Sean** | Escucha / Scout | A |
| `survivor_coach.mdl` | **Brock** | Tanque CEDA | B |
| `survivor_producer.mdl` | **Jaime** | Glass Cannon | B |

---

## 📁 ESTRUCTURA

```
director_base_addon.nut
├── system_perks_unified.nut    → Perks monolítico (8 chars + equipment + events)
├── system_attributes.nut       → Speed/weight/friction engine
├── system_dash.nut             → Dash + input handling
├── system_combat.nut           → FX + Util + FriendlyShove
├── survivor_ai_overhaul.nut    → MIA - IA de bots
└── system_events_misc.nut      → Eventos + Sustos + Sonidos
```

**NOTA:** Los 8 scripts `sp_*.nut` individuales fueron consolidados en `system_perks_unified.nut`.
Ya no existen `system_character.nut`, `system_perks.nut`, `sp_config.nut`, ni `system_movement.nut`.

---

## 🔥 PERKS DETALLADOS

---

### 1. BRENDA — Demolitions Expert (Zoey)

**Pasiva — Piromanía:**
- +30% daño con bombas (molotovs, pipe bombs) y fuego aplicado a infectados.
- **PERO:** Recibe +20% daño de todas las fuentes.

**Pasiva — Mochila de Bombas:**
- Puede llevar hasta 3 bombas.
- Al recoger pilas de munición: 50% probabilidad de ganar +1 throwable.

**Activa — Gnomo Incendiado (E - Uso):**
- Lanza un **gnomo** que está en llamas.
- Tras 2 segundos, explota como molotov: +25% radio, +2s duración de fuego.
- Cooldown: 30s.

**Trade-off — Frágil:**
- **90 HP máximo.**
- Al morir, sus bombas restantes explotan (daño reducido a aliados).

---

### 2. JASON — The Sharpshooter (Nick)

**Pasiva — Entrenamiento Militar:**
- +15% daño con rifles, snipers, y shotguns.
- Headshots: +25% daño adicional.
- -20% spread.

**Activa — Fuego de Precisión (SHIFT):**
- Durante 3s: sin recoil (perfect accuracy).
- Cada kill durante Perfect Aim: +2 temp HP (máx 20).
- Cooldown: 25s.
- **Pierde dash.** SHIFT = activa.

**Trade-off — Pesado:**
- **NO tiene dash** (ni base ni SHIFT).
- Se mueve 15% más lento.

---

### 3. CHRIS — Combat Medic (Bill)

**Pasiva — Manos Curtidas:**
- Botiquines: 25% más rápido, +15 HP temporal (30s).
- Pills: +15 HP extra (65 en vez de 50).
- Al revivir: ambos ganan +10 HP temporal (15s).

**Activa — Terapia de Choque (E - Uso en aliado):**
- Compañero en 200u con LOS: +25 HP instantáneo (temporal) + +10% velocidad (5s).
- Al expirar: -5 HP recoil.
- Cooldown: 45s.

**Trade-off — Pérdida Progresiva:**
- Por cada compañero muerto: -3% HP máximo y -3% velocidad permanentes.

---

### 4. JERRY — Spray and Pray (Louis)

**Pasiva — Cadencia Imparable:**
- +25% cadencia de fuego con SMGs, rifles, AK.
- +20% velocidad de recarga con armas automáticas.

**Pasiva — Economía de Guerra:**
- Cada 100 de daño infligido: munición directa a reserva.
- **PERO:** 33% probabilidad de gastar 2 balas por disparo.
- Si no juega agresivo: -15% daño con TODAS las armas.

**Activa — Sobrecarga (R doble-tap):**
- Recarga instantánea + siguiente cargador +50% balas extra.
- Cooldown: 35s.

---

### 5. PHIL — Riot Cop (Francis)

**Pasiva — Armadura de Disturbios:**
- Comienza con porra/nightstick en vez de pistola.
- +20% daño melee.
- Shoves staggeran 50% más tiempo.
- -20% daño recibido de commons.

**Pasiva — Dash Policial:**
- **MANTIENE dash.** SHIFT = dash mejorado.
- Dash mata commons instantáneamente al atravesarlos.
- Dash staggera SI al tocarlos.
- Final del dash: empujón de área (200u, 10 daño, stagger).

**Activa — Break Free (Mouse2 while grabbed):**
- Se libera automáticamente de agarres de SI.
- Cooldown: 90s.

**Trade-off — Sin Segunda Oportunidad:**
- **NO puede quedar incapacitado.** Si llega a 0 HP, muere directamente.

---

### 6. SEAN — The Listener (Ellis)

**Pasiva — Oído Aguzado:**
- Detecta SI spawneando en 500u (audio + HUD notification).

**Activa — Escucha Progresiva (Agacharse + stay still):**
- Más tiempo = más info para TODO EL EQUIPO.

| Tiempo | Efecto (Equipo) |
|--------|----------------|
| 1s | SI en 200u revelados |
| 3s | SI en 400u revelados |
| 5s | SI en 600u revelados |
| 6s | SI + Commons en 800u revelados |

- Se rompe al moverse, disparar, recibir daño, usar items.

**Trade-off — Metódico:**
- Recarga y levantar compañeros: +15% más lento.
- **80 HP máximo.**

---

### 7. BROCK — The CEDA Wall (Coach)

**Pasiva — Traje Ignífugo (EXCLUSIVO):**
- Inmune al daño de fuego (propio, aliado, ambiental).
- Inmune a quemaduras de infectados en llamas.

**Pasiva — Muro Viviente:**
- -15% daño recibido de todas las fuentes.
- Aliados en 200u: -10% daño (aura).

**Activa — Protocolo CEDA (SHIFT):**
- Reemplaza dash.
- Durante 5s: inmune a stagger + -40% daño recibido.
- Cooldown: 35s.

**Trade-off — Rigidez:**
- Shove penalty se acumula 2x más rápido.
- -30% velocidad de swing melee.

---

### 8. JAIME — Glass Cannon (Rochelle)

**Pasiva — Sed de Sangre (Stacks):**
- Cada infectado muerto: +1 stack (máx 10).
- Cada stack: +5% daño armas de fuego.
- **0 stacks: -15% daño permanente** hasta 1+ stack.
- **8+ stacks: 1 HP/s de daño a sí misma.**
- Stacks decaen si no mata en 10s.

**Activa — Frenesí Devorador (SHIFT):**
- Pierde dash.
- Consume todos los stacks.
- Lifesteal 20% durante 5s + +15% velocidad.
- Cooldown: 30s.

**Trade-off — Frágil:**
- **100 HP máximo.**
- **NO tiene dash.**

---

## ⚙️ CONFIGURACIÓN

La configuración está **hardcodeada** en `BaseAttributes` dentro de `system_perks_unified.nut`.
No se usa archivo externo.

```vscript
BaseAttributes = {
    brenda = { hpMax = 90, speedMult = 1.0, damageIn = 1.2 },
    jason  = { hpMax = 100, speedMult = 0.85 },
    chris  = { hpMax = 100, speedMult = 1.0 },
    jerry  = { hpMax = 100, speedMult = 1.0 },
    phil   = { hpMax = 120, speedMult = 1.0 },
    sean   = { hpMax = 80, speedMult = 1.0 },
    brock  = { hpMax = 120, speedMult = 1.0, damageIn = 0.85, fireImmunity = true },
    jaime  = { hpMax = 100, speedMult = 1.0 },
}
```

Para modificar valores, editar directamente `BaseAttributes` en `system_perks_unified.nut`.

---

## 🏗️ EVENTOS MANEJADOS

| Evento | Uso |
|--------|-----|
| `player_activate` | Identificar personaje, aplicar perks iniciales |
| `player_transitioned` | Re-aplicar perks tras transición de mapa |
| `player_hurt` | Daño in/out, lifesteal, self-damage (Jaime 8+ stacks) |
| `weapon_fire` | Jerry ammo tracking, Jason headshot heal |
| `weapon_reload` | Jerry overcharge, Jerry double consume |
| `infected_death` | Jerry damage tracking, Jaime stacks |
| `player_use` | Brenda gnomo, Chris therapy, Phil break free |
| `round_start` | Init timers, reset states |
| `round_end` | Cleanup |
| `entity_shoved` | Phil stagger duration |
| `player_incapacitated` | Phil: convertir a muerte directa |

---

## 🔄 MIGRACIÓN (Histórico)

### Scripts consolidados en unified:
- `system_character.nut` → BaseAttributes + GetCharacterId
- `sp_brock.nut` → Brock perk logic
- `sp_jaime.nut` → Jaime perk logic
- `sp_jason.nut` → Jason perk logic
- `sp_sean.nut` → Sean perk logic
- `sp_jerry.nut` → Jerry perk logic
- `sp_brenda.nut` → Brenda perk logic
- `sp_chris.nut` → Chris perk logic
- `sp_phil.nut` → Phil perk logic
- `sp_config.nut` → Eliminado (config hardcodeada)
- `system_perks.nut` → Eventos consolidados en unified
- `system_movement.nut` → Reemplazado por system_attributes.nut + system_dash.nut

### director_base_addon.nut:
```vscript
IncludeScript("system_perks_unified", getroottable());
```

---

## ✅ CHECKLIST

- [x] system_perks_unified.nut creado (monolítico)
- [x] 8 perks implementados
- [x] Equipment effects (Section 4.5)
- [x] Event handlers unificados (13 eventos)
- [x] BaseAttributes hardcodeado
- [x] ShowCharacterInfo (3 líneas concisas en inglés)
- [x] director_base_addon.nut actualizado
- [x] Scripts legacy eliminados
- [x] Verificado con Keith
- [x] Testing en servidor dev

---

*Last updated: 2026-06-07*
