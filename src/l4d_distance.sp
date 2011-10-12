#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4downtown>

public Plugin:myinfo =
{
    name        = "L4D2 distance mod",
    author      = "Jahze",
    version     = "0.1",
    description = "L4D2 plugin to set a static per-map distance"
}

new iDistancePoints;
new iDefaultDistance;
new iCurrentDistance = 0;

new Handle:cvar_distanceEnable;
new Handle:cvar_distancePoints;

public OnPluginStart() {
    cvar_distanceEnable = CreateConVar("l4d_distance_enable", "0", "L4D2 custom map distance enabled", FCVAR_PLUGIN);
    HookConVarChange(cvar_distanceEnable, DistanceEnabled);
    
    cvar_distancePoints = CreateConVar("l4d_distance_points", "1", "Distance points per survivor awarded when reaching landmark", FCVAR_PLUGIN);
    HookConVarChange(cvar_distancePoints, DistancePointsChange);
    
    iDistancePoints = GetConVarInt(cvar_distancePoints);
    iDefaultDistance = L4D_GetVersusMaxCompletionScore();
    
    LogMessage("plugin loaded, default distance: %d", iDefaultDistance);
}

public OnPluginEnd() {
    PluginDisable();
}

PluginDisable() {
    L4D_SetVersusMaxCompletionScore(iDefaultDistance);
    UnhookEvent("versus_marker_reached", DistanceMarker);
    UnhookEvent("round_start", DistanceRoundStart);
    UnhookEvent("round_end", DistanceRoundEnd);
}

PluginEnable() {
    HookEvent("versus_marker_reached", DistanceMarker);
    HookEvent("round_start", DistanceRoundStart);
    HookEvent("round_end", DistanceRoundEnd);
}

public Action:DistanceMarker( Handle:event, const String:name[], bool:dontBroadcast ) {
    /*
    decl String:clientName[128];
    new progress = GetEventInt(event, "marker");
    new client   = GetClientOfUserId(GetEventInt(event, "userid"));
    GetClientName(client, clientName, sizeof(clientName));
    LogMessage("%s reached %d", clientName, progress);
    */
    
    new progress = GetEventInt(event, "marker");
    iCurrentDistance += GetSurvivorCount()*iDistancePoints;
    
    LogMessage("%d survivors, %d points, %d total", GetSurvivorCount(), GetSurvivorCount()*iDistancePoints, iCurrentDistance);
    
    if ( progress == 75 ) {
        L4D_SetVersusMaxCompletionScore(iCurrentDistance);
        LogMessage("75% closed with %d points", iCurrentDistance);
    }
}

public Action:DistanceRoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
    LogMessage("%d default distance", iDefaultDistance);
    if ( iDefaultDistance ) {
        L4D_SetVersusMaxCompletionScore(iDefaultDistance);
    }
}

public Action:DistanceRoundEnd( Handle:event, const String:name[], bool:dontBroadcast ) {
    //L4D_SetVersusMaxCompletionScore(iCurrentDistance);
    //LogMessage("door closed with %d points", iCurrentDistance);
}

public OnMapStart() {
    iDefaultDistance = L4D_GetVersusMaxCompletionScore();
}

public OnMapEnd() {
    L4D_SetVersusMaxCompletionScore(iDefaultDistance);
}

public DistanceEnabled( Handle:cvar, const String:oldValue[], const String:newValue[]) {
    if ( StringToInt(newValue) == 0 ) {
        LogMessage("Disabling");    
        PluginDisable();
    }
    else {
        LogMessage("Enabling");
        PluginEnable();
    }
}

public DistancePointsChange( Handle:cvar, const String:oldValue[], const String:newValue[]) {
    iDistancePoints = StringToInt(newValue);
}

GetSurvivorCount() {
    new count = 0;
    
    for ( new i = 1; i <= MaxClients; i++ ) {
        if ( IsClientConnected(i)
        && IsClientInGame(i)
        && GetClientTeam(i) == 2
        && IsPlayerAlive(i) ) {
            count++;
        }
    }
    
    return count;
}
