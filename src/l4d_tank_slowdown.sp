#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

const TANK_ZOMBIE_CLASS = 8;

new iTankClient = -1;

new Handle:timer_tankSlowdown;
new Handle:cvar_tankSlowdown;

public Plugin:myinfo = {
    name        = "L4D Remove Tank Slowdown",
    author      = "Jahze",
    version     = "0.1",
    description = "Removes the slow down from tanks"
};

public OnPluginStart() {
    CreateConVar("l4d_tank_slowdown", "1", "Enables/disables removal of the slow down that weapons to do tanks", FCVAR_PLUGIN);
    HookConVarChange(cvar_tankSlowdown, TankSlowdownChange);
}

PluginEnable() {
    HookEvent("tank_spawn", TankSpawnSlowdown);
    HookEvent("tank_killed", TankKilledSlowdown);
}

PluginDisable() {
    UnhookEvent("tank_spawn", TankSpawnSlowdown);
    UnhookEvent("tank_killed", TankKilledSlowdown);
}

public TankSlowdownChange( Handle:cvar, const String:oldValue[], const String:newValue[] ) {
    if ( StringToInt(newValue) == 0 ) {
        PluginDisable();
    }
    else {
        PluginEnable();
    }
}

public Action:TankSpawnSlowdown( Handle:event, const String:name[], bool:dontBroadcast ) {
    iTankClient = GetClientOfUserId(GetEventInt(event, "userid"));
    timer_tankSlowdown = CreateTimer(1.0, TankSlowdownTimer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action:TankKilledSlowdown( Handle:event, const String:name[], bool:dontBroadcast ) {
    iTankClient = -1;
    if ( timer_tankSlowdown != INVALID_HANDLE ) {
        KillTimer(timer_tankSlowdown);
    }
}

public Action:TankSlowdownTimer( Handle:timer ) {
    if ( !IsTank(iTankClient) ) {
        iTankClient = FindTank();
        
        if ( iTankClient < 0 ) {
            iTankClient = -1;
            timer_tankSlowdown = INVALID_HANDLE;
            return Plugin_Stop;
        }
    }
    
    SetEntProp(iTankClient, Prop_Send, "m_flLaggedMovementValue", 1.0);
    return Plugin_Continue;
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

