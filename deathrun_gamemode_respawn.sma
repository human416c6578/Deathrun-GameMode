#include <amxmodx>
#include <cstrike>
#include <hamsandwich>
#include <deathrun>
#include <cromchat>

#define HUD_TASKID 9123132

#define VOTE_TIME 15.0

enum gamemodes{
	DEATHRUN,
	RESPAWN,
}

//GAMEMODE VOTING
new g_votes[gamemodes];

//vote progress display
new g_hudObjectProgress;
new Float:g_fVoteTime = VOTE_TIME;
new bool:g_bVoteInProgress;

new bool:g_bManualToggled;
new bool:g_bEnabled;

public plugin_init( ) {
	register_plugin( "Deathrun Respawn Gamemode", "1.0", "MrShark45" );
	
	//Command to start the gamemode vote
	register_clcmd("deathrun_vote", "gamemode_start_vote");
	//Command to toggle the gamemode
	register_clcmd("deathrun_toggle","gamemode_toggle");
	RegisterHam(Ham_Killed, "player", "event_player_killed");
	
	g_hudObjectProgress = CreateHudSyncObj()

	CC_SetPrefix("&x07[DR]");
}

public plugin_cfg() {
	register_dictionary("deathrun_respawn.txt");

	g_bManualToggled = false;
	g_bEnabled = false;

	set_task(10.0, "time_check");
	set_task(10.0, "players_check");
}

public event_player_killed(victim, attacker){
	if(!is_user_connected(victim) || cs_get_user_team(victim) != CS_TEAM_CT || !g_bEnabled)
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

public client_putinserver(id) {
	set_task(2.0, "respawn_player", id);
}

public gamemode_toggle(id){
	if(!(get_user_flags(id) & ADMIN_IMMUNITY))
		return PLUGIN_HANDLED;

	g_bManualToggled = !g_bManualToggled;
	g_bEnabled = !g_bEnabled;
	
	if(g_bEnabled)
		gamemode_set_respawn();
	else
		gamemode_set_deathrun();

	return PLUGIN_HANDLED;
}

public gamemode_start_vote(id){
	if(!(get_user_flags(id) & ADMIN_IMMUNITY)) return PLUGIN_HANDLED;

	GAMEMODE_VOTE_START();

	return PLUGIN_HANDLED;
}

public GAMEMODE_VOTE_START(){
	if(g_bVoteInProgress)
		return PLUGIN_CONTINUE;

	g_bVoteInProgress = true;

	//RESET PREVIOUS VOTES IF ANY
	g_votes[DEATHRUN] = g_votes[RESPAWN] = 0;

	new players[32], iNum;
	get_players( players, iNum, "ch" );

	for ( new i = 0; i < iNum; i++ )
	{
		GAMEMODE_VOTE_MENU(players[i]);
		set_task(g_fVoteTime, "force_refuse", players[i]);
	}

	set_task(g_fVoteTime, "GAMEMODE_VOTE_END" );
	set_task(1.0, "GAMEMODE_VOTE_PROGRESS",HUD_TASKID,_,_,"b");

	return PLUGIN_HANDLED;

}

public GAMEMODE_VOTE_MENU(id){
	if(!is_user_connected(id))
		return PLUGIN_HANDLED;
	new menu = menu_create( "\rChoose the map gamemode!:", "GAMEMODE_VOTE_HANDLER" );

	menu_additem( menu, "\yDeathrun", "", 0 );
	menu_additem( menu, "\rRespawn", "", 0 );

	menu_display( id, menu, 0 );

	return PLUGIN_HANDLED;
}

public GAMEMODE_VOTE_HANDLER(id, menu, item){

	if ( item == MENU_EXIT || !g_bVoteInProgress )
	{
		return PLUGIN_HANDLED;
	}

	new szName[32];
	get_user_name(id, szName, 31);

	CC_SendMessage(0, "%L", LANG_PLAYER, "VOTE_MSG" ,szName, item?"RESPAWN":"DEATHRUN");

	g_votes[ item ]++;

	menu_destroy( menu );

	return PLUGIN_HANDLED;
}

public GAMEMODE_VOTE_END(){
	g_bVoteInProgress = false;

	if ( g_votes[DEATHRUN] > g_votes[RESPAWN] ){
		CC_SendMessage(0, "%L", LANG_PLAYER, "GAMEMODE_WON_MSG", "Deathrun", g_votes[DEATHRUN]);
		gamemode_set_deathrun();
	}
	else if ( g_votes[DEATHRUN] < g_votes[RESPAWN] ){
		CC_SendMessage(0, "%L", LANG_PLAYER, "GAMEMODE_WON_MSG", "Respawn", g_votes[RESPAWN]);
		gamemode_set_respawn();
	}
	else{
		CC_SendMessage(0, "%L", LANG_PLAYER, "GAMEMODE_EQUAL_MSG");
		CC_SendMessage(0, "%L", LANG_PLAYER, "GAMEMODE_RANDOM_MSG");

		random(2)?gamemode_set_deathrun():gamemode_set_respawn();
	}

	remove_task(HUD_TASKID);

	g_fVoteTime = VOTE_TIME;
}

public GAMEMODE_VOTE_PROGRESS(){

	g_fVoteTime--;
	new players[32], pnum, tempid;
	get_players( players, pnum );

	set_hudmessage(51, 153, 255, -1.0, 0.25, 0, 0.01, 1.0, 0.01, 0.01, 3)

	for ( new i; i < pnum; i++ )
	{
		tempid = players[i];
		ShowSyncHudMsg(tempid, g_hudObjectProgress, "DEATHRUN %d Voturi^nRESPAWN %d Voturi^n^nTimp de vot ramas %d secunde", g_votes[DEATHRUN], g_votes[RESPAWN], floatround(g_fVoteTime));
	}
}

public gamemode_set_respawn(){
	CC_SendMessage(0, "%L", LANG_PLAYER, "GAMEMODE_ACTIVATED_MSG", "Respawn");
	if(g_bEnabled && !is_deathrun_enabled()) return PLUGIN_CONTINUE;
	g_bEnabled = true;

	enable_deathrun(false);

	set_cvar_num("mp_round_infinite", 1);

	move_players(CS_TEAM_CT);
	respawn_players(CS_TEAM_CT);

	return PLUGIN_CONTINUE;
}

public gamemode_set_deathrun(){
	CC_SendMessage(0, "%L", LANG_PLAYER, "GAMEMODE_ACTIVATED_MSG", "Deathrun");
	if(!g_bEnabled && is_deathrun_enabled()) return PLUGIN_CONTINUE;
	g_bEnabled = false;

	enable_deathrun(true);

	set_cvar_num("sv_restart", 1);
	set_cvar_num("mp_round_infinite", 0);

	return PLUGIN_CONTINUE;
}


public players_check(){
	if(g_bManualToggled)
		return PLUGIN_CONTINUE;
	
	new players[MAX_PLAYERS], iNum;
	get_players(players, iNum, "ch");
	if(iNum<6)
		GAMEMODE_VOTE_START();

	return PLUGIN_CONTINUE;
}

//Check the time , if it's between 6:00PM and 8:00AM, then a vote to choose the gamemode will emerge
public time_check(){
	if(g_bManualToggled)
		return PLUGIN_CONTINUE;
	new data[3];
	get_time("%H", data, 2);
	if((str_to_num(data) < 8) || (str_to_num(data) > 18)){
		GAMEMODE_VOTE_START();
	}
	return PLUGIN_CONTINUE;
}

public respawn_player(id){
	if(cs_get_user_team(id) == CS_TEAM_CT)
		ExecuteHamB(Ham_CS_RoundRespawn, id);

	return PLUGIN_HANDLED;
}

public force_refuse(id)
{	
	client_cmd( id, "slot10;slot1" )
}

move_players(CsTeams:team) {
	for(new i = 0;i<MAX_PLAYERS;i++) {
		if(!is_user_connected(i) || is_user_bot(i)) continue;

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