#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

new bool:bHooked = false;

new Handle:cvar_siSlowdown;

public Plugin:myinfo = {
    name        = "L4D2 Remove Special Infected Slowdown",
    author      = "Jahze",
    version     = "1.0",
    description = "Removes the slow down from special infected"
};

public OnPluginStart() {
    cvar_siSlowdown = CreateConVar("l4d_si_slowdown", "1", "Enables/disables removal of the slow down that weapons to do special infected", FCVAR_PLUGIN);
    HookConVarChange(cvar_siSlowdown, SiSlowdownChange);
    
    PluginEnable();
}

public OnPluginEnd() {
    PluginDisable();
}

PluginEnable() {
    if ( !bHooked ) {
        HookEvent("player_hurt", SiSlowdown);
        bHooked = true;
    }
}

PluginDisable() {
    if ( bHooked ) {
        UnhookEvent("player_hurt", SiSlowdown);
        bHooked = false;
    }
}

public SiSlowdownChange( Handle:cvar, const String:oldValue[], const String:newValue[] ) {
    if ( StringToInt(newValue) == 0 ) {
        PluginDisable();
    }
    else {
        PluginEnable();
    }
}

public Action:SiSlowdown( Handle:event, const String:name[], bool:dontBroadcast ) {
    new victim = GetClientOfUserId(GetEventInt(event, "userid"));
    
    if ( IsClientConnected(victim) && IsClientInGame(victim) && GetClientTeam(victim) == 3 ) {
        SetEntPropFloat(victim, Prop_Send, "m_flVelocityModifier", 1.0);
    }
}


