#include <amxmodx>
#include <engine>
#include <hamsandwich>
#include <fakemeta>
#include <fakemeta_util>
#include <cstrike>
#include <fun>
#include <cromchat>

//Prefix for chat messages
new serverPrefix[] = "[DR]";
//bools for respawn gamemode
new bool:b_RespawnMode;
new bool:b_RespawnActive;
//Variable to stock the respawn time
new respawnTime;
//Task it for the task that disables the respawn
new taskid=29482891;

new lastTerrorist;

new bool:b_MapEnded;

new bool:b_ManualToggled;

//Stock Hud Element
new HideWeapon;

new lives[33];

new terro_next;

//GAMEMODE VOTING
new g_votes[2];
new g_voteMenu;
//vote progress display
new hud_progress;
new hud_progress_taskid = 9123132;
new Float:vote_time = 20.0;
new bool:g_bVoting;
new bool:g_bVoted;

new g_StartHealth[33];
new Float:g_DamageTaken[33];

public plugin_init( ) {
	register_plugin( "Deathrun GameMode", "1.0", "MrShark45" );

	//Cvars
	//How many seconds the respawn is active
	respawnTime = register_cvar("respawn_time","30.0");
	//Commands
	//Command to display info about lives
	register_clcmd("say /lives","life_diplay");
	//Command to respawn the player using a life
	register_clcmd("say /revive","life_use");
	//Command to respawn the player when the respawn mode is activated
	register_clcmd("say /start","player_respawn");
	
	//Command to switch team to spectator/ct
	register_clcmd("say /ct","player_switchteam");
	//Command to switch team to spectator/ct
	register_clcmd("say /spec","player_switchteam");
	//Command to toggle the gamemode
	register_clcmd("deathrun_toggle","gamemode_toggle");
	//Events
	register_logevent("event_round_start", 2, "1=Round_Start");
	register_logevent("event_round_end", 2, "1=Round_End");
	RegisterHam(Ham_Spawn, "player", "player_spawn");
	RegisterHam(Ham_Killed, "player", "player_killed");
	RegisterHam(Ham_TakeDamage, "player", "player_hurt", 0);
	//Forwards
	//Get HUD
	HideWeapon = get_user_msgid("HideWeapon");
	//Reset Hud Event
	register_event("ResetHUD", "hud_reset", "b");
	
	//Block Commands
	
	//Block using buttons during RespawnMode
	if( engfunc(EngFunc_FindEntityByString,-1 ,"classname", "func_button"))
		RegisterHam(Ham_Use, "func_button", "fwButtonUsed");

	if(engfunc(EngFunc_FindEntityByString,-1 ,"classname","func_rot_button"))
		RegisterHam(Ham_Use, "func_rot_button", "fwButtonUsed");
		
	if(engfunc(EngFunc_FindEntityByString,-1 ,"classname", "button_target"))
		RegisterHam(Ham_Use, "button_target", "fwButtonUsed");

	//Block Radio
	register_clcmd( "radio1", "CmdRadio" );
	register_clcmd( "radio2", "CmdRadio" );
	register_clcmd( "radio3", "CmdRadio" );

	//Block Jointeam
	register_clcmd( "jointeam", "CmdRadio" );

	//Block Spray
	register_impulse( 201, "FwdImpulse_201" );

	//Remove Buyzone
	register_message( get_user_msgid( "StatusIcon" ), "MsgStatusIcon" ); // BuyZone Icon
			
	// Remove buyzone on map
	remove_entity_name( "info_map_parameters" );
	remove_entity_name( "func_buyzone" );
			
	// Create own entity to block buying
	new iEntity = create_entity( "info_map_parameters" );
			
	DispatchKeyValue( iEntity, "buying", "3" );
	DispatchSpawn( iEntity );

	//Block Terro Kill
	register_forward( FM_ClientKill,"FwdClientKill" );

	//Terro WIN
	register_logevent("terrorist_won" , 6, "3=Terrorists_Win", "3=Target_Bombed") 

	hud_progress = CreateHudSyncObj()

}

public plugin_natives()
{
	register_library("deathrun")

	register_native("get_bool_respawn", "get_bool_respawn_native");

	register_native("tempRespawn_disable", "tempRespawn_disable_native");

	register_native("set_next_terrorist", "set_next_terrorist_native");
}

public bool:get_bool_respawn_native(numParams){
	return b_RespawnMode;
}

public tempRespawn_disable_native(){
	b_RespawnActive = false;
}

public set_next_terrorist_native(numParams){
	new id = get_param(1);
	if(is_user_connected(terro_next))
		return terro_next;
	terro_next = id;
	return 0;
}

//Game Functions

public plugin_cfg(){
	//Disable Respawn on new map
	b_RespawnMode = false;
	g_bVoted = false;
	//Restart round in 10 seconds
	set_task(10.0, "round_restart");
	//Set those 2 cvars to not mess up with the gamemode
	set_cvar_num("mp_autoteambalance", 0);
	set_cvar_num("mp_limitteams", 0);
	//Set task to send a message once every 2 mins with info about the RespawnGameMode
	set_task(120.0, "respawn_message",_,_,_,"b");
	set_task(20.0, "players_check");
	set_task(20.0, "time_check");
	b_MapEnded = false;
	b_ManualToggled = false;
}

public plugin_end(){
	b_MapEnded = true;
}

//Client connected to the server
public client_putinserver(id){
	if(b_RespawnActive || b_RespawnMode)
		set_task(2.0, "player_respawn", id);
	else
		set_task(2.0, "player_death", id);

	lives[id] = 0;

	if(g_bVoting)
		set_task(5.0, "GAMEMODE_VOTE_MENU", id);

	new players[MAX_PLAYERS], iNum;
	get_players(players, iNum, "ch");

	if(iNum>4 && b_RespawnMode && !g_bVoted)
	{
		g_bVoted = true;
		GAMEMODE_VOTE_START();
	}
		
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

	for(new i;i<33;i++)
		g_DamageTaken[i] = 0.0;
}
//Round End
public event_round_end(){
	//Move Players from T to CT
	new player, players[32],numPlayers,i;
	get_players(players, numPlayers,"ce","TERRORIST");
	for( i = 0; i < numPlayers; i++ ) {
		player = players[ i ];
		cs_set_user_team( player, CS_TEAM_CT );
	}
	if(b_RespawnMode)
		return PLUGIN_CONTINUE;
	//Pick New Terrorist
	terrorist_pick();
	//Kill Respawn Task
	remove_task(taskid);
	return PLUGIN_CONTINUE;
}
//Round Restart
public round_restart(){
	event_round_end();
	event_round_start();

	new players[32],numPlayers;
	get_players(players, numPlayers,"ceh", "CT");
	for(new i;i<numPlayers;i++)
		ExecuteHamB(Ham_CS_RoundRespawn, players[i]);
}
//Player has spawned
public player_spawn(id){
	if(!is_user_connected(id))
		return PLUGIN_CONTINUE;
	//Give Items to player if he's not spectator
	if(cs_get_user_team(id) != CS_TEAM_SPECTATOR){
		set_task(0.2,"GiveItems",id);
	}

	set_task(0.5,"GetUserHealth",id);

	return PLUGIN_CONTINUE;
	
}

//Player has been killed
public player_killed(id, attacker){
	if(!is_user_connected(id))
		return HAM_IGNORED;
	
	if(is_user_connected(attacker)){
		if(attacker != id){
			lives[attacker]++;
			ColorChat(attacker, GREEN,"^x04%s^x01 Ai omorat un jucator, acum ai ^x03%d ^x01vieti.", serverPrefix, lives[attacker]);
		}
		
	}
	//Respawn the player if the respawn mode is active nor the respawn time has passed
	if(b_RespawnMode || b_RespawnActive){
		if(cs_get_user_team(id) == CS_TEAM_CT && !is_user_bot(id)){
			ExecuteHamB(Ham_CS_RoundRespawn, id);
			return HAM_SUPERCEDE;
		}
	}

	return HAM_IGNORED;
}

public player_hurt(id, inflictor, attacker, Float:damage, damagebits){
	static Float:multiplier;
	static Float:newDamage;
	if(!is_user_connected(attacker)){
		multiplier = g_StartHealth[id]/100.0;
		newDamage = damage * multiplier;
		SetHamParamFloat( 4 , newDamage );

		return HAM_HANDLED;
	}
	return HAM_IGNORED;
}

//Function to display info about lives
public life_diplay(id){
	ColorChat(id, GREEN,"^x04%s^x01 Ai ^x03%d ^x01vieti, foloseste comanda ^x03/revive ^x01pentru a le folosi.", serverPrefix, lives[id]);
}

//Function to respawn a player when he uses a life
public life_use(id){
	if(cs_get_user_team(id) == CS_TEAM_CT){
		if(checkCTAlive() < 2){
			client_print(id,print_chat, "Este doar un CT in viata, nu poti folosi aceasta comanda!");
			return PLUGIN_HANDLED;
		}
		if(lives[id]){
			lives[id]--;
			ExecuteHamB(Ham_CS_RoundRespawn, id);
			ColorChat(id, GREEN,"^x04%s^x01 Ti-ai folosit o viata, ai ramas cu ^x03%d ^x01vieti.", serverPrefix, lives[id]);
		}
		else{
			ColorChat(id, GREEN,"^x04%s^x01 Nu ai nicio viata, omoara un jucator pentru a castiga una.", serverPrefix);
			return PLUGIN_HANDLED;
		}
	}
	else{
		ColorChat(id, GREEN,"^x04%s^x01 Trebuie sa fii CT pentru a folosi aceasta comanda!", serverPrefix, lives[id]);
		return PLUGIN_HANDLED;
	}
	return PLUGIN_HANDLED;
}

//Function to respawn the players that's calling it
public player_respawn(id){
	if(b_RespawnMode && !is_user_bot(id)){
		ExecuteHamB(Ham_CS_RoundRespawn, id);
	}
	return HAM_IGNORED;
}

public player_death(id){
	user_silentkill(id);
	return HAM_IGNORED;
}

public player_switchteam(id)
{
	if (cs_get_user_team(id) == CS_TEAM_SPECTATOR){
		cs_set_user_team(id, CS_TEAM_CT, CS_DONTCHANGE);
		if(b_RespawnActive)
			cs_user_spawn(id);
	}
	else if(cs_get_user_team(id) == CS_TEAM_CT){
		cs_set_user_team(id, CS_TEAM_SPECTATOR, CS_DONTCHANGE);
		user_silentkill(id);
	}
	return;
}

//Hud Reset Event
public hud_reset(id){
	//Remove Hud
	message_begin(MSG_ONE_UNRELIABLE, HideWeapon, _, id);
	write_byte(2 | 16 | 32);
	message_end();
}

//Choose a random terrorist at round end
public terrorist_pick(){
	new players[32],numPlayers,newTerro,name[33];
	if(is_user_connected(terro_next)){
		get_user_name(terro_next, name,32);
		cs_set_user_team(terro_next, CS_TEAM_T);
		lastTerrorist = terro_next;
		ColorChat(0, GREEN,"^x04%s^x03 %s^x01 este noul terorist.", serverPrefix, name);
		terro_next = 0;
		return PLUGIN_CONTINUE;
	}
	get_players(players, numPlayers, "e", "CT");
	if(numPlayers<2)
		return PLUGIN_CONTINUE;
	//Pick a random player
	newTerro = players[random(numPlayers)];
	//Checks if he's connected
	if(!is_user_connected(newTerro)){
		set_task(0.1,"terrorist_pick");
		return PLUGIN_CONTINUE;
	}
		
	//Checks if he isn't the terrorist from the last round and that he's a CT
	if(newTerro != lastTerrorist){
		get_user_name(newTerro, name,32);
		cs_set_user_team(newTerro, CS_TEAM_T);
		lastTerrorist = newTerro;
		ColorChat(0, GREEN,"^x04%s^x03 %s^x01 este noul terorist.", serverPrefix, name);
	}
	//If the condition doesn't apply to the new terro the function is called again
	else{
		set_task(0.1,"terrorist_pick");
		return PLUGIN_CONTINUE;
	}
	
	return PLUGIN_CONTINUE;
}
//Replace the terrorist
public terrorist_replace(id){
	new players[32],numPlayers,newTerro,name[33],name2[33];
	get_players(players, numPlayers, "e", "CT");
	if(numPlayers<=1)
		return PLUGIN_CONTINUE;
	//Pick a random player
	newTerro = players[random_num(0,numPlayers-1)];
	get_user_name(id,name2, 32);
	//Checks if he's connected
	if(!is_user_connected(newTerro))
		set_task(0.1,"terrorist_replace");

	get_user_name(newTerro, name,32);
	//Move him to the Terrorists
	cs_set_user_team(newTerro, CS_TEAM_T);
	//Sets him as the last terrorist
	lastTerrorist = newTerro;
	ColorChat(0, GREEN,"^x04%s^x03 %s^x01 este noul terorist, deoarece^x03 %s^x01 s-a deconectat.", serverPrefix, name, name2);
	//Respawns him
	ExecuteHamB(Ham_CS_RoundRespawn, newTerro);
	
	return PLUGIN_CONTINUE;
}
//Check if there's a terrorist
public terrorist_check(id){
	new players[32],numPlayers;
	new bool:isTerro;
	//Get all terrorists
	get_players(players, numPlayers, "ce", "TERRORIST");
	//Going through all
	for(new i; i<numPlayers; i++){
		//Check if the current one is not the player that left, this function is called on client_disconnected
		if(players[i]!=id)
			isTerro = true;
	}

	get_players(players, numPlayers, "ch");
	//If a terrorist isn't found then we pick another player to be the terrorist
	if(!isTerro && numPlayers > 2)
		terrorist_replace(id);
	return PLUGIN_CONTINUE;
}
//Give Terro 3 points when his team won
public terrorist_won(){
	new player, players[32],numPlayers,i;
	get_players(players, numPlayers, "ae", "TERRORIST");
	for( i = 0; i < numPlayers; i++ ) {
		player = players[ i ];
		set_user_frags(player, get_user_frags(player)+3);
	 	lives[player]++;
		ColorChat(player, GREEN,"^x04%s^x01 Ai castigat runda, acum ai ^x03%d ^x01vieti.", serverPrefix, lives[player]);
	}
}
//Toggle the gamemode between deathrun and respawn
public gamemode_toggle(id){
	if(!(get_user_flags(id) & ADMIN_IMMUNITY))
		return PLUGIN_HANDLED;
	b_ManualToggled = !b_ManualToggled;
	b_RespawnMode = !b_RespawnMode;
	event_round_end();

	ColorChat(0, GREEN,"^x04%s^x01 Gamemode-ul a fost schimbat manual!", serverPrefix);
	if(b_RespawnMode)
		ColorChat(0, GREEN,"^x04%s^x01 Gamemode-ul current este^x04 RESPAWN!", serverPrefix);
	else
		ColorChat(0, GREEN,"^x04%s^x01 Gamemode-ul current este^x04 DEATHRUN!", serverPrefix);

	return PLUGIN_HANDLED;
}
//Disable the respawn
public respawn_disable(){
	b_RespawnActive = false;
	if(!b_RespawnMode){
		ColorChat(0, GREEN,"^x04%s^x01 Timpul de respawn s-a terminat!", serverPrefix);
		remove_task(taskid);
	}
}
public players_check(){
	if(b_ManualToggled)
		return PLUGIN_CONTINUE;
	
	new players[MAX_PLAYERS], iNum;
	get_players(players, iNum, "ch");
	if(iNum<4)
		GAMEMODE_VOTE_START();

	return PLUGIN_CONTINUE;
}

//Check the time , if it's between 12:00AM and 8:00AM, then a vote to choose the gamemode will emerge
public time_check(){
	if(b_ManualToggled)
		return PLUGIN_CONTINUE;
	new data[3];
	get_time("%H", data, 2);
	if(str_to_num(data) < 8){
		GAMEMODE_VOTE_START();
	}
	return PLUGIN_CONTINUE;
}

public GAMEMODE_VOTE_START(){
	if(g_bVoting == true)
		return PLUGIN_CONTINUE;

	g_bVoting = true;

	//RESET PREVIOUS VOTES IF ANY
	g_votes[0] = g_votes[1] = 0;

	new players[32], pnum, tempid;
	get_players( players, pnum );

	for ( new i; i < pnum; i++ )
	{
		tempid = players[i];
		GAMEMODE_VOTE_MENU(tempid);
		set_task(vote_time, "RemoveOffer", tempid);
	}

	set_task(vote_time, "GAMEMODE_VOTE_END" );
	set_task(1.0, "GAMEMODE_VOTE_PROGRESS",hud_progress_taskid,_,_,"b");

	return PLUGIN_HANDLED;

}

public GAMEMODE_VOTE_MENU(id){
	g_voteMenu = menu_create( "\rChoose the map gamemode!:", "GAMEMODE_VOTE_HANDLER" );

	menu_additem( g_voteMenu, "Deathrun", "", 0 );
	menu_additem( g_voteMenu, "Respawn", "", 0 );

	menu_display( id, g_voteMenu, 0 );
}

public GAMEMODE_VOTE_HANDLER(id, menu, item){

	if ( item == MENU_EXIT )
	{
		return PLUGIN_HANDLED;
	}

	new szName[32];
	get_user_name(id, szName, 31);

	ColorChat(0, GREEN,"^x04%s %s^x01 a votat pentru ^x04%s^x01!", serverPrefix, szName, item?"RESPAWN":"DEATHRUN");

	g_votes[ item ]++;

	return PLUGIN_HANDLED;
}

public GAMEMODE_VOTE_END(){
	g_bVoting = false;

	if ( g_votes[0] > g_votes[1] ){
		ColorChat(0, GREEN,"^x04%s^x01 Deathrun a castigat cu ^x03%d^x01 voturi!", serverPrefix, g_votes[0]);
		GAMEMODE_SET_DEATHRUN();
	}
	else if ( g_votes[0] < g_votes[1] ){
		ColorChat(0, GREEN,"^x04%s^x01 Respawn a castigat cu ^x03%d^x01 voturi!", serverPrefix, g_votes[1]);
		GAMEMODE_SET_RESPAWN();
	}
	else{
		ColorChat(0, GREEN,"^x04%s^x01 A fost egalitate intre cele doua optiuni!", serverPrefix);
		ColorChat(0, GREEN,"^x04%s^x01 Un gamemode o sa fie ales random!", serverPrefix);

		random(2)?GAMEMODE_SET_DEATHRUN():GAMEMODE_SET_RESPAWN();
	}

	remove_task(hud_progress_taskid);

	vote_time = 20.0;

	menu_destroy( g_voteMenu );
}

public GAMEMODE_VOTE_PROGRESS(){

	vote_time--;
	new players[32], pnum, tempid;
	get_players( players, pnum );

	set_hudmessage(51, 153, 255, -1.0, 0.25, 0, 0.01, 1.0, 0.01, 0.01, 3)

	for ( new i; i < pnum; i++ )
	{
		tempid = players[i];
		ShowSyncHudMsg(tempid, hud_progress, "DEATHRUN %d Voturi^nRESPAWN %d Voturi^n^nTimp de vot %d secunde", g_votes[0], g_votes[1], floatround(vote_time));
	}
}

public GAMEMODE_SET_RESPAWN(){
	ColorChat(0, GREEN,"^x04%s Respawn Gamemode^x01 a fost activat!", serverPrefix);
	if(b_RespawnMode) return PLUGIN_CONTINUE;
	b_RespawnMode = true;
	event_round_end();
	event_round_start();

	new players[32],numPlayers;
	get_players(players, numPlayers, "ceh", "CT");
	for(new i;i<numPlayers;i++)
		ExecuteHamB(Ham_CS_RoundRespawn, players[i]);

	return PLUGIN_CONTINUE;
}

public GAMEMODE_SET_DEATHRUN(){
	ColorChat(0, GREEN,"^x04%s Deathrun Gamemode^x01 a fost activat!", serverPrefix);
	if(!b_RespawnMode) return PLUGIN_CONTINUE;
	b_RespawnMode = false;
	event_round_end();
	event_round_start();

	new players[32],numPlayers;
	get_players(players, numPlayers,"ceh", "CT");
	for(new i;i<numPlayers;i++)
		ExecuteHamB(Ham_CS_RoundRespawn, players[i]);

	return PLUGIN_CONTINUE;
}

public GetUserHealth(id){
	if(!is_user_connected(id))
		return PLUGIN_CONTINUE;
	g_StartHealth[id] = get_user_health(id);

	return PLUGIN_CONTINUE;
}

//Give items to player
public GiveItems(id){
	if(!is_user_connected(id))
		return PLUGIN_CONTINUE;
	//Remove Player Weapons
	fm_strip_user_weapons(id);
	//Checking if he's CT
	if(cs_get_user_team(id) == CS_TEAM_CT){
		give_item(id,"weapon_usp");
		give_item(id,"ammo_45acp");
		give_item(id,"ammo_45acp");
	}
	give_item(id, "weapon_knife");
	return PLUGIN_CONTINUE;
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

//Block buttons during Respawn GameMode
public button_use(iButton, iActivator, iCaller, iUseType, Float:fValue)
{
	if(!b_RespawnMode)
		return HAM_IGNORED;

	return HAM_IGNORED;
}

//Message containing info about the Respawn GameMode
public respawn_message(){
	if(!b_RespawnMode)
		return PLUGIN_CONTINUE;
	ColorChat(0, GREEN,"^x04%s^x01 Poti folosi comanda^x03 [/start]^x01 pentru a te reseta la pozitia de start!", serverPrefix);
	return PLUGIN_CONTINUE;
}

//Dezactivate buttons
public fwButtonUsed(this, idcaller, idactivator, use_type, Float:value){
	if(idcaller!=idactivator) return HAM_IGNORED;
	
	if(pev(this, pev_frame) > 0.0)
		 return HAM_IGNORED;
	new index=get_ent_index(this);
	if(index==-1) 
		return HAM_IGNORED;
	if(b_RespawnMode){
			return HAM_SUPERCEDE;
	}
	return HAM_IGNORED;
}

get_ent_index(ent){
	return pev(ent, pev_iuser4)-1;
}

public checkCTAlive(){
	new playersAlive;
	for(new i;i<=33;i++)
		if(is_user_alive(i) && cs_get_user_team(i) == CS_TEAM_CT)
			playersAlive++;
	return playersAlive;
}

public RemoveOffer(id)
{	
	client_cmd( id, "slot10;slot1" )
}