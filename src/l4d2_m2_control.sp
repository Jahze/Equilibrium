#pragma semicolon 1

#define L4D2UTIL_STOCKS_ONLY

#include <sourcemod>
#include <l4d2util>
#include <l4d2_direct>

// The z_gun_swing_vs_amt_penalty cvar is the amount of cooldown time you get
// when you are on your maximum m2 penalty. However, whilst testing I found that
// a magic number of ~0.7s was always added to this.
#define COOLDOWN_EXTRA_TIME 0.7

new Handle:hMaxShovePenaltyCvar;
new Handle:hShovePenaltyAmtCvar;
new Handle:hPounceCrouchDelayCvar;
new Handle:hMaxStaggerDurationCvar;
new Handle:hLeapIntervalCvar;

public Plugin:myinfo =
{
    name        = "L4D2 M2 Control",
    author      = "Jahze",
    version     = "1.0",
    description = "Blocks instant repounces and gives maximum m2 penalty after a deadstop"
}

public OnPluginStart() {
    HookEvent("player_shoved", OutSkilled);
    hMaxShovePenaltyCvar = FindConVar("z_gun_swing_vs_max_penalty");
    hShovePenaltyAmtCvar = FindConVar("z_gun_swing_vs_amt_penalty");
    hPounceCrouchDelayCvar = FindConVar("z_pounce_crouch_delay");
    hMaxStaggerDurationCvar = FindConVar("z_max_stagger_duration");
    hLeapIntervalCvar = FindConVar("z_leap_interval");
}

public Action:OutSkilled(Handle:event, const String:name[], bool:dontBroadcast) {
    new shovee = GetClientOfUserId(GetEventInt(event, "userid"));
    new shover = GetClientOfUserId(GetEventInt(event, "attacker"));

    if (!IsSurvivor(shover) || !IsInfected(shovee))
        return;

    new L4D2_Infected:zClass = GetInfectedClass(shovee);

    if (zClass == L4D2Infected_Hunter || zClass == L4D2Infected_Jockey) {
        L4D2Direct_SetShovePenalty(shover, GetConVarInt(hMaxShovePenaltyCvar));

        new Float:time = GetGameTime();
        new Float:nextShoveTime = time + GetConVarFloat(hShovePenaltyAmtCvar) + COOLDOWN_EXTRA_TIME;
        L4D2Direct_SetNextShoveTime(shover, nextShoveTime);

        new Float:staggerTime = GetConVarFloat(hMaxStaggerDurationCvar);
        CreateTimer(staggerTime, ResetAbilityTimer, shovee);
    }
}

public Action:ResetAbilityTimer(Handle:event, any:shovee) {
    new Float:time = GetGameTime();
    new L4D2_Infected:zClass = GetInfectedClass(shovee);
    new Float:recharge;

    if (zClass == L4D2Infected_Hunter)
        recharge = GetConVarFloat(hPounceCrouchDelayCvar);
    else
        recharge = GetConVarFloat(hLeapIntervalCvar);

    new Float:timestamp;
    new Float:duration;
    if (! GetInfectedAbilityTimer(shovee, timestamp, duration))
        return;

    if (time + recharge > timestamp)
        SetInfectedAbilityTimer(shovee, time + recharge, recharge);
}

