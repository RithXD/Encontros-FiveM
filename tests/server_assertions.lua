-- Threshold and final-presence contracts, including exact closing boundaries.
for _, earned in ipairs({29,30,31}) do
    Reset(); Boot()
    local ok, id = NewEvent()
    Check(ok, 'event created')
    for t=1005,1025,5 do Sample(t) end
    Sample(1000 + earned)
    Players[1].coords.x = 100
    Sample(1035)
    Players[1].coords.x = 0
    TestNow = 1060
    Check(Invoke('finish',1,id), 'finish accepts active event')
    Eq(Count(DB.claims), earned >= 30 and 1 or 0, '50 percent threshold')
    Eq(DB.events[id].finished_at,1060,'actual closing persisted')
    if earned >=30 then
        Eq(DB.claims[1].reward_amount,1,'single unit')
        Eq(DB.claims[1].expires_at,1060+86400,'claim expiry anchored to finish')
    end
end

Reset(); Boot()
local ok, id = NewEvent()
for t=1005,1055,5 do Sample(t) end
Players[1].coords.x = 100
TestNow=1060; Check(Invoke('finish',1,id)); Eq(Count(DB.claims),0,'must be inside on final observation')

Reset(); Boot()
ok,id=NewEvent()
for t=1005,1030,5 do Sample(t) end
Players[1].bucket=2
Sample(1035)
TestNow=1060; Check(Invoke('finish',1,id)); Eq(Count(DB.claims),0,'same coordinates other instance ineligible')

-- When enabled, attendance starts only after arriving in an owned car.
Reset(); Boot(); Config.AttendanceVehicle = { required = true, types = { automobile = true }, ownership = { required = true } }
ok,id=NewEvent({duration=2})
Sample(1005); Eq(DB.attendance[id] and DB.attendance[id].test_character_a or 0,0,'arrival on foot is not counted')
Vehicles[10] = { type = 'automobile', plate = 'OTHER1', driver = 1 }; Players[1].vehicle = 10
Sample(1010); Eq(DB.attendance[id] and DB.attendance[id].test_character_a or 0,0,'unowned car is not counted')
DB.ownedVehicles[#DB.ownedVehicles + 1] = { citizenid = 'test_character_a', plate = 'OWN123' }
Vehicles[11] = { type = 'automobile', plate = ' own123 ', driver = 1 }; Players[1].vehicle = 11
Sample(1015); Eq(DB.attendance[id] and DB.attendance[id].test_character_a or 0,0,'first owned-car observation only opens attendance')
Players[1].vehicle = 0
Sample(1020); Eq(DB.attendance[id].test_character_a,5,'parked owned-car arrival keeps counting while inside')
Players[1].coords.x = 100; Sample(1025)
Players[1].coords.x = 0; Sample(1030)
Eq(DB.attendance[id].test_character_a,5,'returning on foot after leaving the area is not counted')

-- Disconnect and same-character logout cannot bridge observed intervals.
Reset(); Boot(); ok,id=NewEvent({duration=2})
Sample(1005); Eq(DB.attendance[id].test_character_a,5)
source=1; Handlers.playerDropped(); Players[1].online=false
Sample(1010); Players[1].online=true; Sample(1015)
Eq(DB.attendance[id].test_character_a,5,'reconnect starts observation without elapsed credit')
Sample(1020); Eq(DB.attendance[id].test_character_a,10)
Handlers['QBCore:Server:OnPlayerUnload'](1)
Sample(1025); Eq(DB.attendance[id].test_character_a,10,'logout same character resets session')
Sample(1030); Eq(DB.attendance[id].test_character_a,15)
Sample(1050); Eq(DB.attendance[id].test_character_a,15,'unobserved scheduling gap excluded')

-- Early finish uses elapsed real duration, not originally planned length.
Reset(); Boot(); ok,id=NewEvent({duration=60})
for t=1005,1600,5 do Sample(t) end
Players[1].coords.x=100; Sample(1605)
Players[1].coords.x=0; TestNow=2200
Check(Invoke('finish',1,id)); Eq(Count(DB.claims),1,'20 minute closure requires 10 accumulated minutes')
Eq(DB.attendance[id].test_character_a,600,'one hour scheduled time does not alter actual threshold')

-- Closure is a single SQL transaction and timers/admin cannot duplicate draws.
Reset(); Boot(); ok,id=NewEvent({recurring=true})
for t=1005,1055,5 do Sample(t) end
local rival
TransactionHook=function()
    rival=coroutine.create(function() Invoke('finish',1,id) end)
    local resumed,reason=coroutine.resume(rival); Check(resumed,reason)
    Eq(coroutine.status(rival),'suspended','concurrent finish waits for lifecycle lock')
end
TestNow=1060; Check(Invoke('finish',1,id))
Check(coroutine.resume(rival)); Eq(Count(DB.claims),1); Eq(Count(DB.events),2,'one next recurrence')
RunTimers(1060); Eq(Count(DB.events),2,'stale timer does not recur again')
local drawn=DB.claims[1].reward_item
Invoke('finish',1,id); Eq(DB.claims[1].reward_item,drawn,'repeated finish never redraws')

-- Failed transaction cannot expose a partially finished event or any reward.
Reset(); Boot(); ok,id=NewEvent()
for t=1005,1055,5 do Sample(t) end
FailTransaction=true; TestNow=1060
Eq(Invoke('finish',1,id),false); Eq(DB.events[id].status,'active'); Eq(Count(DB.claims),0)
Check(Invoke('finish',1,id)); Eq(Count(DB.claims),1)

-- A failed close keeps the original snapshot and draw, even if retries happen
-- after the end and participants leave or a different player enters the area.
Reset(); Boot(); ok,id=NewEvent()
for t=1005,1055,5 do Sample(t) end
local originalDraw=EncounterRewardPolicy.draw
local drawCalls=0
EncounterRewardPolicy.draw=function(...)
    drawCalls=drawCalls+1
    return originalDraw(...)
end
FailTransaction=true; TestNow=1060; Eq(Invoke('finish',1,id),false)
Players[1].coords.x=100; Players[2].coords.x=0
TestNow=1080; Check(Invoke('finish',1,id),'original valid snapshot survives delayed retry')
Eq(drawCalls,1,'SQL retry does not perform another draw')
Eq(DB.claims[1].citizenid,'test_character_a'); Eq(DB.claims[1].drawn_at,1060); Eq(DB.events[id].finished_at,1060)
EncounterRewardPolicy.draw=originalDraw

-- A durable close whose confirming SELECT fails is reconciled and announced.
Reset(); Boot(); ok,id=NewEvent()
for t=1005,1055,5 do Sample(t) end
TransactionHook=function() SingleHook=function() error('simulated response lost') end end
TestNow=1060; Eq(Invoke('finish',1,id),false); Eq(Count(DB.claims),1)
TestNow=1080; Check(Invoke('finish',1,id)); Eq(Count(DB.claims),1)
local winnerNotices=0
for _, notice in ipairs(Notifications) do
    if notice.name=='QBCore:Notify' and tostring(notice.args[1]):find('Voce ganhou',1,true) then winnerNotices=winnerNotices+1 end
end
Eq(winnerNotices,1,'unknown acknowledgement still yields a single winner notification')

-- Failure reading the already-committed recurrence retains closure state for
-- background reconciliation; it cannot swallow the winner notification.
Reset(); Boot(); ok,id=NewEvent({recurring=true})
for t=1005,1055,5 do Sample(t) end
TransactionHook=function()
    SingleHook=function() SingleHook=function() error('simulated recurrence SELECT failure') end end
end
TestNow=1060; Eq(Invoke('finish',1,id),false); Eq(Count(DB.claims),1); Eq(Count(DB.events),2)
Sample(1065)
winnerNotices=0
for _, notice in ipairs(Notifications) do
    if notice.name=='QBCore:Notify' and tostring(notice.args[1]):find('Voce ganhou',1,true) then winnerNotices=winnerNotices+1 end
end
Eq(winnerNotices,1,'background retry announces committed award'); Eq(Count(DB.events),2)

Reset(); Boot(); ok,id=NewEvent()
for t=1005,1055,5 do Sample(t) end
UnknownCommit=true; TestNow=1060
Check(Invoke('finish',1,id),'durably committed unknown result reconciles without retry'); Eq(Count(DB.claims),1)

-- Preserve observed seconds after both definitely failed and unknown SQL writes.
for _, uncertain in ipairs({false,true}) do
    Reset(); Boot(); ok,id=NewEvent()
    Sample(1005)
    if uncertain then UnknownCommit=true else FailTransaction=true end
    Sample(1010)
    Eq(Invoke('getMyAttendance',1)[tostring(id)].seconds,10,'earned observation retained in memory')
    Sample(1015); Sample(1020)
    Eq(DB.attendance[id].test_character_a,15,'absolute retry cannot double count uncertain commit')
end

-- Snapshot positions before waiting for the event row: no late entrant award.
Reset(); Boot(); ok,id=NewEvent()
for t=1005,1030,5 do Sample(t) end
Players[1].coords.x=100; Sample(1035)
SingleHook=function() Players[1].coords.x=0 end
TestNow=1060; Check(Invoke('finish',1,id)); Eq(Count(DB.claims),0,'late arrival during SQL read excluded')

-- Immediate creation uses actual now, reconciles unknown start acknowledgement.
Reset(); Boot(); UnknownStart=true
ok,id=NewEvent({start_time=-9000})
Check(ok); Eq(DB.events[id].started_at,1000); Eq(DB.events[id].start_time,1000)
Eq(#Invoke('getActive',1),1,'unknown activation is hydrated and has a timer')
for t=1005,1055,5 do Sample(t) end
RunTimers(1060); Eq(DB.events[id].status,'finished'); Eq(Count(DB.claims),1)

-- Restart preserves the accumulator but never the last observation.
Reset(); Boot(); ok,id=NewEvent({duration=2})
for t=1005,1030,5 do Sample(t) end
Reset(true); TestNow=1040; Boot(); Sample(1045)
Eq(DB.attendance[id].test_character_a,35,'restart gap excluded, previous accumulation retained')
Reset(true); TestNow=1200; Boot()
Eq(DB.events[id].status,'interrupted'); Eq(Count(DB.claims),0,'outage spanning deadline cannot award based on return position')

-- No manual-finish escape hatch after an unobserved deadline.
Reset(); Boot(); ok,id=NewEvent()
for t=1005,1030,5 do Sample(t) end
TestNow=1080; Check(Invoke('finish',1,id))
Eq(DB.events[id].status,'interrupted'); Eq(Count(DB.claims),0,'manual late finish also interrupts')

-- Hydration can itself cross the deadline while SQL is awaiting results.
Reset(); Boot(); ok,id=NewEvent(); Sample(1005)
Reset(true); TestNow=1059
QueryHook=function(sql)
    if sql:find('SELECT citizenid, seconds',1,true) then TestNow=1061; QueryHook=nil end
end
Boot(); Eq(DB.events[id].status,'interrupted'); Eq(Count(DB.claims),0); Eq(#Invoke('getActive',1),0)

-- Independent SQL workers keep every event on the same observation cadence.
Reset(); Boot()
for n=1,3 do Check(NewEvent()) end
TransactionDelay=true
Sample(1005)
Eq(#Threads,5,'sampler/recovery plus three independent persistence workers')
for worker=3,5 do Eq(coroutine.status(Threads[worker]),'suspended','SQL yields each worker independently') end
TestNow=1008
for worker=3,5 do Check(coroutine.resume(Threads[worker])) end
for eventId=1,3 do Eq(DB.attendance[eventId].test_character_a,5) end
Sample(1010); TestNow=1013
for worker=6,8 do Check(coroutine.resume(Threads[worker])) end
for eventId=1,3 do Eq(DB.attendance[eventId].test_character_a,10,'SQL time of other events does not stretch observation interval') end

-- Capture presence even before waiting on an in-flight sampler transaction.
Reset(); Boot(); ok,id=NewEvent()
for t=1005,1030,5 do Sample(t) end
Players[1].coords.x=100; Sample(1035)
TransactionDelay=true; Sample(1055)
local blockedSampler=Threads[#Threads]
TestNow=1060
local finalizer=coroutine.create(function() Check(Invoke('finish',1,id)) end)
Check(coroutine.resume(finalizer)); Eq(coroutine.status(finalizer),'suspended','finish waits for sample persistence after taking snapshot')
Players[1].coords.x=0; TestNow=1061
TransactionDelay=false
Check(coroutine.resume(blockedSampler)); Check(coroutine.resume(finalizer))
Eq(Count(DB.claims),0,'arrival during sampler SQL wait excluded from final snapshot')

-- Legacy conversion is one-time, category-specific, and preserves history.
Reset()
LegacyEvent(1,'active','pecas_carro')
LegacyEvent(2,'scheduled','pecas_moto')
LegacyEvent(3,'scheduled','pecas_caminhao')
local historic=LegacyEvent(4,'finished','encontro')
historic.reward_custom='historical_custom'; historic.reward_item='historical_item'; historic.status_reason='historical_reason'
LegacyEvent(5,'scheduled','encontro',false).event_type='marcador'
LegacyClaim(1,'pecas_carro'); LegacyClaim(2,'pecas_moto'); LegacyClaim(3,'encontro')
LegacyClaim(4,'pecas_caminhao'); local delivered=LegacyClaim(5,'pecas_carro',true)
Boot()
Eq(DB.events[1].status,'cancelled'); Eq(DB.events[2].status,'scheduled'); Eq(DB.events[2].start_time,2000)
Eq(DB.events[3].status,'blocked'); Eq(DB.events[5].reward_enabled,0)
Eq(historic.reward_custom,'historical_custom'); Eq(historic.reward_item,'historical_item'); Eq(historic.status_reason,'historical_reason')
Eq(DB.claims[1].reward_amount,1); Eq(DB.claims[2].reward_amount,1)
Eq(DB.claims[3].status,'suspended'); Eq(DB.claims[4].status,'suspended')
Eq(delivered.reward_item,'legacy_material'); Eq(delivered.reward_amount,9); Eq(delivered.policy_version,1)
local firstDraw,firstExpiry=DB.claims[1].reward_item,DB.claims[1].expires_at
Reset(true); TestNow=1100; Boot()
Eq(DB.claims[1].reward_item,firstDraw); Eq(DB.claims[1].expires_at,firstExpiry,'migration cannot extend claim deadline')
Eq(#Invoke('getActive',1),0,'cancelled legacy active never exposed after restart')

-- Network forgery cannot introduce catalogs, quantities, items, or custom pools.
Reset(); Boot()
for _, override in ipairs({{reward_table='pecas_caminhao'}, {reward_table='encontro'}, {reward_item='jv_retifica_piston'},
    {reward_custom='[]'}, {reward_amount=4}, {amount=4}, {reward_mode='custom'}, {custom_rewards={{item='metalscrap'}}}}) do
    Eq(NewEvent(override),false,'forged reward rejected')
end
Eq(Count(DB.events),0)
Config.RewardTables={pecas_carro={rewards={{item='metalscrap',amount=99}}}}
ok,id=NewEvent(); Check(ok,'mutable Config cannot override closed policy')
for t=1005,1055,5 do Sample(t) end
TestNow=1060; Check(Invoke('finish',1,id)); Check(EncounterRewardPolicy.isAllowedItem('pecas_carro',DB.claims[1].reward_item))
local missing=EncounterRewardPolicy.catalog('pecas_moto').rewards[1].item
TestCore.Shared.Items[missing]=nil
Eq(NewEvent({reward_table='pecas_moto'}),false,'missing registered item blocks category')

-- List all individually selectable claims; claiming enforces owner/proximity and
-- preserves a pre-drawn item across inventory failures, reconnect and config edits.
Reset(); LegacyClaim(1,'pecas_carro'); LegacyClaim(2,'pecas_moto'); Boot()
local view=Invoke('getRewardClaims',1); Check(view.ok); Eq(#view.claims,2)
Eq(view.claims[1].amount,1); Check(view.claims[1].label and view.claims[1].image)
Eq(Invoke('claimReward',1,1).ok,false,'remote claim blocked'); Eq(BridgeCalls,0)
Players[2].coords.x=200
Eq(Invoke('claimReward',2,1).ok,false,'other character blocked'); Eq(BridgeCalls,0)
Players[1].coords.x=203.001
Eq(Invoke('claimReward',1,1).ok,false,'greater than 3m blocked')
Players[1].coords.x=203
local immutable=DB.claims[1].reward_item
BridgeFailure='inventory_full'; Eq(Invoke('claimReward',1,1).ok,false); Eq(DB.claims[1].claimed,0); Eq(DB.claims[1].reward_item,immutable)
BridgeFailure=nil; BusyInventory=true; Eq(Invoke('claimReward',1,1).ok,false); Eq(InventoryCount,0)
BusyInventory=false; Check(Invoke('claimReward',1,1).ok); Eq(InventoryCount,1)
Eq(Invoke('claimReward',1,1).ok,false,'double click does not duplicate'); Eq(InventoryCount,1)
TestNow=DB.claims[2].expires_at
Eq(Invoke('claimReward',1,2).ok,false,'claim blocked exactly at expiry'); Eq(InventoryCount,1)
view=Invoke('getRewardClaims',1)
Eq(view.claims[1].status,'claimed'); Eq(view.claims[2].status,'expired','expired reward remains visible')
Eq(#Invoke('getRewardClaimNpcs',1),1,'fixed mechanic remains after every pending claim expires or is delivered')
for _, entry in ipairs(Notifications) do
    if entry.name=='qb-inventory:client:ItemBox' then Eq(entry.args[3],1,'actual inventory event with one unit') end
end

-- Every new rewarded meeting needs a validated, server-persisted mechanic pose.
Reset(); Boot()
Check(Invoke('canPlaceNpc',1),'admin allowed to place mechanic')
Eq(Invoke('canPlaceNpc',2),false,'non-admin cannot enter placement through callback')
Players[1].online=false; Eq(Invoke('canPlaceNpc',1),false); Players[1].online=true
for _, position in ipairs({false,{}, {x=0,y=0,z=0}, {x=0,y=0,z=0,w=math.huge},
    {x=20001,y=0,z=0,w=0}, {x=0,y=-20001,z=0,w=0}, {x=0,y=0,z=-1001,w=0},
    {x=0,y=0,z=10001,w=0}, {x='nan',y=0,z=0,w=0}}) do
    Eq(NewEvent({npc_coords=position}),false,'invalid or missing mechanic pose rejected')
end
Eq(Count(DB.events),0,'invalid position never creates an event')
ok,id=NewEvent({npc_coords={x=15,y=2,z=3,w=-90},recurring=true})
Check(ok); Eq(DB.events[id].npc_x,15); Eq(DB.events[id].npc_y,2); Eq(DB.events[id].npc_z,3); Eq(DB.events[id].npc_w,270)
local active=Invoke('getActive',1)
Eq(active[1].npc_coords.x,15); Eq(active[1].npc_coords.w,270,'public event includes mechanic heading')
local npcList, npcServerTime=Invoke('getRewardClaimNpcs',1)
Eq(npcServerTime,1000,'NPC deadlines include the server clock')
Eq(#npcList,2,'fixed and local mechanic exist before any prizes'); Eq(npcList[2].id,id)
Eq(npcList[2].coords.x,15); Eq(npcList[2].routing_bucket,0); Eq(npcList[2].expires_at,1660,'active NPC deadline has scheduled end plus ten minutes')
Eq(npcList[1].id,0); Eq(npcList[1].fixed,true); Eq(npcList[1].expires_at,nil,'permanent mechanic has no timeout')
Players[2].bucket=2; Eq(#Invoke('getRewardClaimNpcs',2),0,'NPC list filters routing bucket')
Players[2].online=false; Eq(#Invoke('getRewardClaimNpcs',2),0,'NPC list authenticated')
for t=1005,1055,5 do Sample(t) end
TestNow=1060; Check(Invoke('finish',1,id))
Eq(DB.events[2].npc_x,15); Eq(DB.events[2].npc_y,2); Eq(DB.events[2].npc_z,3); Eq(DB.events[2].npc_w,270,'recurrence preserves positioned mechanic')
npcList=Invoke('getRewardClaimNpcs',1)
Eq(#npcList,2,'scheduled recurrence has no NPC yet'); Eq(npcList[2].expires_at,1660)
local refreshes=0
for _, entry in ipairs(Notifications) do if entry.name=='encontros:client:refreshClaimNpcs' then refreshes=refreshes+1 end end
Eq(refreshes,2,'start and closure prompt NPC refresh')
TestNow=1660; Eq(#Invoke('getRewardClaimNpcs',1),1,'local NPC disappears exactly at ten minutes')

-- Unrewarded events/markers do not require or retain a mechanic; cancellation
-- and interruptions also remove their unclaimed event NPCs.
Reset(); Boot()
ok,id=NewEvent({reward_enabled=false,npc_coords=false}); Check(ok); Eq(DB.events[id].npc_x,nil)
ok,id=NewEvent({event_type='marcador',npc_coords=false}); Check(ok); Eq(DB.events[id].reward_enabled,0)
Eq(#Invoke('getRewardClaimNpcs',1),1)
ok,id=NewEvent(); Check(ok); Eq(#Invoke('getRewardClaimNpcs',1),2)
Check(Invoke('delete',1,id)); Eq(#Invoke('getRewardClaimNpcs',1),1,'cancelled mechanic removed')
ok,id=NewEvent(); TestNow=1080; Check(Invoke('finish',1,id)); Eq(DB.events[id].status,'interrupted')
Eq(#Invoke('getRewardClaimNpcs',1),1,'interrupted mechanic removed')

-- NPC context selects only that meeting's prizes; a claim's location is always
-- resolved by its stored event, never by context/item/quantity from the client.
Reset(); LegacyClaim(10,'pecas_carro'); Boot()
ok,id=NewEvent({npc_coords={x=10,y=0,z=0,w=0}})
local secondId
ok,secondId=NewEvent({npc_coords={x=20,y=0,z=0,w=180}})
for t=1005,1055,5 do Sample(t) end
TestNow=1060; Check(Invoke('finish',1,id)); Check(Invoke('finish',1,secondId))
Eq(#Invoke('getRewardClaims',1).claims,3,'global authenticated query remains compatible')
local firstContext=Invoke('getRewardClaims',1,id)
Eq(#firstContext.claims,1); Eq(firstContext.claims[1].event_id,id); Eq(firstContext.claims[1].npc_coords.x,10)
local firstClaim=firstContext.claims[1].id
Eq(#Invoke('getRewardClaims',1,secondId).claims,1)
Eq(#Invoke('getRewardClaims',1,0).claims,1,'legacy context excludes new local NPC prizes')
Eq(#Invoke('getRewardClaims',2,id).claims,0,'context cannot expose another character prize')
Eq(Invoke('getRewardClaims',1,-1).ok,false); Eq(Invoke('getRewardClaims',1,1.5).ok,false)
Players[1].coords.x=200; Eq(Invoke('claimReward',1,firstClaim).ok,false,'fixed legacy NPC cannot claim new event prize')
Players[1].coords.x=20; Eq(Invoke('claimReward',1,firstClaim).ok,false,'different meeting NPC cannot claim this prize')
Players[1].coords.x=13.001; Eq(Invoke('claimReward',1,firstClaim).ok,false,'local NPC range greater than 3m rejected')
Players[1].coords.x=13; Players[1].bucket=1
Eq(Invoke('claimReward',1,firstClaim).ok,false,'same NPC coordinates wrong bucket rejected')
Players[1].bucket=0
BridgeBeforeValidate=function() Players[1].coords.x=200 end
Eq(Invoke('claimReward',1,firstClaim).ok,false,'transaction validation rechecks actual NPC proximity')
Eq(InventoryCount,0)
BridgeBeforeValidate=nil; Players[1].coords.x=13
Check(Invoke('claimReward',1,firstClaim).ok,'3m inclusive local NPC boundary'); Eq(InventoryCount,1)
Players[1].coords.x=200; Check(Invoke('claimReward',1,10).ok,'legacy orphan prize still uses fixed NPC'); Eq(InventoryCount,2)

-- Historical deadlines never retain an encounter mechanic. Missing closing
-- timestamps and expired local windows move the same reward to the fixed NPC.
for _, finish in ipairs({false,-100000}) do
    Reset()
    local old=LegacyEvent(1,'finished','pecas_carro')
    old.npc_x,old.npc_y,old.npc_z,old.npc_w=30,0,0,45
    if finish then old.finished_at=finish end
    LegacyClaim(1,'pecas_carro'); Boot()
    npcList=Invoke('getRewardClaimNpcs',1)
    Eq(#npcList,1); Eq(npcList[1].id,0); Eq(npcList[1].coords.x,200)
    Eq(npcList[1].expires_at,nil,'converted reward cannot extend any NPC deadline')
    Eq(#Invoke('getRewardClaims',1,0).claims,1,'historical prize appears at permanent mechanic')
    Eq(#Invoke('getRewardClaims',1,1).claims,0,'historical local mechanic has no pickup context')
    Players[1].coords.x=30; Eq(Invoke('claimReward',1,1).ok,false)
    Players[1].coords.x=200; Check(Invoke('claimReward',1,1).ok)
    Eq(#Invoke('getRewardClaimNpcs',1),1,'delivered legacy prize does not remove permanent mechanic')
end

Reset(); LegacyClaim(1,'pecas_carro'); Boot()
npcList=Invoke('getRewardClaimNpcs',1)
Eq(#npcList,1); Eq(npcList[1].id,0); Eq(npcList[1].fixed,true); Eq(npcList[1].coords.x,200)
Eq(#Invoke('getRewardClaimNpcs',2),1,'permanent mechanic visible even without a pending prize')
TestNow=DB.claims[1].expires_at; Eq(#Invoke('getRewardClaimNpcs',1),1,'claim expiry does not remove permanent mechanic')

-- Handoff is exclusive and exact: 599 seconds still local; at 600 and 601,
-- collection is only at the permanent mechanic, with the original 24h expiry.
for _, elapsed in ipairs({599,600,601}) do
    Reset(); Boot(); ok,id=NewEvent()
    for t=1005,1055,5 do Sample(t) end
    TestNow=1060; Check(Invoke('finish',1,id))
    local originalItem, originalExpiry, originalDrawn = DB.claims[1].reward_item, DB.claims[1].expires_at, DB.claims[1].drawn_at
    TestNow=1060+elapsed
    local localPickup=elapsed<600
    npcList,npcServerTime=Invoke('getRewardClaimNpcs',1)
    Eq(npcServerTime,TestNow); Eq(#npcList,localPickup and 2 or 1,'exact NPC lifetime')
    local atLocal,atFixed=Invoke('getRewardClaims',1,id),Invoke('getRewardClaims',1,0)
    Eq(#atLocal.claims,localPickup and 1 or 0); Eq(#atFixed.claims,localPickup and 0 or 1)
    Eq(atLocal.pickup_kind,'event'); Eq(atFixed.pickup_kind,'fixed'); Eq(atFixed.fixed_npc_coords.x,200)
    local globalView=Invoke('getRewardClaims',1)
    Eq(#globalView.claims,1); Eq(globalView.claims[1].pickup_kind,localPickup and 'event' or 'fixed')
    Players[1].coords.x=localPickup and 200 or 10
    Eq(Invoke('claimReward',1,1).ok,false,'wrong phase mechanic denied')
    Players[1].coords.x=localPickup and 10 or 200
    Check(Invoke('claimReward',1,1).ok,'correct phase mechanic accepted')
    Eq(DB.claims[1].reward_item,originalItem); Eq(DB.claims[1].expires_at,originalExpiry); Eq(DB.claims[1].drawn_at,originalDrawn)
    Eq(InventoryCount,1)
end

-- Restart derives the handoff from persisted finish time, never from loading
-- time, and cannot re-open the local window or refresh the reward deadline.
for _, restartedAt in ipairs({1659,1660,1661}) do
    Reset(); Boot(); ok,id=NewEvent()
    for t=1005,1055,5 do Sample(t) end
    TestNow=1060; Check(Invoke('finish',1,id))
    local reward,expiry=DB.claims[1].reward_item,DB.claims[1].expires_at
    Reset(true); TestNow=restartedAt; Boot()
    Eq(#Invoke('getRewardClaimNpcs',1),restartedAt<1660 and 2 or 1)
    Eq(#Invoke('getRewardClaims',1,0).claims,restartedAt<1660 and 0 or 1)
    Eq(DB.claims[1].reward_item,reward); Eq(DB.claims[1].expires_at,expiry)
end

-- The local cutoff follows real early closure, not the original planned end.
Reset(); Boot(); ok,id=NewEvent({duration=60})
for t=1005,1030,5 do Sample(t) end
TestNow=1030; Check(Invoke('finish',1,id))
npcList=Invoke('getRewardClaimNpcs',1); Eq(npcList[2].expires_at,1630)
TestNow=1630; Eq(#Invoke('getRewardClaimNpcs',1),1); Eq(#Invoke('getRewardClaims',1,0).claims,1)

-- Different encounter windows stay independent; every bucket moves to the
-- fixed NPC's own bucket once its local ten-minute window ends.
Reset(); Boot(); Players[1].bucket=2; ok,id=NewEvent()
Players[1].bucket=0; ok,secondId=NewEvent({duration=2})
for t=1005,1055,5 do
    Players[1].bucket=2; Sample(t)
end
TestNow=1060; Check(Invoke('finish',1,id))
Players[1].bucket=0; Sample(1060)
for t=1065,1115,5 do Sample(t) end
TestNow=1120; Check(Invoke('finish',1,secondId))
TestNow=1660
Eq(#Invoke('getRewardClaims',1,0).claims,1,'only first encounter moved to fixed NPC')
Eq(#Invoke('getRewardClaims',1,secondId).claims,1,'second encounter retains its own local window')
Players[1].coords.x=200; Players[1].bucket=2
Eq(Invoke('claimReward',1,1).ok,false,'fixed position in original event bucket rejected')
Eq(#Invoke('getRewardClaimNpcs',1),0,'fixed mechanic only exists in configured bucket')
Players[1].bucket=0; Check(Invoke('claimReward',1,1).ok,'event from another bucket can move to fixed mechanic')
TestNow=1720; Eq(#Invoke('getRewardClaims',1,secondId).claims,0)
Check(Invoke('claimReward',1,2).ok); Eq(InventoryCount,2)

-- A transaction that starts locally before the cutoff must re-check the
-- clock immediately before delivery. A failed attempt never changes the item.
Reset(); Boot(); ok,id=NewEvent()
for t=1005,1055,5 do Sample(t) end
TestNow=1060; Check(Invoke('finish',1,id))
local handoffItem,handoffExpiry=DB.claims[1].reward_item,DB.claims[1].expires_at
TestNow=1659; Players[1].coords.x=10
BridgeBeforeValidate=function() TestNow=1660 end
Eq(Invoke('claimReward',1,1).ok,false,'transaction crossing local cutoff cannot deliver remotely')
Eq(DB.claims[1].claimed,0); Eq(DB.claims[1].reward_item,handoffItem); Eq(DB.claims[1].expires_at,handoffExpiry)
BridgeBeforeValidate=nil; Players[1].coords.x=200
BridgeFailure='inventory_full'; Eq(Invoke('claimReward',1,1).ok,false); Eq(DB.claims[1].claimed,0)
BridgeFailure=nil; TestNow=handoffExpiry-1
BridgeBeforeValidate=function() TestNow=handoffExpiry end
Eq(Invoke('claimReward',1,1).ok,false,'transaction crossing total 24h expiry remains blocked')
Eq(InventoryCount,0); Eq(Invoke('getRewardClaims',1,0).claims[1].status,'expired')

-- Missing historic poses use the fixed NPC. A corrupt partial pose cannot
-- redirect a just-finished reward early, but is harmless after the cutoff.
Reset(); Boot(); ok,id=NewEvent()
for t=1005,1055,5 do Sample(t) end
TestNow=1060; Check(Invoke('finish',1,id))
DB.events[id].npc_y=nil
Players[1].coords.x=200; Eq(Invoke('claimReward',1,1).ok,false,'corrupt pose fails closed before handoff')
Eq(#Invoke('getRewardClaims',1,0).claims,0)
TestNow=1660; Check(Invoke('claimReward',1,1).ok,'after handoff historical pose no longer controls collection')

-- A delayed query must not publish an already-expired local mechanic/context.
Reset(); Boot(); ok,id=NewEvent()
for t=1005,1055,5 do Sample(t) end
TestNow=1060; Check(Invoke('finish',1,id))
TestNow=1560; QueryHook=function() TestNow=1570; QueryHook=nil end
npcList,npcServerTime=Invoke('getRewardClaimNpcs',1)
Eq(#npcList,2); Eq(npcServerTime,1560,'NPC clock is anchored before SQL wait')
Eq(npcList[2].expires_at,1660,'delayed query preserves the persisted deadline')
Eq(1560+(npcList[2].expires_at-npcServerTime),1660,'request clock subtracts SQL latency exactly once')
TestNow=1659; QueryHook=function() TestNow=1660; QueryHook=nil end
npcList,npcServerTime=Invoke('getRewardClaimNpcs',1); Eq(#npcList,1); Eq(npcServerTime,1659)
TestNow=1659; QueryHook=function() TestNow=1660; QueryHook=nil end
Eq(#Invoke('getRewardClaims',1,id).claims,0,'SQL latency cannot reopen local pickup')

print(('Server lifecycle tests passed: %d assertions.'):format(Assertions))
