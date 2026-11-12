-- Edit only the literal Config.Locations array. Never execute submitted Lua.
EncounterLocations = {}
local Locations = EncounterLocations
local loadedBlock, revision, sequence = nil, nil, 0

local function tokens(source)
    local result, i = {}, 1
    local function longEnd(at)
        local equals = source:sub(at):match('^%[(=*)%[')
        if equals == nil then return nil end
        local _, finish = source:find(']' .. equals .. ']', at + #equals + 2, true)
        return finish or false
    end
    while i <= #source do
        local c, first = source:sub(i, i), i
        if c:match('%s') then i = i + 1
        elseif source:sub(i, i + 1) == '--' then
            local finish = longEnd(i + 2)
            if finish == false then return nil end
            i = finish and finish + 1 or (source:find('\n', i + 2, true) or (#source + 1))
        elseif c == "'" or c == '"' then
            i = i + 1
            while i <= #source and source:sub(i, i) ~= c do
                i = i + (source:sub(i, i) == '\\' and 2 or 1)
            end
            if i > #source then return nil end
            i = i + 1
            result[#result + 1] = { text = source:sub(first, i - 1), first = first, last = i - 1 }
        else
            local finish = longEnd(i)
            if finish == false then return nil end
            if finish then i = finish + 1
            elseif c:match('[%a_]') then
                i = i + 1
                while source:sub(i, i):match('[%w_]') do i = i + 1 end
            else i = i + 1 end
            result[#result + 1] = { text = source:sub(first, i - 1), first = first, last = i - 1 }
        end
    end
    return result
end

function Locations.layout(source)
    if type(source) ~= 'string' then return nil end
    local ts = tokens(source)
    if not ts then return nil end
    local begin
    for i = 1, #ts - 4 do
        if ts[i].text == 'Config' and ts[i + 1].text == '.' and ts[i + 2].text == 'Locations' and ts[i + 3].text == '=' then
            if begin or ts[i + 4].text ~= '{' then return nil end
            begin = i + 4
        end
    end
    if not begin then return nil end
    local depth, entries, entryStart = 1, {}, nil
    for i = begin + 1, #ts do
        local t = ts[i]
        if t.text == '{' then
            if depth == 1 then entryStart = t.first end
            depth = depth + 1
        elseif t.text == '}' then
            depth = depth - 1
            if depth == 0 then
                return { first = ts[begin].first, last = t.last, entries = entries }
            elseif depth == 1 then
                local last = t.last
                if ts[i + 1] and (ts[i + 1].text == ',' or ts[i + 1].text == ';') then last = ts[i + 1].last end
                entries[#entries + 1] = { first = entryStart, last = last }
            end
        elseif depth == 1 and t.text ~= ',' and t.text ~= ';' then
            return nil -- Computed tables/assignments need a manual edit, not a rewrite.
        end
    end
    return nil
end

local function block(source, layout) return source:sub(layout.first, layout.last) end
function Locations.initialize()
    local source = LoadResourceFile(GetCurrentResourceName(), 'config.lua')
    local layout = Locations.layout(source)
    loadedBlock = layout and block(source, layout) or nil
    sequence = sequence + 1
    revision = ('%s:%s:%s'):format(os.time(), math.random(100000, 999999), sequence)
end

local function number(value, minimum, maximum, decimals)
    local n = tonumber(value)
    if not n or n ~= n or n < minimum or n > maximum then return nil end
    return tonumber(('%.' .. decimals .. 'f'):format(n))
end
function Locations.validate(data)
    if type(data) ~= 'table' then return nil, 'Local invalido.' end
    local key, label = tostring(data.key or ''), tostring(data.label or '')
    key, label = key:match('^%s*(.-)%s*$'), label:match('^%s*(.-)%s*$')
    if key == '' or #key > 100 or not key:match('^[%w_%- ]+$') then return nil, 'Use uma chave de ate 100 caracteres: letras, numeros, espacos, _ ou -.' end
    if label == '' or #label > 100 or label:find('%c') then return nil, 'Informe um nome de ate 100 caracteres, sem quebras de linha.' end
    local c = type(data.coords) == 'table' and data.coords or {}
    local p = type(data.npc) == 'table' and data.npc or {}
    local x, y, z = number(c.x, -20000, 20000, 2), number(c.y, -20000, 20000, 2), number(c.z, -1000, 10000, 2)
    local nx, ny, nz, heading = number(p.x, -20000, 20000, 2), number(p.y, -20000, 20000, 2), number(p.z, -1000, 10000, 2), number(p.w, -360000, 360000, 2)
    if not x or not y or not z then return nil, 'Informe um vector3 valido para o centro do evento.' end
    if not nx or not ny or not nz or not heading then return nil, 'Informe um vector4 valido para o NPC.' end
    local radius, height = number(data.radius, 1, 1000, 1), number(data.heightTolerance, 1, 500, 1)
    if not radius or not height then return nil, 'Raio: 1 a 1000 m. Altura: 1 a 500 m.' end
    return { key = key, label = label, coords = { x = x, y = y, z = z },
        npc = { x = nx, y = ny, z = nz, w = heading % 360 }, radius = radius, heightTolerance = height }
end

function Locations.list()
    local entries = {}
    for _, entry in ipairs(Config.Locations or {}) do
        local c, p = entry.coords or {}, entry.npc or entry.npc_coords or entry.rewardNpc or {}
        entries[#entries + 1] = { key = entry.key, label = entry.label,
            coords = { x = c.x or c[1], y = c.y or c[2], z = c.z or c[3] },
            npc = { x = p.x or p[1], y = p.y or p[2], z = p.z or p[3], w = p.w or p[4] or p.heading or 0 },
            radius = entry.radius or Config.EventAreaRadius,
            heightTolerance = entry.heightTolerance or entry.height_tolerance or Config.EventHeightTolerance }
    end
    return entries, revision
end

local function quoted(value) return "'" .. value:gsub('\\', '\\\\'):gsub("'", "\\'") .. "'" end
local function render(entry, indent, newline)
    local child = indent .. (indent:find('\t', 1, true) and '\t' or '    ')
    return table.concat({ indent .. '{',
        child .. 'key = ' .. quoted(entry.key) .. ',',
        child .. 'label = ' .. quoted(entry.label) .. ',',
        child .. ('coords = vector3(%.2f, %.2f, %.2f),'):format(entry.coords.x, entry.coords.y, entry.coords.z),
        child .. ('npc = vector4(%.2f, %.2f, %.2f, %.2f),'):format(entry.npc.x, entry.npc.y, entry.npc.z, entry.npc.w),
        child .. ('radius = %.1f,'):format(entry.radius),
        child .. ('heightTolerance = %.1f,'):format(entry.heightTolerance), indent .. '},' }, newline) .. newline
end

local function lineRange(source, span)
    local first = span.first
    while first > 1 and source:sub(first - 1, first - 1):match('[ \t]') do first = first - 1 end
    -- Only consume the entry's own newline, never the next comment or field.
    local last = span.last
    local tail = source:sub(last + 1):match('^[ \t]*\r?\n')
    if tail then last = last + #tail end
    return first, last, source:sub(first, span.first - 1)
end

function Locations.save(data, originalKey, expectedRevision, removing)
    if expectedRevision ~= revision then return false, 'A lista mudou. Atualize os locais antes de salvar.' end
    local resource = GetCurrentResourceName()
    local source = LoadResourceFile(resource, 'config.lua')
    local layout = Locations.layout(source)
    if not loadedBlock or not layout or block(source, layout) ~= loadedBlock then
        return false, 'Config.Locations foi alterado fora do painel ou nao usa uma lista literal. Reinicie o recurso apos revisar o arquivo.'
    end
    local entries = Locations.list()
    if #layout.entries ~= #entries then return false, 'Formato de Config.Locations incompativel. Revise o arquivo e reinicie o recurso.' end
    local found
    for i, entry in ipairs(entries) do
        if entry.key == originalKey then
            if found then return false, 'Existem chaves duplicadas em Config.Locations. Corrija o arquivo.' end
            found = i
        end
    end
    if originalKey ~= nil and not found then return false, 'Local nao encontrado. Atualize a lista.' end
    local entry, reason
    if not removing then
        entry, reason = Locations.validate(data)
        if not entry then return false, reason end
        for i, existing in ipairs(entries) do
            if i ~= found and existing.key == entry.key then return false, 'Ja existe um local com essa chave.' end
        end
    elseif not found then return false, 'Selecione o local a remover.' end
    local newline = source:find('\r\n', 1, true) and '\r\n' or '\n'
    local first, last, indent
    if found then first, last, indent = lineRange(source, layout.entries[found])
    elseif #layout.entries > 0 then
        local previousFirst
        previousFirst, last, indent = lineRange(source, layout.entries[#layout.entries])
        first, last = last + 1, last
    else first, last, indent = layout.first + 1, layout.first, '    ' end
    if indent == '' then indent = '    ' end
    local replacement = removing and '' or render(entry, indent, newline)
    if not found and (first == layout.first + 1 or source:sub(first - 1, first - 1) ~= '\n') then replacement = newline .. replacement end
    if not found and #layout.entries > 0 then
        local previous = layout.entries[#layout.entries]
        local separator = source:sub(previous.last, previous.last)
        if separator ~= ',' and separator ~= ';' then
            return false, 'Adicione uma virgula apos o ultimo local em Config.Locations e reinicie o recurso.'
        end
    end
    local candidate = source:sub(1, first - 1) .. replacement .. source:sub(last + 1)
    local updatedLayout = Locations.layout(candidate)
    if not updatedLayout or not load(candidate, '@config.lua', 't', {}) then return false, 'Nao foi possivel gerar um config.lua valido.' end
    -- File natives are synchronous: no other panel can interleave this mutation.
    local backupOk = SaveResourceFile(resource, 'config.lua.locations.bak', source, #source)
    if not backupOk or LoadResourceFile(resource, 'config.lua.locations.bak') ~= source then return false, 'Nao foi possivel criar a copia de seguranca. Confira as permissoes do recurso.' end
    SaveResourceFile(resource, 'config.lua', candidate, #candidate)
    if LoadResourceFile(resource, 'config.lua') ~= candidate then
        SaveResourceFile(resource, 'config.lua', source, #source)
        return false, 'Falha ao gravar config.lua. A copia anterior esta em config.lua.locations.bak.'
    end
    if removing then table.remove(Config.Locations, found)
    else
        Config.Locations[found or (#Config.Locations + 1)] = { key = entry.key, label = entry.label,
            coords = vector3(entry.coords.x, entry.coords.y, entry.coords.z), npc = vector4(entry.npc.x, entry.npc.y, entry.npc.z, entry.npc.w),
            radius = entry.radius, heightTolerance = entry.heightTolerance }
    end
    loadedBlock = block(candidate, updatedLayout)
    sequence = sequence + 1
    revision = ('%s:%s:%s'):format(os.time(), math.random(100000, 999999), sequence)
    return true
end
