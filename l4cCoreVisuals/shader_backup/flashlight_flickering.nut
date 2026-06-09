flickerthewristgeeb <-
{
    // Variables de configuracion
    normal_brightness = 0.6       // Intensidad normal de la linterna (aumentado para modpack oscuro)
    flicker_brightness = 0.15     // Intensidad cuando parpadea (no poner 0 para no cegar)
    
    // Variables de control del sistema
    state = 0                     // 0: Esperando, 1: Parpadeo 1 (bajo), 2: Parpadeo 1 (alto), 3: Parpadeo 2 (bajo), 4: Fin
    timer = 0                     // Contador de tiempo interno

    function UpdateFlicker()
    {
        // La funcion corre cada 0.05 segundos (definido en el logic_timer)
        
        if (state == 0)
        {
            // ESTADO 0: Esperando el momento de parpadear
            timer--;
            if (timer <= 0)
            {
                // Iniciar secuencia de parpadeo (Bajar intensidad)
                Convars.SetValue( "r_flashlightbrightness", flicker_brightness );
                state = 1;
                timer = 2; // Duración del bajón (2 ticks = 0.10 segundos)
            }
        }
        else if (state == 1)
        {
            // ESTADO 1: Primer bajon terminado, subir luz brevemente
            timer--;
            if (timer <= 0)
            {
                Convars.SetValue( "r_flashlightbrightness", normal_brightness );
                state = 2;
                timer = 2; // Tiempo que mantiene la luz alta entre parpadeos (0.10 segundos)
            }
        }
        else if (state == 2)
        {
            // ESTADO 2: Segundo bajon de inmediato
            timer--;
            if (timer <= 0)
            {
                Convars.SetValue( "r_flashlightbrightness", flicker_brightness );
                state = 3;
                timer = 2; // Duracion del segundo bajon (0.10 segundos)
            }
        }
        else if (state == 3)
        {
            // ESTADO 3: Restaurar luz normal y entrar en espera larga
            timer--;
            if (timer <= 0)
            {
                Convars.SetValue( "r_flashlightbrightness", normal_brightness );
                state = 0;
                // Esperar aleatoriamente entre 5 y 15 segundos para el próximo evento
                // 100 ticks = 5 segundos, 300 ticks = 15 segundos
                timer = RandomInt(100, 300); 
            }
        }
    }

    function OnGameEvent_round_start(params) 
    {
        // Inicializar el temporizador de espera al empezar
        timer = RandomInt(100, 300); 
        
        // temporizador logico que ejecuta la funcion cada 0.05s
        SpawnEntityFromTable("logic_timer", 
        { 
            RefireTime = 0.05, 
            OnTimer = "!caller,runscriptcode,DirectorScript.flickerthewristgeeb.UpdateFlicker()" 
        });
    }
}

__CollectGameEventCallbacks(flickerthewristgeeb);
