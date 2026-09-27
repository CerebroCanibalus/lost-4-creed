# Contributing to Lost 4 Creed

Gracias por mirar el proyecto. Antes de escribir código, lee esto entero y después
[`AGENTS.md`](AGENTS.md) — que es la memoria viva del modpack y documenta las
trampas de Squirrel y de L4D2 que ya nos han costado tiempo.

---

## 📋 Antes de tocar nada

1. **Lee [`AGENTS.md`](AGENTS.md).** Load order, las 4 reglas de eventos, los
   patrones sistemáticos y el checklist final están ahí por razones.
2. **Lee [`docs/MaoLib.md`](docs/MaoLib.md).** MaoLib es la dependencia dura. Antes
   de escribir algo, comprueba si ya existe.
3. **No rompas el load order.** Varios addons comparten nombre de fichero y
   **todos** se ejecutan. No los "simplifiques".
4. **Entorno: listen server / coop local.** Servidor y cliente son el mismo proceso.
   Los conVars de render son manipulables desde VScript sin entidades de mapa.

---

## 🧪 Valida siempre antes de abrir PR

```powershell
.\testing\test_vscripts.ps1 -Full -Verbose
```

El validador estático detecta los patrones que cuelgan el juego en runtime:

| Patrón | Severidad |
|---|---|
| `MaoLib.AddTimer*(...,word,word)` — method detachment | CRITICAL |
| `ScriptedMode_AddUpdate(word)` | CRITICAL |
| `DirectorScript.Word` — cross-ref a global | CRITICAL |
| `function OnGameEvent_*()` global | HIGH |
| `Word = function(` en tabla de eventos | HIGH |

Si el validador reporta algo, **investiga con lectura de código** antes de
descartarlo como falso positivo. Y no escribas validadores ad-hoc: el oficial es
`testing/test_vscripts.ps1`.

---

## 📏 Reglas de estilo VScript

### Eventos: siempre tabla, nunca función global

```vscript
// ✅ Correcto
::MiScript <- {
    helper = 42,
    function OnGameEvent_spawn(p) { helper }
}
__CollectGameEventCallbacks(::MiScript);

// ❌ Prohibido: hijackea el evento y rompe las demás tablas
function OnGameEvent_spawn(p) {}
__CollectGameEventCallbacks(getroottable())   // 🚫 NUNCA
```

**Usa sintaxis `function Name()`, nunca `Name = function()`.** Los methods heredan
el environment de la tabla; las properties buscan en global. En Squirrel 3.2 §2.8.2
está la razón.

### Callbacks: envuelve en closure

```vscript
MaoLib.AddTimer("n", 0.5, Table.Method)                     // ❌ pierde this
MaoLib.AddTimer("n", 0.5, function() { Table.Method(); })   // ✅
```

### Loops con closure: captura nueva binding

```vscript
while (ent = Entities.FindByClassname(ent, "infected")) {
    local captured = ent    // ✅ binding nueva por iteración
    MaoLib.AddTimer("t", 0.5, function() { Do(captured) })
}
```

### Timers

- `AddTimer` = **recurrente**. `DelayCall` = **one-shot**.
- `PauseTimer` + `ResumeTimer` **resetea el intervalo**. Para todo lo demás:
  `RemoveTimer` en `round_end` + `AddTimerForce` en `round_start`.
- `IsTimerActive` devuelve `false` si el timer está pausado. No lo uses para decidir
  si crear un timer. Usa `AddTimerForce`.

### Daño: guarda de recursión obligatoria

`TakeDamage()` dentro de `player_hurt` o `infected_hurt` genera otro evento del
mismo tipo. Sin guarda, recursión infinita. **Una sola flag por script** que cubra
ambos handlers, porque `player_hurt` puede generar AoE que dispare `infected_hurt`.

```vscript
::MiScript <- {
    _processingDamageEvent = false
    function OnGameEvent_player_hurt(p) {
        if (_processingDamageEvent) return
        _processingDamageEvent = true
        // ...
        _processingDamageEvent = false
    }
    // infected_hurt con la MISMA flag
}
```

### Dependencia dura: MaoLib

**Nunca** escribas `if ("MaoLib" in getroottable())`. Asume que existe. Si falla, el
script debe crashear con error visible — un check condicional crea scripts zombie
que cargan, no crashean y no hacen nada.

### Depuración

Toda función pública lleva `Dbg("ENTER ...")` / `Dbg("EXIT ...")`, y todo `return`
temprano explica por qué.

### Palabras reservadas de Squirrel

No las uses como identificadores: `base`, `case`, `catch`, `class`, `clone`,
`continue`, `default`, `delete`, `else`, `enum`, `extends`, `false`, `for`,
`foreach`, `function`, `if`, `in`, `local`, `null`, `resume`, `return`, `static`,
`switch`, `this`, `throw`, `true`, `try`, `typeof`, `while`, `yield`,
`constructor`, `instanceof`, `rawcall`, `rawdelete`, `rawget`, `rawin`, `rawnew`,
`rawset`, `rawthrow`, `delegate`, `parent`, `const`.

```vscript
local threat = { class = zClass }   // ❌ keyword
local threat = {}; threat.class <- zClass   // ✅
```

---

## 📝 Pull requests

1. **Un PR, un cambio.** No mezcles refactors con features.
2. **Actualiza `l4cCoreAddon/CHANGELOG.md` con fecha** antes de commitear. Es
   obligatorio, también para hotfixes y reverts.
3. **Pasa el validador** y pega el resultado en la descripción.
4. **Explica el porqué.** El qué se ve en el diff; el porqué no.
5. Si toca carga, eventos o timers, cita la sección de `AGENTS.md` que lo governs.

### Qué entra y qué no

Este repo es **solo código**. No subas:

- Modelos, texturas, sonidos, mapas, vídeos (`.mdl` `.vtf` `.wav` `.bsp` `.bik`…)
- VPK compilados — se generan con `Compile-VPKs.ps1`
- Nada de `referencias/` ni `references/` (código de terceros, licencias propias)
- Nada de `tools/` (vendored, licencias ajenas)
- Ficheros de `trash_bin/` / `trashbin/`

El `.gitignore` está preparado para rejectarlos, pero revisa `git status` antes de
commitear.

---

## 🐛 Reportar bugs

Usa la plantilla de bug report. Incluye siempre:

- Mapa y modo
- Qué esperabas y qué pasó
- Salida de consola (`developer` console) con el error
- Si es un crash, el volcado de stack

Los bugs de runtime sin log son casi imposibles de reproducir. Con log, se resuelven
en minutos.

---

## 📄 Licencia

Al contribuir aceptas que tu trabajo se publique bajo GPL-3.0. Los assets no entran
en el repositorio.
