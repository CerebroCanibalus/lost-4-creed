# l4cCoreVisuals — "Graybox Aesthetics" v4

**Addon:** Lost 4 Creed — Visual Conversion  
**Author:** Beria & Richardhaifer  
**Entry Point:** `scripts/vscripts/director_base_addon.nut`  
**Tamaño:** ~331 MB (2,102 archivos)  
**VTFs:** 941 texturas comprimidas (~275 MB)

---

## 📋 Estructura del Addon

| Carpeta | Propósito |
|---------|-----------|
| `materials/` | 941 VTFs + VMTs (~275 MB): ciudad, vegetación, metal, madera, partículas, cielos, efectos, decals, graffiti |
| `models/` | Props custom, deadbodies, vehicles, armas, tren, edificios, foliage |
| `particles/` | 7 PCFs: screen_fx, smoker, spitter, steam, survivor, water, weapon |
| `scripts/vscripts/` | 11 scripts: bloom, luces dinámicas, sangre, linterna, UI |
| `shaders/fxc/` | 1 shader compilado: `simple_bloom_ps20b.vcs` |
| `shaders/src/` | HLSL fuente + `shader_preview.py` para test offline |
| `sound/` | Airport crash sequence WAV |
| `resource/` | UI modifications |

---

## 📦 Compresión de Texturas (VTFs)

### Pipeline `vtfzapmain`

Para reducir el tamaño del addon, todas las texturas VTF fueron procesadas con una herramienta propia (`vtfzapmain`) que **descarta el mipmap más grande** de cada textura, reduciendo su resolución a la mitad sin pérdida visual apreciable en el motor Source.

### Proceso

| Pasada | Rango | VTFs | MB Antes | MB Después | Ahorro |
|--------|-------|------|----------|------------|--------|
| 1 | > 2 MB | 80 | 421.25 | 112.48 | **-308.77 MB (73%)** |
| 2 | 1–2 MB | 129 | 161.21 | 42.31 | **-118.90 MB (74%)** |
| **Total** | > 1 MB | **209** | **582.46** | **154.79** | **-427.67 MB (73%)** |

### Cómo funciona

```
VTF original (1024×1024, 11 mips)                    VTF comprimido (512×512, 10 mips)
┌─────────────────────┐                               ┌─────────────────────┐
│  Mip 0: 1024×1024   │  ─── vtfzapmain ───→         │  Mip 0: 512×512    │ (antes era mip 1)
│  Mip 1: 512×512     │    (descarta mip 0)           │  Mip 1: 256×256    │
│  Mip 2: 256×256     │                               │  ...               │
│  ...                │                               └─────────────────────┘
└─────────────────────┘
```

Para VTFs sin mipmaps (1 solo mip), primero se genera la cadena completa con `vtfgenmips` y luego se aplica `vtfzapmain`. El motor Source usa el mipmap adecuado según la distancia, por lo que la calidad visual se mantiene.

### Herramientas

Ubicadas en `tools/vtf-tools/bin_x64/`:

| Tool | Función |
|------|---------|
| `vtfzapmain.exe` | Descarta el mipmap más grande (reduce resolución a la mitad) |
| `vtfgenmips.exe` | Genera cadena de mipmaps completa para VTFs sin ella |

### Modo de uso

```powershell
# Individual
vtfzapmain.exe textura.vtf

# Batch (solo archivos sin mipchain)
vtfgenmips.exe textura.vtf
vtfzapmain.exe textura.vtf

# Batch completo (PowerShell)
$vtfs = Get-ChildItem -Recurse -Filter "*.vtf" | Where-Object Length -gt 1MB
foreach ($v in $vtfs) {
    vtfzapmain.exe $v.FullName
    $after = (Get-Item $v.FullName).Length
    if ($after -ge $v.Length - 1024) {
        vtfgenmips.exe $v.FullName
        vtfzapmain.exe $v.FullName
    }
}
```

> **Nota:** `vtfzapmain` opera in-place (modifica el archivo original). Opera con VTF 7.2–7.5. Usa API VTFLib creando un VTF limpio intermedio, evitando corrupción en VTFs con resource entries dañados.

---

## 🔍 Shader: `simple_bloom_ps20b.vcs` (v4)

### Arquitectura

Un único shader de postproceso que combina **bloom** + **cuantización de color progresiva**:

```
         ┌─────────────────────────────────┐
         │         FRAMEBUFFER IN          │
         │       (_rt_FullFrameFB)         │
         └──────────┬──────────────────────┘
                    │
         ┌──────────▼──────────────────────┐
         │  ① CUANTIZACIÓN DE COLOR         │
         │  · 16 niveles en oscuridad       │
         │  · 256 niveles en luz           │
         │  · Transición progresiva         │
         └──────────┬──────────────────────┘
                    │
         ┌──────────▼──────────────────────┐
         │  ② BLOOM (Kawase)               │
         │  · Threshold: solo brillos       │
         │  · Kawase 3 iteraciones          │
         │  · 13 samples, half-pixel offset │
         └──────────┬──────────────────────┘
                    │
         ┌──────────▼──────────────────────┐
         │         FRAMEBUFFER OUT          │
         └─────────────────────────────────┘
```

### Archivos

| Archivo | Ruta | Rol |
|---------|------|-----|
| `simple_bloom_ps20b.vcs` | `shaders/fxc/` | Shader compilado (734 bytes) |
| `simple_bloom.vmt` | `materials/effects/shaders/` | Material VMT con parámetros |
| `simplebloom_activator.nut` | `scripts/vscripts/` | Script que activa el overlay |
| `simple_bloom_ps2x.hlsl` | `shaders/src/` | Fuente HLSL (v4, Kawase) |
| `compile_shader.bat` | raíz del addon | Compila + deploya el shader |
| `shader_preview.py` | `shaders/src/` | Preview offline en Python |

### Parámetros del VMT

| VMT | Shader | Valor | Efecto |
|-----|--------|-------|--------|
| `$c0_x` | `BloomThreshold` | **0.85** | Solo brillos intensos generan bloom |
| `$c0_y` | `BloomIntensity` | **2.0** | Intensidad del bloom |
| `$c0_z` | `BlurRadius` | **3.0** | Kawase pixel radius (1x, 3x, 5x spread) |
| `$c1_x` | `PixelDarkThresh` | **0.005** | Oscuridad para efectos (casi negro) |
| `$c1_y` | `PixelLightThresh` | **0.02** | Luminancia para salir de efectos |
| `$c1_w` | `ColorLevels` | **16** | Niveles de color en sombras (2-256) |
| `$c2_x` | `TexelSizeX` | **0.000521** | 1/1920 (texel size X) |
| `$c2_y` | `TexelSizeY` | **0.000926** | 1/1080 (texel size Y) |

### Kawase Blur

Reemplaza el Gaussian 5x5 original (25 samples) por un blur multi-iteración:

- **13 samples** en 3 iteraciones (vs 25 del Gaussian)
- Half-pixel offset sampling = más suave que box blur
- Iteraciones a 1x, 3x, 5x el `BlurRadius`
- Ej: radius=3 → muestreo a 3, 9 y 15 píxeles

### Compilación

```
compile_shader.bat
```

Compila `shaders/src/simple_bloom_ps2x.hlsl` como SM3.0, renombra a `_ps20b`, deploya a `shaders/fxc/`. Requiere `ShaderCompile.exe` de ficool2 SDK.

**No necesita recompilación para ajustar parámetros** — los valores se pasan en runtime via `$c0`/`$c1`/`$c2` del VMT.

### Shader Preview (Python)

```bash
cd shaders/src
python shader_preview.py screenshot.png --threshold 0.85 --intensity 2.0 --colors 16
```

Solo requiere numpy + pillow. Procesa screenshots con el mismo algoritmo que el HLSL.

---

## 📜 VScripts

### `director_base_addon.nut` (Entry Point)
- Carga MaoLib y subsistemas via `IncludeScript`
- Setea convars visuales: cinematic light, flashlight, decals, ragdoll limit
- ✅ Incluye `flashlight_flickering.nut`

### `simplebloom_activator.nut`
- Tabla `::SimpleBloom_Activator` registrada con `__CollectGameEventCallbacks`
- `OnGameEvent_player_spawn`: spawn `env_screenoverlay` con overlay `effects/shaders/simple_bloom`
- Cleanup en `round_end`, `map_transition`, `mission_lost`

### `l4c_dymlight.nut` — Dynamic Projectile Lighting
- Luz dinámica para: molotov, spitter, pipe bomb, firecracker, insect swarm

### `l4c_dymlight_muzzle.nut` — Muzzle Flash Lighting
- `light_dynamic` que se activa en `weapon_fire` (duración 0.08s)

### `blood_splatter_effect.nut` — Enhanced Blood Decals
- Decals de sangre en `player_hurt` e `infected_hurt`
- Array circular de 256 para evitar string table overflow

### `blood_pool.nut` — Ground Blood Pools
- 25% chance en `player_death` (infected)
- `info_particle_system` (blood_bleedout / blood_incapacitated)

### `flashlight_dym.nut` — Bot Flashlight
- ⚠️ Desactivado (inestabilidad por `env_projectedtexture`)

### `flashlight_flickering.nut` — Flashlight Flicker
- Tabla `::flickerthewristgeeb` registrada con `__CollectGameEventCallbacks`
- Ciclo: normal(0.6) → flicker(0.15) → normal → flicker → normal, pausa 5-15s
- ✅ Migrado de `logic_timer` a `MaoLib.AddTimerSafe` + cleanup

### `shared.nut` — Shared State
- ⚠️ No incluido en `director_base_addon.nut`

---

## 🔧 Notas de Mantenimiento

### Eventos
- **SIEMPRE** tablas dedicadas + `__CollectGameEventCallbacks(tabla)`
- **Prohibido** `function OnGameEvent_*()` global
- **Prohibido** `__CollectGameEventCallbacks(getroottable())`

### Problemas Conocidos
- `flashlight_dym.nut` desactivado (`env_projectedtexture`)
- `shared.nut` no incluido en entry point
- `$c2_x/y` hardcodeados para 1920x1080 — cambiar si se usa otra resolución

### Backups en `shader_backup/`
- `simple_bloom_ps20b.vcs` (original)
- `simple_bloom.vmt` (original)
- `simplebloom_activator.nut` (original)

### Changelog

| Versión | Cambios |
|---------|---------|
| v2.4 | Reemplazo sistema muzzleflash: `weapon_fx.pcf` + materiales de Ultramuzzle + `muzzleflashx.vtf` de NewRifleMuzzle + texturas vanilla. Backup del PCF anterior en `.backup` |
| v2.3 | Fix `AmmoStack.vmt` — rutas de textura apuntaban a archivos inexistentes (`ammo_stack*`), corregido a texturas vanilla L4D2 (`ammostack` en `models/props/terror/`) |
| v2.2 | Compresión masiva de texturas: 209 VTFs (>1 MB) reducidos de 582 MB → 155 MB (-73%) |
| v4 | Kawase blur, cuantización de color progresiva, sin pixelación |
| v3 | Compilación SM3.0 renombrado, blur corregido |
| v2 | HLSL escrito desde cero, bug gaussiano corregido |
| v1 | Shader original (simple bloom, 3 parámetros) |

*Last updated: 2026-05-30*
