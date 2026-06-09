// survivor_ai_overhaul.nut - Entry point for Minimal Intervention AI
// Loads all modules in correct dependency order
//
// Module loading order:
// 1. config.nut   - Defines SurvivorAI table, constants, state
// 2. validator.nut - Navmesh validation and safe pathfinding
// 3. vision.nut    - Proactive vision system (must load before detector)
// 4. detector.nut  - Detects when vanilla AI is failing
// 5. executor.nut  - Executes minimal interventions
// 6. core.nut      - Think loop, entry point

printl("[SurvivorAI] Loading Minimal Intervention AI system...")

// 1. CONFIG - define tabla principal y ShouldVisionScan
printl("[SurvivorAI] Cargando modulo: sa_config.nut")
if (!IncludeScript("sa_config", getroottable()))
    error("[SurvivorAI][FATAL] No se encontro sa_config.nut!\n")

printl("[SurvivorAI] Cargando modulo: sa_validator.nut")
if (!IncludeScript("sa_validator", getroottable()))
    error("[SurvivorAI][FATAL] No se encontro sa_validator.nut!\n")

printl("[SurvivorAI] Cargando modulo: sa_vision.nut")
if (!IncludeScript("sa_vision", getroottable()))
    error("[SurvivorAI][FATAL] No se encontro sa_vision.nut!\n")

printl("[SurvivorAI] Cargando modulo: sa_detector.nut")
if (!IncludeScript("sa_detector", getroottable()))
    error("[SurvivorAI][FATAL] No se encontro sa_detector.nut!\n")

printl("[SurvivorAI] Cargando modulo: sa_executor.nut")
if (!IncludeScript("sa_executor", getroottable()))
    error("[SurvivorAI][FATAL] No se encontro sa_executor.nut!\n")

printl("[SurvivorAI] Cargando modulo: sa_items.nut")
if (!IncludeScript("sa_items", getroottable()))
    error("[SurvivorAI][FATAL] No se encontro sa_items.nut!\n")

printl("[SurvivorAI] Cargando modulo: sa_core.nut")
if (!IncludeScript("sa_core", getroottable()))
    error("[SurvivorAI][FATAL] No se encontro sa_core.nut!\n")

// Verificacion post-carga
if (!("ShouldVisionScan" in ::SurvivorAI))
    error("[SurvivorAI][FATAL] ShouldVisionScan NO fue cargada! Crash inminente.\n")

printl("[SurvivorAI] Todos los modulos cargados exitosamente.")
