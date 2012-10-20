#pragma semicolon 1

#define L4D2UTIL_STOCKS_ONLY 1

#include <sourcemod>
#include <sdkhooks>
#include <l4d2util>

new Float:g_fRiotCopDamageReduction;
new Handle:g_hCvarRiotCopDamageReduction;

public Plugin:myinfo = {
    name        = "L4D2 Riot Cops",
    author      = "Jahze",
    version     = "1.0",
    description = "Allow riot cops to be killed from the front"
}

public OnPluginStart() {
    g_hCvarRiotCopDamageReduction = CreateConVar("l4d2_riot_cop_dmg_reduction", "3.0", "Damage done to riot cops is divided by this number to simulate them having more health");
    HookConVarChange(g_hCvarRiotCopDamageReduction, RiotCopDamageReduction);
    g_fRiotCopDamageReduction = GetConVarFloat(g_hCvarRiotCopDamageReduction);
}

public RiotCopDamageReduction(Handle:hCvar, const String:oldVal[], const String:newVal[]) {
    g_fRiotCopDamageReduction = StringToFloat(newVal);
}

public OnEntityCreated(entity, const String:classname[]) {
    if (entity <= 0 || entity > 2048) {
        return;
    }

    if (StrEqual("infected", classname)) {
        SDKHook(entity, SDKHook_SpawnPost, RiotCopSpawn);
    }
}

public RiotCopSpawn(entity) {
    if (GetGender(entity) == L4D2Gender_RiotCop) {
        SDKHook(entity, SDKHook_OnTakeDamage, RiotCopTakeDamage);
    }
}

public Action:RiotCopTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damageType, &weapon, Float:damageForce[3], Float:damagePosition[3]) {
    if (! attacker) {
        return Plugin_Continue;
    }

    SDKHooks_TakeDamage(victim, 0, attacker, damage / g_fRiotCopDamageReduction);
    return Plugin_Handled;
}

