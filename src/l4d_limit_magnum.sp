#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define FLAG_COUNT          (1<<3)
#define WEAPON_MAGNUM_ID    32

new iMagnumLimit = 1;

new Handle:cvar_magnumLimit;

public Plugin:myinfo =
{
    name        = "L4D2 Limit Magnum",
    author      = "Jahze",
    version     = "1.0",
    description = "Limits the number of magnums per weapon spawn"
}

public OnPluginStart() {
    cvar_magnumLimit = CreateConVar("l4d_magnum_limit", "1", "Number of magnums available at a magnum spawn", FCVAR_PLUGIN);
    HookConVarChange(cvar_magnumLimit, MagnumLimitChange);
    
    PluginEnable();
}

public OnPluginEnd() {
    PluginDisable();
}

public MagnumLimitChange( Handle:cvar, const String:oldValue[], const String:newValue[] ) {
    iMagnumLimit = StringToInt(newValue);
    
    if ( iMagnumLimit > 4 ) {
        iMagnumLimit = 4;
    }
    else if ( iMagnumLimit < -1 ) {
        iMagnumLimit = -1;
    }
}

PluginEnable() {
    HookEvent("round_start", MagnumLimitRoundStart);
}

PluginDisable() {
    UnhookEvent("round_start", MagnumLimitRoundStart);
}

public Action:MagnumLimitRoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
    CreateTimer(1.0, MagnumLimitDelay);
}

public Action:MagnumLimitDelay( Handle:timer ) {
    decl String:count[16];
    new iEntity = -1;
    
    if ( iMagnumLimit == -1 ) {
        return;
    }
    
    IntToString(iMagnumLimit, count, sizeof(count));
    
    while ( (iEntity = FindEntityByClassname(iEntity, "weapon_pistol_magnum_spawn")) != -1 ) {
        LimitMagnum(iEntity, count);
    }
    
    iEntity = -1;
    
    while ( (iEntity = FindEntityByClassname(iEntity, "weapon_spawn")) != -1 ) {
        if ( GetEntProp(iEntity, Prop_Send, "m_weaponID") == WEAPON_MAGNUM_ID ) {
            LimitMagnum(iEntity, count);
        }
    }
}

LimitMagnum( iEntity, const String:count[] ) {
    DispatchKeyValue(iEntity, "count", count);
            
    new iFlags = GetEntityFlags(iEntity);
    
    LogMessage("[Deathwish] Found a magnum spawn with flags %d", iFlags);
    if ( iFlags & FLAG_COUNT ) {
        SetEntityFlags(iEntity, iFlags ^ FLAG_COUNT);
    }
}
