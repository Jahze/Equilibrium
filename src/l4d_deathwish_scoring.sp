#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4downtown>

const TANK_ZOMBIE_CLASS = 8;

enum L4D2Team {
    L4D2Team_Unknown    = 0,
    L4D2Team_Spectator  = 1,
    L4D2Team_Survivor   = 2,
    L4D2Team_Infected   = 3
}

new bool:bSecondRound;
new bool:bTankAlive;

new iSaferoomDoor;
new iDistance;
new iTankFlow;

new Handle:cvar_deathwishScoring;

new String:sTankFlowMsg[128];

public Plugin:myinfo = {
    name        = "L4D2 Deathwish Scoring",
    author      = "Jahze",
    version     = "2.0",
    description = "Changes default L4D2 scoring to deathwish style"
};

public OnPluginStart() {
    cvar_deathwishScoring = CreateConVar("l4d_deathwish_scoring", "1", "Changes default L4D2 scoring to deathwish style", FCVAR_PLUGIN);
    HookConVarChange(cvar_deathwishScoring, DeathwishScoringChange);
    
    RegConsoleCmd("sm_tank", TankCmd);
    
    PluginEnable();
}

public OnPluginEnd() {
    PluginDisable();
}

public OnMapStart() {
    iTankFlow       = 0;
    bSecondRound    = false;
    iDistance       = L4D_GetVersusMaxCompletionScore();
    sTankFlowMsg[0] = 0;
}

public OnMapEnd() {
    bSecondRound = false;
}

PluginEnable() {
    HookEvent("round_start", DeathwishRoundStart);
    HookEvent("round_end", DeathwishRoundEnd);
    HookEvent("tank_spawn", DeathwishTankSpawn);
    HookEvent("player_death", DeathwishTankKilled);
    HookEvent("player_use", DeathwishSaferoomDoor);
    HookEvent("player_left_start_area", DeathwishPlayerLeftStartArea);
    
    LogMessage("[Deathwish] Plugin enabled");
}

PluginDisable() {
    UnhookEvent("round_start", DeathwishRoundStart);
    UnhookEvent("round_end", DeathwishRoundEnd);
    UnhookEvent("tank_spawn", DeathwishTankSpawn);
    UnhookEvent("player_death", DeathwishTankKilled);
    UnhookEvent("player_use", DeathwishSaferoomDoor);
    UnhookEvent("player_left_start_area", DeathwishPlayerLeftStartArea);
    
    LogMessage("[Deathwish] Plugin disabled");
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

public Action:DeathwishPlayerLeftStartArea( Handle:event, const String:name[], bool:dontBroadcast ) {
    if ( !bSecondRound ) {    
        decl Float:tankFlows[2];
        
        // XXX: minus by 5% as tank spawns at this position when survivors are a bit earlier
        L4D2_GetVersusTankFlowPercent(tankFlows);
        iTankFlow = RoundToNearest((tankFlows[0] * 100.0) - 5.0);
        
        Format(sTankFlowMsg, sizeof(sTankFlowMsg), "[Deathwish] The tank will spawn at %d%s through the map.", iTankFlow, "%%");
        PrintHintTextToAll(sTankFlowMsg);
    }
}

public Action:DeathwishRoundEnd( Handle:event, const String:name[], bool:dontBroadcast ) {
    bSecondRound = true;
}

public Action:DeathwishTankSpawn( Handle:event, const String:name[], bool:dontBroadcast ) {
    if ( !bTankAlive ) {
        bTankAlive = true;
        L4D_SetVersusMaxCompletionScore(0);
    }
}

public Action:DeathwishTankKilled( Handle:event, const String:name[], bool:dontBroadcast ) {
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    
    if ( bTankAlive && client
    && GetClientTeam(client) == L4D2Team_Infected
    && GetEntProp(client, Prop_Send, "m_zombieClass") == TANK_ZOMBIE_CLASS ) {
        bTankAlive = false;
        
        L4D_SetVersusMaxCompletionScore(iDistance);
    }
}

public Action:DeathwishSaferoomDoor( Handle:event, const String:name[], bool:dontBroadcast ) {
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    new iEntity = GetEventInt(event, "targetid");
    
    if ( IsValidEntity(iEntity) && iEntity == iSaferoomDoor ) {
        if ( bTankAlive ) {
            LockSaferoomDoor();
            PrintToChat(client, "[Deathwish] The tank must be killed before entering the saferoom.");
        }
        else {
            UnlockSaferoomDoor();
        }
    }
    
    return Plugin_Continue;
}

CloseSaferoomDoor() {
    new iEntity = -1;
    
    while ( (iEntity = FindEntityByClassname(iEntity, "prop_door_rotating_checkpoint")) != -1 ) {
        if ( GetEntProp(iEntity, Prop_Data, "m_hasUnlockSequence") == 0 ) {
            iSaferoomDoor = iEntity;
            LockSaferoomDoor();
        }
    }
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

public Action:TankCmd(client, args) {
    if ( strlen(sTankFlowMsg) ) {
        ReplyToCommand(client, sTankFlowMsg);
    }
}

