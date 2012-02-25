#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4downtown>

const TANK_ZOMBIE_CLASS = 8;

new bool:bSecondRound;
new bool:bTankAlive;
new bool:bHooked;

new iDistance;

new Handle:cvar_noTankRush;

public Plugin:myinfo = {
    name        = "L4D2 No Tank Rush",
    author      = "Jahze",
    version     = "1.0",
    description = "Stops distance points accumulating whilst the tank is alive"
};

public OnPluginStart() {
    cvar_noTankRush = CreateConVar("l4d_no_tank_rush", "1", "Prevents survivor team from accumulating points whilst the tank is alive", FCVAR_PLUGIN);
    HookConVarChange(cvar_noTankRush, NoTankRushChange);
    
    bHooked = false;
    PluginEnable();
}

public OnPluginEnd() {
    PluginDisable();
}

public OnMapStart() {
    bSecondRound = false;
}

PluginEnable() {
    if ( !bHooked ) {
        HookEvent("round_start", RoundStart);
        HookEvent("round_end", RoundEnd);
        HookEvent("tank_spawn", TankSpawn);
        HookEvent("player_death", TankKilled);
        
        bHooked = true;
    }
}

PluginDisable() {
    if ( bHooked ) {
        UnhookEvent("round_start", RoundStart);
        UnhookEvent("round_end", RoundEnd);
        UnhookEvent("tank_spawn", TankSpawn);
        UnhookEvent("player_death", TankKilled);
        
        bHooked = false;
    }
}

public NoTankRushChange( Handle:cvar, const String:oldValue[], const String:newValue[] ) {
    if ( StringToInt(newValue) == 0 ) {
        PluginDisable();
    }
    else {
        PluginEnable();
    }
}

public Action:RoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
    bTankAlive = false;
    
    if ( bSecondRound ) {
        L4D_SetVersusMaxCompletionScore(iDistance);
    }
}

public Action:RoundEnd( Handle:event, const String:name[], bool:dontBroadcast ) {
    bSecondRound = true;
}

public Action:TankSpawn( Handle:event, const String:name[], bool:dontBroadcast ) {
    if ( !bTankAlive ) {
        bTankAlive = true;
        iDistance  = L4D_GetVersusMaxCompletionScore();
        
        L4D_SetVersusMaxCompletionScore(0);
    }
}

public Action:TankKilled( Handle:event, const String:name[], bool:dontBroadcast ) {
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    
    if ( bTankAlive && IsTank(client) ) {
        CreateTimer(0.1, TankKilledDelay);
    }
}

public Action:TankKilledDelay( Handle:timer ) {
    if ( FindTank() == -1 ) {
        bTankAlive = false;
        L4D_SetVersusMaxCompletionScore(iDistance);
    }
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
