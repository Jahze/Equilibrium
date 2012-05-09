#pragma semicolon 1

#define L4D2UTIL_STOCKS_ONLY

#include <sourcemod>
#include <sdktools>
#include <l4d2util>
#include <l4d2_direct>
#include <left4downtown>

new String:teamATank[32];
new String:teamBTank[32];

new Handle:hTeamATanks;
new Handle:hTeamBTanks;

public OnPluginStart() {
    hTeamATanks = CreateArray(32);
    hTeamBTanks = CreateArray(32);
}

public Action:L4D_OnTryOfferingTankBot(tank_index, &bool:enterStatis) {
    PrintToChatAll("Tank is being offered");
    
    if (!IsFakeClient(tank_index)) {
        PrintToChatAll("The tank isn't a bot so reset rage");
        //PrintHintText(tank_index, "One rage 
        SetTankFrustration(tank_index, 100);
        L4D2Direct_SetTankPassedCount(L4D2Direct_GetTankPassedCount() + 1);
        PrintToChatAll("Incremented pass count");
        return Plugin_Handled;
    }
    
    ChooseTank(true);
    
    if (GetDesignatedTank() != -1) {
        PrintToChatAll("Chosen tank is %N", GetDesignatedTank());
        ForceTankPlayer();
    }
    
    return Plugin_Continue;
}

static GetDesignatedTank() {
    return GetInfectedPlayerBySteamId(GameRules_GetProp("m_bAreTeamsFlipped") ? teamBTank : teamATank);
}

static bool:HasBeenTank(client) {
    decl String:SteamId[32];
    GetClientAuthString(client, SteamId, sizeof(SteamId));
    for (new i = 0; i < GetArraySize(GameRules_GetProp("m_bAreTeamsFlipped") ? hTeamBTanks : hTeamATanks); ++i)
    {
        decl String:name[32];
        GetArrayString(GameRules_GetProp("m_bAreTeamsFlipped") ? hTeamBTanks : hTeamATanks, i, name, sizeof(name));
        PrintToChatAll("(%s) is in tank array %d", name, GameRules_GetProp("m_bAreTeamsFlipped"));
    }
    return (FindStringInArray(GameRules_GetProp("m_bAreTeamsFlipped") ? hTeamBTanks : hTeamATanks, SteamId) != -1);
}

static ChooseTank(bool:bFirstPass) {
    decl String:SteamId[32];
    new Handle:SteamIds = CreateArray(32);
    new bool:bTeamsFlipped = bool:GameRules_GetProp("m_bAreTeamsFlipped");
    
    PrintToChatAll("bTeamsFlipped = %d", bTeamsFlipped);
    
    for (new i = 1; i < MaxClients+1; i++) {
        if (!IsClientConnected(i) || !IsClientInGame(i)) {
            continue;
        }
        
        PrintToChatAll("%d should be connected and in game", i);
        PrintToChatAll("%d, IsFakeClient=%d, IsInfected=%d, HasBeenTank=%d", i, IsFakeClient(i), IsInfected(i), HasBeenTank(i));
        
        if (IsFakeClient(i) || !IsInfected(i) || HasBeenTank(i)) {
            continue;
        }
        
        GetClientAuthString(i, SteamId, sizeof(SteamId));
        PushArrayString(SteamIds, SteamId);
        PrintToChatAll("(%s) added to the choices", SteamId);
    }
    
    if (GetArraySize(SteamIds) == 0) {
        PrintToChatAll("No tanks found first_try = %d", bFirstPass);
        if (bFirstPass) {
            ClearArray(bTeamsFlipped ? hTeamBTanks : hTeamATanks);
            ChooseTank(false);
        }
        return;
    }
    
    new idx = GetRandomInt(0, GetArraySize(SteamIds)-1);
    GetArrayString(SteamIds, idx, bTeamsFlipped ? teamBTank : teamATank, sizeof(teamBTank));
    PrintToChatAll("Adding %s to played tanks", bTeamsFlipped ? teamBTank : teamATank);
    PushArrayString(bTeamsFlipped ? hTeamBTanks : hTeamATanks, bTeamsFlipped ? teamBTank : teamATank);
}

static ForceTankPlayer() {
    new tank = GetDesignatedTank();
    
    for (new i = 1; i < MaxClients+1; i++) {
        if (!IsClientConnected(i) || !IsClientInGame(i)) {
            continue;
        }
        
        if (IsInfected(i)) {
            if (tank == i) {
                L4D2Direct_SetTankTickets(i, 20000);
            }
            else {
                L4D2Direct_SetTankTickets(i, 0);
            }
        }
    }
}

static GetInfectedPlayerBySteamId(const String:SteamId[]) {
    decl String:cmpSteamId[32];
   
    for (new i = 1; i < MaxClients+1; i++) {
        if (!IsClientConnected(i)) {
            continue;
        }
        
        if (!IsInfected(i)) {
            continue;
        }
        
        GetClientAuthString(i, cmpSteamId, sizeof(cmpSteamId));
        
        if (StrEqual(SteamId, cmpSteamId)) {
            return i;
        }
    }
    
    return -1;
}

