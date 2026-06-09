::flickerthewristgeeb <-
{
    // Variables de configuracion
    // DEBE coincidir con r_flashlightbrightness en director_base_addon.nut
    normal_brightness = 2.5,      // Intensidad normal (alto brillo, corto alcance)
    flicker_brightness = 0.5,     // Intensidad cuando parpadea (~20% del normal, visible pero no apaga)

    // Variables de control del sistema
    state = 0,                    // 0: Esperando, 1: Parpadeo 1 (bajo), 2: Parpadeo 1 (alto), 3: Parpadeo 2 (bajo), 4: Fin
    timer = 0,                    // Contador de tiempo interno

    // Nombre del timer para MaoLib
    _timerName = "l4c_flashlight_flicker",

    function UpdateFlicker()
    {
        if (state == 0)
        {
            // ESTADO 0: Esperando el momento de parpadear
            timer--;
            if (timer <= 0)
            {
                Convars.SetValue("r_flashlightbrightness", flicker_brightness);
                state = 1;
                timer = 2;
            }
        }
        else if (state == 1)
        {
            timer--;
            if (timer <= 0)
            {
                Convars.SetValue("r_flashlightbrightness", normal_brightness);
                state = 2;
                timer = 2;
            }
        }
        else if (state == 2)
        {
            timer--;
            if (timer <= 0)
            {
                Convars.SetValue("r_flashlightbrightness", flicker_brightness);
                state = 3;
                timer = 2;
            }
        }
        else if (state == 3)
        {
            timer--;
            if (timer <= 0)
            {
                Convars.SetValue("r_flashlightbrightness", normal_brightness);
                state = 0;
                timer = RandomInt(100, 300);
            }
        }
    }

    function StartFlicker()
    {
        timer = RandomInt(100, 300);
        MaoLib.AddTimerSafe(_timerName, 0.05, @() ::flickerthewristgeeb.UpdateFlicker());
    }

    function StopFlicker()
    {
        Convars.SetValue("r_flashlightbrightness", normal_brightness);
        state = 0;
        timer = 0;
        MaoLib.RemoveTimer(_timerName);
    }

    function OnGameEvent_round_start(params)
    {
        StartFlicker();
    }

    function OnGameEvent_round_end(params)
    {
        StopFlicker();
    }

    function OnGameEvent_map_transition(params)
    {
        StopFlicker();
    }

    function OnGameEvent_mission_lost(params)
    {
        StopFlicker();
    }
}

__CollectGameEventCallbacks(::flickerthewristgeeb);
