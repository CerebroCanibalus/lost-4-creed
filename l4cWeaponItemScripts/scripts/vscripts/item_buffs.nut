// item_buffs.nut — Equipment Passive Effects v2.0
// Reanimado: Timer central con MaoLib.AddTimer (reemplaza AddThinkToEnt)
//
// Efectos:
//   Medkit:     +1 HP permanente AoE cada 10s (radio 110)
//   Gnome:      +1-20 munición cada 10s + Adrenalina AoE cada 60s (radio 100)
//   Pills:      +5 temp HP AoE cada 15s (radio 88)
//   Adrenaline: +3 HP permanente AoE cada 35s (radio 121)

if ("g_ItemBuffs_init_guard" in getroottable()) return;
getroottable()["g_ItemBuffs_init_guard"] <- true;

::g_ItemBuffs <- {
	VERSION = "2.0"

	// ============================================================
	// CONFIG
	// ============================================================
	Config = {
		ENABLED = true,
		// Intervals (seconds)
		MEDKIT_INTERVAL = 10.0,
		GNOME_AMMO_INTERVAL = 10.0,
		GNOME_ADREN_INTERVAL = 60.0,
		PILLS_INTERVAL = 15.0,
		ADRENALINE_INTERVAL = 35.0,
		// Radii
		MEDKIT_RADIUS = 110,
		GNOME_RADIUS = 100,
		PILLS_RADIUS = 88,
		ADRENALINE_RADIUS = 121,
		// Gnome ammo
		GNOME_AMMO_MIN = 1,
		GNOME_AMMO_MAX = 20,
		// Adrenaline duration (seconds)
		GNOME_ADREN_DURATION = 5.0,
	},

	// Last apply time per player per item type
	// LastApply[userid][itemType] = timestamp
	LastApply = {},

	function Dbg(msg) { printl("[ItemBuffs] " + msg) }

	// ============================================================
	// TIMER CENTRAL — 1.0s tick
	// ============================================================
	function Think() {
		if (!Config.ENABLED) return

		foreach (s in ::MaoLib.YieldSurvivors()) {
			if (!::MaoLib.IsAlive(s)) continue
			local uid = s.GetPlayerUserId()
			if (!(uid in LastApply)) LastApply[uid] <- {}

			local now = Time()
			CheckMedkit(s, uid, now)
			CheckGnome(s, uid, now)
			CheckPills(s, uid, now)
			CheckAdrenaline(s, uid, now)
		}
	}

	// ============================================================
	// HELPERS
	// ============================================================
	function HasItem(player, className) {
		if (!player || !player.IsValid()) return false
		local item = null
		while (item = Entities.FindByClassname(item, className)) {
			if (item.GetOwnerEntity() == player) return true
		}
		return false
	}

	function GetLast(uid, itemType) {
		if (!(uid in LastApply) || !(itemType in LastApply[uid])) return -9999
		return LastApply[uid][itemType]
	}

	function SetLast(uid, itemType, time) {
		if (!(uid in LastApply)) LastApply[uid] <- {}
		LastApply[uid][itemType] <- time
	}

	function ForEachSurvivorInRadius(origin, radius, callback) {
		foreach (s in ::MaoLib.YieldSurvivors()) {
			if (!::MaoLib.IsAlive(s)) continue
			if (::MaoLib.DistanceBetween(origin, s) <= radius) {
				callback(s)
			}
		}
	}

	// ============================================================
	// MEDKIT — +1 HP permanente AoE cada 10s
	// ============================================================
	function CheckMedkit(survivor, uid, now) {
		if (!HasItem(survivor, "weapon_first_aid_kit")) return
		if (now - GetLast(uid, "medkit") < Config.MEDKIT_INTERVAL) return
		SetLast(uid, "medkit", now)

		local origin = survivor.GetOrigin()
		ForEachSurvivorInRadius(origin, Config.MEDKIT_RADIUS, function(target) {
			if (target.GetHealth() < NetProps.GetPropInt(target, "m_iMaxHealth")) {
				target.SetHealth(target.GetHealth() + 1)
			}
		})
	}

	// ============================================================
	// GNOME — Munición + Adrenalina AoE
	// ============================================================
	function CheckGnome(survivor, uid, now) {
		if (!HasItem(survivor, "weapon_gnome")) return

		// Munición cada 10s
		if (now - GetLast(uid, "gnome_ammo") >= Config.GNOME_AMMO_INTERVAL) {
			SetLast(uid, "gnome_ammo", now)
			survivor.GiveAmmo(RandomInt(Config.GNOME_AMMO_MIN, Config.GNOME_AMMO_MAX))
		}

		// Adrenalina AoE cada 60s
		if (now - GetLast(uid, "gnome_adren") >= Config.GNOME_ADREN_INTERVAL) {
			SetLast(uid, "gnome_adren", now)
			local origin = survivor.GetOrigin()
			ForEachSurvivorInRadius(origin, Config.GNOME_RADIUS, function(target) {
				target.UseAdrenaline(Config.GNOME_ADREN_DURATION)
			})
		}
	}

	// ============================================================
	// PILLS — +5 temp HP AoE cada 15s
	// ============================================================
	function CheckPills(survivor, uid, now) {
		if (!HasItem(survivor, "weapon_pain_pills")) return
		if (now - GetLast(uid, "pills") < Config.PILLS_INTERVAL) return
		SetLast(uid, "pills", now)

		local origin = survivor.GetOrigin()
		ForEachSurvivorInRadius(origin, Config.PILLS_RADIUS, function(target) {
			local maxHp = NetProps.GetPropInt(target, "m_iMaxHealth")
			if ((target.GetHealth() + target.GetHealthBuffer()) < maxHp) {
				target.SetHealthBuffer(target.GetHealthBuffer() + 5)
			}
		})
	}

	// ============================================================
	// ADRENALINE — +3 HP permanente AoE cada 35s
	// ============================================================
	function CheckAdrenaline(survivor, uid, now) {
		if (!HasItem(survivor, "weapon_adrenaline")) return
		if (now - GetLast(uid, "adrenaline") < Config.ADRENALINE_INTERVAL) return
		SetLast(uid, "adrenaline", now)

		local origin = survivor.GetOrigin()
		ForEachSurvivorInRadius(origin, Config.ADRENALINE_RADIUS, function(target) {
			if (target.GetHealth() < NetProps.GetPropInt(target, "m_iMaxHealth")) {
				target.SetHealth(target.GetHealth() + 3)
			}
		})
	}

	// ============================================================
	// CLEANUP
	// ============================================================
	function OnGameEvent_round_end(params) {
		LastApply = {}
		::MaoLib.RemoveTimer("itembuffs_think")
	}

	function OnGameEvent_mission_lost(params) {
		LastApply = {}
		::MaoLib.RemoveTimer("itembuffs_think")
	}

	function OnGameEvent_map_transition(params) {
		LastApply = {}
		::MaoLib.RemoveTimer("itembuffs_think")
	}

	function OnGameEvent_player_disconnect(params) {
		if ("userid" in params && params.userid in LastApply) {
			delete LastApply[params.userid]
		}
	}
}

// ============================================================
// INIT
// ============================================================
::MaoLib.AddTimer("itembuffs_think", 1.0, function() {
	::g_ItemBuffs.Think()
})

::g_ItemBuffs.Events <- {
	function OnGameEvent_round_end(e) { ::g_ItemBuffs.OnGameEvent_round_end(e) }
	function OnGameEvent_mission_lost(e) { ::g_ItemBuffs.OnGameEvent_mission_lost(e) }
	function OnGameEvent_map_transition(e) { ::g_ItemBuffs.OnGameEvent_map_transition(e) }
	function OnGameEvent_player_disconnect(e) { ::g_ItemBuffs.OnGameEvent_player_disconnect(e) }
}
__CollectGameEventCallbacks(::g_ItemBuffs.Events)

printl("[ItemBuffs] v" + ::g_ItemBuffs.VERSION + " loaded — Timer-based (no AddThinkToEnt)")
printl("[ItemBuffs] ENABLED=" + ::g_ItemBuffs.Config.ENABLED)
