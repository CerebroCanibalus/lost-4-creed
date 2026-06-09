::SaveOptionsPills <- {

    // ──────── CONFIG FILE PATH ────────
    CONFIG_FILE = "sharepills_config.txt", // EDIT HERE --------------------- 🛑🛑
	
    // ──────── Create default config ────────
    function InitConfig() {
        local txt = "healRadius=100\n" +  // EDIT HERE --------------------- 🛑🛑
		            "tempHealth=5\n"; // EDIT HERE --------------------- 🛑🛑
        printl("[SaveOptionsPills] Creating default config at: " + ::SaveOptionsPills.CONFIG_FILE);
        StringToFile(::SaveOptionsPills.CONFIG_FILE, txt);
        printl("[SaveOptionsPills] Default config written:\n" + txt);
        return txt;
    },

    // ──────── Load config ────────
    function LoadConfig() {
        printl("[SaveOptionsPills] Attempting to load config from: " + ::SaveOptionsPills.CONFIG_FILE);
        local txt = FileToString(::SaveOptionsPills.CONFIG_FILE);

        if (txt == null) {
            printl("[SaveOptionsPills] Config file not found, initializing default config.");
            txt = ::SaveOptionsPills.InitConfig();
        } else {
            printl("[SaveOptionsPills] Config loaded:\n" + txt);
        }

        foreach (line in split(txt, "\n")) {
            if (line.len() < 1) continue;

            local kv = split(line, "=");
            if (kv.len() != 2) {
                printl("[SaveOptionsPills] Skipping invalid line: " + line);
                continue;
            }

            local key = strip(kv[0]);
            local val = strip(kv[1]);
            local parsedValue;

            if (val == "true") {
                parsedValue = true;
            } else if (val == "false") {
                parsedValue = false;
            } else {
                parsedValue = val.tointeger();
            }

            if (key == "healRadius") { // EDIT HERE --------------------- 🛑🛑
                ::PillsHealNearby.healRadius = parsedValue; // EDIT HERE --------------------- 🛑🛑
                printl("[SaveOptionsPills] Loaded healRadius: " + ::PillsHealNearby.healRadius); // EDIT HERE --------------------- 🛑🛑
            } else if (key == "tempHealth") {  // EDIT HERE --------------------- 🛑🛑
                ::PillsHealNearby.tempHealth = parsedValue;  // EDIT HERE --------------------- 🛑🛑
                printl("[SaveOptionsPills] Loaded tempHealth: " + ::PillsHealNearby.tempHealth);  // EDIT HERE --------------------- 🛑🛑
            } else {
                printl("[SaveOptionsPills] Unknown key: " + key);
            }
        }
    },

    // ──────── Save Config ────────
    function SaveConfig() {
        local out = "healRadius=" + ::PillsHealNearby.healRadius + "\n" + // EDIT HERE --------------------- 🛑🛑
                    "tempHealth=" + ::PillsHealNearby.tempHealth + "\n";  // EDIT HERE --------------------- 🛑🛑
        printl("[SaveOptionsPills] Saving config to: " + ::SaveOptionsPills.CONFIG_FILE);
        printl("[SaveOptionsPills] Data being saved:\n" + out);
        StringToFile(::SaveOptionsPills.CONFIG_FILE, out);
    },
};