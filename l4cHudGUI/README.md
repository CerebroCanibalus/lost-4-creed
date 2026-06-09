# l4cHudGUI — "Interfaz de Usuario" v2.3

**Addon:** Lost 4 Creed — HUD & GUI  
**Author:** Lost 4 Creed Team  
**Entry Point:** Ninguno (solo assets de UI)  
**Dependencias:** Ninguna  
**Tamaño:** ~10 MB (~200+ archivos)

---

## 📋 Descripción

Addon que reemplaza completamente la interfaz de usuario de Left 4 Dead 2 con un HUD personalizado. Incluye paneles de salud de Special Infected, temporizadores de habilidades, pantallas de selección, scoreboard, menú principal estilo Xbox 360, y más.

Sin scripts VScript — solo archivos RES y texturas.

---

## 📂 Estructura

```
resource/
├── ui/
│   ├── hud/
│   │   ├── abilitytimer.res        ← Timer de habilidades
│   │   ├── localplayer.res         ← HUD del jugador local
│   │   ├── teammate.res            ← HUD de compañeros
│   │   ├── teamdisplay.res         ← Display de equipo
│   │   ├── spectator.res           ← HUD de espectador
│   │   ├── scoreboard.res          ← Tabla de puntuaciones
│   │   ├── health_boomer.res       ← Salud de Boomer
│   │   ├── health_charger.res      ← Salud de Charger
│   │   ├── health_hunter.res       ← Salud de Hunter
│   │   ├── health_jockey.res       ← Salud de Jockey
│   │   ├── health_smoker.res       ← Salud de Smoker
│   │   ├── health_spitter.res      ← Salud de Spitter
│   │   ├── health_tank.res         ← Salud de Tank
│   │   ├── zombie_team_display.res ← Display de equipo zombie
│   │   └── transitionstats.res     ← Estadísticas de transición
│   ├── l4d360ui/
│   │   ├── mainmenu.res            ← Menú principal (estilo 360)
│   │   ├── options.res             ← Pantalla de opciones
│   │   ├── loading.res             ← Pantalla de carga
│   │   ├── chat.res                ← Chat
│   │   ├── vote.res                ← Votación
│   │   ├── chapterselect.res       ← Selección de capítulo
│   │   ├── quickjoin.res           ← Unión rápida
│   │   ├── tools.res               ← Herramientas
│   │   └── maps.res                ← Mapas
│   ├── ghostpanel.res              ← Panel fantasma
│   ├── scoreboard_survivor.res     ← Scoreboard survivors
│   └── hudlayout.res               ← Layout general del HUD
├── scripts/
│   ├── hudlayout.res
│   └── stats_crawl.txt             ← Texto de estadísticas
└── materials/
    ├── vgui/
    │   ├── hud/
    │   │   ├── altcrosshair.vmt/vtf    ← Mira alternativa
    │   │   ├── hmm.vmt/vtf            ← Indicador "hmm"
    │   │   ├── progressbar.vmt/vtf     ← Barra de progreso
    │   │   └── digits.vmt/vtf          ← Dígitos numéricos
    │   └── ingamemenu/
    │       ├── brightness.vmt/vtf      ← Icono brillo
    │       ├── captions.vmt/vtf        ← Icono subtítulos
    │       ├── fov.vmt/vtf             ← Icono FOV
    │       ├── info.vmt/vtf            ← Icono información
    │       ├── music.vmt/vtf           ← Icono música
    │       ├── sound.vmt/vtf           ← Icono sonido
    │       └── slider.vmt/vtf          ← Slider
    ├── clock/                          ← Reloj digital
    └── sprites/
        └── 640_pain_*.vmt/vtf          ← Indicadores de dolor
```

---

## 🎯 Paneles del HUD

### HUD de Supervivientes
- **localplayer.res** — Salud, munición, armas del jugador
- **teammate.res** — Salud y estado de compañeros
- **teamdisplay.res** — Vista general del equipo
- **abilitytimer.res** — Temporizador de habilidades activas

### HUD de Infectados (Versus)
- **health_boomer/charger/hunter/jockey/smoker/spitter/tank.res** — Salud individual de cada SI
- **zombie_team_display.res** — Display del equipo infectado

### Menú Principal (Estilo Xbox 360)
- mainmenu, options, loading, chat, vote, chapter select, quick join

---

## 🔧 Dependencias

Ninguna. Addon independiente.

---

## ⚠️ Notas

- **No contiene VScripts** — solo archivos RES de interfaz y texturas
- El HUD reemplaza completamente la interfaz vanilla
- Incluye health bars individuales para cada tipo de Special Infected
- Los health_*.res se usan en modo Versus para ver la salud de los SI

---

*Last updated: 2026-05-30*
