#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4downtown>
#include <mapinfo>

new bool:distanceEnabled = false;
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
    
    PluginEnable();
}

public OnMapStart() {
    if ( distanceEnabled ) {
        CreateTimer(1.0, SetMapDistance);
    }
}

public OnPluginEnd() {
    PluginDisable();
}

PluginEnable() {
    if ( !distanceEnabled ) {
        HookEvent("player_left_start_area", AnnounceMapDistance);
        distanceEnabled = true;
    }
}

PluginDisable() {
    if ( distanceEnabled ) {
        UnhookEvent("player_left_start_area", AnnounceMapDistance);
        distanceEnabled = false;
    }
}

public Action:SetMapDistance( Handle:timer ) {
    if ( distanceEnabled ) {
        new iDistance = LGO_GetMapValueInt("max_distance", L4D_GetVersusMaxCompletionScore());
        L4D_SetVersusMaxCompletionScore(iDistance);
    }
}

public CustomDistanceChange( Handle:cvar, const String:oldValue[], const String:newValue[] ) {
    if ( StringToInt(newValue) == 0 ) {
        PluginDisable();
    }
    else {
        PluginEnable();
    }
}

public Action:AnnounceMapDistance( Handle:event, const String:name[], bool:dontBroadcast ) {
    decl String:msg[128];
    
    Format(msg, sizeof(msg), "[Deathwish] This map is worth %d distance points.", L4D_GetVersusMaxCompletionScore());
    PrintToChatAll(msg);
}
