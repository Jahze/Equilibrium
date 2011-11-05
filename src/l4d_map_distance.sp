#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4downtown>
#include <mapinfo>

new bool:distanceEnabled;
new Handle:cvar_customMapDistance;

public Plugin:myinfo = {
    name        = "L4D2 Custom Map Distance",
    author      = "Jahze",
    version     = "1.0",
    description = "Enables custom map distance read from mapinfo.txt"
}

public OnPluginStart() {
    cvar_customMapDistance = CreateConVar("l4d_map_distance", "1", "Sets a custom distance if defined in mapinfo.txt", FCVAR_PLUGIN);
    HookConVarChange(cvar_customMapDistance, CustomDistanceChange);
    distanceEnabled = true;
}

public OnMapStart() {
    CreateTimer(1.0, SetMapDistance);
}

public Action:SetMapDistance( Handle:timer ) {
    if ( distanceEnabled ) {
        new iDistance = LGO_GetMapValueInt("max_distance", L4D_GetVersusMaxCompletionScore());
        L4D_SetVersusMaxCompletionScore(iDistance);
    }
}

public CustomDistanceChange( Handle:cvar, const String:oldValue[], const String:newValue[] ) {
    if ( StringToInt(newValue) == 0 ) {
        distanceEnabled = false;
    }
    else {
        distanceEnabled = true;
    }
}
