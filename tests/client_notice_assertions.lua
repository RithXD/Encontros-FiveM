local assertions = 0
local function eq(actual, expected, message)
    assertions = assertions + 1
    assert(actual == expected, (message or 'assertion') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end
local function removeSnapshot(id)
    for index = #HydratedEvents, 1, -1 do
        if HydratedEvents[index].id == tonumber(id) then table.remove(HydratedEvents, index) end
    end
end
local function start(event)
    removeSnapshot(event.id)
    if event.status == 'active' then HydratedEvents[#HydratedEvents + 1] = event end
    Handlers['encontros:client:started'](event)
end
local function removed(id)
    removeSnapshot(id)
    Handlers['encontros:client:removed'](id)
end
local function active() return ClientExports.IsStartNoticeActive() end

ResetClient()
eq(active(), false, 'H has no owner before a start')
Frame(1, true)
eq(#Waypoints, 0, 'H before notice is ignored')
start(Event(1))
local shown = LastMessage('showStartNotice').notice
eq(shown.id, '1:1800000000', 'identity contains real activation')
eq(shown.title, 'Encontro 1')
eq(shown.location, 'Praça 1')
eq(shown.durationMs, 10000)
eq(shown.remainingMs, 10000)
eq(shown.marked, false)
eq(active(), true)
eq(#FocusChanges, 0, 'notice never grabs mouse or focus')
eq(#Notifications, 0, 'legacy seven second toast removed')
Frame(9999)
eq(active(), true, 'notice still exists at 9999 ms')
eq(LastMessage('updateStartNotice').notice.remainingMs, 1)
Frame(1, true)
eq(active(), false, 'notice expires exactly at 10000 ms')
eq(CountMessages('hideStartNotice'), 1)
eq(#Waypoints, 0, 'H at expiry cannot route to expired notice')
local disabledAtExpiry = #DisabledFrames
Frame(1, true)
eq(#DisabledFrames, disabledAtExpiry, 'headlight control released after notice')

ResetClient()
start(Event(2))
Frame(1, true)
eq(#Waypoints, 1)
eq(Waypoints[1].x, 20)
eq(Waypoints[1].y, 40)
eq(LastMessage('updateStartNotice').notice.marked, true)
Frame(1, true)
eq(#Waypoints, 1, 'repeated H does not mark twice')
eq(active(), true, 'marked notice retains its original ten second window')
eq(#DisabledFrames, 2, 'headlights disabled each frame, including after marking')
Frame(9998, true)
eq(active(), false)
eq(#Waypoints, 1)

ResetClient()
start(Event(3))
Focused = true
Frame(1, true)
eq(#Waypoints, 0, 'chat or focused NUI consumes H')
Focused = false
Paused = true
Frame(1, true)
eq(#Waypoints, 0, 'pause menu consumes H')
Paused = false
Handlers['encontros:client:openInfo']()
Frame(1, true)
eq(#Waypoints, 0, 'open encounter panel ignores H')
NuiCallbacks.closePanel({}, function() end)
Frame(1, true)
eq(#Waypoints, 1, 'H resumes after closing focused panel')

ResetClient()
start(Event(4))
start(Event(5))
start(Event(4))
local numericStringCopy = Event(4)
numericStringCopy.started_at = '1800000000.0'
start(numericStringCopy)
eq(CountMessages('showStartNotice'), 1, 'queue does not replace current or duplicate it')
Frame(10000)
eq(CountMessages('showStartNotice'), 2, 'second event appears after first expires')
eq(LastMessage('showStartNotice').notice.id, '5:1800000000')
eq(LastMessage('showStartNotice').notice.remainingMs, 10000, 'queued event gets full duration')
Frame(1, true)
eq(Waypoints[1].x, 50, 'H targets currently displayed event only')
Frame(9999)
eq(active(), false)
start(Event(4))
eq(CountMessages('showStartNotice'), 2, 'already displayed activation remains deduplicated')
start(Event(4, 1800000010))
eq(CountMessages('showStartNotice'), 3, 'another actual activation has its own notice')

ResetClient()
start(Event(6))
start(Event(7))
start(Event(8))
removed('7')
eq(CountMessages('showStartNotice'), 1, 'queued cancellation stays invisible')
removed(6)
eq(LastMessage('hideStartNotice').id, '6:1800000000')
eq(LastMessage('showStartNotice').notice.id, '8:1800000000', 'skip canceled queue entry')
Handlers['encontros:client:finished'](Event(8))
eq(active(), false, 'finish removes active notice even before removed event arrives')
Frame(1, true)
eq(#Waypoints, 0, 'finished event cannot be marked')

ResetClient()
start(Event(9, nil, 'marcador'))
eq(CountMessages('showStartNotice'), 0, 'markers do not announce')
local scheduled = Event(10); scheduled.status = 'scheduled'; start(scheduled)
eq(CountMessages('showStartNotice'), 0, 'only confirmed active events announce')
HydratedEvents = { Event(11) }
Frame(2000)
eq(CountMessages('showStartNotice'), 0, 'loading active events never replays old announcements')
eq(active(), false)

ResetClient()
start(Event(18.0, 1800000000.0))
eq(LastMessage('showStartNotice').notice.id, '18:1800000000', 'float payload keeps a canonical NUI identity')
local numericStringIdentity = Event('18', '1800000000.0')
start(numericStringIdentity)
eq(CountMessages('showStartNotice'), 1, 'string and float identities represent the same activation')

ResetClient()
local missingActivation = Event(15); missingActivation.started_at = nil; start(missingActivation)
local nonFiniteActivation = Event(16); nonFiniteActivation.started_at = math.huge; start(nonFiniteActivation)
eq(CountMessages('showStartNotice'), 0, 'malformed activation cannot announce')
local nonFiniteCoords = Event(17); nonFiniteCoords.coords.x = math.huge; start(nonFiniteCoords)
eq(CountMessages('showStartNotice'), 0, 'non-finite waypoint coordinates cannot announce')

ResetClient()
start(Event(12)); start(Event(13))
Handlers.onResourceStop('another-resource')
eq(active(), true)
Handlers.onResourceStop('Encontrinhos_Pog')
eq(active(), false, 'resource stop clears current notice')
Frame(1, true)
eq(#Waypoints, 0)
eq(CountMessages('showStartNotice'), 1, 'resource stop clears queued notices')

ResetClient()
Now = 4294967290.0
start(Event(14))
Frame(9)
eq(active(), true)
-- Simulate a wrapped native clock (fresh worker wake follows the new clock).
Now = 3
for _, thread in ipairs(Threads) do thread.wake = Now end
Frame(9990)
eq(active(), true, 'timer wrap preserves 9999 ms elapsed')
Frame(1)
eq(active(), false, 'timer wrap still expires at ten seconds')

print(('Client start notices: %d assertions passed'):format(assertions))
