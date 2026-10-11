-- Fixed performance catalog. A configuration or client payload cannot add prizes.
EncounterRewardPolicy = {}
local Policy = EncounterRewardPolicy
Policy.VERSION = 2
Policy.SAMPLE_SECONDS = 5
Policy.CLAIM_TTL = 86400

local catalogs = {
    pecas_carro = {
        label = 'Performance de Carro', vehicleType = 'car',
        items = {
            'jv_piston_taxado',
            'jv_piston_destaxado',
            'jv_piston_forjado',
            'jv_piston_taxado_forjado',
            'jv_piston_destaxado_competicao',
            'jv_connectingrod_retrabalhada',
            'jv_connectingrod_forjada',
            'jv_connectingrod_h_beam',
            'jv_connectingrod_billet',
            'jv_camshaft_baixa',
            'jv_camshaft_graduado',
            'jv_camshaft_alta',
            'jv_camshaft_competicao',
            'jv_camshaft_drag',
            'jv_sparkplug_brasa_rua',
            'jv_sparkplug_voltix_plus',
            'jv_sparkplug_ignimax_iridium',
            'jv_sparkplug_novapulse_racing',
            'jv_cylinderhead_rebaixado',
            'jv_cylinderhead_retrabalhado',
            'jv_cylinderhead_rebaixado_forjado',
            'jv_cylinderhead_fluxo_competicao',
            'jv_cylinderhead_cnc_drag',
            'jv_engineblock_retrabalhado',
            'jv_engineblock_reforcado',
            'jv_engineblock_titanio',
        },
    },
    pecas_moto = {
        label = 'Performance de Moto', vehicleType = 'motorcycle',
        items = {
            'jv_piston_moto_taxado',
            'jv_piston_moto_destaxado',
            'jv_piston_moto_forjado',
            'jv_piston_moto_taxado_forjado',
            'jv_piston_moto_destaxado_competicao',
            'jv_connectingrod_moto_retrabalhada',
            'jv_connectingrod_moto_forjada',
            'jv_connectingrod_moto_h_beam',
            'jv_connectingrod_moto_billet',
            'jv_camshaft_moto_baixa',
            'jv_camshaft_moto_graduado',
            'jv_camshaft_moto_alta',
            'jv_camshaft_moto_competicao',
            'jv_camshaft_moto_drag',
            'jv_sparkplug_moto_brasa_rua',
            'jv_sparkplug_moto_voltix_plus',
            'jv_sparkplug_moto_ignimax_iridium',
            'jv_sparkplug_moto_novapulse_racing',
            'jv_cylinderhead_moto_rebaixado',
            'jv_cylinderhead_moto_retrabalhado',
            'jv_cylinderhead_moto_rebaixado_forjado',
            'jv_cylinderhead_moto_fluxo_competicao',
            'jv_cylinderhead_moto_cnc_drag',
            'jv_engineblock_moto_retrabalhado',
            'jv_engineblock_moto_reforcado',
            'jv_engineblock_moto_titanio',
        },
    },
}

-- Return fresh tables so UI/config edits cannot mutate the server allowlist.
function Policy.catalog(key)
    local source = catalogs[key]
    if not source then return nil end
    local result = { label = source.label, vehicleType = source.vehicleType, enabled = true, rewards = {} }
    for _, item in ipairs(source.items) do
        result.rewards[#result.rewards + 1] = { item = item, amount = 1, weight = 1 }
    end
    return result
end

function Policy.tables()
    return {
        pecas_carro = Policy.catalog('pecas_carro'),
        pecas_moto = Policy.catalog('pecas_moto'),
        pecas_caminhao = { label = 'Caminhao — bloqueado', enabled = false, rewards = {} },
    }
end

function Policy.isAllowedItem(key, item)
    local catalog = catalogs[key]
    if not catalog or type(item) ~= 'string' then return false end
    for _, allowed in ipairs(catalog.items) do
        if item == allowed then return true end
    end
    return false
end

function Policy.validateCatalog(sharedItems, key)
    if key ~= nil and not catalogs[key] then return false, 'invalid_reward_table' end
    if type(sharedItems) ~= 'table' then return false, 'catalog_unavailable' end
    for tableKey, catalog in pairs(catalogs) do
        if key == nil or tableKey == key then
            for _, item in ipairs(catalog.items) do
                if type(sharedItems[item]) ~= 'table' then return false, 'catalog_item_missing' end
            end
        end
    end
    return true
end

function Policy.draw(key, random)
    local catalog = catalogs[key]
    if not catalog then return nil end
    local index = (random or math.random)(1, #catalog.items)
    if type(index) ~= 'number' or index % 1 ~= 0 or not catalog.items[index] then return nil end
    return { item = catalog.items[index], amount = 1 }
end

function Policy.itemInfo(key)
    local catalog = catalogs[key]
    if not catalog then return nil end
    return { health = 100, quality = 'new', sourceType = 'performance', isPerformance = true, vehicleType = catalog.vehicleType }
end

function Policy.minimumSeconds(startedAt, finishedAt)
    return math.max(1, math.ceil(math.max(0, (tonumber(finishedAt) or 0) - (tonumber(startedAt) or 0)) / 2))
end
