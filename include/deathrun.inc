#pragma reqlib "deathrun"

native set_next_terrorist(id);
native get_next_terrorist();
native bool:is_deathrun_enabled();
native bool:is_respawn_active();
native enable_deathrun(bool:value);
native disable_respawn();
forward forward_deathrun_enable(bool:value);

