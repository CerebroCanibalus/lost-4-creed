::g_ItemBuffs <- {
    MedicPickupLimit = 0
    ItemBuffMode = 0

    function IsAvailableEntity(kent)
    {
        if(kent)
        {
            return true;
        }
        return false;
    }

    function OnGameEvent_item_pickup(event)
    {
        HandleItemPickup(event);
    }

    function HandleItemPickup(event)
{
    local pickeditem = null;
    if(("item" in event))
    {
        pickeditem = event["item"];
        
    }
    local kent = null;
    if(("userid" in event))
    {
        kent = GetPlayerFromUserID(event.userid);
        
    }
    if(kent.IsSurvivor())
    {
        // ---------------------------------------------------------
        // MEDKIT
        // Radio: 110 (10% mayor que el base 100 del gnomo)
        // Frecuencia: 10 segundos
        // ---------------------------------------------------------
        if(pickeditem == "first_aid_kit")
        {
            for(local owneditem; owneditem = Entities.FindByClassname(owneditem, "weapon_" + pickeditem); )
            {
                if(owneditem.GetOwnerEntity() == kent)
                {
                    if(owneditem.ValidateScriptScope())
                    {
                        local entity_entityscript = owneditem.GetScriptScope();
                        entity_entityscript["MedkitThink"] <- function()
                        {
                            if(self.GetOwnerEntity() != null)
                            {
                                local owner = self.GetOwnerEntity();
                                // Busca jugadores cercanos en un radio de 110
                                for(local survivor; survivor = Entities.FindByClassname(survivor, "player"); )
                                {
                                    if(survivor.IsSurvivor() && NetProps.GetPropInt(survivor, "m_lifeState") == 0 && !survivor.IsIncapacitated())
                                    {
                                        if((owner.GetOrigin() - survivor.GetOrigin()).Length() <= 110)
                                        {
                                            // Cura 1 de vida permanente
                                            if(survivor.GetHealth() < NetProps.GetPropInt(survivor, "m_iMaxHealth"))
                                            {
                                                survivor.SetHealth(survivor.GetHealth() + 1);
                                            }
                                        }
                                    }
                                }
                            }
                            return 10.0;
                        }
                    }
                    AddThinkToEnt(owneditem, "MedkitThink");
                    printl("Added 'THINKER' to " + owneditem);
                }
            }
        }
        // ---------------------------------------------------------
        // GNOME
        // Efecto Adrenaline AoE cada 60s
        // Munición aleatoria (1-20) al portador cada 10s
        // Otros efectos eliminados
        // ---------------------------------------------------------
        else if(pickeditem == "gnome")
        {
            for(local owneditem; owneditem = Entities.FindByClassname(owneditem, "weapon_" + pickeditem); )
            {
                if(owneditem.GetOwnerEntity() == kent)
                {
                    if(owneditem.ValidateScriptScope())
                    {
                        local entity_entityscript = owneditem.GetScriptScope();
                        // Variables para controlar el tiempo
                        entity_entityscript["LastAmmoTime"] <- Time();
                        entity_entityscript["LastAdrenTime"] <- Time();

                        entity_entityscript["GnomeThink"] <- function()
                        {
                            if(self.GetOwnerEntity() != null)
                            {
                                local owner = self.GetOwnerEntity();
                                local currentTime = Time();
                                local scriptScope = self.GetScriptScope();

                                // Munición aleatoria cada 10 segundos
                                if(currentTime - scriptScope.LastAmmoTime >= 10.0)
                                {
                                    if(NetProps.GetPropInt(owner, "m_lifeState") == 0 && !owner.IsIncapacitated())
                                    {
                                        owner.GiveAmmo(RandomInt(1,20));
                                    }
                                    scriptScope.LastAmmoTime = currentTime;
                                }

                                // Efecto Adrenaline en área cada 60 segundos
                                if(currentTime - scriptScope.LastAdrenTime >= 60.0)
                                {
                                    if(NetProps.GetPropInt(owner, "m_lifeState") == 0 && !owner.IsIncapacitated())
                                    {
                                        // Busca jugadores cercanos (Radio base del gnome 100)
                                        for(local survivor; survivor = Entities.FindByClassname(survivor, "player"); )
                                        {
                                            if(survivor.IsSurvivor() && NetProps.GetPropInt(survivor, "m_lifeState") == 0 && !survivor.IsIncapacitated())
                                            {
                                                if((owner.GetOrigin() - survivor.GetOrigin()).Length() <= 100)
                                                {
                                                    // Aplica efecto de adrenalina
                                                    survivor.UseAdrenaline(5); // 5 es la duración estándar aprox o el efecto
                                                }
                                            }
                                        }
                                    }
                                    scriptScope.LastAdrenTime = currentTime;
                                }
                            }
                            return 1.0; // Chequeo rápido para manejar los timers internos
                        }
                    }
                    AddThinkToEnt(owneditem, "GnomeThink");
                    printl("Added 'THINKER' to " + owneditem);
                }
            }
        }
        // ---------------------------------------------------------
        // PILLS
        // Radio: 88 (20% menor que el medkit 110)
        // Frecuencia: 15 segundos
        // ---------------------------------------------------------
        else if(pickeditem == "pain_pills")
        {
            for(local owneditem; owneditem = Entities.FindByClassname(owneditem, "weapon_" + pickeditem); )
            {
                if(owneditem.GetOwnerEntity() == kent)
                {
                    if(owneditem.ValidateScriptScope())
                    {
                        local entity_entityscript = owneditem.GetScriptScope();
                        entity_entityscript["PillsThink"] <- function()
                        {
                            if(self.GetOwnerEntity() != null)
                            {
                                local owner = self.GetOwnerEntity();
                                // Busca jugadores en radio 88
                                for(local survivor; survivor = Entities.FindByClassname(survivor, "player"); )
                                {
                                    if(survivor.IsSurvivor() && NetProps.GetPropInt(survivor, "m_lifeState") == 0 && !survivor.IsIncapacitated())
                                    {
                                        if((owner.GetOrigin() - survivor.GetOrigin()).Length() <= 88)
                                        {
                                            // Cura vida temporal
                                            if((survivor.GetHealth() + survivor.GetHealthBuffer()) < NetProps.GetPropInt(survivor, "m_iMaxHealth"))
                                            {
                                                survivor.SetHealthBuffer(survivor.GetHealthBuffer() + 5); // Un poco más de cantidad para que sea útil cada 15s
                                            }
                                        }
                                    }
                                }
                            }
                            return 15.0;
                        }
                    }
                    AddThinkToEnt(owneditem, "PillsThink");
                    printl("Added 'THINKER' to " + owneditem);
                }
            }
        }
        // ---------------------------------------------------------
        // ADRENALINE
        // Radio: 121 (10% mayor que el medkit 110)
        // Frecuencia: 35 segundos
        // Efecto: +3 puntos de vida permanente
        // ---------------------------------------------------------
        else if(pickeditem == "adrenaline")
        {
            for(local owneditem; owneditem = Entities.FindByClassname(owneditem, "weapon_" + pickeditem); )
            {
                if(owneditem.GetOwnerEntity() == kent)
                {
                    if(owneditem.ValidateScriptScope())
                    {
                        local entity_entityscript = owneditem.GetScriptScope();
                        entity_entityscript["AdrenalineThink"] <- function()
                        {
                            if(self.GetOwnerEntity() != null)
                            {
                                local owner = self.GetOwnerEntity();
                                // Busca jugadores en radio 121
                                for(local survivor; survivor = Entities.FindByClassname(survivor, "player"); )
                                {
                                    if(survivor.IsSurvivor() && NetProps.GetPropInt(survivor, "m_lifeState") == 0 && !survivor.IsIncapacitated())
                                    {
                                        if((owner.GetOrigin() - survivor.GetOrigin()).Length() <= 121)
                                        {
                                            // +3 Vida permanente
                                            if(survivor.GetHealth() < NetProps.GetPropInt(survivor, "m_iMaxHealth"))
                                            {
                                                survivor.SetHealth(survivor.GetHealth() + 3);
                                            }
                                        }
                                    }
                                }
                            }
                            return 35.0;
                        }
                    }
                    AddThinkToEnt(owneditem, "AdrenalineThink");
                    printl("Added 'THINKER' to " + owneditem);
                }
            }
        }
        
    }

    function OnGameEvent_round_start_post_nav(event)
    {
        HandleRoundStartPostNav(event);
    }

    function HandleRoundStartPostNav(event)
    {
        printl("ITEM BUFFS WORKING");
    }
}

__CollectGameEventCallbacks(::g_ItemBuffs);