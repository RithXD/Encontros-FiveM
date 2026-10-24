local QBCore = exports['qb-core']:GetCoreObject()
local Policy = EncounterRewardPolicy
local ActiveEvents, Attendance, EventTimers, EventLocks, ClaimLocks, Sessions, VehicleArrivals = {}, {}, {}, {}, {}, {}, {}
local PendingClosures = {}
local Ready, SessionSequence, TokenSequence = false, 0, 0
local scheduleEventStart, scheduleEventFinish, finishEvent

math.randomseed(os.time())

local function truthy(value) return value == true or value == 1 or value == '1' end
local function finite(value)
    local number = tonumber(value)
    return number and number == number and number ~= math.huge and number ~= -math.huge and number or nil
end
local function positiveId(value)
    local number = finite(value)
    return number and number > 0 and number == math.floor(number) and number or nil
end
local function clampNumber(value, fallback, minimum, maximum)
    return math.max(minimum, math.min(maximum, finite(value) or fallback))
end
local function isAdmin(playerId)
    for _, group in ipairs(Config.AdminGroups) do
        if QBCore.Functions.HasPermission(playerId, group) then return true end
    end
    return false
end
local function getCitizenId(playerId)
    local player = QBCore.Functions.GetPlayer(playerId)
    return player and player.PlayerData and player.PlayerData.citizenid or nil
end
local function announceAdmins(message)
    for _, playerId in ipairs(GetPlayers()) do
        if isAdmin(tonumber(playerId)) then TriggerClientEvent('QBCore:Notify', tonumber(playerId), message, 'error', 10000) end
    end
end
local function getEventType(value)
    local key = tostring(value or '')
    return Config.Blips[key] and key or (Config.Blips.encontro and 'encontro' or 'social')
end
local function npcCoords(x, y, z, w)
    x, y, z, w = finite(x), finite(y), finite(z), finite(w)
    if not x or not y or not z or not w or math.abs(x) > 20000 or math.abs(y) > 20000 or z < -1000 or z > 10000 then return nil end
    return { x = x, y = y, z = z, w = w % 360 }
end
local function sanitizeKey(value, fallback)
    local key = tostring(value or ''):sub(1, 100)
    return key ~= '' and key or fallback
end
local function coordComponent(coords, key, index)
    if not coords then return nil end
    local value = coords[key]
    if value == nil and index then value = coords[index] end
    return finite(value)
end
<<<<<<< HEAD
local function clampNumber(value, fallback, minimum, maximum)
    return math.max(minimum, math.min(maximum, finite(value) or fallback))
end
local function isAdmin(playerId)
    for _, group in ipairs(Config.AdminGroups) do
        if QBCore.Functions.HasPermission(playerId, group) then return true end
    end
    return false
end
local function getCitizenId(playerId)
    local player = QBCore.Functions.GetPlayer(playerId)
    return player and player.PlayerData and player.PlayerData.citizenid or nil
end
local function announceAdmins(message)
    for _, playerId in ipairs(GetPlayers()) do
        if isAdmin(tonumber(playerId)) then TriggerClientEvent('QBCore:Notify', tonumber(playerId), message, 'error', 10000) end
    end
end
local function getEventType(value)
    local key = tostring(value or '')
    return Config.Blips[key] and key or (Config.Blips.encontro and 'encontro' or 'social')
end
local function npcCoords(x, y, z, w)
    x, y, z, w = finite(x), finite(y), finite(z), finite(w)
    if not x or not y or not z or not w or math.abs(x) > 20000 or math.abs(y) > 20000 or z < -1000 or z > 10000 then return nil end
    return { x = x, y = y, z = z, w = w % 360 }
end
local function sanitizeKey(value, fallback)
    local key = tostring(value or ''):sub(1, 100)
    return key ~= '' and key or fallback
end
local function coordComponent(coords, key, index)
    if not coords then return nil end
    local value = coords[key]
    if value == nil and index then value = coords[index] end
    return finite(value)
end
=======
>>>>>>> e0632c7a61e4d7d804debcb67e0c49d9ead74b61
local function configuredLocations()
    local locations = {}
    for index, entry in ipairs(Config.Locations or {}) do
        local coords = entry and entry.coords
        local x, y, z = coordComponent(coords, 'x', 1), coordComponent(coords, 'y', 2), coordComponent(coords, 'z', 3)
        local npcSource = entry and (entry.npc or entry.npc_coords or entry.rewardNpc)
        local npc = npcSource and npcCoords(
            coordComponent(npcSource, 'x', 1),
            coordComponent(npcSource, 'y', 2),
            coordComponent(npcSource, 'z', 3),
            coordComponent(npcSource, 'w', 4) or coordComponent(npcSource, 'heading')
        )
<<<<<<< HEAD
        if x and y and z and npc then
            local key = sanitizeKey(entry.key, tostring(index))
            locations[#locations + 1] = {
                key = key,
                label = tostring(entry.label or key):sub(1, 100),
                x = x, y = y, z = z,
                radius = finite(entry.radius),
                height_tolerance = finite(entry.heightTolerance or entry.height_tolerance),
                npc = npc,
            }
        end
    end
    return locations
end
local function locationKeyForEvent(event)
    if event and event.location_key and tostring(event.location_key) ~= '' then return tostring(event.location_key) end
    if not event then return nil end
    for _, location in ipairs(configuredLocations()) do
        if location.label == event.location
            and location.x == tonumber(event.coords_x) and location.y == tonumber(event.coords_y) and location.z == tonumber(event.coords_z) then
            return location.key
        end
    end
    return nil
end
local function randomLocation(excludedKey)
    local locations, pool = configuredLocations(), {}
    if #locations == 0 then return nil end
    for _, location in ipairs(locations) do
        if #locations == 1 or location.key ~= excludedKey then pool[#pool + 1] = location end
    end
    if #pool == 0 then pool = locations end
    return pool[math.random(1, #pool)]
end
local function blipConfig(eventType) return Config.Blips[eventType] or Config.Blips.encontro or Config.Blips.social end
local function blipSprite(value, eventType)
    return math.floor(clampNumber(value, blipConfig(eventType).sprite, Config.BlipSpriteIdMin or 1, Config.BlipSpriteIdMax or 1000))
end
local function eventHasReward(event) return event.event_type ~= 'marcador' and truthy(event.reward_enabled) end
local function endsAt(event) return tonumber(event.start_time) + tonumber(event.duration) * 60 end
local function eventNpcCoords(event)
    return event and npcCoords(event.npc_x, event.npc_y, event.npc_z, event.npc_w) or nil
end
local function hasNpcPosition(event)
    return event and (event.npc_x ~= nil or event.npc_y ~= nil or event.npc_z ~= nil) or false
end
local function publicEvent(event)
    return {
        id = event.id, title = event.title, description = event.description or '', location = event.location,
        event_type = event.event_type, area_message = event.area_message or '', blip_sprite = blipSprite(event.blip_sprite, event.event_type),
        coords = { x = event.coords_x, y = event.coords_y, z = event.coords_z },
        npc_coords = eventNpcCoords(event),
        reward_enabled = eventHasReward(event) and 1 or 0, reward_table = event.reward_table,
        radius = event.radius, height_tolerance = event.height_tolerance, start_time = event.start_time,
        started_at = event.started_at, finished_at = event.finished_at, duration = event.duration,
        status = event.status, status_reason = event.status_reason, recurring = truthy(event.recurring) and 1 or 0,
        random_location = truthy(event.random_location) and 1 or 0, location_key = event.location_key,
        routing_bucket = event.routing_bucket, policy_version = event.policy_version,
    }
end
local function getEvent(id)
    return MySQL.single.await('SELECT * FROM encontros WHERE id = ? LIMIT 1', { id })
end
local function token(kind, id)
    TokenSequence = TokenSequence + 1
    return ('%s:%s:%s:%s:%s'):format(kind, id, os.time(), TokenSequence, math.random(100000, 999999))
end
local function transaction(queries)
    local ok, committed = pcall(MySQL.transaction.await, queries)
    return ok and committed == true
end
local function lockedEvent(id, action)
    -- Timers, the sampler and administrative actions use the same lock. SQL state
    -- and a unique closure token additionally guard resource restarts/retries.
    while EventLocks[id] do Wait(25) end
    EventLocks[id] = true
    local ok, result, reason = pcall(action)
    EventLocks[id] = nil
    if not ok then
        print('[Encontrinhos_Pog] Operacao de encontro falhou; dados preservados para nova tentativa.')
        return false, 'Falha ao persistir o encontro.'
    end
    return result, reason
end
local function insideEvent(event, playerId)
    if GetPlayerRoutingBucket(playerId) ~= (tonumber(event.routing_bucket) or 0) then return false end
    local ped = GetPlayerPed(playerId)
    if not ped or ped == 0 then return false end
    local coords = GetEntityCoords(ped)
    if not coords then return false end
    local dx, dy = coords.x - event.coords_x, coords.y - event.coords_y
    return dx * dx + dy * dy <= (event.radius or Config.EventAreaRadius) ^ 2
        and math.abs(coords.z - event.coords_z) <= (event.height_tolerance or Config.EventHeightTolerance)
end
local function eventNpcLifetime()
    return math.max(0, math.floor(finite(Config.EventRewardNpc and Config.EventRewardNpc.afterFinishSeconds) or 600))
end
local function fixedNpcCoords()
    local config = Config.RewardClaimNpc
    local coords = config and config.coords
    return coords and npcCoords(coords.x, coords.y, coords.z, coords.w or 0) or nil
end
local function pickupLocation(event, now)
    local finishedAt = event and finite(event.finished_at)
    local status = event and (event.event_status or event.status)
    if status == 'finished' and finishedAt and now < finishedAt + eventNpcLifetime() and hasNpcPosition(event) then
        -- An incomplete local pose fails closed during its short pickup window.
        -- Historical events without a closing time use the permanent mechanic.
        return 'event', eventNpcCoords(event), tonumber(event.routing_bucket) or 0
    end
    return 'fixed', fixedNpcCoords(), Config.RewardClaimNpc and Config.RewardClaimNpc.routingBucket or 0
end
local function insideClaimNpc(playerId, event)
    local _, npc, bucket = pickupLocation(event, os.time())
    if not npc or GetPlayerRoutingBucket(playerId) ~= bucket then return false end
    local ped = GetPlayerPed(playerId)
    if not ped or ped == 0 then return false end
    local coords = GetEntityCoords(ped)
    if not coords then return false end
    return (coords.x - npc.x) ^ 2 + (coords.y - npc.y) ^ 2 + (coords.z - npc.z) ^ 2 <= 9
end
local function presentPlayers(event)
    local present = {}
    for _, value in ipairs(GetPlayers()) do
        local playerId = tonumber(value)
        local citizenid = getCitizenId(playerId)
        if citizenid and insideEvent(event, playerId) then
            if not Sessions[playerId] or Sessions[playerId].citizenid ~= citizenid then
                SessionSequence = SessionSequence + 1
                Sessions[playerId] = { citizenid = citizenid, id = SessionSequence }
            end
            present[citizenid] = { source = playerId, session = Sessions[playerId].id }
        end
    end
    return present
end
local function attendanceQueries(id, state, now)
    local queries = {}
    for citizenid, record in pairs(state) do
        queries[#queries + 1] = { query = [[INSERT INTO encontros_attendance (event_id, citizenid, seconds, updated_at)
            VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE seconds = GREATEST(seconds, VALUES(seconds)), updated_at = VALUES(updated_at)]],
            values = { id, citizenid, record.seconds, now } }
    end
    return queries
end
local function loadAttendance(event)
    local state = {}
    for _, row in ipairs(MySQL.query.await('SELECT citizenid, seconds FROM encontros_attendance WHERE event_id = ?', { event.id }) or {}) do
        state[row.citizenid] = { seconds = tonumber(row.seconds) or 0 }
    end
    Attendance[event.id] = state -- never restore an observation across resource downtime
    ActiveEvents[event.id] = event
end
local function observe(event, now)
    local present = presentPlayers(event)
    return EncounterAttendance.observe(Attendance[event.id] or {}, present, now, event.started_at, endsAt(event)), present
end
local function sampleEvent(event)
    return lockedEvent(event.id, function()
        if not ActiveEvents[event.id] or PendingClosures[event.id] or os.time() >= endsAt(event) then return true end
        local now = os.time()
        local state = observe(event, now)
        local queries = attendanceQueries(event.id, state, now)
        -- The closing timer may need this already observed time while waiting
        -- for the SQL lock; publishing the observation is synchronous.
        Attendance[event.id] = state
        if #queries > 0 and not transaction(queries) then
            -- Keep time actually observed even if SQL acknowledgement is lost.
            -- Retry absolute totals (GREATEST), never additive deltas, so an
            -- uncertain commit neither duplicates nor discards earned time.
            for _, record in pairs(state) do record.observed_at = nil end
            Attendance[event.id] = state
            return false
        end
        for _, record in pairs(state) do
            local session = record.source and Sessions[record.source]
            if not session or session.id ~= record.session then record.observed_at = nil end
        end
        Attendance[event.id] = state
        return true
    end)
end
local function clearTimers(id) EventTimers[tonumber(id)] = nil end
local function recurrenceQuery(event, closedAt, finishToken)
    if not truthy(event.recurring) then return nil end
    local nextStart = event.start_time + 86400
    while nextStart <= closedAt do nextStart = nextStart + 86400 end
    if truthy(event.random_location) then
        local selected = randomLocation(locationKeyForEvent(event))
        if selected then
            return { query = [[INSERT IGNORE INTO encontros
                (title, description, location, coords_x, coords_y, coords_z, radius, height_tolerance, event_type,
                 area_message, blip_sprite, reward_enabled, reward_table, start_time, duration, recurring, status,
                 policy_version, routing_bucket, recurrence_parent_id, npc_x, npc_y, npc_z, npc_w, random_location, location_key)
                SELECT title, description, ?, ?, ?, ?, ?, ?, event_type, area_message, blip_sprite, reward_enabled,
                 reward_table, ?, duration, 1, 'scheduled', ?, routing_bucket, id, ?, ?, ?, ?, 1, ?
                FROM encontros WHERE id = ? AND finish_token = ?]], values = {
                    selected.label, selected.x, selected.y, selected.z,
                    clampNumber(selected.radius, event.radius or Config.EventAreaRadius, 1, 1000),
                    clampNumber(selected.height_tolerance, event.height_tolerance or Config.EventHeightTolerance, 1, 500),
                    nextStart, Policy.VERSION, selected.npc.x, selected.npc.y, selected.npc.z, selected.npc.w,
                    selected.key, event.id, finishToken,
                } }
        end
    end
    return { query = [[INSERT IGNORE INTO encontros
        (title, description, location, coords_x, coords_y, coords_z, radius, height_tolerance, event_type,
         area_message, blip_sprite, reward_enabled, reward_table, start_time, duration, recurring, status,
         policy_version, routing_bucket, recurrence_parent_id, npc_x, npc_y, npc_z, npc_w, random_location, location_key)
        SELECT title, description, location, coords_x, coords_y, coords_z, radius, height_tolerance, event_type,
         area_message, blip_sprite, reward_enabled, reward_table, ?, duration, 1, 'scheduled', ?, routing_bucket, id, npc_x, npc_y, npc_z, npc_w, random_location, location_key
        FROM encontros WHERE id = ? AND finish_token = ?]], values = { nextStart, Policy.VERSION, event.id, finishToken } }
end
local function afterClosure(event, status)
    local nextEvent = MySQL.single.await('SELECT * FROM encontros WHERE recurrence_parent_id = ? LIMIT 1', { event.id })
    ActiveEvents[event.id], Attendance[event.id] = nil, nil
    PendingClosures[event.id] = nil
    clearTimers(event.id)
    event.status = status
    if status == 'finished' then TriggerClientEvent('encontros:client:finished', -1, publicEvent(event)) end
    TriggerClientEvent('encontros:client:removed', -1, event.id)
    TriggerClientEvent('encontros:client:refreshClaimNpcs', -1)
    if nextEvent and nextEvent.status == 'scheduled' then scheduleEventStart(nextEvent) end
end
local function closeWithoutAward(event, status, reason, recur)
    local now, finishToken = os.time(), token(status, event.id)
    local queries = {{ query = [[UPDATE encontros SET status = ?, status_reason = ?, finished_at = ?, finish_token = ?
        WHERE id = ? AND status IN ('active', 'scheduled')]], values = { status, reason, now, finishToken, event.id } }}
    local recurrence = recur and recurrenceQuery(event, now, finishToken)
    if recurrence then queries[#queries + 1] = recurrence end
    transaction(queries)
    local persisted = getEvent(event.id)
    if not persisted then return false end
    if persisted.finish_token ~= finishToken then
        if persisted.status == 'active' or persisted.status == 'scheduled' then return false end
        afterClosure(persisted, persisted.status)
        return true -- a previous terminal transaction committed without its acknowledgement
    end
    afterClosure(persisted, status)
    if status == 'interrupted' or status == 'blocked' then announceAdmins(('Encontro "%s": %s'):format(event.title, reason)) end
    return true
end

local function startEvent(candidate)
    return lockedEvent(candidate.id, function()
        local event = getEvent(candidate.id)
        if not event then return false end
        if event.status == 'active' and not ActiveEvents[event.id] then
            if not event.started_at or os.time() >= endsAt(event) then
                return closeWithoutAward(event, 'interrupted', 'Ativacao sem confirmacao antes do encerramento. Recrie o evento.', true)
            end
            loadAttendance(event)
            if os.time() >= endsAt(event) then
                return closeWithoutAward(event, 'interrupted', 'Ativacao sem confirmacao antes do encerramento. Recrie o evento.', true)
            end
            Attendance[event.id] = observe(event, os.time())
            scheduleEventFinish(event)
            TriggerClientEvent('encontros:client:started', -1, publicEvent(event))
            TriggerClientEvent('encontros:client:refreshClaimNpcs', -1)
            return true
        end
        if event.status ~= 'scheduled' then return false end
        local now = os.time()
        if now >= endsAt(event) then
            return closeWithoutAward(event, 'interrupted', 'O horario do encontro passou durante a indisponibilidade. Recrie o evento.', true)
        end
        if eventHasReward(event) then
            local valid = Policy.validateCatalog(QBCore.Shared.Items, event.reward_table)
            if not valid then return closeWithoutAward(event, 'blocked', 'Categoria ou catalogo de pecas indisponivel. Recrie com carro ou moto.', false) end
        end
        local writeOk, changed = pcall(MySQL.update.await, [[UPDATE encontros SET status = 'active', started_at = ?, policy_version = ?
            WHERE id = ? AND status = 'scheduled']], { now, Policy.VERSION, event.id })
        if not writeOk or changed ~= 1 then
            local persisted = getEvent(event.id)
            if not persisted or persisted.status ~= 'active' or not persisted.started_at then return false end
            event = persisted
        else event.status, event.started_at = 'active', now end
        if os.time() >= endsAt(event) then
            return closeWithoutAward(event, 'interrupted', 'Banco indisponivel durante a ativacao. Recrie o evento.', true)
        end
        Attendance[event.id], ActiveEvents[event.id] = {}, event
        Attendance[event.id] = observe(event, os.time())
        TriggerClientEvent('encontros:client:started', -1, publicEvent(event))
        TriggerClientEvent('encontros:client:refreshClaimNpcs', -1)
        scheduleEventFinish(event)
        return true
    end)
end

local function announceRewards(event, rewards)
    for _, reward in ipairs(rewards) do
        if getCitizenId(reward.source) == reward.citizenid then
            local item = QBCore.Shared.Items[reward.item]
            local pickup = eventNpcCoords(event)
                and 'Retire no NPC do encontro nos primeiros 10 minutos; depois, no NPC fixo de premios. O prazo total e de 24 horas a partir do sorteio.'
                or 'Retire no NPC fixo de premios em ate 24 horas a partir do sorteio.'
            TriggerClientEvent('QBCore:Notify', reward.source,
                ('Voce ganhou 1x %s no encontro %s! %s'):format(item and item.label or reward.item, event.title, pickup), 'success', 12000)
        end
    end
end

local function prepareClosure(event)
    local now = os.time()
    if not event.started_at or now - endsAt(event) > Policy.SAMPLE_SECONDS + 2 then
        return { terminal = 'interrupted', reason = 'Presenca no encerramento nao pode ser comprovada apos indisponibilidade. Recrie o evento.', recur = true }
    end
    local closedAt = math.min(now, endsAt(event))
    local state, present = observe(event, closedAt)
    local minimum, rewards = Policy.minimumSeconds(event.started_at, closedAt), {}
    if eventHasReward(event) then
        if not Policy.validateCatalog(QBCore.Shared.Items, event.reward_table) then
            return { terminal = 'blocked', reason = 'Catalogo de pecas indisponivel no encerramento. Recrie o evento.', recur = false }
        end
        for citizenid, session in pairs(present) do
            if state[citizenid] and state[citizenid].seconds >= minimum then
                local reward = Policy.draw(event.reward_table)
                rewards[#rewards + 1] = { citizenid = citizenid, source = session.source, item = reward.item }
            end
        end
    end
    return { closedAt = closedAt, state = state, rewards = rewards, finishToken = token('finish', event.id) }
end

finishEvent = function(candidate)
    local observedEvent = ActiveEvents[candidate.id]
    if not observedEvent then return false end
    -- Capture at the trigger, BEFORE even waiting for a sampler's SQL lock.
    -- Cooperative handlers cannot interleave until the first yield, so only
    -- one immutable snapshot/draw is constructed for this event.
    if not PendingClosures[candidate.id] then PendingClosures[candidate.id] = prepareClosure(observedEvent) end
    return lockedEvent(candidate.id, function()
        local event = ActiveEvents[candidate.id]
        if not event then return false end
        local closure = PendingClosures[event.id]
        if closure.terminal then
            return closeWithoutAward(event, closure.terminal, closure.reason, closure.recur)
        end
        local closedAt, state, rewards, finishToken = closure.closedAt, closure.state, closure.rewards, closure.finishToken
        local current = getEvent(candidate.id)
        if not current then return false end
        if current.status ~= 'active' then
            afterClosure(current, current.status)
            if current.status == 'finished' and current.finish_token == finishToken then announceRewards(current, rewards) end
            return true -- reconcile an earlier committed but unacknowledged close
        end
        local queries = {{ query = [[UPDATE encontros SET status = 'finished', finished_at = ?, finish_token = ?, status_reason = NULL
            WHERE id = ? AND status = 'active']], values = { closedAt, finishToken, event.id } }}
        for _, query in ipairs(attendanceQueries(event.id, state, closedAt)) do queries[#queries + 1] = query end
        for _, reward in ipairs(rewards) do
            queries[#queries + 1] = { query = [[INSERT IGNORE INTO encontros_reward_claims
                (event_id, citizenid, event_title, reward_table, reward_item, reward_amount, policy_version, status, drawn_at, expires_at)
                SELECT id, ?, title, reward_table, ?, 1, ?, 'pending', ?, ? FROM encontros WHERE id = ? AND finish_token = ?]],
                values = { reward.citizenid, reward.item, Policy.VERSION, closedAt, closedAt + Policy.CLAIM_TTL, event.id, finishToken } }
        end
        local recurrence = recurrenceQuery(event, closedAt, finishToken)
        if recurrence then queries[#queries + 1] = recurrence end
        transaction(queries)
        -- Read after an ambiguous transaction response; never re-draw a committed closure.
        local persisted = getEvent(event.id)
        if not persisted or persisted.finish_token ~= finishToken then return false end
        afterClosure(persisted, 'finished')
        announceRewards(persisted, rewards)
        return true
    end)
end

scheduleEventStart = function(event)
    if not event then return end
    local id, marker = tonumber(event.id), token('start', event.id)
    EventTimers[id] = { start = marker }
    SetTimeout(math.max(0, event.start_time - os.time()) * 1000, function()
        if not Ready or not EventTimers[id] or EventTimers[id].start ~= marker then return end
        if not startEvent(event) then
            local ok, current = pcall(getEvent, id)
            if not ok or (current and (current.status == 'scheduled' or (current.status == 'active' and not ActiveEvents[id]))) then
                SetTimeout(5000, function() scheduleEventStart(ok and current or event) end)
            end
        end
    end)
end
scheduleEventFinish = function(event)
    if not event then return end
    local id, marker = tonumber(event.id), token('finishTimer', event.id)
    EventTimers[id] = { finish = marker }
    SetTimeout(math.max(0, endsAt(event) - os.time()) * 1000, function()
        if not Ready or not EventTimers[id] or EventTimers[id].finish ~= marker then return end
        if not finishEvent(event, true) then
            if ActiveEvents[id] then SetTimeout(5000, function() scheduleEventFinish(ActiveEvents[id]) end) end
        end
    end)
end

local function migrateLegacy()
    local now = os.time()
    -- Never touch delivered history. Version changes and a fixed draw happen in
    -- the same statement, making a second boot a no-op even after a partial run.
    for _, claim in ipairs(MySQL.query.await('SELECT * FROM encontros_reward_claims WHERE policy_version < ? AND claimed = 0', { Policy.VERSION }) or {}) do
        if Policy.catalog(claim.reward_table) then
            assert(Policy.validateCatalog(QBCore.Shared.Items, claim.reward_table), 'Catalogo indisponivel para migracao.')
            local reward = Policy.draw(claim.reward_table)
            MySQL.update.await([[UPDATE encontros_reward_claims SET reward_item = ?, reward_amount = 1, reward_custom = NULL,
                policy_version = ?, status = 'pending', status_reason = NULL, drawn_at = ?, expires_at = ?
                WHERE id = ? AND policy_version < ? AND claimed = 0]],
                { reward.item, Policy.VERSION, now, now + Policy.CLAIM_TTL, claim.id, Policy.VERSION })
        else
            MySQL.update.await([[UPDATE encontros_reward_claims SET status = 'suspended', policy_version = ?,
                status_reason = 'Categoria antiga suspensa: somente carro e moto.' WHERE id = ? AND policy_version < ? AND claimed = 0]],
                { Policy.VERSION, claim.id, Policy.VERSION })
        end
    end
    for _, event in ipairs(MySQL.query.await('SELECT * FROM encontros WHERE policy_version < ?', { Policy.VERSION }) or {}) do
        if event.status ~= 'active' and event.status ~= 'scheduled' then
            -- Delivered/history rows retain their original reward configuration.
            MySQL.update.await('UPDATE encontros SET policy_version = ? WHERE id = ? AND policy_version < ?',
                { Policy.VERSION, event.id, Policy.VERSION })
        else
        local status, reason = event.status, ''
        local enabled = event.event_type ~= 'marcador' and (truthy(event.reward_enabled)
            or (event.reward_item and event.reward_item ~= '') or (event.reward_custom and event.reward_custom ~= '' and event.reward_custom ~= '[]'))
        if status == 'active' then
            status, reason = 'cancelled', 'Evento ativo anterior a regra de presenca. Recrie para iniciar a contagem.'
        elseif status == 'scheduled' and enabled and not Policy.catalog(event.reward_table) then
            status, reason = 'blocked', 'Categoria antiga bloqueada. Recrie com pecas de carro ou moto.'
        end
        MySQL.update.await([[UPDATE encontros SET status = ?, status_reason = ?, reward_enabled = ?, reward_item = '',
            reward_custom = NULL, policy_version = ?, finished_at = CASE WHEN ? IN ('cancelled', 'blocked') THEN ? ELSE finished_at END
            WHERE id = ? AND policy_version < ?]], { status, reason, enabled and 1 or 0, Policy.VERSION, status, now, event.id, Policy.VERSION })
        end
    end
end
local function hydrateEventTimers()
    for _, event in ipairs(MySQL.query.await("SELECT * FROM encontros WHERE status IN ('active', 'scheduled')") or {}) do
        if event.status == 'active' then
            if os.time() >= endsAt(event) or not event.started_at then
                closeWithoutAward(event, 'interrupted', 'Servidor ou recurso indisponivel no encerramento. Recrie o evento.', true)
            elseif eventHasReward(event) and not Policy.validateCatalog(QBCore.Shared.Items, event.reward_table) then
                closeWithoutAward(event, 'blocked', 'Catalogo de pecas indisponivel. Recrie o evento.', false)
            else
                loadAttendance(event)
                if os.time() >= endsAt(event) then
                    closeWithoutAward(event, 'interrupted', 'Recurso indisponivel ate o encerramento. Recrie o evento.', true)
                else
                    Attendance[event.id] = observe(event, os.time())
                    scheduleEventFinish(event)
                end
            end
        else
            scheduleEventStart(event)
        end
    end
end

MySQL.ready(function()
    local ok = pcall(function()
        for _, sql in ipairs(EncounterSchema) do MySQL.query.await(sql) end
        migrateLegacy()
        Ready = true
        hydrateEventTimers()
    end)
    if not ok then
        Ready = false
        print('[Encontrinhos_Pog] Inicializacao incompleta; eventos e resgates bloqueados. Verifique esquema e catalogo antes de reiniciar o recurso.')
    end
end)

CreateThread(function()
    local nextSample = os.time() + Policy.SAMPLE_SECONDS
    while true do
        Wait(math.max(0, nextSample - os.time()) * 1000)
        nextSample = os.time() + Policy.SAMPLE_SECONDS
        if Ready then
            for id, event in pairs(ActiveEvents) do
                -- Independent writes prevent SQL latency from other events or
                -- inventory recovery from stretching every sampling interval.
                if not EventLocks[id] then
                    CreateThread(function()
                        if PendingClosures[id] then finishEvent(event) else sampleEvent(event) end
                    end)
                end
            end
        end
    end
end)
CreateThread(function()
    while true do
        Wait(Policy.SAMPLE_SECONDS * 1000)
        if Ready then
            -- Pending inventory operations survive a restart of this resource.
            -- The bridge owns the durable barrier and reconciles the captured
            -- session, including disconnected players, before unlocking saves.
            pcall(function()
                for _, pending in ipairs(exports['qb-inventory']:GetPendingExternalItemMutations('encounter') or {}) do
                    local claimId = tonumber(tostring(pending.operationId):match('^encounter_(%d+)$'))
                    if claimId then exports['qb-inventory']:ReconcileEncounterReward(pending.source, claimId) end
                end
            end)
        end
    end
end)
local function forgetSession(playerId)
    playerId = tonumber(playerId)
    if not playerId then return end
    Sessions[playerId] = nil
    EncounterAttendance.disconnect(Attendance, playerId)
end
AddEventHandler('playerDropped', function() forgetSession(source) end)
AddEventHandler('QBCore:Server:OnPlayerUnload', forgetSession)
-- Kept as a harmless compatibility endpoint. The client cannot grant attendance.
RegisterNetEvent('encontros:server:setInsideArea', function() end)

QBCore.Functions.CreateCallback('encontros:server:getAll', function(playerId, cb)
    if not Ready or not isAdmin(playerId) then cb({}) return end
    cb(MySQL.query.await('SELECT * FROM encontros ORDER BY start_time DESC') or {})
end)
QBCore.Functions.CreateCallback('encontros:server:getActive', function(_, cb)
    local events = {}
    if Ready then
        for _, event in pairs(ActiveEvents) do
            if os.time() < endsAt(event) then events[#events + 1] = publicEvent(event) end
        end
    end
    table.sort(events, function(a, b) return a.start_time > b.start_time end)
    cb(events)
end)
QBCore.Functions.CreateCallback('encontros:server:canPlaceNpc', function(playerId, cb)
    cb(Ready and getCitizenId(playerId) ~= nil and isAdmin(playerId))
end)
QBCore.Functions.CreateCallback('encontros:server:getRewardClaimNpcs', function(playerId, cb)
    local citizenid = getCitizenId(playerId)
    if not Ready or not citizenid then cb({}, os.time()) return end
    local observedAt, bucket, npcs = os.time(), GetPlayerRoutingBucket(playerId), {}
    local events = MySQL.query.await([[SELECT * FROM encontros WHERE reward_enabled = 1
        AND routing_bucket = ? AND (status = 'active' OR (status = 'finished' AND finished_at > ?))]],
        { bucket, observedAt - eventNpcLifetime() }) or {}
    local now = os.time() -- A database wait cannot keep a local NPC past its deadline.
    if not getCitizenId(playerId) or GetPlayerRoutingBucket(playerId) ~= bucket then cb({}, observedAt) return end
    for _, event in ipairs(events) do
        local coords = eventNpcCoords(event)
        if coords and eventHasReward(event) and (tonumber(event.routing_bucket) or 0) == bucket
            and ((event.status == 'active' and endsAt(event) > now)
                or (event.status == 'finished' and tonumber(event.finished_at) and tonumber(event.finished_at) + eventNpcLifetime() > now)) then
            local entry = { id = event.id, title = event.title, coords = coords, routing_bucket = bucket,
                expires_at = (event.status == 'finished' and tonumber(event.finished_at) or endsAt(event)) + eventNpcLifetime() }
            npcs[#npcs + 1] = entry
        end
    end
    local fixed = fixedNpcCoords()
    if fixed and bucket == (Config.RewardClaimNpc.routingBucket or 0) then
        npcs[#npcs + 1] = { id = 0, title = 'Premios dos encontros', fixed = true,
            coords = fixed, routing_bucket = bucket }
    end
    table.sort(npcs, function(a, b) return tonumber(a.id) < tonumber(b.id) end)
    -- The client anchors this clock to its request timer, so SQL latency is
    -- subtracted once. Selection above still uses the clock after the query.
    cb(npcs, observedAt)
end)
QBCore.Functions.CreateCallback('encontros:server:getMyAttendance', function(playerId, cb)
    local result, citizenid, now = {}, getCitizenId(playerId), os.time()
    if Ready and citizenid then
        for id, event in pairs(ActiveEvents) do
            local record = Attendance[id] and Attendance[id][citizenid]
            result[tostring(id)] = { seconds = record and record.seconds or 0,
                current_required_seconds = Policy.minimumSeconds(event.started_at, math.min(now, endsAt(event))),
                planned_required_seconds = Policy.minimumSeconds(event.started_at, endsAt(event)), inside = insideEvent(event, playerId) }
        end
    end
    cb(result)
end)

QBCore.Functions.CreateCallback('encontros:server:create', function(playerId, cb, data)
    if not Ready then cb(false, 'Sistema de encontros indisponivel.') return end
    if not isAdmin(playerId) then cb(false, 'Sem permissao.') return end
    data = type(data) == 'table' and data or {}
    local randomizeLocation = truthy(data.random_location)
    local title, location = tostring(data.title or ''):sub(1, 100), tostring(data.location or ''):sub(1, 100)
    local selectedLocation, locationKey = nil, nil
    local coords = type(data.coords) == 'table' and data.coords or {}
    local x, y, z = finite(coords.x or data.coords_x), finite(coords.y or data.coords_y), finite(coords.z or data.coords_z)
    if randomizeLocation then
        selectedLocation = randomLocation()
        if not selectedLocation then cb(false, 'Nenhum local valido com NPC configurado em Config.Locations.') return end
        if title == '' then title = 'Encontro Aleatorio' end
        location, locationKey = selectedLocation.label, selectedLocation.key
        x, y, z = selectedLocation.x, selectedLocation.y, selectedLocation.z
    else
        if title == '' or location == '' then cb(false, 'Informe o nome e o local do encontro.') return end
        if not x or not y or not z then cb(false, 'Informe um vector3 valido para o encontro.') return end
    end
    -- Removed controls are rejected here too, including direct network calls.
    for _, key in ipairs({ 'reward_item', 'reward_custom', 'custom_rewards', 'reward_amount', 'amount', 'rewards' }) do
        if data[key] ~= nil and data[key] ~= '' then cb(false, 'Premiacao personalizada desativada. Use carro ou moto, uma unidade.') return end
    end
    if data.reward_mode and data.reward_mode ~= 'table' then cb(false, 'Premiacao personalizada desativada.') return end
    local category = tostring(data.reward_table or '')
    if category ~= '' and not Policy.catalog(category) then cb(false, 'Somente pecas de carro e moto estao liberadas.') return end
    local eventType = getEventType(data.event_type)
    local marker = eventType == 'marcador' or blipConfig(eventType).requiresNpc == false
    local enabled = not marker and truthy(data.reward_enabled)
    local npc = randomizeLocation and not marker and selectedLocation and selectedLocation.npc or nil
    if enabled then
        local valid, reason = Policy.validateCatalog(QBCore.Shared.Items, category)
        if not valid then cb(false, reason or 'Catalogo de pecas indisponivel.') return end
        if not randomizeLocation then
            local position = type(data.npc_coords) == 'table' and data.npc_coords or {}
            npc = npcCoords(position.x, position.y, position.z, position.w)
        end
        if not npc then cb(false, 'Posicione o NPC mecanico no mundo antes de criar o encontro premiado.') return end
    end
    local now, status = os.time(), data.status == 'active' and 'active' or 'scheduled'
    local startTime = status == 'active' and now or math.floor(finite(data.start_time) or now)
    if status == 'scheduled' and startTime <= now then cb(false, 'O horario agendado precisa estar no futuro.') return end
    local duration = math.floor(clampNumber(data.duration, 60, 1, 10080))
    local values = {
        title, tostring(data.description or ''):sub(1, 500), location, x, y, z,
        marker and 0 or (selectedLocation and clampNumber(selectedLocation.radius, blipConfig(eventType).radius or Config.EventAreaRadius, 1, 1000)
            or clampNumber(data.radius, blipConfig(eventType).radius or Config.EventAreaRadius, 1, 1000)),
        selectedLocation and clampNumber(selectedLocation.height_tolerance, Config.EventHeightTolerance, 1, 500)
            or clampNumber(data.height_tolerance or data.heightTolerance, Config.EventHeightTolerance, 1, 500), eventType,
        tostring(data.area_message or ''):sub(1, 500), blipSprite(data.blip_sprite, eventType), enabled and 1 or 0,
        category, startTime, duration, truthy(data.recurring) and 1 or 0, Policy.VERSION, GetPlayerRoutingBucket(playerId),
        randomizeLocation and 1 or 0, locationKey
    }
    if npc then
        values[21], values[22], values[23], values[24] = npc.x, npc.y, npc.z, npc.w
    end
    local id = MySQL.insert.await([[INSERT INTO encontros
        (title, description, location, coords_x, coords_y, coords_z, radius, height_tolerance, event_type, area_message,
         blip_sprite, reward_enabled, reward_table, start_time, duration, recurring, status, policy_version, routing_bucket,
         random_location, location_key, npc_x, npc_y, npc_z, npc_w)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'scheduled', ?, ?, ?, ?, ]] ..
        (npc and '?, ?, ?, ?)' or 'NULL, NULL, NULL, 0)'), values)
    if not id then cb(false, 'Nao foi possivel salvar o encontro.') return end
    local event = getEvent(id)
    if status == 'active' then
        local ok, reason = startEvent(event)
        if not ok then cb(false, reason or 'Encontro salvo, mas nao pode ser iniciado. Consulte o painel.') return end
    else scheduleEventStart(event) end
    cb(true)
end)

local function claimView(row, now)
    local item = QBCore.Shared.Items[row.reward_item or '']
    local status = truthy(row.claimed) and 'claimed' or row.status
    if status == 'pending' and (not row.expires_at or tonumber(row.expires_at) <= now) then status = 'expired' end
    return { id = row.id, event_id = row.event_id, event_title = row.event_title, item = row.reward_item, npc_coords = eventNpcCoords(row),
        pickup_kind = pickupLocation(row, now),
        label = item and item.label or row.reward_item or 'Premiacao suspensa', image = item and item.image or '',
        amount = row.reward_amount or 0, expires_at = row.expires_at, status = status, reason = row.status_reason }
end
QBCore.Functions.CreateCallback('encontros:server:getRewardClaims', function(playerId, cb, contextEventId)
    local citizenid = getCitizenId(playerId)
    if not Ready or not citizenid then cb({ ok = false, claims = {}, reason = 'Personagem ou sistema indisponivel.' }) return end
    local claims, contextSql, values, context = {}, '', { citizenid }, nil
    if contextEventId ~= nil then
        context = finite(contextEventId)
        if not context or context < 0 or context ~= math.floor(context) then
            cb({ ok = false, claims = {}, reason = 'NPC de encontro invalido.' }) return
        end
        if context > 0 then
            contextSql, values[2] = ' AND c.event_id = ?', context
        end
    end
    local rows = MySQL.query.await([[SELECT c.*, e.npc_x, e.npc_y, e.npc_z, e.npc_w,
        e.finished_at, e.status AS event_status, e.routing_bucket FROM encontros_reward_claims c
        LEFT JOIN encontros e ON e.id = c.event_id WHERE c.citizenid = ?]] .. contextSql .. [[
        ORDER BY COALESCE(c.expires_at, 9223372036854775807) ASC, c.id ASC]], values) or {}
    local now = os.time()
    for _, row in ipairs(rows) do
        local kind = pickupLocation(row, now)
        if context == nil or (context == 0 and kind == 'fixed') or (context and context > 0 and kind == 'event') then
            claims[#claims + 1] = claimView(row, now)
        end
    end
    cb({ ok = true, claims = claims, server_time = now,
        pickup_kind = context and context > 0 and 'event' or 'fixed', fixed_npc_coords = fixedNpcCoords() })
end)

local function claimReward(playerId, value)
    local claimId, citizenid = positiveId(value), getCitizenId(playerId)
    if not Ready or not citizenid or not claimId then return { ok = false, reason = 'Resgate invalido ou indisponivel.' } end
    if ClaimLocks[claimId] then return { ok = false, reason = 'Resgate em processamento. Aguarde.' } end
    ClaimLocks[claimId] = true
    local ok, result = pcall(function()
        -- Resolves an uncertain previous SQL result before allowing a fresh attempt.
        local recovered = exports['qb-inventory']:ReconcileEncounterReward(playerId, claimId)
        if recovered and recovered.ok == false and recovered.reason ~= 'operation_not_pending' then
            return { ok = false, reason = 'Entrega em verificacao. Aguarde antes de tentar novamente.' }
        end
        local claim = MySQL.single.await('SELECT * FROM encontros_reward_claims WHERE id = ? AND citizenid = ? LIMIT 1', { claimId, citizenid })
        if not claim then return { ok = false, reason = 'Recompensa nao encontrada para este personagem.' } end
        local event = getEvent(claim.event_id)
        if not insideClaimNpc(playerId, event) then
            local kind = pickupLocation(event, os.time())
            return { ok = false, reason = kind == 'event'
                and 'Retire no NPC do encontro durante os primeiros 10 minutos apos o termino.'
                or 'Va ate o NPC fixo de premios para reivindicar sua peca.' }
        end
        if truthy(claim.claimed) then return { ok = false, reason = 'Esta peca ja foi entregue.' } end
        if claim.status ~= 'pending' then return { ok = false, reason = claim.status_reason or 'Recompensa indisponivel.' } end
        if not claim.expires_at or tonumber(claim.expires_at) <= os.time() then return { ok = false, reason = 'O prazo de 24 horas para esta peca expirou.' } end
        if tonumber(claim.policy_version) ~= Policy.VERSION or tonumber(claim.reward_amount) ~= 1
            or not Policy.isAllowedItem(claim.reward_table, claim.reward_item) or not QBCore.Shared.Items[claim.reward_item] then
            return { ok = false, reason = 'Recompensa inconsistente. Avise a administracao.' }
        end
        local delivered = exports['qb-inventory']:CommitEncounterReward(playerId, claimId, {
            expectedCitizenId = citizenid, itemName = claim.reward_item,
            validate = function()
                local playerState = Player(playerId)
                return getCitizenId(playerId) == citizenid and insideClaimNpc(playerId, event)
                    and tonumber(claim.expires_at) > os.time()
                    and (not playerState or not playerState.state or not playerState.state.inv_busy)
            end,
        })
        if not delivered or not delivered.ok then
            return { ok = false, reason = 'Nao foi possivel entregar agora. Verifique espaco e disponibilidade do inventario; sua peca continua a mesma.' }
        end
        TriggerClientEvent('qb-inventory:client:ItemBox', playerId, QBCore.Shared.Items[claim.reward_item], 'add', 1)
        TriggerClientEvent('encontros:client:refreshClaimNpcs', playerId)
        return { ok = true, message = ('Voce resgatou 1x %s.'):format(QBCore.Shared.Items[claim.reward_item].label or claim.reward_item) }
    end)
    ClaimLocks[claimId] = nil
    if not ok then return { ok = false, reason = 'Entrega em verificacao. Tente novamente em instantes.' } end
    return result
end
QBCore.Functions.CreateCallback('encontros:server:claimReward', function(playerId, cb, claimId) cb(claimReward(playerId, claimId)) end)
RegisterNetEvent('encontros:server:claimReward', function(claimId)
    local playerId = tonumber(source)
    local result = claimReward(playerId, claimId)
    TriggerClientEvent('QBCore:Notify', playerId, result.message or result.reason, result.ok and 'success' or 'error', 7000)
end)
QBCore.Functions.CreateCallback('encontros:server:delete', function(playerId, cb, value)
    local id = positiveId(value)
    if not Ready or not isAdmin(playerId) or not id then cb(false) return end
    local ok = lockedEvent(id, function()
        local event = getEvent(id)
        if not event then return false end
        if event.status ~= 'scheduled' and event.status ~= 'active' then return false end
        return closeWithoutAward(event, 'cancelled', 'Cancelado pela administracao.', false)
    end)
    if ok then TriggerClientEvent('encontros:client:deleted', -1, id) end
    cb(ok)
end)
QBCore.Functions.CreateCallback('encontros:server:finish', function(playerId, cb, value)
    local id = positiveId(value)
    if not Ready or not isAdmin(playerId) or not id then cb(false) return end
    cb(finishEvent({ id = id }, false))
end)
RegisterCommand(Config.AdminCommand, function(playerId)
    if playerId ~= 0 and isAdmin(playerId) then TriggerClientEvent('encontros:client:openAdmin', playerId) end
end, false)
RegisterCommand(Config.EventCommand, function(playerId)
    if playerId ~= 0 then TriggerClientEvent('encontros:client:openInfo', playerId) end
end, false)
=======
        if x and y and z and npc then
            local key = sanitizeKey(entry.key, tostring(index))
            locations[#locations + 1] = {
                key = key,
                label = tostring(entry.label or key):sub(1, 100),
                x = x, y = y, z = z,
                radius = finite(entry.radius),
                height_tolerance = finite(entry.heightTolerance or entry.height_tolerance),
                npc = npc,
            }
        end
    end
    return locations
end
local function locationKeyForEvent(event)
    if event and event.location_key and tostring(event.location_key) ~= '' then return tostring(event.location_key) end
    if not event then return nil end
    for _, location in ipairs(configuredLocations()) do
        if location.label == event.location
            and location.x == tonumber(event.coords_x) and location.y == tonumber(event.coords_y) and location.z == tonumber(event.coords_z) then
            return location.key
        end
    end
    return nil
end
local function randomLocation(excludedKey)
    local locations, pool = configuredLocations(), {}
    if #locations == 0 then return nil end
    for _, location in ipairs(locations) do
        if #locations == 1 or location.key ~= excludedKey then pool[#pool + 1] = location end
    end
    if #pool == 0 then pool = locations end
    return pool[math.random(1, #pool)]
end
local function blipConfig(eventType) return Config.Blips[eventType] or Config.Blips.encontro or Config.Blips.social end
local function blipSprite(value, eventType)
    return math.floor(clampNumber(value, blipConfig(eventType).sprite, Config.BlipSpriteIdMin or 1, Config.BlipSpriteIdMax or 1000))
end
local function eventHasReward(event) return event.event_type ~= 'marcador' and truthy(event.reward_enabled) end
local function endsAt(event) return tonumber(event.start_time) + tonumber(event.duration) * 60 end
local function eventNpcCoords(event)
    return event and npcCoords(event.npc_x, event.npc_y, event.npc_z, event.npc_w) or nil
end
local function hasNpcPosition(event)
    return event and (event.npc_x ~= nil or event.npc_y ~= nil or event.npc_z ~= nil) or false
end
local function listAllows(list, value)
    return type(list) == 'table' and value ~= nil and (list[value] == true or list[tostring(value)] == true)
end
local function attendanceVehicleRequired()
    return type(Config.AttendanceVehicle) == 'table' and Config.AttendanceVehicle.required == true
end
local function normalizedPlate(value)
    local plate = tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', ''):upper()
    return plate ~= '' and plate or nil
end
local function sqlIdentifier(value, fallback)
    local identifier = tostring(value or fallback or '')
    return identifier:match('^[%w_]+$') and identifier or fallback
end
local function vehicleOwnedBy(citizenid, plate)
    local ownership = Config.AttendanceVehicle and Config.AttendanceVehicle.ownership or {}
    if type(ownership) ~= 'table' or ownership.required == false then return true end
    if not citizenid or not plate then return false end
    local tableName = sqlIdentifier(ownership.table, 'player_vehicles')
    local ownerColumn = sqlIdentifier(ownership.ownerColumn, 'citizenid')
    local plateColumn = sqlIdentifier(ownership.plateColumn, 'plate')
    local row = MySQL.single.await(('SELECT 1 AS owned FROM %s WHERE %s = ? AND UPPER(TRIM(%s)) = ? LIMIT 1')
        :format(tableName, ownerColumn, plateColumn), { citizenid, plate })
    return row ~= nil
end
local function allowedAttendanceVehicle(ped, citizenid)
    if not attendanceVehicleRequired() then return true end
    if type(GetVehiclePedIsIn) ~= 'function' then return false end
    local vehicle = GetVehiclePedIsIn(ped, false)
    if not vehicle or vehicle == 0 then return false end
    local settings = Config.AttendanceVehicle or {}
    if settings.driverOnly == true then
        if type(GetPedInVehicleSeat) ~= 'function' or GetPedInVehicleSeat(vehicle, -1) ~= ped then return false end
    end
    if type(settings.types) == 'table' then
        if type(GetVehicleType) ~= 'function' or not listAllows(settings.types, GetVehicleType(vehicle)) then return false end
    elseif type(settings.classes) == 'table' then
        if type(GetVehicleClass) ~= 'function' or not listAllows(settings.classes, GetVehicleClass(vehicle)) then return false end
    end
    if type(GetVehicleNumberPlateText) ~= 'function' then return false end
    return vehicleOwnedBy(citizenid, normalizedPlate(GetVehicleNumberPlateText(vehicle)))
end
local function publicEvent(event)
    return {
        id = event.id, title = event.title, description = event.description or '', location = event.location,
        event_type = event.event_type, area_message = event.area_message or '', blip_sprite = blipSprite(event.blip_sprite, event.event_type),
        coords = { x = event.coords_x, y = event.coords_y, z = event.coords_z },
        npc_coords = eventNpcCoords(event),
        reward_enabled = eventHasReward(event) and 1 or 0, reward_table = event.reward_table,
        radius = event.radius, height_tolerance = event.height_tolerance, start_time = event.start_time,
        started_at = event.started_at, finished_at = event.finished_at, duration = event.duration,
        status = event.status, status_reason = event.status_reason, recurring = truthy(event.recurring) and 1 or 0,
        random_location = truthy(event.random_location) and 1 or 0, location_key = event.location_key,
        routing_bucket = event.routing_bucket, policy_version = event.policy_version,
    }
end
local function getEvent(id)
    return MySQL.single.await('SELECT * FROM encontros WHERE id = ? LIMIT 1', { id })
end
local function token(kind, id)
    TokenSequence = TokenSequence + 1
    return ('%s:%s:%s:%s:%s'):format(kind, id, os.time(), TokenSequence, math.random(100000, 999999))
end
local function transaction(queries)
    local ok, committed = pcall(MySQL.transaction.await, queries)
    return ok and committed == true
end
local function lockedEvent(id, action)
    -- Timers, the sampler and administrative actions use the same lock. SQL state
    -- and a unique closure token additionally guard resource restarts/retries.
    while EventLocks[id] do Wait(25) end
    EventLocks[id] = true
    local ok, result, reason = pcall(action)
    EventLocks[id] = nil
    if not ok then
        print('[Encontrinhos_Pog] Operacao de encontro falhou; dados preservados para nova tentativa.')
        return false, 'Falha ao persistir o encontro.'
    end
    return result, reason
end
local function insideEventArea(event, playerId)
    if GetPlayerRoutingBucket(playerId) ~= (tonumber(event.routing_bucket) or 0) then return false end
    local ped = GetPlayerPed(playerId)
    if not ped or ped == 0 then return false end
    local coords = GetEntityCoords(ped)
    if not coords then return false end
    local dx, dy = coords.x - event.coords_x, coords.y - event.coords_y
    local inside = dx * dx + dy * dy <= (event.radius or Config.EventAreaRadius) ^ 2
        and math.abs(coords.z - event.coords_z) <= (event.height_tolerance or Config.EventHeightTolerance)
    return inside, ped
end
local function insideEvent(event, playerId, citizenid)
    local inside, ped = insideEventArea(event, playerId)
    if not inside then
        if event and event.id and citizenid and VehicleArrivals[event.id] then VehicleArrivals[event.id][citizenid] = nil end
        return false
    end
    if not attendanceVehicleRequired() then return true end
    local eventId = event and event.id
    if not eventId then return allowedAttendanceVehicle(ped, citizenid) end
    local arrivals = VehicleArrivals[eventId]
    if not arrivals then
        arrivals = {}
        VehicleArrivals[eventId] = arrivals
    end
    if citizenid and arrivals[citizenid] then return true end
    if allowedAttendanceVehicle(ped, citizenid) then
        if citizenid then arrivals[citizenid] = true end
        return true
    end
    return false
end
local function eventNpcLifetime()
    return math.max(0, math.floor(finite(Config.EventRewardNpc and Config.EventRewardNpc.afterFinishSeconds) or 600))
end
local function fixedNpcCoords()
    local config = Config.RewardClaimNpc
    local coords = config and config.coords
    return coords and npcCoords(coords.x, coords.y, coords.z, coords.w or 0) or nil
end
local function pickupLocation(event, now)
    local finishedAt = event and finite(event.finished_at)
    local status = event and (event.event_status or event.status)
    if status == 'finished' and finishedAt and now < finishedAt + eventNpcLifetime() and hasNpcPosition(event) then
        -- An incomplete local pose fails closed during its short pickup window.
        -- Historical events without a closing time use the permanent mechanic.
        return 'event', eventNpcCoords(event), tonumber(event.routing_bucket) or 0
    end
    return 'fixed', fixedNpcCoords(), Config.RewardClaimNpc and Config.RewardClaimNpc.routingBucket or 0
end
local function insideClaimNpc(playerId, event)
    local _, npc, bucket = pickupLocation(event, os.time())
    if not npc or GetPlayerRoutingBucket(playerId) ~= bucket then return false end
    local ped = GetPlayerPed(playerId)
    if not ped or ped == 0 then return false end
    local coords = GetEntityCoords(ped)
    if not coords then return false end
    return (coords.x - npc.x) ^ 2 + (coords.y - npc.y) ^ 2 + (coords.z - npc.z) ^ 2 <= 9
end
local function presentPlayers(event)
    local present = {}
    for _, value in ipairs(GetPlayers()) do
        local playerId = tonumber(value)
        local citizenid = getCitizenId(playerId)
        if citizenid and insideEvent(event, playerId, citizenid) then
            if not Sessions[playerId] or Sessions[playerId].citizenid ~= citizenid then
                SessionSequence = SessionSequence + 1
                Sessions[playerId] = { citizenid = citizenid, id = SessionSequence }
            end
            present[citizenid] = { source = playerId, session = Sessions[playerId].id }
        end
    end
    return present
end
local function attendanceQueries(id, state, now)
    local queries = {}
    for citizenid, record in pairs(state) do
        queries[#queries + 1] = { query = [[INSERT INTO encontros_attendance (event_id, citizenid, seconds, updated_at)
            VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE seconds = GREATEST(seconds, VALUES(seconds)), updated_at = VALUES(updated_at)]],
            values = { id, citizenid, record.seconds, now } }
    end
    return queries
end
local function loadAttendance(event)
    local state = {}
    for _, row in ipairs(MySQL.query.await('SELECT citizenid, seconds FROM encontros_attendance WHERE event_id = ?', { event.id }) or {}) do
        state[row.citizenid] = { seconds = tonumber(row.seconds) or 0 }
    end
    Attendance[event.id] = state -- never restore an observation across resource downtime
    VehicleArrivals[event.id] = {}
    ActiveEvents[event.id] = event
end
local function observe(event, now)
    local present = presentPlayers(event)
    return EncounterAttendance.observe(Attendance[event.id] or {}, present, now, event.started_at, endsAt(event)), present
end
local function sampleEvent(event)
    return lockedEvent(event.id, function()
        if not ActiveEvents[event.id] or PendingClosures[event.id] or os.time() >= endsAt(event) then return true end
        local now = os.time()
        local state = observe(event, now)
        local queries = attendanceQueries(event.id, state, now)
        -- The closing timer may need this already observed time while waiting
        -- for the SQL lock; publishing the observation is synchronous.
        Attendance[event.id] = state
        if #queries > 0 and not transaction(queries) then
            -- Keep time actually observed even if SQL acknowledgement is lost.
            -- Retry absolute totals (GREATEST), never additive deltas, so an
            -- uncertain commit neither duplicates nor discards earned time.
            for _, record in pairs(state) do record.observed_at = nil end
            Attendance[event.id] = state
            return false
        end
        for _, record in pairs(state) do
            local session = record.source and Sessions[record.source]
            if not session or session.id ~= record.session then record.observed_at = nil end
        end
        Attendance[event.id] = state
        return true
    end)
end
local function clearTimers(id) EventTimers[tonumber(id)] = nil end
local function recurrenceQuery(event, closedAt, finishToken)
    if not truthy(event.recurring) then return nil end
    local nextStart = event.start_time + 86400
    while nextStart <= closedAt do nextStart = nextStart + 86400 end
    if truthy(event.random_location) then
        local selected = randomLocation(locationKeyForEvent(event))
        if selected then
            return { query = [[INSERT IGNORE INTO encontros
                (title, description, location, coords_x, coords_y, coords_z, radius, height_tolerance, event_type,
                 area_message, blip_sprite, reward_enabled, reward_table, start_time, duration, recurring, status,
                 policy_version, routing_bucket, recurrence_parent_id, npc_x, npc_y, npc_z, npc_w, random_location, location_key)
                SELECT title, description, ?, ?, ?, ?, ?, ?, event_type, area_message, blip_sprite, reward_enabled,
                 reward_table, ?, duration, 1, 'scheduled', ?, routing_bucket, id, ?, ?, ?, ?, 1, ?
                FROM encontros WHERE id = ? AND finish_token = ?]], values = {
                    selected.label, selected.x, selected.y, selected.z,
                    clampNumber(selected.radius, event.radius or Config.EventAreaRadius, 1, 1000),
                    clampNumber(selected.height_tolerance, event.height_tolerance or Config.EventHeightTolerance, 1, 500),
                    nextStart, Policy.VERSION, selected.npc.x, selected.npc.y, selected.npc.z, selected.npc.w,
                    selected.key, event.id, finishToken,
                } }
        end
    end
    return { query = [[INSERT IGNORE INTO encontros
        (title, description, location, coords_x, coords_y, coords_z, radius, height_tolerance, event_type,
         area_message, blip_sprite, reward_enabled, reward_table, start_time, duration, recurring, status,
         policy_version, routing_bucket, recurrence_parent_id, npc_x, npc_y, npc_z, npc_w, random_location, location_key)
        SELECT title, description, location, coords_x, coords_y, coords_z, radius, height_tolerance, event_type,
         area_message, blip_sprite, reward_enabled, reward_table, ?, duration, 1, 'scheduled', ?, routing_bucket, id, npc_x, npc_y, npc_z, npc_w, random_location, location_key
        FROM encontros WHERE id = ? AND finish_token = ?]], values = { nextStart, Policy.VERSION, event.id, finishToken } }
end
local function afterClosure(event, status)
    local nextEvent = MySQL.single.await('SELECT * FROM encontros WHERE recurrence_parent_id = ? LIMIT 1', { event.id })
    ActiveEvents[event.id], Attendance[event.id], VehicleArrivals[event.id] = nil, nil, nil
    PendingClosures[event.id] = nil
    clearTimers(event.id)
    event.status = status
    if status == 'finished' then TriggerClientEvent('encontros:client:finished', -1, publicEvent(event)) end
    TriggerClientEvent('encontros:client:removed', -1, event.id)
    TriggerClientEvent('encontros:client:refreshClaimNpcs', -1)
    if nextEvent and nextEvent.status == 'scheduled' then scheduleEventStart(nextEvent) end
end
local function closeWithoutAward(event, status, reason, recur)
    local now, finishToken = os.time(), token(status, event.id)
    local queries = {{ query = [[UPDATE encontros SET status = ?, status_reason = ?, finished_at = ?, finish_token = ?
        WHERE id = ? AND status IN ('active', 'scheduled')]], values = { status, reason, now, finishToken, event.id } }}
    local recurrence = recur and recurrenceQuery(event, now, finishToken)
    if recurrence then queries[#queries + 1] = recurrence end
    transaction(queries)
    local persisted = getEvent(event.id)
    if not persisted then return false end
    if persisted.finish_token ~= finishToken then
        if persisted.status == 'active' or persisted.status == 'scheduled' then return false end
        afterClosure(persisted, persisted.status)
        return true -- a previous terminal transaction committed without its acknowledgement
    end
    afterClosure(persisted, status)
    if status == 'interrupted' or status == 'blocked' then announceAdmins(('Encontro "%s": %s'):format(event.title, reason)) end
    return true
end

local function startEvent(candidate)
    return lockedEvent(candidate.id, function()
        local event = getEvent(candidate.id)
        if not event then return false end
        if event.status == 'active' and not ActiveEvents[event.id] then
            if not event.started_at or os.time() >= endsAt(event) then
                return closeWithoutAward(event, 'interrupted', 'Ativacao sem confirmacao antes do encerramento. Recrie o evento.', true)
            end
            loadAttendance(event)
            if os.time() >= endsAt(event) then
                return closeWithoutAward(event, 'interrupted', 'Ativacao sem confirmacao antes do encerramento. Recrie o evento.', true)
            end
            Attendance[event.id] = observe(event, os.time())
            scheduleEventFinish(event)
            TriggerClientEvent('encontros:client:started', -1, publicEvent(event))
            TriggerClientEvent('encontros:client:refreshClaimNpcs', -1)
            return true
        end
        if event.status ~= 'scheduled' then return false end
        local now = os.time()
        if now >= endsAt(event) then
            return closeWithoutAward(event, 'interrupted', 'O horario do encontro passou durante a indisponibilidade. Recrie o evento.', true)
        end
        if eventHasReward(event) then
            local valid = Policy.validateCatalog(QBCore.Shared.Items, event.reward_table)
            if not valid then return closeWithoutAward(event, 'blocked', 'Categoria ou catalogo de pecas indisponivel. Recrie com carro ou moto.', false) end
        end
        local writeOk, changed = pcall(MySQL.update.await, [[UPDATE encontros SET status = 'active', started_at = ?, policy_version = ?
            WHERE id = ? AND status = 'scheduled']], { now, Policy.VERSION, event.id })
        if not writeOk or changed ~= 1 then
            local persisted = getEvent(event.id)
            if not persisted or persisted.status ~= 'active' or not persisted.started_at then return false end
            event = persisted
        else event.status, event.started_at = 'active', now end
        if os.time() >= endsAt(event) then
            return closeWithoutAward(event, 'interrupted', 'Banco indisponivel durante a ativacao. Recrie o evento.', true)
        end
        Attendance[event.id], VehicleArrivals[event.id], ActiveEvents[event.id] = {}, {}, event
        Attendance[event.id] = observe(event, os.time())
        TriggerClientEvent('encontros:client:started', -1, publicEvent(event))
        TriggerClientEvent('encontros:client:refreshClaimNpcs', -1)
        scheduleEventFinish(event)
        return true
    end)
end

local function announceRewards(event, rewards)
    for _, reward in ipairs(rewards) do
        if getCitizenId(reward.source) == reward.citizenid then
            local item = QBCore.Shared.Items[reward.item]
            local pickup = eventNpcCoords(event)
                and 'Retire no NPC do encontro nos primeiros 10 minutos; depois, no NPC fixo de premios. O prazo total e de 24 horas a partir do sorteio.'
                or 'Retire no NPC fixo de premios em ate 24 horas a partir do sorteio.'
            TriggerClientEvent('QBCore:Notify', reward.source,
                ('Voce ganhou 1x %s no encontro %s! %s'):format(item and item.label or reward.item, event.title, pickup), 'success', 12000)
        end
    end
end

local function prepareClosure(event)
    local now = os.time()
    if not event.started_at or now - endsAt(event) > Policy.SAMPLE_SECONDS + 2 then
        return { terminal = 'interrupted', reason = 'Presenca no encerramento nao pode ser comprovada apos indisponibilidade. Recrie o evento.', recur = true }
    end
    local closedAt = math.min(now, endsAt(event))
    local state, present = observe(event, closedAt)
    local minimum, rewards = Policy.minimumSeconds(event.started_at, closedAt), {}
    if eventHasReward(event) then
        if not Policy.validateCatalog(QBCore.Shared.Items, event.reward_table) then
            return { terminal = 'blocked', reason = 'Catalogo de pecas indisponivel no encerramento. Recrie o evento.', recur = false }
        end
        for citizenid, session in pairs(present) do
            if state[citizenid] and state[citizenid].seconds >= minimum then
                local reward = Policy.draw(event.reward_table)
                rewards[#rewards + 1] = { citizenid = citizenid, source = session.source, item = reward.item }
            end
        end
    end
    return { closedAt = closedAt, state = state, rewards = rewards, finishToken = token('finish', event.id) }
end

finishEvent = function(candidate)
    local observedEvent = ActiveEvents[candidate.id]
    if not observedEvent then return false end
    -- Capture at the trigger, BEFORE even waiting for a sampler's SQL lock.
    -- Cooperative handlers cannot interleave until the first yield, so only
    -- one immutable snapshot/draw is constructed for this event.
    if not PendingClosures[candidate.id] then PendingClosures[candidate.id] = prepareClosure(observedEvent) end
    return lockedEvent(candidate.id, function()
        local event = ActiveEvents[candidate.id]
        if not event then return false end
        local closure = PendingClosures[event.id]
        if closure.terminal then
            return closeWithoutAward(event, closure.terminal, closure.reason, closure.recur)
        end
        local closedAt, state, rewards, finishToken = closure.closedAt, closure.state, closure.rewards, closure.finishToken
        local current = getEvent(candidate.id)
        if not current then return false end
        if current.status ~= 'active' then
            afterClosure(current, current.status)
            if current.status == 'finished' and current.finish_token == finishToken then announceRewards(current, rewards) end
            return true -- reconcile an earlier committed but unacknowledged close
        end
        local queries = {{ query = [[UPDATE encontros SET status = 'finished', finished_at = ?, finish_token = ?, status_reason = NULL
            WHERE id = ? AND status = 'active']], values = { closedAt, finishToken, event.id } }}
        for _, query in ipairs(attendanceQueries(event.id, state, closedAt)) do queries[#queries + 1] = query end
        for _, reward in ipairs(rewards) do
            queries[#queries + 1] = { query = [[INSERT IGNORE INTO encontros_reward_claims
                (event_id, citizenid, event_title, reward_table, reward_item, reward_amount, policy_version, status, drawn_at, expires_at)
                SELECT id, ?, title, reward_table, ?, 1, ?, 'pending', ?, ? FROM encontros WHERE id = ? AND finish_token = ?]],
                values = { reward.citizenid, reward.item, Policy.VERSION, closedAt, closedAt + Policy.CLAIM_TTL, event.id, finishToken } }
        end
        local recurrence = recurrenceQuery(event, closedAt, finishToken)
        if recurrence then queries[#queries + 1] = recurrence end
        transaction(queries)
        -- Read after an ambiguous transaction response; never re-draw a committed closure.
        local persisted = getEvent(event.id)
        if not persisted or persisted.finish_token ~= finishToken then return false end
        afterClosure(persisted, 'finished')
        announceRewards(persisted, rewards)
        return true
    end)
end

scheduleEventStart = function(event)
    if not event then return end
    local id, marker = tonumber(event.id), token('start', event.id)
    EventTimers[id] = { start = marker }
    SetTimeout(math.max(0, event.start_time - os.time()) * 1000, function()
        if not Ready or not EventTimers[id] or EventTimers[id].start ~= marker then return end
        if not startEvent(event) then
            local ok, current = pcall(getEvent, id)
            if not ok or (current and (current.status == 'scheduled' or (current.status == 'active' and not ActiveEvents[id]))) then
                SetTimeout(5000, function() scheduleEventStart(ok and current or event) end)
            end
        end
    end)
end
scheduleEventFinish = function(event)
    if not event then return end
    local id, marker = tonumber(event.id), token('finishTimer', event.id)
    EventTimers[id] = { finish = marker }
    SetTimeout(math.max(0, endsAt(event) - os.time()) * 1000, function()
        if not Ready or not EventTimers[id] or EventTimers[id].finish ~= marker then return end
        if not finishEvent(event, true) then
            if ActiveEvents[id] then SetTimeout(5000, function() scheduleEventFinish(ActiveEvents[id]) end) end
        end
    end)
end

local function migrateLegacy()
    local now = os.time()
    -- Never touch delivered history. Version changes and a fixed draw happen in
    -- the same statement, making a second boot a no-op even after a partial run.
    for _, claim in ipairs(MySQL.query.await('SELECT * FROM encontros_reward_claims WHERE policy_version < ? AND claimed = 0', { Policy.VERSION }) or {}) do
        if Policy.catalog(claim.reward_table) then
            assert(Policy.validateCatalog(QBCore.Shared.Items, claim.reward_table), 'Catalogo indisponivel para migracao.')
            local reward = Policy.draw(claim.reward_table)
            MySQL.update.await([[UPDATE encontros_reward_claims SET reward_item = ?, reward_amount = 1, reward_custom = NULL,
                policy_version = ?, status = 'pending', status_reason = NULL, drawn_at = ?, expires_at = ?
                WHERE id = ? AND policy_version < ? AND claimed = 0]],
                { reward.item, Policy.VERSION, now, now + Policy.CLAIM_TTL, claim.id, Policy.VERSION })
        else
            MySQL.update.await([[UPDATE encontros_reward_claims SET status = 'suspended', policy_version = ?,
                status_reason = 'Categoria antiga suspensa: somente carro e moto.' WHERE id = ? AND policy_version < ? AND claimed = 0]],
                { Policy.VERSION, claim.id, Policy.VERSION })
        end
    end
    for _, event in ipairs(MySQL.query.await('SELECT * FROM encontros WHERE policy_version < ?', { Policy.VERSION }) or {}) do
        if event.status ~= 'active' and event.status ~= 'scheduled' then
            -- Delivered/history rows retain their original reward configuration.
            MySQL.update.await('UPDATE encontros SET policy_version = ? WHERE id = ? AND policy_version < ?',
                { Policy.VERSION, event.id, Policy.VERSION })
        else
        local status, reason = event.status, ''
        local enabled = event.event_type ~= 'marcador' and (truthy(event.reward_enabled)
            or (event.reward_item and event.reward_item ~= '') or (event.reward_custom and event.reward_custom ~= '' and event.reward_custom ~= '[]'))
        if status == 'active' then
            status, reason = 'cancelled', 'Evento ativo anterior a regra de presenca. Recrie para iniciar a contagem.'
        elseif status == 'scheduled' and enabled and not Policy.catalog(event.reward_table) then
            status, reason = 'blocked', 'Categoria antiga bloqueada. Recrie com pecas de carro ou moto.'
        end
        MySQL.update.await([[UPDATE encontros SET status = ?, status_reason = ?, reward_enabled = ?, reward_item = '',
            reward_custom = NULL, policy_version = ?, finished_at = CASE WHEN ? IN ('cancelled', 'blocked') THEN ? ELSE finished_at END
            WHERE id = ? AND policy_version < ?]], { status, reason, enabled and 1 or 0, Policy.VERSION, status, now, event.id, Policy.VERSION })
        end
    end
end
local function hydrateEventTimers()
    for _, event in ipairs(MySQL.query.await("SELECT * FROM encontros WHERE status IN ('active', 'scheduled')") or {}) do
        if event.status == 'active' then
            if os.time() >= endsAt(event) or not event.started_at then
                closeWithoutAward(event, 'interrupted', 'Servidor ou recurso indisponivel no encerramento. Recrie o evento.', true)
            elseif eventHasReward(event) and not Policy.validateCatalog(QBCore.Shared.Items, event.reward_table) then
                closeWithoutAward(event, 'blocked', 'Catalogo de pecas indisponivel. Recrie o evento.', false)
            else
                loadAttendance(event)
                if os.time() >= endsAt(event) then
                    closeWithoutAward(event, 'interrupted', 'Recurso indisponivel ate o encerramento. Recrie o evento.', true)
                else
                    Attendance[event.id] = observe(event, os.time())
                    scheduleEventFinish(event)
                end
            end
        else
            scheduleEventStart(event)
        end
    end
end

MySQL.ready(function()
    local ok = pcall(function()
        for _, sql in ipairs(EncounterSchema) do MySQL.query.await(sql) end
        migrateLegacy()
        Ready = true
        hydrateEventTimers()
    end)
    if not ok then
        Ready = false
        print('[Encontrinhos_Pog] Inicializacao incompleta; eventos e resgates bloqueados. Verifique esquema e catalogo antes de reiniciar o recurso.')
    end
end)

CreateThread(function()
    local nextSample = os.time() + Policy.SAMPLE_SECONDS
    while true do
        Wait(math.max(0, nextSample - os.time()) * 1000)
        nextSample = os.time() + Policy.SAMPLE_SECONDS
        if Ready then
            for id, event in pairs(ActiveEvents) do
                -- Independent writes prevent SQL latency from other events or
                -- inventory recovery from stretching every sampling interval.
                if not EventLocks[id] then
                    CreateThread(function()
                        if PendingClosures[id] then finishEvent(event) else sampleEvent(event) end
                    end)
                end
            end
        end
    end
end)
CreateThread(function()
    while true do
        Wait(Policy.SAMPLE_SECONDS * 1000)
        if Ready then
            -- Pending inventory operations survive a restart of this resource.
            -- The bridge owns the durable barrier and reconciles the captured
            -- session, including disconnected players, before unlocking saves.
            pcall(function()
                for _, pending in ipairs(exports['qb-inventory']:GetPendingExternalItemMutations('encounter') or {}) do
                    local claimId = tonumber(tostring(pending.operationId):match('^encounter_(%d+)$'))
                    if claimId then exports['qb-inventory']:ReconcileEncounterReward(pending.source, claimId) end
                end
            end)
        end
    end
end)
local function forgetSession(playerId)
    playerId = tonumber(playerId)
    if not playerId then return end
    local session = Sessions[playerId]
    if session and session.citizenid then
        for _, arrivals in pairs(VehicleArrivals) do arrivals[session.citizenid] = nil end
    end
    Sessions[playerId] = nil
    EncounterAttendance.disconnect(Attendance, playerId)
end
AddEventHandler('playerDropped', function() forgetSession(source) end)
AddEventHandler('QBCore:Server:OnPlayerUnload', forgetSession)
-- Kept as a harmless compatibility endpoint. The client cannot grant attendance.
RegisterNetEvent('encontros:server:setInsideArea', function() end)

QBCore.Functions.CreateCallback('encontros:server:getAll', function(playerId, cb)
    if not Ready or not isAdmin(playerId) then cb({}) return end
    cb(MySQL.query.await('SELECT * FROM encontros ORDER BY start_time DESC') or {})
end)
QBCore.Functions.CreateCallback('encontros:server:getActive', function(_, cb)
    local events = {}
    if Ready then
        for _, event in pairs(ActiveEvents) do
            if os.time() < endsAt(event) then events[#events + 1] = publicEvent(event) end
        end
    end
    table.sort(events, function(a, b) return a.start_time > b.start_time end)
    cb(events)
end)
QBCore.Functions.CreateCallback('encontros:server:canPlaceNpc', function(playerId, cb)
    cb(Ready and getCitizenId(playerId) ~= nil and isAdmin(playerId))
end)
QBCore.Functions.CreateCallback('encontros:server:getRewardClaimNpcs', function(playerId, cb)
    local citizenid = getCitizenId(playerId)
    if not Ready or not citizenid then cb({}, os.time()) return end
    local observedAt, bucket, npcs = os.time(), GetPlayerRoutingBucket(playerId), {}
    local events = MySQL.query.await([[SELECT * FROM encontros WHERE reward_enabled = 1
        AND routing_bucket = ? AND (status = 'active' OR (status = 'finished' AND finished_at > ?))]],
        { bucket, observedAt - eventNpcLifetime() }) or {}
    local now = os.time() -- A database wait cannot keep a local NPC past its deadline.
    if not getCitizenId(playerId) or GetPlayerRoutingBucket(playerId) ~= bucket then cb({}, observedAt) return end
    for _, event in ipairs(events) do
        local coords = eventNpcCoords(event)
        if coords and eventHasReward(event) and (tonumber(event.routing_bucket) or 0) == bucket
            and ((event.status == 'active' and endsAt(event) > now)
                or (event.status == 'finished' and tonumber(event.finished_at) and tonumber(event.finished_at) + eventNpcLifetime() > now)) then
            local entry = { id = event.id, title = event.title, coords = coords, routing_bucket = bucket,
                expires_at = (event.status == 'finished' and tonumber(event.finished_at) or endsAt(event)) + eventNpcLifetime() }
            npcs[#npcs + 1] = entry
        end
    end
    local fixed = fixedNpcCoords()
    if fixed and bucket == (Config.RewardClaimNpc.routingBucket or 0) then
        npcs[#npcs + 1] = { id = 0, title = 'Premios dos encontros', fixed = true,
            coords = fixed, routing_bucket = bucket }
    end
    table.sort(npcs, function(a, b) return tonumber(a.id) < tonumber(b.id) end)
    -- The client anchors this clock to its request timer, so SQL latency is
    -- subtracted once. Selection above still uses the clock after the query.
    cb(npcs, observedAt)
end)
QBCore.Functions.CreateCallback('encontros:server:getMyAttendance', function(playerId, cb)
    local result, citizenid, now = {}, getCitizenId(playerId), os.time()
    if Ready and citizenid then
        for id, event in pairs(ActiveEvents) do
            local record = Attendance[id] and Attendance[id][citizenid]
            result[tostring(id)] = { seconds = record and record.seconds or 0,
                current_required_seconds = Policy.minimumSeconds(event.started_at, math.min(now, endsAt(event))),
                planned_required_seconds = Policy.minimumSeconds(event.started_at, endsAt(event)), inside = insideEvent(event, playerId, citizenid) }
        end
    end
    cb(result)
end)

QBCore.Functions.CreateCallback('encontros:server:create', function(playerId, cb, data)
    if not Ready then cb(false, 'Sistema de encontros indisponivel.') return end
    if not isAdmin(playerId) then cb(false, 'Sem permissao.') return end
    data = type(data) == 'table' and data or {}
    local randomizeLocation = truthy(data.random_location)
    local title, location = tostring(data.title or ''):sub(1, 100), tostring(data.location or ''):sub(1, 100)
    local selectedLocation, locationKey = nil, nil
    local coords = type(data.coords) == 'table' and data.coords or {}
    local x, y, z = finite(coords.x or data.coords_x), finite(coords.y or data.coords_y), finite(coords.z or data.coords_z)
    if randomizeLocation then
        selectedLocation = randomLocation()
        if not selectedLocation then cb(false, 'Nenhum local valido com NPC configurado em Config.Locations.') return end
        if title == '' then title = 'Encontro Aleatorio' end
        location, locationKey = selectedLocation.label, selectedLocation.key
        x, y, z = selectedLocation.x, selectedLocation.y, selectedLocation.z
    else
        if title == '' or location == '' then cb(false, 'Informe o nome e o local do encontro.') return end
        if not x or not y or not z then cb(false, 'Informe um vector3 valido para o encontro.') return end
    end
    -- Removed controls are rejected here too, including direct network calls.
    for _, key in ipairs({ 'reward_item', 'reward_custom', 'custom_rewards', 'reward_amount', 'amount', 'rewards' }) do
        if data[key] ~= nil and data[key] ~= '' then cb(false, 'Premiacao personalizada desativada. Use carro ou moto, uma unidade.') return end
    end
    if data.reward_mode and data.reward_mode ~= 'table' then cb(false, 'Premiacao personalizada desativada.') return end
    local category = tostring(data.reward_table or '')
    if category ~= '' and not Policy.catalog(category) then cb(false, 'Somente pecas de carro e moto estao liberadas.') return end
    local eventType = getEventType(data.event_type)
    local marker = eventType == 'marcador' or blipConfig(eventType).requiresNpc == false
    local enabled = not marker and truthy(data.reward_enabled)
    local npc = randomizeLocation and not marker and selectedLocation and selectedLocation.npc or nil
    if enabled then
        local valid, reason = Policy.validateCatalog(QBCore.Shared.Items, category)
        if not valid then cb(false, reason or 'Catalogo de pecas indisponivel.') return end
        if not randomizeLocation then
            local position = type(data.npc_coords) == 'table' and data.npc_coords or {}
            npc = npcCoords(position.x, position.y, position.z, position.w)
        end
        if not npc then cb(false, 'Posicione o NPC mecanico no mundo antes de criar o encontro premiado.') return end
    end
    local now, status = os.time(), data.status == 'active' and 'active' or 'scheduled'
    local startTime = status == 'active' and now or math.floor(finite(data.start_time) or now)
    if status == 'scheduled' and startTime <= now then cb(false, 'O horario agendado precisa estar no futuro.') return end
    local duration = math.floor(clampNumber(data.duration, 60, 1, 10080))
    local values = {
        title, tostring(data.description or ''):sub(1, 500), location, x, y, z,
        marker and 0 or (selectedLocation and clampNumber(selectedLocation.radius, blipConfig(eventType).radius or Config.EventAreaRadius, 1, 1000)
            or clampNumber(data.radius, blipConfig(eventType).radius or Config.EventAreaRadius, 1, 1000)),
        selectedLocation and clampNumber(selectedLocation.height_tolerance, Config.EventHeightTolerance, 1, 500)
            or clampNumber(data.height_tolerance or data.heightTolerance, Config.EventHeightTolerance, 1, 500), eventType,
        tostring(data.area_message or ''):sub(1, 500), blipSprite(data.blip_sprite, eventType), enabled and 1 or 0,
        category, startTime, duration, truthy(data.recurring) and 1 or 0, Policy.VERSION, GetPlayerRoutingBucket(playerId),
        randomizeLocation and 1 or 0, locationKey
    }
    if npc then
        values[21], values[22], values[23], values[24] = npc.x, npc.y, npc.z, npc.w
    end
    local id = MySQL.insert.await([[INSERT INTO encontros
        (title, description, location, coords_x, coords_y, coords_z, radius, height_tolerance, event_type, area_message,
         blip_sprite, reward_enabled, reward_table, start_time, duration, recurring, status, policy_version, routing_bucket,
         random_location, location_key, npc_x, npc_y, npc_z, npc_w)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'scheduled', ?, ?, ?, ?, ]] ..
        (npc and '?, ?, ?, ?)' or 'NULL, NULL, NULL, 0)'), values)
    if not id then cb(false, 'Nao foi possivel salvar o encontro.') return end
    local event = getEvent(id)
    if status == 'active' then
        local ok, reason = startEvent(event)
        if not ok then cb(false, reason or 'Encontro salvo, mas nao pode ser iniciado. Consulte o painel.') return end
    else scheduleEventStart(event) end
    cb(true)
end)

local function claimView(row, now)
    local item = QBCore.Shared.Items[row.reward_item or '']
    local status = truthy(row.claimed) and 'claimed' or row.status
    if status == 'pending' and (not row.expires_at or tonumber(row.expires_at) <= now) then status = 'expired' end
    return { id = row.id, event_id = row.event_id, event_title = row.event_title, item = row.reward_item, npc_coords = eventNpcCoords(row),
        pickup_kind = pickupLocation(row, now),
        label = item and item.label or row.reward_item or 'Premiacao suspensa', image = item and item.image or '',
        amount = row.reward_amount or 0, expires_at = row.expires_at, status = status, reason = row.status_reason }
end
QBCore.Functions.CreateCallback('encontros:server:getRewardClaims', function(playerId, cb, contextEventId)
    local citizenid = getCitizenId(playerId)
    if not Ready or not citizenid then cb({ ok = false, claims = {}, reason = 'Personagem ou sistema indisponivel.' }) return end
    local claims, contextSql, values, context = {}, '', { citizenid }, nil
    if contextEventId ~= nil then
        context = finite(contextEventId)
        if not context or context < 0 or context ~= math.floor(context) then
            cb({ ok = false, claims = {}, reason = 'NPC de encontro invalido.' }) return
        end
        if context > 0 then
            contextSql, values[2] = ' AND c.event_id = ?', context
        end
    end
    local rows = MySQL.query.await([[SELECT c.*, e.npc_x, e.npc_y, e.npc_z, e.npc_w,
        e.finished_at, e.status AS event_status, e.routing_bucket FROM encontros_reward_claims c
        LEFT JOIN encontros e ON e.id = c.event_id WHERE c.citizenid = ?]] .. contextSql .. [[
        ORDER BY COALESCE(c.expires_at, 9223372036854775807) ASC, c.id ASC]], values) or {}
    local now = os.time()
    for _, row in ipairs(rows) do
        local kind = pickupLocation(row, now)
        if context == nil or (context == 0 and kind == 'fixed') or (context and context > 0 and kind == 'event') then
            claims[#claims + 1] = claimView(row, now)
        end
    end
    cb({ ok = true, claims = claims, server_time = now,
        pickup_kind = context and context > 0 and 'event' or 'fixed', fixed_npc_coords = fixedNpcCoords() })
end)

local function claimReward(playerId, value)
    local claimId, citizenid = positiveId(value), getCitizenId(playerId)
    if not Ready or not citizenid or not claimId then return { ok = false, reason = 'Resgate invalido ou indisponivel.' } end
    if ClaimLocks[claimId] then return { ok = false, reason = 'Resgate em processamento. Aguarde.' } end
    ClaimLocks[claimId] = true
    local ok, result = pcall(function()
        -- Resolves an uncertain previous SQL result before allowing a fresh attempt.
        local recovered = exports['qb-inventory']:ReconcileEncounterReward(playerId, claimId)
        if recovered and recovered.ok == false and recovered.reason ~= 'operation_not_pending' then
            return { ok = false, reason = 'Entrega em verificacao. Aguarde antes de tentar novamente.' }
        end
        local claim = MySQL.single.await('SELECT * FROM encontros_reward_claims WHERE id = ? AND citizenid = ? LIMIT 1', { claimId, citizenid })
        if not claim then return { ok = false, reason = 'Recompensa nao encontrada para este personagem.' } end
        local event = getEvent(claim.event_id)
        if not insideClaimNpc(playerId, event) then
            local kind = pickupLocation(event, os.time())
            return { ok = false, reason = kind == 'event'
                and 'Retire no NPC do encontro durante os primeiros 10 minutos apos o termino.'
                or 'Va ate o NPC fixo de premios para reivindicar sua peca.' }
        end
        if truthy(claim.claimed) then return { ok = false, reason = 'Esta peca ja foi entregue.' } end
        if claim.status ~= 'pending' then return { ok = false, reason = claim.status_reason or 'Recompensa indisponivel.' } end
        if not claim.expires_at or tonumber(claim.expires_at) <= os.time() then return { ok = false, reason = 'O prazo de 24 horas para esta peca expirou.' } end
        if tonumber(claim.policy_version) ~= Policy.VERSION or tonumber(claim.reward_amount) ~= 1
            or not Policy.isAllowedItem(claim.reward_table, claim.reward_item) or not QBCore.Shared.Items[claim.reward_item] then
            return { ok = false, reason = 'Recompensa inconsistente. Avise a administracao.' }
        end
        local delivered = exports['qb-inventory']:CommitEncounterReward(playerId, claimId, {
            expectedCitizenId = citizenid, itemName = claim.reward_item,
            validate = function()
                local playerState = Player(playerId)
                return getCitizenId(playerId) == citizenid and insideClaimNpc(playerId, event)
                    and tonumber(claim.expires_at) > os.time()
                    and (not playerState or not playerState.state or not playerState.state.inv_busy)
            end,
        })
        if not delivered or not delivered.ok then
            return { ok = false, reason = 'Nao foi possivel entregar agora. Verifique espaco e disponibilidade do inventario; sua peca continua a mesma.' }
        end
        TriggerClientEvent('qb-inventory:client:ItemBox', playerId, QBCore.Shared.Items[claim.reward_item], 'add', 1)
        TriggerClientEvent('encontros:client:refreshClaimNpcs', playerId)
        return { ok = true, message = ('Voce resgatou 1x %s.'):format(QBCore.Shared.Items[claim.reward_item].label or claim.reward_item) }
    end)
    ClaimLocks[claimId] = nil
    if not ok then return { ok = false, reason = 'Entrega em verificacao. Tente novamente em instantes.' } end
    return result
end
QBCore.Functions.CreateCallback('encontros:server:claimReward', function(playerId, cb, claimId) cb(claimReward(playerId, claimId)) end)
RegisterNetEvent('encontros:server:claimReward', function(claimId)
    local playerId = tonumber(source)
    local result = claimReward(playerId, claimId)
    TriggerClientEvent('QBCore:Notify', playerId, result.message or result.reason, result.ok and 'success' or 'error', 7000)
end)
QBCore.Functions.CreateCallback('encontros:server:delete', function(playerId, cb, value)
    local id = positiveId(value)
    if not Ready or not isAdmin(playerId) or not id then cb(false) return end
    local ok = lockedEvent(id, function()
        local event = getEvent(id)
        if not event then return false end
        if event.status ~= 'scheduled' and event.status ~= 'active' then return false end
        return closeWithoutAward(event, 'cancelled', 'Cancelado pela administracao.', false)
    end)
    if ok then TriggerClientEvent('encontros:client:deleted', -1, id) end
    cb(ok)
end)
QBCore.Functions.CreateCallback('encontros:server:finish', function(playerId, cb, value)
    local id = positiveId(value)
    if not Ready or not isAdmin(playerId) or not id then cb(false) return end
    cb(finishEvent({ id = id }, false))
end)
RegisterCommand(Config.AdminCommand, function(playerId)
    if playerId ~= 0 and isAdmin(playerId) then TriggerClientEvent('encontros:client:openAdmin', playerId) end
end, false)
RegisterCommand(Config.EventCommand, function(playerId)
    if playerId ~= 0 then TriggerClientEvent('encontros:client:openInfo', playerId) end
end, false)
>>>>>>> e0632c7a61e4d7d804debcb67e0c49d9ead74b61
