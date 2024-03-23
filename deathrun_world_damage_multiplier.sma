#include <amxmodx>
#include <cstrike>
#include <hamsandwich>
#include <fun>
#include <cromchat>

new g_StartHealth[33];

public plugin_init() {
    register_plugin("Deathrun World Damage Multiplier", "1.0", "MrShark45");

    RegisterHam(Ham_Spawn, "player", "player_spawn", 1);
    RegisterHam(Ham_TakeDamage, "player", "player_hurt", 1);
}

public player_spawn(id){
	if(!is_user_connected(id) || cs_get_user_team(id) == CS_TEAM_SPECTATOR)
		return PLUGIN_CONTINUE;

	set_task(0.5,"get_user_start_health", id);

	return PLUGIN_CONTINUE;
}

public player_hurt(id, inflictor, attacker, Float:damage, damagebits){
	static Float:multiplier;
	static Float:newDamage;

	if(get_user_health(id) > 250 && cs_get_user_team(id) == CS_TEAM_CT)
		set_user_health(id, 250);

	// multiplier for world damage
	// if the player spawns with more than 100hp
	if(!is_user_connected(attacker)){
		multiplier = g_StartHealth[id]/100.0;
		newDamage = damage * multiplier;
		SetHamParamFloat( 4 , newDamage );

		return HAM_HANDLED;
	}
	return HAM_IGNORED;
}


public get_user_start_health(id){
	if(!is_user_connected(id))
		return PLUGIN_CONTINUE;
	g_StartHealth[id] = get_user_health(id);

	return PLUGIN_CONTINUE;
}