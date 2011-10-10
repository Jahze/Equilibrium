/*
 * Heavily borrowed from confogl's plugin to limit to one hunting rifle:
 * http://confogl.googlecode.com
 */
 
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4downtown>

#define SCOUT_WEAPON_NAME   "weapon_sniper_scout"

new Handle:cvar_scoutLimit;

new iScoutLimit         = 1;
new iScoutLastWeapon    = -1;
new iScoutLastClient    = -1;
new String:sScoutLastWeapon[64];

public OnPluginStart() {
    cvar_scoutLimit = CreateConVar("l4d_scout_limit", "1", "Limits the maximum number of scouts per team", FCVAR_PLUGIN);
    HookConVarChange(cvar_scoutLimit, ScoutLimitChange);
    
    iScoutLimit = GetConVarInt(cvar_scoutLimit);
    
    HookEvent("player_use", ScoutPlayerUse);
    HookEvent("weapon_drop", ScoutWeaponDrop);
    
    /*
    if ( L4D2_IsValidWeapon("scout_sniper") ) {
        LogMessage("[Scout Tweaks] scout_sniper");
    }
    
    if ( L4D2_IsValidWeapon("sniper_scout") ) {
        LogMessage("[Scout Tweaks] sniper_scout");
    }
    
    if ( L4D2_IsValidWeapon("weapon_scout_sniper") ) {
        LogMessage("[Scout Tweaks] weapon_scout_sniper");
    }
    
    if ( L4D2_IsValidWeapon("weapon_sniper_scout") ) {
        LogMessage("[Scout Tweaks] weapon_sniper_scout");
    }
    */
    
    LogMessage("[Scout Tweaks] Loaded...");
}

public OnPluginEnd() {
    UnhookEvent("player_use", ScoutPlayerUse);
    UnhookEvent("weapon_drop", ScoutWeaponDrop);
}

public ScoutLimitChange( Handle:cvar, const String:oldValue[], const String:newValue[] ) {
    iScoutLimit = GetConVarInt(cvar_scoutLimit);
}

public Action:ScoutWeaponDrop( Handle:event, const String:name[], bool:dontBroadcast ) {
    iScoutLastWeapon = GetEventInt(event, "propid");
    iScoutLastClient = GetClientOfUserId(GetEventInt(event, "userid"));
    GetEventString(event, "item", sScoutLastWeapon, sizeof(sScoutLastWeapon));
}

public Action:ScoutPlayerUse( Handle:event, const String:name[], bool:dontBroadcast ) {
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    new weapon = GetPlayerWeaponSlot(client, 0);
    
    if ( !IsValidEdict(weapon) ) {
        return;
    }
    
    decl String:weaponName[64];
    GetEdictClassname(weapon, weaponName, sizeof(weaponName));
    
    if ( StrEqual(weaponName, SCOUT_WEAPON_NAME) ) {
        if ( ScoutCount(client) >= iScoutLimit ) {
            RemovePlayerItem(client, weapon);
            PrintToChat(client, "[Deathwish] Maximum of %d scout(s) per team", iScoutLimit);
        }
        
        if ( client == iScoutLastClient ) {
            if ( IsValidEdict(iScoutLastWeapon) ) {
                AcceptEntityInput(iScoutLastWeapon, "Kill");
                
                new giveFlags = GetCommandFlags("give");
                SetCommandFlags("give", giveFlags ^ FCVAR_CHEAT);
                
                decl String:giveCommand[128];
                Format(giveCommand, sizeof(giveCommand), "give %s", sScoutLastWeapon);
                FakeClientCommand(client, giveCommand);
                
                SetCommandFlags("give", giveFlags);
            }
        }
    }
    
    iScoutLastWeapon = -1;
    iScoutLastClient = -1;
    sScoutLastWeapon[0] = 0;
}

ScoutCount(client) {
    new count = 0;
    
    for ( new i = 0; i < MaxClients; i++ ) {
        if ( i != client
        && i != 0
        && IsClientConnected(i)
        && IsClientInGame(i)
        && GetClientTeam(i) == 2 ) {
            new weapon = GetPlayerWeaponSlot(i, 0);
            if ( IsValidEdict(weapon) ) {
                decl String:weaponName[64];
                GetEdictClassname(weapon, weaponName, sizeof(weaponName));
                if ( StrEqual(weaponName, SCOUT_WEAPON_NAME) ) {
                    count++;
                }
            }
        }
    }
    
    return count;
}
