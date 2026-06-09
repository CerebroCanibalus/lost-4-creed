printl("-------- REWORKED RECOIL --------");
printl("        ~ By ygoroffici ~         ");

const YS_RR_VERSION = "1.0";
const YS_RR_VERSION_PATH = "./reworked_recoil/addon_version";
const YS_RR_CONFIG_PATH = "./reworked_recoil/config.ini";
// pettiness
const CROUCH_FLAG = 4;
const WALK_FLAG = 131072;
const LASER_UPGR = 4;

::YsReworkedRecoil <- {

  Config =
  {
    # Global
    pingThreshold = 50,
    enableSmoothing = true,
    rndSpreadFraction = 0.7,
    globalRecoilMult = 1.1,
    globalHorzMult = 1.4,
    walkMult = 0.8,
    crouchMult = 0.6,
    laserMult = 0.6,

    # Per-weapon
    "pistol"        :   {  baseRecoil = 0.65, horzBias = -0.15  },
    "pistol_magnum" :   {  baseRecoil = 2.15, horzBias = 0.2  },

    "smg"           :   {  baseRecoil = 1.15, horzBias = 0.01  },
    "smg_silenced"  :   {  baseRecoil = 0.15, horzBias = 0.01  },
    "smg_mp5"       :   {  baseRecoil = 1.75, horzBias = -0.25  },

    "pumpshotgun"   :   {  baseRecoil = -4.25, horzBias = 1.15  },
    "shotgun_chrome":   {  baseRecoil = 13.0, horzBias = -0.3  },
    "autoshotgun"   :   {  baseRecoil = 2.75, horzBias = 0.05  },
    "shotgun_spas"  :   {  baseRecoil = 0.05, horzBias = 0.01  },

    "rifle"         :   {  baseRecoil = 0.73, horzBias = -0.2  },
    "rifle_ak47"    :   {  baseRecoil = 1.26, horzBias = 0.2  },
    "rifle_desert"  :   {  baseRecoil = 0.32, horzBias = 0.65  },
    "rifle_sg552"   :   {  baseRecoil = -3.0, horzBias = 0.0  },

    "hunting_rifle" :   {  baseRecoil = 1.43, horzBias = -0.02  },
    "sniper_military":  {  baseRecoil = 0.69, horzBias = -0.05  },
    "sniper_awp"    :   {  baseRecoil = 14, horzBias = 0.07  },
    "sniper_scout"  :   {  baseRecoil = 6.5, horzBias = 0.05  },

    "grenade_launcher": {  baseRecoil = 16.0, horzBias = 0.0  },
    "rifle_m60"     :   {  baseRecoil = 2.0, horzBias = -0.70  },
  }

  playerQueue = {}, # for recoil
  cachedVars = {}, # key: weapon  value: list [0 = crouch, 1 = walk]
  playerManager = null, # for getting ping
  crouchState = {}, # [player] = bool — cache para suavizar transición crouch
  fastGuns = { // firerate < 0.1, except for m60
    "rifle"        :      0.1,
    "rifle_desert" :      0.035,
    "rifle_sg552"  :      0.1705,
    "smg"          :      0.070,
    "smg_mp5"      :      0.075,
    "smg_silenced" :      0.090,
    "rifle_m60"    :      0.20
  }

  /************************************************
  Main Logic
  *************************************************/

  function OnGameEvent_weapon_fire( params )
  {
    if( "userid" in params && "weapon" in params )
    {
      if( !(params.weapon in Config) )
        return;

      local player = GetPlayerFromUserID(params.userid);
      if( !player ) return;
      if( !playerManager )
        playerManager = Entities.FindByClassname(null, "terror_player_manager");

      if( player.IsSurvivor() && !IsPlayerABot(player) )
        {
          local iPing = NetProps.GetPropIntArray(playerManager, "m_iPing", player.GetEntityIndex());
          if( iPing > Config.pingThreshold)   return; // could probably try to add the ping value to DoEntFire? Maybe? But how?
          
          // Registrar timestamp del disparo REAL — el crouch workaround usa esto
          lastWeaponFireTime[player] <- Time()
          
          DoRecoilLogic( player, params.weapon );
        }
      }
  }

  // Rate-limit para el workaround de crouch
  lastRecoilTime = {}  // [player] = timestamp
  
  // Timestamp del último weapon_fire REAL por jugador
  // El crouch workaround solo aplica recoil si hubo un disparo real recientemente
  lastWeaponFireTime = {}  // [player] = timestamp

  function DoRecoilLogic( plr, wpn )
  {
    local x = 0.1;
    local y = 0.1;
    local recoil = GetRealRecoil(plr, wpn);
    local fracInt = Config.rndSpreadFraction * 100;

    x = -recoil - (recoil * RandomFloatFromInt(0, fracInt)); // vertical, needs to be negative
    y = recoil * Config[wpn].horzBias + (recoil * RandomFloatFromInt(-fracInt, fracInt)); // horizontal

    if( Config.enableSmoothing )
    {
      x *= (wpn in fastGuns) ? 0.33 : 0.25
      y *= (wpn in fastGuns) ? 0.33 : 0.25
      playerQueue[plr] <- { "targetAdd" : QAngle(x, y, 0), "cycles" : (wpn in fastGuns) ? 3 : 4 }
    }
    else {
      playerQueue[plr] <- { "targetAdd" : QAngle(x, y, 0), "cycles" : 1 };
    }
  }

  function UpdateRecoil()
  {
    foreach( player, value in playerQueue )
    {
      if( value["cycles"] > 0 )
      {
        value["cycles"]--;
        player.SnapEyeAngles(player.EyeAngles() + value["targetAdd"]);
      }
      // ── CROUCH WORKAROUND: engine interrumpe weapon_fire al agacharse ──
      // Solo re-disparar recoil si hubo un weapon_fire REAL recientemente.
      // Esto evita recoil fantasma cuando: sin munición, en cooldown, recargando, etc.
      else if (player.IsValid() && (player.GetButtonMask() & 1) != 0)
      {
        local now = Time()
        
        // Verificar que hubo un disparo real en los últimos 0.15s
        local hadRealFire = (player in lastWeaponFireTime) && 
                            (now - lastWeaponFireTime[player] < 0.15)
        
        if (hadRealFire && 
            (!(player in lastRecoilTime) || now - lastRecoilTime[player] > 0.08))
        {
          local weapon = player.GetActiveWeapon()
          if (weapon && weapon.IsValid())
          {
            local cls = weapon.GetClassname()
            if (cls.len() > 7 && cls.slice(0, 7) == "weapon_")
            {
              local wpn = cls.slice(7)
              if (wpn in Config)
              {
                DoRecoilLogic(player, wpn)
                lastRecoilTime[player] <- now
              }
            }
          }
        }
      }
    }
  }

  /************************************************
  Utils & others
  *************************************************/

  # An attempt at "better distribution"(?) of random values, they're randomized as ints and then converted back to floats
  function RandomFloatFromInt(lower, upper)
  {
    return (RandomInt(lower, upper)).tofloat() / 100;
  }

  function GetRealRecoil( plr, wpn )
  {
    local rtn = Config[wpn].baseRecoil;
    local isCrouching = (plr.GetButtonMask() & CROUCH_FLAG) > 0
    if( isCrouching )
      rtn = cachedVars[wpn][0];
    if( (plr.GetButtonMask() & WALK_FLAG) > 0 ) // is walking
      rtn = cachedVars[wpn][1];

    // ── CROUCH SMOOTH: suavizar transición pie↔agachado ──
    // Evita que el recoil salte bruscamente al agacharse/levantarse
    local prevCrouch = (plr in crouchState) ? crouchState[plr] : isCrouching
    crouchState[plr] <- isCrouching
    if (isCrouching != prevCrouch) {
      // Blend 50% viejo + 50% nuevo en el frame de transición
      local oldRecoil = isCrouching ? Config[wpn].baseRecoil : cachedVars[wpn][0]
      rtn = (rtn + oldRecoil) * 0.5
    }

    local bit = NetProps.GetPropInt(plr.GetActiveWeapon(), "m_upgradeBitVec");
    if( (bit & LASER_UPGR) != 0 ) // is lasering
      rtn *= Config.laserMult;

    return rtn;
  }

  function CreateThinker()
  {
		MaoLib.AddTimerForce("c_lerp_tick", 0.05, @() ::YsReworkedRecoil.UpdateRecoil())
  }

  function OnGameEvent_round_start( params )
  {
    CreateThinker();
  }
}

/************************************************
 Config handling
 ************************************************/
::RRConfigManager <- {

  ConfigRef = ::YsReworkedRecoil.Config,
  CacheRef = ::YsReworkedRecoil.cachedVars,

  function GetVersion()
  {
    local ver = FileToString(YS_RR_VERSION_PATH);
    if( !ver )
    {
      printl(">>> Reworked Recoil:  Version file not found, creating one");
      ver = YS_RR_VERSION;
      StringToFile(YS_RR_VERSION_PATH, ver);
    }

    return ver;
  }

  function WriteConfigs()
  {
    local ini = "[Global]\n";
    ini += "pingThreshold = 50\n";
    ini += "enableSmoothing = true\n";
    ini += "rndSpreadFraction = 0.5\n";
    ini += "globalRecoilMult = 1.0\n";
    ini += "globalHorzMult = 1.5\n";
    ini += "walkMult = 0.8\n";
    ini += "crouchMult = 0.6\n";
    ini += "laserMult = 0.6\n\n";
    foreach( k,v in ConfigRef )
    {
      if( typeof(v) != "table" )
        continue;
      ini += "["+k+"]\n";
      foreach(key,data in v)
      {
        ini += key + " = " + data + "\n";
      }
    }

    StringToFile(YS_RR_VERSION_PATH, YS_RR_VERSION); // updating cfg version
    StringToFile(YS_RR_CONFIG_PATH, ini);
    return ini;
  }

  function ReadConfigs()
  {
    local file = FileToString(YS_RR_CONFIG_PATH);
    if( file == null ) {
      printl(">>> Reworked Recoil:  Config file doesn't exist, creating a new one");
      file = WriteConfigs();
    }

    local block = "";
    foreach( value in split(file, "\n") )
    {
      try {
        if( value.find("[") == 0 ) {
          block = value.slice(1, value.find("]")).tolower();
          // printl(block);
          continue;
        }
        # Globals
        if( block == "global" )
        {
          local keyData = split(value, "=").map(@(x) strip(x));
          if( keyData[0].find("enable") == 0 ) {
            ConfigRef[keyData[0]] = (keyData[1] == "true") ? true : false;
            continue;
          }

          ConfigRef[keyData[0]] = keyData[1].tofloat();
        }
        # Per-weapon
        else {
          local keyData = split(value, "=").map(@(x) strip(x));
          if( keyData[0] == "baseRecoil" )
            ConfigRef[block][keyData[0]] = keyData[1].tofloat() * ConfigRef.globalRecoilMult;
          if( keyData[0] == "horzBias" )
            ConfigRef[block][keyData[0]] = keyData[1].tofloat() * ConfigRef.globalHorzMult;
        }
      } catch (e) {
        printl("Error while reading configs: " + e);
      }
    }
    CacheVars();
    DoConfigTreatment();
    printl(">>> Reworked Recoil:  Config file loaded successfully");
  }

  function CacheVars()
  {
    foreach( k,v in ConfigRef )
    {
      if( typeof(v) != "table" )
        continue;

      CacheRef[k] <- array(2);
      CacheRef[k][0] = v.baseRecoil * ConfigRef.crouchMult;
      CacheRef[k][1] = v.baseRecoil * ConfigRef.walkMult;
    }
    printl(">>> Reworked Recoil:  Cached multiplied recoil values");
    // printl("CROUCH: " + cachedVars["pistol_magnum"][0] + " WALK: " + cachedVars["pistol_magnum"][1]);
  }

  // some small safety stuff n troubleshooting
  function DoConfigTreatment()
  {
    foreach( identifier, data in ConfigRef )
    {
      if( identifier == "rndSpreadFraction" || identifier == "globalRecoilMult" || identifier == "globalHorzMult" )
      {
        if( data < 0 )
        {
          ClientPrint(null, 3  /* HUD_PRINTTALK */, "\x04== " + identifier + " in RR config file cannot be less than 0 - setting it to 0 ==");
          ConfigRef[identifier] == 0.0;
        }
        else if( data == 0 && identifier == "globalRecoilMult" ) {
          ClientPrint(null, 3  /* HUD_PRINTTALK */, "\x04== Warning: " + identifier + " in RR config file is 0 - this will nullify all recoil effects! ==");
        }
      }
    }
  }

  function OnGameEvent_player_say( params )
  {
    local author = GetPlayerFromUserID(params.userid);
    if( !author || !author.IsValid() || author != GetListenServerHost() )  return;

    if( params.text.find("rr!reload") == 0 )
    {
      ReadConfigs();
      ClientPrint(null, 3  /* HUD_PRINTTALK */, "\x04== Reloaded configs! Check console for any possible errors ==");
    }
  }

  function OnGameEvent_round_start( params )
  {
    if( GetVersion() != YS_RR_VERSION )
    {
      printl(">>> Reworked Recoil:  Config file is outdated, writing new one!");
      WriteConfigs();
      ReadConfigs();
    }
  }

 	function OnGameEvent_round_end(params) {
 		MaoLib.RemoveTimer("c_lerp_tick")
 		::YsReworkedRecoil.crouchState.clear()
 		::YsReworkedRecoil.lastRecoilTime.clear()
 		::YsReworkedRecoil.lastWeaponFireTime.clear()
 	}
}

__CollectGameEventCallbacks(::YsReworkedRecoil);
__CollectGameEventCallbacks(::RRConfigManager);