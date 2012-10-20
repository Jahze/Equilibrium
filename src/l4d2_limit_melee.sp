#pragma semicolon 1

#include <sourcemod>
#include <l4d2util>

#define FLAG_COUNT          (1<<3)

public Plugin:myinfo =
{
    name        = "L4D2 Limit Melee",
    author      = "Jahze",
    version     = "1.0",
    description = "Limits the number of melee weapons found in a map"
}

enum WeaponInfoStruct {
    WeaponInfo_Entity,
    WeaponInfo_Type,
    WeaponInfo_Origin1,
    WeaponInfo_Origin2,
    WeaponInfo_Origin3,
    WeaponInfo_Angles1,
    WeaponInfo_Angles2,
    WeaponInfo_Angles3
};

new Handle:g_hCvarMeleeLimit;
new Handle:g_hWeaponInfoArray;

public OnPluginStart() {
    g_hCvarMeleeLimit = CreateConVar("l4d2_melee_limit", "4", "Keep this many melee weapons in each map and remove the rest");
    g_hWeaponInfoArray = CreateArray(_:WeaponInfoStruct);
}

public OnMapStart() {
    ClearArray(g_hWeaponInfoArray);
}

public OnRoundStart() {
    CreateTimer(0.5, RoundStartDelay);
}

public Action:RoundStartDelay(Handle:timer) {
    if (InSecondHalfOfRound()) {
        RestoreMeleeSpawns();
    }
    else {
        LimitMeleeSpawns();
    }
}

static FindAllMeleeWeapons(bool:bRemove) {
    new iEntity = -1;
    decl item[WeaponInfoStruct];
    decl Float:vOrigin[3];
    decl Float:vAngles[3];

    while ((iEntity = FindEntityByClassname(iEntity, "weapon_melee_spawn")) != -1) {
        if (bRemove) {
            AcceptEntityInput(iEntity, "Kill");
            continue;
        }

        MakeSinglePickup(iEntity);

        GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", vOrigin);
        GetEntPropVector(iEntity, Prop_Send, "m_angRotation", vAngles);

        item[WeaponInfo_Entity]  = iEntity;
        item[WeaponInfo_Type]    = _:IdentifyMeleeWeapon(iEntity);
        item[WeaponInfo_Origin1] = _:vOrigin[0];
        item[WeaponInfo_Origin2] = _:vOrigin[1];
        item[WeaponInfo_Origin3] = _:vOrigin[2];
        item[WeaponInfo_Angles1] = _:vAngles[0];
        item[WeaponInfo_Angles2] = _:vAngles[1];
        item[WeaponInfo_Angles3] = _:vAngles[2];

        PushArrayArray(g_hWeaponInfoArray, item[0]);
    }
}

static RemoveMeleeWeapons(limit) {
    decl item[WeaponInfoStruct];

    while (GetArraySize(g_hWeaponInfoArray) > limit) {
        new idx = GetURandomInt() % GetArraySize(g_hWeaponInfoArray);

        GetArrayArray(g_hWeaponInfoArray, idx, item[0]);
        AcceptEntityInput(item[WeaponInfo_Entity], "Kill");
        RemoveFromArray(g_hWeaponInfoArray, idx);
    }
}

static RestoreOldMeleeWeapons() {
    decl item[WeaponInfoStruct];
    decl Float:vOrigin[3];
    decl Float:vAngles[3];

    for (new i = 0; i < GetArraySize(g_hWeaponInfoArray); ++i) {
        GetArrayArray(g_hWeaponInfoArray, i, item[0]);

        new iEntity = CreateEntityByName("weapon_melee_spawn");
        new MeleeWeaponId:wepid = MeleeWeaponId:item[WeaponInfo_Type];

        decl String:sWepName[32];
        GetWeaponName(wepid, sWepName, sizeof(sWepName));

        DispatchKeyValue(iEntity, "melee_weapon", sWepName);
        DispatchSpawn(iEntity);

        vOrigin[0] = Float:item[WeaponInfo_Origin1];
        vOrigin[1] = Float:item[WeaponInfo_Origin2];
        vOrigin[2] = Float:item[WeaponInfo_Origin3];
        vAngles[0] = Float:item[WeaponInfo_Angles1];
        vAngles[1] = Float:item[WeaponInfo_Angles2];
        vAngles[2] = Float:item[WeaponInfo_Angles3];

        TeleportEntity(iEntity, vOrigin, vAngles, NULL_VECTOR);
        MakeSinglePickup(iEntity);
    }
}

static LimitMeleeSpawns() {
    FindAllMeleeWeapons(false);
    RemoveMeleeWeapons(GetConVarInt(g_hCvarMeleeLimit));
}

static RestoreMeleeSpawns() {
    FindAllMeleeWeapons(true);
    RestoreOldMeleeWeapons();
}

static MakeSinglePickup(iEntity) {
    DispatchKeyValue(iEntity, "count", "1");

    new iFlags = GetEntityFlags(iEntity);
    if (iFlags & FLAG_COUNT) {
        SetEntityFlags(iEntity, iFlags ^ FLAG_COUNT);
    }
}

