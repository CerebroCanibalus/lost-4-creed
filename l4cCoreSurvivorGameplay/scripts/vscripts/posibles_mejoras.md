# Posibles Mejoras para IA de Supervivientes (Survivor AI Overhaul)

> Fecha: 2026-05-07
> Basado en investigación de: Left4Bots (smilz0), Competitive-Bots+, AI Improver (Emana202), guías competitivas de L4D2

---

## 🎯 1. POSICIONAMIENTO TÁCTICO (Prioridad Alta)

### A. Formación de Choke Points
**Fuente**: Estrategias competitivas oficiales + Left4Bots

Los equipos competitivos usan formaciones en choke points:
- **2 supervivientes agachados al frente** (shotguns/melee)
- **2 supervivientes de pie atrás** (disparando por encima)

**Implementación VScript**:
```squirrel
// Detectar choke points usando nav mesh
// Si hay puerta/pasillo estrecho y horda/SI → formación en línea
// Front bots: crouch + shotgun/melee
// Back bots: standing + rifle
```

**Setting sugerido**: `ChokePointWidth = 200`

---

### B. High Ground Advantage
**Fuente**: Guías competitivas + AI Improver

Los bots deberían preferir posiciones elevadas con Tank/horde:
- Tank tiene dificultad para alcanzar high ground
- Mejor visibilidad para disparar SI
- Más tiempo de reacción contra Charger

**Implementación VScript**:
- Usar `MaoLib.NavUtils.FindHighGround(center, radius, minHeightDiff)`
- Score extra para posiciones con `z` mayor que promedio del equipo

---

### C. Retreat Positions Pre-Calculadas
**Fuente**: Competitive-Bots+

Los bots competitivos conocen spots de retreat en cada mapa:
- Cuando Tank spawnea, ya saben a dónde correr
- Posiciones con curación/ammo cerca
- Spots con 1-2 direcciones de entrada

**Implementación VScript**:
- Tabla de `RetreatPoints` por mapa (`SessionState.MapName`)
- Cuando Tank aparece → moverse al retreat point más cercano
- Si HP < 50% → considerar retreat inmediato

---

## 🔫 2. COMBATE AVANZADO (Prioridad Alta)

### A. Campo de Visión (FOV) Simulado
**Fuente**: Left4Bots (`manual_attack_mindot = 0.7`)

Los bots vanilla disparan a enemigos que ni siquiera están mirando. FOV simulado = bots más humanos y menos gasto de munición.

```squirrel
// Dot product entre forward vector del bot y dirección al enemigo
// Si dot < 0.7 (≈45° fuera de visión) → no disparar
```

**Implementación**: Reemplazar `CommandABot({cmd=0, target=si})` con lógica FOV.

---

### B. Headshots Selectivos por Distancia
**Fuente**: Left4Bots

- **Comunes a <180 unidades**: apuntar a cabeza (1 shot kill)
- **Especiales a <120 unidades**: apuntar a cabeza
- **Lejos**: apuntar a cuerpo

---

### C. Weapon Range Awareness
**Fuente**: AI Improver

Los bots deberían conocer el rango efectivo de su arma:
- **Shotgun**: no disparar a >500 unidades → cambiar a pistola
- **Sniper**: no disparar a <100 unidades → cambiar a primaria corta
- **Melee**: solo si 4+ comunes a <200 unidades

```squirrel
local weapon = bot.GetActiveWeapon()
local dist = (bot.GetOrigin() - target.GetOrigin()).Length()

if (weaponClass == "weapon_pumpshotgun" && dist > 500) {
    // Forzar cambio a pistola
    NetProps.SetPropInt(bot, "m_afButtonForced", 
        NetProps.GetPropInt(bot, "m_afButtonForced") | 32)
}
```

---

## 🛡️ 3. EVASIÓN Y SUPERVIVENCIA (Prioridad Media-Alta)

### A. Dodge de Tank Rocks con Compensación
**Fuente**: Left4Bots (`shoot_rock_ahead = 4`)

Cuando Tank lanza una roca:
1. Detectar rock entity (`m_hThrowingEntity`)
2. Calcular trayectoria (posición + velocidad)
3. Mover perpendicular a la trayectoria
4. Opcional: Disparar la roca en el aire

**Mejora actual**: Ya tenemos dodge básico, pero se puede mejorar con compensación de velocidad del rock.

---

### B. Dodge de Charger con Delay Proporcional
**Fuente**: Left4Bots (`dodge_charger_distdelay_factor = 0.0006`)

Los bots esquivan Charger **demasiado temprano** (el Charger corrige dirección). Técnica competitiva:
- Calcular tiempo hasta impacto: `distancia / velocidad`
- Esquivar en el **último momento**

```squirrel
local timeToImpact = dist / chargerSpeed
if (timeToImpact < 0.3) {  // Último momento
    CommandABot({cmd=1, bot=bot, pos=dodgePos})
}
```

---

### C. Spit/Fire Avoidance con Pathfinding
**Fuente**: AI Improver

Los bots deberían evitar áreas con fuego/ácido activo:
- Detectar `inferno` entities cerca
- Marcar nav areas como "bloqueadas"
- Pathfind alrededor del fuego

**Implementación**: Mejorar `FindSafePosition()` con radio de detección más grande.

---

### D. Slowwalk Cerca de Witches
**Fuente**: AI Improver

Los bots corren cerca de witches y las alertan:
- Detectar witch no alertada (`m_rage < 0.1`)
- Si distancia < 400 → **caminar lento** (no correr)
- Si tiene shotgun y distancia < 100 → **autocrown**

```squirrel
if (witch && witchDist < 400 && !witchAngry) {
    NetProps.SetPropInt(bot, "m_afButtonForced",
        NetProps.GetPropInt(bot, "m_afButtonForced") & ~512) // Quitar IN_SPEED
}
```

---

## 🤝 4. COOPERACIÓN DE EQUIPO (Prioridad Media)

### A. Team Item Quotas
**Fuente**: Left4Bots

El equipo debería mantener mínimos de items:
- Mínimo 2 medkits
- Mínimo 1 shotgun
- Mínimo 1 molotov
- Máximo 2 melee weapons
- Máximo 0 chainsaws (competitivo)

**Implementación**: Contar items del equipo cada 5 segundos.

---

### B. Help Pinned Survivors (Shove o Shoot)
**Fuente**: AI Improver + Left4Bots

Cuando un compañero está pinned:
- **Opción 1**: Disparar al SI (rango 1250)
- **Opción 2**: Shove al SI si está cerca (rango 75)
- **Prioridad**: Shooter más cercano dispara, el más cercano shovea

**Nota**: Charger NO recibe empujes. Solo disparar.

---

### C. Damage Redirect (Jockey)
**Fuente**: Left4Bots

Cuando un Jockey monta a un compañero, los bots disparan al compañero (friendly fire). Solución: hacer que el bot apunte al Jockey, no al compañero.

---

## 💣 5. GRANADAS Y THROWABLES (Prioridad Media)

### A. Horde Detection para Pipe Bombs
**Fuente**: Left4Bots + AI Improver

Lanzar pipe bombs/molotovs cuando:
- Horda size ≥ `5 × número_de_supervivientes`
- Radio de detección: 450 unidades
- Cooldown entre lanzamientos: 15-35s aleatorio

**Implementación**: Usar `CachedHordeCount` que ya tenemos.

---

### B. Tank Molotov Logic
**Fuente**: Left4Bots

Condiciones para lanzar molotov al Tank:
- Tank vida > 1500
- Distancia al Tank: 200-1300 unidades
- Distancia Tank a otros supervivientes > 240
- Cooldown: 4s entre molotovs de diferentes bots

---

## 🧠 6. TOMA DE DECISIONES (Prioridad Media)

### A. Sistema de Pausa Contextual
**Fuente**: Left4Bots

Cuando hay amenaza, los bots pausan su goal actual:
- Tank a <650 unidades → pausar todo
- Special cerca → pausar loot/heal
- Horda grande → pausar avance
- Duración mínima de pausa: 2 segundos

---

### B. Stuck Detection
**Fuente**: Left4Bots

Bots a veces se atascan:
- Trackear posición cada 3 segundos
- Si no se movió >100 unidades en 3s → stuck
- Unstuck: teleport corto o comando forzado

---

## 📋 RESUMEN EJECUTIVO: TOP 10 MEJORAS

| # | Mejora | Impacto | Dificultad | Fuente |
|---|--------|---------|-----------|--------|
| 1 | **FOV simulado** (dot product) | ⭐⭐⭐⭐⭐ | Fácil | Left4Bots |
| 2 | **Choke point formations** | ⭐⭐⭐⭐⭐ | Media | Competitivo |
| 3 | **Spit/fire avoidance** mejorado | ⭐⭐⭐⭐⭐ | Media | AI Improver |
| 4 | **Witch slowwalk + autocrown** | ⭐⭐⭐⭐⭐ | Fácil | AI Improver |
| 5 | **Weapon range awareness** | ⭐⭐⭐⭐ | Fácil | AI Improver |
| 6 | **Help pinned (shove o shoot)** | ⭐⭐⭐⭐ | Fácil | AI Improver |
| 7 | **Tank rock dodge** con compensación | ⭐⭐⭐⭐ | Media | Left4Bots |
| 8 | **Horde detection para granadas** | ⭐⭐⭐⭐ | Fácil | Left4Bots + AI |
| 9 | **High ground preference** | ⭐⭐⭐ | Media | Competitivo |
| 10 | **Team item quotas** | ⭐⭐⭐ | Media | Left4Bots |

---

## ⚠️ LIMITACIONES DE VSCRIPT

Algunas técnicas de SourceMod **no son posibles** en VScript nativo:

| Técnica | Por qué no funciona |
|---------|---------------------|
| Weapon preference per survivor | No podemos forzar swap de armas confiablemente |
| Shoot tank rocks en el aire | `CommandABot` no permite apuntar a proyectiles |
| Headshot preciso | No podemos controlar `m_aimPunchAngle` con precisión |
| Crown witch perfecto | Timing de animación muy difícil sin hooks |
| Ammo type override | NetProps de munición son read-only |

---

*Documento generado para Lost 4 Creed - L4D2 Modpack*
*Archivo relacionado: `survivor_ai_overhaul.nut`*
