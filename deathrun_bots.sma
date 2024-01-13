#include <amxmodx>
#include <amxmisc>
#include <hamsandwich>
#include <cstrike>
#include <fun>
#include <fakemeta_util>
#include <deathrun>
#include <save>

public plugin_init() {
	register_plugin("Deathrun YAPB Tero", "1.0", "MrShark45");

	//Events
	RegisterHam(Ham_Killed, "player", "event_player_killed", 1);
}

public plugin_end() {
	server_cmd("yb kickall instant");
}

public event_player_killed(id, attacker) {
	if(is_deathrun_enabled()) return HAM_IGNORED;

	// check if bot was killed so we can respawn him
	if(cs_get_user_team(id) == CS_TEAM_T) {
		// the terrorist was a bot
		// respawn him
		if(is_user_bot(id)) {
			set_task(1.0, "respawn_player", id);
		}
		else {
			cs_set_user_team(id, CS_TEAM_CT);
			set_task(1.0, "respawn_player", id);

			server_cmd("yb add 4 1 1 0 MrBot45");
			set_task(1.0, "respawn_bot");
		}

		new next_tero = get_next_terrorist();

		if(next_tero != 0) {
			set_next_terrorist(0);
			cs_set_user_team(next_tero, CS_TEAM_T);
			set_task(1.0, "respawn_player", id);
			server_cmd("yb kickall instant");
		}
		//respawn killer
		//to make sure the killer doesn't exploit the save function we have to reset it
		if(is_user_connected(attacker)) {
#if defined reset_save
			reset_save(attacker);
#endif
			set_task(1.0, "respawn_player", attacker);
		}
	}

	return HAM_IGNORED;
}

public forward_deathrun_enable(bool:value) {
	if(value)
		server_cmd("yb kickall instant");
	else {
		server_cmd("yb add 4 1 1 0 MrBot45");
		set_task(1.0, "respawn_bot");
	}
		
		
}

public respawn_player(id) {
	if(!is_user_connected(id)) return PLUGIN_HANDLED;

	ExecuteHamB(Ham_CS_RoundRespawn, id);
	give_player_items(id);

	return PLUGIN_HANDLED;
}

public respawn_bot() {
	new bot_id = get_bot_id();
	if(bot_id != 0)	respawn_player(bot_id);

	return PLUGIN_HANDLED;
}

public give_player_items(id){
	if(!is_user_connected(id))
		return PLUGIN_CONTINUE;

	//Remove Player Weapons
	fm_strip_user_weapons(id);

	give_item(id, "weapon_knife");

	//Checking if he's CT
	if(cs_get_user_team(id) == CS_TEAM_CT){
		give_item(id,"weapon_usp");
		give_item(id,"ammo_45acp");
		give_item(id,"ammo_45acp");
	}
	else if(cs_get_user_team(id) == CS_TEAM_T){
		set_user_health(id, 200);
		fm_give_item(id, "weapon_ak47");
		fm_give_item(id, "weapon_m4a1");
		cs_set_user_bpammo(id, CSW_AK47, 200);
		cs_set_user_bpammo(id, CSW_M4A1, 200);
	}
	
	return PLUGIN_CONTINUE;
}

stock get_bot_id() {
	for(new i=1;i<33;i++) {
		if(!is_user_bot(i)) continue;
		if(cs_get_user_team(i) == CS_TEAM_T) {
			return i;
		}
	}

	return 0;
}