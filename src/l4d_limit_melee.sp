#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <mapinfo>

new bool:bStoredMelees = false;
new bool:bNoMeleeInSafe = true;
new iMeleeLimit = 6;

new Handle:cvar_noMeleeInSafe;
new Handle:cvar_meleeLimit;

new Handle:hStoredMelees;

public Plugin:myinfo =
{
    name        = "L4D2 Limit Melee Weapons",
    author      = "Jahze",
    version     = "1.0",
    description = "Limit melee weapons"
}

public OnPluginStart() {
    cvar_noMeleeInSafe = CreateConVar("l4d_no_melee_saferoom", "1", "Remove melee weapons from the safe room", FCVAR_PLUGIN);
    HookConVarChange(cvar_noMeleeInSafe, NoMeleeInSafeChange);
    
    cvar_meleeLimit = CreateConVar("l4d_melee_limit", "6", "Limit maximum number of melee weapons per map (-1 for no limit)", FCVAR_PLUGIN);
    HookConVarChange(cvar_meleeLimit, MeleeLimitChange);
    
    PluginEnable();
}

public OnPluginEnd() {
    PluginDisable();
}

public OnMapStart() {
    bStoredMelees = false;
}

PluginDisable() {
    UnhookEvent("round_start", RoundStartHook);
    
    ClearArray(hStoredMelees);
    CloseHandle(hStoredMelees);
}

PluginEnable() {
    HookEvent("round_start", RoundStartHook);
    
    SetRandomSeed(RoundFloat(GetTime()));
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
    
    new Handle:hMelees = CreateArray();
    new Handle:hKeepMelees;
    decl iEntity, entcount;
    entcount = GetEntityCount();
    
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
            
            if ( iMeleeLimit == 0 ) {
                RemoveMelee(iEntity);
                continue;
            }
            
            // If we have stored melees then remove all but these
            if ( hStoredMelees ) {
                if ( !IsStoredMelee(iEntity) ) {
                    RemoveMelee(iEntity);
                }
            }
            else {
                PushArrayCell(hMelees, iEntity);
            }
        }
    }
    
    // If melees are already stored or we have less than the limit bail out
    new size = GetArraySize(hMelees);
    if ( bStoredMelees || size <= iMeleeLimit ) {
        ClearArray(hMelees);
        CloseHandle(hMelees);
        return;
    }
    
    // Randomly choose some melees to keep
    hKeepMelees = CreateArray();
    for ( new i = 0; i < iMeleeLimit; i++ ) {
        new keep = GetRandomInt(0, size-1);
        
        PushArrayCell(hKeepMelees, GetArrayCell(hMelees, keep));
        RemoveFromArray(hMelees, keep);
        size--;
    }
    
    // Remove extra melees
    for ( new i = 0; i < GetArraySize(hMelees); i++ ) {
        RemoveMelee(GetArrayCell(hMelees, i));
    }
    
    ClearArray(hMelees);
    CloseHandle(hMelees);
    
    // Store which melees we're keeping
    if ( hStoredMelees != INVALID_HANDLE ) {
        ClearArray(hStoredMelees);
    }
    else {
        hStoredMelees = CreateArray(3);
    }
    
    for ( new i = 0; i < GetArraySize(hKeepMelees); i++ ) {
        decl Float:fPos[3];
        GetEntPropVector(GetArrayCell(hKeepMelees, i), Prop_Send, "m_vecOrigin", fPos);
        PushArrayArray(hStoredMelees, fPos);
        LogMessage("[Deathwish] Melee at %f %f %f", fPos[0], fPos[1], fPos[2]);
    }
    
    ClearArray(hKeepMelees);
    CloseHandle(hKeepMelees);
    
    bStoredMelees = true;
}

bool:IsStoredMelee( iEntity ) {
    decl Float:fPos1[3], fPos2[3];
    GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fPos1);
    
    LogMessage("[Deathwish] Comparing melee at %f %f %f", fPos1[0], fPos1[1], fPos1[2]);
    
    for ( new i = 0; i < GetArraySize(hStoredMelees); i++ ) {
        GetArrayArray(hStoredMelees, i, fPos2);
        LogMessage("    [Deathwish] with melee at %f %f %f (%f)", fPos2[0], fPos2[1], fPos2[2], GetVectorDistance(fPos1, fPos2));
        if ( GetVectorDistance(fPos1, fPos2) < 1.0 ) {
            return true;
        }
    }
    
    return false;
}

