#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4downtown>
#include <mapinfo>

#include "cfgname.sp"

new bool:distanceEnabled = false;

new Float:fDesiredHb = 1.0;

new Handle:cvar_customMapDistance;
new Handle:cvar_hbRatio;
new Handle:cvar_desiredHb;

public Plugin:myinfo = {
    name        = "L4D2 Custom Map Distance",
    author      = "Jahze",
    version     = "1.1",
    description = "Enables custom map distance read from mapinfo.txt"
}

public OnPluginStart() {
    cvar_customMapDistance = CreateConVar("l4d_map_distance", "1", "Sets a custom distance if defined in mapinfo.txt", FCVAR_PLUGIN);
    HookConVarChange(cvar_customMapDistance, CustomDistanceChange);
    
    // XXX: The desired health bonus ratio. Set this to what you would set SM_healthbonusratio to.
    // l4d2_scoremod.sp doesn't work with l4d2lib as the call to get max_distance uses a literal default
    // value or something ("Invalid address value") -- too lazy to figure it out just yet
    cvar_desiredHb = CreateConVar("l4d_desired_hb", "1", "The desired health bonus ratio (this is a hack)", FCVAR_PLUGIN);
    HookConVarChange(cvar_desiredHb, DesiredHbChange);
    
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
        new iDefaultDistance = L4D_GetVersusMaxCompletionScore();
        
        if ( cvar_hbRatio == INVALID_HANDLE ) {
            cvar_hbRatio = FindConVar("SM_healthbonusratio");
        }
        
        new iDistance = LGO_GetMapValueInt("max_distance", iDefaultDistance);
        
        L4D_SetVersusMaxCompletionScore(iDistance);
        
        if ( cvar_hbRatio != INVALID_HANDLE ) {
            SetConVarFloat(cvar_hbRatio, (Float:iDistance/Float:iDefaultDistance) * fDesiredHb);
        }
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

public DesiredHbChange( Handle:cvar, const String:oldValue[], const String:newValue[] ) {
    fDesiredHb = StringToFloat(newValue);
}

public Action:AnnounceMapDistance( Handle:event, const String:name[], bool:dontBroadcast ) {
    decl String:msg[128];
    decl String:cfgName[128];
    
    GetCfgName(cfgName, sizeof(cfgName));
    
    Format(msg, sizeof(msg), "[%s] This map is worth %d distance points.", cfgName, L4D_GetVersusMaxCompletionScore());
    PrintToChatAll(msg);
}
