printl("Audio Hitmarker for specials");

// ==============================
// Settings System
// ==============================

Settings <-
{
    function exist(key, arr)
    {
        local len=arr.len();
        for(local i=0;i<len;i++) if(arr[i]==key) return true;
        return false;
    }
    function dumpSettings(path, settings, ignore=[])
    {
        local data="";
        foreach(key, val in settings) if(!exist(key, ignore))
            data=data+key+" = "+val+"\n";
        StringToFile(path, data);
    }
    function loadSettings(path, settings, logfile = null, allkeys = false)
    {
        local data;
        if(data = FileToString(path))
        {
            try
            {
                data=compilestring("return {" + data + "}")();
                foreach(key, val in data) if(allkeys||(key in settings))
                    settings[key] <- val;
            }
            catch(exception)
            {
                error("Error: unable to read settings from "+path+"\n");
                if(logfile!=null)
                {
                    local report = "Error: unable to read settings from " +path+ "\n";
                    report = report + "Traceback:\n\n" + exception.tostring();
                    StringToFile(report,logfile);
                }
            }
            return true;
        }
        else return false;
    }
    function easyRead(name, settings, ignore = [], allkeys = false)
    {
        local settings_path = name + "/settings.cfg";
        local error_log_path = name + "/error.log";
        if(!loadSettings(settings_path, settings, error_log_path, allkeys))
            dumpSettings(settings_path, settings, ignore);
    }
}



// ==============================
// Configurable Variables
// ==============================

::hitMarkerVars<-{
    playSound = true,
    soundFix = true,
    commonFeedback = false,	// if you want to hear hitting the commons too
    botFeedback = false
}



// ==============================
// Hitmarker Core
// ==============================

::hitMarker<-
{
    State =
    {
        bX = 0,
        bY = 0,
        bZ = 0,
        bAttacker = 0,
        fired = []
    }

    function HandlePlayerFirstSpawn(params)
    {
        if(GetPlayerFromUserID(params.userid).IsSurvivor()) State.fired.clear();
    }

    function HandlePlayerTransitioned(params)
    {
        if(GetPlayerFromUserID(params.userid).IsSurvivor()) State.fired.clear();
    }

    function HandleWeaponFire(params)
    {
        local player=GetPlayerFromUserID(params.userid);
        if(State.fired.find(player)==null) State.fired.append(player);
    }

    function HandlePlayerDeath(params)
    {
        local attacker = GetPlayerFromUserID(params.attacker);
        if(params.victimname == "Infected")
        {
            if(::hitMarkerVars.commonFeedback) playSound(attacker, null, 2);
            return;
        }
        if(IsPlayerABot(attacker)) return;
        playSound(attacker, null, 2);
    }

    function HandleBulletImpact(params)
    {
        State.bX = params.x;
        State.bY = params.y;
        State.bZ = params.z;
        State.bAttacker = GetPlayerFromUserID(params.userid);
    }

    function HandlePlayerHurt(params)
    {
        local attacker = null;
        if("attackerentid" in params) attacker = EntIndexToHScript(params.attackerentid);
        else if("attacker" in params) attacker = GetPlayerFromUserID(params.attacker);

        if(attacker==null) return;
        if(!::hitMarkerVars.botFeedback && attacker.GetClassname() == "player" && IsPlayerABot(attacker)) return;

        local victim = GetPlayerFromUserID(params.userid);
        if(NetProps.GetPropIntArray(victim, "m_iTeamNum", 0) != 2)
        {
            playSound(attacker, victim, params.type);
        }
    }

    function HandleInfectedHurt(params)
    {
        local tgvictim = EntIndexToHScript(params.entityid);
        local attacker = GetPlayerFromUserID(params.attacker);
        if(!::hitMarkerVars.botFeedback && IsPlayerABot(attacker)) return;

        if(tgvictim.GetClassname() == "witch")
        {
            playSound(attacker,tgvictim,params.type);
        }
        else if(tgvictim.GetClassname() == "infected")
        {
            if(!::hitMarkerVars.commonFeedback) return;
            playSound(attacker,tgvictim,params.type);
        }
    }

    function playSound(tgplayer, tgvictim, wtype)
    {
        if(!::hitMarkerVars.playSound) return;
        if((wtype&2)!=2 && wtype != 128 && wtype != 67108864) return;
        if(tgplayer==null||!tgplayer.IsSurvivor()||IsPlayerABot(tgplayer)) return;

        if(::hitMarkerVars.soundFix)
        {
            local len=State.fired.len();
            local chk=false;
            for(local i=len-1;i>=0;i--) if(State.fired[i]==tgplayer)
            {
                State.fired.remove(i); chk=true;
            }
            if(!chk) return;
        }
        EmitSoundOnClient("Coach_Blank", tgplayer);
        State.bX = 0; State.bY = 0; State.bZ = 0;
    }
}

Settings.easyRead("hitmarker", ::hitMarkerVars, []);

function ::hitMarker::OnGameEvent_player_first_spawn(params) { ::hitMarker.HandlePlayerFirstSpawn(params); }
function ::hitMarker::OnGameEvent_player_transitioned(params) { ::hitMarker.HandlePlayerTransitioned(params); }
function ::hitMarker::OnGameEvent_weapon_fire(params) { ::hitMarker.HandleWeaponFire(params); }
function ::hitMarker::OnGameEvent_player_death(params) { ::hitMarker.HandlePlayerDeath(params); }
function ::hitMarker::OnGameEvent_bullet_impact(params) { ::hitMarker.HandleBulletImpact(params); }
function ::hitMarker::OnGameEvent_player_hurt(params) { ::hitMarker.HandlePlayerHurt(params); }
function ::hitMarker::OnGameEvent_infected_hurt(params) { ::hitMarker.HandleInfectedHurt(params); }
__CollectGameEventCallbacks(::hitMarker);
