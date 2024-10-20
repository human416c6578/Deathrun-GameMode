#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>

#define PLUGIN "Terrorist Menu"	
#define VERSION "1.0"
#define AUTHOR "MrShark45"

#pragma tabsize 0

public plugin_init(){

    RegisterHam(Ham_Spawn,"player","Spawn",1);
}

public Spawn(id){
    if(!is_user_connected(id))
        return PLUGIN_CONTINUE;
    if(cs_get_user_team(id) == CS_TEAM_T){
        //set_task(1.5, "GiveXmas", id);
        ShowMenu(id);
    }

    return PLUGIN_CONTINUE;
}

public GiveXmas(id){
    if(!is_user_connected(id))
        return PLUGIN_CONTINUE;
    fm_give_item(id, "weapon_m3");
    cs_set_user_bpammo(id, CSW_M3, 200);

    return PLUGIN_HANDLED;
}

public ShowMenu(id){
    new menu = menu_create( "\r[FWO] \d- \wMenu Terrorista", "menu_handler" );

    menu_additem( menu, "\wDeagle", "", 0 );
    menu_additem( menu, "\w200Hp", "", 0 );
    menu_additem( menu, "\wGrenades", "", 0 );
   
    menu_setprop( menu, MPROP_EXIT, MEXIT_ALL );
    
    menu_display( id, menu, 0 );
}

public menu_handler(id, menu, item){
    if(!is_user_connected(id))
        return PLUGIN_CONTINUE;
    if(cs_get_user_team(id) != CS_TEAM_T)
        return PLUGIN_CONTINUE;
    switch(item){
        case 0:
        {
            fm_give_item(id, "weapon_deagle");
            cs_set_user_bpammo(id, CSW_DEAGLE, 35);
        }
        case 1:
        {   
            fm_set_user_health(id,200);
            cs_set_user_armor(id, 100, CS_ARMOR_VESTHELM);
        }
        case 2:
        {
            fm_give_item(id,"weapon_hegrenade");
            fm_give_item(id,"weapon_smokegrenade");
            fm_give_item(id,"weapon_flashbang");
            fm_give_item(id,"weapon_flashbang");
        }
    }

    menu_destroy( menu );
    return PLUGIN_HANDLED;
}