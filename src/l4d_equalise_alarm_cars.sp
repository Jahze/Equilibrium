#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

public Plugin:myinfo =
{
    name        = "L4D2 Equalise Alarm Cars",
    author      = "Jahze",
    version     = "1.0",
    description = "Make the alarmed car spawns the same for each team in versus"
};

new bool:bHooked = false;
new bool:bSecondRound = false;
new bool:bPatched = false;

new Handle:hFirstRoundCars;
new Handle:hFirstRoundTriggeredCars;
new Handle:hSecondRoundCars;

new Handle:hCvarEqAlarmCars;

public OnPluginStart() {
    hCvarEqAlarmCars = CreateConVar("l4d_equalise_alarm_cars", "1", "Makes alarmed cars spawn in the same way for both teams", FCVAR_PLUGIN);
    HookConVarChange(hCvarEqAlarmCars, EqAlarmCarsChange);
    
    hFirstRoundCars = CreateArray(128);
    hFirstRoundTriggeredCars = CreateArray(128);
    hSecondRoundCars = CreateArray(128);
    
    HookEvents();
}

public OnPluginStop() {
    UnhookEvents();
}

public OnMapStart() {
    bSecondRound = false;
    bPatched = false;
    
    ClearArray(hFirstRoundCars);
    ClearArray(hFirstRoundTriggeredCars);
    ClearArray(hSecondRoundCars);
}

HookEvents() {
    if ( !bHooked ) {
        HookEvent("round_start", RoundStart);
        HookEvent("round_end", RoundEnd);
        bHooked = true;
    }
}

UnhookEvents() {
    if ( bHooked ) {
        UnhookEvent("round_start", RoundStart);
        UnhookEvent("round_end", RoundEnd);
        bHooked = false;
    }
}

public EqAlarmCarsChange( Handle:cvar, const String:oldValue[], const String:newValue[] ) {
    if ( StringToInt(newValue) == 1 ) {
        HookEvents();
    }
    else {
        UnhookEvents();
    }
}

public Action:RoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
    CreateTimer(0.1, RoundStartDelay);
}

public Action:RoundEnd( Handle:event, const String:name[], bool:dontBroadcast ) {
    if ( !bSecondRound ) {
        bSecondRound = true;
    }
}

public Action:RoundStartDelay( Handle:timer ) {
    new iEntity = -1;
    decl String:sTargetName[128];
    
    while ( (iEntity = FindEntityByClassname(iEntity, "logic_relay")) != -1 ) {
        GetEntityName(iEntity, sTargetName, sizeof(sTargetName));
        
        if ( StrContains(sTargetName, "-relay_caralarm_off") == -1 ) {
            continue;
        }
        
        LogMessage("%s was hooked", sTargetName);
        HookSingleEntityOutput(iEntity, "OnTrigger", CarAlarmLogicRelayTriggered);
    }
    
    iEntity = -1;
    
    while ( (iEntity = FindEntityByClassname(iEntity, "prop_car_alarm")) != -1 ) {
        GetEntityName(iEntity, sTargetName, sizeof(sTargetName));
        
        LogMessage("%s car alarm was hooked", sTargetName);
        HookSingleEntityOutput(iEntity, "OnCarAlarmStart", CarAlarmTriggered); 
    }
}

public CarAlarmLogicRelayTriggered( const String:output[], caller, activator, Float:delay ) {
    new sTargetName[128];
    GetEntityName(caller, sTargetName, sizeof(sTargetName));
    
    LogMessage("%s was triggered %s %d", output, sTargetName, bSecondRound);
    
    if ( !bSecondRound ) {
        if ( !CarWasTriggered(sTargetName) ) {
            PushArrayString(hFirstRoundCars, sTargetName);
        }
        else {
            LogMessage("Not adding as the car was triggered");
        }
    }
    else {
        PushArrayString(hSecondRoundCars, sTargetName);
        if ( !bPatched ) {
            CreateTimer(1.0, PatchAlarmedCars);
            bPatched = true;
        }
    }
}

public Action:PatchAlarmedCars( Handle:timer ) {
    decl String:sEntName[128];
    
    for ( new i = 0; i < GetArraySize(hFirstRoundCars); i++ ) {
        GetArrayString(hFirstRoundCars, i, sEntName, sizeof(sEntName));
        
        if ( FindStringInArray(hSecondRoundCars, sEntName) == -1 ) {
            LogMessage("%s was fired 1st round but not 2nd", sEntName);
            DisableCar(sEntName);
        }
        else {
            LogMessage("%s fired in 1st and 2nd round", sEntName);
        }
    }
    
    for ( new i = 0; i < GetArraySize(hSecondRoundCars); i++ ) {
        GetArrayString(hSecondRoundCars, i, sEntName, sizeof(sEntName));
        
        if ( FindStringInArray(hFirstRoundCars, sEntName) == -1 ) {
            LogMessage("%s was fired 2nd round but not 1st", sEntName);
            EnableCar(sEntName);
        }
        else {
            LogMessage("%s fired in 1st and 2nd round", sEntName);
        }
    }
}

bool:ExtractCarName( const String:sName[], String:sBuffer[], iSize ) {
    return (SplitString(sName, "-", sBuffer, iSize) != -1);
}

DisableCar( const String:sName[] ) {
    LogMessage("Disabling %s", sName);
    TriggerCarRelay(sName, false);
}

EnableCar( const String:sName[] ) {
    LogMessage("Enabling %s", sName);
    TriggerCarRelay(sName, true);
}

TriggerCarRelay( const String:sName[], bool:bOn ) {
    decl String:sCarName[128];
    new iEntity;
    
    if ( !ExtractCarName(sName, sCarName, sizeof(sCarName)) ) {
        return;
    }
    
    LogMessage("Got name");
    StrCat(sCarName, sizeof(sCarName), "-relay_caralarm_");
    
    if ( bOn ) {
        StrCat(sCarName, sizeof(sCarName), "on");
    }
    else {
        StrCat(sCarName, sizeof(sCarName), "off");
    }
    
    iEntity = FindEntityByName(sCarName, "logic_relay");
    
    if ( iEntity != -1 ) {
        LogMessage("Triggering %s", sCarName);
        AcceptEntityInput(iEntity, "Trigger");
    }
    else {
        LogMessage("Couldn't find %s", sCarName);
    }
}

public CarAlarmTriggered( const String:output[], caller, activator, Float:delay ) {
    if ( bSecondRound ) {
        return;
    }
    
    decl String:sTargetName[128];
    decl String:sCarName[128];
    
    GetEntityName(caller, sTargetName, sizeof(sTargetName));
    ExtractCarName(sTargetName, sCarName, sizeof(sCarName));
    
    LogMessage("%s was triggered %s %d", output, sTargetName, bSecondRound);
    LogMessage("Pushing %s onto triggered cars", sCarName);
    
    PushArrayString(hFirstRoundTriggeredCars, sCarName);
}

bool:CarWasTriggered( const String:sTargetName[] ) {
    new String:sCarName[128];
    
    ExtractCarName(sTargetName, sCarName, sizeof(sCarName));
    
    return FindStringInArray(hFirstRoundTriggeredCars, sCarName) != -1;
}

FindEntityByName( const String:sName[], const String:sClassName[] ) {
    new iEntity = -1;
    decl String:sEntName[128];
    
    while ( (iEntity = FindEntityByClassname(iEntity, sClassName)) != -1 ) {
        if ( !IsValidEntity(iEntity) ) {
            continue;
        }
        
        GetEntityName(iEntity, sEntName, sizeof(sEntName));
        
        if ( StrEqual(sEntName, sName) ) {
            return iEntity;
        }
    }
    
    return -1;
}

GetEntityName( iEntity, String:sTargetName[], iSize ) {
    GetEntPropString(iEntity, Prop_Data, "m_iName", sTargetName, iSize);
}
