#include <amxmodx>
#include <cstrike>
#include <hamsandwich>
#include <cromchat2>
#include <deathrun>

new g_iLives[MAX_PLAYERS];
new g_iExtraLives[MAX_PLAYERS];
// instead of checking if isPlayerVip here, give in vip plugin extra lives
// create natives set_extra_lives(id, num) and get_extra_lives(id) so it's easier to manage

public plugin_init() {
	register_plugin("Deathrun Life", "1.0", "MrShark45");

	//Command to display info about lives
	register_clcmd("say /lives","life_diplay");
	//Command to respawn the player using a life
	register_clcmd("say /revive","life_use");

	RegisterHam(Ham_Killed, "player", "player_killed");

	CC_SetPrefix("&x04[FWO]");
}

public plugin_natives() {
	register_library("deathrun_life");

	register_native("get_player_lives", "get_player_lives_native");
	register_native("get_player_extra_lives", "get_player_extra_lives_native");
	register_native("set_player_lives", "set_player_lives_native");
	register_native("set_player_extra_lives", "set_player_extra_lives_native");
}

public plugin_cfg() {
	register_dictionary("deathrun_life.txt");
}

public client_putinserver(id) {
	g_iLives[id] = 0;
}

public get_player_lives_native(numParams){
	new id = get_param(1);

	return g_iLives[id];
}

public get_player_extra_lives_native(numParams){
	new id = get_param(1);

	return g_iExtraLives[id];
}

public set_player_lives_native(numParams){
	new id = get_param(1);
	new value = get_param(2);

	g_iLives[id] = value;
}

public set_player_extra_lives_native(numParams){
	new id = get_param(1);
	new value = get_param(2);

	g_iExtraLives[id] = value;
}

public player_killed(victim, attacker) {
	if(!is_user_connected(attacker) || attacker == victim) return HAM_IGNORED;

	g_iLives[attacker]++;
	CC_SendMessage(attacker, "%L", attacker, "KILL_PLAYER_MSG", g_iLives[attacker]);

	return HAM_IGNORED;
}

//Function to display info about lives
public life_diplay(id){
	CC_SendMessage(id, "%L", id, "DISPLAY_LIVES_MSG", g_iLives[id]);
}

//Function to respawn a player when he uses a life
public life_use(id){
	if(cs_get_user_team(id) != CS_TEAM_CT) {
		CC_SendMessage(id, "%L", id, "DENY_REVIVE_TEAM_MSG");
		return PLUGIN_HANDLED;
	}
	if(is_respawn_active()){
		ExecuteHamB(Ham_CS_RoundRespawn, id);
		return PLUGIN_HANDLED;
	}
	if(get_ct_alive() < 2){
		client_print(id,print_chat, "%L", id, "DENY_REVIVE_ALIVE_MSG");
		return PLUGIN_HANDLED;
	}
	if(!g_iExtraLives[id] && !g_iLives[id]) {
		CC_SendMessage(id, "%L", id, "DENY_REVIVE_NO_LIVES_MSG");
		return PLUGIN_HANDLED;
	}

	if(g_iExtraLives[id]){
		g_iExtraLives[id]--;
		ExecuteHamB(Ham_CS_RoundRespawn, id);
		return PLUGIN_HANDLED;
	}
	
	if(g_iLives[id]){
		g_iLives[id]--;
		ExecuteHamB(Ham_CS_RoundRespawn, id);
		CC_SendMessage(id, "%L", id, "LIFE_USE_MSG", g_iLives[id]);
		return PLUGIN_HANDLED;
	}

	return PLUGIN_HANDLED;
}

stock get_ct_alive(){
	new players[MAX_PLAYERS], iCtAlive;
	get_players(players, iCtAlive, "aceh", "CT");
	
	return iCtAlive;
}