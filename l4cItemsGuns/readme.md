# l4cItemsGuns — "Armas e Items Custom" v2.3

**Addon:** Lost 4 Creed — Custom Weapons & Items  
**Author:** Lost 4 Creed Team  
**Entry Point:** `scripts/vscripts/director_base_addon.nut`  
**Dependencias:** MaoLib (l4cCoreAddon)  
**Tamaño:** ~169 MB (post-compresión VTFs)

---

## 📋 Descripción

Addon que agrega nuevos modelos y texturas de armas y objetos al juego, además de mejorar la motosierra con un sistema de sangrado progresivo.

---

## 🏗️ Estructura

```
director_base_addon.nut
├── scripts/vscripts/chainsawblood.nut  ← Sangrado de motosierra
└── materials/
    ├── modelos de armas:
    │   ├── Skorpion (BO1)              ← Subfusil custom
    │   ├── Type99 LMG                  ← Ametralladora ligera
    │   ├── MG42                        ← Ametralladora pesada
    │   ├── F2000                       ← Rifle de asalto
    │   ├── Galil                       ← Rifle de asalto
    │   ├── USAS12                      ← Escopeta automática
    │   ├── Ruger 1022                  ← Rifle de precisión
    │   ├── Super Shorty                ← Escopeta de pump
    │   ├── Trigun                      → Arma estilo anime
    │   ├── RGL-80                      ← Lanzagranadas
    │   ├── Sledgehammer (Kf2)          ← Mazo (Killing Floor 2)
    │   └── linterna custom             ← Linterna personalizada
    ├── ping_system/                    ← Sistema de ping visual
    └── signs/                          ← Señales/letreros
```

---

## 📜 Scripts

### `chainsawblood.nut` — Sangrado Progresivo

**Namespace:** `::ChainsawBlood`

Sistema que incrementa el nivel de sangre de la motosierra al golpear infectados:

| Propiedad | Detalle |
|-----------|---------|
| Variable | `m_iBloodyWeaponLevel` (0-10) |
| Eventos | `infected_death`, `player_hurt`, `infected_hurt` |
| Incremento | +1 por golpe |

---

## 📦 Compresión de Texturas (VTFs)

### Pipeline `vtfzapmain`

Todas las texturas VTF fueron procesadas con `vtfzapmain` para reducir el tamaño del addon.

### Resultados

| Rango | VTFs | MB Antes | MB Después | Ahorro |
|-------|------|----------|------------|--------|
| > 10 MB | 8 | 106.67 | 26.67 | **-80 MB (75%)** |
| 500 KB – 10 MB | 181 | 353.45 | 92.12 | **-261.33 MB (73.9%)** |
| **Total** | **189** | **460.12** | **118.79** | **-341.33 MB (74.2%)** |

### Nota sobre texturas faltantes

- Fix `AmmoStack.vmt` (l4cCoreVisuals) — rutas incorrectas (`models/props/ammo_stack*`) apuntaban a texturas inexistentes. Corregido a texturas vanilla L4D2 (`models/props/terror/ammostack`).
- Todos los VMTs de l4cItemsGunks verificados — **0 texturas faltantes reales**. Las texturas custom (Skorpion, Type99, MG42, etc.) están presentes y comprimidas.

---

## 🎯 Armas Custom

| Arma | Tipo | Origen |
|------|------|--------|
| Skorpion | Subfusil | Black Ops 1 |
| Type99 LMG | Ametralladora ligera | WWII |
| MG42 | Ametralladora pesada | WWII |
| F2000 | Rifle de asalto | Moderno |
| Galil | Rifle de asalto | Moderno |
| USAS12 | Escopeta automática | Moderno |
| Ruger 1022 | Rifle de precisión | Civil |
| Super Shorty | Escopeta pump | Táctica |
| RGL-80 | Lanzagranadas | Militar |
| Sledgehammer | Melee | Killing Floor 2 |
| Trigun | Arma especial | Anime |

---

## 🔧 Dependencias

| Addon | Relación |
|-------|----------|
| l4cCoreAddon | **REQUERIDO** — Provee MaoLib |

---

## ⚠️ Notas

- Principalmente un addon de **assets gráficos** (texturas/modelos)
- El único script funcional es `chainsawblood.nut`
- Las armas custom reemplazan visualmente a las armas vanilla

---

*Last updated: 2026-05-30*
