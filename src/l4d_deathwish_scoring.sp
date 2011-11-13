#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4downtown>

const TANK_ZOMBIE_CLASS = 8;

new bool:bSecondRound;
new bool:bTankAlive;

new iSaferoomDoor;
new iDistance;

new Handle:cvar_deathwishScoring;

public Plugin:myinfo = {
    name        = "L4D2 Deathwish Scoring",
    author      = "Jahze",
    version     = "2.0",
    description = "Changes default L4D2 scoring to deathwish style"
};

public OnPluginStart() {
    cvar_deathwishScoring = CreateConVar("l4d_deathwish_scoring", "1", "Changes default L4D2 scoring to deathwish style", FCVAR_PLUGIN);
    HookConVarChange(cvar_deathwishScoring, DeathwishScoringChange);
    
    PluginEnable();
}

public OnPluginEnd() {
    PluginDisable();
}

public OnMapStart() {
    bSecondRound = false;
}

PluginEnable() {
    HookEvent("round_start", DeathwishRoundStart);
    HookEvent("round_end", DeathwishRoundEnd);
    HookEvent("tank_spawn", DeathwishTankSpawn);
    HookEvent("player_death", DeathwishTankKilled);
    HookEvent("player_use", DeathwishSaferoomDoor);
}

PluginDisable() {
    UnhookEvent("round_start", DeathwishRoundStart);
    UnhookEvent("round_end", DeathwishRoundEnd);
    UnhookEvent("tank_spawn", DeathwishTankSpawn);
    UnhookEvent("player_death", DeathwishTankKilled);
    UnhookEvent("player_use", DeathwishSaferoomDoor);
}

public DeathwishScoringChange( Handle:cvar, const String:oldValue[], const String:newValue[] ) {
    if ( StringToInt(newValue) == 0 ) {
        PluginDisable();
    }
    else {
        PluginEnable();
    }
}

public Action:DeathwishRoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
    bTankAlive = false;
    
    iSaferoomDoor = -1;
    CloseSaferoomDoor();
    
    if ( bSecondRound ) {
        L4D_SetVersusMaxCompletionScore(iDistance);
    }
}

public Action:DeathwishRoundEnd( Handle:event, const String:name[], bool:dontBroadcast ) {
    bSecondRound = true;
}

public Action:DeathwishTankSpawn( Handle:event, const String:name[], bool:dontBroadcast ) {
    if ( !bTankAlive ) {
        bTankAlive = true;
        iDistance  = L4D_GetVersusMaxCompletionScore();
        L4D_SetVersusMaxCompletionScore(0);
    }
}

public Action:DeathwishTankKilled( Handle:event, const String:name[], bool:dontBroadcast ) {
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    
    if ( bTankAlive && IsTank(client) ) {
        CreateTimer(0.1, TankKilledDelay);
    }
}

public Action:TankKilledDelay( Handle:timer ) {
    if ( FindTank() == -1 ) {
        bTankAlive = false;
        L4D_SetVersusMaxCompletionScore(iDistance);
        CreateTimer(3.0, UnlockDoorDelay);
    }
}

public Action:UnlockDoorDelay( Handle:timer ) {
    if ( IsValidEntity(iSaferoomDoor) ) {
        UnlockSaferoomDoor();
        iSaferoomDoor = -1;
    }
}

public Action:DeathwishSaferoomDoor( Handle:event, const String:name[], bool:dontBroadcast ) {
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    new iEntity = GetEventInt(event, "targetid");
    
    if ( IsValidEntity(iEntity) && iEntity == iSaferoomDoor ) {
        if ( bTankAlive ) {
            PrintToChat(client, "[Deathwish] The tank must be killed before entering the saferoom.");
        }
    }
    
    return Plugin_Continue;
}

CloseSaferoomDoor() {
    new iEntity = -1;
    
    while ( (iEntity = FindEntityByClassname(iEntity, "prop_door_rotating_checkpoint")) != -1 ) {
        if ( !IsSaferoomLocked(iEntity) ) {
            iSaferoomDoor = iEntity;
            LockSaferoomDoor();
        }
    }
}

bool:IsSaferoomLocked( iEntity ) {
    return bool:GetEntProp(iEntity, Prop_Data, "m_hasUnlockSequence");
}

LockSaferoomDoor() {
    AcceptEntityInput(iSaferoomDoor, "Close");
    AcceptEntityInput(iSaferoomDoor, "Lock");
    AcceptEntityInput(iSaferoomDoor, "ForceClosed");
    SetEntProp(iSaferoomDoor, Prop_Data, "m_hasUnlockSequence", 1);
}

UnlockSaferoomDoor() {
    SetEntProp(iSaferoomDoor, Prop_Data, "m_hasUnlockSequence", 0);
    AcceptEntityInput(iSaferoomDoor, "Unlock");
    AcceptEntityInput(iSaferoomDoor, "ForceClosed");
    AcceptEntityInput(iSaferoomDoor, "Open");
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
