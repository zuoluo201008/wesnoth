local H = wesnoth.require "lua/helper.lua"
local AH = wesnoth.require "ai/lua/ai_helper.lua"
local FAU = wesnoth.require "ai/micro_ais/cas/ca_fast_attack_utils.lua"
local LS = wesnoth.require "lua/location_set.lua"

local ca_fast_combat_leader = {}

function ca_fast_combat_leader:evaluation(cfg, data)
    -- Some parts of this are very similar to ca_fast_combat.lua.
    -- However, for speed reasons we really want this to be a separate CA, so
    -- that the (more expensive) calculations for keeping the leader safe only
    -- get done once, when all other Fast MAI CAs are entirely done.

    leader_weight = (cfg and cfg.leader_weight) or 2
    leader_attack_max_units = (cfg and cfg.leader_attack_max_units) or 3
    leader_additional_threat = (cfg and cfg.leader_additional_threat) or 1

    data.move_cache = { turn = wesnoth.current.turn }
    data.gamedata = FAU.gamedata_setup()

    local filter_own = H.get_child(cfg, "filter")
    local filter_enemy = H.get_child(cfg, "filter_second")
    local excluded_enemies, leader
    if (not filter_own) and (not filter_enemy) then
        leader = FAU.get_attackers(data, "leader")[1]
        if (not leader) then return 0 end
        excluded_enemies = FAU.get_attackers(data, "enemy")
    else
        leader = wesnoth.get_units(
            FAU.build_attack_filter("leader", filter_own)
        )[1]
        if (not leader) then return 0 end
        if filter_enemy then
            excluded_enemies = wesnoth.get_units(
                FAU.build_attack_filter("enemy", filter_enemy)
            )
        end
    end

    if (leader.attacks_left == 0) or (#leader.attacks == 0) then return 0 end

    local excluded_enemies_map = LS.create()

    -- Exclude enemies not matching [filter_enemy]
    if excluded_enemies then
        for _,e in ipairs(excluded_enemies) do
            excluded_enemies_map:insert(e.x, e.y)
        end
    end

    -- Exclude hidden enemies, except if attack_hidden_enemies=yes is set in [micro_ai] tag
    if (not cfg.attack_hidden_enemies) then
        local hidden_enemies = wesnoth.get_units {
            { "filter_side", { { "enemy_of", { side = wesnoth.current.side } } } },
            { "filter_vision", { side = wesnoth.current.side, visible = 'no' } }
        }

        for _,e in ipairs(hidden_enemies) do
            excluded_enemies_map:insert(e.x, e.y)
        end
    end

    local aggression = ai.get_aggression()
    if (aggression > 1) then aggression = 1 end
    local own_value_weight = 1. - aggression

    -- Get the locations to be avoided
    local avoid_map = FAU.get_avoid_map(cfg)

    -- Enemy power and number maps
    -- Currently, the power is simply the summed hitpoints of all enemies that
    -- can get to a hex
    local enemies = wesnoth.get_units {
        { "filter_side", { { "enemy_of", { side = wesnoth.current.side } } } }
    }

    local enemy_power_map = LS.create()
    local enemy_number_map = LS.create()

    for _,enemy in ipairs(enemies) do
        -- Only need to consider enemies that are close enough
        if (H.distance_between(leader.x, leader.y, enemy.x, enemy.y) <= (enemy.max_moves + leader.max_moves + 1)) then
            enemy_power = enemy.hitpoints

            local old_moves = enemy.moves
            enemy.moves = enemy.max_moves
            local reach = wesnoth.find_reach(enemy)
            enemy.moves = old_moves

            for _,loc in ipairs(reach) do
                enemy_power_map:insert(
                    loc[1], loc[2],
                    (enemy_power_map:get(loc[1], loc[2]) or 0) + enemy_power
                )
                enemy_number_map:insert(
                    loc[1], loc[2],
                    (enemy_number_map:get(loc[1], loc[2]) or 0) + 1
                )
            end
        end
    end

    local leader_info = FAU.get_unit_info(leader, data.gamedata)
    local leader_copy = FAU.get_unit_copy(leader.id, data.gamedata)

    -- If threatened_leader_fights=yes, check out the current threat (power only,
    -- not units) on the AI leader
    local leader_current_threat = 0
    if cfg and cfg.threatened_leader_fights then
        for xa,ya in H.adjacent_tiles(leader.x, leader.y) do
            local enemy_power = enemy_power_map:get(xa, ya) or 0
            if (enemy_power > leader_current_threat) then
                leader_current_threat = enemy_power
            end
        end
    end

    local attacks = AH.get_attacks({ leader }, { include_occupied = cfg.include_occupied_attack_hexes })

    if (#attacks > 0) then
        local max_rating, best_target, best_dst = -9e99
        for _,attack in ipairs(attacks) do
            if (not excluded_enemies_map:get(attack.target.x, attack.target.y))
                and (not avoid_map:get(attack.dst.x, attack.dst.y))
            then
                -- First check if the threat against the leader at this hex
                -- is acceptable
                local acceptable_attack = true
                for xa,ya in H.adjacent_tiles(attack.dst.x, attack.dst.y) do
                    local enemy_power = enemy_power_map:get(xa, ya) or 0
                    local enemy_number = enemy_number_map:get(xa, ya) or 0

                    -- A threat is considered acceptable, if it is within the
                    -- limits given for HP and units, or if it is not more than the
                    -- threat on the leader at the current position times
                    -- leader_additional_threat (the latter only if
                    -- threatened_leader_fights=yes is set, otherwise
                    -- leader_current_threat is zero)
                    if (enemy_power > leader_current_threat * leader_additional_threat) then
                        if (enemy_power * leader_weight > leader.hitpoints)
                            or (enemy_number > leader_attack_max_units)
                        then
                            acceptable_attack = false
                            break
                        end
                    end
                end

                if acceptable_attack then
                    local target = wesnoth.get_unit(attack.target.x, attack.target.y)
                    local target_info = FAU.get_unit_info(target, data.gamedata)

                    local att_stat, def_stat = FAU.battle_outcome(
                        leader_copy, target, { attack.dst.x, attack.dst.y },
                        leader_info, target_info, data.gamedata, data.move_cache
                    )

                    local rating, attacker_rating, defender_rating, extra_rating = FAU.attack_rating(
                        { leader_info }, target_info, { { attack.dst.x, attack.dst.y } },
                        { att_stat }, def_stat, data.gamedata,
                        {
                            own_value_weight = own_value_weight,
                            leader_weight = cfg.leader_weight
                        }
                    )

                    acceptable_attack = FAU.is_acceptable_attack(attacker_rating, defender_rating, own_value_weight)

                    if acceptable_attack and (rating > max_rating) then
                        max_rating, best_target, best_dst = rating, target, attack.dst
                    end
                end
            end
        end

        if best_target then
            data.leader = leader
            data.fast_target, data.fast_dst = best_target, best_dst
            return cfg.ca_score
        end
    end

    return 0
end

function ca_fast_combat_leader:execution(cfg, data)
    local leader = data.leader
    AH.movefull_outofway_stopunit(ai, leader, data.fast_dst.x, data.fast_dst.y)

    if (not leader) or (not leader.valid) then return end
    if (not data.fast_target) or (not data.fast_target.valid) then return end
    if (H.distance_between(leader.x, leader.y, data.fast_target.x, data.fast_target.y) ~= 1) then return end

    AH.checked_attack(ai, leader, data.fast_target)

    data.leader = nil
end

return ca_fast_combat_leader
