// MaoLib cargado exclusivamente por l4cCoreAddon

// ⚠️ Dynamic lights REMOVIDOS: l4c_sal, l4c_sfl_mao
// Causaban inestabilidad y conflictos. Mantenemos solo efectos visuales sin luces dinámicas.
// shared.nut también removido — solo era usado por los sistemas de luz dinámica.

IncludeScript("l4c_dymlight", getroottable());
IncludeScript("l4c_dymlight_muzzle", getroottable());
IncludeScript("simplebloom_activator", getroottable());

// Flicker de linterna cada 5-15s (MaoLib timer, no logic_timer)
IncludeScript("flashlight_flickering", getroottable());

// Efectos de sangre mejorados
IncludeScript("blood_splatter_effect", getroottable());
IncludeScript("blood_pool", getroottable());

Convars.SetValue("cl_cinematiclight_b", 0);
Convars.SetValue("cl_cinematiclight_g", 0);
Convars.SetValue("cl_cinematiclight_r", 10);
Convars.SetValue("cl_cinematiclight_scale", 8.0);
Convars.SetValue("cl_cinematiclight_tonemap", "0.2");
// === FLASHLIGHT SETTINGS ===
// Diseño: Alto brillo, corto alcance (táctico/horror)
// Vanilla ref: far=750, fov=53, 3rd_range=60, brightness=0.25, linear=100, near=4

Convars.SetValue("r_flashlightbrightness", 2.5);           // 10x vanilla — haz muy brillante cerca
Convars.SetValue("r_flashlightfar", 750.0);                // Vanilla — corto alcance
Convars.SetValue("r_flashlightfov", 120);                  // Amplio — cobertura generosa
Convars.SetValue("r_flashlight_3rd_person_range", 300);    // Amplio — luz ajena visible a distancia media
Convars.SetValue("r_flashlightinfectedfov", 140);          // Amplio — haz infectado generoso
Convars.SetValue("r_flashlightlinear", 75);                // Intermedio — caída moderada, punch a ~15m
Convars.SetValue("r_flashlightnear", 4.0);                 // Vanilla
Convars.SetValue("r_flashlightshadowatten", 0.10);         // Sombras muy profundas (vanilla=0.35)
Convars.SetValue("r_flashlightambient", 0.0);              // Sin luz ambiental del haz
Convars.SetValue("r_flashlightconstant", 0.0);             // Vanilla
Convars.SetValue("r_flashlightquadratic", 0.0);            // Vanilla
Convars.SetValue("r_flashlightvolumetrics", 1);            // Volumétricos activos (si soporta)
Convars.SetValue("r_flashlightmodels", 1);                 // Iluminar modelos
Convars.SetValue("r_FlashlightDetailProps", 1);            // Iluminar props de detalle
Convars.SetValue("cl_ragdoll_limit", "25");

Convars.SetValue("r_decal_cover_count", 3);
Convars.SetValue("r_decal_overlap_area", 1);
Convars.SetValue("r_decal_overlap_count", 5);
Convars.SetValue("r_decals", 1000);
printl("Decal Cvars");
