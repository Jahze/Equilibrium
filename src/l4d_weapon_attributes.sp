#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <left4downtown>

#define MAX_ATTRS           19
#define TANK_ZOMBIE_CLASS   8

public Plugin:myinfo =
{
    name        = "L4D2 Weapon Attributes",
    author      = "Jahze",
    version     = "1.0",
    description = "Allowing tweaking of the attributes of all weapons"
};

new iWeaponAttributes[MAX_ATTRS] = {
    L4D2IWA_Damage,
    L4D2IWA_Bullets,
    L4D2IWA_ClipSize,
    L4D2FWA_MaxPlayerSpeed,
    L4D2FWA_SpreadPerShot,
    L4D2FWA_MaxSpread,
    L4D2FWA_SpreadDecay,
    L4D2FWA_MinDuckingSpread,
    L4D2FWA_MinStandingSpread,
    L4D2FWA_MinInAirSpread,
    L4D2FWA_MaxMovementSpread,
    L4D2FWA_PenetrationNumLayers,
    L4D2FWA_PenetrationPower,
    L4D2FWA_PenetrationMaxDist,
    L4D2FWA_CharPenetrationMaxDist,
    L4D2FWA_Range,
    L4D2FWA_RangeModifier,
    L4D2FWA_CycleTime,
    -1
};

new String:sWeaponAttrNames[MAX_ATTRS][32] = {
    "Damage",
    "Bullets",
    "Clip Size",
    "Max player speed",
    "Spread per shot",
    "Max spread",
    "Spread decay",
    "Min ducking spread",
    "Min standing spread",
    "Min in air spread",
    "Max movement spread",
    "Penetraion num layers",
    "Penetration power",
    "Penetration max dist",
    "Char penetration max dist",
    "Range",
    "Range modifier",
    "Cycle time",
    "Tank damage multiplier"
};

new String:sWeaponAttrShortName[MAX_ATTRS][32] = {
    "damage",
    "bullets",
    "clipsize",
    "speed",
    "spreadpershot",
    "maxspread",
    "spreaddecay",
    "minduckspread",
    "minstandspread",
    "minairspread",
    "maxmovespread",
    "penlayers",
    "penpower",
    "penmaxdist",
    "charpenmaxdist",
    "range",
    "rangemod",
    "cycletime",
    "tankdamagemult"
};

new iTankClient = -1;

new bool:bHooked = false;
new bool:bTankSpawned = false;
new Handle:hTankDamageKVs;

public OnPluginStart() {
    RegServerCmd("sm_weapon", Weapon);
    RegConsoleCmd("sm_weapon_attributes", WeaponAttributes);
    
    hTankDamageKVs = CreateKeyValues("DamageVsTank");
    
    HookEvents();
}

public OnPluginEnd() {
    if ( hTankDamageKVs != INVALID_HANDLE ) {
        CloseHandle(hTankDamageKVs);
        hTankDamageKVs = INVALID_HANDLE;
    }
    
    UnhookEvents();
}

HookEvents() {
    if ( !bHooked ) {
        HookEvent("tank_spawn", TankSpawned);
        HookEvent("player_death", PlayerDeath);
        HookEvent("round_start", RoundStart);
        bHooked = true;
    }
}

UnhookEvents() {
    if ( bHooked ) {
        UnhookEvent("tank_spawn", TankSpawned);
        UnhookEvent("player_death", PlayerDeath);
        UnhookEvent("round_start", RoundStart);
        bHooked = false;
    }
}

GetWeaponAttributeIndex( String:sAttrName[128] ) {
    for ( new i = 0; i < MAX_ATTRS; i++ ) {
        if ( StrEqual(sAttrName, sWeaponAttrShortName[i]) ) {
            return i;
        }
    }
    
    return -1;
}

GetWeaponAttributeInt( const String:sWeaponName[], idx ) {
    return L4D2_GetIntWeaponAttribute(sWeaponName, iWeaponAttributes[idx]);
}

Float:GetWeaponAttributeFloat( const String:sWeaponName[], idx ) {
    return L4D2_GetFloatWeaponAttribute(sWeaponName, iWeaponAttributes[idx]);
}

SetWeaponAttributeInt( const String:sWeaponName[], idx, value ) {
    L4D2_SetIntWeaponAttribute(sWeaponName, iWeaponAttributes[idx], value);
}

SetWeaponAttributeFloat( const String:sWeaponName[], idx, Float:value ) {
    L4D2_SetFloatWeaponAttribute(sWeaponName, iWeaponAttributes[idx], value);
}

public Action:Weapon( args ) {
    new iValue;
    new Float:fValue;
    new iAttrIdx;
    decl String:sWeaponName[128];
    decl String:sWeaponNameFull[128];
    decl String:sAttrName[128];
    decl String:sAttrValue[128];
    
    if ( GetCmdArgs() < 3 ) {
        PrintToServer("Syntax: sm_weapon <weapon> <attr> <value>");
        return;
    }

    GetCmdArg(1, sWeaponName, sizeof(sWeaponName));
    GetCmdArg(2, sAttrName, sizeof(sAttrName));
    GetCmdArg(3, sAttrValue, sizeof(sAttrValue));

    if ( L4D2_IsValidWeapon(sWeaponName) ) {
        PrintToServer("Bad weapon name: %s", sWeaponName);
        return;
    }

    iAttrIdx = GetWeaponAttributeIndex(sAttrName);
    
    if ( iAttrIdx == -1 ) {
        PrintToServer("Bad attribute name: %s", sAttrName);
        return;
    }
    
    sWeaponNameFull[0] = 0;
    StrCat(sWeaponNameFull, sizeof(sWeaponNameFull), "weapon_");
    StrCat(sWeaponNameFull, sizeof(sWeaponNameFull), sWeaponName);
    
    iValue = StringToInt(sAttrValue);
    fValue = StringToFloat(sAttrValue);
    
    if ( iAttrIdx < 3 ) {
        SetWeaponAttributeInt(sWeaponNameFull, iAttrIdx, iValue);
        PrintToServer("%s for %s set to %d", sWeaponAttrNames[iAttrIdx], sWeaponName, iValue);
    }
    else if ( iAttrIdx < MAX_ATTRS-1 ) {
        SetWeaponAttributeFloat(sWeaponNameFull, iAttrIdx, fValue);
        PrintToServer("%s for %s set to %.2f", sWeaponAttrNames[iAttrIdx], sWeaponName, fValue);
    }
    else {
        KvSetFloat(hTankDamageKVs, sWeaponNameFull, fValue);
        PrintToServer("%s for %s set to %.2f", sWeaponAttrNames[iAttrIdx], sWeaponName, fValue);
    }
}

public Action:WeaponAttributes( client, args ) {
    decl String:sWeaponName[128];
    decl String:sWeaponNameFull[128];
    
    if ( GetCmdArgs() < 1 ) {
        ReplyToCommand(client, "Syntax: sm_weapon_attributes <weapon>");
        return;
    }
    
    GetCmdArg(1, sWeaponName, sizeof(sWeaponName));
    
    if ( L4D2_IsValidWeapon(sWeaponName) ) {
        ReplyToCommand(client, "Bad weapon name: %s", sWeaponName);
        return;
    }

    sWeaponNameFull[0] = 0;
    StrCat(sWeaponNameFull, sizeof(sWeaponNameFull), "weapon_");
    StrCat(sWeaponNameFull, sizeof(sWeaponNameFull), sWeaponName);
    
    ReplyToCommand(client, "Weapon stats for %s", sWeaponName);
    
    for ( new i = 0; i < 3; i++ ) {
        new iValue = GetWeaponAttributeInt(sWeaponNameFull, i);
        ReplyToCommand(client, "%s: %d", sWeaponAttrNames[i], iValue);
    }
    
    for ( new i = 3; i < MAX_ATTRS-1; i++ ) {
        new Float:fValue = GetWeaponAttributeFloat(sWeaponNameFull, i);
        ReplyToCommand(client, "%s: %.2f", sWeaponAttrNames[i], fValue);
    }
    
    new Float:fBuff = KvGetFloat(hTankDamageKVs, sWeaponNameFull, 0.0);
    
    if ( fBuff ) {
        ReplyToCommand(client, "%s: %.2f", sWeaponAttrNames[MAX_ATTRS-1], fBuff);
    }
}

public Action:RoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
    bTankSpawned = false;
    iTankClient = -1;
}

public Action:TankSpawned( Handle:event, const String:name[], bool:dontBroadcast ) {
    if ( !bTankSpawned ) {
        iTankClient = GetClientOfUserId(GetEventInt(event, "userid"));
        SDKHook(iTankClient, SDKHook_OnTakeDamage, DamageBuffVsTank);
        bTankSpawned = true;
    }
}

public Action:PlayerDeath( Handle:event, const String:name[], bool:dontBroadcast ) {
    if ( bTankSpawned && iTankClient == GetClientOfUserId(GetEventInt(event, "userid")) ) {
        CreateTimer(0.1, FindTankDelay);
    }
}

public Action:FindTankDelay( Handle:timer ) {
    iTankClient = FindTank();
    
    if ( iTankClient != -1 ) {
        SDKHook(iTankClient, SDKHook_OnTakeDamage, DamageBuffVsTank);
    }
    else {
        bTankSpawned = false;
    }
}

public Action:DamageBuffVsTank( victim, &attacker, &inflictor, &Float:damage, &damageType, &weapon, Float:damageForce[3], Float:damagePosition[3] ) {
    if ( !attacker ) {
        return Plugin_Continue;
    }
    
    if ( !IsTank(victim) ) {
        SDKUnhook(victim, SDKHook_OnTakeDamage, DamageBuffVsTank);
        return Plugin_Continue;
    }
    
    decl String:sWeaponName[128];
    GetClientWeapon(attacker, sWeaponName, sizeof(sWeaponName));
    new Float:fBuff = KvGetFloat(hTankDamageKVs, sWeaponName, 0.0);
    
    if ( !fBuff ) {
        return Plugin_Continue;
    }
    
    damage *= fBuff;
    
    return Plugin_Changed;
}

FindTank() {
    for ( new i = 1; i <= MaxClients; i++ ) {
        if ( IsTank(i) ) {
            return i;
        }
    }
    
    return -1;
}

bool:IsTank( client ) {
    if ( client < 0
    || !IsClientConnected(client)
    || !IsClientInGame(client)
    || GetClientTeam(client) != 3
    || !IsPlayerAlive(client) ) {
        return false;
    }
    
    new playerClass = GetEntProp(client, Prop_Send, "m_zombieClass");
    
    if ( playerClass == TANK_ZOMBIE_CLASS ) {
        return true;
    }
    
    return false;
}

