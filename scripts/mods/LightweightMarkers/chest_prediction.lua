-- Predicts the items the server reserved in each chest at mission start. The server's distribution
-- (PickupSystem._populate_pickups, scripts/extension_systems/pickups/pickup_system.lua:270-340,589-913)
-- is a deterministic function of the level seed, the pickup pool and the spawner layout, all of which
-- a client has. What differs per process is the pairs() order over the pool's string keys, so solve()
-- replays the distribution over those orders and keeps only what reproduces the floor pickups the
-- client can see. The engine functions come in through deps so offline tests can run the solver.

local MAX_SIMULATIONS = 20000
local MAX_STATES = 64
-- Fewer explained floor pickups than this is too weak a check to trust.
local MIN_MATCHED = 10
local MAX_ITEM_DISTANCE_SQ = 9
local CO_LOCATED_SQ = 0.0025
local EDGES = { "include", "exclude" }
-- What a pool name can turn into on the floor (pickup_settings.lua:89-104).
local SELECTED = {
    syringe_generic_pocketable = {
        "syringe_ability_boost_pocketable", "syringe_power_boost_pocketable", "syringe_speed_boost_pocketable",
    },
}

return function(deps)
    local next_random = deps.next_random
    local shuffle = deps.shuffle
    local selectors = deps.selectors
    local pool_values = deps.pool_values

    local function find(t, v)
        for i = 1, #t do
            if t[i] == v then
                return i
            end
        end
    end

    local function copy(t)
        local c = {}

        for i = 1, #t do
            c[i] = t[i]
        end

        return c
    end

    local function sorted_keys(t)
        local keys = {}

        for key in pairs(t) do
            keys[#keys + 1] = key
        end

        table.sort(keys)

        return keys
    end

    local function permutations(list)
        local out = {}

        local function rec(prefix, rest)
            if #rest == 0 then
                out[#out + 1] = prefix

                return
            end

            for i = 1, #rest do
                local p, r = copy(prefix), copy(rest)

                p[#p + 1] = table.remove(r, i)
                rec(p, r)
            end
        end

        rec({}, list)

        return out
    end

    -- Reads the replay inputs on a client or host in a linear mission. Private reads: the spawner
    -- components (pickup_spawner_extension.lua:25-87) and the pool from _fetch_settings
    -- (pickup_system.lua:74-128), which only allocates.
    local function capture()
        local state = Managers.state
        local extension_manager = state and state.extension
        local pickup_system = extension_manager and extension_manager:system("pickup_system")
        local component_system = extension_manager and extension_manager:system("component_system")
        local main_path = state and state.main_path

        if not pickup_system or not component_system or not main_path or main_path:path_type() ~= "linear" then
            return nil
        end

        local ok, pool = pcall(pickup_system._fetch_settings, pickup_system)

        if not ok or type(pool) ~= "table" then
            return nil
        end

        local spawners = {}

        for unit, extension in pairs(pickup_system:unit_to_extension_map()) do
            local pct = extension:percentage_through_level()

            if pct then
                local position = Unit.world_position(unit, 1)
                local comps = {}

                for i, component in ipairs(extension._components) do
                    local items = component.spawnable_pickups

                    comps[i] = {
                        dtype = component.distribution_type,
                        all = items == "all",
                        list = items ~= "all" and items or nil,
                    }
                end

                spawners[#spawners + 1] = {
                    key = unit,
                    pct = pct,
                    chest = extension:is_chest(),
                    x = position.x,
                    y = position.y,
                    z = position.z,
                    comps = comps,
                }
            end
        end

        local floor = {}

        for unit in pairs(extension_manager:get_entities("PickupAnimationExtension")) do
            if Unit.has_data(unit, "pickup_type") then
                local position = Unit.world_position(unit, 1)

                floor[#floor + 1] = { name = Unit.get_data(unit, "pickup_type"), x = position.x, y = position.y, z = position.z }
            end
        end

        return {
            seed = component_system:get_level_seed(),
            pool = pool,
            min_ratios = pickup_system._min_chest_spawner_ratios or {},
            spawners = spawners,
            floor = floor,
        }
    end

    local function distance_sq(a, b)
        local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z

        return dx * dx + dy * dy + dz * dz
    end

    -- snapshot: { seed, pool = { [dtype] = { [category] = { [name] = count } } }, min_ratios,
    --   spawners = { { key, pct, chest, x, y, z, comps = { { dtype, all, list } } } },
    --   floor = { { name, x, y, z } } }
    -- Returns { chests = { [key] = { name, ... } }, matched, candidates } or nil, reason.
    local function solve(snapshot, yield)
        yield = yield or function() end

        local spawners = {}

        for i, s in ipairs(snapshot.spawners) do
            spawners[i] = s
        end

        -- Linear paths sort by percentage (pickup_system.lua:213-218,282-283). Tied spawners keep an
        -- order that differs per process, but they are interchangeable in every later step: ties only
        -- decide which member gets an item, so tied chests are not shown.
        table.sort(spawners, function(a, b)
            return a.pct < b.pct
        end)

        -- Each floor pickup belongs to the spawner it sits on; spawners at the same spot share it.
        -- Spawners of different types on one spot could each have placed it, so it is not used.
        local observed_at = {}

        for _, item in ipairs(snapshot.floor) do
            local best, best_d = nil, MAX_ITEM_DISTANCE_SQ

            for _, s in ipairs(spawners) do
                local d = distance_sq(s, item)

                if d < best_d then
                    best, best_d = s, d
                end
            end

            if best then
                local group, dtype, mixed = {}, nil, false

                for _, s in ipairs(spawners) do
                    if distance_sq(s, best) < CO_LOCATED_SQ then
                        group[#group + 1] = s

                        for _, c in ipairs(s.comps) do
                            dtype = dtype or c.dtype
                            mixed = mixed or c.dtype ~= dtype
                        end
                    end
                end

                if not mixed then
                    for _, s in ipairs(group) do
                        observed_at[s] = observed_at[s] or {}
                        observed_at[s][#observed_at[s] + 1] = item
                    end
                end
            end
        end

        yield()

        -- Observations per distribution type and tie class (equal percentage), from floor spawners
        -- whose components all share that type; class sizes find tied chests.
        local observed, class_size = {}, {}

        for _, s in ipairs(spawners) do
            local dtype = s.comps[1] and s.comps[1].dtype
            local single = dtype ~= nil

            for _, c in ipairs(s.comps) do
                class_size[c.dtype] = class_size[c.dtype] or {}

                local sizes = class_size[c.dtype]

                sizes[s.pct] = sizes[s.pct] or {}
                sizes[s.pct][s] = true
                single = single and c.dtype == dtype
            end

            if single and not s.chest and observed_at[s] then
                observed[dtype] = observed[dtype] or {}

                local list = observed[dtype][s.pct] or {}

                observed[dtype][s.pct] = list

                for _, item in ipairs(observed_at[s]) do
                    if not find(list, item) then
                        list[#list + 1] = item
                    end
                end
            end
        end

        local seed = snapshot.seed
        local base = {}

        -- spawn_guaranteed per spawner in sorted order (pickup_spawner_extension.lua:191-208) with
        -- get_guaranteed_pickup (pickup_system.lua:589-631).
        local guaranteed = {}

        for _, s in ipairs(spawners) do
            for i, c in ipairs(s.comps) do
                if c.dtype == "guaranteed" and not c.all and c.list and #c.list > 0 then
                    local weights, total = {}, 0

                    for j, name in ipairs(c.list) do
                        local spawned = guaranteed[name]
                        local value = pool_values[name]

                        total = total + (spawned and value and 1 / (spawned * value) or 1)
                        weights[j] = total
                    end

                    local rnd

                    seed, rnd = next_random(seed)
                    rnd = rnd * total

                    local index = 1

                    while rnd > weights[index] do
                        if index == #c.list then
                            break
                        end

                        index = index + 1
                    end

                    local name = c.list[index]

                    guaranteed[name] = (guaranteed[name] or 0) + 1
                    base[#base + 1] = { spawner = s, comp = i, name = name, chest = s.chest }
                end
            end
        end

        local simulations = 0

        -- _check_spawn (pickup_system.lua:895-913), recording instead of spawning.
        local function check_spawn(entry, to_spawn, placements)
            for i = 1, #to_spawn do
                local name = to_spawn[i]

                if entry.all or entry.list and find(entry.list, name) then
                    placements[#placements + 1] = { spawner = entry.spawner, comp = entry.comp, name = name, chest = entry.chest }

                    return true, i
                end
            end

            return false
        end

        -- _spawn_linear_pickup_category (pickup_system.lua:717-860) with an explicit name order. The
        -- sections span from the first to the last entry of the usable list (:741-749), which an
        -- earlier category of the same type may have shuffled in place (:837). The last section's upper
        -- bound lands within rounding of the last entry's percentage, and the server computes
        -- percentages a few bits differently, so edge decides whether spawners at exactly that
        -- percentage fall inside the last section. Returns the seed and whether edge decided anything.
        local function run_category(name_order, amounts, usable, seed_in, placements, edge)
            local s = seed_in
            local to_spawn = {}

            for _, name in ipairs(name_order) do
                for _ = 1, amounts[name] do
                    local selected = name
                    local selector = selectors[name]

                    if selector then
                        selected, s = selector(s)
                    end

                    to_spawn[#to_spawn + 1] = selected
                end
            end

            s = shuffle(to_spawn, s)

            local num_sections = #to_spawn
            local section_size = 1 / num_sections
            local section_start = 0
            local spawn_debt = 0
            local edge_pct = nil
            local edge_used = false

            if #usable >= 2 then
                local first = usable[1].spawner.pct
                local last = usable[#usable].spawner.pct

                section_size = (1 - first - (1 - last)) / num_sections
                section_start = first
                edge_pct = last
            end

            for i = 1, num_sections do
                local section, used = {}, {}
                local section_end = section_start + section_size

                for j = 1, #usable do
                    local p = usable[j].spawner.pct
                    local inside = section_start <= p and p < section_end or num_sections == i and p == 1

                    if num_sections == i and p == edge_pct and section_start <= p and p ~= 1 then
                        inside = edge == "include"
                        edge_used = true
                    end

                    if inside then
                        section[#section + 1] = usable[j]
                    end
                end

                section_start = section_end

                local num_section = #section

                if num_section > 0 and spawn_debt >= 0 then
                    local in_section = math.min(1 + math.ceil(spawn_debt / (num_sections - i + 1)), num_section)

                    s = shuffle(section, s)

                    local spawned, previous = 0, nil

                    for _ = 1, in_section do
                        local available = #section

                        if previous then
                            local pp = previous.spawner.pct

                            table.sort(section, function(a, b)
                                return math.abs(pp - a.spawner.pct) < math.abs(pp - b.spawner.pct)
                            end)
                        end

                        for k = 1, available do
                            local selected = section[k]
                            local ok, index = check_spawn(selected, to_spawn, placements)

                            if ok then
                                used[#used + 1] = selected
                                table.remove(section, find(section, selected))
                                table.remove(to_spawn, index)
                                previous = selected
                                spawned = spawned + 1

                                break
                            end
                        end
                    end

                    spawn_debt = spawn_debt - (spawned - 1)
                else
                    spawn_debt = spawn_debt + 1
                end

                for j = 1, #used do
                    table.remove(usable, find(usable, used[j]))
                end
            end

            if spawn_debt > 0 then
                local n = #to_spawn

                if #usable > 0 then
                    s = shuffle(usable, s)

                    for _ = 1, n do
                        for j = 1, #usable do
                            local ok, index = check_spawn(usable[j], to_spawn, placements)

                            if ok then
                                table.remove(usable, j)
                                table.remove(to_spawn, index)

                                break
                            end
                        end
                    end
                end
            end

            return s, edge_used
        end

        -- Explained (matched) and unexplained (contradictions) floor pickups of one category: an
        -- observed item of the category's names in a tie class where the replay placed none.
        local function check_category(dtype, names, placements, from)
            local predicted = {}

            for i = from, #placements do
                local p = placements[i]
                local list = predicted[p.spawner.pct] or {}

                predicted[p.spawner.pct] = list
                list[#list + 1] = p.name
            end

            local contradictions, matched = 0, 0

            for pct, list in pairs(observed[dtype] or {}) do
                local remaining = predicted[pct] and copy(predicted[pct]) or {}

                for _, item in ipairs(list) do
                    if names[item.name] then
                        local i = find(remaining, item.name)

                        if i then
                            table.remove(remaining, i)
                            matched = matched + 1
                        else
                            contradictions = contradictions + 1
                        end
                    end
                end
            end

            return contradictions, matched
        end

        local types = {}

        for dtype in pairs(snapshot.pool) do
            if dtype ~= "rubberband_pool" then
                types[#types + 1] = dtype
            end
        end

        table.sort(types)

        -- Tied spawners are interchangeable only when they allow the same items: _check_spawn takes
        -- the first item a spawner allows (:895-913) and guaranteed weights depend on order (:589-631).
        -- Otherwise the per-process order of a tie changes the result, so nothing is predicted.
        local function contents_key(c)
            if c.all then
                return "all"
            end

            local list = copy(c.list or {})

            table.sort(list)

            return table.concat(list, "+")
        end

        local checked_types = copy(types)

        checked_types[#checked_types + 1] = "guaranteed"

        for _, dtype in ipairs(checked_types) do
            for _, members in pairs(class_size[dtype] or {}) do
                local spawner_count, key, differs = 0, nil, false

                for s in pairs(members) do
                    spawner_count = spawner_count + 1

                    for _, c in ipairs(s.comps) do
                        if c.dtype == dtype then
                            local k = contents_key(c)

                            key = key or k
                            differs = differs or k ~= key
                        end
                    end
                end

                if spawner_count > 1 and differs then
                    return nil, "tied spawners allow different items"
                end
            end
        end

        local type_info = {}

        for _, dtype in ipairs(types) do
            local usable = {}

            for _, s in ipairs(spawners) do
                for i, c in ipairs(s.comps) do
                    if c.dtype == dtype then
                        usable[#usable + 1] = { spawner = s, comp = i, chest = s.chest, all = c.all, list = c.list }
                    end
                end
            end

            local count, categories, chests = 0, {}, 0

            for category, names in pairs(snapshot.pool[dtype]) do
                local total, amounts, keys = 0, {}, {}

                for name, n in pairs(names) do
                    count = count + n

                    if n > 0 then
                        total = total + n
                        amounts[name] = n
                        keys[#keys + 1] = name
                    end
                end

                if total > 0 then
                    table.sort(keys)

                    local produced = {}

                    for _, name in ipairs(keys) do
                        for _, result in ipairs(SELECTED[name] or { name }) do
                            produced[result] = true
                        end
                    end

                    categories[#categories + 1] = { name = category, amounts = amounts, orders = permutations(keys), produced = produced }
                end
            end

            table.sort(categories, function(a, b)
                return a.name < b.name
            end)

            for _, u in ipairs(usable) do
                if u.chest then
                    chests = chests + 1
                end
            end

            type_info[dtype] = { usable = usable, count = count, categories = categories, chests = chests }
        end

        -- The chest-favouring trim in spawn_spread_pickups (pickup_system.lua:653-687).
        local function trim(dtype, usable, s)
            local info = type_info[dtype]
            local ratio = snapshot.min_ratios[dtype] or 0

            if info.count / #usable < ratio and info.chests > 0 then
                local initial = #usable
                local allowed = math.floor(info.count / ratio)
                local to_remove = math.min(initial - allowed, initial - info.count)
                local options = {}

                for i = 1, initial do
                    if not usable[i].chest then
                        options[#options + 1] = i
                    end
                end

                s = shuffle(options, s)

                for i = to_remove + 1, initial do
                    options[i] = nil
                end

                table.sort(options)

                for i = #options, 1, -1 do
                    table.remove(usable, options[i])
                end
            end

            return s
        end

        local aborted = false
        local cache = {}

        -- Every way one distribution type can run from a given seed without contradicting the floor.
        local function search_type(dtype, seed_in)
            local key = dtype .. "|" .. seed_in

            if cache[key] then
                return cache[key]
            end

            local info = type_info[dtype]
            local results = {}
            local usable = copy(info.usable)
            local s0 = trim(dtype, usable, seed_in)

            local function rec(s, usable_now, used, placements, matched, depth)
                if aborted then
                    return
                end

                if depth > #info.categories then
                    results[#results + 1] = { seed = s, placements = placements, matched = matched }

                    return
                end

                for _, category in ipairs(info.categories) do
                    if not used[category] then
                        for _, order in ipairs(category.orders) do
                            for _, edge in ipairs(EDGES) do
                                simulations = simulations + 1

                                if simulations > MAX_SIMULATIONS then
                                    aborted = true

                                    return
                                end

                                local u = copy(usable_now)
                                local pl = copy(placements)
                                local from = #pl + 1
                                local s_next, edge_used = run_category(order, category.amounts, u, s, pl, edge)
                                local contradictions, m = check_category(dtype, category.produced, pl, from)

                                yield()

                                if contradictions == 0 then
                                    used[category] = true
                                    rec(s_next, u, used, pl, matched + m, depth + 1)
                                    used[category] = nil
                                end

                                if aborted then
                                    return
                                end

                                -- Without a spawner on the edge both outcomes are the same run.
                                if not edge_used then
                                    break
                                end
                            end
                        end
                    end
                end
            end

            rec(s0, usable, {}, {}, 0, 1)
            cache[key] = results

            return results
        end

        -- Breadth over the order of distribution types (pickup_system.lua:319).
        local states = { { seed = seed, used = {}, placements = copy(base), matched = 0 } }

        for _ = 1, #types do
            local next_states = {}

            for _, st in ipairs(states) do
                for _, dtype in ipairs(types) do
                    if not st.used[dtype] then
                        for _, r in ipairs(search_type(dtype, st.seed)) do
                            if aborted then
                                return nil, "too many simulations"
                            end

                            local used = {}

                            for k in pairs(st.used) do
                                used[k] = true
                            end

                            used[dtype] = true

                            local placements = copy(st.placements)

                            for _, p in ipairs(r.placements) do
                                placements[#placements + 1] = p
                            end

                            next_states[#next_states + 1] = { seed = r.seed, used = used, placements = placements, matched = st.matched + r.matched }

                            if #next_states > MAX_STATES then
                                return nil, "too ambiguous"
                            end
                        end
                    end
                end

                if aborted then
                    return nil, "too many simulations"
                end
            end

            states = next_states

            if #states == 0 then
                return nil, "no replay matches the floor"
            end
        end

        local best = 0

        for _, st in ipairs(states) do
            best = math.max(best, st.matched)
        end

        if best < MIN_MATCHED then
            return nil, "too few floor pickups to confirm"
        end

        local top = {}

        for _, st in ipairs(states) do
            if st.matched == best then
                top[#top + 1] = st
            end
        end

        -- A chest is shown only when every equally good candidate agrees on it and it is not tied.
        local per_candidate = {}

        for i, st in ipairs(top) do
            local m = {}

            for _, p in ipairs(st.placements) do
                if p.chest then
                    m[p.spawner] = m[p.spawner] or {}
                    m[p.spawner][p.comp] = p.name
                end
            end

            per_candidate[i] = m
        end

        local chests = {}

        for _, s in ipairs(spawners) do
            if s.chest then
                local tied = false

                for _, c in ipairs(s.comps) do
                    for other in pairs(class_size[c.dtype][s.pct]) do
                        if other ~= s then
                            tied = true
                        end
                    end
                end

                if not tied then
                    local agreed, names = true, nil

                    for i = 1, #per_candidate do
                        local slots = per_candidate[i][s] or {}
                        local list = {}

                        for comp = 1, #s.comps do
                            if slots[comp] then
                                list[#list + 1] = slots[comp]
                            end
                        end

                        local signature = table.concat(list, ",")

                        if names == nil then
                            names = list
                            names.signature = signature
                        elseif names.signature ~= signature then
                            agreed = false
                        end
                    end

                    if agreed and names and #names > 0 then
                        names.signature = nil
                        chests[s.key] = names
                    end
                end
            end
        end

        return { chests = chests, matched = best, candidates = #top, simulations = simulations }
    end

    return {
        capture = capture,
        solve = solve,
    }
end
