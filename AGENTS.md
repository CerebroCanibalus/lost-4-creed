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

**VPK:** 🔴 **USAR SIEMPRE `Compile-VPKs.ps1`**, no `vpk.exe` directo. Output ordenado a `compiled/` + incremental caching + evita VPKs huérfanos en raíz. `vpk.exe` solo para debug rápido.

---
## 🖥️ ENTORNO — SIEMPRE LOCAL

**ASUMIMOS SIEMPRE LISTEN SERVER / COOP LOCAL** (server y cliente = mismo proceso). NO dedicated.

**Implicación:** conVars de render/cliente (`mat_*`, `r_*`, `cl_*`) SÍ funcionan desde VScript. No hace falta `env_tonemap_controller` ni entidades de mapa para FX visuales globales — un `Convars.SetValue()` basta.

---
## 🔴 REGISTRO DE CAMBIOS OBLIGATORIO

**LEY CRÍTICA:** Tras cualquier cambio funcional, fix, refactor o migración de API, **actualizar `l4cCoreAddon/CHANGELOG.md` con fecha antes de commitear.**

```markdown
### [Fixed|Added|Changed|Removed] — YYYY-MM-DD
- **Sistema/Archivo:** Descripción concisa. Impacto: X. Fix/razón: Y.
```

**NO omitir:** Hotfixes, reverts, migraciones de API, dead code removal, cambios de balance.
**Sí omitir:** Typo en comentarios, formato puramente cosmético.

---
## 🔴 RECUPERACIÓN DE ARCHIVOS CORROMPIDOS

**LEY CRÍTICA:** Si una tool corrompe un archivo (encoding, duplicados, pérdida de contenido), **NO seguir editando sobre él**. El agente DEBE:

1. Informar al usuario qué archivo se corrompió y cómo.
2. **Pedirle el archivo al usuario** (`read`, backup, o `git checkout -- <archivo>`) antes de continuar.
3. No usar `write` para reescribir VScript grandes completos — usar `edit` con anclas verificadas.
4. Verificar encoding tras edición grande (`file -i` o primeras líneas).

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

**DO priority:** `DirectorScript.DO ← MapScript.DO ← LocalScript.DO ← ChallengeScript.DO` (LOW→HIGH). Key missing → walk UP chain.

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
- NO crear `mapspawn_addon.nut` salvo esencial → contamina getroottable().

---
## ⚠️ VERIFICACIÓN VSLIB → NATIVO
NO usamos VSLib en runtime. Solo NATIVO (VScript + MaoLib).
Si ves `EntityOutputs`, `VSLib::*`, `Utils.*` en código activo → **reemplazar con nativos**.
**Natives válidos:** `DoEntFire`, `EntFire`, `EmitSoundOn`, `StopSoundOn`, `EntFireByHandle`, `DispatchSpawn`, `NetProps.*`.
**NavMesh:** `NavMesh.*` confirmados (GetNearestNavArea, NavAreaBuildPath, GetNavAreasInRadius, GetAllAreas, GetNavAreaCount, FindNavAreaAlongRay).

**VSLib como verificación:** El repo VSLib (`references/vslib/`) se usa SOLO para confirmar qué métodos nativos existen en el binario. Si VSLib accede a un método directamente (ej. `_ent.GetEntityIndex()`), existe. Ver "Auditoría VSLib" en ELLIS.md.

---
## ⚠️ EVENTOS — 4 REGLAS

> **⛔ `maolib_events.nut` ELIMINADO (23/05/2026).** No hay sistema central de eventos. Cada script gestiona los suyos.

### R1: SIEMPRE tabla, NUNCA función global
```vscript
::Script <- { function OnGameEvent_hurt(p) { } }  // ✅
__CollectGameEventCallbacks(::Script);
function OnGameEvent_hurt(p) { }                   // ❌ HIJACKEA
```

### R2: `__CollectGameEventCallbacks(getroottable())` PROHIBIDO
→ Registra TODO en global → sobrescribe tablas → CRASH.

### R3: Global `OnGameEvent_*` HIJACKEA evento
Si existe global + tabla registrada para mismo evento → global gana → tabla NUNCA recibe → CRASH.

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
## ⚠️ METHOD DETACHMENT (Pitfall #1)

Pasar método de tabla como callback → pierde `this`.
```vscript
MaoLib.AddTimer("n", 0.5, Table.Method)                            // ❌
MaoLib.AddTimer("n", 0.5, function() { Table.Method(); })          // ✅
g_MapScript.ScriptedMode_AddUpdate(function() { this.Method(); })  // ✅
MaoLib.AddTimerSafe("n", 0.05, @() ::Table.Method())              // ✅
```

---
## ⚠️ LOOP-VARIABLE CLOSURE CAPTURE (Pitfall #2)
Closure en loop captura variable POR REFERENCIA. Todos comparten la misma binding.
```vscript
// ❌ — 'ent' = null al disparar el timer
while (ent = Entities.FindByClassname(ent, "infected")) {
    MaoLib.AddTimer("t_"+ent.GetEntityIndex(), 0.5, function() { Do(ent) })
}
// ✅ — 'captured' es NUEVA binding cada iteración
while (ent = Entities.FindByClassname(ent, "infected")) {
    local captured = ent
    MaoLib.AddTimer("t_"+captured.GetEntityIndex(), 0.5, function() { Do(captured) })
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
Carga: `IncludeScript("maolib", getroottable())` + navutils, vfx, state, hud, modifiers, aoe, status, mapper.
// input, cooldowns REMOVIDOS (9 Jun 2026) — ningún script activo los usa.
// status_hooks ELIMINADO (9 Jun 2026) — incompatible con StatusEffects v3.0 plano.

Namespaces: `::MaoLib`, `::MaoLib.NavUtils`, `::MaoLib_VFX`, `::MaoLib.PlayerState`, `::MaoLib.HUD`, `::MaoLib.Modifiers`, `::MaoLib.AoE`, `::MaoLib.StatusEffects`, `::MaoLib.Mapper`

### 🔴 NUNCA `if ("MaoLib" in getroottable())` — SILENT KILLER
Asume que MaoLib existe. Si falla, el script DEBE crashear con error visible. Un check condicional crea scripts zombie (cargan, no crashean, no hacen nada).

**Excepciones (solo self-check):** `maolib.nut`, `maolib_navutils.nut`, `maolib_timers_cleanup.nut`

> 📖 **API completa de MaoLib (NavUtils, PlayerState, HUD, Modifiers, AoE, StatusEffects, Mapper, VFX, natives, netprops) → ver ELLIS.md.**

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

> **No crear scripts Python ad-hoc para validar VScript.** `test_vscripts.ps1` es la herramienta oficial. Si reporta un issue, investigar con lectura de código (`read`, `grep`) antes de descartarlo como falso positivo.

---
## 🗺️ l4cMapRefresh

**Archivos:** `director_base_addon.nut`(entry) `maprefresh_main.nut`(loader) `maprefresh_utils.nut`(spawners) `maprefresh_proptypes.nut`(33 categorías) `maprefresh_refdata.nut`(coords) `cXmY_mapname.nut`(per-map)

**Mapas activos con eventos:** c1m1_hotel(sky elevator+tank) c1m2_streets(gunshop ambush+gas tanker) c2m1_highway(HELI HOTEL: flyover→crash→tank+slowmo) c2m2_fairgrounds(wood barricade) c2m4_barns(barn tank hold-zone) c3m2_swamp(aircraft crash) c3m3_shantytown(corridor tank)

**Mapas solo props:** c2m3_coaster c8m1_apartment c8m2_subway c8m3_sewers c8m4_interior c8m5_rooftop

**Pendientes (registrados sin script):** c5m1_waterfront c5m2_park c5m3_cemetery c5m4_quarter

**Skipped:** c1m3_mall c1m4_atrium c2m3_coaster(scavenge) c2m5_concert c3m1_plankcountry c3m4_plantation

**Design:** 60% prop density, MaoLib hard dep, no VSLib, eventos>props, EntityOutputs nativos via Mapper.

---
## 🤖 SurvAI v3 — Utility AI con Blackboard (EN PLANIFICACIÓN)

**Proyecto grande.** Rediseño del sistema de IA de supervivientes (`sa_*`, l4cCoreSurvivorGameplay) para arreglar el avance all-bot y añadir humanización. **Plan detallado por fases → `docs/survai_v3_plan.md`** (LEER antes de tocar sa_*).

**Problema:** sistema actual = "Minimal Intervention" con prioridades fijas. En all-bot, `DetectTask()` devuelve `ATTACK_COMMON` (75) casi siempre → `DetectAdvanceTask()` (30, la más baja) NUNCA se evalúa → bots estáticos.

**Fix:** Utility AI — avance es UNA consideración con score dinámico (sube en SAFE, baja en COMBAT). Un solo pipeline, comportamientos repetibles.

**Fases (cada una incremental, sin romper funcionalidad):**
| Fase | Contenido | Riesgo |
|------|-----------|--------|
| 0 | Diagnóstico + baseline (logs actuales) | Bajo |
| 1 | Fundación: `sa_team.nut` (TeamState/FlowState/Leader) + `sa_utility.nut` (scores+arbiter). BotThink usa arbiter. Detectores→consideraciones. Executors intactos | Bajo |
| 2 | Avance por flow: `GetNavAhead` con `NavAreaTravelDistance` (gradiente), safety gate, líder dinámico | Medio |
| 3 | Formación point/relay/rear/flex + combate-avance (`CommandABot(cmd=1)` + `IN_ATTACK`) | Medio |
| 4 | Humanización: `sa_humanize.nut` (reaction delay, fail chance, aim error, personality, idle behaviors, exploración por capas) | Medio |
| 5 | Pulido: debug blackboard, tuning scores, docs v3.0 | Bajo |

**Truquillos clave (nadie los usa):** `NavMesh.NavAreaTravelDistance` (flow nativo), `CTerrorPlayer.GetLastKnownArea()`, `TerrorNavArea.IsCompletelyVisibleToTeam()`, cache de áreas por ID, percepción retardada por bot, combate-avance con botones forzados.

**⚠️ CommandABot desactiva IA vanilla mientras está comandado** → re-comandar cada tick.

**Regla de oro:** human-like, NO dioses. Bots que fallan, exploran, hacen chorradas y esperan al equipo. NO aim perfecto, NO reacción instantánea, NO teleport como solución.

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
🔴 **CRÍTICO: NO usar `vpk.exe` directo.** Siempre usar `Compile-VPKs.ps1`. VPKs creados manualmente en raíz serán ignorados por el loader y contaminan el directorio.

---
## ⚠️ ENTIDADES PROBLEMÁTICAS
| Patrón | Riesgo |
|--------|--------|
| `info_null` (2+) | 🔴 Crash al cerrar saferoom |
| `env_projectedtexture` | 🔴 Crash en L4D2 |
| `ambient_generic.SetParent()` | 🔴 NO soporta parenting de posición |
| `LookupBone` en "infected" | ⚠️ Crash POTENCIAL (entidades sin huesos/animaciones incompletas). Para precisión (decals) puede ser necesario con try/catch. Fallback: `GetEffectPosition()` |
| `QAngle.ToKVString()` | 🔴 NO existe — string manual |
| Operador `<=>` | 🔴 NO existe en Squirrel |
| `light_dynamic.SetOrigin()` con luz encendida | 🔴 NO actualiza posición visual — usar TurnOff→SetOrigin→TurnOn o parent |

### Nativos que NO funcionan como esperas
- `ambient_generic`: Usar `SourceEntityName` keyvalue apuntando a info_target para sonido posicional
- `ApplyAbsVelocityImpulse`: Sí funciona, pero envolver en try/catch
- `EmitSoundOn(sound, entity)`: Nativo de 2 params (sound, entity)

---
## 🐛 BUGS COMUNES

### `light_dynamic` — NO `SetOrigin()` mientras está encendida
```vscript
// ❌ Posición no cambia visualmente
light.SetOrigin(newPos)  // luz ya encendida: ignorado por renderer

// ✅ Forzar re-evaluación de origen
EntFire(light.GetName(), "TurnOff")
light.SetOrigin(newPos)
EntFire(light.GetName(), "TurnOn")

// ✅ O parentear la luz a la entidad que se mueve
light.SetParent(player)
```

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

### 2. Timer lifecycle — 🔴 PauseTimer RESETEA el intervalo
**⚠️⚠️⚠️ CRÍTICO:** `PauseTimer` + `ResumeTimer` **NO preservan el timing.** `ResumeTimer()` hace `timer.nextRun = Time() + timer.interval`, perdiendo todo el progreso acumulado mientras estuvo pausado.

**Ejemplo concreto:**
```vscript
// Timer de 0.5s se pausa en t=10.2, se reanuda en t=15.0
// nextRun = t=15.5 (NO t=10.7 como esperarías)
// → 5 segundos de timing perdidos
```

**¿Cuándo usar PauseTimer?** SÓLO para un caso nicho: auto-pause por entity death. `TimerThink()` auto-pausa si `timer.entity` muere. Luego en el handler del spawn: `ResumeTimer()` revive.

**Para TODO lo demás — RemoveTimer + AddTimerForce:**
```vscript
// ✅ CORRECTO: Remove en round_end, Add fresco en round_start
function OnGameEvent_round_end(p) {
    MaoLib.RemoveTimer("my_timer")
    MyData.clear()
}
function OnGameEvent_round_start_post_nav(p) {
    MaoLib.AddTimerForce("my_timer", 0.1, fn)
}

// ❌ NO hacer: Pause+Resume entre rounds (nextRun se resetea)
function OnGameEvent_round_end(p) {
    MaoLib.PauseTimer("my_timer")       // ← pierde timing
}
function OnGameEvent_round_start_post_nav(p) {
    MaoLib.ResumeTimer("my_timer")      // ← nextRun = Time() + interval
}
```

**⚠️ IsTimerActive es TRAMPA MORTAL:** devuelve `false` si el timer está PAUSED. Si lo usas para decidir entre AddTimer o no:
```vscript
// ❌ FALLO: IsTimerActive → false → AddTimer → WARNING (name existe)
// → Timer queda PAUSED forever (BIG zombie)
if (!MaoLib.IsTimerActive("my_timer"))
    MaoLib.AddTimer("my_timer", 0.1, fn)

// ✅ CORRECTO: AddTimerForce sobreescribe siempre
MaoLib.AddTimerForce("my_timer", 0.1, fn)

// ✅ CORRECTO: IsTimerRegistered si NECESITAS saber si existe
if (MaoLib.IsTimerRegistered("my_timer"))
    MaoLib.ResumeTimer("my_timer")   // pero cuidado con el nextRun reset
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
