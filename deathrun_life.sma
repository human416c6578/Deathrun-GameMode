#include <amxmodx>
#include <cstrike>
#include <hamsandwich>
#include <cromchat>

new g_iLives[MAX_PLAYERS];

public plugin_init() {
	register_plugin("Deathrun Life", "1.0", "MrShark45");

	//Command to display info about lives
	register_clcmd("say /lives","life_diplay");
	//Command to respawn the player using a life
	register_clcmd("say /revive","life_use");

	RegisterHam(Ham_Killed, "player", "player_killed");

	CC_SetPrefix("^x04[DR]");
}

public plugin_natives() {
	register_library("deathrun_life");

	register_native("get_player_lives", "get_player_lives_native");
	register_native("set_player_lives", "set_player_lives_native");
}

public client_putinserver(id) {
	g_iLives[id] = 0;
}

public get_player_lives_native(numParams){
	new id = get_param(1);
	return g_iLives[id];
}

public set_player_lives_native(numParams){
	new id = get_param(1);
	new value = get_param(2);

	g_iLives[id] = value;
}

public player_killed(victim, attacker) {
	if(!is_user_connected(attacker) || attacker == victim) return HAM_IGNORED;

	g_iLives[attacker]++;
	CC_SendMessage(attacker,"^x01 Ai omorat un jucator, acum ai ^x03%d ^x01vieti.", g_iLives[attacker]);

	return HAM_IGNORED;
}

//Function to display info about lives
public life_diplay(id){
	CC_SendMessage(id, "^x01 Ai ^x03%d ^x01vieti, foloseste comanda ^x03/revive ^x01pentru a le folosi.",g_iLives[id]);
}

//Function to respawn a player when he uses a life
public life_use(id){
	if(cs_get_user_team(id) == CS_TEAM_CT){
		if(get_ct_alive() < 2){
			client_print(id,print_chat, "Este doar un CT in viata, nu poti folosi aceasta comanda!");
		}
		if(g_iLives[id]){
			g_iLives[id]--;
			ExecuteHamB(Ham_CS_RoundRespawn, id);
			CC_SendMessage(id,"^x01 Ti-ai folosit o viata, ai ramas cu ^x03%d ^x01vieti.",g_iLives[id]);
		}
		else{
			CC_SendMessage(id,"^x01 Nu ai nicio viata, omoara un jucator pentru a castiga una.");
		}
	}
	else{
		CC_SendMessage(id,"^x01 Trebuie sa fii CT pentru a folosi aceasta comanda!",g_iLives[id]);
	}

	return PLUGIN_HANDLED;
}

stock get_ct_alive(){
	new players[MAX_PLAYERS], iCtAlive;
	get_players(players, iCtAlive, "aceh", "CT");
	
	return iCtAlive;
}