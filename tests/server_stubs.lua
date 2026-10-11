local realTime = os.time
os.time = function() return TestNow end
function vector3(x, y, z) return { x = x, y = y, z = z } end
function vector4(x, y, z, w) return { x = x, y = y, z = z, w = w } end
function Clone(value)
    if type(value) ~= 'table' then return value end
    local copy = {}
    for k, v in pairs(value) do copy[k] = Clone(v) end
    return copy
end
function Check(value, message)
    Assertions = Assertions + 1
    assert(value, message or ('assertion ' .. Assertions))
end
function Eq(actual, expected, message)
    Check(actual == expected, (message or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end
Assertions = 0
function Player(id) return { state = { inv_busy = BusyInventory } } end
function GetPlayers()
    local ids = {}
    for id, player in pairs(Players) do if player.online then ids[#ids + 1] = tostring(id) end end
    return ids
end
function GetPlayerPed(id) return Players[id] and Players[id].online and id or 0 end
function GetEntityCoords(id) return Players[id] and Players[id].coords end
function GetPlayerRoutingBucket(id) return Players[id] and Players[id].bucket or 0 end
function TriggerClientEvent(name, id, ...) Notifications[#Notifications + 1] = { name = name, source = id, args = {...} } end
function RegisterNetEvent(name, callback) NetEvents[name] = callback end
function AddEventHandler(name, callback) Handlers[name] = callback end
function RegisterCommand(name, callback) Commands[name] = callback end
function SetTimeout(delay, callback) Timers[#Timers + 1] = { due = TestNow + delay / 1000, callback = callback } end
function CreateThread(callback)
    local thread = coroutine.create(callback)
    Threads[#Threads + 1] = thread
    if AutoRunThreads then local ok, err = coroutine.resume(thread); assert(ok, err) end
end
function Wait(ms) coroutine.yield(ms) end

local function normalize(sql) return sql:gsub('%s+', ' ') end
local function selectQuery(sql, values)
    sql, values = normalize(sql), values or {}
    if QueryHook then QueryHook(sql, values) end
    if sql:find('FROM encontros_reward_claims', 1, true) then
        local rows = {}
        for _, claim in pairs(DB.claims) do
            local event = DB.events[claim.event_id]
            local hasNpc = event and (event.npc_x ~= nil or event.npc_y ~= nil or event.npc_z ~= nil)
            if (not sql:find('policy_version <', 1, true) or (claim.policy_version < values[1] and claim.claimed == 0))
                and (not sql:find('WHERE citizenid =', 1, true) or claim.citizenid == values[1])
                and (not sql:find('WHERE c.citizenid =', 1, true) or claim.citizenid == values[1])
                and (not sql:find('c.event_id = ?', 1, true) or claim.event_id == values[2])
                and (not sql:find('e.npc_x IS NULL', 1, true) or not hasNpc)
                and (not sql:find('c.claimed = 0', 1, true) or (claim.claimed == 0 and claim.status == 'pending' and claim.expires_at and claim.expires_at > values[2])) then
                local row = Clone(claim)
                if sql:find('LEFT JOIN encontros e', 1, true) and event then
                    row.npc_x, row.npc_y, row.npc_z, row.npc_w = event.npc_x, event.npc_y, event.npc_z, event.npc_w
                    row.routing_bucket, row.finished_at, row.event_status = event.routing_bucket, event.finished_at, event.status
                end
                rows[#rows + 1] = row
            end
        end
        table.sort(rows, function(a, b) return (a.expires_at or 1e20) < (b.expires_at or 1e20) end)
        return rows
    elseif sql:find('SELECT citizenid, seconds FROM encontros_attendance', 1, true) then
        local rows = {}
        for citizenid, seconds in pairs(DB.attendance[values[1]] or {}) do rows[#rows + 1] = { citizenid = citizenid, seconds = seconds } end
        return rows
    elseif sql:find('SELECT * FROM encontros', 1, true) then
        local rows = {}
        for _, event in pairs(DB.events) do
            if (not sql:find('policy_version <', 1, true) or event.policy_version < values[1])
                and (not sql:find("status IN ('active', 'scheduled')", 1, true) or event.status == 'active' or event.status == 'scheduled') then
                rows[#rows + 1] = Clone(event)
            end
        end
        return rows
    end
    -- Schema queries are intentionally not executed by this offline adapter.
    if sql:find('CREATE TABLE', 1, true) or sql:find('ALTER TABLE', 1, true) then return {} end
    error('Unhandled query: ' .. sql)
end
local function singleQuery(sql, values)
    sql = normalize(sql)
    if SingleHook then local hook = SingleHook; SingleHook = nil; hook() end
    if sql:find('encontros_reward_claims', 1, true) then
        local claim = DB.claims[values[1]]
        return claim and claim.citizenid == values[2] and Clone(claim) or nil
    elseif sql:find('recurrence_parent_id', 1, true) then
        for _, event in pairs(DB.events) do if event.recurrence_parent_id == values[1] then return Clone(event) end end
        return nil
    end
    return Clone(DB.events[values[1]])
end
local function update(sql, v)
    sql = normalize(sql)
    if sql:find("SET status = 'active'", 1, true) then
        local row = DB.events[v[3]]
        if not row or row.status ~= 'scheduled' then return 0 end
        row.status, row.started_at, row.policy_version = 'active', v[1], v[2]
        if UnknownStart then UnknownStart = false; error('simulated lost start acknowledgement') end
        return 1
    elseif sql:find("SET status = 'finished'", 1, true) then
        local row = DB.events[v[3]]
        if not row or row.status ~= 'active' then return 0 end
        row.status, row.finished_at, row.finish_token = 'finished', v[1], v[2]
        return 1
    elseif sql:find('SET status = ?, status_reason = ?, finished_at', 1, true) then
        local row = DB.events[v[5]]
        if not row or (row.status ~= 'active' and row.status ~= 'scheduled') then return 0 end
        row.status, row.status_reason, row.finished_at, row.finish_token = v[1], v[2], v[3], v[4]
        return 1
    elseif sql:find('UPDATE encontros_reward_claims SET reward_item', 1, true) then
        local row = DB.claims[v[5]]
        if row.claimed ~= 0 or row.policy_version >= v[6] then return 0 end
        row.reward_item, row.reward_amount, row.reward_custom = v[1], 1, nil
        row.policy_version, row.status, row.drawn_at, row.expires_at = v[2], 'pending', v[3], v[4]
        return 1
    elseif sql:find("SET status = 'suspended'", 1, true) then
        local row = DB.claims[v[2]]
        if row.claimed ~= 0 or row.policy_version >= v[3] then return 0 end
        row.status, row.policy_version = 'suspended', v[1]
        return 1
    elseif sql:find('SET status = ?, status_reason = ?, reward_enabled', 1, true) then
        local row = DB.events[v[7]]
        if row.policy_version >= v[8] then return 0 end
        row.status, row.status_reason, row.reward_enabled, row.policy_version = v[1], v[2], v[3], v[4]
        row.reward_item, row.reward_custom = '', nil
        if v[5] == 'cancelled' or v[5] == 'blocked' then row.finished_at = v[6] end
        return 1
    elseif sql:find('SET policy_version = ?', 1, true) then
        local row = DB.events[v[2]]
        if row.policy_version >= v[3] then return 0 end
        row.policy_version = v[1]
        return 1
    end
    error('Unhandled update: ' .. sql)
end
local function insert(sql, v)
    sql = normalize(sql)
    if sql:find('INSERT INTO encontros_attendance', 1, true) then
        DB.attendance[v[1]] = DB.attendance[v[1]] or {}
        DB.attendance[v[1]][v[2]] = math.max(DB.attendance[v[1]][v[2]] or 0, v[3])
        return 1
    elseif sql:find('INSERT IGNORE INTO encontros_reward_claims', 1, true) then
        local event = DB.events[v[6]]
        if not event or event.finish_token ~= v[7] then return 0 end
        for _, row in pairs(DB.claims) do if row.event_id == event.id and row.citizenid == v[1] then return 0 end end
        DB.claimSequence = DB.claimSequence + 1
        local id = DB.claimSequence
        DB.claims[id] = { id = id, event_id = event.id, citizenid = v[1], event_title = event.title,
            reward_table = event.reward_table, reward_item = v[2], reward_amount = 1, policy_version = v[3],
            status = 'pending', claimed = 0, drawn_at = v[4], expires_at = v[5] }
        return id
    elseif sql:find('INSERT IGNORE INTO encontros', 1, true) then
        local random = sql:find('SELECT title, description, %?', 1, false) ~= nil
        local parentId, finishToken = random and v[14] or v[3], random and v[15] or v[4]
        local parent = DB.events[parentId]
        if not parent or parent.finish_token ~= finishToken then return 0 end
        for _, row in pairs(DB.events) do if row.recurrence_parent_id == parent.id then return 0 end end
        local row = Clone(parent)
        DB.eventSequence = DB.eventSequence + 1
        row.id, row.start_time, row.policy_version, row.recurrence_parent_id = DB.eventSequence, random and v[7] or v[1], random and v[8] or v[2], parent.id
        row.status, row.started_at, row.finished_at, row.finish_token = 'scheduled', nil, nil, nil
        if random then
            row.location, row.coords_x, row.coords_y, row.coords_z = v[1], v[2], v[3], v[4]
            row.radius, row.height_tolerance, row.random_location, row.location_key = v[5], v[6], 1, v[13]
            row.npc_x, row.npc_y, row.npc_z, row.npc_w = v[9], v[10], v[11], v[12]
        end
        DB.events[row.id] = row
        return row.id
    elseif sql:find('INSERT INTO encontros', 1, true) then
        DB.eventSequence = DB.eventSequence + 1
        local id = DB.eventSequence
        DB.events[id] = { id = id, title = v[1], description = v[2], location = v[3], coords_x = v[4], coords_y = v[5], coords_z = v[6],
            radius = v[7], height_tolerance = v[8], event_type = v[9], area_message = v[10], blip_sprite = v[11], reward_enabled = v[12],
            reward_table = v[13], start_time = v[14], duration = v[15], recurring = v[16], status = 'scheduled', policy_version = v[17], routing_bucket = v[18],
            random_location = v[19], location_key = v[20], npc_x = v[21], npc_y = v[22], npc_z = v[23], npc_w = v[24] or 0 }
        return id
    end
    error('Unhandled insert: ' .. sql)
end
function Reset(keepDatabase)
    TestNow = 1000
    if not keepDatabase then DB = { events = {}, attendance = {}, claims = {}, eventSequence = 0, claimSequence = 0 } end
    Players = { [1] = { online = true, citizenid = 'test_character_a', coords = vector3(0, 0, 0), bucket = 0, admin = true },
        [2] = { online = true, citizenid = 'test_character_b', coords = vector3(100, 0, 0), bucket = 0, admin = false } }
    Notifications, Callbacks, NetEvents, Handlers, Commands, Timers, Threads = {}, {}, {}, {}, {}, {}, {}
    AutoRunThreads = false
    Config = { AdminGroups = {'admin'}, AdminCommand = 'encontrosadmin', EventCommand = 'encontro', EventAreaRadius = 50,
        EventHeightTolerance = 15, Blips = { encontro = { sprite = 280, radius = 50 }, marcador = { sprite = 280, radius = 0, requiresNpc = false } },
        EventRewardNpc = { afterFinishSeconds = 600 }, RewardClaimNpc = { coords = vector4(200, 0, 0, 0), routingBucket = 0 },
        Locations = {
            { key = 'praca', label = 'Praca', coords = vector3(0, 0, 0), npc = vector4(10, 0, 0, 90), radius = 50, heightTolerance = 15 },
            { key = 'pier', label = 'Pier', coords = vector3(300, 0, 0), npc = vector4(310, 0, 0, 180), radius = 70, heightTolerance = 20 },
        } }
    local core = { Shared = { Items = {} }, Functions = {} }
    for _, key in ipairs({'pecas_carro', 'pecas_moto'}) do
        for _, reward in ipairs(EncounterRewardPolicy.catalog(key).rewards) do core.Shared.Items[reward.item] = { name = reward.item, label = reward.item, image = reward.item .. '.png' } end
    end
    TestCore = core
    core.Functions.HasPermission = function(id) return Players[id] and Players[id].admin end
    core.Functions.GetPlayer = function(id) return Players[id] and Players[id].online and { PlayerData = { citizenid = Players[id].citizenid } } or nil end
    core.Functions.CreateCallback = function(name, callback) Callbacks[name] = callback end
    BridgeCalls, Reconciliations, InventoryCount = 0, 0, 0
    BridgeFailure, BusyInventory, UnknownStart, FailTransaction, UnknownCommit, SingleHook, TransactionHook = nil, false, false, false, false, nil, nil
    QueryHook, TransactionDelay, BridgeBeforeValidate = nil, false, nil
    exports = { ['qb-core'] = { GetCoreObject = function() return core end }, ['qb-inventory'] = {
        GetPendingExternalItemMutations = function() return {} end,
        ReconcileEncounterReward = function() Reconciliations = Reconciliations + 1; return { ok = false, reason = 'operation_not_pending' } end,
        CommitEncounterReward = function(_, id, claimId, options)
            BridgeCalls = BridgeCalls + 1
            if BridgeBeforeValidate then BridgeBeforeValidate() end
            if not options.validate() then return { ok = false, reason = 'actor_invalid' } end
            if BridgeFailure then return { ok = false, reason = BridgeFailure } end
            local claim = DB.claims[claimId]
            Check(claim.reward_amount == 1 and claim.citizenid == options.expectedCitizenId and claim.reward_item == options.itemName, 'narrow bridge arguments')
            claim.claimed, claim.status = 1, 'claimed'
            InventoryCount = InventoryCount + 1
            return { ok = true, slot = 1 }
        end,
    } }
    MySQL = { ready = function(callback) BootCallback = callback end,
        query = { await = selectQuery }, single = { await = singleQuery }, update = { await = update }, insert = { await = insert },
        transaction = { await = function(queries)
            if TransactionDelay then coroutine.yield('database wait') end
            if TransactionHook then local hook = TransactionHook; TransactionHook = nil; hook() end
            if FailTransaction then FailTransaction = false; return false end
            for _, statement in ipairs(queries) do
                if normalize(statement.query):find('UPDATE ', 1, true) == 1 then update(statement.query, statement.values)
                else insert(statement.query, statement.values) end
            end
            if UnknownCommit then UnknownCommit = false; return false end
            return true
        end },
    }
end
function Boot()
    BootMain()
    BootCallback()
    for _, thread in ipairs(Threads) do local ok, err = coroutine.resume(thread); assert(ok, err) end
    AutoRunThreads = true
end
function Invoke(name, id, ...)
    local result
    Callbacks['encontros:server:' .. name](id or 1, function(...) result = {...} end, ...)
    return table.unpack(result)
end
function NewEvent(overrides)
    local data = { title = 'Encontro teste', location = 'Local teste', coords = {x=0,y=0,z=0},
        npc_coords = {x=10,y=0,z=0,w=90}, reward_enabled = true, reward_table = 'pecas_carro', duration = 1, status = 'active', event_type = 'encontro' }
    for key, value in pairs(overrides or {}) do data[key] = value end
    local ok, reason = Invoke('create', 1, data)
    return ok, DB.eventSequence, reason
end
function Sample(now)
    TestNow = now
    local ok, err = coroutine.resume(Threads[1])
    assert(ok, err)
end
function RunTimers(now)
    TestNow = now
    local due = {}
    for i = #Timers, 1, -1 do if Timers[i].due <= now then due[#due + 1] = table.remove(Timers, i) end end
    for _, timer in ipairs(due) do timer.callback() end
end
function Count(rows) local n = 0; for _ in pairs(rows) do n = n + 1 end; return n end
function LegacyEvent(id, status, category, reward)
    DB.eventSequence = math.max(DB.eventSequence, id)
    DB.events[id] = { id=id, title='Legado', location='Local', coords_x=0,coords_y=0,coords_z=0,radius=50,height_tolerance=15,
        event_type='encontro', blip_sprite=280, reward_enabled=reward == false and 0 or 1,reward_table=category,policy_version=1,
        start_time=2000,duration=10,recurring=0,status=status,routing_bucket=0 }
    return DB.events[id]
end
function LegacyClaim(id, category, claimed)
    DB.claimSequence = math.max(DB.claimSequence, id)
    DB.claims[id] = { id=id,event_id=id,citizenid='test_character_a',event_title='Legado',reward_table=category,
        reward_item=claimed and 'legacy_material' or nil,reward_amount=claimed and 9 or nil,
        status='pending',policy_version=1,claimed=claimed and 1 or 0 }
    return DB.claims[id]
end
