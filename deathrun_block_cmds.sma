#include <amxmodx>
#include <engine>
#include <hamsandwich>
#include <fakemeta>
#include <cstrike>
#include <deathrun>

public plugin_init() {
	register_plugin("Deathrun Block Commands", "1.0", "MrShark45");

	//Block Radio
	register_clcmd( "radio1", "cmd_radio" );
	register_clcmd( "radio2", "cmd_radio" );
	register_clcmd( "radio3", "cmd_radio" );

	//Block Jointeam
	register_clcmd( "jointeam", "cmd_radio" );

	//Block Spray
	register_impulse( 201, "fwd_impulse_201" );

	//Remove Buyzone
	register_message( get_user_msgid( "StatusIcon" ), "msg_status_icon" ); // BuyZone Icon
			
	// Remove buyzone on map
	remove_entity_name( "info_map_parameters" );
	remove_entity_name( "func_buyzone" );
			
	// Create own entity to block buying
	new iEntity = create_entity( "info_map_parameters" );
			
	DispatchKeyValue( iEntity, "buying", "3" );
	DispatchSpawn( iEntity );

	//Block Terro Kill
	register_forward( FM_ClientKill,"fwd_client_kill" );
	
	//Block using buttons during RespawnMode
	if( engfunc(EngFunc_FindEntityByString,-1 ,"classname", "func_button"))
		RegisterHam(Ham_Use, "func_button", "fwd_button_used");

	if(engfunc(EngFunc_FindEntityByString,-1 ,"classname","func_rot_button"))
		RegisterHam(Ham_Use, "func_rot_button", "fwd_button_used");
		
	if(engfunc(EngFunc_FindEntityByString,-1 ,"classname", "button_target"))
		RegisterHam(Ham_Use, "button_target", "fwd_button_used");

}

//Block Commands

//Radio
public cmd_radio( id ) {
	return PLUGIN_HANDLED_MAIN;
}

//Hud Buyzone
public msg_status_icon( msg_id, msg_dest, id ) {
	new szIcon[ 8 ];
	get_msg_arg_string( 2, szIcon, 7 );
	
	static const BuyZone[ ] = "buyzone";
	
	if( equal( szIcon, BuyZone ) ) {
		set_pdata_int( id, 235, get_pdata_int( id, 235, 5 ) & ~( 1 << 0 ), 5 );
		
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
}

//Spray
public fwd_impulse_201( const id ) {
	if( is_user_alive( id ) )	
		return PLUGIN_HANDLED_MAIN;
	return PLUGIN_CONTINUE;
	
}

//Terrorist Kill command
public fwd_client_kill( const id ) {
	if(!is_user_alive(id) )
		return FMRES_IGNORED;
	
	if(cs_get_user_team( id ) == CS_TEAM_T){
		return FMRES_SUPERCEDE;
	}
	
	return FMRES_IGNORED;
}

//Dezactivate buttons
public fwd_button_used(this, idcaller, idactivator, use_type, Float:value){
	if(idcaller!=idactivator) return HAM_IGNORED;
	
	if(pev(this, pev_frame) > 0.0)
		 return HAM_IGNORED;
	new index=get_ent_index(this);
	if(index==-1) 
		return HAM_IGNORED;
	if(!is_deathrun_enabled() && cs_get_user_team(idcaller) == CS_TEAM_T){
			return HAM_SUPERCEDE;
	}
	return HAM_IGNORED;
}

get_ent_index(ent){
	return pev(ent, pev_iuser4)-1;
}