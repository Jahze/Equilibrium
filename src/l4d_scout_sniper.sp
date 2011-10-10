#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define SCOUT_MDL   "models/w_models/weapons/w_sniper_scout.mdl"

const WEAPON_HUNTING_RIFLE_ID   = 6;
const WEAPON_SNIPER_SCOUT_ID    = 36;

new bool:bScoutEnabled;

new Handle:cvar_scoutEnabled;

public OnPluginStart() {
    //LogMessage("[Scout] plugin start");
    cvar_scoutEnabled = CreateConVar("l4d_scout_sniper", "1", "Replace hunting rifle with scout in confogl", FCVAR_PLUGIN);
    HookConVarChange(cvar_scoutEnabled, ScoutEnabled);
    
    bScoutEnabled = true;
    PluginEnable();
}

public OnPluginEnd() {
    //LogMessage("[Scout] in OnPluginEnd()");
    PluginDisable();
}

PluginDisable() {
    //LogMessage("[Scout] Disabling");
    UnhookEvent("round_start", RoundStartHook);
    UnhookEvent("spawner_give_item", SpawnerGiveItemHook);
}

PluginEnable() {
    //LogMessage("[Scout] Enabling");
    
    PreloadWeapons();
    
    HookEvent("round_start", RoundStartHook);
    HookEvent("spawner_give_item", SpawnerGiveItemHook);
}

PreloadWeapons() {
    if (!IsModelPrecached("models/v_models/v_snip_scout.mdl")) PrecacheModel("models/v_models/v_snip_scout.mdl");
    
    new index = CreateEntityByName("weapon_sniper_scout");
    DispatchSpawn(index);
    RemoveEdict(index);
}

public ScoutEnabled( Handle:cvar, const String:oldValue[], const String:newValue[] ) {
    //LogMessage("[Scout] in ScoutEnabled()");
    if ( StringToInt(newValue) == 0 ) {
        PluginDisable();
        bScoutEnabled = false;
    }
    else {
        PluginEnable();
        bScoutEnabled = true;
    }
}

IsHuntingRifle( iEntity, const String:sEntityClassName[128] ) {
    // If it's not a weapon, it's not a hunting rifle
    if ( StrContains(sEntityClassName, "weapon") == -1 ) {
        return false;
    }
    
    if ( StrEqual(sEntityClassName, "weapon_spawn") ) {
        new weaponID = GetEntProp(iEntity, Prop_Send, "m_weaponID");
        
        //LogMessage("[Scout] Found weapon spawn %d", weaponID);
        if ( weaponID == WEAPON_HUNTING_RIFLE_ID ) {
            return true;
        }
    }
    else if ( StrEqual(sEntityClassName, "weapon_hunting_rifle_spawn") ) {
        return true;
    }
    
    return false;
}

ReplaceHuntingRifle( iEntity, const String:sEntityClassName[128] ) {
    //LogMessage("[Scout] Trying to replace...");
    
    // Static spawn
    if ( StrEqual(sEntityClassName, "weapon_hunting_rifle_spawn") ) {
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

DetectAndReplaceHR( iEntity ) {
    decl String:sEntityClassName[128];
    GetEdictClassname(iEntity, sEntityClassName, sizeof(sEntityClassName));
    
    if ( IsHuntingRifle(iEntity, sEntityClassName) ) {
        ReplaceHuntingRifle(iEntity, sEntityClassName);
    }
}

public Action:RoundStartHook( Handle:event, const String:name[], bool:dontBroadcast ) {
    CreateTimer(1.0, RoundStartReplaceHR);
}

public Action:RoundStartReplaceHR( Handle:timer ) {
    //LogMessage("[Scout] Round start replacements starting");
    if ( !bScoutEnabled ) {
        return;
    }
    
    //LogMessage("[Scout] Round start replacements enabled");
    
    decl iEntity, entcount;
    entcount = GetEntityCount();
    
    for ( iEntity = 1; iEntity <= entcount; iEntity++ ) {
        if ( !IsValidEdict(iEntity) || !IsValidEntity(iEntity) ) {
            continue;
        }
        
        DetectAndReplaceHR( iEntity );
    }
    
    //LogMessage("[Scout] Round start replacements done");
}

public Action:SpawnerGiveItemHook(Handle:event, const String:name[], bool:dontBroadcast) {
    if ( !bScoutEnabled ) {
        return;
    }
    
    //LogMessage("[Scout] Replacing through spawner");
    new iEntity = GetEventInt(event, "spawner");
    DetectAndReplaceHR( iEntity );
}
