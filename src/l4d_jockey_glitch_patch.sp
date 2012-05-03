#pragma semicolon 1

#define L4D2UTIL_STOCKS_ONLY 1

#include <sourcemod>
#include <sdkhooks>
#include <l4d2util>

new bool:bLateLoad;
new Float:fLastJockeyDamageTime;
new Handle:hCvarVsTankDamage;

public Plugin:myinfo =
{
    name        = "L4D2 Jockey Glitch Patch",
    author      = "Jahze",
    version     = "1.0",
    description = "Prevent the tank from insta-incapping jockeys and scratches on jockeyed targets doing double damage"
}

public APLRes:AskPluginLoad2( Handle:plugin, bool:late, String:error[], errMax) {
    bLateLoad = late;
    return APLRes_Success;
}

public OnPluginStart() {
    if ( bLateLoad ) {
        for ( new i = 1; i < MaxClients+1; i++ ) {
            if ( IsClientInGame(i) ) {
                SDKHook(i, SDKHook_OnTakeDamage, Hurt);
            }
        }
    }
    
    fLastJockeyDamageTime = GetGameTime();
    hCvarVsTankDamage = FindConVar("vs_tank_damage");
}

public OnClientPutInServer( client ) {
    SDKHook(client, SDKHook_OnTakeDamage, Hurt);
}

public Action:Hurt( victim, &attacker, &inflictor, &Float:damage, &damageType, &weapon, Float:damageForce[3], Float:damagePosition[3] ) {
    // Is the victim a survivor
    if (!IsValidClient(victim) || !IsSurvivor(victim)) {
        return Plugin_Continue;
    }
    
    // Is the survivor being jockeyed
    new jockeyAttacker = GetEntPropEnt(victim, Prop_Send, "m_jockeyAttacker");
    if (!IsValidClient(jockeyAttacker) || GetInfectedClass(jockeyAttacker) != L4D2Infected_Jockey) {
        return Plugin_Continue;
    }
    
    // Is the attacker an infected who isn't the jockey
    if (!IsValidClient(attacker) || !IsInfected(attacker) || attacker == jockeyAttacker) {
        return Plugin_Continue;
    }
    
    // If the last time a jockeyed survivor took damage from a scratch was less
    // than 100ms ago it's likely to be a double damage scratch.
    if (GetGameTime() < fLastJockeyDamageTime + 0.1) {
        return Plugin_Handled;
    }
    
    fLastJockeyDamageTime = GetGameTime();
    
    // Tank's will do 250 damage to survivor when the jockey glitch kicks in
    if (GetInfectedClass(attacker) == L4D2Infected_Tank && damage == 250.0)
    {
        damage = GetConVarFloat(hCvarVsTankDamage);
        return Plugin_Changed;
    }
    
    return Plugin_Continue;
}

bool:IsValidClient(client) {
    return (client > 0 && client <= MaxClients);
}

