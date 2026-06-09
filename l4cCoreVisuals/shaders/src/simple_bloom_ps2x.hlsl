// simple_bloom_ps2x.hlsl - BLOOM + COLOR QUANTIZATION
// v4 - Mayo 2026 - Sin pixelacion (causaba bugs de distancia)
//
// - Kawase multi-iteration blur (13 samples, half-pixel offset)
// - Cuantizacion de color progresiva en zonas oscuras (posterized shadows)
// - Thresholds ultra-bajos: solo reacciona en casi-negro
//
// c0: bloom params (threshold, intensity, blur_radius)
// c1: quantization params (dark_thresh, light_thresh, 0, color_levels)
// c2: texel size (1/width, 1/height) para Kawase

#include "common.hlsl"

// c0 - Bloom
#define BloomThreshold  Constants0.x   // brightness threshold (0.7 default)
#define BloomIntensity  Constants0.y   // bloom intensity (1.5 default)
#define BlurRadius      max(Constants0.z, 0.001)  // pixel radius for Kawase (3.0 default)

// c1 - Quantization params
#define PixelDarkThresh  Constants1.x  // luminance <= this = full effects (0.005)
#define PixelLightThresh Constants1.y  // luminance >= this = no effects (0.02)
#define ColorLevels      max(Constants1.w, 2.0)    // color levels in darkness (16 default)

// c2 - Screen info (texel size for Kawase)
#define TexelSizeX  Constants2.x  // 1.0 / screen_width  (0.00052 at 1920)
#define TexelSizeY  Constants2.y  // 1.0 / screen_height (0.00093 at 1080)

// Luminance helper
float Luminance(float3 c)
{
    return dot(c, float3(0.299, 0.587, 0.114));
}

// ============================================================
// KAWASE BLUR (3 iteraciones, 13 samples)
// ============================================================
// Cada iteracion usa half-pixel offset con radio creciente:
//   1x, 3x, 5x el BlurRadius (en pixels)
// Ej: BlurRadius=2 → muestreo a 2, 6, 10 píxeles de distancia
float3 KawaseBlur(float2 uv, float radius)
{
    float2 texel = float2(TexelSizeX, TexelSizeY);
    if (texel.x <= 0.0) texel.x = 0.00052;  // fallback 1920
    if (texel.y <= 0.0) texel.y = 0.00093;  // fallback 1080

    float3 sum = tex2D(TexBase, uv).rgb;
    float totalWeight = 1.0;

    // Iteracion 1: 1x radius (cerca)
    float2 off1 = texel * radius;
    sum += tex2D(TexBase, uv + float2( off1.x,  off1.y)).rgb;
    sum += tex2D(TexBase, uv + float2(-off1.x,  off1.y)).rgb;
    sum += tex2D(TexBase, uv + float2( off1.x, -off1.y)).rgb;
    sum += tex2D(TexBase, uv + float2(-off1.x, -off1.y)).rgb;
    totalWeight += 4.0;

    // Iteracion 2: 3x radius (medio)
    float2 off2 = texel * (radius * 3.0);
    sum += tex2D(TexBase, uv + float2( off2.x,  off2.y)).rgb;
    sum += tex2D(TexBase, uv + float2(-off2.x,  off2.y)).rgb;
    sum += tex2D(TexBase, uv + float2( off2.x, -off2.y)).rgb;
    sum += tex2D(TexBase, uv + float2(-off2.x, -off2.y)).rgb;
    totalWeight += 4.0;

    // Iteracion 3: 5x radius (lejos)
    float2 off3 = texel * (radius * 5.0);
    sum += tex2D(TexBase, uv + float2( off3.x,  off3.y)).rgb;
    sum += tex2D(TexBase, uv + float2(-off3.x,  off3.y)).rgb;
    sum += tex2D(TexBase, uv + float2( off3.x, -off3.y)).rgb;
    sum += tex2D(TexBase, uv + float2(-off3.x, -off3.y)).rgb;
    totalWeight += 4.0;

    return sum / totalWeight;
}

// ============================================================
// BOX BLUR 3x3 (fallback para radius chico)
// ============================================================
float3 Blur3x3(float2 uv)
{
    float2 texel = float2(TexelSizeX, TexelSizeY);
    if (texel.x <= 0.0) texel.x = 0.00052;
    if (texel.y <= 0.0) texel.y = 0.00093;

    float3 color = 0;
    for (int bx = -1; bx <= 1; bx++)
    {
        for (int by = -1; by <= 1; by++)
        {
            float2 offset = float2(bx, by) * texel;
            color += tex2D(TexBase, uv + offset).rgb;
        }
    }
    return color / 9.0;
}

float4 main( PS_INPUT i ) : COLOR
{
    float2 uv = i.uv;

    float4 baseColor = tex2D(TexBase, uv);
    float3 color = baseColor.rgb;
    float lum = Luminance(color);

    // darknessFactor: 0 = luz, 1 = oscuridad total
    float darknessFactor = 1.0 - smoothstep(PixelDarkThresh, PixelLightThresh, lum);

    // ========== 1. CUANTIZACION DE COLOR PROGRESIVA ==========
    // En oscuridad: posterizado (16 niveles por canal)
    // En luz: 256 niveles (sin cambios)
    if (darknessFactor > 0.001)
    {
        float levels = ColorLevels + (256.0 - ColorLevels) * (1.0 - darknessFactor);
        color = floor(color * levels + 0.5) / levels;
    }

    // ========== 2. BLOOM (Kawase) ==========
    float3 brights = max(color - BloomThreshold, 0);
    float brightLum = Luminance(brights);

    if (brightLum > 0.001)
    {
        float3 bloom;

        if (BlurRadius > 1.0)
            bloom = KawaseBlur(uv, BlurRadius);
        else
            bloom = Blur3x3(uv);

        color += bloom * BloomIntensity;
    }

    return float4(color, baseColor.a);
}
