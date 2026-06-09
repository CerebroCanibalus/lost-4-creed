// Load MaoLib central library first (auto-loads timers_cleanup, vfx, events)
IncludeScript("maolib", getroottable());

// ⚠️ Dynamic lights REMOVIDOS: l4c_sal, l4c_sfl_mao
// Causaban inestabilidad y conflictos. Mantenemos solo efectos visuales sin luces dinámicas.
// shared.nut también removido — solo era usado por los sistemas de luz dinámica.

IncludeScript("l4c_dymlight", getroottable());
IncludeScript("l4c_dymlight_muzzle", getroottable());
IncludeScript("simplebloom_activator", getroottable());

IncludeScript("blood_splatter_effect", getroottable());
IncludeScript("blood_pool", getroottable());

Convars.SetValue("cl_cinematiclight_b", 0);
Convars.SetValue("cl_cinematiclight_g", 0);
Convars.SetValue("cl_cinematiclight_r", 10);
Convars.SetValue("cl_cinematiclight_scale", 8.0);
Convars.SetValue("cl_cinematiclight_tonemap", "0.2");
Convars.SetValue("r_flashlightshadowatten", 0.15);
Convars.SetValue("r_flashlight_3rd_person_range", "300");
Convars.SetValue("r_flashlightfov", 120);
Convars.SetValue("r_flashlightinfectedfov", "140");
Convars.SetValue("r_flashlightfar", 1500);
Convars.SetValue("r_flashlightbrightness", 1.0);
Convars.SetValue("r_flashlightlinear", 50);
Convars.SetValue("r_flashlightnear", 2);
Convars.SetValue("cl_ragdoll_limit", "25");

Convars.SetValue("r_decal_cover_count", 3);
Convars.SetValue("r_decal_overlap_area", 1);
Convars.SetValue("r_decal_overlap_count", 5);
Convars.SetValue("r_decals", 1000);
printl("Decal Cvars");
