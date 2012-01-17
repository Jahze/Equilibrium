#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define TANK_ZOMBIE_CLASS   8

new bool:bHooked = false;
new bool:bRoundEnded = false;

new Handle:cvar_tankHP;

public Plugin:myinfo = {
    name        = "L4D2 Show Tank Remaining HP",
    author      = "Jahze",
    version     = "1.0",
    description = "Shows the tank's remaining HP if the survivors wiped"
};

public OnPluginStart() {
    cvar_tankHP = CreateConVar("l4d_show_tank_remaining_hp", "1", "Shows the tank's remaing HP after a wipe", FCVAR_PLUGIN);
    HookConVarChange(cvar_tankHP, TankHPChange);
    
    PluginEnable();
}

public OnPluginEnd() {
    PluginDisable();
}

public OnMapStart() {
    bRoundEnded = false;
}

PluginEnable() {
    if ( !bHooked ) {
        HookEvent("round_start", RoundStart);
        HookEvent("round_end", RoundEnd);
        bHooked = true;
    }
}

PluginDisable() {
    if ( bHooked ) {
        UnhookEvent("round_start", RoundStart);
        UnhookEvent("round_end", RoundEnd);
        bHooked = false;
    }
}

public TankHPChange( Handle:cvar, const String:oldValue[], const String:newValue[] ) {
    if ( StringToInt(newValue) == 0 ) {
        PluginDisable();
    }
    else {
        PluginEnable();
    }
}

public Action:RoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
    bRoundEnded = false;
}

public Action:RoundEnd( Handle:event, const String:name[], bool:dontBroadcast ) {
    if ( !bRoundEnded ) {
        CreateTimer(0.1, RoundEndDelay);
    }
    
    bRoundEnded = true;
}

public Action:RoundEndDelay( Handle:timer ) {
    if ( SurvivorsWiped() ) {
        new iTankClient = FindTank();
        
        if ( iTankClient != -1 ) {
            PrintToChatAll("[Tank] Remaining HP: %d", GetPermanentHealth(iTankClient));
        }
    }
}

bool:SurvivorsWiped() {
    for ( new i = 1; i < MaxClients+1; i++ ) {
        if ( IsClientInGame(i)
            && GetClientTeam(i) == 2
            && IsPlayerAlive(i)
            && !IsPlayerIncapacitated(i) ) {
            return false;
        }
    }
    
    return true;
}

IsPlayerIncapacitated(client) {
    return GetEntProp(client, Prop_Send, "m_isIncapacitated");
}

FindTank() {
    for ( new i = 1; i <= MaxClients; i++ ) {
        if ( IsTank(i) ) {
            return i;
        }
    }
    
    return -1;
}

bool:IsTank( client ) {
    if ( client < 0
    || !IsClientConnected(client)
    || !IsClientInGame(client)
    || GetClientTeam(client) != 3
    || !IsPlayerAlive(client) ) {
        return false;
    }
    
    new playerClass = GetEntProp(client, Prop_Send, "m_zombieClass");
    
    if ( playerClass == TANK_ZOMBIE_CLASS ) {
        return true;
    }
    
    return false;
}

GetPermanentHealth(client)
{
    return GetEntProp(client, Prop_Send, "m_iHealth");
}

