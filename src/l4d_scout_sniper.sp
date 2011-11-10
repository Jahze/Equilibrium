#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4downtown>

#define SCOUT_MDL           "models/w_models/weapons/w_sniper_scout.mdl"
#define SCOUT_WEAPON_NAME   "weapon_sniper_scout"

const WEAPON_HUNTING_RIFLE_ID   = 6;
const WEAPON_SNIPER_SCOUT_ID    = 36;

new SCOUT_CLIP_SIZE = 10;
new SCOUT_DAMAGE    = 135;

new bool:bScoutEnabled;
new bool:bHooked;

new iScoutLimit         = 1;
new iScoutLastWeapon    = -1;
new iScoutLastClient    = -1;
new iDefaultClipSize    = 15;
new iDefaultDamage      = 90;
new String:sScoutLastWeapon[64];

new Handle:cvar_scoutEnabled;
new Handle:cvar_scoutLimit;
new Handle:cvar_scoutClipSize;
new Handle:cvar_scoutDamage;

public Plugin:myinfo =
{
    name        = "L4D2 Scout Sniper",
    author      = "Jahze",
    version     = "1.0",
    description = "Replace hunting rifle with the scout"
}

public OnPluginStart() {
    cvar_scoutEnabled = CreateConVar("l4d_scout_sniper", "1", "Replace hunting rifle with scout in confogl", FCVAR_PLUGIN);
    HookConVarChange(cvar_scoutEnabled, ScoutEnabled);
    
    cvar_scoutLimit = CreateConVar("l4d_scout_limit", "1", "Limits the maximum number of scouts per team", FCVAR_PLUGIN);
    HookConVarChange(cvar_scoutLimit, ScoutLimitChange);
    
    cvar_scoutClipSize = CreateConVar("l4d_scout_clip", "8", "Bullets in a scout clip", FCVAR_PLUGIN);
    HookConVarChange(cvar_scoutClipSize, ScoutClipSizeChange);
    
    cvar_scoutDamage = CreateConVar("l4d_scout_damage", "115", "Damage per scout bullet", FCVAR_PLUGIN);
    HookConVarChange(cvar_scoutDamage, ScoutDamageChange);
    
    bScoutEnabled = GetConVarBool(cvar_scoutEnabled);
    iScoutLimit = GetConVarInt(cvar_scoutLimit);
    
    bHooked = false;
}

public OnPluginEnd() {
    PluginDisable();
}

public OnMapStart() {
    if ( bScoutEnabled ) {
        PluginEnable();
    }
}

PluginDisable() {
    if ( bHooked ) {
        UnhookEvent("round_start", RoundStartHook);
        UnhookEvent("spawner_give_item", SpawnerGiveItemHook);
        UnhookEvent("player_use", ScoutPlayerUse);
        UnhookEvent("weapon_drop", ScoutWeaponDrop);
        
        L4D2_SetIntWeaponAttribute(SCOUT_WEAPON_NAME, L4D2IWA_ClipSize, iDefaultClipSize);
        L4D2_SetIntWeaponAttribute(SCOUT_WEAPON_NAME, L4D2IWA_Damage, iDefaultDamage);
        
        bHooked = false;
    }
}

PluginEnable() {
    if ( !bHooked ) {
        HookEvent("round_start", RoundStartHook);
        HookEvent("spawner_give_item", SpawnerGiveItemHook);
        HookEvent("player_use", ScoutPlayerUse);
        HookEvent("weapon_drop", ScoutWeaponDrop);
        
        iDefaultClipSize = L4D2_GetIntWeaponAttribute(SCOUT_WEAPON_NAME, L4D2IWA_ClipSize);
        iDefaultDamage   = L4D2_GetIntWeaponAttribute(SCOUT_WEAPON_NAME, L4D2IWA_Damage);
        L4D2_SetIntWeaponAttribute(SCOUT_WEAPON_NAME, L4D2IWA_ClipSize, SCOUT_CLIP_SIZE);
        L4D2_SetIntWeaponAttribute(SCOUT_WEAPON_NAME, L4D2IWA_Damage, SCOUT_DAMAGE);
        
        bHooked = true;
    }
}

PreloadWeapons() {
    if (IsModelPrecached(SCOUT_MDL)) PrecacheModel(SCOUT_MDL);
    if (!IsModelPrecached("models/v_models/v_snip_scout.mdl")) PrecacheModel("models/v_models/v_snip_scout.mdl");
    
    new index = CreateEntityByName("weapon_sniper_scout");
    DispatchSpawn(index);
    RemoveEdict(index);
}

public ScoutEnabled( Handle:cvar, const String:oldValue[], const String:newValue[] ) {
    if ( StringToInt(newValue) == 0 ) {
        PluginDisable();
        bScoutEnabled = false;
    }
    else {
        PluginEnable();
        bScoutEnabled = true;
    }
}

public ScoutClipSizeChange( Handle:cvar, const String:oldValue[], const String:newValue[] ) {
    SCOUT_CLIP_SIZE = StringToInt(newValue);
    L4D2_SetIntWeaponAttribute(SCOUT_WEAPON_NAME, L4D2IWA_ClipSize, SCOUT_CLIP_SIZE);
}

public ScoutDamageChange( Handle:cvar, const String:oldValue[], const String:newValue[] ) {
    SCOUT_DAMAGE = StringToInt(newValue);
    L4D2_SetIntWeaponAttribute(SCOUT_WEAPON_NAME, L4D2IWA_Damage, SCOUT_DAMAGE);
}

public ScoutLimitChange( Handle:cvar, const String:oldValue[], const String:newValue[] ) {
    iScoutLimit = GetConVarInt(cvar_scoutLimit);
}

ScoutCount(client) {
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
                if ( StrEqual(weaponName, SCOUT_WEAPON_NAME) ) {
                    count++;
                }
            }
        }
    }
    
    return count;
}

bool:IsHuntingRifle( iEntity, const String:sEntityClassName[128] ) {
    // If it's not a weapon, it's not a hunting rifle
    if ( StrContains(sEntityClassName, "weapon") == -1 ) {
        return false;
    }
    
    if ( StrEqual(sEntityClassName, "weapon_spawn") ) {
        new weaponID = GetEntProp(iEntity, Prop_Send, "m_weaponID");
        
        if ( weaponID == WEAPON_HUNTING_RIFLE_ID ) {
            return true;
        }
    }
    else if ( StrEqual(sEntityClassName, "weapon_hunting_rifle_spawn") ) {
        return true;
    }
    
    return false;
}

ReplaceHuntingRifle( iEntity, const String:sEntityClassName[128], bool:bSpawnerEvent ) {
    // Static spawn
    if ( !bSpawnerEvent && StrEqual(sEntityClassName, "weapon_hunting_rifle_spawn") ) {
        // Delete static spawn
        decl Float:fOrigin[3], Float:fRotation[3];
        GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fOrigin);    
        GetEntPropVector(iEntity, Prop_Send, "m_angRotation", fRotation);
        AcceptEntityInput(iEntity, "Kill");
        
        // Replace with a weapon_spawn
        iEntity = CreateEntityByName("weapon_spawn");
        SetEntProp(iEntity, Prop_Send, "m_weaponID", WEAPON_SNIPER_SCOUT_ID);
        SetEntityModel(iEntity, SCOUT_MDL);
        
        TeleportEntity(iEntity, fOrigin, fRotation, NULL_VECTOR);
        DispatchKeyValue(iEntity, "count", "5");
        DispatchSpawn(iEntity);
        SetEntityMoveType(iEntity,MOVETYPE_NONE);
        
        return;
    }
    
    SetEntProp(iEntity, Prop_Send, "m_weaponID", WEAPON_SNIPER_SCOUT_ID);
    SetEntityModel(iEntity, SCOUT_MDL);
}

DetectAndReplaceHR( iEntity, bool:bSpawnerEvent = false ) {
    decl String:sEntityClassName[128];
    GetEdictClassname(iEntity, sEntityClassName, sizeof(sEntityClassName));
    
    if ( IsHuntingRifle(iEntity, sEntityClassName) ) {
        ReplaceHuntingRifle(iEntity, sEntityClassName, bSpawnerEvent);
    }
}

public Action:ScoutUsed( Handle:timer ) {
    for ( new client = 0; client <= MaxClients; client++ ) {
        new weapon = GetPlayerWeaponSlot(client, 0);
        
        if ( !IsValidEdict(weapon) ) {
            return;
        }
        
        decl String:weaponName[64];
        GetEdictClassname(weapon, weaponName, sizeof(weaponName));
        
        // Adjust scout ammo
        if ( StrEqual(weaponName, SCOUT_WEAPON_NAME) ) {
            SetEntProp(weapon, Prop_Send, "m_iClip1", SCOUT_CLIP_SIZE);
            break;
        }
    }
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
    
    // Player picked up a scout
    if ( StrEqual(weaponName, SCOUT_WEAPON_NAME) ) {
        if ( ScoutCount(client) >= iScoutLimit ) {
            RemovePlayerItem(client, weapon);
            PrintToChat(client, "[Deathwish] Maximum of %d scout(s) per team.", iScoutLimit);
            
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
    }
    
    iScoutLastWeapon = -1;
    iScoutLastClient = -1;
    sScoutLastWeapon[0] = 0;
}

public Action:RoundStartHook( Handle:event, const String:name[], bool:dontBroadcast ) {
    CreateTimer(1.0, RoundStartReplaceHR);
}

public Action:RoundStartReplaceHR( Handle:timer ) {
    LogMessage("[Deathwish] Round started" );
    if ( !bScoutEnabled ) {
        return;
    }
    
    LogMessage("[Deathwish] Preloading scout" );
    PreloadWeapons();
    
    decl iEntity, entcount;
    entcount = GetEntityCount();
    
    for ( iEntity = 1; iEntity <= entcount; iEntity++ ) {
        if ( !IsValidEdict(iEntity) || !IsValidEntity(iEntity) ) {
            continue;
        }
        
        DetectAndReplaceHR( iEntity );
    }
}

public Action:SpawnerGiveItemHook(Handle:event, const String:name[], bool:dontBroadcast) {
    if ( !bScoutEnabled ) {
        return;
    }
    
    new iEntity = GetEventInt(event, "spawner");
    DetectAndReplaceHR(iEntity, true);
}
