# Lost 4 Creed

**Modpack de terror cooperativo para Left 4 Dead 2, escrito íntegramente en VScript (Squirrel).**

Campaña custom, sistemas de Director, supervivientes con perks propio, infectados
especiales, IA de navegación, FX, HUD y ambientación — todo sin una sola línea
de C++ ni de SourceMod. El motor Source carga los scripts directamente desde los VPK.

![L4D2](https://img.shields.io/badge/juego-Left%204%20Dead%202-cc3333)
![VScript](https://img.shields.io/badge/lenguaje-VScript%20%2F%20Squirrel-8eaadb)
![Licencia](https://img.shields.io/badge/licencia-GPL--3.0-blue)
![Addons con código](https://img.shields.io/badge/addons%20con%20c%C3%B3digo-11-green)

---

## 📦 Qué hay en este repositorio

**Solo código.** El proyecto completo pesa ~9,9 GB, de los cuales apenas **1,9 MB son
VScript**. Este repositorio contiene el código; los assets se distribuyen aparte.

| | |
|---|---|
| Ficheros VScript | **233** `.nut` |
| Líneas de código | **~51.400** |
| Addons con código | **11** |
| Tamaño del repo | **~2 MB** |

### Addons con código

| Addon | `.nut` | Descripción |
|---|---|---|
| `MaoLib` | 11 | Librería núcleo: timers, navmesh, AoE, VFX, HUD, estado, mods |
| `l4cCoreAddon` | 81 | Director, MaoLib, lógica de juego, CHANGELOG |
| `l4cWeaponItemScripts` | 56 | Armas, items, buffs, recoil |
| `l4cMapRefresh` | 21 | Props y eventos por mapa (c1m1–c8m5) |
| `l4cInfectedGameplay` | 18 | IA de infectados, combate de Tank |
| `l4cCoreSurvivorGameplay` | 17 | Perks, movimiento, `sa_*` (SurvAI) |
| `l4cCustomInfected` | 11 | Especiales custom |
| `l4cCoreVisuals` | 10 | Shaders y VFX |
| `l4cMusicCuesAndSounds` | 4 | Cues musicales |
| `l4cHordeMusic` | 2 | Música de horda |
| `l4cItemsGuns` | 2 | Scripts de armas |

### Addons sin código (no incluidos)

13 addons son **puramente assets** (modelos, texturas, sonidos). No aportan nada al
código, por lo que no están en el repo. Se compilan aparte con `Compile-VPKs.ps1`:

```
l4cAmbienceCore (+Pt2, Pt3)      l4cEnvironmentCore (+Pt2, Pt3)
l4cAnimationsCore                l4cHudGUI
l4cInfectedReplacements         l4cMusicCuesAndSoundsPt2, Pt3
l4cSurvivorsCast                 l4cWeaponSounds
```

---

## 🧩 MaoLib — la librería que lo sostiene

MaoLib es la dependencia dura del modpack. Sin ella, ningún script arranca.

```
MaoLib.NavUtils      Pathfinding, LOS, choke points, flow distance, flanking
MaoLib.PlayerState   Estado por jugador con bus de eventos y limpieza
MaoLib.Modifiers     Multiplicadores de velocidad y fricción
MaoLib.AoE           Selectores (Circle/Cone/Line) → Aplicadores (Damage/Push...)
MaoLib.StatusEffects Buffs/debuffs, DoT, hooks automáticos de daño
MaoLib.HUD           Notificaciones y overlays
MaoLib.Mapper        Entity Outputs, spawns con outputs, utilidades de mapa
MaoLib_VFX           Partículas, decals, screen shake, screen effects
```

```vscript
::MiScript <- {
    Debug = 1
    function Dbg(m) { if (Debug) printl("[MiScript][DBG] "+m) }

    function OnGameEvent_player_hurt(p) {
        Dbg("ENTER player_hurt; uid="+p.userid)
        local victim = GetPlayerFromUserID(p.userid)
        if (!victim) return          // sin victim: no hay nada que hacer
        MaoLib.HUD.NotifyAll("Cuidado, " + victim.GetName())
        Dbg("EXIT player_hurt")
    }
}
__CollectGameEventCallbacks(::MiScript);
```

---

## 📥 Instalación

Este repo es el código, no el mod jugable. Para jugar necesitas los VPK.

### 1. Compilar los addons

```powershell
git clone https://github.com/CerebroCanibalus/lost-4-creed.git
cd lost-4-creed
.\Compile-VPKs.ps1                 # menú interactivo
.\Compile-VPKs.ps1 -Force          # rebuild completo
.\Compile-VPKs.ps1 -ExcludeFromDefender   # modo rápido
```

Los VPK salen en `compiled/`. **No uses `vpk.exe` a mano**: el script gestiona el
orden de dependencias, la caché incremental y evita VPKs huérfanos.

### 2. Instalar en L4D2

Copia los `.vpk` de `compiled/` a:

```
Steam/steamapps/common/Left 4 Dead 2/left4dead2/addons/
```

### 3. Añadir los assets

Los addons solo-asset no se compilan aquí. Si tienes sus carpetas de origen con
modelos, texturas y sonidos, compílalos también con `Compile-VPKs.ps1`.

---

## 🚀 Uso

Lost 4 Creed está pensado para **listen server / coop local** (servidor y cliente en
el mismo proceso), no para dedicated server. Eso implica que los conVars de render
(`mat_*`, `r_*`, `cl_*`) son manipulables desde VScript sin tricks adicionales.

Añade el modo a tu mapa vía `MissionFile` en la configuración de la partida, y
`director_base_addon.nut` se encarga de cargar el resto.

### Load order

El orden de carga no es trivial — varios addons comparten nombre de fichero y
todos se ejecutan:

```
mapspawn.nut               → getroottable()
[modename].nut            → g_ModeScript   (ChallengeScript)
[mapname]_[modename].nut  → g_MapScript
director_base_addon.nut   → DirectorScript  (l4cCoreAddon DEBE ir primero)
[mapname]_finale.nut      → trigger_finale
```

Prioridad de DirectorOptions: `DirectorScript.DO ← MapScript.DO ← LocalScript.DO ← ChallengeScript.DO`

---

## 🧠 SurvAI — utility AI con blackboard

Rediseño en curso de la IA de supervivientes. El sistema actual usa
"Minimal Intervention" con prioridades fijas, lo que en all-bot produce bots
estáticos: la detección devuelve siempre `ATTACK_COMMON` y la tarea de avance,
siendo la de menor prioridad, nunca llega a evaluarse.

El plan es pasarlo a **utility AI**: el avance pasa a ser una consideración más,
con score dinámico según el estado del grupo.

**Regla de oro: comportamiento humano, no divinidad.** Los bots deben fallar,
explorar, hacer el tonto y esperar al equipo. Sin aim perfecto, sin reacción
instantánea, sin teleport como solución.

Detalle por fases en [`docs/survai_v3_plan.md`](docs/survai_v3_plan.md).

---

## 📖 Documentación

| Fichero | Contenido |
|---|---|
| [`AGENTS.md`](AGENTS.md) | Memoria del proyecto: load order, trampas de Squirrel, bugs conocidos, checklist |
| [`docs/MaoLib.md`](docs/MaoLib.md) | API completa de MaoLib |
| [`docs/survai_v3_plan.md`](docs/survai_v3_plan.md) | Plan de SurvAI por fases |
| [`l4cCoreAddon/CHANGELOG.md`](l4cCoreAddon/CHANGELOG.md) | Registro de cambios |
| [`testing/`](testing) | Validador estático de VScript |

### Trampas documentadas

[`AGENTS.md`](AGENTS.md) recoge los bugs de Squirrel y de L4D2 que más caro salen,
con el motivo de cada uno:

- **Method detachment** — pasar `Table.Method` como callback pierde `this`
- **Closure capture en loop** — Squirrel captura por referencia, no por valor
- **`__CollectGameEventCallbacks(getroottable())`** — prohibido, cuelga el juego
- **`PauseTimer`/`ResumeTimer`** — resetea el intervalo, pierde el timing acumulado
- **`LookupBone` en `infected`** — crash; usar `GetEffectPosition()`
- **Recursión de daño** — `TakeDamage()` en `player_hurt` sin guarda = infinito

---

## 🧪 Tests

```powershell
.\testing\test_vscripts.ps1 -Full -Verbose
```

Validador estático que detecta los patrones peligrosos de VScript antes de que
lleguen al juego. No es un sustituto de probar en partida.

---

## 🤝 Contribuir

Lee [`CONTRIBUTING.md`](CONTRIBUTING.md) y [`AGENTS.md`](AGENTS.md) antes de tocar
nada — el orden de carga y las reglas de eventos no son negociables.

Reporta vulnerabilidades de forma privada según [`SECURITY.md`](SECURITY.md).

---

## 📄 Licencia

GPL-3.0. Ver [`LICENSE`](LICENSE).

Left 4 Dead 2 es marca de Valve Corporation. Este proyecto no está afiliado ni
patrocinado por Valve. Los assets (modelos, texturas, sonidos) **no** se distribuyen
bajo esta licencia y no están en el repositorio.

---

## 📊 Estado

| Componente | Estado |
|---|---|
| MaoLib (núcleo) | Estable |
| Director + lógica de juego | Estable |
| Armas, items, recoil | Estable |
| MapRefresh (props + eventos) | 7 mapas con eventos, resto solo props |
| Infectados custom | Estable |
| SurvAI v3 | En planificación — fases 0-1 |
| Shaders / VFX | Estable |
