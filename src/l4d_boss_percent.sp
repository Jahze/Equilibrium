#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <l4d2_direct>
#include <l4d2lib>
#undef REQUIRE_PLUGIN
#include <l4d2util>
#define REQUIRE_PLUGIN
#include <left4downtown>

public Plugin:myinfo = {
    name = "L4D2 Boss Flow Announce",
    author = "ProdigySim, Jahze",
    version = "1.0",
    description = "Announce boss flow percents!"
};

new Handle:g_hVsBossBuffer;
new Handle:g_hVsBossFlowMax;
new Handle:g_hVsBossFlowMin;

public OnPluginStart() {
    g_hVsBossBuffer = FindConVar("versus_boss_buffer");
    g_hVsBossFlowMax = FindConVar("versus_boss_flow_max");
    g_hVsBossFlowMin = FindConVar("versus_boss_flow_min");
    
    RegConsoleCmd("sm_boss", BossCmd);
    RegConsoleCmd("sm_tank", BossCmd);
    RegConsoleCmd("sm_witch", BossCmd);
    
    HookEvent("player_left_start_area", EventHook:LeftStartAreaEvent, EventHookMode_PostNoCopy);
    HookEvent("round_start", EventHook:RoundStartEvent, EventHookMode_PostNoCopy);
}

public LeftStartAreaEvent( ) {
    new roundNumber = InSecondHalfOfRound() ? 1 : 0;
    
    if (L4D2Direct_GetVSTankToSpawnThisRound(roundNumber)) {
        PrintToChatAll("Tank spawn: %d%%", RoundToNearest(GetTankFlow(roundNumber)*100));
    }
    
    if (L4D2Direct_GetVSWitchToSpawnThisRound(roundNumber)) {
        PrintToChatAll("Witch spawn: %d%%", RoundToNearest(GetWitchFlow(roundNumber)*100));
    }
}


public RoundStartEvent() {
    AdjustBossFlow();
}

PrintBossPercents(client, iTankPercent, iWitchPercent) {
    if (iTankPercent != 0) {
        ReplyToCommand(client, "Tank spawn: %d%%", iTankPercent);
    }
    
    if (iWitchPercent != 0) {
        ReplyToCommand(client, "Witch spawn: %d%%", iWitchPercent);
    }
}

public Action:BossCmd(client, args) {
    new roundNumber = InSecondHalfOfRound() ? 1 : 0;
    new iTankPercent = 0;
    new iWitchPercent = 0;
    
    if (L4D2Direct_GetVSTankToSpawnThisRound(roundNumber)) {
        iTankPercent = RoundToNearest(GetTankFlow(roundNumber)*100);
    }
    
    if (L4D2Direct_GetVSWitchToSpawnThisRound(roundNumber)) {
        iWitchPercent = RoundToNearest(GetWitchFlow(roundNumber)*100);
    }
    
    new L4D2_Team:iTeam = L4D2_Team:GetClientTeam(client);
    if (iTeam == L4D2Team_Spectator) {
        PrintBossPercents(client, iTankPercent, iWitchPercent);
        return;
    }
    
    for (new i = 1; i < MaxClients+1; i++) {
        if (IsClientConnected(i) && L4D2_Team:GetClientTeam(i) == iTeam) {
            PrintBossPercents(i, iTankPercent, iWitchPercent);
        }
    }
}

Float:GetTankFlow(round) {
    return L4D2Direct_GetVSTankFlowPercent(round) -
        ( Float:GetConVarInt(g_hVsBossBuffer) / L4D2Direct_GetMapMaxFlowDistance() );
}

Float:GetWitchFlow(round) {
    return L4D2Direct_GetVSWitchFlowPercent(round) -
        ( Float:GetConVarInt(g_hVsBossBuffer) / L4D2Direct_GetMapMaxFlowDistance() );
}

AdjustBossFlow() {
    new iMinFlow = L4D2_GetMapValueInt("tank_ban_flow_min", -1);
    new iMaxFlow = L4D2_GetMapValueInt("tank_ban_flow_max", -1);
    
    // Check inputs exist and are sensible
    if (iMinFlow == -1 || iMaxFlow == -1 || iMaxFlow < iMinFlow) {
        return;
    }

    new iRoundNumber = InSecondHalfOfRound() ? 1 : 0;
    new Float:fMinFlow = Float:iMinFlow / 100.0;
    new Float:fMaxFlow = Float:iMaxFlow / 100.0;
    new Float:fTankFlow = L4D2Direct_GetVSTankFlowPercent(iRoundNumber);
    
    // Is the tank in the allowed spawn range?    
    if (fTankFlow < fMinFlow || fTankFlow > fMaxFlow) {
        return;
    }
    
    new Float:fCvarMaxFlow = GetConVarFloat(g_hVsBossFlowMax);
    new Float:fCvarMinFlow = GetConVarFloat(g_hVsBossFlowMin);
    new Float:fCvarFlowRange = fCvarMaxFlow - fCvarMinFlow;
    
    fMinFlow = fMinFlow < fCvarMinFlow ? fCvarMinFlow : fMinFlow;
    fMaxFlow = fMaxFlow > fCvarMaxFlow ? fCvarMaxFlow : fMaxFlow;
    
    // XXX: Spawn the tank between the allowed min and max cutting out the
    // banned area
    new Float:fFlowRange = fMaxFlow - fMinFlow;
    new Float:fFlow = fCvarMinFlow + GetRandomFloat(0.0, fCvarFlowRange-fFlowRange);
    fFlow = fFlow >= fMinFlow ? fFlow + fFlowRange : fFlow;
    
    new Float:fFlows[2];
    fFlows[0] = fFlow;
    fFlows[1] = fFlow;
    
    // XXX: Use this the l4dt2 function for now as StoreToAddress is broken
    L4D2_SetVersusTankFlowPercent(fFlows);
}

