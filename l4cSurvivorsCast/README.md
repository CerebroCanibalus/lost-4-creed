# l4cSurvivorsCast — "Angels of Death" v2.3

**Addon:** Lost 4 Creed — Survivor Model Replacements  
**Author:** Lost 4 Creed Team  
**Entry Point:** Ninguno (solo assets visuales)  
**Dependencias:** Ninguna  
**Tamaño:** ~15 MB (~50+ archivos)

---

## 📋 Descripción

Addon de reemplazo de modelos de supervivientes con temática "Angels of Death". Cambia la apariencia de los 4 supervivientes de L4D2 y los 4 de L4D1 en pantallas de selección, además de añadir variantes de personajes.

Sin scripts VScript — solo archivos de modelos, texturas y UI.

---

## 📂 Estructura

```
materials/
├── models/
│   ├── businessman/
│   │   ├── common_male_suit       ← Mecánico (modelo de common)
│   │   ├── asian_head             ← Cabeza asiática
│   │   └── black_head             ← Cabeza afro
│   ├── firefighter/
│   │   ├── firefighter_a          ← Bombero variante A
│   │   ├── firefighter_d          ← Bombero variante D
│   │   └── hands_1stp             ← Manos en primera persona
│   ├── resistance/
│   │   └── prague_civ             ← Rioter / civil de Praga
│   └── blackops/
│       └── suit/                  ← Traje de operaciones especiales
└── vgui/
    ├── panel_icons/
    │   └── survivors/
    │       ├── biker              ← Icono biker
    │       ├── coach              ← Icono Coach
    │       ├── gambler            ← Icono Nick
    │       ├── manager            ← Icono Manager
    │       ├── mechanic           ← Icono mecánico
    │       ├── namvet             ← Icono veterano
    │       ├── producer           ← Icono productor
    │       └── teenangst          ← Icono Zoey
    ├── select/
    │   ├── bill                   ← Bill en pantalla selección
    │   ├── francis                ← Francis
    │   ├── louis                  ← Louis
    │   ├── zoey                   ← Zoey
    │   └── random                 ← Selección aleatoria
    └── lobby/
        └── variants/
            ├── coach              ← Coach lobby
            ├── firefighter        ← Bombero lobby
            ├── gambler            ← Gambler lobby
            ├── mechanic           ← Mecánico lobby
            └── producer           ← Productor lobby

resource/
└── closecaption_english.txt       ← Subtítulos personalizados
```

---

## 🎯 Personajes

### L4D2 Survivors
| Personaje | Apodo | Skin |
|-----------|-------|------|
| Coach | — | Coach |
| Nick | Gambler | Gambler |
| Rochelle | Producer | Producer |
| Ellis | Mechanic | Mechanic |

### L4D1 Survivors
| Personaje | Skin |
|-----------|------|
| Bill | Namvet (veterano) |
| Francis | Biker |
| Louis | Manager |
| Zoey | Teenangst |

---

## 🖼️ Pantallas Afectadas

| Pantalla | Cambio |
|----------|--------|
| Panel icons | Iconos de personajes en HUD |
| Select screen | Retratos en selección de personaje |
| Lobby variants | Apariencia en el lobby multijugador |
| Subtítulos | Texto personalizado via `closecaption_english.txt` |

---

## 🔧 Dependencias

Ninguna. Addon independiente.

---

## ⚠️ Notas

- **No contiene VScripts** — solo reemplazo de texturas y modelos
- Los modelos de `businessman/`, `firefighter/`, `resistance/` y `blackops/` son assets de apoyo para escenarios
- Los subtítulos personalizados están en `closecaption_english.txt`

---

*Last updated: 2026-05-30*
