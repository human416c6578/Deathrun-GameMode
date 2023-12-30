#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <hamsandwich>
#include <fakemeta_util>
#include <engine>
#include <deathrun>

#define VERSION		"1.0"

native isPlayerVip(id);
forward timer_player_category_changed(id);

new const Float:VEC_DUCK_HULL_MIN[3] = { -16.0, -16.0, -18.0 };
new const Float:VEC_DUCK_HULL_MAX[3] = { 16.0, 16.0, 18.0 };

new start_position[33][3];
new Float:start_angles[33][3];
new Float:start_velocity[33][3];

new vip_lives[33];

new bool:used[33];

public plugin_init()
{
	register_plugin("Save Position", VERSION, "MrShark45");

	register_clcmd( "say /start", "Start" );
	register_clcmd( "say /reset", "ResetStart");
	register_clcmd( "say /save", "SaveStart" );

	register_logevent("event_round_start", 2, "1=Round_Start");

	RegisterHam(Ham_Spawn, "player", "player_spawn");

}

public client_putinserver(id){
	start_position[id][0] = 0;

	used[id] = false;

	if(isPlayerVip(id))
		vip_lives[id] = 2;

}

public event_round_start(){
	for(new i;i<33;i++){
		if(isPlayerVip(i))
			vip_lives[i] = 2;

		start_position[i][0] = 0;

		used[i] = false;
	}
		
}

public player_spawn(id){
	used[id] = false;
}

public timer_player_category_changed(id){
	start_position[id][0] = 0;
	used[id] = false;
}

public Start(id){
	if (cs_get_user_team(id) != CS_TEAM_CT) return PLUGIN_CONTINUE;

	if(!get_player_lives(id) && !is_respawn_active()) return PLUGIN_CONTINUE;

	ExecuteHamB(Ham_CS_RoundRespawn, id);

	if(!is_respawn_active())
		TakeLife(id);

	if(!start_position[id][0]) return PLUGIN_CONTINUE;

	set_pev( id, pev_flags, pev( id, pev_flags ) | FL_DUCKING );
	engfunc( EngFunc_SetSize, id, VEC_DUCK_HULL_MIN, VEC_DUCK_HULL_MAX )
	set_pev(id, pev_origin, start_position[id]);
	SetUserAgl(id, start_angles[id]);
	set_pev(id, pev_velocity, start_velocity[id]);

	used[id] = true;

	return PLUGIN_CONTINUE;
}

public SaveStart(id){
	if(used[id]){
		client_print(id, print_chat, "Trebuie sa iti resetezi save-ul pentru a salva din nou!");
		client_print(id, print_chat, "Foloseste comanda [/reset]!");
		return PLUGIN_HANDLED;
	}

	pev(id, pev_origin, start_position[id]);
	entity_get_vector(id, EV_VEC_angles, start_angles[id])
	start_angles[id][0] /= -3.0;
	pev( id, pev_velocity, start_velocity[id]);

	return PLUGIN_HANDLED;
}

public ResetStart(id){
	used[id] = false;

	start_position[id][0] = 0;
	start_position[id][1] = 0;
	start_position[id][2] = 0;

	start_angles[id][0] = 0.0;
	start_angles[id][1] = 0.0;
	start_angles[id][2] = 0.0;

	start_velocity[id][0] = 0.0;
	start_velocity[id][1] = 0.0;
	start_velocity[id][2] = 0.0;

	set_pev( id, pev_velocity, start_velocity[id]);
}

public TakeLife(id){
	if(get_player_lives(id)){
		set_player_lives(id, get_player_lives(id) - 1);
	}
}

stock SetUserAgl(id,Float:agl[3]){
	entity_set_vector(id,EV_VEC_angles,agl)
	entity_set_int(id,EV_INT_fixangle,1)
}

