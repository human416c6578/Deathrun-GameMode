#include <amxmodx>
#include <engine>
#include <hamsandwich>
#include <fakemeta>
#include <fakemeta_util>
#include <cstrike>
#include <fun>
#include <colorchat>
//Prefix for chat messages
new serverPrefix[] = "(Deathrun Usp)";
//bools for respawn gamemode
new bool:b_RespawnMode;
new bool:b_RespawnActive;
//Variable to stock the respawn time
new respawnTime;
//Task it for the task that disables the respawn
new taskid=29482891;

new lastTerrorist;

new bool:b_MapEnded;

//Stock Hud Element
new HideWeapon;

public plugin_init( ) {
	register_plugin( "Deathrun GameMode", "1.0", "MrShark45" );

	//Cvars
	//How many seconds the respawn is active
	respawnTime = register_cvar("respawn_time","30.0");
	//Commands
	//Command to respawn the player when the respawn mode is activated
	register_clcmd("say /start","player_respawn");
	//Command to toggle the gamemode
	register_clcmd("deathrun_toggle","gamemode_toggle");
	//Events
	register_logevent("event_round_start", 2, "1=Round_Start");
	register_logevent("event_round_end", 2, "1=Round_End");
	RegisterHam(Ham_Spawn, "player", "player_spawn", 1);
	RegisterHam(Ham_Killed, "player", "player_killed");
	//Forwards
	//Get HUD
	HideWeapon = get_user_msgid("HideWeapon");
	//Block Commands
	
	//Block using buttons during RespawnMode
	RegisterHam(Ham_Use, "func_button", "button_use")

	//Radio
	register_clcmd( "radio1", "CmdRadio" );
	register_clcmd( "radio2", "CmdRadio" );
	register_clcmd( "radio3", "CmdRadio" );

	//Spray
	register_impulse( 201, "FwdImpulse_201" );

	//Buyzone
	register_message( get_user_msgid( "StatusIcon" ), "MsgStatusIcon" ); // BuyZone Icon
			
	// Remove buyzone on map
	remove_entity_name( "info_map_parameters" );
	remove_entity_name( "func_buyzone" );
			
	// Create own entity to block buying
	new iEntity = create_entity( "info_map_parameters" );
			
	DispatchKeyValue( iEntity, "buying", "3" );
	DispatchSpawn( iEntity );

	//Terro Kill
	register_forward( FM_ClientKill,"FwdClientKill" );
}

//Game Functions

public plugin_cfg(){
	//Disable Respawn on new map
	b_RespawnMode = false;
	//Pick a terrorist in 5 seconds
	set_task(5.0, "terrorist_pick");
	//Set those 2 cvars to not mess up with the gamemode
	set_cvar_num("mp_autoteambalance", 0);
	set_cvar_num("mp_limitteams", 0);
	//Set task to send a message once every 2 mins with info about the RespawnGameMode
	set_task(120.0, "respawn_message",_,_,_,"b");
	time_check();
	b_MapEnded = false;
}

public plugin_end(){
	b_MapEnded = true;
}

//Client connected to the server
public client_putinserver(id){
}

public client_disconnected(id){
	//Replace the terrorist if he disconnects
	if(b_RespawnMode || b_MapEnded)
		return PLUGIN_CONTINUE;
	terrorist_check(id);
	return PLUGIN_CONTINUE;
}

//EVENTS
//Round Start
public event_round_start(){
	//Activate the respawn
	b_RespawnActive = true;
	//Create Task to disable respawn after x seconds
	set_task(get_pcvar_float(respawnTime), "respawn_disable", taskid);
}
//Round End
public event_round_end(){
	//Calls time_check function
	time_check();
	//Move Players from T to CT
	new player, players[32],numPlayers,i;
	get_players(players, numPlayers);
	for( i = 0; i < numPlayers; i++ ) {
		player = players[ i ];
		
		if( cs_get_user_team( player ) == CS_TEAM_T ){
			cs_set_user_team( player, CS_TEAM_CT );
		}
	}
	if(b_RespawnMode)
		return PLUGIN_CONTINUE;
	//Pick New Terrorist
	terrorist_pick();
	//Kill Respawn Task
	remove_task(taskid);
	return PLUGIN_CONTINUE;
}
//Player has spawned
public player_spawn(id){
	if(!is_user_connected(id))
		return PLUGIN_CONTINUE;
	//Give Items to player if he's not spectator
	if(cs_get_user_team(id) != CS_TEAM_SPECTATOR){		
		//Remove all the weapons he has
		fm_strip_user_weapons(id);
		set_task(0.2,"GiveItems",id);
	}	
		

	//Remove Hud
	message_begin(MSG_ONE_UNRELIABLE, HideWeapon, _, id);
	write_byte(2 | 16 | 32);
	message_end();

	return PLUGIN_CONTINUE;
	
}
//Player has been killed
public player_killed(id){
	if(!is_user_connected(id))
		return HAM_IGNORED;
	//Respawn the player if the respawn mode is active nor the respawn time has passed
	if(b_RespawnMode || b_RespawnActive){
		if(cs_get_user_team(id) == CS_TEAM_CT){
			ExecuteHamB(Ham_CS_RoundRespawn, id);
			return HAM_SUPERCEDE;
		}
	}
	return HAM_IGNORED;
}

//Function to respawn the players that's calling it
public player_respawn(id){
	if(b_RespawnMode){
		ExecuteHamB(Ham_CS_RoundRespawn, id);
	}
	return HAM_IGNORED;
}

//Choose a random terrorist at round end
public terrorist_pick(){
	new players[32],numPlayers,newTerro,name[33];
	get_players(players, numPlayers);
	//Pick a random player
	newTerro = players[random(numPlayers)];
	//Checks if he's connected
	if(!is_user_connected(newTerro))
		terrorist_pick();
	//Checks if he isn't the terrorist from the last round and that he's a CT
	if(newTerro != lastTerrorist && cs_get_user_team(newTerro) == CS_TEAM_CT){
		get_user_name(newTerro, name,32);
		cs_set_user_team(newTerro, CS_TEAM_T);
		lastTerrorist = newTerro;
		ColorChat(0, GREEN,"^x04%s^x03 %s^x01 este noul terorist.", serverPrefix, name);
	}
	//If the condition doesn't apply to the new terro the function is called again
	else{
		terrorist_pick();
	}
	
	return PLUGIN_CONTINUE;
}
//Replace the terrorist
public terrorist_replace(id){
	new players[32],numPlayers,newTerro,name[33],name2[33];
	get_players(players, numPlayers);
	if(numPlayers<=1)
		return PLUGIN_CONTINUE;
	//Pick a random player
	newTerro = players[random(numPlayers)];
	get_user_name(id,name2, 32);
	//Checks if he's connected
	if(!is_user_connected(newTerro))
		terrorist_replace(id);
	//Checks if he's a CT
	if(cs_get_user_team(newTerro)==CS_TEAM_CT){
		get_user_name(newTerro, name,32);
		//Move him to the Terrorists
		cs_set_user_team(newTerro, CS_TEAM_T);
		//Sets him as the last terrorist
		lastTerrorist = newTerro;
		ColorChat(0, GREEN,"^x04%s^x03 %s^x01 este noul terorist, deoarece^x03 %s^x01 s-a deconectat.", serverPrefix, name, name2);
		//Respawns him
		ExecuteHamB(Ham_CS_RoundRespawn, newTerro);
	}
	//If the new Terrorist is not CT the function is called again
	else{
		terrorist_replace(id);
	}
	
	return PLUGIN_CONTINUE;
}
//Check if there's a terrorist
public terrorist_check(id){
	new players[32],numPlayers,i;
	new bool:isTerro;
	//Get all terrorists
	get_players(players, numPlayers, "ce", "TERRORIST");
	//Going through all
	for(i=1; i<=32; i++){
		if(!is_user_connected(i))
			continue;
		//Check if the current one is not the player that left, this function is called on client_disconnected
		if(cs_get_user_team(i) == CS_TEAM_T && i!=id)
			isTerro = true;
	}
	//If a terrorist isn't found then we pick another player to be the terrorist
	if(!isTerro)
		terrorist_replace(id);
	return PLUGIN_CONTINUE;
}
//Toggle the gamemode between deathrun and respawn
public gamemode_toggle(){
	b_RespawnMode= !b_RespawnMode;
	event_round_end();
}
//Disable the respawn
public respawn_disable(){
	b_RespawnActive = false;
	if(!b_RespawnMode)
		ColorChat(0, GREEN,"^x04%s^x01 Timpul de respawn s-a terminat!", serverPrefix);
}
//Check the time , if it's between 00:00AM and 10:00AM, then the RESPAWN gamemode will activate
public time_check(){
	new data[3];
	get_time("%H", data, 2);
	if(!b_RespawnMode){
		if(10 > str_to_num(data) >= 0){
			b_RespawnMode = true;
			event_round_end();
			event_round_start();
		}
	}
	else{
		if(10 < str_to_num(data)){
			b_RespawnMode = false;
			event_round_end();
			event_round_start();
		}
	}
}
//Give items to player
public GiveItems(id){
	//Checking if he's CT
	if(cs_get_user_team(id) == CS_TEAM_CT){
		give_item(id,"weapon_usp");
		give_item(id,"ammo_45acp");
		give_item(id,"ammo_45acp");
	}
	give_item(id, "weapon_knife");
}

//Block Commands

//Radio
public CmdRadio( id ) {
	return PLUGIN_HANDLED_MAIN;
}

//Hud Buyzone
public MsgStatusIcon( msg_id, msg_dest, id ) {
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
public FwdImpulse_201( const id ) {
	if( is_user_alive( id ) )	
		return PLUGIN_HANDLED_MAIN;
	return PLUGIN_CONTINUE;
	
}

//Terrorist Kill command
public FwdClientKill( const id ) {
	if(!is_user_alive(id) )
		return FMRES_IGNORED;
	
	if(cs_get_user_team( id ) == CS_TEAM_T){
		return FMRES_SUPERCEDE;
	}
	
	return FMRES_IGNORED;
}

//Block using buttons during Respawn GameMode
public button_use(iButton, iActivator, iCaller, iUseType, Float:fValue)
{
	if(!b_RespawnMode)
		return HAM_IGNORED;

	return HAM_SUPERCEDE;
}

//Message containing info about the Respawn GameMode
public respawn_message(){
	ColorChat(0, GREEN,"^x04%s^x01 Poti folosi comanda^x03 [/start]^x01 pentru a te reseta la pozitia de start!", serverPrefix);
}