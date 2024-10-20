#include <amxmodx>
#include <engine>
#include <hamsandwich>
#include <fakemeta>
#include <fakemeta_util>
#include <cstrike>
#include <fun>
#include <cromchat2>

#define HUD_TASKID 9123132
#define RESPAWN_TASKID 29482891


const CSW_PRIMARY   = (CSW_ALL_SHOTGUNS | CSW_ALL_SMGS | CSW_ALL_RIFLES | CSW_ALL_SNIPERRIFLES | CSW_ALL_MACHINEGUNS); 

new bool:g_bRespawnActive;
new g_pcvarRespawnTime;

new bool:b_MapEnded;
new g_iLastTerro;
new g_iNextTerro;

new bool:g_bEnabled; // Gamemode is enabled ( pick terrorist on round end )
new g_fwdEnableDeathrun;

new bool:g_bFirstSpawn[MAX_PLAYERS];

public plugin_init( ) {
	register_plugin( "Deathrun GameMode", "1.0", "MrShark45" );

	//Cvars
	//How many seconds the respawn is active
	g_pcvarRespawnTime = register_cvar("respawn_time","30.0");

	//Commands
	register_clcmd("say /usp","give_usp_cmd");

	//Command to switch team to spectator/ct
	register_clcmd("say /ct","player_switchteam_cmd");

	//Command to switch team to spectator/ct
	register_clcmd("say /spec","player_switchteam_cmd");

	//Events
	register_logevent("event_round_start", 2, "1=Round_Start");
	register_logevent("event_round_end", 2, "1=Round_End");
	RegisterHam(Ham_Spawn, "player", "event_player_spawn");
	RegisterHam(Ham_Killed, "player", "event_player_killed");

	//Forwards
	g_fwdEnableDeathrun = CreateMultiForward("forward_deathrun_enable", ET_IGNORE, FP_CELL);
	
	CC_SetPrefix("&x07[FWO]");

}

public plugin_natives()
{
	register_library("deathrun")

	register_native("is_deathrun_enabled", "is_deathrun_enabled_native");

	register_native("enable_deathrun", "enable_deathrun_native");

	register_native("is_respawn_active", "is_respawn_active_native");

	register_native("disable_respawn", "disable_respawn_native");

	register_native("set_next_terrorist", "set_next_terrorist_native");

	register_native("get_next_terrorist", "get_next_terrorist_native");
}

public is_deathrun_enabled_native() {
	return g_bEnabled;
}

public enable_deathrun_native() {
	new bool:value = bool:get_param(1);
	g_bEnabled = value;

	new ret;
	ExecuteForward(g_fwdEnableDeathrun, ret, g_bEnabled);
}

public bool:is_respawn_active_native(){
	return g_bRespawnActive;
}

public disable_respawn_native(){
	g_bRespawnActive = false;
}

public set_next_terrorist_native(numParams){
	new id = get_param(1);
	g_iNextTerro = id;
}

public get_next_terrorist_native(){
	if(is_user_connected(g_iNextTerro))
		return g_iNextTerro;
	return 0;
}

//Game Functions

public plugin_cfg(){
	register_dictionary("deathrun.txt");

	//Restart round in 10 seconds
	set_task(10.0, "round_restart");
	//Set those 2 cvars to not mess up with the gamemode
	set_cvar_num("mp_autoteambalance", 0);
	set_cvar_num("mp_limitteams", 0);

	b_MapEnded = false;
	g_bEnabled = true;

	set_task(1.0, "kill_bots",_,_,_,"b");
}

public plugin_end(){
	b_MapEnded = true;
}

//Client connected to the server
public client_putinserver(id){
	if(g_bRespawnActive)
		set_task(2.0, "respawn_player", id);
	else
		set_task(2.0, "kill_player", id);

	g_bFirstSpawn[id] = true;
}

public client_disconnected(id){
	//Replace the terrorist if he disconnects
	if(!b_MapEnded && g_iLastTerro == id && g_bEnabled) {
		new szName[32];
		get_user_name(id, szName, charsmax(szName));
		CC_SendMessage(0, "%l", "DISCONNECT_MSG", szName);
		//CC_SendMessage(0, "&x07%s &x01 s-a deconectat!", szName);
		terrorist_pick(true);
	}
}

//EVENTS
//Round Start
public event_round_start(){
	if(!g_bEnabled) return PLUGIN_CONTINUE;
	
	g_bRespawnActive = true;

	//Create Task to disable respawn after x seconds
	set_task(get_pcvar_float(g_pcvarRespawnTime), "respawn_disable", RESPAWN_TASKID);

	for (new i=0;i<MAX_PLAYERS;i++) {
		g_bFirstSpawn[i] = true;
	}

	return PLUGIN_CONTINUE;
}

//Round End
public event_round_end(){
	if(!g_bEnabled) return PLUGIN_CONTINUE;

	//Move Players from T to CT
	move_players(CS_TEAM_CT);

	terrorist_pick(false);

	if(task_exists(RESPAWN_TASKID))
		remove_task(RESPAWN_TASKID);
	
	return PLUGIN_CONTINUE;
}
//Round Restart
public round_restart(){
	event_round_end();
	event_round_start();

	respawn_players(CS_TEAM_CT);
}

public event_player_spawn(id){
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


public event_player_killed(victim, attacker){
	if(!is_user_connected(victim) || cs_get_user_team(victim) != CS_TEAM_CT || !g_bRespawnActive)
		return HAM_IGNORED;

	if(is_user_connected(attacker)) {
		set_task(1.0, "respawn_player", victim);
		return HAM_IGNORED;
	}
	else {
		// world killed him
		// return supercede so it doesn't show up in the kill feed
		ExecuteHamB(Ham_CS_RoundRespawn, victim);
		return HAM_SUPERCEDE;
	}
}


public give_usp_cmd(id){
	if(!is_user_connected(id) || !is_user_alive(id))
		return PLUGIN_CONTINUE;

	fm_strip_user_gun(id, CSW_USP);
	give_item(id,"weapon_usp");
	give_item(id,"ammo_45acp");
	give_item(id,"ammo_45acp");
	give_item(id, "weapon_knife");
	return PLUGIN_CONTINUE;
}

public player_switchteam_cmd(id)
{
	if (cs_get_user_team(id) == CS_TEAM_SPECTATOR){
		cs_set_user_team(id, CS_TEAM_CT);
		if(g_bRespawnActive || !g_bEnabled) // lazy fix to respawn player on other gamemodes as well
			respawn_player(id);
	}
	else if(cs_get_user_team(id) == CS_TEAM_CT){
		cs_set_user_team(id, CS_TEAM_SPECTATOR);
		user_silentkill(id);
	}
}

public respawn_player(id){
	if(!is_user_connected(id) || is_user_bot(id) || cs_get_user_team(id) != CS_TEAM_CT) return PLUGIN_HANDLED;

	ExecuteHamB(Ham_CS_RoundRespawn, id);

	return PLUGIN_HANDLED;
}

public kill_player(id){
	user_silentkill(id);
	return PLUGIN_HANDLED;
}

public terrorist_pick(bool:respawn){
	if(is_user_connected(g_iNextTerro)){
		set_terro(g_iNextTerro, respawn);
		return PLUGIN_CONTINUE;
	}
		

	if(get_players_alive(CS_TEAM_CT) < 2)
		return PLUGIN_CONTINUE;
	
	//Pick a random player
	new players[MAX_PLAYERS], iNum;
	get_players(players, iNum, "ch");
	new terro = players[random(iNum)];
		
	//Checks if he isn't the terrorist from the last round
	if(terro != g_iLastTerro && cs_get_user_team(terro) != CS_TEAM_SPECTATOR){
		set_terro(terro, respawn);
	}
	else{
		set_task(0.1, "terrorist_pick", respawn);
		return PLUGIN_CONTINUE;
	}
	
	return PLUGIN_CONTINUE;
}

public set_terro(id, bool:respawn) {
	new szName[32];
	get_user_name(id, szName, charsmax(szName));
	cs_set_user_team(id, CS_TEAM_T);
	g_iLastTerro = id;
	CC_SendMessage(0, "%l", 0, "NEW_TERRO_MSG", szName);
	g_iNextTerro = 0;
	fm_strip_user_weapons(id);

	if(respawn)
		ExecuteHamB(Ham_CS_RoundRespawn, id);

	return PLUGIN_CONTINUE;
}

public respawn_disable(){
	g_bRespawnActive = false;
	CC_SendMessage(0, "%l", 0, "RESPAWN_END_MSG");
	remove_task(RESPAWN_TASKID);
}

public give_items(id){
	if(!is_user_connected(id))
		return PLUGIN_CONTINUE;

	/*
	if(pev(id, pev_weapons) & CSW_PRIMARY && cs_get_user_team(id) != CS_TEAM_T) {
		fm_strip_user_weapons(id);
	}
	*/
	if(g_bFirstSpawn[id]) {
		fm_strip_user_weapons(id);
		g_bFirstSpawn[id] = false;
	}
		

	if(pev(id, pev_weapons) & CSW_USP) {
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

get_players_alive(CsTeams:team = CS_TEAM_UNASSIGNED) {
	new num = 0;

	for(new i = 0;i<MAX_PLAYERS;i++) {
		if(!is_user_connected(i) || is_user_bot(i)) continue;
		if(team != CS_TEAM_UNASSIGNED && cs_get_user_team(i) != team) continue;

		num++;
	}

	return num;
}

move_players(CsTeams:team) {
	for(new i = 0;i<MAX_PLAYERS;i++) {
		if(!is_user_connected(i) || is_user_bot(i)) continue;
		if(cs_get_user_team(i) == CS_TEAM_SPECTATOR) continue;

		cs_set_user_team(i, team);
	}
}

respawn_players(CsTeams:team = CS_TEAM_UNASSIGNED) {
	for(new i = 0;i<MAX_PLAYERS;i++) {
		if(!is_user_connected(i) || is_user_bot(i)) continue;

		if(team != CS_TEAM_UNASSIGNED && cs_get_user_team(i) != team) continue;
		
		ExecuteHamB(Ham_CS_RoundRespawn, i);
	}
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

public kill_bots(){
	if(!are_all_ct_dead()) return PLUGIN_CONTINUE;
	new players[MAX_PLAYERS], iBotsAlive;
	get_players(players, iBotsAlive, "adeh", "CT");

	for(new i;i<iBotsAlive;i++)
		user_silentkill(players[i]);

	return PLUGIN_CONTINUE;
}
