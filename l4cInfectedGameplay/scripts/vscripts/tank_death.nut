/**
 * Tank Death Spectacle
 * 
 * Consolidated from: tank_death_spectacle.nut
 * 
 * Epic arcade-style death sequence for the Tank:
 * - Progressive blood explosions during fall
 * - Massive screen shake
 * - Flying gibs (brains, heart, steaks) with explosive velocity
 * - Blood decals on ground
 * - Sequential death sounds
 * - Shockwave that damages and pushes nearby infected
 */

// Gore models
local GoreModels = {
	brains = [
		"models/infected/limbs/brain_01.mdl",
		"models/infected/limbs/brain_02.mdl",
		"models/infected/limbs/brain_03.mdl"
	],
	heart = "models/infected/limbs/heart_veins.mdl",
	steaks = [
		"models/infected/limbs/steak1.mdl",
		"models/infected/limbs/steak2.mdl",
		"models/infected/limbs/steak3.mdl"
	],
	ribs = [
		"models/infected/limbs/rib1.mdl",
		"models/infected/limbs/rib2.mdl"
	],
	intestines = "models/infected/limbs/intestine1.mdl"
}

// Particles
local BloodParticles = {
	impact = [
		"blood_impact_tank_01",
		"blood_impact_red_01",
		"blood_impact_headshot_01"
	],
	arterial = [
		"gore_wound_arterial_spray_1",
		"gore_wound_arterial_spray_2",
		"gore_wound_arterial_spray_3"
	],
	brain = "gore_wound_brain",
	explosion = [
		"boomer_explode",
		"weapon_grenade_explosion"
	],
	sparks = "impact_spark_spray_large",
	smoke = "weapon_grenade_smoke"
}

// Sounds
local DeathSounds = {
	scream = "player/tank/voice/die/tank_death_scream_01.wav",
	bodyfall = "player/tank/fall/tank_death_bodyfall_01.wav",
	explode = "weapons/hegrenade/explode5.wav",
	launcher = "weapons/grenade_launcher/grenade_launcher_explode_1.wav",
	crunch = "player/tank/hit/tank_punch_1.wav",
	splash = "player/boomer/explode.wav"
}

// Dying tanks tracker
::g_DyingTanks <- {}

// Active tank tracker — para detectar muerte incluso si player_death falla
::g_TankDeath_ActiveTanks <- {}

// Precache assets
function PrecacheTankDeathAssets()
{
	foreach (brain in GoreModels.brains)
	{
		try { PrecacheModel(brain); } catch(e) {}
	}
	try { PrecacheModel(GoreModels.heart); } catch(e) {}
	foreach (steak in GoreModels.steaks)
	{
		try { PrecacheModel(steak); } catch(e) {}
	}
	foreach (rib in GoreModels.ribs)
	{
		try { PrecacheModel(rib); } catch(e) {}
	}
	try { PrecacheModel(GoreModels.intestines); } catch(e) {}
	
	foreach (sound in DeathSounds)
	{
		try { PrecacheSound(sound); } catch(e) {}
	}
}

// NOTA: gore_system.nut también dispara partículas para Tank (AttachTankGoreParticles).
// El overlap es esperado — tank_death maneja secuencia coreográfica, gore_system da
// impacto adicional de sangre. gore_system tiene sus partículas reducidas (2-3) para
// no sobrecargar.

// ========== MAIN EVENT ==========
::TankDeathSpectacle <-
{
	/** 0 = silencioso, 1 = verboso */
	Debug = 1
	
	function Dbg(msg) {
		if (Debug) printl("[TankDeath][DEBUG] " + msg)
	}
	
	function OnGameEvent_player_spawn(params)
	{
		if (!("userid" in params)) return
		local player = GetPlayerFromUserID(params.userid)
		if (!player || !player.IsValid() || !player.IsPlayer()) return
		
		local zType = 0
		try { zType = player.GetZombieType() } catch(e) {}
		if (zType == 8) {
			local idx = player.entindex()
			::g_TankDeath_ActiveTanks[idx] <- true
			Dbg("Tank #" + idx + " tracked on spawn")
		}
	}
	
	function OnGameEvent_player_death(params)
	{
		Dbg("ENTER player_death")
		if (!("userid" in params))
			{ Dbg("ABORT: no userid"); return; }
		
		local victim = GetPlayerFromUserID(params.userid);
		if (!victim || !victim.IsValid())
			{ Dbg("ABORT: victim invalid"); return; }
		
		local isTank = false
		local tankId = victim.entindex()
		
		// Método 1: GetZombieType()
		try {
			if (victim.GetZombieType() == 8) isTank = true
		} catch(e) {}
		
		// Método 2: NetProp fallback
		if (!isTank) {
			try {
				if (NetProps.GetPropInt(victim, "m_zombieClass") == 8) isTank = true
			} catch(e) {}
		}
		
		// Método 3: Tracker fallback
		if (!isTank && tankId in ::g_TankDeath_ActiveTanks) {
			isTank = true
		}
		
		if (!isTank) {
			Dbg("ABORT: not tank (entidx=" + tankId + ")")
			return
		}
		
		delete ::g_TankDeath_ActiveTanks[tankId]
		
		local pos = victim.GetOrigin();
		local angles = victim.EyeAngles();
		
		::g_DyingTanks[tankId] <- {
			pos = pos,
			angles = angles,
			startTime = Time(),
			stage = 0
		};
		Dbg("Tank #" + tankId + " registered. g_DyingTanks count=" + ::g_DyingTanks.len())
		
		StartTankDeathSequence(pos, angles, tankId);
	}
	
	function OnGameEvent_tank_killed(params)
	{
		Dbg("ENTER tank_killed")
		// tank_killed no tiene victim ID. Usamos el tracker de tanks activos.
		foreach (tankId, _ in ::g_TankDeath_ActiveTanks) {
			local tank = EntIndexToHScript(tankId)
			if (!tank || !tank.IsValid() || NetProps.GetPropInt(tank, "m_lifeState") != 0) {
				// Este tank ya no está vivo — es el que murió
				delete ::g_TankDeath_ActiveTanks[tankId]
				
				local pos = (tank && tank.IsValid()) ? tank.GetOrigin() : Vector(0,0,0)
				local angles = (tank && tank.IsValid()) ? tank.EyeAngles() : Vector(0,0,0)
				
				::g_DyingTanks[tankId] <- {
					pos = pos,
					angles = angles,
					startTime = Time(),
					stage = 0
				};
				Dbg("Tank #" + tankId + " registered via tank_killed")
				StartTankDeathSequence(pos, angles, tankId);
				return
			}
		}
		Dbg("tank_killed: no tracked tank found")
	}
	
	function OnGameEvent_round_end(params)
	{
		Dbg("ENTER round_end — clearing all dying tanks")
		::g_DyingTanks.clear()
		::g_TankDeath_ActiveTanks.clear()
	}
	
	function OnGameEvent_mission_lost(params)
	{
		Dbg("ENTER mission_lost — clearing all dying tanks")
		::g_DyingTanks.clear()
		::g_TankDeath_ActiveTanks.clear()
	}
	
	function OnGameEvent_map_transition(params)
	{
		Dbg("ENTER map_transition — clearing all dying tanks")
		::g_DyingTanks.clear()
		::g_TankDeath_ActiveTanks.clear()
	}
}

// ========== DEATH SEQUENCE ==========
// ⚠️ Usa MaoLib.DelayCall() — ejecución DIFERIDA ONE-SHOT, NO recurrente.
//    Antes usaba MaoLib.AddTimer() que es RECURRENTE → partículas/sonidos/shake INFINITOS.
//    DelayCall internamente usa AddTimer + auto-RemoveTimer en el primer fire.
function StartTankDeathSequence(pos, angles, tankId)
{
	local deathPos = pos;
	local deathAngles = angles;
	
	::TankDeathSpectacle.Dbg("StartTankDeathSequence for tank #" + tankId + " at " + deathPos)
	
	// T+0.0s - First hemorrhage + scream
	SpawnBloodExplosion(deathPos, "impact", 1);
	PlayDeathSound(deathPos, "scream", 1.0);
	
	// T+0.3s - Arterial spray #1
	MaoLib.DelayCall(function() {
		SpawnBloodExplosion(deathPos, "arterial", 1);
		SpawnBloodExplosion(deathPos, "impact", 1);
	}, 0.3);
	
	// T+0.6s - Blood explosion + sparks
	MaoLib.DelayCall(function() {
		SpawnBloodExplosion(deathPos, "explosion", 1);
		SpawnParticle(deathPos, BloodParticles.sparks, 2.0);
		PlayDeathSound(deathPos, "crunch", 0.8);
	}, 0.6);
	
	// T+0.9s - Arterial spray #2 + splash
	MaoLib.DelayCall(function() {
		SpawnBloodExplosion(deathPos, "arterial", 2);
		SpawnBloodExplosion(deathPos, "impact", 1);
		PlayDeathSound(deathPos, "splash", 0.6);
	}, 0.9);
	
	// T+1.2s - Massive blood impact + smoke
	MaoLib.DelayCall(function() {
		SpawnBloodExplosion(deathPos, "impact", 2);
		SpawnBloodExplosion(deathPos, "explosion", 1);
		SpawnParticle(deathPos, BloodParticles.smoke, 3.0);
	}, 1.2);
	
	// T+1.5s - Arterial spray #3 + brain matter
	MaoLib.DelayCall(function() {
		SpawnBloodExplosion(deathPos, "arterial", 2);
		SpawnParticle(deathPos + Vector(0, 0, 40), BloodParticles.brain, 2.0);
		PlayDeathSound(deathPos, "crunch", 0.7);
	}, 1.5);
	
	// T+1.8s - Pre-explosion
	MaoLib.DelayCall(function() {
		SpawnBloodExplosion(deathPos, "explosion", 2);
		SpawnBloodExplosion(deathPos, "impact", 2);
		SpawnParticle(deathPos, BloodParticles.sparks, 1.5);
	}, 1.8);
	
	// T+2.2s - FINAL EXPLOSION
	MaoLib.DelayCall(function() {
		FinalExplosion(deathPos, deathAngles);
	}, 2.2);
	
	// T+2.8s - Blood decals + shockwave
	MaoLib.DelayCall(function() {
		SpawnBloodDecals(deathPos);
		ShockwaveDamage(deathPos);
		PlayDeathSound(deathPos, "bodyfall", 1.0);
	}, 2.8);
	
	// Cleanup after 5 seconds — sweep all expired tanks from g_DyingTanks
	MaoLib.DelayCall(function() {
		foreach (id, data in ::g_DyingTanks)
		{
			if ((Time() - data.startTime) > 5.0)
			{
				::TankDeathSpectacle.Dbg("Cleanup: removing tank #" + id + " from g_DyingTanks")
				delete ::g_DyingTanks[id];
			}
		}
		::TankDeathSpectacle.Dbg("Cleanup done. g_DyingTanks remaining: " + ::g_DyingTanks.len())
	}, 5.0);
}

// ========== HELPERS ==========
function SpawnBloodExplosion(origin, particleType, count)
{
	local particles = null;
	
	if (particleType == "impact")
		particles = BloodParticles.impact;
	else if (particleType == "arterial")
		particles = BloodParticles.arterial;
	else if (particleType == "explosion")
		particles = BloodParticles.explosion;
	else
		return;
	
	for (local i = 0; i < count; i++)
	{
		local offset = Vector(
			RandomFloat(-60, 60),
			RandomFloat(-60, 60),
			RandomFloat(0, 100)
		);
		
		local particleName = particles[RandomInt(0, particles.len() - 1)];
		SpawnParticle(origin + offset, particleName, 3.0);
	}
}

function SpawnParticle(origin, particleName, lifetime)
{
	local particle = SpawnEntityFromTable("info_particle_system", {
		origin = origin,
		effect_name = particleName
	});
	
	if (particle && particle.IsValid())
	{
		DoEntFire("!self", "Start", "", 0.0, null, particle);
		
		// Stop antes de Kill para evitar residuos de partículas looping
		local stopTime = lifetime - 0.3;
		if (stopTime > 0)
			DoEntFire("!self", "Stop", "", stopTime, null, particle);
		
		DoEntFire("!self", "Kill", "", lifetime, null, particle);
	}
}

function PlayDeathSound(origin, soundType, volume)
{
	local sound = null;
	if (soundType in DeathSounds)
		sound = DeathSounds[soundType];
	
	if (!sound)
		return;
	
	local soundEnt = SpawnEntityFromTable("ambient_generic", {
		origin = origin,
		message = sound,
		health = (volume * 10).tointeger(),
		spawnflags = 16,
		radius = 1500
	});
	
	if (soundEnt && soundEnt.IsValid())
	{
		DoEntFire("!self", "PlaySound", "", 0.0, null, soundEnt);
		DoEntFire("!self", "Kill", "", 5.0, null, soundEnt);
	}
}

function FinalExplosion(pos, angles)
{
	// Screen shake
	local shake = SpawnEntityFromTable("env_shake", {
		origin = pos,
		amplitude = 20,
		duration = 3.0,
		frequency = 60,
		radius = 2000
	});
	if (shake && shake.IsValid())
	{
		DoEntFire("!self", "StartShake", "", 0, null, shake);
		DoEntFire("!self", "Kill", "", 3.5, null, shake);
	}
	
	// Blood explosions
	for (local i = 0; i < 8; i++)
	{
		local offset = Vector(
			RandomFloat(-100, 100),
			RandomFloat(-100, 100),
			RandomFloat(0, 150)
		);
		SpawnParticle(pos + offset, BloodParticles.explosion[RandomInt(0, BloodParticles.explosion.len() - 1)], 4.0);
	}
	
	// Sparks
	SpawnParticle(pos, BloodParticles.sparks, 2.0);
	SpawnParticle(pos + Vector(0, 0, 50), BloodParticles.sparks, 2.0);
	
	// Smoke
	SpawnParticle(pos, BloodParticles.smoke, 5.0);
	
	// Sounds
	PlayDeathSound(pos, "explode", 1.0);
	PlayDeathSound(pos, "launcher", 0.8);
	
	// Flying gibs
	SpawnTankGibs(pos);
	
	// Ground blood
	for (local i = 0; i < 5; i++)
	{
		local groundPos = pos + Vector(RandomFloat(-80, 80), RandomFloat(-80, 80), 10);
		SpawnParticle(groundPos, "blood_impact_red_01", 2.0);
	}
}

function SpawnTankGibs(origin)
{
	local gibCount = RandomInt(14, 18);
	local allGibs = [];
	
	// Always include special organs
	allGibs.append(GoreModels.brains[RandomInt(0, GoreModels.brains.len() - 1)]);
	allGibs.append(GoreModels.heart);
	allGibs.append(GoreModels.intestines);
	
	foreach (rib in GoreModels.ribs)
		allGibs.append(rib);
	
	for (local i = allGibs.len(); i < gibCount; i++)
	{
		allGibs.append(GoreModels.steaks[RandomInt(0, GoreModels.steaks.len() - 1)]);
	}
	
	for (local i = 0; i < allGibs.len(); i++)
	{
		local gib = SpawnEntityFromTable("prop_physics", {
			origin = origin + Vector(
				RandomFloat(-30, 30),
				RandomFloat(-30, 30),
				RandomFloat(30, 90)
			),
			model = allGibs[i],
			spawnflags = 4,
			physicsmode = 2
		});
		
		if (gib && gib.IsValid())
		{
			local velocity = Vector(
				RandomFloat(-600, 600),
				RandomFloat(-600, 600),
				RandomFloat(300, 1000)
			);
			
			NetProps.SetPropVector(gib, "m_vecVelocity", velocity);
			
			local angular = Vector(
				RandomFloat(-300, 300),
				RandomFloat(-300, 300),
				RandomFloat(-300, 300)
			);
			NetProps.SetPropVector(gib, "m_vecAngVelocity", angular);
			
			local lifetime = RandomFloat(10.0, 15.0);
			DoEntFire("!self", "Kill", "", lifetime, null, gib);
		}
	}
}

function SpawnBloodDecals(origin)
{
	local textures = [
		"decals/blood_splatter",
		"decals/blood_streak",
		"decals/blood_splat3",
		"decals/blood_splat4"
	];
	
	for (local i = 0; i < 12; i++)
	{
		local offset = Vector(
			RandomFloat(-200, 200),
			RandomFloat(-200, 200),
			0
		);
		
		local decal = SpawnEntityFromTable("infodecal", {
			origin = origin + offset,
			texture = textures[RandomInt(0, textures.len() - 1)]
		});
		
		if (decal && decal.IsValid())
		{
			DoEntFire("!self", "Activate", "", 0.0, null, decal);
			DoEntFire("!self", "Kill", "", 45.0, null, decal);
		}
	}
}

function ShockwaveDamage(origin)
{
	// Push and damage common infected
	local infected = null;
	while (infected = Entities.FindByClassnameWithin(infected, "infected", origin, 500))
	{
		if (MaoLib.IsReal(infected))
		{
			local away = infected.GetOrigin() - origin;
			away.Norm();
			away.z = 0.4;
			
			NetProps.SetPropVector(infected, "m_vecVelocity", away * RandomFloat(400, 800));
			
			TakeDamageEx(
				infected,
				infected,
				null,
				away * 500,
				origin,
				RandomInt(30, 80),
				1
			);
		}
	}
	
	// Push survivors (no damage, just effect)
	local survivor = null;
	while (survivor = Entities.FindByClassnameWithin(survivor, "player", origin, 400))
	{
		if (MaoLib.IsReal(survivor) && survivor.IsSurvivor())
		{
			local away = survivor.GetOrigin() - origin;
			away.Norm();
			away.z = 0.2;
			
			NetProps.SetPropVector(survivor, "m_vecVelocity", away * RandomFloat(100, 200));
		}
	}
}

// ========== INIT ==========
PrecacheTankDeathAssets();
__CollectGameEventCallbacks(::TankDeathSpectacle);

printl("=================================");
printl("Tank Death Spectacle Loaded");
printl("=================================");