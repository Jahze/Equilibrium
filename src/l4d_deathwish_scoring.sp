#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4downtown>
#include <mapinfo>

static const String:DEATHWISH_GAMEDATA[]        = "deathwish";

static const String:INFECTED_CLASS[]            = "infected";

static const String:PLAYER_FLOW_FUNCTION[]      = "CTerrorPlayer_GetFlowDistance";
static const String:INFECTED_FLOW_FUNCTION[]    = "Infected_GetFlowDistance";

const TANK_ZOMBIE_CLASS                         = 8;

enum L4D2Team {
    L4D2Team_Unknown    = 0,
    L4D2Team_Spectator  = 1,
    L4D2Team_Survivor   = 2,
    L4D2Team_Infected   = 3
}

enum L4D2LogicalTeam {
    L4D2_TeamA = 0,
    L4D2_TeamB = 1
}

new iDefaultMapDistance;
new iMaxDistance = 10;
new iScores[2];
new iLastScores[2];
new iScoreTeams[4];
new iBonusPoints;

new iSurvivorScores[4];
new iSurvivorLastDistance[4];
new iSurvivalBonuses[4];

new bool:bRoundEnded;
new bool:bSecondRound;
new bool:bRoundStarted;
new bool:bTankAlive;

new Float:flMaxFlow;
new iTankFlow;
new iSaferoomDoor;

new Handle:cvar_deathwishScoring;
new Handle:cvar_deathwishDistance;
new Handle:cvar_survivalBonus;

new Handle:fPlayerGetFlowDistance;
new Handle:fGetInfFlowDistance;

new Handle:timer_setScores;

new Handle:scoresHUD;

public Plugin:myinfo = {
    name        = "L4D2 Deathwish Scoring",
    author      = "Jahze",
    version     = "1.0",
    description = "Changes default L4D2 scoring to deathwish style"
};

// Things to consider:
//  - tank + witch = bonus points

public OnPluginStart() {
    PrepSDKCalls();
    
    cvar_deathwishScoring = CreateConVar("l4d_deathwish_scoring", "1", "Changes default L4D2 scoring to deathwish style", FCVAR_PLUGIN);
    HookConVarChange(cvar_deathwishScoring, DeathwishScoringChange);

    cvar_deathwishDistance = CreateConVar("l4d_deathwish_distance", "10", "Distance points a survivor can get", FCVAR_PLUGIN);
    HookConVarChange(cvar_deathwishDistance, DeathwishDistanceChange);

    cvar_survivalBonus = FindConVar("vs_survival_bonus");
    
    PluginEnable();
    
    RegConsoleCmd("saferoom", TeleportToSaferoom, "Teleports a player to the saferoom");
    RegConsoleCmd("myflow", PrintFlowToClient, "Prints a player's flow to them");
    
    iScoreTeams[L4D2Team_Survivor] = L4D2_TeamA;
    iScoreTeams[L4D2Team_Infected] = L4D2_TeamB;    
}

public OnPluginEnd() {
    PluginDisable();
}

public OnMapStart() {
    decl mapName[128];
    
    GetCurrentMap(mapName,sizeof(mapName));
    if ( StrContains(mapName, "m1") != -1 ) {
        LogMessage("[Deathwish] Detected first map resetting to 0 - 0");
        iScores[0] = 0;
        iScores[1] = 0;
        iLastScores[0] = 0;
        iLastScores[1] = 0;
        iMaxDistance   = 5;
        iSurvivalBonuses[3] = 5;
        iSurvivalBonuses[2] = 4;
        iSurvivalBonuses[1] = 3;
        iSurvivalBonuses[0] = 2;
    }
    else {
        iMaxDistance = 10;
        iSurvivalBonuses[3] = 10;
        iSurvivalBonuses[2] = 8;
        iSurvivalBonuses[1] = 5;
        iSurvivalBonuses[0] = 4;
    }
    
    iTankFlow           = 0;
    flMaxFlow           = LGO_GetMapValueFloat("max_flow")*0.97;
    iMaxDistance        = LGO_GetMapValueInt("max_distance",iMaxDistance);
    iDefaultMapDistance = L4D_GetVersusMaxCompletionScore();
    bSecondRound        = false;
    bRoundStarted       = false;
    
    new scores[2];
    L4D2_GetVersusCampaignScores(scores);
    
    LogMessage("[Deathwish] map start, scores are: %d - %d (max flow: %f)", scores[0], scores[1], flMaxFlow);
    
    // If team B's score is higher then they must be survivor
    if ( scores[1] > scores[0] ) {
        iScoreTeams[L4D2Team_Survivor] = L4D2_TeamB;
        iScoreTeams[L4D2Team_Infected] = L4D2_TeamA;
    }
    // Scores are tied, so previous survivor team is going first
    else if ( scores[1] == scores[0] && StrContains(mapName, "m1") < 0 ) {
        SwitchScoreTeams();
    }
    // Survivor is Team A as they have higher score
    else {
        iScoreTeams[L4D2Team_Survivor] = L4D2_TeamA;
        iScoreTeams[L4D2Team_Infected] = L4D2_TeamB;
    }
        
}

public OnMapEnd() {
    bSecondRound = false;
}

PluginEnable() {
    HookEvent("player_death", DeathwishPlayerDeath);
    HookEvent("round_start", DeathwishRoundStart);
    HookEvent("round_end", DeathwishRoundEnd);
    HookEvent("door_close", DeathwishDoorClose);
    HookEvent("player_left_start_area", DeathwishPlayerLeftStartArea);
    HookEvent("tank_spawn", DeathwishTankSpawn);
    HookEvent("player_death", DeathwishTankKilled);
    HookEvent("player_use", DeathwishSaferoomDoor);
    
    timer_setScores = CreateTimer(3.0, DeathwishSetScores, _, TIMER_REPEAT);
    LogMessage("[Deathwish] Plugin enabled");
}

PluginDisable() {
    UnhookEvent("player_death", DeathwishPlayerDeath);
    UnhookEvent("round_start", DeathwishRoundStart);
    UnhookEvent("round_end", DeathwishRoundEnd);
    UnhookEvent("door_close", DeathwishDoorClose);
    UnhookEvent("player_left_start_area", DeathwishPlayerLeftStartArea);
    UnhookEvent("tank_spawn", DeathwishTankSpawn);
    UnhookEvent("player_death", DeathwishTankKilled);
    UnhookEvent("player_use", DeathwishSaferoomDoor);
    
    L4D_SetVersusMaxCompletionScore(iDefaultMapDistance);
    
    KillTimer(timer_setScores);
    LogMessage("[Deathwish] Plugin disabled");
}

PrepSDKCalls() {
    new Handle:gameData = LoadGameConfigFile(DEATHWISH_GAMEDATA);
    
    if ( gameData == INVALID_HANDLE ) {
        ThrowError("[Deathwish] Gamedata could not be loaded (%s.txt)", DEATHWISH_GAMEDATA);
    }
    
    StartPrepSDKCall(SDKCall_Entity);
    
    new bool:bGetInfFlowDistFuncLoaded = PrepSDKCall_SetFromConf(gameData, SDKConf_Signature, INFECTED_FLOW_FUNCTION);
    if (!bGetInfFlowDistFuncLoaded)    {
        ThrowError("[Deathwish] Could not load the GetInfectedFlowDistance signature");
    }
    
    PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
    fGetInfFlowDistance = EndPrepSDKCall();
    
    if (fGetInfFlowDistance == INVALID_HANDLE) {
        ThrowError("[Deathwish] Could not prep the GetInfectedFlowDistance function");    
    }
    
    StartPrepSDKCall(SDKCall_Player);
    
    new bool:bPGetFlowDistFuncLoaded = PrepSDKCall_SetFromConf(gameData, SDKConf_Signature, PLAYER_FLOW_FUNCTION);
    if ( !bPGetFlowDistFuncLoaded ) {
        ThrowError("[Deathwish] Could not load the PlayerGetFlowDistance signature");
    }
    
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
    PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
    fPlayerGetFlowDistance = EndPrepSDKCall();
    
    if (fPlayerGetFlowDistance == INVALID_HANDLE) {
        ThrowError("[Deathwish] Could not prep the PlayerGetFlowDistance function");
    }
}

static Float:L4D2_GetInfectedFlowDistance( entity ) {
    return SDKCall(fGetInfFlowDistance, entity);
}

static Float:L4D2_GetPlayerFlowDistance( client ) {
    return SDKCall(fPlayerGetFlowDistance, client, 0);
}

GetSurvivorDistance(client) {
    new Float:flow      = L4D2_GetPlayerFlowDistance(client);
    new Float:fDistance = (flow/flMaxFlow) * (iMaxDistance);
    new iDistance       = RoundToFloor(fDistance);
    
    iDistance = iDistance < 0 ? 0 : iDistance;
    
    return iDistance > iMaxDistance ? iMaxDistance : iDistance;
}

UpdateSurvivorScore(client) {
    new index = GetEntProp(client, Prop_Send, "m_survivorCharacter");
    new currentDistance = GetSurvivorDistance(client);
    new diff = currentDistance - iSurvivorLastDistance[index];
    if ( diff > 0 ) {
        new incaps = GetEntProp(client, Prop_Send, "m_currentReviveCount");
        new points = 2;
        
        if ( incaps ) {
            points--;
        }
        
        iSurvivorLastDistance[index] = currentDistance;
        iSurvivorScores[index] += diff * points;
        
        PrintToChat(client, "[Deathwish] You have received %d points for reaching %d%% with %d incaps.",
            diff*points, currentDistance*(100/iMaxDistance), incaps);
    }
}

CalculateScores() {
    for ( new i = 1; i <= MaxClients; i++ ) {
        if ( IsClientInGame(i)
        && GetClientTeam(i) == L4D2Team_Survivor
        && IsPlayerAlive(i) ) {
            UpdateSurvivorScore(i);
        }
    }
    
    new surv = iScoreTeams[L4D2Team_Survivor];
    iScores[surv] = iLastScores[surv]
        + iSurvivorScores[0] + iSurvivorScores[1] + iSurvivorScores[2]
        + iSurvivorScores[3] + iBonusPoints;
}

PrintFlows() {
    for ( new i = 1; i <= MaxClients; i++ ) {
        if ( IsClientInGame(i)
        && GetClientTeam(i) == L4D2Team_Survivor
        && IsPlayerAlive(i) ) {
            decl String:name[128];
            GetClientName(i, name, sizeof(name));
            
            new Float:flow = L4D2_GetPlayerFlowDistance(i);
            LogMessage("[Deathwish] %s's flow is %f", name, flow);
        }
    }
}

SwitchScoreTeams() {
    iScoreTeams[L4D2Team_Survivor] = !(iScoreTeams[L4D2Team_Survivor]);
    iScoreTeams[L4D2Team_Infected] = !(iScoreTeams[L4D2Team_Infected]);
}

public DeathwishScoringChange( Handle:cvar, const String:oldValue[], const String:newValue[] ) {
    if ( StringToInt(newValue) == 0 ) {
        PluginDisable();
    }
    else {
        PluginEnable();
    }
}

public DeathwishDistanceChange( Handle:cvar, const String:oldValue[], const String:newValue[] ) {
    iMaxDistance = StringToInt(newValue);
}

public Action:DeathwishPlayerDeath( Handle:event, const String:name[], bool:dontBroadcast ) {
    if ( bRoundEnded ) {
        return;
    }
    
    decl String:clientName[128];
    
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    GetClientName(client, clientName, sizeof(clientName));
    
    if ( !client || GetClientTeam(client) != L4D2Team_Survivor ) {
        return;
    }
    
    LogMessage("[Deathwish] %s died at %f flow", clientName, L4D2_GetPlayerFlowDistance(client));
    
    // Set a players max flow
    UpdateSurvivorScore(client);
    PrintFlows();
}

public Action:DeathwishRoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
    L4D_SetVersusMaxCompletionScore(0);
    
    bRoundEnded         = false;
    bTankAlive          = false;
    iBonusPoints        = 0;
    iSurvivorScores[0]  = 0;
    iSurvivorScores[1]  = 0;
    iSurvivorScores[2]  = 0;
    iSurvivorScores[3]  = 0;
    iSurvivorLastDistance[0] = 0;
    iSurvivorLastDistance[1] = 0;
    iSurvivorLastDistance[2] = 0;
    iSurvivorLastDistance[3] = 0;
    
    iSaferoomDoor = -1;
    CloseSaferoomDoor();
    
    if ( bSecondRound ) {
        SwitchScoreTeams();
    }
}

public Action:DeathwishPlayerLeftStartArea( Handle:event, const String:name[], bool:dontBroadcast ) {
    bRoundStarted = true;

    if ( !bSecondRound ) {    
        decl Float:tankFlows[2];
        
        // XXX: minus by 5% as tank spawns at this position when survivors are a bit earlier
        L4D2_GetVersusTankFlowPercent(tankFlows);
        iTankFlow = RoundToNearest((tankFlows[iScoreTeams[L4D2Team_Survivor]] * 100.0) - 5.0);
    }
}

public Action:DeathwishRoundEnd( Handle:event, const String:name[], bool:dontBroadcast ) {
    // Read in scores for survival bonus
    L4D2_GetVersusCampaignScores(iLastScores);
    
    iScores[0] = iLastScores[0];
    iScores[1] = iLastScores[1];
    
    LogMessage("[Deathwish] round end, scores are: %d - %d", iScores[0], iScores[1]);
    
    bSecondRound = true;
    bRoundStarted = false;
    bRoundEnded = true;
}

public Action:DeathwishDoorClose( Handle:event, const String:name[], bool:dontBroadcast ) {
    if ( GetEventBool(event, "checkpoint") ) {
        TriggerTimer(timer_setScores);
        SetSurvivalBonus();
        PrintFlows();
    }
}

public Action:DeathwishTankSpawn( Handle:event, const String:name[], bool:dontBroadcast ) {
    if ( !bTankAlive ) {
        TriggerTimer(timer_setScores);
    }
    bTankAlive = true;
}

public Action:DeathwishTankKilled( Handle:event, const String:name[], bool:dontBroadcast ) {
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    
    if ( bTankAlive && client
    && GetClientTeam(client) == L4D2Team_Infected
    && GetEntProp(client, Prop_Send, "m_zombieClass") == TANK_ZOMBIE_CLASS ) {
        bTankAlive = false;
    }
}

public Action:DeathwishSaferoomDoor( Handle:event, const String:name[], bool:dontBroadcast ) {
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    new iEntity = GetEventInt(event, "targetid");
    decl String:className[128];
    
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
    
public Action:DeathwishSetScores( Handle:timer ) {
    if ( bRoundStarted && !bRoundEnded && !bTankAlive ) {
        CalculateScores();
        L4D2_SetVersusCampaignScores(iScores);
        RedrawHUD(0);
    }
    else if ( bRoundStarted && bTankAlive ) {
        RedrawHUD(L4D2Team_Survivor);
    }
    
    
    return Plugin_Continue;
}

SetSurvivalBonus() {
    new count = 0;
    
    for ( new i = 1; i <= MaxClients; i++ ) {
        if ( IsClientInGame(i) && GetClientTeam(i) == L4D2Team_Survivor && IsPlayerAlive(i) ) {
            count++;
        }
    }
    
    SetConVarInt(cvar_survivalBonus, iSurvivalBonuses[(count-1)%3]);
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

RedrawHUD(team) {
    if ( scoresHUD != INVALID_HANDLE ) {
        CloseHandle(scoresHUD);
    }
    
    scoresHUD = CreatePanel();
    
    decl String:scoresString[64];
    Format(scoresString, sizeof(scoresString), "%d - %d (%d%%)", iScores[0], iScores[1], iTankFlow);
    DrawPanelText(scoresHUD, scoresString);
    
    for ( new client = 1; client <= MaxClients; client++ ) {
        if ( IsClientInGame(client) && !IsFakeClient(client) ) {
            if ( !team || GetClientTeam(client) == team ) {
                SendPanelToClient(scoresHUD, client, MenuHandlerHUD, 3);
            }
        }
    }
}

public MenuHandlerHUD( Handle:menu, MenuAction:action, param1, param2 ) {
}

public Action:TeleportToSaferoom(client, args) {
    new Float:safeRoomPos[3];
    
    LGO_GetMapValueVector("end_point", safeRoomPos);
    TeleportEntity(client, safeRoomPos, NULL_VECTOR, NULL_VECTOR);
}

public Action:PrintFlowToClient(client, args) {
    decl String:flow[128];
    
    Format(flow, sizeof(flow), "[Deathwish] Your flow is %f.", L4D2_GetPlayerFlowDistance(client));
    ReplyToCommand(client, flow);
    
    new Handle:file = OpenFile("flows.txt", "a");
    decl String:mapName[128];
    GetCurrentMap(mapName, sizeof(mapName));
    WriteFileLine(file, "%s flow: %f", mapName, L4D2_GetPlayerFlowDistance(client));
    CloseHandle(file);
}
