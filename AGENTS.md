# Lost 4 Creed — L4D2 Modpack

Horror/coop modpack. Custom campaign + gameplay + VScript.

## ADDONS (source→VPK)
`l4cCoreAddon` — Core director, MaoLib, game logic
`l4cCoreSurvivorGameplay` — Survivor perks, movement
`l4cCoreVisuals` — Textures, models, VFX
`l4cMapRefresh` — Map props + events (c1m1-c8m5)
`l4cCustomInfected` — Custom specials
`l4cEnvironmentCore` — Environment
`l4cHudGUI` — HUD
`l4cWeaponItemScripts` — Weapons, items
`l4cWeaponSounds` — Weapon audio
`l4cInfectedGameplay` — Infected AI
`l4cSurvivorsCast` — Survivor models

**VPK:** `vpk.exe <folder>` → `<folder>.vpk` en PARENT dir. NO `vpk create folder output.vpk`.

---
## ⚠️ LOAD ORDER

```
1. mapspawn.nut                → getroottable()
2. mapspawn_addon.nut          → getroottable()
3. response_testbed_addon.nut  → g_rr
4. [modename].nut/.nuc         → g_ModeScript (ChallengeScript)
5. [mapname]_[modename].nut    → g_MapScript
6. scriptedmode_addon.nut      → g_MapScript
7. director_base_addon.nut     → DirectorScript
8. director_base_addon.nut (!) → DirectorScript (OTRO addon, NO replace)
9. [mapname]_finale.nut        → g_MapScript (trigger_finale)
10. Entity scripts (KV)        → _<ID>_<name> (on spawn)
11. info_director BeginScript  → LocalScript (on demand)
```

**DO priority:** `DirectorScript.DO ← MapScript.DO ← LocalScript.DO ← ChallengeScript.DO` (LOW→HIGH).
Key missing → walk UP chain.

**Scope tree:**
```
getroottable()  ← mapspawn, mapspawn_addon
DirectorScript  ← director_base_addon.nut
  └─ DirectorOptions
MapScript (g_MapScript) ← mode, map, scriptedmode, finale
  ├─ DirectorOptions, BaseScriptedDOTable
  ├─ ChallengeScript (g_ModeScript) ← MAX PRIORITY
  │   └─ DirectorOptions, MutationState
  ├─ LocalScript (info_director BeginScript)
  └─ MapOptions/MapState
```

**Hechos críticos:**
- TODOS los `director_base_addon.nut` (mismo nombre, distintos VPKs) EJECUTAN. NO replace.
- `l4cCoreAddon/director_base_addon.nut` DEBE cargar primero → provee MaoLib.
- NO crear `mapspawn_addon.nut` a menos que sea esencial → contamina getroottable().

---
## ⚠️ VERIFICACIÓN VSLIB → NATIVO
NO USAMOS VSLib. Solo código NATIVO (VScript + MaoLib).
Si ves `EntityOutputs`, `VSLib::*`, `Utils.*` en código → **reemplazar con nativos**.
**Natives válidos:** `DoEntFire`, `EntFire`, `EmitSoundOn`, `StopSoundOn`, `EntFireByHandle`, `DispatchSpawn`, `NetProps.*`.
**NavMesh:** `NavMesh.*` confirmados en este binario (GetNearestNavArea, NavAreaBuildPath, GetNavAreasInRadius, GetAllAreas, GetNavAreaCount, FindNavAreaAlongRay).

---
## ⚠️ EVENTOS — 4 REGLAS

> **⛔ `maolib_events.nut` fue ELIMINADO (23/05/2026).** No hay sistema central de eventos. Cada script gestiona los suyos.

### R1: SIEMPRE tabla, NUNCA función global
```vscript
::Script <- { function OnGameEvent_hurt(p) { } }  // ✅
__CollectGameEventCallbacks(::Script);
function OnGameEvent_hurt(p) { }                   // ❌ HIJACKEA
```

### R2: `__CollectGameEventCallbacks(getroottable())` PROHIBIDO
→ Registra TODO en global → sobrescribe tablas → CRASH.

### R3: Global `OnGameEvent_*` HIJACKEA evento
Si existe función global + tabla registrada para mismo evento → global gana → tabla NUNCA recibe → CRASH.

### R4: Sintaxis METHOD `function Name()`, NUNCA property `Name = function()`
```vscript
::Tab <- { helper=42, function OnGameEvent_spawn(p) { helper } }  // ✅ method hereda scope
::Tab <- { helper=42, OnGameEvent_spawn = function(p) { helper } } // ❌ property busca global
```
**Causa:** Methods heredan table environment (Squirrel 3.2 §2.8.2). Properties no. Commas: methods no necesitan, properties SÍ.

| Patrón | Válido? |
|--------|---------|
| Table + `__CollectGameEventCallbacks(table)` | ✅ |
| `__CollectGameEventCallbacks(getroottable())` | 🚫 |
| `function OnGameEvent_*()` global | 🚫 |
| `function Helper()` global (no OnGameEvent_) | ✅ |

---
## ⚠️ METHOD DETACHMENT (Squirrel Pitfall #1)

Pasar método de tabla como callback → pierde `this`.
```vscript
MaoLib.AddTimer("n", 0.5, Table.Method)                            // ❌
MaoLib.AddTimer("n", 0.5, function() { Table.Method(); })          // ✅
g_MapScript.ScriptedMode_AddUpdate(function() { this.Method(); })  // ✅
MaoLib.AddTimerSafe("n", 0.05, @() ::Table.Method())              // ✅
```

---
## ⚠️ LOOP-VARIABLE CLOSURE CAPTURE (Pitfall #2)

Closure en loop captura variable POR REFERENCIA. Todos los closures comparten la misma binding.
```vscript
// ❌ — 'ent' = null al disparar el timer
while (ent = Entities.FindByClassname(ent, "infected")) {
    MaoLib.AddTimer("t_"+ent.entindex(), 0.5, function() { Do(ent) })
}
// ✅ — 'captured' es NUEVA binding cada iteración
while (ent = Entities.FindByClassname(ent, "infected")) {
    local captured = ent
    MaoLib.AddTimer("t_"+captured.entindex(), 0.5, function() { Do(captured) })
}
```

---
## ⚠️ SELF-CONTAINED OPS

NO fragmentar lógica que depende de entidad VIVA en callbacks diferidos.
- ❌ `EntFire("worldspawn","RunScriptCode",...)` — entindex expira
- ❌ `DoEntFire("!self","RunScriptCode",...)` — self.Kill() ignorado
- ❌ Guardar entindex para otro frame → slot reasignable

**Si NECESITAS delay:** closure con guard:
```vscript
MaoLib.AddTimer("check", 0.5, function() {
    if (!ent || !ent.IsValid()) return
    if (NetProps.GetPropInt(ent, "m_lifeState") != 0) return
    // ... seguro ...
})
```

---
## 🔴 DEBUG SYSTEM — OBLIGATORIO

```vscript
::MiScript <- {
    Debug = 1  // 0=silent, 1=verbose
    function Dbg(msg) { if (Debug) printl("[MiScript][DBG] "+msg) }
    function DbgWarn(msg) { printl("[MiScript][WARN] "+msg) }
    function OnGameEvent_X(p) {
        Dbg("ENTER X; uid="+p.userid)
        // ... Dbg() en cada decision ...
        Dbg("EXIT X")
    }
}
```
Toda fn pública → `Dbg("ENTER/EXIT")`. Todo `return` temprano → explicar por qué.

---
## 🔴 DirectorScript.X SCOPE BUG

`IncludeScript("x", getroottable())` → variable en `getroottable()`, NO en `DirectorScript`.
```vscript
DirectorScript.myVar.member  // ❌ null → crash
::myVar.member               // ✅
```

---
## MAOLIB — DEPENDENCIA DURA

Carga: `IncludeScript("maolib", getroottable())` + navutils, vfx, input, state, cooldowns, hud, modifiers, aoe, status, status_hooks, mapper.

Namespaces: `::MaoLib`, `::MaoLib.NavUtils`, `::MaoLib_VFX`, `::MaoLib.Input`, `::MaoLib.PlayerState`, `::MaoLib.Cooldowns`, `::MaoLib.HUD`, `::MaoLib.Modifiers`, `::MaoLib.AoE`, `::MaoLib.StatusEffects`, `::MaoLib.Mapper`

### 🔴 NUNCA `if ("MaoLib" in getroottable())` — SILENT KILLER

Asume que MaoLib existe. Si falla, el script DEBE crashear con error visible. Un check condicional crea scripts zombie (cargan, no crashean, no hacen nada).

**Excepciones (solo self-check):** `maolib.nut`, `maolib_navutils.nut`, `maolib_timers_cleanup.nut`

### Method vs Global
```
// METHODS (entity.Method()):
.IsValid() .GetHealth() .GetOrigin() .Kill() .EyePosition() .EyeAngles()
.GetForwardVector() .entindex() .IsPlayer() .IsSurvivor() .Stagger()
.SetHealthBuffer() .GetActiveWeapon() .GiveItem() .GiveAmmo()

// GLOBALS (fn(entity)):
IsPlayerABot() EntIndexToHScript() GetPlayerFromUserID() Time() UniqueString()
```

### Iteradores: `YieldSurvivors()` `YieldSpecials()` `YieldWitches()` `YieldPlayers()`
### Utils: `GetScope(e)` `IsReal(e)` `IsAlive(e)` `IsAlivePlayer(p)` `DistanceBetween(p1,p2)` `min/max(a,b)` `clamp(min,v,max)` `Probability(25)→bool` `startswith(s,p)` `Replace(s,p,r)` `printf(fmt,...)`
### Witch: `SetWitchAnger(w,0.5)` `GetWitchAnger(w)`
### Target: `GetTarget(e)/ForceTarget(e,t)` `GetTargetMisc(i)/ForceTargetMisc(i,t)`

### Timer Manager — SIEMPRE usar, NUNCA logic_timer/AddThinkToEnt
```
AddTimer(name,int,fn)  AddTimerForce/Safe/Auto(name,int,fn)
RemoveTimer(name)  PauseTimer/ResumeTimer(name)  IsTimerActive(name)
ClearAllTimers()  PrintTimerStats()
DelayCall(fn,sec)  DelayCallOpt(fn,sec)  // ⚠️ DelayCall=one-shot, AddTimer=RECURRENTE
```
**Cleanup obligatorio:** Cada script DEBE limpiar timers en `round_end`/`mission_lost`/`map_transition`. `maolib_timers_cleanup.nut` es MONITOR ONLY.

### 🔥 CRÍTICO: AddTimer vs DelayCall
`AddTimer` = recurrente (dispara cada `interval` PARA SIEMPRE). `DelayCall` = one-shot (auto-remove).
```vscript
MaoLib.AddTimer("x", 0.3, fn)  // ❌ INFINITO si querías one-shot
MaoLib.DelayCall(fn, 0.3)      // ✅ one-shot
```

---
## MAOLIB API (compacta)

### NavUtils
`GetNearestNavArea(pos,maxDist,blocked)` `BuildPath(start,end,team)→array` `TravelDistance(start,end,maxDist)` `HasLineOfSight(s,e,ignore)` `CanSeeEntity(viewer,target)` `FindHighGround(c,R,minH)` `FindChokePoints(c,R)` `FindFlankingRoutes(t,R,side)` `FindRockSpots(tank,surv,R=1500)` `FindMostVulnerableSurvivor(surv)` `AreSurvivorsGrouped(surv,maxD)` `GetFlowDistanceToSurvivors(e,surv)` `IsAheadOfSurvivors(e,surv)` `IsNearFire(e,R=200)` `CountNearbyInfernos(e,R=500)`

### Input (tracker central, 1 timer 0.05s)
```vscript
MaoLib.Input.Register(uid, btn, "pressed|released|held", fn)
MaoLib.Input.Unregister(uid, btn, eventType)
// btns: IN_SPEED=131072, IN_USE=32, IN_ATTACK2=512, IN_RELOAD=32
```

### PlayerState
`Set/Get/Delete(uid,key,val?)` `Clear(uid)` `Has(uid,key)` `RegisterOnClear(name,cb)`
Convención: prefijar keys con script (`jaime_`, `brock_`, etc.)

### Cooldowns
`Start(uid,name,dur)` `IsReady(uid,name)→bool` `GetRemaining(uid,name)→float` `Reset/ResetAll(uid)` `AutoNotify(uid,name,msg,sound,hudType)`

### HUD
`Notify(player,msg,{mode,typeKey,throttle,duration,color,sound,priority})` `NotifyAll(msg,opts)` `Clear(player,ch)` `ColorGreen/Red/Yellow(text)`

### Modifiers (speed/friction — think 0.3s activo)
```vscript
RegisterSpeed(player,mult,dur,source)  // 1.0=base, 0.85=-15%, -1=perma
RegisterFriction(player,fric,dur,source)  // >1=más lento, final=MAX
GetSpeedMultiplier(p)→float  GetFriction(p)→float
ClearAll(p)  ClearSource(p,src)  ListActive(p)
```
**Arquitectura:** Modifiers registra+computa. `system_perks_unified.nut` consume.

### AoE (Selector→Aplicador)
```vscript
// Selectores → array
MaoLib.AoE.Select.Circle(origin,R,{className,filter,requireLOS,maxResults,aliveOnly})
MaoLib.AoE.Select.Cone(origin,dir,halfAngle,maxDist,opts)
MaoLib.AoE.Select.Line(origin,dir,len,width,opts)
MaoLib.AoE.Select.ExpandingCircle(origin,maxR,dur,pulses,onPulse)→timerName

// Aplicadores
MaoLib.AoE.Apply.Damage(tgts,dmg,attacker,type,{falloff,origin,radius,minDamage,onHit})
MaoLib.AoE.Apply.Heal/HealTemp(tgts,amount) .Stagger(tgts) .Push(tgts,force)
MaoLib.AoE.Apply.ModifierSpeed/Friction(tgts,mult/fric,dur,src) .Callback(tgts,fn)
```

### StatusEffects v2.0 (buffs/debuffs — hooks automáticos)
**Convención:** Movimiento→Modifiers. Todo lo demás→StatusEffects.
```vscript
Apply(entity, cat, src, val, dur, opts?)  // opts: {targetFlags}
Get(entity, cat, targetFlags?)  Remove(entity, cat, src)  ClearAll(entity)
ApplyDoT(entity, "dot_bleed", src, dps, dur, attacker, targetFlags)
RegisterCallback(src, "onExpire", fn)  ListActive(entity)
```
**Hooks automáticos:** `player_hurt`(damage_in/out,lifesteal,fire_immunity) `infected_hurt`(ci_damage_in/out) `weapon_fire`(fire_rate,melee_speed,ammo) `entity_shoved`/`player_shoved`(stagger_immunity,shove_penalty) `heal_success`/`revive_success`(heal_given/received) `pills_used`(heal_received) `player_spawn`(max_health)

**Target Flags:** `DOT_TARGET_SURVIVOR(1)|COMMON(2)|SI(4)|BOSS(8)|ALL(15)`

### Mapper (map utils)
`ConnectOutput/DisconnectOutput(ent,output,cbName)` `AddOutput(src,out,tgt,in,param,delay,times)` `SpawnWithOutput(class,kv,outputs)` `ApplyDirectorOptions(opts)` `ShuffleArray(arr)` `SpawnReducedProps(tbl,density,fn)` `GetClosestSurvivor(pos,incap,dead)` `TriggerMegaMob()` `IsAnyoneInCombat()` `ForbidTarget/AllowTarget(ent)` `StaggerPlayer(p,from)` `GiveTempHealth(p,amt)` `ExtinguishPlayer(p)` `RevivePlayer(p,defib)` `FindNearest(class,pos,R)` `FindByClassnameWithin(class,pos,R,cb)` `FireCustomEvent(id)`

### VFX v2.2
`SpawnParticle(pos,fx,life=3,prio)→handle` `SpawnParticleOnEntity(e,fx,attach,life,prio)` `SpawnTrail(e,fx,attach,prio)→handle` `StopParticle(p,fade)` `SpawnRing/Spiral/Wave/Curve/CircleFilled` `SpawnExplosion(pos,"small|med|large")` `SpawnImpact(pos,norm,"blood|concrete|metal|wood|dirt")` `SpawnDecal(pos,norm,"blood|scorch|etc")` `EmitSound(ent,path,vol,pitch)` `EmitSoundAt(pos,path,vol,pitch)` `EmitSoundOnClient(player,path)` `ScreenShake(pos,amp,freq,dur,R)` `ScreenEffect(p,"blood|adrenaline|bashed",dur)` `GetEffectPosition(e)` `SafeKill(e,delay)` `IsValidPosition(pos)` `Keyframes.Animate/LerpVector/LerpFloat`

⚠️ NEVER `LookupBone` en "infected" → usar `GetEffectPosition(e)`. Budget: `critical`(8/s) `gameplay`(12/s) `ambient`(4/s).

---
## 🧪 TEST — `testing/test_vscripts.ps1`

| Pattern | Severidad |
|---------|-----------|
| `MaoLib.AddTimer*(...,word,word)` method detachment | 🔴 CRITICAL |
| `ScriptedMode_AddUpdate(word)` | 🔴 CRITICAL |
| `DirectorScript.Word` (global cross-ref) | 🔴 CRITICAL |
| `function OnGameEvent_*` global | 🟡 HIGH |
| `Word = function(` en events table | 🟡 HIGH |

Run: `.\testing\test_vscripts.ps1 -Full -Verbose`

---
## 🗺️ l4cMapRefresh

**Archivos:** `director_base_addon.nut`(entry) `maprefresh_main.nut`(loader) `maprefresh_utils.nut`(spawners) `maprefresh_proptypes.nut`(33 categorías) `maprefresh_refdata.nut`(coords) `cXmY_mapname.nut`(per-map)

**Mapas activos con eventos:** c1m1_hotel(sky elevator+tank) c1m2_streets(gunshop ambush+gas tanker) c2m1_highway(HELI HOTEL: flyover→crash→tank+slowmo) c2m2_fairgrounds(wood barricade) c2m4_barns(barn tank hold-zone) c3m2_swamp(aircraft crash) c3m3_shantytown(corridor tank)

**Mapas solo props:** c2m3_coaster c8m1_apartment c8m2_subway c8m3_sewers c8m4_interior c8m5_rooftop

**Pendientes (registrados sin script):** c5m1_waterfront c5m2_park c5m3_cemetery c5m4_quarter

**Skipped:** c1m3_mall c1m4_atrium c2m3_coaster(scavenge) c2m5_concert c3m1_plankcountry c3m4_plantation

**Design:** 60% prop density, MaoLib hard dep, no VSLib, eventos>props, EntityOutputs nativos via Mapper.

---
## 🔧 LSP SQUIRREL

`tools/squirrel-lsp/bin/squirrel-lsp.exe` (lostluna1/Squirrel-LSP). `vscript_stubs.nut` — 1012 lines typedefs.
Config `opencode.json`: `squirrel-lsp.exe --stdio`. Include paths → vscripts dirs + `tools/squirrel-lsp`.

---
## 🔨 VTF-TOOLS

`tools/vtf-tools/` — 14 CLI tools. Build: `clang++` via `_build_clang.bat`.
**Regla:** usar `vtf_force_72` (VTF 7.2), no 7.5. 7.5 + double-zap = corrupt.
**Bug fix (27 May):** vtfzapmain reescrito con VTFLib API pura. `Save(void*,vlUInt,vlUInt&)` — 3er param OUT ref, variable NO puede ser const.

---
## 📦 VPK COMPILER

```powershell
.\Compile-VPKs.ps1                     # Interactive menu
.\Compile-VPKs.ps1 -Force              # Rebuild all
.\Compile-VPKs.ps1 -ExcludeFromDefender # Turbo mode
```
Orden addons (dependencia): 1.l4cCoreAddon 2.CoreSurvivorGameplay 3.CoreVisuals 4.MapRefresh 5.CustomInfected 6.InfectedGameplay ... (16 total)
Output: `D:\Software\SourceStuff\addons\compiled\`

---
## 📂 AGENTS

`C:\Users\Lord Gatito\.config\opencode\agents\`
| Agent | File | Role |
|-------|------|------|
| ELLIS | `ellis.md` | VScript L4D2 expert — analysis, debug, scripts |
| KEITH | `keith.md` | VScript verifier — errors, conflicts, validation |

---
## 📚 NATIVES RÁPIDOS

### Sonido
`EmitSoundOn(sound,ent)` `EmitAmbientSoundOn(s,vol,level,pitch,ent)` `EmitSoundOnClient(s,player)` `StopAmbientSoundOn(s,ent)` `StopSoundOn(s,ent)`

### Entity Spawn
`SpawnEntityFromTable(class,kv)→handle` `SpawnEntityGroupFromTable(tbl)→bool` `PrecacheEntityFromTable(tbl)→bool`

### Director
`Director.GetGameMode()` `GetMapName()` `ResetMobTimer()` `ResetSpecialTimers()` `IsSinglePlayerGame()` `IsTankInPlay()` `GetAveragedSurvivorSpan()` `GetAveragedSurvivorSpeed()` `GetCommonInfectedCount()` `GetRandomSurvivor()`

### NavMesh
`NavMesh.GetNearestNavArea(pos,maxD,LOS,ground)` `NavAreaBuildPath(s,e,goal,maxD,team)→bool` `GetNavAreasInRadius(c,R,tbl)` `GetAllAreas(tbl)` `GetNavAreaCount()` `FindNavAreaAlongRay(s,e,ignore)`

### Screen
`ScreenShake(center,amp,freq,dur,R,cmd,air)` `ScreenFade(p,r,g,b,a,fadeT,hold,flags)`

### Partículas — Reglas
- `info_particle_system` requiere `Start` input obligatorio
- `Stop` antes de reiniciar. `DestroyImmediately` para kill sin fade.
- Hasta 64 Control Points. CP0 = origen default.

### Eventos — attacker/attackerentid/entityid

| Evento | Campo | Tipo | Significado |
|--------|-------|------|-------------|
| `player_hurt` | `userid` | short | Víctima (userid) |
| | `attacker` | short | userid (players/SI) o **0** (CI — inválido) |
| | `attackerentid` | long | **entindex** del CI atacante (usar `EntIndexToHScript`) |
| `infected_hurt` | `entityid` | short | entindex del CI herido |
| | `attacker` | short | userid del player/SI |
| `player_death` | `attacker` | short | userid |
| `infected_death` | `attacker` | long | entindex |

🚨 `params.entityid` NO existe en `player_hurt`. Usar `params.attackerentid`.

---
## 📚 FUENTES

| Fuente | URL | Prioridad |
|--------|-----|-----------|
| **L4D2node VScript API** 🔥 | https://vscript.l4d2node.org/ | #1 — API real del binario |
| **VDC** | https://developer.valvesoftware.com/ | #2 — Entidades, keyvalues |
| **Squirrel 3.0 Manual** | http://squirrel-lang.org/doc/squirrel3.html | #1 — Sintaxis lenguaje |
| **AlliedModders Events** | https://wiki.alliedmods.net/Left_4_dead_2_events | #3 — Eventos |
| **LeeLand VScript FAQ** | https://www.leeland.info/vscript-faq.html | #4 — Tips |
| **VSLib** | https://github.com/L4D2Scripters/vslib | #5 — Patrones |

> **VDC/L4D2node > AlliedModders > LeeLand > VSLib > Pre-trained knowledge**

---
## ⚠️ ENTIDADES PROBLEMÁTICAS

| Patrón | Riesgo |
|--------|--------|
| `info_null` (2+) | 🔴 Crash al cerrar saferoom |
| `env_projectedtexture` | 🔴 Crash en L4D2 |
| `ambient_generic.SetParent()` | 🔴 NO soporta parenting de posición |
| `LookupBone` en "infected" | 🔴 Crash — usar `GetEffectPosition()` |
| `QAngle.ToKVString()` | 🔴 NO existe — string manual |
| Operador `<=>` | 🔴 NO existe en Squirrel |

### Nativos que NO funcionan como esperas
- `ambient_generic`: Usar `SourceEntityName` keyvalue apuntando a info_target para sonido posicional
- `ApplyAbsVelocityImpulse`: Sí funciona, pero envolver en try/catch
- `EmitSoundOn(sound, entity)`: Nativo de 2 params (sound, entity)

---
## 🐛 BUGS COMUNES

### `ambient_generic` — NO `SetParent()`
```vscript
ambient.SetParent(ent)  // ❌ CRASH
// ✅ Usar keyvalue SourceEntityName apuntando a info_target:
local t = SpawnEntityFromTable("info_target", {origin=ent.GetOrigin(), targetname="t_"+UniqueString()})
ambient.__KeyValueFromString("SourceEntityName", t.GetName())
```

### `QAngle` — NO `.ToKVString()`
`angles = myAngle.x + " " + myAngle.y + " " + myAngle.z`

### `<=>` NO existe en Squirrel
`array.sort(function(a,b){return a.val-b.val})`

### `ApplyAbsVelocityImpulse` — wrapper con try/catch
```vscript
try { ent.ApplyAbsVelocityImpulse(vel) } catch(e) {}
```

### DirectorScript vs getroottable()
`IncludeScript("x",getroottable())` → variable en getroottable(). `DirectorScript.myVar` = null.

### `info_particle_system` lifecycle
Spawn → `Start` → `Stop`(si reusas) → `Kill`(con delay) o `DestroyImmediately`.

---
## 🔴 3 PATRONES SISTÉMICOS

### 1. AddTimer = RECURRENTE. DelayCall = ONE-SHOT
```vscript
MaoLib.AddTimer("x", 0.3, fn)  // ❌ INFINITO si querías delay
MaoLib.DelayCall(fn, 0.3)      // ✅ Ejecuta UNA vez
```
DelayCall usa `UniqueString()` → nombre impredecible. Si necesitas cancelar, guarda retorno:
```vscript
local tn = MaoLib.DelayCall(fn, 5.0); MaoLib.RemoveTimer(tn)
```

### 2. round_end cleanup OBLIGATORIO
VM persiste entre rounds. Timers NO limpiados → se acumulan.
```vscript
function OnGameEvent_round_end(p) {
    MaoLib.RemoveTimer("my_timer")
    MyData.clear()
}
```

### 3. Sonidos looping → StopSoundOn EXPLÍCITO
```vscript
EmitSoundOn("loop.wav", ent)  // NUNCA para solo
// ✅ Programar cleanup:
MaoLib.DelayCall(function() {
    if (ent && ent.IsValid()) StopSoundOn("loop.wav", ent)
}, duration)
```

### 4. Damage recursion guard — OBLIGATORIO en handlers de `player_hurt` / `infected_hurt`
`TakeDamage()` / `AoE.Apply.Damage()` dentro de un handler de daño genera OTRO evento del mismo tipo. Sin guarda → recursión infinita que colapsa todo el modpack.
```vscript
// ❌ INFINITO: cada TakeDamage genera player_hurt, que vuelve a llamar TakeDamage
function OnGameEvent_player_hurt(params) {
    victim.TakeDamage(bonus, 0, attacker)
}

// ✅ CORRECTO: usar flag por script que cubra AMBOS handlers (player + infected)
::MiScript <- {
    _processingDamageEvent = false
    function OnGameEvent_player_hurt(params) {
        if (_processingDamageEvent) return
        _processingDamageEvent = true
        // ... TakeDamage / AoE.Apply.Damage ...
        _processingDamageEvent = false
    }
    function OnGameEvent_infected_hurt(params) {
        if (_processingDamageEvent) return
        _processingDamageEvent = true
        // ... TakeDamage ...
        _processingDamageEvent = false
    }
}
```
**Reglas:**
- Una sola flag por script, NO dos separadas (`_processingPlayerHurt` + `_processingInfectedHurt`), porque `player_hurt` puede generar AoE que dispara `infected_hurt` (cross-event ping-pong).
- Resetear la flag en TODOS los early returns.
- Ver ejemplos en `butcher.nut` (`but_processing_hurt`) y `tank_combat.nut` (`IsApplyingBonusDamage`).

---
## ⚠️ SQUIRREL — Keywords reservadas

NO usar como identifiers: `base`, `case`, `catch`, `class`, `clone`, `continue`, `default`, `delete`, `else`, `enum`, `extends`, `false`, `for`, `foreach`, `function`, `if`, `in`, `local`, `null`, `resume`, `return`, `static`, `switch`, `this`, `throw`, `true`, `try`, `typeof`, `while`, `yield`, `constructor`, `instanceof`, `rawcall`, `rawdelete`, `rawget`, `rawin`, `rawnew`, `rawset`, `rawthrow`, `delegate`, `parent`, `const`.
```vscript
local threat = { class = zClass }  // ❌ class = keyword → expected 'IDENTIFIER'
local threat = {}; threat.class <- zClass  // ✅
```

## ⚠️ L4CWI_Core.RegisterSystem — Inyección _Dbg

Scripts registrados con `L4CWI_Core.RegisterSystem("MiScript", scope)` reciben `_Dbg`, `_DbgWarn`, `_DbgError` automáticamente en su scope. Si usas `_Dbg()` en un script NO registrado → crash. Verificar SIEMPRE que el script esté registrado antes de usar `_Dbg`.

---
## 📋 CHECKLIST FINAL

1. Functions como METHODS, no properties
2. Tablas con `__CollectGameEventCallbacks(tabla)`, NUNCA getroottable()
3. NO logic_timer → MaoLib.AddTimer
4. UserID en eventos, NO entindex
5. NO LookupBone en infected → GetEffectPosition
6. `typeof(val)` NO `type(val)`
7. Invocar KEITH antes de entregar
8. AddTimer=recurrente, DelayCall=one-shot
9. Siempre limpiar timers en round_end
10. Sonidos looping con StopSoundOn explícito
11. NUNCA `if ("MaoLib" in getroottable())`
12. Method detachment → closure wrapper
13. TakeDamage/AoE.Apply en player_hurt/infected_hurt → flag `_processingDamageEvent`
