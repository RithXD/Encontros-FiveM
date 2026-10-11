-- No client time or position is accepted. Only two consecutive server observations
-- from the same connected session can contribute time; observations are not restored.
EncounterAttendance = {}

function EncounterAttendance.observe(previous, present, now, startedAt, endsAt)
    local nextState = {}
    local sampleLimit = EncounterRewardPolicy.SAMPLE_SECONDS + 2
    now = math.min(now, endsAt)
    for citizenid, record in pairs(previous or {}) do
        nextState[citizenid] = { seconds = record.seconds or 0 }
    end
    for citizenid, session in pairs(present or {}) do
        local old = previous and previous[citizenid]
        local record = nextState[citizenid] or { seconds = 0 }
        if old and old.observed_at and old.source == session.source and old.session == session.session then
            local elapsed = now - math.max(old.observed_at, startedAt)
            if elapsed > 0 and elapsed <= sampleLimit then record.seconds = record.seconds + elapsed end
        end
        record.observed_at, record.source, record.session = now, session.source, session.session
        nextState[citizenid] = record
    end
    return nextState
end

function EncounterAttendance.disconnect(states, playerId)
    for _, attendance in pairs(states) do
        for _, record in pairs(attendance) do
            if record.source == playerId then
                record.source, record.session, record.observed_at = nil, nil, nil
            end
        end
    end
end
