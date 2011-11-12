#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4downtown>

new bool:bSecondRound;
new iTankFlow;

new Handle:cvar_tankPercent;

new String:sTankFlowMsg[128];

public Plugin:myinfo = {
    name        = "L4D2 Tank Percent",
    author      = "Jahze",
    version     = "1.0",
    description = "Tell players when the tank will spawn"
};

public OnPluginStart() {
    cvar_tankPercent = CreateConVar("l4d_tank_percent", "1", "Tell players when the tank will spawn", FCVAR_PLUGIN);
    HookConVarChange(cvar_tankPercent, TankPercentChange);
    
    RegConsoleCmd("sm_tank", TankCmd);
    
    PluginEnable();
}

public OnPluginEnd() {
    PluginDisable();
}

public OnMapStart() {
    bSecondRound    = false;
    sTankFlowMsg[0] = 0;
}

public OnMapEnd() {
    bSecondRound = false;
}

PluginEnable() {
    HookEvent("round_end", DeathwishRoundEnd);
    HookEvent("player_left_start_area", DeathwishPlayerLeftStartArea);
}

PluginDisable() {
    UnhookEvent("round_end", DeathwishRoundEnd);
    UnhookEvent("player_left_start_area", DeathwishPlayerLeftStartArea);
}

public TankPercentChange( Handle:cvar, const String:oldValue[], const String:newValue[] ) {
    if ( StringToInt(newValue) == 0 ) {
        PluginDisable();
    }
    else {
        PluginEnable();
    }
}

public Action:DeathwishPlayerLeftStartArea( Handle:event, const String:name[], bool:dontBroadcast ) {
    if ( !bSecondRound ) {    
        decl Float:tankFlows[2];
        
        // XXX: minus by 5% as tank spawns at this position when survivors are a bit earlier
        L4D2_GetVersusTankFlowPercent(tankFlows);
        iTankFlow = RoundToNearest((tankFlows[0] * 100.0) - 5.0);
        
        Format(sTankFlowMsg, sizeof(sTankFlowMsg), "[Deathwish] The tank will spawn at %d%s through the map.", iTankFlow, "%%");
    }
    
    PrintToChatAll(sTankFlowMsg);
}

public Action:DeathwishRoundEnd( Handle:event, const String:name[], bool:dontBroadcast ) {
    bSecondRound = true;
}


public Action:TankCmd(client, args) {
    if ( strlen(sTankFlowMsg) ) {
        ReplyToCommand(client, sTankFlowMsg);
    }
}

