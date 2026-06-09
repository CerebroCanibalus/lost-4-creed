# l4cWeaponSounds — "Sonidos de Armas" v2.3

**Addon:** Lost 4 Creed — Weapon Sound Replacements  
**Author:** Lost 4 Creed Team  
**Entry Point:** Ninguno (solo assets de audio)  
**Dependencias:** Ninguna  
**Tamaño:** ~25 archivos WAV

---

## 📋 Descripción

Addon puramente de audio que reemplaza los sonidos de armas del juego base. Incluye nuevos sonidos para: hacha, motosierra, crowbar, guitarra eléctrica, granadas, y la linterna.

Sin scripts VScript — solo archivos de sonido.

---

## 📂 Estructura

```
sound/weapons/
├── 50cal/
│   └── 50cal_shoot.wav          ← Disparo calibre .50
├── axe/
│   ├── flesh1-4.wav             ← Impactos en carne
│   ├── miss1-2.wav              ← Fallos (swing sin impacto)
│   └── melee_axe_01-03.wav      ← Swings de hacha
├── chainsaw/
│   ├── start.wav                ← Arranque
│   ├── idle.wav                 ← Ralentí
│   ├── high_speed_lp.wav        ← Alta velocidad (loop)
│   └── die.wav                  ← Apagado
├── crowbar/
│   ├── deploy.wav               ← Desenfunde
│   ├── impact_flesh1.wav        ← Impacto en carne
│   ├── impact_world1.wav        ← Impacto en mundo
│   └── swing_miss1.wav          ← Swing sin impacto
├── guitar/
│   ├── hit_world_01-07.wav      ← Impactos en mundo (7 variantes)
│   ├── melee_guitar_01-07.wav   ← Swings de guitarra (7 variantes)
├── hegrenade/
│   ├── explode3.wav             ← Explosión variante 3
│   └── explode5.wav             ← Explosión variante 5
└── (root) flashlight1.wav       ← Encendido/apagado linterna

sound/items/
└── flashlight1.wav              ← Sonido de linterna (items)
```

---

## 🎯 Armas Afectadas

| Arma | Sonidos Reemplazados |
|------|---------------------|
| **Fireaxe** | Impactos (4), swings miss (2), melee swing (3) |
| **Chainsaw** | Arranque, idle, alta velocidad, apagado |
| **Crowbar** | Desenfunde, impacto carne, impacto mundo, swing |
| **Electric Guitar** | Impactos mundo (7), swings (7) |
| **HE Grenade** | Explosiones (2 variantes) |
| **.50 Cal** | Disparo |
| **Flashlight** | Encendido/apagado |

---

## 🔧 Dependencias

Ninguna. Addon independiente.

---

## ⚠️ Notas

- **No contiene VScripts** — solo reemplazo de assets de audio
- Los sonidos se cargan automáticamente al usar el arma correspondiente
- La guitarra eléctrica tiene 14 variantes de sonido (7 impacto + 7 swing)
- Compatible con cualquier mod que no sobreescriba los mismos paths de sonido

---

*Last updated: 2026-05-30*
