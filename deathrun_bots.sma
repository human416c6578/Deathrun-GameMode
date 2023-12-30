#include <amxmodx>
#include <amxmisc>
#include <hamsandwich>
#include <cstrike>
#include <fun>
#include <fakemeta_util>
#include <deathrun>

public plugin_init() {
	register_plugin("Deathrun YAPB Tero", "1.0", "MrShark45");

	//Events
	RegisterHam(Ham_Killed, "player", "event_player_killed");
}

public plugin_end() {
	server_cmd("yb kickall");
}

public event_player_killed(id, attacker) {
	if(!get_bool_respawn()) return PLUGIN_CONTINUE;

	// check if bot was killed so we can spawn another so the round doesn't end
	// we can kick the current bot later
	if(cs_get_user_team(id) == CS_TEAM_T) {
		if(is_user_bot(id)) {
			ExecuteHamB(Ham_CS_RoundRespawn, id);
			GiveItems(id);
		}
		if(!is_user_bot(id)) {
			server_cmd("yb kickall");
			server_cmd("yb add 4 2 1 0 MrBot45");
			new bot_id = get_bot_id();
			if(bot_id != 0) {
				ExecuteHamB(Ham_CS_RoundRespawn, bot_id);
				GiveItems(bot_id);
			}
			//respawn player
			cs_set_user_team(id, CS_TEAM_CT);
			ExecuteHamB(Ham_CS_RoundRespawn, id);
			GiveItems(id);
			
		}
		new next_tero = get_next_terrorist();
		if(next_tero != 0) {
			set_next_terrorist(0);
			cs_set_user_team(next_tero, CS_TEAM_T);
			ExecuteHamB(Ham_CS_RoundRespawn, next_tero);
			GiveItems(next_tero);
			server_cmd("yb kickall");
		}
		//respawn killer
		ExecuteHamB(Ham_CS_RoundRespawn, attacker);
		GiveItems(attacker);
		return HAM_SUPERCEDE;
	}

	return PLUGIN_CONTINUE;
}

public kick_bot(id) {
	new userid = get_user_userid(id);
	server_cmd("kick #%d", userid);
}

public GiveItems(id){
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