#include <amxmodx>
#include <engine>
#include <hamsandwich>
#include <fakemeta>
#include <fakemeta_util>
#include <cstrike>
#include <fun>
#include <cromchat>
#include <reapi>

enum ( <<=1 )
{
    CheckPrimary = 1,
    CheckSecondary,
    CheckKnife,
    CheckNades,
    CheckC4
}

#define HUD_TASKID 9123132
#define RESPAWN_TASKID 29482891

//Prefix for chat messages
new serverPrefix[] = "[DR]";
//bools for respawn gamemode
new bool:g_bRespawnMode;
new bool:g_bRespawnActive;
//Variable to stock the respawn time
new g_pcvarRespawnTime;
//Task it for the task that disables the respawn

new lastTerrorist;

new bool:b_MapEnded;

new bool:b_ManualToggled;

//Stock Hud Element
new HideWeapon;

new terro_next;

//GAMEMODE VOTING
new g_votes[2];
new g_voteMenu;
//vote progress display
new g_hudObjectProgress;
new Float:vote_time = 15.0;
new bool:g_bVoting;
new bool:g_bVoted;


new g_bNewRound[33];

public plugin_init( ) {
	register_plugin( "Deathrun GameMode", "1.0", "MrShark45" );

	//Cvars
	//How many seconds the respawn is active
	g_pcvarRespawnTime = register_cvar("respawn_time","30.0");
	//Commands
	//Command to display info about lives
	register_clcmd("say /usp","give_usp");
	
	//Command to respawn the player when the respawn mode is activated
	// dezactivated because of deathrun_save
	//register_clcmd("say /start","player_respawn");
	
	//Command to switch team to spectator/ct
	register_clcmd("say /ct","player_switchteam");
	//Command to switch team to spectator/ct
	register_clcmd("say /spec","player_switchteam");
	//Command to start the gamemode vote
	register_clcmd("deathrun_vote", "gamemode_vote_cmd");
	//Command to toggle the gamemode
	register_clcmd("deathrun_toggle","gamemode_toggle");
	//Events
	register_logevent("event_round_start", 2, "1=Round_Start");
	register_logevent("event_round_end", 2, "1=Round_End");
	RegisterHam(Ham_Spawn, "player", "player_spawn");
	RegisterHam(Ham_Killed, "player", "player_killed");

	//Forwards
	//Get HUD
	HideWeapon = get_user_msgid("HideWeapon");
	//Reset Hud Event
	register_event("ResetHUD", "hud_reset", "b");
	
	g_hudObjectProgress = CreateHudSyncObj()
}

public plugin_natives()
{
	register_library("deathrun")

	register_native("get_bool_respawn", "get_bool_respawn_native");

	register_native("is_respawn_active", "is_respawn_active_native");

	register_native("tempRespawn_disable", "tempRespawn_disable_native");

	register_native("set_next_terrorist", "set_next_terrorist_native");

	register_native("get_next_terrorist", "get_next_terrorist_native");
}

public bool:get_bool_respawn_native(numParams){
	return g_bRespawnMode;
}

public bool:is_respawn_active_native(){
	return g_bRespawnActive || g_bRespawnMode;
}

public tempRespawn_disable_native(){
	g_bRespawnActive = false;
}

public set_next_terrorist_native(numParams){
	new id = get_param(1);
	terro_next = id;
}

public get_next_terrorist_native(){
	if(is_user_connected(terro_next))
		return terro_next;
	return 0;
}

//Game Functions

public plugin_cfg(){
	//Disable Respawn on new map
	g_bRespawnMode = false;
	g_bVoted = false;
	//Restart round in 10 seconds
	set_task(10.0, "round_restart");
	//Set those 2 cvars to not mess up with the gamemode
	set_cvar_num("mp_autoteambalance", 0);
	set_cvar_num("mp_limitteams", 0);
	//Set task to send a message once every 2 mins with info about the RespawnGameMode
	set_task(120.0, "respawn_message",_,_,_,"b");
	set_task(2.0, "kill_bots",_,_,_,"b");
	set_task(10.0, "players_check");
	set_task(10.0, "time_check");
	b_MapEnded = false;
	b_ManualToggled = false;
}

public plugin_end(){
	b_MapEnded = true;
}

//Client connected to the server
public client_putinserver(id){
	if(g_bRespawnActive || g_bRespawnMode)
		set_task(2.0, "player_respawn", id);
	else
		set_task(2.0, "player_death", id);

	if(g_bVoting)
		set_task(5.0, "GAMEMODE_VOTE_MENU", id);

	new players[MAX_PLAYERS], iNum;
	get_players(players, iNum, "ch");

	/*
	if(iNum>4 && g_bRespawnMode && !g_bVoted)
	{
		g_bVoted = true;
		GAMEMODE_VOTE_START();
	}
	*/
}

public client_disconnected(id){
	//Replace the terrorist if he disconnects
	if(g_bRespawnMode || b_MapEnded)
		return PLUGIN_CONTINUE;
	terrorist_check(id);

	return PLUGIN_CONTINUE;
}

//EVENTS
//Round Start
public event_round_start(){
	//Activate the respawn
	g_bRespawnActive = true;
	//Create Task to disable respawn after x seconds
	set_task(get_pcvar_float(g_pcvarRespawnTime), "respawn_disable", RESPAWN_TASKID);

	for(new i = 0;i<33;i++) {
		g_bNewRound[i] = true;
	}
		
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
	if(g_bRespawnMode)
		return PLUGIN_CONTINUE;

	terrorist_pick();

	remove_task(RESPAWN_TASKID);
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

public player_spawn(id){
	if(!is_user_connected(id) || cs_get_user_team(id) == CS_TEAM_SPECTATOR)
		return PLUGIN_CONTINUE;
		
	// On some maps players are stripped of weapons after a certain time
	// It doesn't matter that we call this function multiple times
	// If the player already has a pistol the function will not run
	give_items(id);
	set_task(0.1,"give_items", id);
	set_task(0.5,"give_items", id);

	return PLUGIN_CONTINUE;
}


public player_killed(victim, attacker){
	if(!is_user_connected(victim))
		return HAM_IGNORED;

	if(!g_bRespawnMode && !g_bRespawnActive)
		return HAM_IGNORED;

	if(cs_get_user_team(victim) != CS_TEAM_CT)
		return HAM_IGNORED;

	if(is_user_connected(attacker)) {
		set_task(1.0, "player_respawn", victim);
		return HAM_IGNORED;
	}
	else {
		// world killed him
		// return supercede so it doesn't show up in the kill feed
		ExecuteHamB(Ham_CS_RoundRespawn, victim);
		return HAM_SUPERCEDE;
	}
}


public give_usp(id){
	if(!is_user_connected(id) || !is_user_alive(id))
		return PLUGIN_CONTINUE;

	fm_strip_user_gun(id, CSW_USP);
	give_item(id,"weapon_usp");
	give_item(id,"ammo_45acp");
	give_item(id,"ammo_45acp");
	give_item(id, "weapon_knife");
	return PLUGIN_CONTINUE;
}


public player_respawn(id){
	if(!is_user_connected(id) || is_user_bot(id) || !g_bRespawnMode || cs_get_user_team(id) != CS_TEAM_CT) return PLUGIN_HANDLED;

	ExecuteHamB(Ham_CS_RoundRespawn, id);

	return PLUGIN_HANDLED;
}

public player_death(id){
	user_silentkill(id);
	return PLUGIN_HANDLED;
}

public player_switchteam(id)
{
	if (cs_get_user_team(id) == CS_TEAM_SPECTATOR){
		cs_set_user_team(id, CS_TEAM_CT, CS_DONTCHANGE);
		if(g_bRespawnActive)
			cs_user_spawn(id);
	}
	else if(cs_get_user_team(id) == CS_TEAM_CT){
		cs_set_user_team(id, CS_TEAM_SPECTATOR, CS_DONTCHANGE);
		user_silentkill(id);
	}
	return;
}

public hud_reset(id){
	//Remove Hud
	message_begin(MSG_ONE_UNRELIABLE, HideWeapon, _, id);
	write_byte(2 | 16 | 32);
	message_end();
}


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
	get_players(players, numPlayers, "ce", "CT");
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

public terrorist_replace(id){
	new players[32],numPlayers,newTerro,name[33],name2[33];
	get_players(players, numPlayers, "ce", "CT");
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

public gamemode_toggle(id){
	if(!(get_user_flags(id) & ADMIN_IMMUNITY))
		return PLUGIN_HANDLED;
	b_ManualToggled = !b_ManualToggled;
	g_bRespawnMode = !g_bRespawnMode;
	event_round_end();

	ColorChat(0, GREEN,"^x04%s^x01 Gamemode-ul a fost schimbat manual!", serverPrefix);
	if(g_bRespawnMode) {
		// add bot on respawn
		server_cmd("yb kickall");
		server_cmd("yb add 4 2 1 0 MrBot45");

		set_cvar_num("mp_round_infinite", 1);

		ColorChat(0, GREEN,"^x04%s^x01 Gamemode-ul current este^x04 RESPAWN!", serverPrefix);
	}
	else {
		server_cmd("yb kickall");

		set_cvar_num("mp_round_infinite", 1);

		ColorChat(0, GREEN,"^x04%s^x01 Gamemode-ul current este^x04 DEATHRUN!", serverPrefix);
	}

	return PLUGIN_HANDLED;
}

public respawn_disable(){
	g_bRespawnActive = false;
	if(!g_bRespawnMode){
		ColorChat(0, GREEN,"^x04%s^x01 Timpul de respawn s-a terminat!", serverPrefix);
		remove_task(RESPAWN_TASKID);
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

//Check the time , if it's between 6:00PM and 8:00AM, then a vote to choose the gamemode will emerge
public time_check(){
	if(b_ManualToggled)
		return PLUGIN_CONTINUE;
	new data[3];
	get_time("%H", data, 2);
	if((str_to_num(data) < 8) || (str_to_num(data) > 18)){
		GAMEMODE_VOTE_START();
	}
	return PLUGIN_CONTINUE;
}

public gamemode_vote_cmd(id){
	if(!(get_user_flags(id) & ADMIN_IMMUNITY)) return PLUGIN_HANDLED;

	GAMEMODE_VOTE_START();

	return PLUGIN_HANDLED;
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
		set_task(vote_time, "force_refuse", tempid);
	}

	set_task(vote_time, "GAMEMODE_VOTE_END" );
	set_task(1.0, "GAMEMODE_VOTE_PROGRESS",HUD_TASKID,_,_,"b");

	return PLUGIN_HANDLED;

}

public GAMEMODE_VOTE_MENU(id){
	if(!is_user_connected(id))
		return PLUGIN_HANDLED;
	g_voteMenu = menu_create( "\rChoose the map gamemode!:", "GAMEMODE_VOTE_HANDLER" );

	menu_additem( g_voteMenu, "\yClassic", "", 0 );
	menu_additem( g_voteMenu, "\rNo \yTerrorist", "", 0 );

	menu_display( id, g_voteMenu, 0 );

	return PLUGIN_HANDLED;
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

	remove_task(HUD_TASKID);

	vote_time = 15.0;

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
		ShowSyncHudMsg(tempid, g_hudObjectProgress, "Classic %d Voturi^nNo Terrorist %d Voturi^n^nTimp de vot ramas %d secunde", g_votes[0], g_votes[1], floatround(vote_time));
	}
}

public GAMEMODE_SET_RESPAWN(){
	ColorChat(0, GREEN,"^x04%s Respawn Gamemode^x01 a fost activat!", serverPrefix);
	if(g_bRespawnMode) return PLUGIN_CONTINUE;
	g_bRespawnMode = true;

	round_restart();

	set_cvar_num("mp_round_infinite", 1);
	
	// add bot on respawn
	server_cmd("yb kickall");
	server_cmd("yb add 4 2 1 0 MrBot45");

	return PLUGIN_CONTINUE;
}

public GAMEMODE_SET_DEATHRUN(){
	ColorChat(0, GREEN,"^x04%s Deathrun Gamemode^x01 a fost activat!", serverPrefix);
	if(!g_bRespawnMode) return PLUGIN_CONTINUE;
	g_bRespawnMode = false;

	round_restart();

	server_cmd("yb kickall");
	set_cvar_num("mp_round_infinite", 0);

	return PLUGIN_CONTINUE;
}


public give_items(id){
	if(!is_user_connected(id))
		return PLUGIN_CONTINUE;

	//Remove Player Weapons
	if(!g_bRespawnMode && g_bNewRound[id])
		fm_strip_user_weapons(id);

	g_bNewRound[id] = false;

	if(pev(id, pev_weapons) & CSW_ALL_PISTOLS || pev(id, pev_weapons) & CSW_USP) {
		cs_set_user_bpammo(id, CSW_USP, 244);
		return PLUGIN_CONTINUE;
	}

	give_item(id, "weapon_knife");

	//Checking if he's CT
	if(cs_get_user_team(id) == CS_TEAM_CT){
		give_item(id,"weapon_usp");
		give_item(id,"ammo_45acp");
		give_item(id,"ammo_45acp");
	}
	
	return PLUGIN_CONTINUE;
}


//Message containing info about the Respawn GameMode
public respawn_message(){
	if(!g_bRespawnMode)
		return PLUGIN_CONTINUE;
	ColorChat(0, GREEN,"^x04%s^x01 Poti folosi comanda^x03 [/start]^x01 pentru a te reseta la pozitia de start!", serverPrefix);
	return PLUGIN_CONTINUE;
}


stock get_ct_alive(){
	new players[MAX_PLAYERS], iCtAlive;
	get_players(players, iCtAlive, "aceh", "CT");
	
	return iCtAlive;
}

stock are_all_ct_dead(){
	new players[MAX_PLAYERS], iCt;
	
	get_players(players, iCt, "ceh", "CT");
	
	return (get_ct_alive() == 0 && iCt > 0);
}

public force_refuse(id)
{	
	client_cmd( id, "slot10;slot1" )
}

public kill_bots(){
	if(!are_all_ct_dead()) return PLUGIN_CONTINUE;
	new players[MAX_PLAYERS], iBotsAlive;
	get_players(players, iBotsAlive, "adeh", "CT");

	for(new i;i<iBotsAlive;i++)
		user_silentkill(players[i]);

	return PLUGIN_CONTINUE;
}
