//=============================================================================
// l4c_music_tracks.nut — Catálogo de Tracks Custom
// Parte del L4C VScript Music Manager
//=============================================================================
// Los tracks .wav van en: sound/music/custom/
// Directorio plano (todos los archivos juntos con nombre único)
//=============================================================================

if (!("L4C_Music" in getroottable())) ::L4C_Music <- {}

::L4C_Music.Tracks <- {

    //=========================================
    // CATEGORÍAS DE TRACKS
    // Cada categoría es un array con paths a music/custom/
    // El Manager elige uno aleatorio de la categoría
    //=========================================

    // --- BOSSES ---
    Tank = [],          // Sin tracks custom (usar reemplazo vanilla en sound/music/tank/)

    Witch = [],         // Sin tracks custom (usar reemplazo vanilla en sound/music/witch/)

    BossWave = [        // 2+ tanks simultáneos
        "music/custom/double_tank.wav",
    ],

    // --- COMBATE / HORDAS (baja probabilidad) ---
    Horde = [           // 12% al iniciar panic event
        "music/custom/r_horde1.wav",
        "music/custom/r_horde2.wav",
        "music/custom/r_horde3.wav",
        "music/custom/r_horde4.wav",
    ],

    PZAttack = [],      // Sin tracks custom (usar reemplazo vanilla en sound/music/pzattack/)

    // --- ESTADOS DE JUGADOR ---
    LastManStanding = [],
    LowHealth = [],
    NearDeath = [],

    // --- EVENTOS DE EQUIPO ---
    DefibRevive = [],
    FirstAidUsed = [],
    BoomerBileTank = [],
    WitchKill = [],

    // --- SAFE / RESCUE ---
    RescueCloset = [],
    SafeRoom = [],

    // --- CALM (90s sin violencia) ---
    Calm = [
        "music/custom/chill1.wav",
        "music/custom/chill2.wav",
        "music/custom/chill3.wav",
    ],

    // --- TRANSICIONES ---
    Silence = []        // Vacío = silencio programado, sin track
}

//=============================================================================
// GetTrack(category) → string path aleatorio de la categoría
// Devuelve "" si la categoría está vacía (no hay tracks)
//=============================================================================
::L4C_Music.GetTrack <- function(category)
{
    if (!(category in ::L4C_Music.Tracks)) {
        if (::L4C_Music.Debug >= 1)
            printl("[L4C_Music] WARN: Categoría '" + category + "' no existe en Tracks")
        return ""
    }

    local pool = ::L4C_Music.Tracks[category]
    if (pool.len() == 0) {
        if (::L4C_Music.Debug >= 2)
            printl("[L4C_Music] INFO: Categoría '" + category + "' vacía (sin tracks)")
        return ""
    }

    local idx = RandomInt(0, pool.len() - 1)
    local track = pool[idx]

    if (::L4C_Music.Debug >= 1)
        printl("[L4C_Music] GetTrack('" + category + "') → " + track)

    return track
}
