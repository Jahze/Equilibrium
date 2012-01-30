#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4downtown>

#define AWP_W_MODEL         "models/w_models/weapons/w_sniper_awp.mdl"
#define AWP_V_MODEL         "models/v_models/v_snip_awp.mdl"
#define AWP_WEAPON_NAME     "weapon_sniper_awp"

#define SCOUT_W_MODEL       "models/w_models/weapons/w_sniper_scout.mdl"
#define SCOUT_V_MODEL       "models/v_models/v_snip_scout.mdl"
#define SCOUT_WEAPON_NAME   "weapon_sniper_scout"

new bool:bHooked;

new iSniperLimit        = 1;
new iSniperLastWeapon   = -1;
new iSniperLastClient   = -1;
new String:sSniperLastWeapon[64];
new String:sSniperType[64];

new Handle:cvar_sniperLimit;
new Handle:cvar_sniperType;

public Plugin:myinfo =
{
    name        = "L4D2 Sniper",
    author      = "Jahze",
    version     = "3.1",
    description = "Plugin that allows limited pickups of AWP or scout"
}

public OnPluginStart() {
    cvar_sniperLimit = CreateConVar("l4d_sniper_limit", "1", "Limits the maximum number of snipers per team", FCVAR_PLUGIN);
    HookConVarChange(cvar_sniperLimit, SniperLimitChange);
    
    cvar_sniperType = CreateConVar("l4d_sniper_type", "scout", "Type of sniper (AWP or scout)", FCVAR_PLUGIN);
    HookConVarChange(cvar_sniperType, SniperTypeChange);
    
    iSniperLimit = GetConVarInt(cvar_sniperLimit);
    GetConVarString(cvar_sniperType, sSniperType, sizeof(sSniperType));
    
    bHooked  = false;
}

public OnPluginEnd() {
    PluginDisable();
}

public OnMapStart() {
    PrecacheSniper();
    PluginEnable();
}

PluginDisable() {
    if ( bHooked ) {
        UnhookEvent("player_use", SniperPlayerUse);
        UnhookEvent("weapon_drop", SniperWeaponDrop);
        
        bHooked  = false;
    }
}

PluginEnable() {
    if ( !bHooked ) {
        HookEvent("player_use", SniperPlayerUse);
        HookEvent("weapon_drop", SniperWeaponDrop);
        
        bHooked = true;
    }
}

PrecacheSniper() {
    decl String:sWModel[64];
    decl String:sVModel[64];
    decl String:sSniperName[64];
    SniperVModel(sVModel, sizeof(sVModel));
    SniperWModel(sWModel, sizeof(sWModel));
    SniperWeaponName(sSniperName, sizeof(sSniperName));
    
    if (!IsModelPrecached(sWModel)) PrecacheModel(sWModel);
    if (!IsModelPrecached(sVModel)) PrecacheModel(sVModel);
    
    new index = CreateEntityByName(sSniperName);
    DispatchSpawn(index);
    RemoveEdict(index);
}

public SniperLimitChange( Handle:cvar, const String:oldValue[], const String:newValue[] ) {
    iSniperLimit = GetConVarInt(cvar_sniperLimit);
}

public SniperTypeChange( Handle:cvar, const String:oldValue[], const String:newValue[] ) {
    Format(sSniperType, sizeof(sSniperType), "%s", newValue);
}

SniperCount(client) {
    new count = 0;
    
    decl String:sSniperName[64];
    SniperWeaponName(sSniperName, sizeof(sSniperName));
    
    for ( new i = 1; i <= MaxClients; i++ ) {
        if ( i != client
        && IsClientConnected(i)
        && IsClientInGame(i)
        && GetClientTeam(i) == 2
        && IsPlayerAlive(i) ) {
            new weapon = GetPlayerWeaponSlot(i, 0);
            if ( IsValidEdict(weapon) ) {
                decl String:weaponName[64];
                GetEdictClassname(weapon, weaponName, sizeof(weaponName));
                if ( StrEqual(weaponName, sSniperName) ) {
                    count++;
                }
            }
        }
    }
    
    return count;
}

public Action:SniperWeaponDrop( Handle:event, const String:name[], bool:dontBroadcast ) {
    iSniperLastWeapon = GetEventInt(event, "propid");
    iSniperLastClient = GetClientOfUserId(GetEventInt(event, "userid"));
    GetEventString(event, "item", sSniperLastWeapon, sizeof(sSniperLastWeapon));
}

public Action:SniperPlayerUse( Handle:event, const String:name[], bool:dontBroadcast ) {
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    new weapon = GetPlayerWeaponSlot(client, 0);
    
    decl String:sSniperName[64];
    SniperWeaponName(sSniperName, sizeof(sSniperName));
    
    if ( !IsValidEdict(weapon) ) {
        return;
    }
    
    decl String:weaponName[64];
    GetEdictClassname(weapon, weaponName, sizeof(weaponName));
    
    // Player picked up a sniper
    if ( StrEqual(weaponName, sSniperName) ) {
        if ( SniperCount(client) >= iSniperLimit ) {
            RemovePlayerItem(client, weapon);
            PrintToChat(client, "[Sniper] Maximum of %d sniper(s) per team.", iSniperLimit);
            
            if ( client == iSniperLastClient ) {
                if ( IsValidEdict(iSniperLastWeapon) ) {
                    AcceptEntityInput(iSniperLastWeapon, "Kill");
                    
                    new giveFlags = GetCommandFlags("give");
                    SetCommandFlags("give", giveFlags ^ FCVAR_CHEAT);
                    
                    decl String:giveCommand[128];
                    Format(giveCommand, sizeof(giveCommand), "give %s", sSniperLastWeapon);
                    FakeClientCommand(client, giveCommand);
                    
                    SetCommandFlags("give", giveFlags);
                }
            }
        }
    }
    
    iSniperLastWeapon = -1;
    iSniperLastClient = -1;
    sSniperLastWeapon[0] = 0;
}

SniperVModel(String:buf[], len) {
    if ( StrContains(sSniperType, "awp", false) != -1 ) {
        strcopy(buf, len, AWP_V_MODEL);
    }
    else {
        strcopy(buf, len, SCOUT_V_MODEL);
    }
}

SniperWModel(String:buf[], len) {
    if ( StrContains(sSniperType, "awp", false) != -1 ) {
        strcopy(buf, len, AWP_W_MODEL);
    }
    else {
        strcopy(buf, len, SCOUT_W_MODEL);
    }
}

SniperWeaponName(String:buf[], len) {
    if ( StrContains(sSniperType, "awp", false) != -1 ) {
        strcopy(buf, len, AWP_WEAPON_NAME);
    }
    else {
        strcopy(buf, len, SCOUT_WEAPON_NAME);
    }
}
