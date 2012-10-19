#pragma semicolon 1

#define L4D2UTIL_STOCKS_ONLY

#include <sourcemod>
#include <sdktools>
#include <l4d2_direct>
#include <l4d2lib>
#include <l4d2util>

public Plugin:myinfo = {
    name = "L4D2 Boss Flow Announce",
    author = "ProdigySim, Jahze",
    version = "1.1",
    description = "Announce boss flow percents!"
};

new g_iTankPercent;
new g_iWitchPercent;
new bool:bLateLoad = false;

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

    if (bLateLoad)
        SaveBossPercents();
}

public APLRes:AskPluginLoad2(Handle:plugin, bool:late, String:error[], err_max) {
    bLateLoad = late;
}

public LeftStartAreaEvent( ) {
    for (new i = 0; i < MaxClients+1; ++i) {
        PrintBossPercents(i);
    }
}

public RoundStartEvent() {
    CreateTimer(0.5, AdjustBossFlow);
}

PrintBossPercents(client) {
    if (g_iTankPercent != 0) {
        PrintToChat(client, "\x01Tank spawn: [\x04%d%%\x01]", g_iTankPercent);
    }
    else {
        PrintToChat(client, "\x01Tank spawn: [\x04None\x01]", g_iTankPercent);
    }

    if (g_iWitchPercent != 0) {
        PrintToChat(client, "\x01Witch spawn: [\x04%d%%\x01]", g_iWitchPercent);
    }
    else {
        PrintToChat(client, "\x01Witch spawn: [\x04None\x01]", g_iWitchPercent);
    }
}

public Action:BossCmd(client, args) {
    new L4D2_Team:iTeam = L4D2_Team:GetClientTeam(client);
    if (iTeam == L4D2Team_Spectator) {
        PrintBossPercents(client);
        return;
    }

    for (new i = 1; i < MaxClients+1; i++) {
        if (IsClientConnected(i) && IsClientInGame(i) && L4D2_Team:GetClientTeam(i) == iTeam) {
            PrintBossPercents(i);
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

public Action:AdjustBossFlow(Handle:timer) {
    SaveBossPercents();

    new iMinFlow = L4D2_GetMapValueInt("tank_ban_flow_min", -1);
    new iMaxFlow = L4D2_GetMapValueInt("tank_ban_flow_max", -1);

    // Check inputs exist and are sensible
    if (iMinFlow == -1 || iMaxFlow == -1 || iMaxFlow < iMinFlow) {
        return;
    }

    new iRoundNumber = InSecondHalfOfRound() ? 1 : 0;
    new Float:fMinFlow = Float:float(iMinFlow) / 100.0;
    new Float:fMaxFlow = Float:float(iMaxFlow) / 100.0;
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

    L4D2Direct_SetVSTankFlowPercent(0, fFlow);
    L4D2Direct_SetVSTankFlowPercent(1, fFlow);

    g_iTankPercent = RoundToNearest(fFlow*100.0);
}

static SaveBossPercents() {
    if (! InSecondHalfOfRound()) {
        g_iTankPercent = 0;
        g_iWitchPercent = 0;

        if (L4D2Direct_GetVSTankToSpawnThisRound(0)) {
            g_iTankPercent = RoundToNearest(GetTankFlow(0)*100.0);
        }

        if (L4D2Direct_GetVSWitchToSpawnThisRound(0)) {
            g_iWitchPercent = RoundToNearest(GetWitchFlow(0)*100.0);
        }
    }
    else {
        if (g_iTankPercent != 0) {
            g_iTankPercent = RoundToNearest(GetTankFlow(1)*100.0);
        }

        if (g_iWitchPercent != 0) {
            g_iWitchPercent = RoundToNearest(GetWitchFlow(1)*100.0);
        }
    }
}

