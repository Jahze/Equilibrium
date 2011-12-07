GetCfgName( String:cfgName[], length ) {
    GetConVarString(FindConVar("confogl_cfg_name"), cfgName, length);
    cfgName[0] = CharToUpper(cfgName[0]);
    for ( new i = 1; i < length && i < strlen(cfgName); i++ ) {
        cfgName[i] = CharToLower(cfgName[i]);
    }
}
