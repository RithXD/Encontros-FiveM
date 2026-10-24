-- Extends the existing FiveM frame harness with local entities and NPC callbacks.
local originalReset = ResetClient
function ResetClient()
    Entities = { [1] = { coords = { x = 100, y = 200, z = 30, w = 90 }, frozen = false } }
    PlayerEntity, NextEntity, CreatedEntities, DeletedEntities = 1, 100, {}, {}
    TargetEntities, RemovedTargets, Commands, KeyMappings = {}, {}, {}, {}
    NpcEntries, CallbackCalls, DeferredCallbacks, PendingCallbacks = {}, {}, {}, {}
    TestBlips, RemovedBlips = {}, {}
    PressedControls, HeldControls, DisabledGroups, EnabledControls = {}, {}, {}, {}
    ModelAvailable, AllowedPlacement, InVehicle, Dead, CameraHeading, FrameSeconds = true, true, false, false, 0, 0.02
    GroundHeight, GroundCalls, FailCoordinates, LastNuiResult = 29, 0, false, nil
    originalReset()
end
Config.EventRewardNpc = { model = 's_m_m_autoshop_02', distance = 2.0, afterFinishSeconds = 600 }
Config.RewardClaimNpc = { model = 's_m_m_autoshop_02', coords = vector4(1829.39, 3844.86, 36.75, 122.80),
    label = 'Retirar peças dos encontros', blip = { sprite = 446, color = 3, scale = 0.7, label = 'Retirada de peças dos encontros' } }
function ServerNow() return 1800000000 + math.floor((Now - 10000) / 1000) end
local Core = exports['qb-core']:GetCoreObject()
function Core.Functions.TriggerCallback(name, callback, ...)
    CallbackCalls[#CallbackCalls + 1] = { name = name, args = { ... } }
    if DeferredCallbacks[name] then
        PendingCallbacks[#PendingCallbacks + 1] = { name = name, callback = callback }; return
    end
    if name == 'encontros:server:getActive' then callback(HydratedEvents)
    elseif name == 'encontros:server:getRewardClaimNpcs' then callback(NpcEntries, ServerNow())
    elseif name == 'encontros:server:canPlaceNpc' then callback(AllowedPlacement)
    elseif name == 'encontros:server:getRewardClaims' then
        local context = ...
        callback({ ok = true, claims = {}, server_time = ServerNow(),
            pickup_kind = context == 0 and 'fixed' or 'event', fixed_npc_coords = Config.RewardClaimNpc.coords })
    else callback({}) end
end
function RegisterCommand(name, fn) Commands[name] = fn end
function RegisterKeyMapping(command, label, device, key) KeyMappings[key] = { command = command, device = device, label = label } end
function PlayerPedId() return PlayerEntity end
function GetEntityCoords(ped) return Entities[ped].coords end
function GetEntityHeading(ped) return Entities[ped].coords.w end
function GetOffsetFromEntityInWorldCoords(ped, x, y, z)
    local c = Entities[ped].coords
    return { x = c.x + x, y = c.y + y, z = c.z + z }
end
function GetGroundZFor_3dCoord() GroundCalls = GroundCalls + 1; return true, GroundHeight end
function IsPedInAnyVehicle() return InVehicle end
function IsEntityDead() return Dead end
function IsEntityPositionFrozen(ped) return Entities[ped].frozen end
function DoesEntityExist(ped) return Entities[ped] ~= nil end
function RequestModel() end
function HasModelLoaded() return ModelAvailable end
function SetModelAsNoLongerNeeded() end
function CreatePed(kind, model, x, y, z, w, networked, host)
    NextEntity = NextEntity + 1
    Entities[NextEntity] = { model = model, coords = { x = x, y = y, z = z, w = w }, networked = networked, frozen = false }
    CreatedEntities[#CreatedEntities + 1] = NextEntity
    return NextEntity
end
function DeleteEntity(ped) Entities[ped] = nil; DeletedEntities[#DeletedEntities + 1] = ped end
function SetEntityCoordsNoOffset(ped, x, y, z)
    if FailCoordinates then FailCoordinates = false; error('simulated native failure') end
    local c = Entities[ped].coords
    c.x, c.y, c.z = x, y, z
end
function SetEntityHeading(ped, w) Entities[ped].coords.w = w end
function SetEntityInvincible(ped, value) Entities[ped].invincible = value end
function FreezeEntityPosition(ped, value) Entities[ped].frozen = value end
function SetBlockingOfNonTemporaryEvents(ped, value) Entities[ped].blocked = value end
function SetEntityCollision(ped, value) Entities[ped].collision = value end
function SetEntityAlpha(ped, value) Entities[ped].alpha = value end
exports['qb-target'].AddTargetEntity = function(_, ped, options) TargetEntities[ped] = options end
exports['qb-target'].RemoveTargetEntity = function(_, ped) TargetEntities[ped] = nil; RemovedTargets[#RemovedTargets + 1] = ped end
function DisableAllControlActions(group) DisabledGroups[group] = true end
function EnableControlAction(group, control) EnabledControls[control] = true end
function DisableControlAction() end
function IsDisabledControlJustPressed(_, control)
    local pressed = PressedControls[control]
    PressedControls[control] = nil
    return pressed == true
end
function IsDisabledControlPressed(_, control) return HeldControls[control] == true end
function GetGameplayCamRot() return { z = CameraHeading } end
function GetFrameTime() return FrameSeconds end
function Nui(name, data)
    LastNuiResult = nil
    NuiCallbacks[name](data or {}, function(result) LastNuiResult = result end)
    return LastNuiResult
end
function OpenAdmin() Handlers['encontros:client:openAdmin']() end
function Place(coords)
    return Nui('placeRewardNpc', { coords = coords, eventCoords = { x = 9000, y = 9000, z = 0 }, radius = 1, heightTolerance = 1 })
end
function LatestPed() return CreatedEntities[#CreatedEntities] end
function LastCallback(name)
    for index = #CallbackCalls, 1, -1 do if CallbackCalls[index].name == name then return CallbackCalls[index] end end
end
function Press(control) PressedControls[control] = true; Frame(20) end
function AddBlipForCoord(x, y, z)
    local blip = { x = x, y = y, z = z }
    TestBlips[#TestBlips + 1] = blip
    return blip
end
function RemoveBlip(blip) blip.removed = true; RemovedBlips[#RemovedBlips + 1] = blip end
function SetBlipSprite(blip, value) blip.sprite = value end
function SetBlipColour(blip, value) blip.color = value end
function SetBlipScale(blip, value) blip.scale = value end
function SetBlipAsShortRange(blip, value) blip.shortRange = value end
