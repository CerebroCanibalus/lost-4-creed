// ———— Flags ————
getroottable()["TIMER_REPEAT"] <- 1;
getroottable()["TIMER_NO_REPLACE"] <- 2;
getroottable()["TIMER_RESTART"] <- 4;


::ZPoision <- {

    Strikes = {},

    // ———— Timer System ————
    SetTimer = function(name, delay, func, params = null, flags = 0) {
        local ent = Entities.FindByName(null, name);
        if (ent && ent.ValidateScriptScope()) {
            local scope = ent.GetScriptScope();
            if ((flags & TIMER_RESTART) != 0) ent.Kill();
            else if ((flags & TIMER_NO_REPLACE) != 0) return null;
        }

        local thinker = SpawnEntityFromTable("info_target", { targetname = name });
        if (!thinker.ValidateScriptScope()) return null;

        local scope = thinker.GetScriptScope();
        scope.lasttime <- Time();
        scope.delay <- delay;
        scope.func <- func;
        scope.params <- params;
        scope.flags <- flags;

        scope.Think <- function() {
            local now = Time();
            if ((now - lasttime) >= delay) {
                local ret = params == null ? func() : func(params);
                if (ret && (flags & TIMER_REPEAT)) {
                    lasttime = now;
                    return delay;
                } else {
                    self.Kill();
                }
            }
            return 0.01;
        };

        AddThinkToEnt(thinker, "Think");
        return thinker;
    },

    RemoveTimer = function(name) {
        local ent = Entities.FindByName(null, name);
        if (ent && ent.IsValid()) {
            ent.Kill();
            return true;
        }
        return false;
    },

    // ———— Poison ————
    ApplyPoison = function(player, ticks = 3) {
        local pid = player.GetEntityIndex();
        if (pid in ::ZPoision.Strikes) return;

        ::ZPoision.Strikes[pid] <- ticks;

        local timerName = "Poison_Timer_" + pid;
        ::ZPoision.SetTimer(timerName, 1.0, function() {
            if (!player.IsValid() || NetProps.GetPropInt(player, "m_lifeState") != 0) {
                ::ZPoision.RemoveTimer(timerName);
                ::ZPoision.Strikes.rawdelete(pid);
                return false;
            }

            local hp = player.GetHealth();
            if (hp > 1) player.SetHealth(hp - 1);

            ::ZPoision.Strikes[pid] -= 1;
            if (::ZPoision.Strikes[pid] <= 0) {
                ::ZPoision.RemoveTimer(timerName);
                ::ZPoision.Strikes.rawdelete(pid);
                return false;
            }

            return true;
        }, null, TIMER_REPEAT | TIMER_RESTART);
    },

    // ———— Game Event ————
    OnGameEvent_player_hurt = function(params) {
        local player = GetPlayerFromUserID(params.userid);
        if (player && player.IsValid() && player.IsSurvivor()) {
            ::ZPoision.ApplyPoison(player);
        }
    }
};

__CollectEventCallbacks(ZPoision, "OnGameEvent_", "GameEventCallbacks", RegisterScriptGameEventListener);