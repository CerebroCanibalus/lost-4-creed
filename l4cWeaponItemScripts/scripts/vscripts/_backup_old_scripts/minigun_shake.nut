
L4D1MinigunShake <-
{
	function OnGameEvent_weapon_fire( params )
	{
		local player = GetPlayerFromUserID( params.userid )
		if ( !player )
			return

		if ( NetProps.GetPropInt( player, "m_usingMountedWeapon" ) != 1 )
			return

		local minigun = NetProps.GetPropEntity( player, "m_hUseEntity" )
		if ( !minigun || minigun.GetClassname() != "prop_minigun_l4d1" )
			return

		// Screen shake via MaoLib_VFX (optimized, no manual entity spawn)
		MaoLib_VFX.ScreenShake(
			minigun.GetOrigin(),
			Settings.amplitude,
			Settings.frequency,
			Settings.duration,
			Settings.radius
		)
	}

	Settings = 
	{
		amplitude = 2,
		radius = 100,
		duration = 0.3,
		frequency = 40,
	}

	function ParseSettings()
	{
		local SettingsFileName = "l4d1_minigun_shake/Settings.cfg"
		local file = FileToString(SettingsFileName)

		local tData;
		local function SerializeSettings() {
			local sData = "{"
			foreach (key, val in Settings) {
				if (typeof(val) == "string") {
					val = "\"" + val + "\""
				} else if (typeof(val) == "array") {
					local newValue = "["
					for (local i = 0; i < val.len(); i++) {
						if (typeof(val[i]) == "string") {
							newValue += "\"" + val[i] + "\""
						} else {
							newValue += val[i].tostring()
						}
						if (i < val.len() - 1) {
							newValue += ", "
						}
					}
					newValue += "]"
					val = newValue
				}
				sData += "\n\t" + key + " = " + val
			}
			sData += "\n}"
			StringToFile(SettingsFileName, sData)
		}
		if (tData = file){
			try {
				tData = compilestring("return " + tData)()
				local hasMissingKey = false
				foreach (key, val in Settings){
					if (key in tData){
						Settings[key] = tData[key]
					}
					else if (!hasMissingKey){
						hasMissingKey = true 
					}
				}
				if (hasMissingKey)
				{ SerializeSettings() }
			}
			catch (error) {
				SerializeSettings()
			}
		}
		else{
			SerializeSettings();
		}

		local fullString = "https://developer.valvesoftware.com/wiki/Env_shake#Keyvalues \nYou're smart, you can figure it out."

		local InfoFileName = "l4d1_minigun_shake/info.txt"
		local file = StringToFile( InfoFileName, fullString )
	}
}
__CollectGameEventCallbacks( L4D1MinigunShake )
L4D1MinigunShake.ParseSettings()
