#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define SCOUT_MDL   "models/w_models/weapons/w_sniper_scout.mdl"

const WEAPON_HUNTING_RIFLE_ID   = 6;
const WEAPON_SNIPER_SCOUT_ID    = 36;

new bool:bScoutEnabled;

new Handle:cvar_scoutEnabled;

public OnPluginStart() {
    cvar_scoutEnabled = CreateConVar("l4d_scout_sniper", "1", "Replace hunting rifle with scout in confogl", FCVAR_PLUGIN);
    HookConVarChange(cvar_scoutEnabled, ScoutEnabled);
}

public OnPluginEnd() {
    PluginDisable();
}

PluginDisable() {
    UnhookEvent("round_start", RoundStartHook);
    UnhookEvent("spawner_give_item", SpawnerGiveItemHook);
}

PluginEnable() {
    HookEvent("round_start", RoundStartHook);
    HookEvent("spawner_give_item", SpawnerGiveItemHook);
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

IsHuntingRifle( iEntity, const String:sEntityClassName[128] ) {
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
    
    return false;
}

ReplaceHuntingRifle( iEntity ) {
    SetEntProp(iEntity, Prop_Send, "m_weaponID", WEAPON_SNIPER_SCOUT_ID);
    SetEntityModel(iEntity, SCOUT_MDL);
}

DetectAndReplaceHR( iEntity ) {
    decl String:sEntityClassName[128];
    GetEdictClassname(iEntity, sEntityClassName, sizeof(sEntityClassName));
    
    if ( IsHuntingRifle(iEntity, sEntityClassName) ) {
        ReplaceHuntingRifle(iEntity);
    }
}

public Action:RoundStartHook( Handle:event, const String:name[], bool:dontBroadcast ) {
    CreateTimer(1.0, RoundStartReplaceHR);
}

public Action:RoundStartReplaceHR( Handle:timer ) {
    if ( !bScoutEnabled ) {
        return;
    }
    
    decl iEntity, entcount;
    entcount = GetEntityCount();
    
    for ( iEntity = 1; iEntity <= entcount; iEntity++ ) {
        if ( !IsValidEdict(iEntity) || !IsValidEntity(iEntity) ) {
            continue;
        }
        
        DetectAndReplaceHR( iEntity );
    }
}

public Action:SpawnerGiveItemHook(Handle:event, const String:name[], bool:dontBroadcast)
{
    if ( !bScoutEnabled ) {
        return;
    }
    
    new iEntity = GetEventInt(event, "spawner");
    DetectAndReplaceHR( iEntity );
}
