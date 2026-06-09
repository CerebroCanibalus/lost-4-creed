// ============================================================
// L4CWI — Core System v1.0
// Base común para todos los sistemas de l4cWeaponItemScripts
// ============================================================

::L4CWI_Core <- {
    VERSION = "1.0"
    DEBUG_GLOBAL = 1
    
    // ============================================================
    // DEBUG
    // ============================================================
    function Dbg(system, msg) {
        if (::L4CWI_Core.DEBUG_GLOBAL)
            printl("[L4CWI][" + system + "][DEBUG] " + msg)
    }
    
    function DbgWarn(system, msg) {
        printl("[L4CWI][" + system + "][WARN] " + msg)
    }
    
    function DbgError(system, msg) {
        printl("[L4CWI][" + system + "][ERROR] " + msg)
    }
    
    // ============================================================
    // CONFIG PARSER UNIFICADO (INI-like)
    // ============================================================
    function ParseConfig(path, defaults) {
        local result = clone defaults
        local content = FileToString(path)
        
        if (!content) {
            ::L4CWI_Core.WriteConfig(path, defaults)
            return result
        }
        
        foreach (line in split(content, "\n")) {
            line = strip(line)
            if (line.len() == 0) continue
            if (line.find("//") == 0) continue
            
            local idx = line.find("=")
            if (idx == null) continue
            
            local key = strip(line.slice(0, idx))
            local val = strip(line.slice(idx + 1))
            
            if (!(key in result)) continue
            
            local defaultVal = defaults[key]
            local valType = typeof(defaultVal)
            
            try {
                if (valType == "integer") result[key] = val.tointeger()
                else if (valType == "float") result[key] = val.tofloat()
                else if (valType == "bool") result[key] = (val == "true" || val == "1")
                else result[key] = val
            } catch (e) {
                ::L4CWI_Core.DbgWarn("Config", "Failed to parse '" + key + "' in " + path + ": " + e)
            }
        }
        
        return result
    }
    
    function WriteConfig(path, data) {
        local content = "// L4CWI Config - " + path + "\n"
        content += "// Auto-generated. Edit values after '='\n\n"
        
        foreach (key, val in data) {
            content += key + " = " + val + "\n"
        }
        
        StringToFile(path, content)
    }
    
    // ============================================================
    // UTILIDADES COMUNES
    // ============================================================
    function GetActiveWeaponClass(player) {
        local w = player.GetActiveWeapon()
        return w ? w.GetClassname() : null
    }
    
    function GetWeaponModel(player) {
        local w = player.GetActiveWeapon()
        return w ? w.GetModelName() : null
    }
    
    function IsSurvivorAlive(player) {
        return player && player.IsValid() && player.IsSurvivor() 
            && NetProps.GetPropInt(player, "m_lifeState") == 0
    }
    
    function IsHumanPlayer(player) {
        return player && player.IsValid() && !IsPlayerABot(player)
    }
    
    function GetSurvivors() {
        local survivors = []
        local ent = null
        while (ent = Entities.FindByClassname(ent, "player")) {
            if (ent.IsValid() && ent.IsSurvivor() && NetProps.GetPropInt(ent, "m_lifeState") == 0)
                survivors.append(ent)
        }
        return survivors
    }
    
    function ForEachSurvivor(callback) {
        local ent = null
        while (ent = Entities.FindByClassname(ent, "player")) {
            if (ent.IsValid() && ent.IsSurvivor() && NetProps.GetPropInt(ent, "m_lifeState") == 0)
                callback(ent)
        }
    }
    
    // ============================================================
    // REGISTRO DE SISTEMAS
    // ============================================================
    Systems = []
    
    function RegisterSystem(name, sysTable) {
        sysTable._systemName <- name
        sysTable._Dbg <- function(msg) { ::L4CWI_Core.Dbg(name, msg) }
        sysTable._DbgWarn <- function(msg) { ::L4CWI_Core.DbgWarn(name, msg) }
        sysTable._DbgError <- function(msg) { ::L4CWI_Core.DbgError(name, msg) }
        
        Systems.append(sysTable)
        ::L4CWI_Core.Dbg("Core", "Registered system: " + name)
        
        if ("Init" in sysTable) {
            try {
                sysTable.Init()
            } catch (e) {
                ::L4CWI_Core.DbgError(name, "Init failed: " + e)
            }
        }
    }
    
    function CleanupSystems() {
        foreach (sys in Systems) {
            if ("Cleanup" in sys) {
                try {
                    sys.Cleanup()
                } catch (e) {
                    ::L4CWI_Core.DbgError(sys._systemName, "Cleanup failed: " + e)
                }
            }
        }
        Systems.clear()
    }
    
    // ============================================================
    // GAME EVENTS — Despacho central
    // ============================================================
    function OnGameEvent_round_start(params) {
        foreach (sys in Systems) {
            if ("OnRoundStart" in sys) {
                try { sys.OnRoundStart(params) } catch (e) {}
            }
        }
    }
    
    function OnGameEvent_round_end(params) {
        foreach (sys in Systems) {
            if ("OnRoundEnd" in sys) {
                try { sys.OnRoundEnd(params) } catch (e) {}
            }
        }
        CleanupSystems()
    }
    
    function OnGameEvent_round_start_post_nav(params) {
        foreach (sys in Systems) {
            if ("OnRoundStartPostNav" in sys) {
                try { sys.OnRoundStartPostNav(params) } catch (e) {}
            }
        }
    }
}

__CollectGameEventCallbacks(::L4CWI_Core)
printl("[L4CWI] Core System v" + ::L4CWI_Core.VERSION + " loaded")
