# 🔥 Flamethrower Melee Custom — Post-Mortem & Lessons Learned

> **Estado:** DESCARTADO ❌  
> **Fecha:** Junio 2026  
> **Motivo:** Pipeline de modelos Source no funcional; modelo muestra error (manos de hunter)  
> **Autores:** Ellis (VScript) + Keith (verificación)

---

## 📋 Resumen del Proyecto

Intentamos implementar un **lanzallamas melee custom** para Left 4 Dead 2 VScript basado en el plugin SourceMod "Flamethrower V1" por Stay Puft / Boris007.

**Objetivo:** Arma melee automática (slot 1) con:
- Sistema de fuel consumible
- Partículas de fuego dinámicas
- Luz dinámica (`light_dynamic`)
- Daño en cono continuo
- Recarga vía `ammo_pickup`
- 10% chance de spawn en mapas

---

## 🗂️ Archivos del Intento

### Scripts Creados
- `l4cWeaponItemScripts/scripts/vscripts/flamethrower_system.nut` (822 líneas)
- `l4cWeaponItemScripts/scripts/melee/thrower.txt` (config de arma melee)

### Assets Copiados
- **Modelos:** `v_thrower.mdl`, `w_thrower.mdl` (+ .vvd, .dx90.vtx)
- **Materiales:** ~15 texturas VTF/VMT en `materials/models/thrower/`
- **Partículas:** 6 archivos .pcf (thrower, thrower_louis, thrower_zoey, pilotlight, etc.)
- **Sonidos:** `fire.mp3`, `pilotlight.mp3`

### Modificaciones a Sistemas Existentes
- `director_base_addon.nut` — IncludeScript de flamethrower_system
- `melee_base_system.nut` — Exclusiones de v_thrower.mdl del tracking de durabilidad
- `melee_manifest.txt` — Registro de thrower.txt
- `particles_manifest.txt` — 6 entradas de partículas thrower

---

## ⚠️ Problemas Encontrados (en orden de aparición)

### 1. Modelo Muestra Error (Manos de Hunter)
**Síntoma:** Al spawnear `weapon_melee` con `melee_script_name = "thrower"`, el arma aparece como manos de hunter desfiguradas.

**Causa root:** Modelo Source no renderiza correctamente. Posibles razones:
- ❌ Modelo no compilado correctamente para L4D2
- ❌ Falta de `PrecacheModel()` (añadido posteriormente, no resolvió)
- ❌ Dependencias de bones/attachments no coinciden con animaciones melee
- ❌ Archivos .mdl corruptos o incompletos (falta .phy, .sw.vtx, etc.)

**Lección:** En Source engine, un modelo que muestra "manos de hunter" (error model) indica que el .mdl no puede ser renderizado. Esto puede deberse a:
1. Mala compilación del modelo (studiomdl)
2. Faltan archivos requeridos (.vvd corrupto, .vtx mal generado)
3. El modelo depende de bones que no existen en el esqueleto de superviviente
4. Las animaciones del modelo no coinciden con el esqueleto del jugador

---

### 2. Melee Scripts Requieren Mission File
**Descubrimiento:** Las armas melee custom en L4D2 **deben estar listadas** en el campo `meleeweapons` del mission file de la campaña.

```txt
// Ejemplo: missions/campaign1.txt
"meleeweapons" "fireaxe;crowbar;cricket_bat;katana;baseball_bat;knife;thrower"
```

**Impacto:** Sin modificar los 14 mission files de campañas oficiales (y cualquier campaña custom), el arma no spawnea naturalmente en `weapon_melee_spawn`.

**Lección:** El engine valida `melee_script_name` contra la lista blanca del mission file. Spawnear VScript con `melee_script_name = "thrower"` funciona para el entity, pero los spawners nativos no lo reconocen sin mission override.

---

### 3. Sistemas de Custom Weapons Existentes
**Investigamos dos enfoques previos:**

#### A) Custom Weapon Lab (Rectus)
- Usa **mission file overrides** para añadir melees a `meleeweapons`
- Reemplaza `weapon_melee_spawn` nativos cambiando `melee_weapon` keyvalue
- Funciona pero requiere 14+ archivos de misión
- No viable para modpack que corre en cualquier mapa sin saber la campaña

#### B) Custom Weapons Melee (Rectus / versión antigua)
- Similar al anterior pero con más armas custom
- Mismo problema: dependencia de mission files

---

### 4. Alternativas Exploradas y Descartadas

| Alternativa | Problema |
|-------------|----------|
| `weapon_chainsaw` como base | Hardcodeo de sonido de motor + animaciones chainsaw |
| `weapon_melee` shell + lógica externa | Swing melee nativo sigue ocurriendo (no cancelable en VScript) |
| Prop_physics interactivo | No es un arma equipable; requiere input manual |
| Drops de infectados | Posible, pero sin modelo funcional no tiene sentido |

---

## ✅ Lo que SÍ Funcionó

1. **Sistema de fuel** — Lógica de drain/recharge vía timers (MaoLib)
2. **Detección de input** — `weapon_fire` event para hold-click continuo
3. **Partículas** — `info_particle_system` con auto-start/stop
4. **Luz dinámica** — `light_dynamic` spawn y control
5. **Daño en cono** — `MaoLib.AoE.Select.Cone` + `Apply.Damage`
6. **Debug command** — `!thrower` / `!ft` vía `player_say` event
7. **Precache** — `PrecacheModel()` para modelos custom

---

## 🧪 Estado Final del Código

**Eliminado del modpack:**
- ❌ `flamethrower_system.nut`
- ❌ `thrower.txt`
- ❌ Modelos, materiales, partículas, sonidos copiados
- ❌ Modificaciones a `director_base_addon.nut`
- ❌ Modificaciones a `melee_base_system.nut`
- ❌ Entradas en manifest files

---

## 📚 Referencias Técnicas

### Documentación Consultada
- [VDC: Weapon_melee](https://developer.valvesoftware.com/wiki/Weapon_melee_(Left_4_Dead_2)) — Requiere mission file
- [VDC: Melee_weapon_spawn](https://developer.valvesoftware.com/wiki/Weapon_melee_spawn) — Spawn entity docs
- [Steam Workshop: Custom Weapon Base](https://steamcommunity.com/sharedfiles/filedetails/?id=923209945) — Rectus system
- AlliedModders: `m_strMapSetScriptName` — Netprop para detectar melee script

### Repositorios Analizados
- `referencias/flamethrower/` — Plugin SourceMod original (Stay Puft)
- `referencias/customweapons/` — Custom Weapon Lab v2 (Rectus)
- `referencias/CUSTOMWEAPONSMELEE/` — Custom Weapon Base melee (Rectus)

---

## 💡 Recomendaciones para Futuros Intentos

### Si alguien quiere retomar esto:

1. **Verificar modelo primero**
   - Usar `prop_dynamic` con el modelo en un mapa test
   - Si muestra error model → el .mdl está mal compilado
   - Solución: Recompilar con studiomdl de L4D2 SDK o conseguir modelo testeado

2. **Usar `weapon_chainsaw` como base**
   - Es un arma melee nativa con "fuel" (m_iClip1)
   - Reemplazar modelo vía `CBaseEntity::SetModel()` en script scope
   - Sobrescribir sonido con `EmitSound()` propio
   - Menos problemas de compatibilidad que melee script custom

3. **Mission file override**
   - Si se quiere melee script puro, crear `missions/` overrides
   - Necesario para cada campaña oficial (1-14) y campañas custom

4. **Alternativa: No usar melee slot**
   - Usar `weapon_rifle` o `weapon_pistol` como shell
   - Bloquear disparo nativo (difícil en VScript puro, posible con plugin helper)
   - Implementar fuego vía `TraceLine` + partículas manual

---

## 🔗 Archivos de Referencia (Conservados)

Los siguientes archivos se mantienen en `referencias/` para consulta:

```
referencias/
├── flamethrower/           # Plugin SourceMod original
│   ├── scripts/melee/thrower.txt
│   ├── scripts/melee/flamethrower.sp
│   ├── models/weapons/melee/
│   ├── materials/models/thrower/
│   ├── particles/
│   └── sound/
├── customweapons/            # Custom Weapon Lab v2
│   └── scripts/vscripts/custom_weapon_lab_main/
└── CUSTOMWEAPONSMELEE/       # Custom Weapon Base melee
    └── scripts/vscripts/custom_weapon_controller.nut
```

---

## 📝 Notas para la Comunidad

**Si encuentras un modelo de lanzallamas funcional para L4D2 melee:**

1. Verifica que renderice correctamente como `prop_dynamic`
2. Asegúrate de tener todos los archivos: `.mdl`, `.vvd`, `.dx90.vtx`, `.phy`
3. Precachea con `PrecacheModel()` antes de spawnear
4. Testea en `weapon_melee` con `melee_script_name`
5. Considera usar `weapon_chainsaw` como clase base si el melee script da problemas

**Contacto:** Este documento es parte del modpack "Lost 4 Creed" (L4C). Para discusiones técnicas, referirse al repositorio del proyecto.

---

*Documento generado automáticamente tras el cierre del proyecto Flamethrower. Última actualización: Junio 2026.*
