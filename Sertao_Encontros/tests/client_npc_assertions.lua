local assertions = 0
local function check(condition, message)
    assertions = assertions + 1
    assert(condition, message)
end
local function close(actual, expected) return math.abs(actual - expected) < 0.000001 end

ResetClient()
NpcEntries = { { id = 12, expires_at = 1800003600, coords = { x = 0, y = 0, z = 0, w = 0 }, routing_bucket = 0 },
    { id = 13, expires_at = 1800003600, coords = { x = 10, y = 20, z = 30, w = 90 }, routing_bucket = 0 } }
Frame(1000)
check(#CreatedEntities == 2, 'one ped for each supplied event')
local first = CreatedEntities[1]
local zeroPed
for ped, entity in pairs(Entities) do if ped ~= 1 and entity.coords.z == 0 then zeroPed = ped end end
check(zeroPed ~= nil and Entities[zeroPed].coords.x == 0, 'all-zero coordinates are valid and Z is exact')
check(Entities[first].model == 's_m_m_autoshop_02' and Entities[first].networked == false, 'local mechanic model')
check(Entities[first].frozen and Entities[first].invincible and Entities[first].blocked, 'stationary protected mechanic')
Handlers['encontros:client:refreshClaimNpcs']()
check(#CreatedEntities == 2, 'refresh does not duplicate peds')
TargetEntities[zeroPed].options[1].action()
check(LastCallback('encontros:server:getRewardClaims').args[1] == 12, 'target opens only event claims')
check(LastMessage('showClaims').pickup_kind == 'event' and LastMessage('showClaims').fixed_npc_coords.x == 1829.39,
    'claims screen receives pickup context and fixed destination')
Nui('refreshClaims')
check(LastCallback('encontros:server:getRewardClaims').args[1] == 12, 'refresh preserves claim context')
NpcEntries = { { id = 12, expires_at = 1800003600, coords = { x = 0, y = 0, z = 0, w = 0 }, routing_bucket = 0 } }
Handlers['encontros:client:refreshClaimNpcs']()
check(#DeletedEntities == 1 and Entities[zeroPed] ~= nil, 'removed entry removes only its NPC')
NpcEntries[1].routing_bucket = 3
Handlers['encontros:client:refreshClaimNpcs']()
check(Entities[zeroPed] == nil and #CreatedEntities == 3, 'bucket transition recreates scoped NPC')
Handlers['encontros:client:removed'](12)
check(#CreatedEntities == 3 and #DeletedEntities == 2, 'event end does not remove NPC still supplied for redemption')
NpcEntries = { { id = 0, fixed = true, coords = { x = 50, y = 60, z = 70, w = 0 }, routing_bucket = 0 } }
Handlers['encontros:client:refreshClaimNpcs']()
check(Entities[LatestPed()].coords.z == 70, 'fixed NPC uses its exact configured Z coordinate')
TargetEntities[LatestPed()].options[1].action()
check(LastCallback('encontros:server:getRewardClaims').args[1] == 0, 'fixed target context is zero')
check(LastMessage('showClaims').pickup_kind == 'fixed', 'fixed target forwards its context to the screen')
local fixedBlip = TestBlips[#TestBlips]
check(fixedBlip.sprite == 446 and fixedBlip.color == 3 and fixedBlip.scale == 0.7 and fixedBlip.shortRange == true,
    'fixed pickup blip is short range on the minimap')
NpcEntries = {}
Handlers['encontros:client:refreshClaimNpcs']()
check(next(TargetEntities) == nil, 'empty list removes NPCs and fixed point when leaving its bucket')
check(fixedBlip.removed, 'leaving fixed NPC bucket also removes its blip')

ResetClient()
check(Place().ok == false and #CreatedEntities == 0, 'placement requires open administration panel')
OpenAdmin()
AllowedPlacement = false
check(Place().ok == false and #CreatedEntities == 0 and not Entities[1].frozen, 'server authorization precedes preview')
AllowedPlacement = true
InVehicle = true
check(Place().ok == false and #CreatedEntities == 0, 'vehicle placement is rejected')
InVehicle = false
check(Place({ x = 0, y = 0, z = 0, w = 0 }).ok, 'zero coordinates can be edited')
local preview = LatestPed()
check(Entities[preview].coords.z == 0 and GroundCalls == 0, 'confirmed height is never snapped to ground')
check(Entities[preview].model == 's_m_m_autoshop_02' and Entities[preview].collision == false and Entities[preview].alpha == 180, 'noncolliding mechanic ghost')
check(TargetEntities[preview] == nil, 'preview has no claim target')
check(Entities[1].frozen and not Focused, 'player is frozen and NUI focus released')
check(LastMessage('showNpcPlacement').coords.z == 0, 'card receives exact coordinates')
check(Place().ok == false, 'double placement request cannot duplicate preview')
check(Nui('closePanel') == 'placing', 'Escape close callback cannot close draft during placement')
for _, key in ipairs({ 'PLUS', 'MINUS', 'ADD', 'SUBTRACT' }) do
    check(KeyMappings[key] and KeyMappings[key].device == 'keyboard', 'height binding: ' .. key)
end
HeldControls[172] = true
for _ = 1, 50 do Frame(20) end
check(close(Entities[preview].coords.y, 0.5) and close(Entities[preview].coords.x, 0), 'arrow movement is 0.5m per second')
HeldControls[172] = nil
CameraHeading = 90
HeldControls[175] = true
Frame(20)
check(close(Entities[preview].coords.y, 0.51), 'right arrow follows camera orientation')
HeldControls[175] = nil
Commands['+encontroNpc_up']()
Frame(20)
Commands['-encontroNpc_up']()
check(close(Entities[preview].coords.z, 0.01), 'main-row plus raises NPC')
Commands['+encontroNpc_down']()
Frame(20)
Commands['-encontroNpc_down']()
check(close(Entities[preview].coords.z, 0), 'main-row minus lowers NPC')
Commands['+encontroNpc_upNumpad']()
Frame(20)
Commands['-encontroNpc_upNumpad']()
Commands['+encontroNpc_downNumpad']()
Frame(20)
Commands['-encontroNpc_downNumpad']()
check(close(Entities[preview].coords.z, 0), 'numeric keypad raises and lowers')
Press(241)
check(Entities[preview].coords.w == 5, 'scroll up rotates five degrees')
Press(242)
check(Entities[preview].coords.w == 0, 'scroll down rotates back')
Press(242)
check(Entities[preview].coords.w == 355, 'heading wraps within 0..359')
check(DisabledGroups[0] and DisabledGroups[2] and EnabledControls[1] and EnabledControls[2], 'game actions suppressed while camera stays available')
Focused = true
Press(201)
check(Entities[preview] ~= nil, 'Enter in another NUI cannot confirm placement')
PressedControls = {}
Focused, Paused = false, true
Press(201)
check(Entities[preview] ~= nil, 'Enter in pause menu cannot confirm placement')
PressedControls = {}
Paused = false
Press(201)
check(Entities[preview] == nil and not Entities[1].frozen and Focused, 'confirmation deletes ghost and restores player/focus')
local confirmed = LastMessage('finishNpcPlacement')
check(confirmed.confirmed and confirmed.coords.w == 355 and close(confirmed.coords.z, 0), 'confirmation returns only final coordinates')
check(Entities[1].coords.x == 100 and Entities[1].coords.y == 200 and Entities[1].coords.z == 30, 'player never teleports')

ResetClient()
OpenAdmin()
Entities[1].frozen = true
check(Place().ok, 'initial position can use player location')
preview = LatestPed()
check(Entities[preview].coords.x == 100 and Entities[preview].coords.y == 202 and Entities[preview].coords.z == 29, 'new preview starts in front of player on found ground')
check(GroundCalls == 1, 'ground queried once at initialization')
Press(200)
check(Entities[preview] == nil and Entities[1].frozen and Focused, 'cancel restores previous frozen state')
check(not LastMessage('finishNpcPlacement').confirmed and LastMessage('finishNpcPlacement').coords == nil, 'cancel cannot overwrite confirmed draft coordinates')

ResetClient()
OpenAdmin()
Place({ x = 10, y = 20, z = 30, w = 45 })
preview = LatestPed()
Handlers['encontros:client:started'](Event(1))
check(ClientExports.IsStartNoticeActive(), 'visible notice keeps door integration blocking H while positioning')
PressedControls[74] = true
Frame(20)
check(#Waypoints == 0, 'H does not mark waypoint during positioning')
PressedControls = {}
FailCoordinates = true
HeldControls[172] = true
Frame(20)
check(Entities[preview] == nil and not Entities[1].frozen and Focused, 'native update failure restores state')
check(LastMessage('finishNpcPlacement').reason ~= nil and not LastMessage('finishNpcPlacement').confirmed, 'native failure returns recoverable error to form')

ResetClient()
OpenAdmin()
FailCoordinates = true
check(not Place().ok and not Entities[1].frozen and Focused, 'initialization native failure leaves form usable')
check(Entities[LatestPed()] == nil, 'failed initialization removes preview')

for _, termination in ipairs({ 'logout', 'stop', 'ped-change', 'death' }) do
    ResetClient()
    OpenAdmin()
    Place()
    preview = LatestPed()
    if termination == 'logout' then Handlers['QBCore:Client:OnPlayerUnload']()
    elseif termination == 'stop' then Handlers.onResourceStop('Encontrinhos_Pog')
    elseif termination == 'ped-change' then Entities[2] = { coords = { x = 0, y = 0, z = 0 }, frozen = false }; PlayerEntity = 2; Frame(20)
    else Dead = true; Frame(20) end
    check(Entities[preview] == nil and not Entities[1].frozen, 'cleanup after ' .. termination)
end

ResetClient()
OpenAdmin()
DeferredCallbacks['encontros:server:canPlaceNpc'] = true
Place()
Frame(1)
Frame(10000)
check(LastNuiResult and not LastNuiResult.ok and #CreatedEntities == 0, 'authorization timeout releases pending editor')
PendingCallbacks[1].callback(true)
check(#CreatedEntities == 0, 'late authorization cannot reopen timed-out editor')
DeferredCallbacks['encontros:server:canPlaceNpc'] = nil
check(Place().ok, 'retry after authorization timeout works')

ResetClient()
OpenAdmin()
ModelAvailable = false
CreateThread(function() Place() end)
Frame(1)
Frame(5000)
check(LastNuiResult and not LastNuiResult.ok and #CreatedEntities == 0 and not Entities[1].frozen, 'model timeout leaves draft and player untouched')

ResetClient()
OpenAdmin()
ModelAvailable = false
CreateThread(function() Place() end)
Frame(1)
Handlers['QBCore:Client:OnPlayerUnload']()
OpenAdmin()
DeferredCallbacks['encontros:server:canPlaceNpc'] = true
Place()
ModelAvailable = true
Frame(50)
check(#CreatedEntities == 0, 'stale model load cannot start preview after logout')
check(Place().ok == false and #PendingCallbacks == 1, 'stale model completion cannot clear a newer pending attempt')
PendingCallbacks[1].callback(true)
check(#CreatedEntities == 1 and not Focused, 'current attempt still starts after older model completion')

ResetClient()
ModelAvailable = false
NpcEntries = { { id = 30, expires_at = 1800003600, coords = { x = 1, y = 2, z = 3, w = 4 } } }
CreateThread(function() Handlers['encontros:client:refreshClaimNpcs']() end)
Frame(1)
Handlers['encontros:client:refreshClaimNpcs']()
check(#CreatedEntities == 0, 'overlapping refresh waits for the same model load')
Handlers.onResourceStop('Encontrinhos_Pog')
ModelAvailable = true
Frame(50)
check(#CreatedEntities == 0, 'model completion after resource stop cannot spawn NPC')

ResetClient()
DeferredCallbacks['encontros:server:getRewardClaimNpcs'] = true
Handlers['encontros:client:refreshClaimNpcs']()
Handlers['encontros:client:refreshClaimNpcs']()
check(#PendingCallbacks == 1, 'overlapping NPC list requests are coalesced')
NpcEntries = { { id = 22, expires_at = 1800003600, coords = { x = 1, y = 2, z = 3, w = 4 } } }
DeferredCallbacks['encontros:server:getRewardClaimNpcs'] = nil
PendingCallbacks[1].callback(NpcEntries, ServerNow())
check(#CreatedEntities == 1, 'coalesced refresh creates only one NPC')
Handlers['QBCore:Client:OnPlayerUnload']()
check(next(TargetEntities) == nil and Entities[LatestPed()] == nil, 'logout removes targets and peds')

local function centralNpc()
    return { id = 0, fixed = true, coords = Config.RewardClaimNpc.coords, routing_bucket = 0 }
end
local function temporaryNpc(id, expiry)
    return { id = id, coords = { x = 100, y = 200, z = 30, w = 90 }, routing_bucket = 0, expires_at = expiry }
end
local function eventPed()
    for ped, target in pairs(TargetEntities) do
        if Entities[ped].coords.x == 100 then return ped, target end
    end
end

ResetClient()
NpcEntries = { centralNpc(), temporaryNpc(80, ServerNow() + 600) }
Handlers['encontros:client:refreshClaimNpcs']()
local temporary = eventPed()
check(temporary ~= nil, 'event NPC starts the ten-minute collection window')
Frame(599999)
check(Entities[temporary] ~= nil and TargetEntities[temporary] ~= nil, 'temporary NPC remains until just before 600 seconds')
Frame(1)
check(Entities[temporary] == nil and TargetEntities[temporary] == nil, 'exactly 600 seconds removes ped and target without polling')
check(#CreatedEntities == 2, 'periodic response cannot recreate an expired local NPC')
local central
for ped in pairs(TargetEntities) do central = ped end
check(central and Entities[central].coords.x == 1829.39 and Entities[central].coords.z == 36.75,
    'permanent mechanic remains at exact fixed coordinates after event handoff')
Frame(86400000)
check(Entities[central] ~= nil, 'fixed NPC persists beyond individual prize expiration')
Handlers['QBCore:Client:OnPlayerUnload']()
local creations = #CreatedEntities
Frame(30000)
check(#CreatedEntities == creations and next(TargetEntities) == nil and TestBlips[#TestBlips].removed,
    'logout removes fixed blip and prevents polling from recreating NPCs')
Handlers['QBCore:Client:OnPlayerLoaded']()
check(#CreatedEntities == creations + 1, 'character load restores the permanent NPC once')
Handlers.onResourceStop('Encontrinhos_Pog')
check(next(TargetEntities) == nil and TestBlips[#TestBlips].removed, 'resource stop removes fixed NPC and blip')

ResetClient()
NpcEntries = { temporaryNpc(81, ServerNow() + 30) }
Frame(1000)
temporary = eventPed()
Frame(28999)
check(Entities[temporary] ~= nil, 'resource hydration keeps the existing remaining window')
Frame(1)
check(Entities[temporary] == nil, 'resource hydration does not grant a fresh ten minutes')

ResetClient()
DeferredCallbacks['encontros:server:getRewardClaimNpcs'] = true
local staleServerTime = ServerNow()
Handlers['encontros:client:refreshClaimNpcs']()
Frame(1500)
PendingCallbacks[1].callback({ temporaryNpc(82, staleServerTime + 1) }, staleServerTime)
check(#CreatedEntities == 0, 'response arriving after its deadline cannot resurrect an NPC')

ResetClient()
DeferredCallbacks['encontros:server:getRewardClaimNpcs'] = true
staleServerTime = ServerNow()
NpcEntries = { temporaryNpc(87, staleServerTime + 600) }
Handlers['encontros:client:refreshClaimNpcs']()
Frame(5000)
DeferredCallbacks['encontros:server:getRewardClaimNpcs'] = nil
PendingCallbacks[1].callback(NpcEntries, staleServerTime)
temporary = eventPed()
Frame(594999)
check(Entities[temporary] ~= nil, 'SQL delay is counted once with the pre-query server clock')
Frame(1)
check(Entities[temporary] == nil, 'delayed response keeps the original 600-second deadline')

ResetClient()
ModelAvailable = false
NpcEntries = { temporaryNpc(83, ServerNow() + 1) }
CreateThread(function() Handlers['encontros:client:refreshClaimNpcs']() end)
Frame(1)
ModelAvailable = true
Frame(1000)
check(#CreatedEntities == 0, 'model finishing after deadline cannot create an expired NPC')

ResetClient()
NpcEntries = { temporaryNpc(84, ServerNow() + 3600) }
Handlers['encontros:client:refreshClaimNpcs']()
temporary = eventPed()
DeferredCallbacks['encontros:server:getRewardClaimNpcs'] = true
Handlers['encontros:client:refreshClaimNpcs']()
local staleEntries, staleTime = NpcEntries, ServerNow()
NpcEntries = { temporaryNpc(84, ServerNow() + 600) }
DeferredCallbacks['encontros:server:getRewardClaimNpcs'] = nil
local finishedEvent = Event(84)
finishedEvent.finished_at, finishedEvent.status = ServerNow(), 'finished'
Handlers['encontros:client:finished'](finishedEvent)
PendingCallbacks[1].callback(staleEntries, staleTime)
Frame(599999)
check(Entities[temporary] ~= nil, 'early finish keeps exactly the new ten-minute grace window')
Frame(1)
check(Entities[temporary] == nil, 'pre-finish callback cannot restore the longer original deadline')

ResetClient()
ModelAvailable = false
NpcEntries = { temporaryNpc(85, ServerNow() + 3600) }
CreateThread(function() Handlers['encontros:client:refreshClaimNpcs']() end)
Frame(1)
NpcEntries = {}
Handlers['encontros:client:removed'](85)
ModelAvailable = true
Frame(50)
check(#CreatedEntities == 0, 'event cancellation invalidates an in-flight NPC model load')

ResetClient()
NpcEntries = { temporaryNpc(86, nil), { id = 0, coords = Config.RewardClaimNpc.coords, expires_at = ServerNow() + 600 } }
Handlers['encontros:client:refreshClaimNpcs']()
check(#CreatedEntities == 0, 'invalid deadline or missing fixed marker cannot create an immortal NPC')

for _, termination in ipairs({ 'logout', 'stop' }) do
    ResetClient()
    DeferredCallbacks['encontros:server:getRewardClaimNpcs'] = true
    Handlers['encontros:client:refreshClaimNpcs']()
    if termination == 'logout' then Handlers['QBCore:Client:OnPlayerUnload']()
    else Handlers.onResourceStop('Encontrinhos_Pog') end
    PendingCallbacks[1].callback({ centralNpc() }, ServerNow())
    check(#CreatedEntities == 0 and #TestBlips == 0, 'late fixed-NPC response is ignored after ' .. termination)
end

print(('Client encounter NPCs and placement: %d assertions passed'):format(assertions))
