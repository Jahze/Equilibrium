#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4downtown>
#include <mapinfo>

static const String:DEATHWISH_GAMEDATA[]        = "deathwish";

static const String:INFECTED_CLASS[]            = "infected";

static const String:PLAYER_FLOW_FUNCTION[]      = "CTerrorPlayer_GetFlowDistance";
static const String:INFECTED_FLOW_FUNCTION[]    = "Infected_GetFlowDistance";

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
new iMaxDistance = 4;
new iScores[2];
new iLastScores[2];
new iScoreTeams[4];
new iSurvivorScores[4];
new iBonusPoints;

new bool:bRoundEnded;
new bool:bSecondRound;
new bool:bRoundStarted;

new Float:flMaxFlow;

new Handle:cvar_deathwishScoring;
new Handle:cvar_deathwishDistance;

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
//  - use AreTeamsFlipped() (see srsmod)

public OnPluginStart() {
    PrepSDKCalls();
    
    cvar_deathwishScoring = CreateConVar("l4d_deathwish_scoring", "1", "Changes default L4D2 scoring to deathwish style", FCVAR_PLUGIN);
    HookConVarChange(cvar_deathwishScoring, DeathwishScoringChange);

    cvar_deathwishDistance = CreateConVar("l4d_deathwish_distance", "4", "Distance points a survivor can get", FCVAR_PLUGIN);
    HookConVarChange(cvar_deathwishDistance, DeathwishDistanceChange);

    PluginEnable();
    
    //RegConsoleCmd("saferoom", TeleportToSaferoom, "Teleports a player to the saferoom");
    //RegConsoleCmd("myflow", PrintFlowToClient, "Prints a player's flow to them");
    
    iScoreTeams[L4D2Team_Survivor] = L4D2_TeamA;
    iScoreTeams[L4D2Team_Infected] = L4D2_TeamB;    
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
    }
    
    flMaxFlow           = LGO_GetMapValueFloat("max_flow")*0.95;
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
    
    timer_setScores = CreateTimer(3.0, DeathwishSetScores, _, TIMER_REPEAT);
    LogMessage("[Deathwish] Plugin enabled");
}

PluginDisable() {
    UnhookEvent("player_death", DeathwishPlayerDeath);
    UnhookEvent("round_start", DeathwishRoundStart);
    UnhookEvent("round_end", DeathwishRoundEnd);
    UnhookEvent("door_close", DeathwishDoorClose);
    UnhookEvent("player_left_start_area", DeathwishPlayerLeftStartArea);
    
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

GetSurvivorPoints(client) {
    new Float:flow      = L4D2_GetPlayerFlowDistance(client);
    new Float:fDistance = (flow/flMaxFlow) * (iMaxDistance);
    new iDistance       = RoundToFloor(fDistance);
    
    iDistance = iDistance < 0 ? 0 : iDistance;
    
    return iDistance > iMaxDistance ? iMaxDistance : iDistance;
}

CalculateScores() {
    for ( new i = 1; i <= MaxClients; i++ ) {
        if ( IsClientInGame(i)
        && GetClientTeam(i) == L4D2Team_Survivor
        && IsPlayerAlive(i) ) {
            new index = GetEntProp(i, Prop_Send, "m_survivorCharacter");
            new currentPoints = GetSurvivorPoints(i);
            if ( currentPoints > iSurvivorScores[index] ) {
                iSurvivorScores[index] = currentPoints;
                PrintToChat(i, "[Deathwish] You have received a distance point for reaching %d%%.", currentPoints*25); 
            }
        }
    }
    
    iScores[iScoreTeams[L4D2Team_Survivor]] = iLastScores[iScoreTeams[L4D2Team_Survivor]]
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
            
            new points = GetSurvivorPoints(i);
            new Float:flow = L4D2_GetPlayerFlowDistance(i);
            
            LogMessage("[Deathwish] %s's flow is %f (%d)", name, flow, points);
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
    new index = GetEntProp(client, Prop_Send, "m_survivorCharacter");
    new currentPoints = GetSurvivorPoints(client);
    if ( currentPoints > iSurvivorScores[index] ) {
        iSurvivorScores[index] = currentPoints;
    }
    
    PrintFlows();
}

public Action:DeathwishRoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
    L4D_SetVersusMaxCompletionScore(0);
    
    bRoundEnded         = false;
    iBonusPoints        = 0;
    iSurvivorScores[0]  = 0;
    iSurvivorScores[1]  = 0;
    iSurvivorScores[2]  = 0;
    iSurvivorScores[3]  = 0;
    
    if ( bSecondRound ) {
        SwitchScoreTeams();
    }
}

public Action:DeathwishPlayerLeftStartArea( Handle:event, const String:name[], bool:dontBroadcast ) {
    bRoundStarted = true;
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
        PrintFlows();
    }
}

public Action:DeathwishSetScores( Handle:timer ) {
    if ( bRoundStarted && !bRoundEnded ) {
        CalculateScores();
        L4D2_SetVersusCampaignScores(iScores);
        RedrawHUD();
    }
    
    return Plugin_Continue;
}

RedrawHUD() {
    if ( scoresHUD != INVALID_HANDLE ) {
        CloseHandle(scoresHUD);
    }
    
    scoresHUD = CreatePanel();
    
    decl String:scoresString[64];
    Format(scoresString, sizeof(scoresString), "%d - %d", iScores[0], iScores[1]);
    DrawPanelText(scoresHUD, scoresString);
    
    for ( new client = 1; client <= MaxClients; client++ ) {
        if ( IsClientInGame(client) && !IsFakeClient(client) ) {
            SendPanelToClient(scoresHUD, client, MenuHandlerHUD, 3);
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
}
