# 🔴 REPORTE CRÍTICO: Thinkers, Timers y Loops en L4C Modpack

> **Fecha:** 2026-05-08  
> **Issues detectados:** 55 thinker/entity issues → 34 thinker issues críticos  
> **Scripts afectados:** 21 scripts  
> **Riesgo:** Crasheos en runtime, memory leaks, entidades huérfanas

---

## 📊 TABLA RESUMEN EJECUTIVA

| Script | Ruta | Mecanismo | Frecuencia | Cleanup | Riesgo |
|--------|------|-----------|------------|---------|--------|
| **restore_crawlanim** | `l4cCoreAddon/scripts/vscripts/` | `AddThinkToEnt` + `logic_relay` | 0.1s / 1.0s | ❌ NO | **CRÍTICO** |
| **maolib** | `l4cCoreAddon/scripts/vscripts/` | `AddThinkToEnt` + `info_target` | Variable | ❌ NO | **CRÍTICO** |
| **shared** | `l4cCoreAddon/scripts/vscripts/` | `AddThinkToEnt` + `info_target` | 0.1s | ❌ NO | **CRÍTICO** |
| **tank_aggressive_ai** | `l4cInfectedGameplay/scripts/vscripts/` | `AddThinkToEnt` + `info_target` | 0.5s | ✅ SÍ (parcial) | **CRÍTICO** |
| **tacticalmovement** | `l4cCoreSurvivorGameplay/scripts/vscripts/` | `AddThinkToEnt` + `fish` | 0.01s | ✅ SÍ (round_end) | **CRÍTICO** |
| **rrlogic** | `l4cWeaponItemScripts/scripts/vscripts/` | `AddThinkToEnt` + `info_target` | 0.03s | ❌ NO | **CRÍTICO** |
| **rush_incap** | `l4cInfectedGameplay/scripts/vscripts/` | `AddThinkToEnt` + `info_target` | 0.01s / 1.0s | ❌ NO | **CRÍTICO** |
| **rotpi** | `l4cInfectedGameplay/scripts/vscripts/` | `AddThinkToEnt` + `info_target` | 0.01s | ✅ SÍ (self.Kill) | **CRÍTICO** |
| **ctsh** | `l4cCoreAddon/scripts/vscripts/` | `AddThinkToEnt` + `info_target` | Default (0.1s) | ❌ NO | **CRÍTICO** |
| **fire_spreads_geeb** | `l4cInfectedGameplay/scripts/vscripts/` | `AddThinkToEnt` + `script_trigger_multiple` | 0.1s / variable | ✅ SÍ (self.Kill) | **CRÍTICO** |
| **item_buffs** | `l4cWeaponItemScripts/scripts/vscripts/` | `AddThinkToEnt` en weapon entities | 1s / 10s / 15s / 35s | ❌ NO | **CRÍTICO** |
| **fallenspawn_** | `l4cCoreAddon/scripts/vscripts/` | `AddThinkToEnt` + `info_target` | 1.0s | ❌ NO | **CRÍTICO** |
| **bleeding** | `l4cCoreAddon/scripts/vscripts/` | `AddThinkToEnt` + `info_target` | 0.01s / 1.0s | ✅ SÍ (self.Kill) | **CRÍTICO** |
| **_vscript_stubs** | `l4cCoreAddon/scripts/vscripts/` | Stub vacío de `AddThinkToEnt` | N/A | N/A | **CRÍTICO** (falso positivo) |
| **passivetank_scopemanager** | `l4cInfectedGameplay/scripts/vscripts/` | `AddThinkToEnt` + `info_director` | Variable | ✅ SÍ (RemoveMainFromScope) | **CRÍTICO** |
| **clipempty** | `l4cWeaponItemScripts/scripts/vscripts/` | `logic_timer` (nativo ✅) | 0.1s | ✅ SÍ (round_end) | **OK** (ya nativo) |
| **infected_regen** | `l4cInfectedGameplay/scripts/vscripts/` | `logic_timer` | 0.1s | ✅ SÍ (round_start) | **WARNING** (sin round_end) |
| **chch_uncommons** | `l4cCoreAddon/scripts/vscripts/` | `logic_timer` | 0.03s | ❌ NO | **WARNING** |
| **water_slowdown_reduction** | `l4cCoreAddon/scripts/vscripts/` | `logic_timer` ×2 | 0.05s / 30s | ❌ NO | **WARNING** |
| **hunter_jump** | `l4cInfectedGameplay/scripts/vscripts/` | `logic_timer` ×2 | 0.1s cada uno | ❌ NO | **WARNING** |
| **tankfire** | `l4cInfectedGameplay/scripts/vscripts/` | `logic_timer` | 0.1s | ❌ NO | **WARNING** |
| **ci_death_fix** | `l4cInfectedGameplay/scripts/vscripts/` | `logic_timer` | 0.2s | ✅ SÍ (Enable/Disable) | **WARNING** (sin round_end) |
| **ladder_sounds** | `l4cCoreAddon/scripts/vscripts/` | `logic_timer` | 0.5s | ❌ NO | **WARNING** |
| **smoker_momentum_tongue** | `l4cInfectedGameplay/scripts/vscripts/` | `logic_timer` | 0.1s | ✅ SÍ (KillUpdateTimer) | **WARNING** (sin round_end) |
| **dashing** | `l4cCoreSurvivorGameplay/scripts/vscripts/` | `logic_timer` | 0.05s | ❌ NO | **WARNING** |
| **boomer_fall** | `l4cInfectedGameplay/scripts/vscripts/` | `logic_timer` | 0.1s | ❌ NO | **WARNING** |
| **overdose_pills** | `l4cWeaponItemScripts/scripts/vscripts/` | `Schedule()` recursivo | 7.5s | ✅ SÍ (bActive flag) | **WARNING** (patrón riesgoso) |

**Leyenda de riesgo:**
- **CRÍTICO:** Usa `AddThinkToEnt` → crasheará en L4D2 nativo sin VSLib
- **WARNING:** Usa `logic_timer` sin cleanup en `round_end` → entity leak acumulativo

---

## 🚨 PROBLEMA CENTRAL: `AddThinkToEnt` NO EXISTE EN L4D2 NATIVO

### ¿Qué es `AddThinkToEnt`?

`AddThinkToEnt(entity, funcName)` es una función proporcionada por la librería **VSLib** (VScript Library), un addon de Steam Workshop que inyecta funciones adicionales en el runtime de L4D2. **NO es nativa del motor Source ni de L4D2 VScript.**

### ¿Por qué crashea?

Cuando un script llama `AddThinkToEnt` sin tener VSLib cargado:
1. El parser de Squirrel no encuentra la función en el scope global
2. Lanza un error de runtime: `unknown function AddThinkToEnt`
3. El script se detiene abruptamente
4. Dependiendo del contexto, puede crashear el servidor o dejar funcionalidad sin cargar

### ¿Dónde está definido en el modpack?

En `l4cCoreAddon/scripts/vscripts/_vscript_stubs.nut` (línea 26):
```squirrel
function AddThinkToEnt(entity, funcName) {}
```

**Este stub es un placebo.** Solo evita el error de compilación, pero **NO hace nada**. La función real de VSLib registra un think hook en el engine de Source; el stub vacío simplemente no ejecuta nada.

> ⚠️ **Esto significa que TODOS los scripts que usan `AddThinkToEnt` están actualmente DESHABILITADOS** (silenciosamente fallando), a menos que VSLib esté cargado como addon externo.

---

## 🔧 PATRONES NATIVOS DE REEMPLAZO

### Patrón 1: `logic_timer` con `RunScriptCode` (RECOMENDADO)

**Ventajas:**
- 100% nativo de L4D2, no requiere VSLib
- Soporta cleanup con `Kill()`
- Intervalo configurable via `RefireTime`
- Puede habilitarse/deshabilitarse con `Enable`/`Disable`

**Ejemplo:**
```squirrel
function StartMyTimer()
{
    // Cleanup previo
    local existing = Entities.FindByName(null, "my_timer_name")
    if (existing && existing.IsValid())
        existing.Kill()
    
    // Crear nuevo timer
    local timer = SpawnEntityFromTable("logic_timer", {
        targetname = "my_timer_name",
        RefireTime = 0.5,
        OnTimer = "!self,RunScriptCode,::MyNamespace.MyThinkFunction()"
    })
}

function StopMyTimer()
{
    local timer = Entities.FindByName(null, "my_timer_name")
    if (timer && timer.IsValid())
        timer.Kill()
}

// Cleanup en round_end
function OnGameEvent_round_end(params)
{
    StopMyTimer()
}
```

**Cuándo usarlo:**
- Thinkers globales (IA, sistemas de regen, verificaciones periódicas)
- Timers que necesitan habilitarse/deshabilitarse dinámicamente
- Sistemas donde el intervalo es fijo y no muy corto (>0.05s)

---

### Patrón 2: `DoEntFire` con delay (Para delays puntuales)

**Ventajas:**
- Sin crear entidades → zero overhead
- Ideal para delays únicos o raros
- Nativo 100%

**Ejemplo:**
```squirrel
// Ejecutar una función después de 2.5 segundos sin crear entidad
DoEntFire("worldspawn", "RunScriptCode", "::MyNamespace.DoSomething()", 2.5, null, null)
```

**Limitaciones:**
- No es recurrente (para loops usar Patrón 1 o 3)
- No se puede cancelar fácilmente una vez programado

---

### Patrón 3: `ConnectOutput` en `logic_timer` (Para encapsulación)

**Ventajas:**
- La función callback vive en el scope de la entidad → evita colisiones de nombres
- Más limpio para scripts complejos

**Ejemplo:**
```squirrel
local timer = SpawnEntityFromTable("logic_timer", {
    targetname = "my_timer",
    RefireTime = 1.0
})

timer.ValidateScriptScope()
timer.GetScriptScope().MyThink <- function() {
    printl("Thinking from entity scope!")
    return 1.0  // No se usa con ConnectOutput, pero útil para referencia
}

timer.ConnectOutput("OnTimer", "MyThink")
EntFire("my_timer", "Enable", "", 0.1)
```

---

### Patrón 4: Flag de parada para `Schedule()`-like

Si necesitas un sistema de scheduling similar al de VSLib:

```squirrel
::MyScheduler <- {
    active = true,
    
    function ScheduleCheck()
    {
        if (!active) return
        
        // Lógica aquí
        ::MyScheduler.DoWork()
        
        // Reprogramar siguiente ejecución
        if (active)
        {
            DoEntFire("worldspawn", "RunScriptCode", 
                "::MyScheduler.ScheduleCheck()", 7.5, null, null)
        }
    },
    
    function Stop()
    {
        active = false
    }
}

// En round_end
function OnGameEvent_round_end(params)
{
    ::MyScheduler.Stop()
}
```

---

## 📋 ANÁLISIS DETALLADO POR SCRIPT

### 1. `restore_crawlanim.nut` — CRÍTICO

**Mecanismo:** `AddThinkToEnt` en `logic_relay` (línea 209)
**Frecuencia:** 0.1s cuando hay incapacitados, 1.0s cuando no
**Cleanup:** SÍ (líneas 212-216: `thinkEnt.Kill()`), pero solo en `ToggleThink(false)`
**Problema:** 
- Usa `AddThinkToEnt` → no ejecuta el think en nativo
- No hay cleanup en `round_end` → si la ronda termina con incapacitados, el `logic_relay` queda vivo
- `ToggleThink(false)` solo se llama cuando el array `IncappedClients` queda vacío

**Reemplazo recomendado:**
```squirrel
function OnGameEvent_round_start_post_nav(params)
{
    // ... código existente ...
    
    // Reemplazar AddThinkToEnt por logic_timer
    local timer = Entities.FindByName(null, "incap_crawl_timer")
    if (timer && timer.IsValid()) timer.Kill()
    
    timer = SpawnEntityFromTable("logic_timer", {
        targetname = "incap_crawl_timer",
        RefireTime = 0.1,
        OnTimer = "!self,RunScriptCode,::incapCrawlAnimFix.ThinkWrapper()"
    })
}

function ThinkWrapper()
{
    local interval = incapCrawlAnimFix.IterateIncaps()
    
    // Actualizar RefireTime dinámicamente
    local timer = Entities.FindByName(null, "incap_crawl_timer")
    if (timer && timer.IsValid())
    {
        timer.__KeyValueFromFloat("RefireTime", interval)
    }
}

function OnGameEvent_round_end(params)
{
    local timer = Entities.FindByName(null, "incap_crawl_timer")
    if (timer && timer.IsValid()) timer.Kill()
}
```

---

### 2. `maolib.nut` — CRÍTICO (Biblioteca central)

**Mecanismo:** `AddThinkToEnt` en `info_target` relay (línea 371, función `AddMonitor`)
**Frecuencia:** Variable (según opts.delay)
**Cleanup:** `RemoveMonitor` existe (línea 380), pero es manual
**Problema:**
- Toda la librería `MaoLib.AddMonitor` está construida sobre `AddThinkToEnt`
- Scripts que dependen de `AddMonitor` (como `DelayCall`) fallan silenciosamente
- El `DelayMonitor` (línea 682) usa `AddThinkToEnt` indirectamente

**Reemplazo recomendado:**
Refactorizar `AddMonitor` para usar `logic_timer` con targetname único:

```squirrel
function AddMonitor(what, name, func, opts = {}, env = null)
{
    if (!what || !what.IsValid()) return false
    
    RemoveMonitor(what, name)
    
    local timerName = "maolib_monitor_" + what.GetEntityIndex() + "_" + name
    local timer = SpawnEntityFromTable("logic_timer", {
        targetname = timerName,
        RefireTime = ("delay" in opts) ? opts.delay : 1.0
    })
    
    if (!timer || !timer.IsValid()) return false
    
    timer.ValidateScriptScope()
    local scope = timer.GetScriptScope()
    scope.callback <- func
    scope.opts <- opts
    
    timer.ConnectOutput("OnTimer", "TimerCallback")
    EntFire(timerName, "Enable", "", 0.05)
    
    // Guardar referencia en el scope del target
    local targetScope = GetScope(what)
    targetScope[name] <- timer
    
    return true
}

// En el scope del timer:
function TimerCallback()
{
    local result = callback()
    // result puede ser usado para decidir si continuar
}
```

---

### 3. `shared.nut` — CRÍTICO

**Mecanismo:** `AddThinkToEnt` en `info_target` (líneas 46-49)
**Frecuencia:** 0.1s (retornado por `updateWeaponChange`)
**Cleanup:** ❌ NO hay `OnGameEvent_round_end`
**Problema:**
- El thinker `thinkWeaponChange` se crea en `round_start_post_nav`
- Nunca se mata al terminar la ronda
- Si el mapa cambia, la entidad puede persistir (aunque normalmente el cambio de mapa limpia entidades)

**Reemplazo recomendado:**
```squirrel
function OnGameEvent_round_start_post_nav(params) {
    // ... código existente ...
    
    if (!thinkWeaponChange) {
        // Usar logic_timer en lugar de info_target + AddThinkToEnt
        thinkWeaponChange = SpawnEntityFromTable("logic_timer", {
            targetname = "thinkWeaponChange",
            RefireTime = 0.1,
            OnTimer = "!self,RunScriptCode,::Shared.updateWeaponChange()"
        })
    }
}

function OnGameEvent_round_end(params) {
    printl("===== Round End Reason: "+params.reason)
    if (params.reason != 3) SaveTable("shared", saveData)
    
    // Cleanup del timer
    if (thinkWeaponChange && thinkWeaponChange.IsValid()) {
        thinkWeaponChange.Kill()
        thinkWeaponChange = null
    }
}
```

---

### 4. `tank_aggressive_ai.nut` — CRÍTICO

**Mecanismo:** `AddThinkToEnt` en `info_target` (línea 655)
**Frecuencia:** 0.5s (`ThinkInterval`)
**Cleanup:** ✅ SÍ (líneas 629-641: verifica y mata thinkers huérfanos)
**Problema:**
- Aunque tiene protección contra duplicados, sigue usando `AddThinkToEnt`
- El thinker nunca se ejecuta realmente en nativo

**Reemplazo recomendado:**
```squirrel
function StartTankAI()
{
    if (g_TankAIThinker && g_TankAIThinker.IsValid())
    {
        printl("[TankAI] Thinker already exists, skipping.")
        return
    }
    
    local existing = Entities.FindByName(null, "tank_aggressive_ai_think")
    if (existing && existing.IsValid())
    {
        existing.Kill()
        printl("[TankAI] Killed orphaned thinker entity.")
    }
    
    // Reemplazar info_target + AddThinkToEnt por logic_timer
    local thinkEnt = SpawnEntityFromTable("logic_timer",
    {
        targetname = "tank_aggressive_ai_think",
        RefireTime = AggressiveTankAI.ThinkInterval,
        OnTimer = "!self,RunScriptCode,::TankAI_Think()"
    })
    
    if (thinkEnt && thinkEnt.IsValid())
    {
        g_TankAIThinker = thinkEnt
        printl("[TankAI] Aggressive AI Think started (interval: " + AggressiveTankAI.ThinkInterval + "s)")
    }
}
```

---

### 5. `tacticalmovement.nut` — CRÍTICO

**Mecanismo:** `AddThinkToEnt` en entidad `fish` (línea 566)
**Frecuencia:** 0.01s (100Hz) — **MUY ALTO**
**Cleanup:** ✅ SÍ (líneas 596-599: `Kill()` en `round_end`)
**Problema:**
- Frecuencia de 100Hz es excesiva y puede causar lag
- Usa `AddThinkToEnt` → think no ejecuta
- La entidad `fish` es un hack conocido (clase inofensiva para thinkers)

**Reemplazo recomendado:**
```squirrel
function SlowerInit()
{
    // Cleanup existing timer
    local existing = Entities.FindByName(null, "tacticalmovement_timer")
    if (existing && existing.IsValid()) existing.Kill()
    
    // Usar logic_timer nativo en lugar de fish + AddThinkToEnt
    ::tacticalMovement.MovementThinkEntity = SpawnEntityFromTable("logic_timer", {
        targetname = "tacticalmovement_timer",
        RefireTime = 0.05,  // Reducir de 0.01 a 0.05 (20Hz es suficiente)
        OnTimer = "!self,RunScriptCode,::tacticalMovement.PlayerMovementCheck()"
    })
}
```

---

### 6. `rrlogic.nut` — CRÍTICO

**Mecanismo:** `AddThinkToEnt` en `info_target` (línea 164)
**Frecuencia:** 0.03s (~33Hz)
**Cleanup:** ❌ NO
**Problema:**
- No hay cleanup en `round_end`
- El timer se crea en cada `round_start`
- Sin `AddThinkToEnt` nativo, el recoil smoothing no funciona

**Reemplazo recomendado:**
```squirrel
function CreateThinker()
{
    // Cleanup previo
    local existing = Entities.FindByName(null, "c_lerp_tick")
    if (existing && existing.IsValid()) existing.Kill()
    
    // Crear logic_timer nativo
    local tick = SpawnEntityFromTable("logic_timer", {
        targetname = "c_lerp_tick",
        RefireTime = 0.03,
        OnTimer = "!self,RunScriptCode,::YsReworkedRecoil.UpdateRecoil()"
    })
    
    printl("Created logic_timer for Reworked Recoil!")
}

function OnGameEvent_round_end(params)
{
    local tick = Entities.FindByName(null, "c_lerp_tick")
    if (tick && tick.IsValid()) tick.Kill()
}
```

---

### 7. `rush_incap.nut` — CRÍTICO

**Mecanismo:** `AddThinkToEnt` en `info_target` (línea 53) + sistema `SetTimer` propio
**Frecuencia:** 0.01s (chequeo) / 1.0s (ejecución real)
**Cleanup:** ✅ SÍ (self.Kill en línea 47)
**Problema:**
- El sistema `SetTimer` está bien diseñado (con flags y auto-kill)
- Pero usa `AddThinkToEnt` para el think
- Sin VSLib, el timer nunca ejecuta

**Reemplazo recomendado:**
El sistema `SetTimer` ya es bastante robusto. Solo hay que cambiar el mecanismo de think:

```squirrel
scope.Think <- function() {
    local now = Time();
    if ((now - scope.lasttime) >= scope.delay) {
        local ret = scope.params == null
            ? scope.func()
            : scope.func(scope.params);

        if (ret && (scope.flags & TIMER_REPEAT)) {
            scope.lasttime = now;
            return scope.delay;
        } else {
            self.Kill();
        }
    }
    return 0.01;
};

// REEMPLAZAR:
// AddThinkToEnt(thinker, "Think");
// POR:
// Crear un logic_timer que llame al think
local timer = SpawnEntityFromTable("logic_timer", {
    targetname = name,
    RefireTime = 0.01
})
timer.ValidateScriptScope()
timer.GetScriptScope().owner <- thinker
timer.GetScriptScope().Callback <- function() {
    local interval = owner.GetScriptScope().Think()
    // El intervalo de retorno no se usa con logic_timer, 
    // pero podríamos ajustar RefireTime si es necesario
}
timer.ConnectOutput("OnTimer", "Callback")
EntFire(name, "Enable", "", 0.01)
```

**Alternativa más simple:** Dado que `SetTimer` ya usa `info_target`, podemos migrar todo a `logic_timer` nativo y eliminar `AddThinkToEnt` completamente.

---

### 8. `rotpi.nut` — CRÍTICO

**Mecanismo:** `AddThinkToEnt` en `info_target` (línea 72)
**Frecuencia:** 0.01s
**Cleanup:** ✅ SÍ (línea 66: `thinker.Kill()` cuando aterriza)
**Problema:**
- Usa `DoEntFire` con delay 0.25s para llamar `AddThinkToEnt` — doble problema
- Si el thinker no se registra, la animación nunca se aplica

**Reemplazo recomendado:**
```squirrel
// En lugar de:
// DoEntFire("!self", "RunScriptCode", "AddThinkToEnt(self, \"rotpi_think\")", 0.25, null, thinker);

// Crear un logic_timer asociado al thinker:
local timer = SpawnEntityFromTable("logic_timer", {
    targetname = thinker_name + "_timer",
    RefireTime = 0.01,
    OnTimer = "!self,RunScriptCode,::ROTPI.ThinkStep(\"" + thinker_name + "\")"
})

// La función ThinkStep busca el thinker y ejecuta la lógica
function ThinkStep(thinker_name)
{
    local thinker = Entities.FindByName(null, thinker_name)
    if (!thinker || !thinker.IsValid()) return
    
    local player = // ... obtener player de algún manera (scope del thinker)
    
    if (NetProps.GetPropInt(player, "m_hGroundEntity") != -1)
    {
        // Aplicar animación
        // ...
        
        // Matar thinker y timer
        thinker.Kill()
        local timer = Entities.FindByName(null, thinker_name + "_timer")
        if (timer && timer.IsValid()) timer.Kill()
    }
}
```

---

### 9. `ctsh.nut` — CRÍTICO

**Mecanismo:** `AddThinkToEnt` en `info_target` (línea 69)
**Frecuencia:** Default (0.1s)
**Cleanup:** ❌ NO
**Problema:**
- Se crea en `player_spawn` pero nunca se destruye
- Si hay muchos spawns, se crean múltiples thinkers (aunque hay chequeo `if (thinkEnt) return`)
- Sin `AddThinkToEnt`, el glow nunca se actualiza

**Reemplazo recomendado:**
```squirrel
function OnGameEvent_player_spawn(params) {
    if (!thinkEnt) thinkEnt = Entities.FindByName(null, "thinkCTH")
    if (thinkEnt) return
    
    thinkEnt = SpawnEntityFromTable("logic_timer", {
        targetname = "thinkCTH",
        RefireTime = 0.1,
        OnTimer = "!self,RunScriptCode,::CrouchToHear.update()"
    })
}

function OnGameEvent_round_end(params) {
    if (thinkEnt && thinkEnt.IsValid()) {
        thinkEnt.Kill()
        thinkEnt = null
    }
}
```

---

### 10. `fire_spreads_geeb.nut` — CRÍTICO

**Mecanismo:** `AddThinkToEnt` en `script_trigger_multiple` (línea 100)
**Frecuencia:** 0.1s (hasta que se apaga el fuego) / `lingerDuration + 1` (cuando el owner muere)
**Cleanup:** ✅ SÍ (línea 88: `EntFire("!self", "Kill", "", 3)` / línea 96: `EntFire("!self", "Kill", "")`)
**Problema:**
- Aunque tiene cleanup interno, usa `AddThinkToEnt`
- El trigger se actualiza para seguir al owner en fuego

**Reemplazo recomendado:**
```squirrel
// En lugar de AddThinkToEnt, usar un logic_timer asociado al trigger:
local timer = SpawnEntityFromTable("logic_timer", {
    targetname = trig.GetName() + "_timer",  // requiere asignar nombre al trig
    RefireTime = 0.1,
    OnTimer = "!self,RunScriptCode,::FireSpread.UpdateTrigger(\"" + trig.GetName() + "\")"
})

// Función estática que busca el trigger y actualiza
function UpdateTrigger(trigger_name)
{
    local trig = Entities.FindByName(null, trigger_name)
    if (!trig || !trig.IsValid()) return
    
    local scope = trig.GetScriptScope()
    local owner = scope.owner
    
    if (!owner || !owner.IsValid()) {
        trig.Kill()
        return
    }
    
    trig.SetOrigin(owner.GetCenter())
    // ... resto de la lógica ...
}
```

---

### 11. `item_buffs.nut` — CRÍTICO

**Mecanismo:** `AddThinkToEnt` en weapon entities (líneas 67, 133, 176, 220)
**Frecuencia:** 1s (Gnome) / 10s (Medkit) / 15s (Pills) / 35s (Adrenaline)
**Cleanup:** ❌ NO
**Problema:**
- Agrega think a entidades de arma dinámicamente
- Las armas pueden dropearse, despawnearse, o cambiar de owner
- Sin `AddThinkToEnt`, los buffs nunca se aplican

**Reemplazo recomendado:**
Este es el caso más complejo. En lugar de attach thinks a weapons, usar un **timer global** que itere sobre las armas:

```squirrel
// Crear un único timer global para todos los item buffs
function OnGameEvent_round_start_post_nav(event)
{
    printl("ITEM BUFFS WORKING")
    
    local existing = Entities.FindByName(null, "item_buffs_timer")
    if (existing && existing.IsValid()) existing.Kill()
    
    SpawnEntityFromTable("logic_timer", {
        targetname = "item_buffs_timer",
        RefireTime = 1.0,  // El intervalo más corto de todos los buffs
        OnTimer = "!self,RunScriptCode,::ItemBuffsGlobalThink()"
    })
}

function ItemBuffsGlobalThink()
{
    // Iterar sobre todas las armas equipadas y aplicar efectos
    // según el tipo y el tiempo transcurrido
    // ...
}
```

**Nota:** Este requeriría un refactor significativo. Una alternativa más simple es usar `DoEntFire` con delays específicos para cada tipo de buff.

---

### 12. `fallenspawn_.nut` — CRÍTICO

**Mecanismo:** `AddThinkToEnt` en `info_target` (línea 760)
**Frecuencia:** 1.0s
**Cleanup:** ❌ NO
**Problema:**
- Se crea un thinker por cada spawn de Fallen Survivor
- Si hay múltiples spawns, hay múltiples thinkers
- Nunca se limpian

**Reemplazo recomendado:**
```squirrel
// En lugar de crear un thinker por spawn, crear un timer global
local timer = SpawnEntityFromTable("logic_timer", {
    targetname = "fallenspawn_checker",
    RefireTime = 1.0,
    OnTimer = "!self,RunScriptCode,::FallenSpawn.CheckSpawnConditions()"
})

// La función CheckSpawnConditions itera sobre todas las condiciones pendientes
function CheckSpawnConditions()
{
    // Iterar sobre array de pending spawns y verificar flow
}
```

---

### 13. `bleeding.nut` — CRÍTICO

**Mecanismo:** `AddThinkToEnt` en `info_target` (línea 44)
**Frecuencia:** 0.01s (chequeo) / 1.0s (ejecución)
**Cleanup:** ✅ SÍ (línea 47: `self.Kill()`)
**Problema:**
- El sistema `SetTimer` es robusto (similar a `rush_incap`)
- Pero depende de `AddThinkToEnt`

**Reemplazo recomendado:**
Igual que `rush_incap`: migrar el sistema `SetTimer` a usar `logic_timer` nativo.

---

### 14. `passivetank_scopemanager.nut` — CRÍTICO

**Mecanismo:** `AddThinkToEnt` en `info_director` (línea 13)
**Frecuencia:** Variable (`PassiveTank.Settings.ThinkInterval`)
**Cleanup:** ✅ SÍ (función `RemoveMainFromScope`, línea 16)
**Problema:**
- Usa `info_director` como entidad thinker (mejor que `info_target`)
- Pero sigue usando `AddThinkToEnt`
- `AddThinkToEnt(relay, null)` en línea 20 para "detener" — esto es específico de VSLib

**Reemplazo recomendado:**
```squirrel
function AddMainToScope()
{
    if (PassiveTank.GlobalTimer == null)
    {
        PassiveTank.GlobalTimer = SpawnEntityFromTable("logic_timer", {
            targetname = "PassiveTank_MainThinker",
            RefireTime = PassiveTank.Settings.ThinkInterval,
            OnTimer = "!self,RunScriptCode,::PassiveTank.ScopeManager.UpdatePassiveTankMain()"
        })
    }
}

function RemoveMainFromScope()
{
    if (PassiveTank.GlobalTimer != null)
    {
        PassiveTank.GlobalTimer.Kill()
        PassiveTank.GlobalTimer = null
    }
}
```

---

### 15. `clipempty.nut` — ✅ OK (Ya usa nativo)

**Mecanismo:** `logic_timer` nativo (línea 143)
**Frecuencia:** 0.1s (10Hz)
**Cleanup:** ✅ SÍ (líneas 51-59: `Kill()` en `round_end`)
**Estado:** Este script es el **patrón correcto**. Ya usa `logic_timer` nativo con cleanup.

**Nota:** El comentario en línea 6 dice "Eliminated VSLib timer system (info_target + AddThinkToEnt leak)" — esto confirma que el autor ya sabía del problema y lo corrigió.

---

### 16-24. Scripts con `logic_timer` sin cleanup en `round_end`

#### `infected_regen.nut`
- **Mecanismo:** `logic_timer` con `OnTimer` → `RunScriptCode`
- **Cleanup:** SÍ en `round_start` (líneas 74-76: mata timer anterior antes de crear nuevo)
- **Problema:** No hay cleanup en `round_end`, pero como se recrea en cada `round_start`, el leak es mínimo
- **Recomendación:** Agregar `OnGameEvent_round_end` con `Kill()` por seguridad

#### `chch_uncommons.nut`
- **Mecanismo:** `logic_timer` con `OnTimer`
- **Frecuencia:** 0.03s (muy alto)
- **Cleanup:** ❌ NO
- **Problema:** Timer se spawnea en cada `round_start`. Si no se mata, se acumulan.
- **Recomendación:** Agregar `targetname` y cleanup en `round_end`

#### `water_slowdown_reduction.nut`
- **Mecanismo:** `logic_timer` ×2 (think + cleanup)
- **Cleanup:** ❌ NO
- **Problema:** Dos timers persistentes. El cleanup timer de 30s es redundante si hay `round_end`.
- **Recomendación:** Agregar cleanup en `round_end` para ambos timers

#### `hunter_jump.nut`
- **Mecanismo:** `logic_timer` ×2 (`Witch_HunterJumpThinker` + `Ground_Thinker`)
- **Cleanup:** ❌ NO
- **Problema:** Dos timers en `round_start`. El segundo (`timer_ground`) tiene `StartDisabled = 1`.
- **Recomendación:** Agregar `targetname` único y cleanup en `round_end`

#### `tankfire.nut`
- **Mecanismo:** `logic_timer`
- **Cleanup:** ❌ NO
- **Recomendación:** Agregar cleanup en `round_end`

#### `ci_death_fix.nut`
- **Mecanismo:** `logic_timer` con Enable/Disable inteligente
- **Cleanup:** Parcial (se desactiva cuando no hay infected muriendo)
- **Problema:** No hay `round_end` cleanup. El timer queda desactivado pero vivo.
- **Recomendación:** Agregar `Kill()` en `round_end`

#### `ladder_sounds.nut`
- **Mecanismo:** `logic_timer`
- **Cleanup:** ❌ NO
- **Recomendación:** Agregar cleanup en `round_end`

#### `smoker_momentum_tongue.nut`
- **Mecanismo:** `logic_timer` con `KillUpdateTimer()`
- **Cleanup:** SÍ (se mata cuando no hay drags activos)
- **Problema:** No hay `round_end` cleanup de emergencia
- **Recomendación:** Agregar `KillUpdateTimer()` en `OnGameEvent_round_end`

#### `dashing.nut`
- **Mecanismo:** `logic_timer`
- **Cleanup:** ❌ NO
- **Problema:** Timer persistente. Aunque es eficiente, no hay cleanup.
- **Recomendación:** Agregar cleanup en `round_end`

#### `boomer_fall.nut`
- **Mecanismo:** `logic_timer`
- **Cleanup:** ❌ NO
- **Recomendación:** Agregar cleanup en `round_end`

---

### 25. `overdose_pills.nut` — WARNING

**Mecanismo:** `Schedule()` recursivo (línea 81)
**Frecuencia:** 7.5s
**Cleanup:** ✅ SÍ (flag `bActive`, líneas 97-100)
**Problema:**
- `Schedule()` es una función de VSLib (no nativa)
- Aunque tiene flag `bActive`, si `Schedule` no existe, el loop nunca inicia
- El stub de `_vscript_stubs.nut` no define `Schedule`

**Reemplazo recomendado:**
```squirrel
function ScheduleNextCheck()
{
    DoEntFire("worldspawn", "RunScriptCode", 
        "::OverdosingAddon.CheckMaxHPLoop()", 7.5, null, null)
}
```

O usando `logic_timer`:
```squirrel
function Start()
{
    ::OverdosingAddon.bActive = true
    
    local timer = Entities.FindByName(null, "overdose_pills_timer")
    if (timer && timer.IsValid()) timer.Kill()
    
    SpawnEntityFromTable("logic_timer", {
        targetname = "overdose_pills_timer",
        RefireTime = 7.5,
        OnTimer = "!self,RunScriptCode,::OverdosingAddon.CheckMaxHPLoop()"
    })
}

function OnGameEvent_round_end(params)
{
    ::OverdosingAddon.bActive = false
    ::OverdosePlayers.clear()
    
    local timer = Entities.FindByName(null, "overdose_pills_timer")
    if (timer && timer.IsValid()) timer.Kill()
}
```

---

## 🎯 PLAN DE ACCIÓN RECOMENDADO

### Prioridad 1: CRÍTICO (Crashean sin VSLib)

1. **maolib.nut** — Refactorizar `AddMonitor` para usar `logic_timer`
2. **shared.nut** — Migrar a `logic_timer` + agregar `round_end` cleanup
3. **tacticalmovement.nut** — Migrar a `logic_timer` (y bajar frecuencia a 0.05s)
4. **tank_aggressive_ai.nut** — Migrar a `logic_timer`
5. **rrlogic.nut** — Migrar a `logic_timer` + agregar cleanup
6. **item_buffs.nut** — Refactorizar a timer global o `DoEntFire` delays
7. **restore_crawlanim.nut** — Migrar a `logic_timer`
8. **rush_incap.nut** — Migrar sistema `SetTimer` a `logic_timer`
9. **bleeding.nut** — Igual que rush_incap
10. **rotpi.nut** — Migrar think a `logic_timer` asociado
11. **ctsh.nut** — Migrar a `logic_timer`
12. **fire_spreads_geeb.nut** — Migrar trigger update a `logic_timer`
13. **fallenspawn_.nut** — Migrar a timer global
14. **passivetank_scopemanager.nut** — Migrar a `logic_timer`

### Prioridad 2: WARNING (Entity leaks)

1. **chch_uncommons.nut** — Agregar `targetname` + cleanup `round_end`
2. **water_slowdown_reduction.nut** — Agregar cleanup `round_end`
3. **hunter_jump.nut** — Agregar cleanup `round_end`
4. **tankfire.nut** — Agregar cleanup `round_end`
5. **ladder_sounds.nut** — Agregar cleanup `round_end`
6. **dashing.nut** — Agregar cleanup `round_end`
7. **boomer_fall.nut** — Agregar cleanup `round_end`
8. **ci_death_fix.nut** — Agregar `Kill()` en `round_end`
9. **smoker_momentum_tongue.nut** — Agregar `KillUpdateTimer()` en `round_end`
10. **infected_regen.nut** — Agregar cleanup `round_end`

### Prioridad 3: MEJORA

1. **overdose_pills.nut** — Reemplazar `Schedule()` por `DoEntFire` o `logic_timer`
2. **_vscript_stubs.nut** — Actualizar stub de `AddThinkToEnt` para loggear warning en runtime
3. **Crear sistema de cleanup global** en `l4c_entity_cleanup.nut` (ya existe, verificar que cubra todos los casos)

---

## 📚 REFERENCIAS

- [Steam Community: Update() Function compatibility](https://steamcommunity.com/app/550/discussions/3/5671690972173005574/) — Rectus explica alternativas nativas a `AddThinkToEnt`
- [Leeland VScript FAQ](https://www.leeland.info/vscript-faq.html) — Documentación de funciones nativas
- `clipempty.nut` — Ejemplo de script ya migrado a `logic_timer` nativo
- `_vscript_stubs.nut` — Stub vacío que confirma `AddThinkToEnt` no es nativo

---

## ✅ CHECKLIST DE VERIFICACIÓN

- [ ] ¿Todos los scripts con `AddThinkToEnt` tienen reemplazo nativo?
- [ ] ¿Todos los `logic_timer` tienen `targetname` único?
- [ ] ¿Todos los timers tienen cleanup en `OnGameEvent_round_end`?
- [ ] ¿Se eliminó toda referencia a `AddThinkToEnt` en código de producción?
- [ ] ¿Se probó sin VSLib cargado?
- [ ] ¿No hay frecuencias >20Hz innecesarias?

---

*Reporte generado automáticamente por análisis de VScript L4D2.*
