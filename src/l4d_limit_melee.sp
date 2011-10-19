#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <mapinfo>

new bool:bNoMeleeInSafe = true;
new iMeleeLimit = 4;

new Handle:cvar_noMeleeInSafe;
new Handle:cvar_meleeLimit;

public Plugin:myinfo =
{
    name        = "L4D2 Limit Melee Weapons",
    author      = "Jahze",
    version     = "0.1",
    description = "Limit melee weapons"
}

public OnPluginStart() {
    cvar_noMeleeInSafe = CreateConVar("l4d_no_melee_saferoom", "1", "Remove melee weapons from the safe room", FCVAR_PLUGIN);
    HookConVarChange(cvar_noMeleeInSafe, NoMeleeInSafeChange);
    
    cvar_meleeLimit = CreateConVar("l4d_melee_limit", "4", "Limit maximum number of melee weapons per map (-1 for no limit)", FCVAR_PLUGIN);
    HookConVarChange(cvar_meleeLimit, MeleeLimitChange);
    
    PluginEnable();
}

public OnPluginEnd() {
    PluginDisable();
}

PluginDisable() {
    UnhookEvent("round_start", RoundStartHook);
}

PluginEnable() {
    HookEvent("round_start", RoundStartHook);
}

public NoMeleeInSafeChange( Handle:cvar, const String:oldValue[], const String:newValue[] ) {
    if ( StringToInt(newValue) == 0 ) {
        bNoMeleeInSafe = false;
    }
    else {
        bNoMeleeInSafe = true;
    }
}

public MeleeLimitChange( Handle:cvar, const String:oldValue[], const String:newValue[] ) {
    iMeleeLimit = StringToInt(newValue);
}

IsMelee( iEntity ) {
    decl String:sEntityClassName[128];
    GetEdictClassname(iEntity, sEntityClassName, sizeof(sEntityClassName));
    
    if ( StrEqual(sEntityClassName, "weapon_melee_spawn") ) {
        return true;
    }
    
    return false;
}

RemoveMelee( iEntity ) {
    AcceptEntityInput(iEntity, "Kill");
}

public Action:RoundStartHook( Handle:event, const String:name[], bool:dontBroadcast ) {
    CreateTimer(1.0, RoundStartLimitMelee);
}

public Action:RoundStartLimitMelee( Handle:timer ) {
    if ( !bNoMeleeInSafe && iMeleeLimit < 0 ) {
        return;
    }
    
    decl iEntity, entcount;
    entcount = GetEntityCount();
    new count = 0;
    
    for ( iEntity = 1; iEntity <= entcount; iEntity++ ) {
        if ( !IsValidEdict(iEntity) || !IsValidEntity(iEntity) ) {
            continue;
        }
        
        // We found a melee
        if ( IsMelee(iEntity) ) {
            // Remove them from the safe room
            if ( bNoMeleeInSafe && LGO_IsEntityInSaferoom(iEntity, 3) ) {
                RemoveMelee(iEntity);
                continue;
            }
            
            // If we're imposing melee limits
            if ( iMeleeLimit >= 0 ) {
                // Remove melees past the limit
                if ( count >= iMeleeLimit ) {
                    RemoveMelee(iEntity);
                }
                else {
                    count++;
                }
            }
        }
    }
}
