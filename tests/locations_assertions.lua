local function Current() return Invoke('getLocations',1) end
local function Save(entry, original, rev)
    return Invoke('saveLocation',1,{ location=entry, original_key=original, revision=rev or Current().revision })
end
local function Delete(key, rev) return Invoke('deleteLocation',1,{original_key=key, revision=rev or Current().revision}) end
local function Entry(key)
    return {key=key or 'novo',label="Ponto d'agua \\ { } -- [=[texto]=]",coords={x=-50.1234,y=100.9876,z=30.12},
        npc={x=-45.12,y=100.98,z=30.13,w=-90},radius=80.26,heightTolerance=20.16}
end
local function DiskConfig()
    local env={Config={},vector3=vector3,vector4=vector4,EncounterRewardPolicy=EncounterRewardPolicy}
    assert(load(ResourceFiles['config.lua'],'@saved-config.lua','t',env))()
    return env.Config
end

Reset(); Boot()
local initial=ResourceFiles['config.lua']
local initialLayout=EncounterLocations.layout(initial)
local firstOriginal=initial:sub(initialLayout.entries[1].first,initialLayout.entries[1].last)
local secondOriginal=initial:sub(initialLayout.entries[2].first,initialLayout.entries[2].last)
local before=Current()
Check(before.ok); Eq(#before.locations,2); Eq(before.locations[2].key,'pier')
local result=Save(Entry())
Check(result.ok,result.reason); Eq(#result.locations,3); Check(result.revision~=before.revision)
Eq(ResourceFiles['config.lua.locations.bak'],initial,'backup precedes mutation')
Check(ResourceFiles['config.lua']:find(firstOriginal,1,true)); Check(ResourceFiles['config.lua']:find(secondOriginal,1,true))
Check(ResourceFiles['config.lua']:find('-- Example:',1,true)); Check(ResourceFiles['config.lua']:find("Config.Unrelated = 'keep'",1,true))
Check(ResourceFiles['config.lua']:find('        coords = vector3(-50.12, 100.99, 30.12),',1,true))
Check(ResourceFiles['config.lua']:find('        npc = vector4(-45.12, 100.98, 30.13, 270.00),',1,true))
Check(ResourceFiles['config.lua']:find('        radius = 80.3,',1,true))
Eq(DiskConfig().Locations[3].label,Entry().label,'quoted input remains data')
Eq(DiskConfig().Locations[3].coords.x,Config.Locations[3].coords.x,'runtime and disk use same precision')
Eq(Config.Locations[3].npc.w,270)
local events, locations, rev=Invoke('getAll',1)
Eq(#locations,3); Eq(rev,result.revision)
local syncCount=0
for _, notice in ipairs(Notifications) do
    if notice.name=='encontros:client:locationsUpdated' then Eq(notice.source,1,'sync only admins'); syncCount=syncCount+1 end
end
Eq(syncCount,1)

local unchanged=ResourceFiles['config.lua']; local writes=ResourceWrites
Eq(Save(Entry('stale'),nil,before.revision).ok,false,'stale panel cannot overwrite config')
Eq(Save(Entry('pier')).ok,false,'duplicate key rejected')
Eq(Delete('not-found').ok,false)
Eq(ResourceWrites,writes); Eq(ResourceFiles['config.lua'],unchanged)
Eq(Invoke('getLocations',2).ok,false)
Eq(Invoke('saveLocation',2,{location=Entry('hack'),revision=Current().revision}).ok,false)
Eq(Invoke('deleteLocation',2,{original_key='pier',revision=Current().revision}).ok,false)
Eq(ResourceWrites,writes,'unauthorized calls never write files')

-- File persistence is enough to restore the live pool on a resource restart.
Reset(true); Boot(); Eq(#Config.Locations,3); Eq(Current().locations[3].key,'novo')
Check(Delete('praca').ok); Check(Delete('pier').ok)
local created,id=NewEvent({random_location=true})
Check(created); Eq(DB.events[id].location,Entry().label); Eq(DB.events[id].coords_x,-50.12)
Eq(DB.events[id].npc_x,-45.12); Eq(DB.events[id].npc_w,270); Eq(DB.events[id].radius,80.3)
local changed=Entry('renomeado'); changed.label='Local atualizado'; changed.coords.x=200
Check(Save(changed,'novo').ok)
Eq(Config.Locations[1].key,'renomeado'); Eq(DiskConfig().Locations[1].key,'renomeado')
Eq(DB.events[id].coords_x,-50.12,'existing event keeps its own location snapshot')
Eq(DB.events[id].location,Entry().label)
local nextCreated,nextId=NewEvent({random_location=true})
Check(nextCreated); Eq(DB.events[nextId].coords_x,200); Eq(DB.events[nextId].location,'Local atualizado')
Check(Delete('renomeado').ok); Eq(#Config.Locations,0); Eq(#DiskConfig().Locations,0)
Eq(NewEvent({random_location=true}),false,'empty pool blocks random creation')
Check(Save(Entry('primeiro')).ok,'empty literal pool accepts additions')
Eq(#DiskConfig().Locations,1)

-- Manual changes outside this array survive; manual changes inside require reload.
ResourceFiles['config.lua']=ResourceFiles['config.lua']..'\n-- Edited elsewhere: preserve me.\n'
Check(Save(Entry('segundo')).ok)
Check(ResourceFiles['config.lua']:find('-- Edited elsewhere: preserve me.',1,true))
ResourceFiles['config.lua']=ResourceFiles['config.lua']:gsub("key = 'segundo'","key = 'manual'")
writes=ResourceWrites
Eq(Save(Entry('terceiro')).ok,false); Eq(ResourceWrites,writes)
Eq(Config.Locations[2].key,'segundo','refusal cannot change runtime pool')
Reset(true); Boot(); Eq(Config.Locations[2].key,'manual')
Check(Save(Entry('terceiro')).ok)

-- All validation is authoritative on the server, including NaN/infinity.
for _, field in ipairs({'key','label','coords','npc','radius','heightTolerance'}) do
    local invalid=Entry(); invalid[field]=false
    Eq(Save(invalid).ok,false,'invalid '..field)
end
for _, invalid in ipairs({0,-1,1001,math.huge,0/0}) do
    local entry=Entry(); entry.radius=invalid; Eq(Save(entry).ok,false)
end
for _, invalid in ipairs({-1001,10001,math.huge,0/0}) do
    local entry=Entry(); entry.coords.z=invalid; Eq(Save(entry).ok,false)
end
local invalid=Entry(); invalid.label='line\nbreak'; Eq(Save(invalid).ok,false)
invalid=Entry(); invalid.key="x'; os.execute('hack')"; Eq(Save(invalid).ok,false)

-- A failed backup/write never changes the live pool. A partial write is restored.
Reset(); Boot(); initial=ResourceFiles['config.lua']
FailResourceWrite='config.lua.locations.bak'
Eq(Save(Entry()).ok,false); Eq(ResourceFiles['config.lua'],initial); Eq(#Config.Locations,2)
FailResourceWrite='config.lua'
Eq(Save(Entry()).ok,false); Eq(ResourceFiles['config.lua'],initial); Eq(#Config.Locations,2)
FailResourceWrite=nil; CorruptResourceWrite=true
Eq(Save(Entry()).ok,false); Eq(ResourceFiles['config.lua'],initial,'partial write restored from original'); Eq(#Config.Locations,2)
Check(Save(Entry()).ok,'failure can be retried after restoration')

-- Token scanning ignores braces/assignments inside comments and string literals.
local complex=[====[
-- Config.Locations = { ignored }
Config.Other = 'Config.Locations = { fake }'
--[=[ multiline { Config.Locations = { } } ]=]
Config.Locations = {
    { key = 'a', label = "brace } and \\" , coords = vector3(0,0,0), npc = vector4(1,2,3,0) },
    { key = 'b', label = [=[{literal}]=], coords = vector3(0,0,0), npc = vector4(1,2,3,0) },
}
Config.After = { other = 'keep' }
]====]
local layout=EncounterLocations.layout(complex)
Check(layout~=nil); Eq(#layout.entries,2)
Eq(EncounterLocations.layout('Config.Locations = {}\nConfig.Locations = {}'),nil,'multiple assignments rejected')
Eq(EncounterLocations.layout('Config.Locations = buildLocations()'),nil)
Eq(EncounterLocations.layout('Config.Locations = { named = {} }'),nil)
Eq(EncounterLocations.layout("Config.Locations = { {label='unterminated}"),nil)
Eq(EncounterLocations.layout('Config.Locations = { --[=[unterminated'),nil)

-- The project's real configuration keeps every unrelated byte, examples and CRLF.
Reset()
ResourceFiles['config.lua']=RealConfigSource
assert(load(RealConfigSource,'@config.lua','t',_ENV))()
Boot()
local realLayout=EncounterLocations.layout(RealConfigSource)
local prefix,suffix=RealConfigSource:sub(1,realLayout.first-1),RealConfigSource:sub(realLayout.last+1)
local realCount=#Config.Locations
result=Save(Entry('teste-formatacao')); Check(result.ok,result.reason)
Eq(#Config.Locations,realCount+1)
local savedLayout=EncounterLocations.layout(ResourceFiles['config.lua'])
Eq(ResourceFiles['config.lua']:sub(1,savedLayout.first-1),prefix)
Eq(ResourceFiles['config.lua']:sub(savedLayout.last+1),suffix)
Check(ResourceFiles['config.lua']:find('-- Exemplo para adicionar mais locais:',1,true))
Eq(DiskConfig().Locations[realCount+1].key,'teste-formatacao')
Check(Delete('teste-formatacao').ok)
Eq(ResourceFiles['config.lua'],RealConfigSource,'adding and deleting preserves the real original file exactly')

print(('Random locations passed: %d assertions.'):format(Assertions))
