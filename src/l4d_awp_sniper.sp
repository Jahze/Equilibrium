#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4downtown>

#define AWP_W_MDL           "models/w_models/weapons/w_sniper_awp.mdl"
#define AWP_V_MDL           "models/v_models/v_snip_awp.mdl"
#define AWP_WEAPON_NAME     "weapon_sniper_awp"

new AWP_CLIP_SIZE = 10;
new AWP_DAMAGE    = 135;

new bool:bHooked;
new bool:bTweaked;

new iAwpLimit           = 1;
new iAwpLastWeapon      = -1;
new iAwpLastClient      = -1;
new iDefaultClipSize    = 15;
new iDefaultDamage      = 90;
new String:sAwpLastWeapon[64];

new Handle:cvar_awpLimit;
new Handle:cvar_awpClipSize;
new Handle:cvar_awpDamage;

public Plugin:myinfo =
{
    name        = "L4D2 AWP Sniper",
    author      = "Jahze",
    version     = "2.0",
    description = "Limit and tweak AWP"
}

public OnPluginStart() {
    cvar_awpLimit = CreateConVar("l4d_awp_limit", "1", "Limits the maximum number of AWPs per team", FCVAR_PLUGIN);
    HookConVarChange(cvar_awpLimit, AwpLimitChange);
    
    cvar_awpClipSize = CreateConVar("l4d_awp_clip", "8", "Bullets in a AWP clip", FCVAR_PLUGIN);
    HookConVarChange(cvar_awpClipSize, AwpClipSizeChange);
    
    cvar_awpDamage = CreateConVar("l4d_awp_damage", "135", "Damage per AWP bullet", FCVAR_PLUGIN);
    HookConVarChange(cvar_awpDamage, AwpDamageChange);
    
    iAwpLimit = GetConVarInt(cvar_awpLimit);
    
    bHooked  = false;
    bTweaked = false;
}

public OnPluginEnd() {
    PluginDisable();
}

public OnMapStart() {
    PrecacheAwp();
    PluginEnable();
}

PluginDisable() {
    if ( bHooked ) {
        UnhookEvent("player_use", AwpPlayerUse);
        UnhookEvent("weapon_drop", AwpWeaponDrop);
        
        L4D2_SetIntWeaponAttribute(AWP_WEAPON_NAME, L4D2IWA_ClipSize, iDefaultClipSize);
        L4D2_SetIntWeaponAttribute(AWP_WEAPON_NAME, L4D2IWA_Damage, iDefaultDamage);
        
        bHooked  = false;
        bTweaked = false;
    }
}

PluginEnable() {
    if ( !bHooked ) {
        HookEvent("player_use", AwpPlayerUse);
        HookEvent("weapon_drop", AwpWeaponDrop);
        
        bHooked = true;
    }
}

PrecacheAwp() {
    LogMessage("[AWP] Precaching");
    if (!IsModelPrecached(AWP_W_MDL)) PrecacheModel(AWP_W_MDL);
    if (!IsModelPrecached(AWP_V_MDL)) PrecacheModel(AWP_V_MDL);
    
    new index = CreateEntityByName(AWP_WEAPON_NAME);
    DispatchSpawn(index);
    RemoveEdict(index);
}

TweakAwp() {
    if ( !bTweaked ) {
        LogMessage("[AWP] Tweaking");
        iDefaultClipSize = L4D2_GetIntWeaponAttribute(AWP_WEAPON_NAME, L4D2IWA_ClipSize);
        iDefaultDamage   = L4D2_GetIntWeaponAttribute(AWP_WEAPON_NAME, L4D2IWA_Damage);
        L4D2_SetIntWeaponAttribute(AWP_WEAPON_NAME, L4D2IWA_ClipSize, AWP_CLIP_SIZE);
        L4D2_SetIntWeaponAttribute(AWP_WEAPON_NAME, L4D2IWA_Damage, AWP_DAMAGE);
        bTweaked = true;
    }
}

public AwpClipSizeChange( Handle:cvar, const String:oldValue[], const String:newValue[] ) {
    AWP_CLIP_SIZE = StringToInt(newValue);
    L4D2_SetIntWeaponAttribute(AWP_WEAPON_NAME, L4D2IWA_ClipSize, AWP_CLIP_SIZE);
}

public AwpDamageChange( Handle:cvar, const String:oldValue[], const String:newValue[] ) {
    AWP_DAMAGE = StringToInt(newValue);
    L4D2_SetIntWeaponAttribute(AWP_WEAPON_NAME, L4D2IWA_Damage, AWP_DAMAGE);
}

public AwpLimitChange( Handle:cvar, const String:oldValue[], const String:newValue[] ) {
    iAwpLimit = GetConVarInt(cvar_awpLimit);
}

AwpCount(client) {
    new count = 0;
    
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
                if ( StrEqual(weaponName, AWP_WEAPON_NAME) ) {
                    count++;
                }
            }
        }
    }
    
    return count;
}

public Action:AwpWeaponDrop( Handle:event, const String:name[], bool:dontBroadcast ) {
    iAwpLastWeapon = GetEventInt(event, "propid");
    iAwpLastClient = GetClientOfUserId(GetEventInt(event, "userid"));
    GetEventString(event, "item", sAwpLastWeapon, sizeof(sAwpLastWeapon));
}

public Action:AwpPlayerUse( Handle:event, const String:name[], bool:dontBroadcast ) {
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    new weapon = GetPlayerWeaponSlot(client, 0);
    
    if ( !IsValidEdict(weapon) ) {
        return;
    }
    
    decl String:weaponName[64];
    GetEdictClassname(weapon, weaponName, sizeof(weaponName));
    
    // Player picked up a AWP
    if ( StrEqual(weaponName, AWP_WEAPON_NAME) ) {
        if ( AwpCount(client) >= iAwpLimit ) {
            RemovePlayerItem(client, weapon);
            PrintToChat(client, "[AWP] Maximum of %d AWP(s) per team.", iAwpLimit);
            
            if ( client == iAwpLastClient ) {
                if ( IsValidEdict(iAwpLastWeapon) ) {
                    AcceptEntityInput(iAwpLastWeapon, "Kill");
                    
                    new giveFlags = GetCommandFlags("give");
                    SetCommandFlags("give", giveFlags ^ FCVAR_CHEAT);
                    
                    decl String:giveCommand[128];
                    Format(giveCommand, sizeof(giveCommand), "give %s", sAwpLastWeapon);
                    FakeClientCommand(client, giveCommand);
                    
                    SetCommandFlags("give", giveFlags);
                }
            }
        }
        else {
            TweakAwp();
        }
    }
    
    iAwpLastWeapon = -1;
    iAwpLastClient = -1;
    sAwpLastWeapon[0] = 0;
}
