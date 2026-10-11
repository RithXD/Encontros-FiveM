local function noop() end
function vector4(x, y, z, w) return { x = x, y = y, z = z, w = w } end
Config = {
    RewardClaimNpc = { coords = vector4(0, 0, 0, 0) }, EventAreaRadius = 80, PublicUi = {},
    Blips = { encontro = { sprite = 1, scale = 1, color = 2 }, marcador = { sprite = 2, scale = 1, color = 3 } },
}
local Core = { Functions = {} }
function Core.Functions.TriggerCallback(name, callback)
    if name == 'encontros:server:getActive' then callback(HydratedEvents) else callback({}) end
end
function Core.Functions.Notify(...) Notifications[#Notifications + 1] = { ... } end
exports = setmetatable({ ['qb-core'] = { GetCoreObject = function() return Core end }, ['qb-target'] = {} }, {
    __call = function(_, name, fn) ClientExports[name] = fn end,
})
function ResetClient()
    Now, Focused, Paused, KeyPressed = 10000, false, false, false
    Handlers, NuiCallbacks, ClientExports, Threads, Messages = {}, {}, {}, {}, {}
    HydratedEvents, Notifications, Waypoints, DisabledFrames, FocusChanges = {}, {}, {}, {}, {}
    BootClient()
    Frame(0)
end
function RegisterNetEvent(name, fn) Handlers[name] = fn end
function AddEventHandler(name, fn) Handlers[name] = fn end
function RegisterNUICallback(name, fn) NuiCallbacks[name] = fn end
RegisterCommand, RegisterKeyMapping = noop, noop
function GetHashKey(model) return model end
function TriggerEvent(name, ...) Handlers[name](...) end
function CreateThread(fn) Threads[#Threads + 1] = { co = coroutine.create(fn), wake = Now } end
function Wait(ms) return coroutine.yield(ms) end
function Frame(delta, pressed)
    Now = Now + (delta or 0)
    KeyPressed = pressed == true
    for _, thread in ipairs(Threads) do
        if thread.wake <= Now and coroutine.status(thread.co) ~= 'dead' then
            local ok, delay = coroutine.resume(thread.co)
            assert(ok, delay)
            thread.wake = Now + math.max(delay or 0, 1)
        end
    end
    KeyPressed = false
end
function GetGameTimer() return Now end
function GetCurrentResourceName() return 'Encontrinhos_Pog' end
function SendNUIMessage(message) Messages[#Messages + 1] = message end
function IsNuiFocused() return Focused end
function IsPauseMenuActive() return Paused end
function SetNuiFocus(hasFocus, cursor) FocusChanges[#FocusChanges + 1] = { hasFocus, cursor }; Focused = hasFocus end
function DisableControlAction(group, control, disabled)
    assert(group == 0 and control == 74 and disabled == true)
    DisabledFrames[#DisabledFrames + 1] = Now
end
function IsDisabledControlJustPressed(group, control)
    assert(group == 0 and control == 74)
    local pressed = KeyPressed
    KeyPressed = false
    return pressed
end
function SetNewWaypoint(x, y) Waypoints[#Waypoints + 1] = { x = x, y = y } end
function AddBlipForCoord() return {} end
function AddBlipForRadius() return {} end
RemoveBlip, SetBlipSprite, SetBlipDisplay, SetBlipScale, SetBlipColour = noop, noop, noop, noop, noop
SetBlipAsShortRange, BeginTextCommandSetBlipName, AddTextComponentSubstringPlayerName = noop, noop, noop
EndTextCommandSetBlipName, SetBlipAlpha = noop, noop
function DoesEntityExist() return false end
function Event(id, started, eventType)
    return {
        id = id, started_at = started or 1800000000, status = 'active', event_type = eventType or 'encontro',
        title = 'Encontro ' .. id, location = 'Praça ' .. id, coords = { x = id * 10, y = id * 20, z = 30 },
    }
end
function CountMessages(action)
    local count = 0
    for _, message in ipairs(Messages) do if message.action == action then count = count + 1 end end
    return count
end
function LastMessage(action)
    for index = #Messages, 1, -1 do if Messages[index].action == action then return Messages[index] end end
end
