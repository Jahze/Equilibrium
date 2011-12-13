#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>

new bool:bLateLoad;
new Handle:cvar_siSlowdown;

public Plugin:myinfo = {
    name        = "L4D2 Remove Special Infected Slowdown",
    author      = "Jahze",
    version     = "1.1",
    description = "Removes the slow down from special infected"
};

public APLRes:AskPluginLoad2( Handle:plugin, bool:late, String:error[], errMax ) {
    bLateLoad = late;
    return APLRes_Success;    
}

public OnPluginStart() {
    cvar_siSlowdown = CreateConVar("l4d_si_slowdown", "1", "Enables/disables removal of the slow down that weapons to do special infected", FCVAR_PLUGIN);
    
    if ( bLateLoad ) {
        for ( new i = 1; i < MaxClients+1; i++ ) {
            if ( IsClientInGame(i) ) {
                SDKHook(i, SDKHook_OnTakeDamagePost, SiSlowdown);
            }
        }
    }
}

public OnClientPutInServer( client ) {
    SDKHook(client, SDKHook_OnTakeDamagePost, SiSlowdown);
}

public Action:SiSlowdown( victim, &attacker, &inflictor, &Float:damage, &damageType, &weapon, Float:damageForce[3], Float:damagePosition[3] ) {
    if ( GetConVarBool(cvar_siSlowdown) && IsSi(victim) ) {
        SetEntPropFloat(victim, Prop_Send, "m_flVelocityModifier", 1.0);
    }
}

bool:IsSi( client ) {
    if ( IsClientConnected(client)
    && IsClientInGame(client)
    && GetClientTeam(client) == 3 ) {
        return true;
    }
    
    return false;
}
