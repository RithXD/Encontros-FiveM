local QBCore = exports['qb-core']:GetCoreObject()

local ActiveEvents, EventBlips, RadiusBlips = {}, {}, {}
local ClaimPeds, panelOpen, panelView, panelRequest = {}, false, nil, 0
local claimContext, NpcSyncRequest, NpcSyncBusy, NpcSyncAgain = nil, 0, false, false
local ClaimBlip, NpcExpiryWorkerRunning, PlayerReady = nil, false, true
local Placement, PlacementPending, ResourceStopping = nil, false, false
local PlacementAttempt = 0
local PlacementKeys = {}
local NoticeQueue, SeenNotices, CurrentNotice = {}, {}, nil
local NoticeWorkerRunning = false
local NOTICE_DURATION_MS, NOTICE_UPDATE_MS = 10000, 100

local function noticeKey(event)
    local id = tonumber(event and event.id)
    local activation = tonumber(event and event.started_at)
    if not id or id ~= id or id <= 0 or id == math.huge or id ~= math.floor(id)
        or not activation or activation ~= activation or activation <= 0 or activation == math.huge
        or activation ~= math.floor(activation) then return nil end
    return ('%d:%d'):format(id, activation)
end

local function isNoticeEventActive(notice)
    local event = ActiveEvents[notice.eventId]
    return event and event.status == 'active' and event.event_type ~= 'marcador' and noticeKey(event) == notice.id
end

local function noticeElapsed(now, startedAt)
    -- GetGameTimer wraps; keep a notice's elapsed duration valid across the wrap.
    return (now - startedAt) % 4294967296
end

local function hideCurrentNotice()
    if CurrentNotice then SendNUIMessage({ action = 'hideStartNotice', id = CurrentNotice.id }) end
    CurrentNotice = nil
end

local function showNextNotice()
    while not CurrentNotice and #NoticeQueue > 0 do
        local notice = table.remove(NoticeQueue, 1)
        if isNoticeEventActive(notice) then
            notice.shownAt = GetGameTimer()
            notice.updatedAt = notice.shownAt
            CurrentNotice = notice
            SendNUIMessage({ action = 'showStartNotice', publicUi = Config.PublicUi, notice = {
                id = notice.id, title = notice.title, location = notice.location,
                durationMs = NOTICE_DURATION_MS, remainingMs = NOTICE_DURATION_MS, marked = false,
            } })
        end
    end
end

local function updateNotice(notice, remaining)
    notice.updatedAt = GetGameTimer()
    SendNUIMessage({ action = 'updateStartNotice', notice = {
        id = notice.id, remainingMs = remaining, marked = notice.marked,
    } })
end

local function runNoticeWorker()
    if NoticeWorkerRunning then return end
    NoticeWorkerRunning = true
    CreateThread(function()
        while CurrentNotice do
            local now = GetGameTimer()
            local notice = CurrentNotice
            local elapsed = noticeElapsed(now, notice.shownAt)
            if not isNoticeEventActive(notice) or elapsed >= NOTICE_DURATION_MS then
                hideCurrentNotice()
                showNextNotice()
                notice = CurrentNotice
                elapsed = 0
            end
            if notice then
                -- Disable the native headlight action every frame while H belongs
                -- to this notice. Other resources use the export below to yield H.
                DisableControlAction(0, 74, true)
                local remaining = NOTICE_DURATION_MS - elapsed
                if not notice.marked and not Placement and not PlacementPending and not IsNuiFocused() and not IsPauseMenuActive()
                    and IsDisabledControlJustPressed(0, 74) and isNoticeEventActive(notice) then
                    SetNewWaypoint(notice.x, notice.y)
                    notice.marked = true
                    updateNotice(notice, remaining)
                elseif noticeElapsed(now, notice.updatedAt) >= NOTICE_UPDATE_MS then
                    updateNotice(notice, remaining)
                end
            end
            Wait(0)
        end
        NoticeWorkerRunning = false
    end)
end

local function enqueueStartNotice(event)
    local key = noticeKey(event)
    if not key or SeenNotices[key] or event.status ~= 'active' or event.event_type == 'marcador' then return end
    local x, y = tonumber(event.coords and event.coords.x), tonumber(event.coords and event.coords.y)
    if not x or not y or x ~= x or y ~= y or math.abs(x) == math.huge or math.abs(y) == math.huge then return end
    SeenNotices[key] = true
    NoticeQueue[#NoticeQueue + 1] = {
        id = key, eventId = tonumber(event.id), title = event.title or 'Encontro', location = event.location or '',
        x = x + 0.0, y = y + 0.0, marked = false,
    }
    showNextNotice()
    runNoticeWorker()
end

local function removeStartNotice(eventId)
    for index = #NoticeQueue, 1, -1 do
        if NoticeQueue[index].eventId == eventId then table.remove(NoticeQueue, index) end
    end
    if CurrentNotice and CurrentNotice.eventId == eventId then
        hideCurrentNotice()
        showNextNotice()
    end
end

local function clearStartNotices()
    NoticeQueue = {}
    hideCurrentNotice()
end

exports('IsStartNoticeActive', function()
    return CurrentNotice ~= nil and isNoticeEventActive(CurrentNotice)
        and noticeElapsed(GetGameTimer(), CurrentNotice.shownAt) < NOTICE_DURATION_MS
end)

local function removeEventBlips(id)
    if EventBlips[id] then RemoveBlip(EventBlips[id]); EventBlips[id] = nil end
    if RadiusBlips[id] then RemoveBlip(RadiusBlips[id]); RadiusBlips[id] = nil end
end

local function removeAllBlips()
    for id in pairs(EventBlips) do removeEventBlips(id) end
end

local function removeTargetPed(ped)
    if ped and DoesEntityExist(ped) then
        exports['qb-target']:RemoveTargetEntity(ped)
        DeleteEntity(ped)
    end
end

local function removeClaimNpcs()
    NpcSyncRequest = NpcSyncRequest + 1
    NpcSyncBusy, NpcSyncAgain = false, false
    for id, npc in pairs(ClaimPeds) do
        removeTargetPed(npc.ped)
        ClaimPeds[id] = nil
    end
    if ClaimBlip then RemoveBlip(ClaimBlip); ClaimBlip = nil end
end

local function finite(value)
    local number = tonumber(value)
    return number and number == number and math.abs(number) < math.huge and number or nil
end

local function copyCoords(coords)
    local kind = type(coords)
    if kind ~= 'table' and kind ~= 'vector3' and kind ~= 'vector4' then return nil end
    local x, y, z = finite(coords.x), finite(coords.y), finite(coords.z)
    local w = finite(coords.w or coords.heading or 0)
    if not x or not y or not z or not w then return nil end
    return { x = x, y = y, z = z, w = w % 360 }
end

local function loadModel(model)
    RequestModel(model)

    local requestedAt = GetGameTimer()
    while not ResourceStopping and not HasModelLoaded(model) and noticeElapsed(GetGameTimer(), requestedAt) < 5000 do
        Wait(50)
    end

    return not ResourceStopping and HasModelLoaded(model)
end

local function freezeClaimPed(ped)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
end

local function npcRemaining(npc, now)
    if npc.fixed then return math.huge end
    return npc.lifetimeMs - noticeElapsed(now, npc.observedAt)
end

local function runNpcExpiryWorker()
    if NpcExpiryWorkerRunning then return end
    NpcExpiryWorkerRunning = true
    CreateThread(function()
        while not ResourceStopping do
            local timedNpc = false
            for id, npc in pairs(ClaimPeds) do
                if not npc.fixed then
                    if npcRemaining(npc, GetGameTimer()) <= 0 then
                        removeTargetPed(npc.ped)
                        ClaimPeds[id] = nil
                    else timedNpc = true end
                end
            end
            if not timedNpc then break end
            -- Check the local deadline every frame, independently of the 30s sync.
            Wait(0)
        end
        NpcExpiryWorkerRunning = false
    end)
end

local function syncFixedClaimBlip()
    local fixed = ClaimPeds[0]
    if not fixed then
        if ClaimBlip then RemoveBlip(ClaimBlip); ClaimBlip = nil end
        return
    end
    if ClaimBlip then return end
    local settings = (Config.RewardClaimNpc or {}).blip or {}
    local c = fixed.coords
    ClaimBlip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(ClaimBlip, settings.sprite or 446)
    SetBlipDisplay(ClaimBlip, 4)
    SetBlipScale(ClaimBlip, settings.scale or 0.7)
    SetBlipColour(ClaimBlip, settings.color or 3)
    SetBlipAsShortRange(ClaimBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(settings.label or 'Retirada de peças dos encontros')
    EndTextCommandSetBlipName(ClaimBlip)
end

local function syncClaimNpcs(entries, serverTime, request, requestedAt)
    local desired = {}
    serverTime = finite(serverTime)
    -- The server observes this clock before its SQL reads. Pair it with the
    -- request's local timer so delayed SQL/responses cannot extend the window.
    for _, entry in ipairs(entries or {}) do
        local id, coords = finite(entry.id), copyCoords(entry.coords)
        local fixed = id == 0 and entry.fixed == true
        local expiry = finite(entry.expires_at)
        if id and id >= 0 and id == math.floor(id) and coords and (fixed or (id > 0 and serverTime and expiry)) then
            local candidate = { id = id, coords = coords, routing_bucket = entry.routing_bucket or 0,
                fixed = fixed, expires_at = expiry, observedAt = requestedAt,
                lifetimeMs = fixed and 0 or math.max(0, expiry - serverTime) * 1000 }
            local previous = ClaimPeds[id]
            -- A repeated response for the same server deadline cannot renew it.
            if previous and not fixed and previous.expires_at == expiry
                and npcRemaining(previous, GetGameTimer()) < npcRemaining(candidate, GetGameTimer()) then
                candidate.observedAt, candidate.lifetimeMs = previous.observedAt, previous.lifetimeMs
            end
            if npcRemaining(candidate, GetGameTimer()) > 0 then desired[id] = candidate end
        end
    end
    for id, npc in pairs(ClaimPeds) do
        local target = desired[id]
        local c, d = npc.coords, target and target.coords
        if not target or not DoesEntityExist(npc.ped) or npc.routing_bucket ~= target.routing_bucket
            or c.x ~= d.x or c.y ~= d.y or c.z ~= d.z or c.w ~= d.w then
            removeTargetPed(npc.ped)
            ClaimPeds[id] = nil
            if id == 0 and ClaimBlip then RemoveBlip(ClaimBlip); ClaimBlip = nil end
        else
            npc.expires_at, npc.observedAt, npc.lifetimeMs = target.expires_at, target.observedAt, target.lifetimeMs
        end
    end
    syncFixedClaimBlip()
    for id, entry in pairs(desired) do
        if not ClaimPeds[id] then
            local settings = (entry.fixed and Config.RewardClaimNpc or Config.EventRewardNpc) or {}
            local model = GetHashKey(settings.model or 's_m_m_autoshop_02')
            local loaded = loadModel(model)
            if request ~= NpcSyncRequest then SetModelAsNoLongerNeeded(model); return end
            local c, ped = entry.coords, nil
            if loaded and npcRemaining(entry, GetGameTimer()) > 0 then
                ped = CreatePed(4, model, c.x, c.y, c.z, c.w, false, true)
            end
            if ped and ped ~= 0 then
                SetEntityCoordsNoOffset(ped, c.x, c.y, c.z, false, false, false)
                freezeClaimPed(ped)
                entry.ped = ped
                ClaimPeds[id] = entry
                runNpcExpiryWorker()
                syncFixedClaimBlip()
                exports['qb-target']:AddTargetEntity(ped, {
                    options = { {
                        icon = 'fas fa-gift', label = settings.label or 'Retirar prêmio do encontro',
                        action = function() TriggerEvent('encontros:client:openClaims', id) end,
                    } },
                    distance = settings.distance or 2.0,
                })
            end
            SetModelAsNoLongerNeeded(model)
        end
    end
end

local refreshClaimNpcs
refreshClaimNpcs = function(force)
    if ResourceStopping or not PlayerReady then return end
    if force == true then
        NpcSyncRequest = NpcSyncRequest + 1
        NpcSyncBusy, NpcSyncAgain = false, false
    end
    if NpcSyncBusy then NpcSyncAgain = true; return end
    NpcSyncBusy = true
    NpcSyncRequest = NpcSyncRequest + 1
    local request = NpcSyncRequest
    local requestedAt = GetGameTimer()
    QBCore.Functions.TriggerCallback('encontros:server:getRewardClaimNpcs', function(entries, serverTime)
        if request ~= NpcSyncRequest or ResourceStopping then return end
        syncClaimNpcs(entries, serverTime, request, requestedAt)
        if request ~= NpcSyncRequest or ResourceStopping then return end
        NpcSyncBusy = false
        if NpcSyncAgain then NpcSyncAgain = false; refreshClaimNpcs() end
    end)
    CreateThread(function()
        Wait(10000)
        if NpcSyncBusy and request == NpcSyncRequest then
            NpcSyncRequest = NpcSyncRequest + 1
            NpcSyncBusy = false
            if NpcSyncAgain then NpcSyncAgain = false; refreshClaimNpcs() end
        end
    end)
end

local function finishPlacement(confirmed, restoreFocus, reason)
    local placement = Placement
    PlacementAttempt = PlacementAttempt + 1
    Placement, PlacementPending, PlacementKeys = nil, false, {}
    if not placement then return end
    pcall(function() if placement.ped and DoesEntityExist(placement.ped) then DeleteEntity(placement.ped) end end)
    pcall(function() if DoesEntityExist(placement.player) then FreezeEntityPosition(placement.player, placement.wasFrozen) end end)
    pcall(function() if restoreFocus and panelOpen and panelView == 'admin' then SetNuiFocus(true, true) end end)
    pcall(SendNUIMessage, { action = 'finishNpcPlacement', confirmed = confirmed, reason = reason,
        coords = confirmed and copyCoords(placement.coords) or nil })
end

-- Cfx keyboard mappings support the main row and the numeric keypad separately.
for _, binding in ipairs({
    { 'up', 'PLUS', 'Subir NPC (+)' }, { 'down', 'MINUS', 'Descer NPC (-)' },
    { 'upNumpad', 'ADD', 'Subir NPC (numpad +)' }, { 'downNumpad', 'SUBTRACT', 'Descer NPC (numpad -)' },
}) do
    local key, command = binding[1], 'encontroNpc_' .. binding[1]
    RegisterCommand('+' .. command, function() if Placement then PlacementKeys[key] = true end end, false)
    RegisterCommand('-' .. command, function() PlacementKeys[key] = nil end, false)
    RegisterKeyMapping('+' .. command, binding[3], 'keyboard', binding[2])
end

local function runPlacement()
    CreateThread(function()
        while Placement do
            local ok = pcall(function()
            local current = Placement
            if PlayerPedId() ~= current.player or IsEntityDead(current.player) then
                finishPlacement(false, true)
                return
            end
            DisableAllControlActions(0)
            DisableAllControlActions(2)
            EnableControlAction(0, 1, true)
            EnableControlAction(0, 2, true)
            if IsNuiFocused() or IsPauseMenuActive() then PlacementKeys = {}; return end
            if IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 202) then
                finishPlacement(false, true)
            elseif IsDisabledControlJustPressed(0, 201) then
                finishPlacement(true, true)
            else
                local c, changed = current.coords, false
                local step = math.min(GetFrameTime(), 0.1) * (IsDisabledControlPressed(0, 21) and 2.0 or 0.5)
                local forward = (IsDisabledControlPressed(0, 172) and 1 or 0) - (IsDisabledControlPressed(0, 173) and 1 or 0)
                local right = (IsDisabledControlPressed(0, 175) and 1 or 0) - (IsDisabledControlPressed(0, 174) and 1 or 0)
                if forward ~= 0 or right ~= 0 then
                    local heading = math.rad(GetGameplayCamRot(2).z)
                    local length = math.max(1.0, math.sqrt(forward^2 + right^2))
                    c.x = c.x + (-math.sin(heading) * forward + math.cos(heading) * right) * step / length
                    c.y = c.y + (math.cos(heading) * forward + math.sin(heading) * right) * step / length
                    changed = true
                end
                local vertical = ((PlacementKeys.up or PlacementKeys.upNumpad) and 1 or 0)
                    - ((PlacementKeys.down or PlacementKeys.downNumpad) and 1 or 0)
                if vertical ~= 0 then c.z = c.z + vertical * step; changed = true end
                local rotation = (IsDisabledControlJustPressed(0, 241) and 1 or 0) - (IsDisabledControlJustPressed(0, 242) and 1 or 0)
                if rotation ~= 0 then c.w = (c.w + rotation * 5) % 360; changed = true end
                if changed then
                    SetEntityCoordsNoOffset(current.ped, c.x, c.y, c.z, false, false, false)
                    SetEntityHeading(current.ped, c.w)
                end
                if noticeElapsed(GetGameTimer(), current.lastUpdate) >= 100 then
                    current.lastUpdate = GetGameTimer()
                    SendNUIMessage({ action = 'updateNpcPlacement', coords = copyCoords(c) })
                end
            end
            end)
            if not ok then finishPlacement(false, true, 'Não foi possível continuar o posicionamento. Tente novamente.') end
            Wait(0)
        end
    end)
end

RegisterNUICallback('placeRewardNpc', function(data, cb)
    if Placement or PlacementPending or not panelOpen or panelView ~= 'admin' then
        cb({ ok = false, reason = 'Abra o formulário de criação para posicionar o mecânico.' }); return
    end
    PlacementPending = true
    PlacementAttempt = PlacementAttempt + 1
    local attempt = PlacementAttempt
    local request = panelRequest
    local answered = false
    local function releasePending()
        if attempt == PlacementAttempt then PlacementPending = false end
    end
    local function respond(result)
        if answered then return end
        answered = true
        cb(result)
    end
    CreateThread(function()
        Wait(10000)
        if not answered then
            releasePending()
            respond({ ok = false, reason = 'O posicionamento demorou para responder. Tente novamente.' })
        end
    end)
    QBCore.Functions.TriggerCallback('encontros:server:canPlaceNpc', function(allowed)
        if answered then return end
        if allowed ~= true or request ~= panelRequest or attempt ~= PlacementAttempt or ResourceStopping then
            releasePending()
            respond({ ok = false, reason = 'Não foi possível iniciar o posicionamento.' }); return
        end
        local player = PlayerPedId()
        if IsPedInAnyVehicle(player, false) or IsEntityDead(player) then
            releasePending()
            respond({ ok = false, reason = 'Saia do veículo para posicionar o mecânico.' }); return
        end
        local model = GetHashKey((Config.EventRewardNpc or {}).model or 's_m_m_autoshop_02')
        if not loadModel(model) or request ~= panelRequest or attempt ~= PlacementAttempt or answered then
            releasePending()
            SetModelAsNoLongerNeeded(model)
            respond({ ok = false, reason = 'Não foi possível carregar o mecânico.' }); return
        end
        local coords = copyCoords(data and data.coords)
        if not coords then
            coords = copyCoords(GetOffsetFromEntityInWorldCoords(player, 0.0, 2.0, 0.0))
            coords.w = GetEntityHeading(player) % 360
            local groundFound, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 2.0, false)
            if groundFound then coords.z = groundZ end
        end
        local preview = CreatePed(4, model, coords.x, coords.y, coords.z, coords.w, false, true)
        SetModelAsNoLongerNeeded(model)
        if not preview or preview == 0 then
            releasePending()
            respond({ ok = false, reason = 'Não foi possível criar a prévia do mecânico.' }); return
        end
        Placement = { ped = preview, player = player, coords = coords,
            wasFrozen = IsEntityPositionFrozen(player), lastUpdate = GetGameTimer() }
        PlacementPending, PlacementKeys = false, {}
        local ok = pcall(function()
            SetEntityCoordsNoOffset(preview, coords.x, coords.y, coords.z, false, false, false)
            freezeClaimPed(preview)
            SetEntityCollision(preview, false, false)
            SetEntityAlpha(preview, 180, false)
            FreezeEntityPosition(player, true)
            SetNuiFocus(false, false)
            SendNUIMessage({ action = 'showNpcPlacement', coords = copyCoords(coords) })
        end)
        if not ok then
            finishPlacement(false, true)
            respond({ ok = false, reason = 'Não foi possível iniciar a prévia. Tente novamente.' }); return
        end
        respond({ ok = true })
        runPlacement()
    end)
end)

local function createEventBlips(event)
    local id = tonumber(event.id)
    if not id then return end

    removeEventBlips(id)

    local blipConfig = Config.Blips[event.event_type] or Config.Blips.encontro or Config.Blips.social
    EventBlips[id] = AddBlipForCoord(event.coords.x, event.coords.y, event.coords.z)
    SetBlipSprite(EventBlips[id], event.blip_sprite or blipConfig.sprite)
    SetBlipDisplay(EventBlips[id], 4)
    SetBlipScale(EventBlips[id], blipConfig.scale)
    SetBlipColour(EventBlips[id], blipConfig.color)
    SetBlipAsShortRange(EventBlips[id], false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(event.title or blipConfig.label)
    EndTextCommandSetBlipName(EventBlips[id])

    local radius = (event.radius or Config.EventAreaRadius) + 0.0
    if radius > 0.0 then
        RadiusBlips[id] = AddBlipForRadius(event.coords.x, event.coords.y, event.coords.z, radius)
        SetBlipColour(RadiusBlips[id], blipConfig.color)
        SetBlipAlpha(RadiusBlips[id], 75)
    end
end

local function setActiveEvent(event)
    local id = tonumber(event and event.id)
    if not id then return end

    ActiveEvents[id] = event
    createEventBlips(event)
end

local function setActiveEvents(events)
    ActiveEvents = {}
    removeAllBlips()

    for _, event in ipairs(events or {}) do
        setActiveEvent(event)
    end
end

RegisterNUICallback('closePanel', function(_, cb)
    if Placement or PlacementPending then cb('placing'); return end
    SetNuiFocus(false, false)
    panelOpen = false
    panelView = nil
    claimContext = nil
    panelRequest = panelRequest + 1
    cb('ok')
end)

RegisterNUICallback('getPlayerCoords', function(_, cb)
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    cb({ x = c.x, y = c.y, z = c.z, w = GetEntityHeading(ped) })
end)

RegisterNUICallback('createEvent', function(data, cb)
    QBCore.Functions.TriggerCallback('encontros:server:create', function(ok, reason)
        cb({ ok = ok, reason = reason })
        if ok then
            QBCore.Functions.Notify('Encontro salvo com sucesso!', 'success')
            Wait(200)
            TriggerEvent('encontros:client:openAdmin')
        end
    end, data)
end)

RegisterNUICallback('deleteEvent', function(data, cb)
    QBCore.Functions.TriggerCallback('encontros:server:delete', function(ok)
        cb(ok)
        if ok then TriggerEvent('encontros:client:openAdmin') end
    end, data.id)
end)

RegisterNUICallback('finishEvent', function(data, cb)
    QBCore.Functions.TriggerCallback('encontros:server:finish', function(ok)
        cb(ok)
        if ok then TriggerEvent('encontros:client:openAdmin') end
    end, data.id)
end)

RegisterNUICallback('claimReward', function(data, cb)
    QBCore.Functions.TriggerCallback('encontros:server:claimReward', function(result)
        cb(result or { ok = false, reason = 'Não foi possível consultar o resgate.' })
    end, tonumber(data.id))
end)

RegisterNUICallback('refreshClaims', function(_, cb)
    QBCore.Functions.TriggerCallback('encontros:server:getRewardClaims', function(result)
        cb(result or { ok = false, reason = 'Não foi possível consultar os prêmios.' })
    end, claimContext)
end)

RegisterNUICallback('markOnMap', function(data, cb)
    SetNewWaypoint(data.x + 0.0, data.y + 0.0)
    cb('ok')
end)

RegisterNetEvent('encontros:client:openAdmin', function()
    if Placement or PlacementPending then return end
    panelRequest = panelRequest + 1
    local request = panelRequest
    QBCore.Functions.TriggerCallback('encontros:server:getAll', function(events)
        if request ~= panelRequest then return end
        panelOpen = true
        panelView = 'admin'
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'showAdmin', events = events, defaultRadius = Config.EventAreaRadius, defaultHeight = Config.EventHeightTolerance, blipIcons = Config.EventBlipIcons, blipConfigs = Config.Blips, rewardTables = Config.RewardTables })
    end)
end)

RegisterNetEvent('encontros:client:openInfo', function()
    if Placement or PlacementPending then return end
    panelRequest = panelRequest + 1
    local request = panelRequest
    QBCore.Functions.TriggerCallback('encontros:server:getActive', function(events)
        if request ~= panelRequest then return end
        panelOpen = true
        panelView = 'info'
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'showInfo', events = events, publicUi = Config.PublicUi })
        QBCore.Functions.TriggerCallback('encontros:server:getMyAttendance', function(attendance)
            if panelOpen and panelView == 'info' and request == panelRequest then
                SendNUIMessage({ action = 'updateAttendance', attendance = attendance })
            end
        end)
    end)
end)

RegisterNetEvent('encontros:client:openClaims', function(eventId)
    if Placement or PlacementPending then return end
    eventId = finite(eventId)
    if not eventId or eventId < 0 or eventId ~= math.floor(eventId) then return end
    panelRequest = panelRequest + 1
    local request = panelRequest
    QBCore.Functions.TriggerCallback('encontros:server:getRewardClaims', function(result)
        if request ~= panelRequest then return end
        if not result or not result.ok then
            QBCore.Functions.Notify(result and result.reason or 'Não foi possível consultar os prêmios.', 'error')
            return
        end
        panelOpen = true
        panelView = 'claims'
        claimContext = eventId
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'showClaims', claims = result.claims, server_time = result.server_time,
            pickup_kind = result.pickup_kind, fixed_npc_coords = result.fixed_npc_coords, publicUi = Config.PublicUi })
    end, eventId)
end)

-- Presence is counted only by the server. These reads update the open panel.
CreateThread(function()
    while true do
        Wait(5000)
        if panelOpen and panelView == 'info' then
            local request = panelRequest
            QBCore.Functions.TriggerCallback('encontros:server:getMyAttendance', function(attendance)
                if panelOpen and panelView == 'info' and request == panelRequest then
                    SendNUIMessage({ action = 'updateAttendance', attendance = attendance })
                end
            end)
        end
    end
end)

RegisterNetEvent('encontros:client:started', function(event)
    setActiveEvent(event)
    SendNUIMessage({ action = 'activeEventStarted', event = event })
    enqueueStartNotice(event)
    refreshClaimNpcs(true)
end)

RegisterNetEvent('encontros:client:removed', function(id)
    id = tonumber(id)
    if not id then return end

    ActiveEvents[id] = nil
    removeStartNotice(id)
    removeEventBlips(id)
    SendNUIMessage({ action = 'activeEventRemoved', id = id })
    refreshClaimNpcs(true)
end)

RegisterNetEvent('encontros:client:finished', function(event)
    local id = tonumber(event and event.id)
    if id then
        ActiveEvents[id] = nil
        removeStartNotice(id)
    end
    QBCore.Functions.Notify(('O encontro "%s" foi encerrado.'):format(event.title), 'primary', 7000)
    SendNUIMessage({ action = 'refreshClaims' })
    refreshClaimNpcs(true)
end)

RegisterNetEvent('encontros:client:refreshClaimNpcs', refreshClaimNpcs)

CreateThread(function()
    Wait(1000)
    while not ResourceStopping do
        refreshClaimNpcs()
        Wait(30000)
    end
end)

CreateThread(function()
    Wait(2000)
    QBCore.Functions.TriggerCallback('encontros:server:getActive', function(events)
        setActiveEvents(events or {})
    end)
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerReady = true
    refreshClaimNpcs(true)
end)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    PlayerReady = false
    panelRequest = panelRequest + 1
    finishPlacement(false, false)
    PlacementPending = false
    removeClaimNpcs()
    clearStartNotices()
    if panelOpen then SetNuiFocus(false, false) end
    panelOpen, panelView, claimContext = false, nil, nil
    SendNUIMessage({ action = 'hidePanel' })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    ResourceStopping = true
    panelRequest = panelRequest + 1
    finishPlacement(false, false)
    PlacementPending = false
    clearStartNotices()
    removeAllBlips()
    removeClaimNpcs()
    if panelOpen then SetNuiFocus(false, false) end
end)
