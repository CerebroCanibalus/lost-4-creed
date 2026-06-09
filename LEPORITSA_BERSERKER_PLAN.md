# Leporitsa Rework Plan — "El Desgarrador" (Berserker)

## Estado
- **Pendiente de implementación.** Documento guardado para retomar tras fixear problemas críticos de linterna e IA.
- **Fecha:** 2026-05-06
- **Bloqueado por:** Issues críticos en flashlight + survivor AI

---

## Concepto Central

Boomer mutado sin bolsa de bilis. Desarrolló músculos desproporcionados y furia incontrolable. **Brawler de melee puro** que se vuelve más peligroso cuanto más daño recibe.

> *"No vomita... te desgarra."*

---

## Mecánicas

### 1. Furia Sangrienta (Pasiva — Al recibir daño)

| Stack | Velocidad | Daño melee | Duración |
|-------|-----------|------------|----------|
| 1 | +20% | +15% | 5s |
| 2 | +40% | +30% | 5s |
| 3 | +60% | +50% | 5s |

- **Visual:** `blood_impact_red_01` + sonido `Player.Tank.Attack`
- **Técnica:** `player_hurt` → si víctima es Leporitsa → `m_flLaggedMovementValue` + stack counter
- Stack se renueva con cada golpe recibido (max 3)

### 2. Golpe Demoledor (Melee pasivo)

- Cada golpe empuja al survivor
- Knockback: 200–400 fuerza + 100 upward
- Dirección: desde Leporitsa hacia survivor
- **Técnica:** `ApplyAbsVelocityImpulse` (patrón confirmado en `tank_crowd_control.nut`)

### 3. Combo Salvaje (Melee activo)

- Golpear al **mismo survivor 2 veces** en 3s activa combo
- **3er golpe:** +50% daño + empuje masivo (600 fuerza)
- **Visual:** `Player.Tank.Pound` + screen shake
- Resetea si cambia de target o pasa tiempo

### 4. Rugido de Muerte (Al morir)

- Rugido en radio 400u
- Survivors cercanos: screen shake + -20% velocidad por 3s
- Sin daño — puro disrupción

---

## Stats

| Stat | Valor | Comparación |
|------|-------|-------------|
| HP | 1200 | Boomer=150, Charger=600, Tank=6000 |
| Velocidad base | 0.90 | Boomer=1.0 |
| Velocidad max (Furia x3) | 1.44 | Tank berserker=1.5 |
| Daño melee base | 12 | Boomer=6, Charger=15 |
| Daño melee max | 18 | Tank=24 |
| Cooldown melee | 1.0s | Modificable vía ConVar |

---

## Implementación Técnica

### Eventos
- `OnGameEvent_player_hurt` — Detectar daño recibido/caused por Leporitsa
- `OnGameEvent_player_death` — Rugido de muerte

### NetProps
- `m_flLaggedMovementValue` — Velocidad
- `m_iHealth` / `m_iMaxHealth` — HP para stacks

### Funciones nativas confirmadas
- `ApplyAbsVelocityImpulse(victim, direction * force)` — Knockback
- `EntIndexToHScript()` / `GetPlayerFromUserID()` — Handles

### Arquitectura
Thinker por Leporitsa (no global) usando `MaoLib.AddMonitor` o `logic_timer` vinculado a entity index.

---

## Limitaciones y Mitigaciones

| Limitación | Mitigación |
|------------|-----------|
| No se pueden cambiar animaciones | Particles + sonidos para feedback |
| No se puede crear "nuevo tipo" de infected | Reemplazar modelo + desactivar vomit |
| El bot usa IA de boomer (se acerca y golpea) | Perfecto para un brawler |
| Conflicto potencial con `tank_berserker.nut` | Usar scriptscope local, no variables globales |

---

## Archivos a Modificar

- `l4cCustomInfected/scripts/vscripts/lepotitsa.nut` — rework completo
- `l4cCustomInfected/scripts/vscripts/director_base_addon.nut` — asegurar include

---

## Notas de Implementación

### Cómo detectar melee del boomer
```squirrel
// En OnGameEvent_player_hurt:
if (params.weapon == "boomer_claw") {
    // Es un golpe melee de boomer/Leporitsa
}
```

### Cómo detectar si el atacante es Leporitsa
```squirrel
// Verificar modelo o variable en scriptscope
local attacker = GetPlayerFromUserID(params.attacker)
if (attacker.GetModelName() == "models/infected/lepotitsa.mdl") {
    // Es Leporitsa
}
```

### Cómo aplicar velocidad
```squirrel
NetProps.SetPropFloat(lep, "m_flLaggedMovementValue", 1.2)  // +20%
```

### Cómo aplicar knockback
```squirrel
local dir = (victim.GetOrigin() - lep.GetOrigin())
dir.Norm()
victim.ApplyAbsVelocityImpulse(dir * 300 + Vector(0, 0, 100))
```

---

## Checklist Post-Implementación

- [ ] Implementar sistema de Furia (stacks + velocidad + daño)
- [ ] Implementar knockback en melee + combo system
- [ ] Implementar rugido de muerte con screen shake
- [ ] Desactivar vomit nativo
- [ ] Integrar con MaoLib para thinker limpio
- [ ] Verificar con Keith (VSLib fantasmas, sintaxis)
- [ ] Testear en-game con bots y humanos
- [ ] Balancear stats según feedback

---

## Referencias

- `tank_berserker.nut` — Patrón de escalating rage con `m_flLaggedMovementValue`
- `tank_crowd_control.nut` — Patrón de knockback con `ApplyAbsVelocityImpulse`
- `lepotitsa.nut` (original) — Código base a reemplazar
- `vscript-obscure` skill — Limitaciones conocidas de VScript nativo
