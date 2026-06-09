"""
l4cCoreVisuals - Shader Preview Tool (OPTIMIZADO)
Reimplementa simple_bloom_ps2x.hlsl en Python.
Usa numpy vectorizado para ser rapido incluso a 1080p.

Uso:
    python shader_preview.py ruta/a/screenshot.png [opciones]

Opciones (mismos defaults que el VMT):
    --threshold 0.7      Umbral bloom (c0_x)
    --intensity 1.5      Intensidad bloom (c0_y)
    --blur-radius 0.003  Radio blur bloom (c0_z)
    --dark-thresh 0.15   Luminancia para pixelacion total (c1_x)
    --light-thresh 0.45  Luminancia sin pixelacion (c1_y)
    --block-min 0.008    Tamano bloque minimo en UV (poca oscuridad)
    --block-max 0.040    Tamano bloque MAX en oscuridad total
    --colors 16          Cantidad de colores por canal en oscuridad (c1_w, 256 = sin cuantizar)
    --output result.png  Archivo de salida
    --resize 0.5         Escala para preview rapido (0.5 = mitad de resolucion)
"""

import sys
import os
import numpy as np
from PIL import Image
from numpy.lib.stride_tricks import sliding_window_view


# ============================================================
# CONVOLUCION 2D VECTORIZADA (sliding window)
# ============================================================

def convolve2d_fast(image, kernel):
    """Convolucion 2D vectorizada con numpy (100x mas rapida que manual)."""
    kh, kw = kernel.shape
    pad_h, pad_w = kh // 2, kw // 2
    padded = np.pad(image, ((pad_h, pad_h), (pad_w, pad_w)), mode='reflect')
    windows = sliding_window_view(padded, (kh, kw))
    return np.sum(windows * kernel, axis=(-2, -1))


# ============================================================
# KERNELS (igual que HLSL)
# ============================================================

KERNEL_5X5 = np.array([
    [np.exp(-(kx*kx + ky*ky) / 2.0) for ky in range(-2, 3)]
    for kx in range(-2, 3)
], dtype=np.float32)
KERNEL_5X5 /= KERNEL_5X5.sum()

KERNEL_3X3 = np.ones((3, 3), dtype=np.float32) / 9.0


def gaussian_blur_5x5(image):
    """Blur 5x5 vectorizado."""
    if image.ndim == 3:
        return np.stack([convolve2d_fast(image[..., c], KERNEL_5X5) for c in range(3)], axis=2)
    return convolve2d_fast(image, KERNEL_5X5)


def box_blur_3x3(image):
    """Box blur 3x3 vectorizado."""
    if image.ndim == 3:
        return np.stack([convolve2d_fast(image[..., c], KERNEL_3X3) for c in range(3)], axis=2)
    return convolve2d_fast(image, KERNEL_3X3)


# ============================================================
# HELPERS (igual que HLSL)
# ============================================================

def luminance(rgb):
    """dot(c, float3(0.299, 0.587, 0.114))."""
    return np.dot(rgb[..., :3], [0.299, 0.587, 0.114])


def smoothstep(edge0, edge1, x):
    """Hermite identico al HLSL."""
    t = np.clip((x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


# ============================================================
# SHADER CORE
# ============================================================

def apply_shader(img_array, params):
    h, w = img_array.shape[:2]
    color = img_array[..., :3].copy().astype(np.float32)
    lum = luminance(color)

    # ===== 1. PIXELACION PROGRESIVA =====
    block_min = params['block_min']
    block_max = params['block_max']

    if block_max > 0:
        dark_th = params['dark_thresh']
        light_th = params['light_thresh']

        # pixelFactor va de 0 (luz) a 1 (oscuridad)
        pixel_factor = 1.0 - smoothstep(dark_th, light_th, lum)

        if pixel_factor.max() > 0.001:
            h_img, w_img = h, w
            # UV grid
            uv_x = np.tile(np.arange(w_img, dtype=np.float32) / w_img, (h_img, 1))
            uv_y = np.tile(np.arange(h_img, dtype=np.float32) / h_img, (w_img, 1)).T

            # Block size progresivo: crece con la oscuridad
            block_size = block_min + (block_max - block_min) * pixel_factor

            # blockUV = floor(uv / blockSize) * blockSize + blockSize * 0.5
            block_uv_x = np.floor(uv_x / block_size) * block_size + block_size * 0.5
            block_uv_y = np.floor(uv_y / block_size) * block_size + block_size * 0.5

            bx = np.clip((block_uv_x * (w_img - 1)).astype(np.int32), 0, w_img - 1)
            by = np.clip((block_uv_y * (h_img - 1)).astype(np.int32), 0, h_img - 1)

            pixelated = img_array[by, bx, :3].astype(np.float32)

            pf_3d = np.expand_dims(pixel_factor, axis=2)
            color = color * (1.0 - pf_3d) + pixelated * pf_3d

    # ===== 2. CUANTIZACION DE COLOR PROGRESIVA =====
    # En oscuridad: pocos niveles de color (posterizado)
    # En luz: 256 niveles (sin cuantizar)
    color_levels = params['color_levels']
    if color_levels < 256:
        # darknessFactor = 1 en sombras, 0 en luz
        darkness_factor = 1.0 - smoothstep(params['dark_thresh'], params['light_thresh'], lum)
        if darkness_factor.max() > 0.001:
            # Niveles progresivos: desde colorLevels hasta 256
            levels = color_levels + (256.0 - color_levels) * (1.0 - darkness_factor)
            df_3d = np.expand_dims(darkness_factor, axis=2)
            lv_3d = np.expand_dims(levels, axis=2)
            color = np.floor(color * lv_3d + 0.5) / lv_3d

    # ===== 3. BLOOM =====
    threshold = params['threshold']
    intensity = params['intensity']

    brights = np.maximum(color - threshold, 0)
    bright_lum = luminance(brights)

    if bright_lum.max() > 0.001:
        if params['blur_radius'] > 0.001:
            bloom = gaussian_blur_5x5(color)
        else:
            bloom = box_blur_3x3(color)

        color = color + bloom * intensity

    return np.clip(color, 0.0, 1.0)


# ============================================================
# CLI
# ============================================================

def main():
    if len(sys.argv) < 2 or sys.argv[1] in ('-h', '--help'):
        print(__doc__)
        sys.exit(1)

    input_path = sys.argv[1]
    if not os.path.exists(input_path):
        print(f'Error: no existe {input_path}')
        sys.exit(1)

    params = {
        'threshold': 0.65,
        'intensity': 2.5,
        'blur_radius': 0.003,
        'dark_thresh': 0.005,
        'light_thresh': 0.02,
        'block_min': 0.001,
        'block_max': 0.005,
        'color_levels': 16,
        'resize': 1.0,
        'output': None,
    }

    i = 2
    while i < len(sys.argv):
        arg = sys.argv[i]
        if arg == '--threshold' and i + 1 < len(sys.argv):
            params['threshold'] = float(sys.argv[i + 1]); i += 2
        elif arg == '--intensity' and i + 1 < len(sys.argv):
            params['intensity'] = float(sys.argv[i + 1]); i += 2
        elif arg == '--blur-radius' and i + 1 < len(sys.argv):
            params['blur_radius'] = float(sys.argv[i + 1]); i += 2
        elif arg == '--dark-thresh' and i + 1 < len(sys.argv):
            params['dark_thresh'] = float(sys.argv[i + 1]); i += 2
        elif arg == '--light-thresh' and i + 1 < len(sys.argv):
            params['light_thresh'] = float(sys.argv[i + 1]); i += 2
        elif arg == '--block-min' and i + 1 < len(sys.argv):
            params['block_min'] = float(sys.argv[i + 1]); i += 2
        elif arg == '--block-max' and i + 1 < len(sys.argv):
            params['block_max'] = float(sys.argv[i + 1]); i += 2
        elif arg == '--colors' and i + 1 < len(sys.argv):
            params['color_levels'] = float(sys.argv[i + 1]); i += 2
        elif arg == '--output' and i + 1 < len(sys.argv):
            params['output'] = sys.argv[i + 1]; i += 2
        else:
            print(f'Error: argumento desconocido: {arg}')
            sys.exit(1)

    img = Image.open(input_path).convert('RGBA')

    # Resize para preview rapido
    scale = params['resize']
    if scale < 1.0:
        new_w = int(img.width * scale)
        new_h = int(img.height * scale)
        img = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
        print(f'  Redimensionado: {new_w}x{new_h}')

    img_array = np.array(img, dtype=np.float32) / 255.0
    print(f'Cargando: {input_path}  ({img.width}x{img.height})')

    print('Procesando...')
    print(f'  Bloom:   thresh={params["threshold"]}, int={params["intensity"]}, blur={params["blur_radius"]}')
    print(f'  Pixel:   dark<={params["dark_thresh"]}, light>={params["light_thresh"]}, block_min={params["block_min"]}, block_max={params["block_max"]}')
    print(f'  Color:   {params["color_levels"]} niveles en sombras (progresivo a 256)')

    result = apply_shader(img_array, params)

    output_path = params['output'] or os.path.splitext(input_path)[0] + '_bloom.png'
    result_img = Image.fromarray((result * 255).astype(np.uint8))
    result_img.save(output_path)
    print(f'Guardado: {output_path}')


if __name__ == '__main__':
    main()
