-- Offline check of the chest prediction solver against two real online missions: client dumps of the
-- spawners, floor pickups and pool taken at mission start on 2026-10-14 (tests/fixtures). In the second
-- mission the user opened the chests afterwards; the predictions asserted here are the ones confirmed
-- in game. Run from the workspace root:
--   tools/luajit/luajit mods/active/LightweightMarkers/tests/test_chest_prediction.lua

local MOD_DIR = "mods/active/LightweightMarkers/scripts/mods/LightweightMarkers/"
local FIXTURES = "mods/active/LightweightMarkers/tests/fixtures/"

package.path = "darktide-source/?.lua;" .. package.path

-- Engine native math.next_random: the Numerical Recipes LCG identified from in-game samples
-- (types/SOURCES.md, math.next_random).
local TWO32 = 4294967296

function math.next_random(seed, a, b)
    local n = (1664525 * (seed % TWO32) + 1013904223) % TWO32
    local v = n / TWO32
    local s = n >= 2147483648 and n - TWO32 or n

    if b then
        return s, a + math.floor(v * (b - a + 1))
    elseif a then
        return s, 1 + math.floor(v * a)
    end

    return s, v
end

-- table.shuffle, seeded branch (scripts/foundation/utilities/table.lua:781-799).
local function shuffle(source, seed)
    for ii = #source, 2, -1 do
        local swap

        seed, swap = math.next_random(seed, ii)
        source[swap], source[ii] = source[ii], source[swap]
    end

    return seed
end

table.enum = function(...)
    local t = {}

    for _, k in ipairs({ ... }) do
        t[k] = k
    end

    return t
end
settings = function(_, t)
    return t
end

local PickupSettings = require("scripts/settings/pickup/pickup_settings")
local PickupPools = require("scripts/settings/pickup/pickup_pools")
local ChestPrediction = dofile(MOD_DIR .. "chest_prediction.lua")({
    next_random = math.next_random,
    shuffle = shuffle,
    selectors = PickupSettings.pickup_selector,
    pool_values = PickupSettings.pickup_pool_value,
})

local checks, failures = 0, 0

local function check(condition, fmt, ...)
    checks = checks + 1

    if not condition then
        failures = failures + 1
        print("FAIL: " .. string.format(fmt, ...))
    end
end

-- Snapshot from a dump: S, P, Q (pool from the client's _fetch_settings) and R lines. The first dump
-- predates Q lines; its pool is the default pool at its challenge, as _fetch_settings builds it.
local function load_snapshot(file, seed, challenge)
    local snapshot = { seed = seed, spawners = {}, floor = {}, min_ratios = {}, pool = nil }

    for line in io.lines(FIXTURES .. file) do
        local kind = line:sub(1, 2)

        if kind == "S|" then
            local li, pct, chest, x, y, z, comps = line:match("^S|([^|]*)|([^|]*)|([^|]*)|([^,]*),([^,]*),([^|]*)|(.*)$")
            local s = { key = li, pct = tonumber(pct), chest = chest == "1", x = tonumber(x), y = tonumber(y), z = tonumber(z), comps = {} }

            for c in comps:gmatch("[^;]+") do
                local dtype, items = c:match("^([^:]*):(.*)$")
                local list = nil

                if items ~= "all" then
                    list = {}

                    for name in items:gmatch("[^+]+") do
                        list[#list + 1] = name
                    end
                end

                s.comps[#s.comps + 1] = { dtype = dtype, all = items == "all", list = list }
            end

            snapshot.spawners[#snapshot.spawners + 1] = s
        elseif kind == "P|" then
            local name, x, y, z = line:match("^P|([^|]*)|([^,]*),([^,]*),(.*)$")

            snapshot.floor[#snapshot.floor + 1] = { name = name, x = tonumber(x), y = tonumber(y), z = tonumber(z) }
        elseif kind == "Q|" then
            local dtype, category, name, count = line:match("^Q|([^|]*)|([^|]*)|([^|]*)|(.*)$")

            snapshot.pool = snapshot.pool or {}
            snapshot.pool[dtype] = snapshot.pool[dtype] or {}
            snapshot.pool[dtype][category] = snapshot.pool[dtype][category] or {}
            snapshot.pool[dtype][category][name] = tonumber(count)
        elseif kind == "R|" then
            local dtype, ratio = line:match("^R|([^|]*)|(.*)$")

            snapshot.min_ratios[dtype] = tonumber(ratio)
        end
    end

    if not snapshot.pool then
        snapshot.pool = {}

        for dtype, groups in pairs(PickupPools.default_distribution_pool) do
            snapshot.pool[dtype] = {}

            for category, names in pairs(groups) do
                snapshot.pool[dtype][category] = {}

                for name, counts in pairs(names) do
                    snapshot.pool[dtype][category][name] = counts[challenge] or counts[#counts]
                end
            end
        end

        for dtype, ratio in pairs(PickupSettings.min_chest_spawner_ratios) do
            snapshot.min_ratios[dtype] = ratio
        end
    end

    return snapshot
end

local function same(list, expected)
    return list ~= nil and table.concat(list, ",") == table.concat(expected, ",")
end

-- 1. km_station (seed 374320701, challenge 2): every floor pickup explained. The mid-event items are
-- too few for the floor to decide their name order, so the equally good candidates disagree on the
-- mid-event chests (496 held a large clip in game) and those are not shown.
do
    local result, reason = ChestPrediction.solve(load_snapshot("km_station_374320701.txt", 374320701, 2))

    check(result ~= nil, "km_station solves (%s)", tostring(reason))

    if result then
        check(result.matched == 54, "km_station explains 54 floor pickups, got %d", result.matched)
        check(result.candidates > 1 and result.chests["496"] == nil, "ambiguous mid-event chests are not shown")
        check(same(result.chests["394"], { "small_platinum" }), "km_station chest 394 holds diamantine")
        check(same(result.chests["580"], { "large_clip", "syringe_ability_boost_pocketable" }), "km_station chest 580 lists slots in order")
        check(result.simulations < 5000, "km_station search stays small (%d simulations)", result.simulations)
    end
end

-- 2. hm_cartel (seed 611946183, challenge 2): predictions confirmed by opening the chests in game.
do
    local snapshot = load_snapshot("hm_cartel_611946183.txt", 611946183, 2)
    local result, reason = ChestPrediction.solve(snapshot)

    check(result ~= nil, "hm_cartel solves (%s)", tostring(reason))

    if result then
        check(result.matched == 65, "hm_cartel explains 65 floor pickups, got %d", result.matched)

        local confirmed = {
            ["266"] = { "small_grenade" },
            ["288"] = { "large_clip" },
            ["290"] = { "small_clip" },
            ["321"] = { "large_clip" },
            ["324"] = { "small_grenade" },
            ["295"] = { "small_platinum" },
        }

        for key, expected in pairs(confirmed) do
            check(same(result.chests[key], expected), "hm_cartel chest %s holds %s, got %s", key, table.concat(expected, ","),
                result.chests[key] and table.concat(result.chests[key], ",") or "nothing")
        end

        check(result.chests["309"] == nil, "a chest tied with another spawner is not shown")
        check(result.chests["320"] == nil and result.chests["265"] == nil and result.chests["268"] == nil,
            "chests without a reservation show nothing")
    end

    -- A floor pickup the replay cannot explain makes the whole prediction unconfirmed.
    local wrong = load_snapshot("hm_cartel_611946183.txt", 611946183, 2)

    for _, item in ipairs(wrong.floor) do
        if item.name == "small_metal" then
            item.name = "small_platinum"

            break
        end
    end

    check(ChestPrediction.solve(wrong) == nil, "an unexplained floor pickup blocks the prediction")

    local wrong_seed = load_snapshot("hm_cartel_611946183.txt", 611946184, 2)

    check(ChestPrediction.solve(wrong_seed) == nil, "a wrong seed finds no consistent replay")

    -- Too few floor pickups left to confirm anything (a late join after most were picked up).
    local sparse = load_snapshot("hm_cartel_611946183.txt", 611946183, 2)

    for i = #sparse.floor, 6, -1 do
        sparse.floor[i] = nil
    end

    check(ChestPrediction.solve(sparse) == nil, "five floor pickups are too few to confirm a prediction")

    -- The solver yields between simulations so the game can spread it over frames.
    local yields = 0

    ChestPrediction.solve(snapshot, function()
        yields = yields + 1
    end)

    check(yields > 100, "the solver yields regularly (%d yields)", yields)
end

print(string.format("%d checks, %d failures", checks, failures))

if failures > 0 then
    os.exit(1)
end
