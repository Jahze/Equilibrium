#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4downtown>

public Plugin:myinfo =
{
    name        = "L4D2 distance mod",
    author      = "Jahze",
    version     = "1.0",
    description = "L4D2 plugin to set a static per-map distance"
}

new iMaxDistance;
new iDefaultDistance;

new bool:bCustomDistanceEnabled;

new Handle:cvar_distanceEnable;
new Handle:cvar_distanceMax;

public OnPluginStart() {
    cvar_distanceEnable = CreateConVar("l4d_distance_enable", "0", "L4D2 custom map distance enabled", FCVAR_PLUGIN);
    HookConVarChange(cvar_distanceEnable, DistanceEnabled);
    
    // TODO: Allow this to be set via mapinfo
    cvar_distanceMax = CreateConVar("l4d_distance_max", "4", "Maximum distance points for any map", FCVAR_PLUGIN);
    HookConVarChange(cvar_distanceMax, DistanceMaxChange);
    
    iMaxDistance = GetConVarInt(cvar_distanceMax);
    iDefaultDistance = L4D_GetVersusMaxCompletionScore();
}

public OnPluginEnd() {
    PluginDisable();
}

PluginDisable() {
    L4D_SetVersusMaxCompletionScore(iDefaultDistance);
    // TODO: unhook events
}

public OnMapStart() {
    iDefaultDistance = L4D_GetVersusMaxCompletionScore();
    if ( bCustomDistanceEnabled ) {
        L4D_SetVersusMaxCompletionScore(iMaxDistance);
    }
}

public DistanceEnabled( Handle:cvar, const String:oldValue[], const String:newValue[]) {
    if ( StringToInt(newValue) == 0 ) {
        PluginDisable();
        bCustomDistanceEnabled = false;
    }
    else {
        // XXX: we don't set the distance here (might be in the middle of a map ... what would happen?!)
        bCustomDistanceEnabled = true;
    }
}

public DistanceMaxChange( Handle:cvar, const String:oldValue[], const String:newValue[]) {
    iMaxDistance = StringToInt(newValue);
    if ( bCustomDistanceEnabled) {
        L4D_SetVersusMaxCompletionScore(iMaxDistance);
    }
}