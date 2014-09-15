/*
   Copyright (C) 2006 - 2015 by Joerg Hinrichs <joerg.hinrichs@alice-dsl.de>
   wesnoth playlevel Copyright (C) 2003 by David White <dave@whitevine.net>
   Part of the Battle for Wesnoth Project http://www.wesnoth.org/

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.
   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY.

   See the COPYING file for more details.
*/

/**
 *  @file
 *  Container for multiplayer game-creation parameters.
 */

#include "mp_game_settings.hpp"
#include "formula_string_utils.hpp"

mp_game_settings::mp_game_settings() :
	savegame_config(),
	name(),
	password(),
	hash(),
	mp_era(),
	mp_scenario(),
	mp_scenario_name(),
	mp_campaign(),
	difficulty_define(),
	active_mods(),
	addon_ids(),
	side_users(),
	show_configure(true),
	show_connect(true),
	num_turns(0),
	village_gold(0),
	village_support(1),
	xp_modifier(100),
	mp_countdown_init_time(0),
	mp_countdown_reservoir_time(0),
	mp_countdown_turn_bonus(0),
	mp_countdown_action_bonus(0),
	mp_countdown(false),
	use_map_settings(false),
	random_start_time(false),
	fog_game(false),
	shroud_game(false),
	allow_observers(false),
	shuffle_sides(false),
	saved_game(false),
	random_faction_mode(DEFAULT),
	options()
{}

mp_game_settings::mp_game_settings(const config& cfg)
	: savegame_config()
	, name(cfg["scenario"].str())
	, password()
	, hash(cfg["hash"].str())
	, mp_era(cfg["mp_era"].str())
	, mp_scenario(cfg["mp_scenario"].str())
	, mp_scenario_name(cfg["mp_scenario_name"].str())
	, mp_campaign(cfg["mp_campaign"].str())
	, difficulty_define(cfg["difficulty_define"].str())
	, active_mods(utils::split(cfg["active_mods"], ','))
	, addon_ids(utils::split(cfg["addon_ids"], ','))
	, side_users(utils::map_split(cfg["side_users"]))
	, show_configure(cfg["show_configure"].to_bool(true))
	, show_connect(cfg["show_connect"].to_bool(true))
	, num_turns(cfg["mp_num_turns"])
	, village_gold(cfg["mp_village_gold"])
	, village_support(cfg["mp_village_support"])
	, xp_modifier(cfg["experience_modifier"].to_int(100))
	, mp_countdown_init_time(cfg["mp_countdown_init_time"])
	, mp_countdown_reservoir_time(cfg["mp_countdown_reservoir_time"])
	, mp_countdown_turn_bonus(cfg["mp_countdown_turn_bonus"])
	, mp_countdown_action_bonus(cfg["mp_countdown_action_bonus"])
	, mp_countdown(cfg["mp_countdown"].to_bool())
	, use_map_settings(cfg["mp_use_map_settings"].to_bool())
	, random_start_time(cfg["mp_random_start_time"].to_bool())
	, fog_game(cfg["mp_fog"].to_bool())
	, shroud_game(cfg["mp_shroud"].to_bool())
	, allow_observers(cfg["observer"].to_bool())
	, shuffle_sides(cfg["shuffle_sides"].to_bool())
	, saved_game(cfg["savegame"].to_bool())
	, random_faction_mode(string_to_RANDOM_FACTION_MODE_default(cfg["random_faction_mode"].str(), DEFAULT))
	, options(cfg.child_or_empty("options"))
{
}

config mp_game_settings::to_config() const
{
	config cfg;

	cfg["scenario"] = name;
	cfg["hash"] = hash;
	cfg["mp_era"] = mp_era;
	cfg["mp_scenario"] = mp_scenario;
	cfg["mp_scenario_name"] = mp_scenario_name;
	cfg["mp_campaign"] = mp_campaign;
	cfg["difficulty_define"] = difficulty_define;
	cfg["active_mods"] = utils::join(active_mods, ",");
	cfg["addon_ids"] = utils::join(addon_ids, ",");
	cfg["side_users"] = utils::join_map(side_users);
	cfg["show_configure"] = show_configure;
	cfg["show_connect"] = show_connect;
	cfg["experience_modifier"] = xp_modifier;
	cfg["mp_countdown"] = mp_countdown;
	cfg["mp_countdown_init_time"] = mp_countdown_init_time;
	cfg["mp_countdown_turn_bonus"] = mp_countdown_turn_bonus;
	cfg["mp_countdown_reservoir_time"] = mp_countdown_reservoir_time;
	cfg["mp_countdown_action_bonus"] = mp_countdown_action_bonus;
	cfg["mp_num_turns"] = num_turns;
	cfg["mp_village_gold"] = village_gold;
	cfg["mp_village_support"] = village_support;
	cfg["mp_fog"] = fog_game;
	cfg["mp_shroud"] = shroud_game;
	cfg["mp_use_map_settings"] = use_map_settings;
	cfg["mp_random_start_time"] = random_start_time;
	cfg["observer"] = allow_observers;
	cfg["shuffle_sides"] = shuffle_sides;
	cfg["random_faction_mode"] = RANDOM_FACTION_MODE_to_string (random_faction_mode);
	cfg["savegame"] = saved_game;
	cfg.add_child("options", options);

	return cfg;
}
