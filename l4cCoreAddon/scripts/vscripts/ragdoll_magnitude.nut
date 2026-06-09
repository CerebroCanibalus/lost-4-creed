printl("Loading ragdoll tweaks")

local config_directory = "RagdollTweaks";
local config_path = config_directory + "/config.txt";
local force_magnitude = 1.75;

function EnsureConfigDirectory() {
    if (!FileToString(config_path)) {
        StringToFile(config_path, "{force_magnitude = 1.5}");
    }
}
EnsureConfigDirectory();

function LoadConfig() {
    local config_data = FileToString(config_path);
    if (config_data) {
        try {
            local parsed = MaoLib.ParseConfigString(config_data);
            if ("force_magnitude" in parsed) {
                force_magnitude = parsed["force_magnitude"];
            }
        } catch (err) {
            Msg("Ragdoll tweaks missing/invalid config.. Resetting to default");
            StringToFile(config_path, "{force_magnitude = 1.75}");
        }
    } else {
        StringToFile(config_path, "{force_magnitude = 1.75}");
    }
}
LoadConfig();

Convars.SetValue("phys_ragdoll_force_magnitude", force_magnitude.tostring());
Convars.SetValue("phys2_ragdoll_drive_type", "3");
printl("Loaded ragdoll tweaks");
