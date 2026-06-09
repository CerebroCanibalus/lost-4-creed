::WoundFeedback <-
{
	WoundTime = {}
	Ent_BuckShot = null
	
	function HurtVictim(Victim, Damage, DamageType, Attacker)
	{
		Victim = EntIndexToHScript(Victim);
		Attacker = EntIndexToHScript(Attacker);
		if (Victim && Attacker)
		{
			if (NetProps.GetPropInt(Victim, "m_lifeState") == 0)
			{
				Victim.TakeDamage(Damage, DamageType, Attacker);
			}
		}
	}
	
	function OnGameEvent_round_start_post_nav(params)
	{
		if (!Ent_BuckShot)
		Ent_BuckShot = SpawnEntityFromTable
		(
			"func_timescale",
			{
				origin = Vector(0,0,0),
				angles = Vector(0,0,0),
				desiredTimescale = 1.0,
				acceleration = 1.0,
				minBlendRate = 1.0,
				blendDeltaMultiplier = 1.0,
			}
		);
	}
	
	function OnGameEvent_bullet_impact(params)
	{
		local Infected = Entities.FindByClassnameNearest("infected", Vector(params.x, params.y, params.z), 0.0);
		if (!Infected)
			return;
		if (NetProps.GetPropInt(Infected, "m_lifeState") != 0)
			Infected.TakeDamage(0, (1 << 25), Infected);
	}
	
	function OnGameEvent_infected_hurt(params)
	{
		HandleInfectedHurt(params);
	}

	function HandleInfectedHurt(params)
	{
		local Infected = EntIndexToHScript(params.entityid);
		if (Infected.GetClassname() == "witch" || params.amount == 0)
			return;
		if ("attacker" in params)
		{
			local Attacker = GetPlayerFromUserID(params.attacker);
			if (!Attacker)
				return;
			if (!Attacker.IsSurvivor())
				return;
			local Gender = NetProps.GetPropInt(Infected, "m_Gender");
			if (Gender == 17)
				return;
			local Damage = params.amount;
			local Health = Infected.GetHealth();
			local RH = Health - Damage;
			local HH = Infected.GetMaxHealth() * 0.5 + 1;
			local DamageType = params.type;
			local HitGroup = params.hitgroup;
			//printl("Health: " + Health + "; ");
			//printl("HitGroup: " + HitGroup + "; ");
			//Infected.SetHealth(Health - 1);
			if (RH > 1 && !(DamageType & (1 << 3)) && !(DamageType & (1 << 6)) && HitGroup != 1)
			{
				if (NetProps.GetPropInt(Infected, "m_iRequestedWound2") != -1)
					NetProps.SetPropInt(Infected, "m_iRequestedWound2", -1);
				if (RH > HH)
				{
					if (NetProps.GetPropInt(Infected, "m_iRequestedWound1") != -1)
						NetProps.SetPropInt(Infected, "m_iRequestedWound1", -1);
				}
				else if (!(Infected in WoundTime))
				{
					local Wound1 = NetProps.GetPropInt(Infected, "m_iRequestedWound1");
					local NewWound1 = Wound1;
					switch (Gender)
					{
						case 0:case 1:case 12:case 13:case 14:case 16:case 20:case 21:
						{
							switch (Wound1)
							{
								case -1:
									switch (HitGroup)
									{
										case 2:
											if (DamageType == -2147483646 || DamageType == -1610612734) // -2147483646步枪伤害类型 -1610612734霰弹枪伤害类型
												NewWound1 = 7;
										break;
										case 3:
											if (DamageType == -2147483646 || DamageType == -1610612734)
												NewWound1 = 26;
										break;
										case 4:	NewWound1 = 19;	break;
										case 5:	NewWound1 = 13;	break;
									}
								break;
								case 10:	NewWound1 = 18;	break;
								case 11:	NewWound1 = 12;	break;
							}
						break;
						}
						case 2:case 22:
						{
							switch (Wound1)
							{
								case -1:
									switch (HitGroup)
									{
										case 2:
											if (DamageType == -2147483646 || DamageType == -1610612734) // -2147483646步枪伤害类型 -1610612734霰弹枪伤害类型
												NewWound1 = 7;
										break;
										case 3:
											if (DamageType == -2147483646 || DamageType == -1610612734)
												NewWound1 = 25;
										break;
										case 4:	NewWound1 = 18;	break;
										case 5:	NewWound1 = 12;	break;
									}
								break;
								case 9:	NewWound1 = 17;	break;
								case 10:	NewWound1 = 11;	break;
							}
						break;
						}
						case 11:
						{
							switch (Wound1)
							{
								case -1:
									switch (HitGroup)
									{
										case 4:	NewWound1 = 7;	break;
										case 5:	NewWound1 = 3;	break;
									}
								break;
							}
						break;
						}
					}
					if (NewWound1 != Wound1)
						NetProps.SetPropInt(Infected, "m_iRequestedWound1", NewWound1);
					if (NewWound1 != -1)
					{
						WoundTime[Infected] <- Time();
						local AOri = Attacker.EyePosition(); 
						local IOri = Infected.GetOrigin(); 
						local Location = IOri + (AOri - IOri) * (200 / (AOri - IOri).Length());
						//printl((IOri - Location).Length());
						Ent_BuckShot.SetOrigin(Location);
						Infected.TakeDamage(0, (1 << 29), Ent_BuckShot);
					}
				}
			}
			else
			{
				if (RH == 1)
					Infected.SetHealth(Damage);
				if (!(Infected in WoundTime))
				{
					local Wound1 = NetProps.GetPropInt(Infected, "m_iRequestedWound1");
					local NewWound1 = Wound1;
					switch (Gender)
					{
						case 0:case 1:case 12:case 13:case 16:case 20:case 21:
						{
							switch (Wound1)
							{
								case -1:
									switch (HitGroup)
									{
										case 1:
											switch (RandomInt(1,2))
											{
												case 1:
													NewWound1 = 6;
												break;
												case 2:
													NewWound1 = 8;
												break;
											}
										break;
										case 2:
											if (DamageType == -2147483646 || DamageType == -1610612734)
												NewWound1 = 0;
										break;
										case 3:
											if (DamageType == -2147483646 || DamageType == -1610612734)
												NewWound1 = 26;
										break;
										case 4:	NewWound1 = 19;	break;
										case 5:	NewWound1 = 13;	break;
										case 6:	NewWound1 = 21;	break;
										case 7:	NewWound1 = 17;	break;
									}
								break;
								case 10:	NewWound1 = 18;	break;
								case 11:	NewWound1 = 12;	break;
								case 14:	NewWound1 = 20;	break;
								case 15:	NewWound1 = 16;	break;
								case 41:
									if (DamageType & (1 << 7))
									{
										switch (RandomInt(0,1))
										{
											case 1:
												NewWound1 = 8;
											break;
										}
									}
								break;
							}
						break;
						}
						case 14:
						{
							switch (Wound1)
							{
								case -1:
									switch (HitGroup)
									{
										case 1:
											if (RH <= 1)
											{
												switch (RandomInt(1,2))
												{
													case 1:
														NewWound1 = 6;
													break;
													case 2:
														NewWound1 = 8;
													break;
												}
											}
										break;
										case 2:
											if (DamageType == -2147483646 || DamageType == -1610612734)
												NewWound1 = 0;
										break;
										case 3:
											if (DamageType == -2147483646 || DamageType == -1610612734)
												NewWound1 = 26;
										break;
										case 4:	NewWound1 = 19;	break;
										case 5:	NewWound1 = 13;	break;
										case 6:	NewWound1 = 21;	break;
										case 7:	NewWound1 = 17;	break;
									}
								break;
								case 10:	NewWound1 = 18;	break;
								case 11:	NewWound1 = 12;	break;
								case 14:	NewWound1 = 20;	break;
								case 15:	NewWound1 = 16;	break;
								case 41:
									if (DamageType & (1 << 7))
									{
										switch (RandomInt(0,1))
										{
											case 1:
												NewWound1 = 8;
											break;
										}
									}
								break;
							}
						break;
						}
						case 2:case 22:
						{
							switch (Wound1)
							{
								case -1:
									switch (HitGroup)
									{
										case 1:
											switch (RandomInt(1,2))
											{
												case 1:
													NewWound1 = 6;
												break;
												case 2:
													NewWound1 = 8;
												break;
											}
										break;
										case 2:
											if (DamageType == -2147483646 || DamageType == -1610612734) // -2147483646步枪伤害类型 -1610612734霰弹枪伤害类型
												NewWound1 = 0;
										break;
										case 3:
											if (DamageType == -2147483646 || DamageType == -1610612734)
												NewWound1 = 25;
										break;
										case 4:	NewWound1 = 18;	break;
										case 5:	NewWound1 = 12;	break;
										case 6:	NewWound1 = 20;	break;
										case 7:	NewWound1 = 16;	break;
									}
								break;
								case 9:	NewWound1 = 17;	break;
								case 10:	NewWound1 = 11;	break;
								case 13:	NewWound1 = 19;	break;
								case 14:	NewWound1 = 15;	break;
								case 41:
									if (DamageType & (1 << 7))
									{
										switch (RandomInt(0,1))
										{
											case 1:
												NewWound1 = 8;
											break;
										}
									}
								break;
							}
						break;
						}
						case 11:
						{
							switch (Wound1)
							{
								case -1:
									switch (HitGroup)
									{
										case 1:	NewWound1 = 0;	break;
										case 4:	NewWound1 = 7;	break;
										case 5:	NewWound1 = 3;	break;
										case 6:	NewWound1 = 9;	break;
										case 7:	NewWound1 = 5;	break;
									}
								break;
							}
						break;
						}
					}
					if (NewWound1 != -1)
					{
						WoundTime[Infected] <- Time();
						if (NewWound1 != Wound1)
							NetProps.SetPropInt(Infected, "m_iRequestedWound1", NewWound1);
					}
				}
				else
				{
					if (HitGroup == 1)
					{
						//if (Gender != 14 && Time() - WoundTime[Infected] < 4)
						if (Gender != 14)
						{
							Infected.SetHealth(Damage);
						}
					}
					local Wound1 = NetProps.GetPropInt(Infected, "m_iRequestedWound1");
					local Wound2 = NetProps.GetPropInt(Infected, "m_iRequestedWound2");
					local NewWound2 = Wound2;
					switch (Gender)
					{
						case 0:case 1:case 12:case 13:case 16:case 20:case 21:
						{
							switch (Wound2)
							{
								case -1:
									switch (HitGroup)
									{
										case 1:
											if (Wound1 != 6 && Wound1 != 8 && Wound1 != 41)
											{
												switch (RandomInt(1,2))
												{
													case 1:
														NewWound2 = 6;
													break;
													case 2:
														NewWound2 = 8;
													break;
												}
											}
										break;
										case 2:
											if (DamageType == -2147483646 || DamageType == -1610612734) // -2147483646步枪伤害类型 -1610612734霰弹枪伤害类型
											{
												if (Wound1 != 0 && Wound1 != 4)
													NewWound2 = 0;
											}
										break;
										case 3:
											if (DamageType == -2147483646 || DamageType == -1610612734)
											{
												if (Wound1 != 1 && Wound1 != 2 && Wound1 != 3 && Wound1 != 4 && Wound1 != 5 && Wound1 != 26)
													NewWound2 = 26;
											}
										break;
										case 4:
											if (Wound1 != 10 && Wound1 != 18 && Wound1 != 19)
												NewWound2 = 19;
										break;
										case 5:
											if (Wound1 != 11 && Wound1 != 12 && Wound1 != 13)
												NewWound2 = 13;
										break;
										case 6:
											if (Wound1 != 14 && Wound1 != 20 && Wound1 != 21)
												NewWound2 = 21;
										break;
										case 7:
											if (Wound1 != 15 && Wound1 != 16 && Wound1 != 17)
												NewWound2 = 17;
										break;
									}
								break;
								case 10:	NewWound2 = 18;	break;
								case 11:	NewWound2 = 12;	break;
								case 14:	NewWound2 = 20;	break;
								case 15:	NewWound2 = 16;	break;
								case 41:
									if (DamageType & (1 << 7))
									{
										switch (RandomInt(1,3))
										{
											case 1:
												NewWound2 = 6;
											break;
											case 2:
												NewWound2 = 8;
											break;
										}
									}
								break;
							}
						break;
						}
						case 14:
						{
							switch (Wound2)
							{
								case -1:
									switch (HitGroup)
									{
										case 1:
											if (RH <= 1)
											{
												if (Wound1 != 6 && Wound1 != 8 && Wound1 != 41)
												{
													switch (RandomInt(1,2))
													{
														case 1:
															NewWound2 = 6;
														break;
														case 2:
															NewWound2 = 8;
														break;
													}
												}
											}
										break;
										case 2:
											if (DamageType == -2147483646 || DamageType == -1610612734) // -2147483646步枪伤害类型 -1610612734霰弹枪伤害类型
											{
												if (Wound1 != 0 && Wound1 != 4)
													NewWound2 = 0;
											}
										break;
										case 3:
											if (DamageType == -2147483646 || DamageType == -1610612734)
											{
												if (Wound1 != 1 && Wound1 != 2 && Wound1 != 3 && Wound1 != 4 && Wound1 != 5 && Wound1 != 26)
													NewWound2 = 26;
											}
										break;
										case 4:
											if (Wound1 != 10 && Wound1 != 18 && Wound1 != 19)
												NewWound2 = 19;
										break;
										case 5:
											if (Wound1 != 11 && Wound1 != 12 && Wound1 != 13)
												NewWound2 = 13;
										break;
										case 6:
											if (Wound1 != 14 && Wound1 != 20 && Wound1 != 21)
												NewWound2 = 21;
										break;
										case 7:
											if (Wound1 != 15 && Wound1 != 16 && Wound1 != 17)
												NewWound2 = 17;
										break;
									}
								break;
								case 10:	NewWound2 = 18;	break;
								case 11:	NewWound2 = 12;	break;
								case 14:	NewWound2 = 20;	break;
								case 15:	NewWound2 = 16;	break;
								case 41:
									if (DamageType & (1 << 7))
									{
										switch (RandomInt(0,1))
										{
											case 1:
												NewWound2 = 8;
											break;
										}
									}
								break;
							}
						break;
						}
						case 2:case 22:
						{
							switch (Wound2)
							{
								case -1:
									switch (HitGroup)
									{
										case 1:
											if (Wound1 != 6 && Wound1 != 8 && Wound1 != 40 && Wound1 != 41)
											{
												switch (RandomInt(1,2))
												{
													case 1:
														NewWound2 = 6;
													break;
													case 2:
														NewWound2 = 8;
													break;
												}
											}
										break;
										case 2:
											if (DamageType == -2147483646 || DamageType == -1610612734) // -2147483646步枪伤害类型 -1610612734霰弹枪伤害类型
											{
												if (Wound1 != 0 && Wound1 != 4)
													NewWound2 = 0;
											}
										break;
										case 3:
											if (DamageType == -2147483646 || DamageType == -1610612734)
											{
												if (Wound1 != 1 && Wound1 != 2 && Wound1 != 3 && Wound1 != 4 && Wound1 != 5 && Wound1 != 25)
													NewWound2 = 25;
											}
										case 4:
											if (Wound1 != 9 && Wound1 != 17 && Wound1 != 18)
												NewWound2 = 18;
										break;
										case 5:
											if (Wound1 != 10 && Wound1 != 11 && Wound1 != 12)
												NewWound2 = 12;
										break;
										case 6:
											if (Wound1 != 13 && Wound1 != 19 && Wound1 != 20)
												NewWound2 = 20;
										break;
										case 7:
											if (Wound1 != 14 && Wound1 != 15 && Wound1 != 16)
												NewWound2 = 16;
										break;
									}
								break;
								case 9:	NewWound2 = 17;	break;
								case 10:	NewWound2 = 11;	break;
								case 13:	NewWound2 = 19;	break;
								case 14:	NewWound2 = 15;	break;
								case 41:
									if (DamageType & (1 << 7))
									{
										switch (RandomInt(0,1))
										{
											case 1:
												NewWound2 = 8;
											break;
										}
									}
								break;
							}
						break;
						}
						case 11:
						{
							switch (Wound2)
							{
								case -1:
									switch (HitGroup)
									{
										case 1:
											if (Wound1 != 0)
												NewWound2 = 0;
										break;
										case 4:
											if (Wound1 != 6 && Wound1 != 7)
												NewWound2 = 7;
										break;
										case 5:
											if (Wound1 != 2 && Wound1 != 3)
												NewWound2 = 3;
										break;
										case 6:
											if (Wound1 != 8 && Wound1 != 9)
												NewWound2 = 9;
										break;
										case 7:
											if (Wound1 != 4 && Wound1 != 5)
												NewWound2 = 5;
										break;
									}
								break;
							}
						break;
						}
					}
					if (NewWound2 != Wound2)
						NetProps.SetPropInt(Infected, "m_iRequestedWound2", NewWound2);
				}
			}
		}
	}

	function OnGameEvent_round_end(params) {
		if (Ent_BuckShot && Ent_BuckShot.IsValid()) {
			Ent_BuckShot.Kill()
			Ent_BuckShot = null
		}
	}
}
__CollectGameEventCallbacks(::WoundFeedback);

/*========================================================================================================================
						local AA = Attacker.GetAngles().y;
						local IA = Infected.GetAngles().y;
						if (AA < 0)
							AA += 360;
						if (IA < 0)
							IA += 360;
						local AD = fabs(AA - IA);
						local IV = Infected.GetVelocity();
						if (AD > 90 && AD < 180 || sqrt(pow(IV.x, 2) + pow(IV.y, 2) + pow(IV.z, 2)) > 50)
						{
							EntFire("worldspawn", "RunScriptCode", "::WoundFeedback.HurtVictim(" + Infected.GetEntityIndex().tostring() + "," + 0 + "," + (1 << 25) + "," + Attacker.GetEntityIndex().tostring() + ")", 0.01, null);
						}
========================================================================================================================*/