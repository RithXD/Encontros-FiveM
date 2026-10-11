// Offline contract with the real inventory definitions and retifica catalog.
const fs = require('node:fs');
const path = require('node:path');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require(process.env.FENGARI_PATH || 'fengari');
const root = path.resolve(__dirname, '..');
const resources = path.resolve(root, '../..');
const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
function run(source, name) {
  if (lauxlib.luaL_loadbuffer(L, to_luastring(source), null, to_luastring(name)) !== lua.LUA_OK
      || lua.lua_pcall(L, 0, 0, 0) !== lua.LUA_OK) {
    throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
  }
}
run(`QBCore = {Shared = {}}; vector3 = function(x,y,z) return {x=x,y=y,z=z} end
vector4 = function(x,y,z,w) return {x=x,y=y,z=z,w=w} end`, '@boundaries');
for (const file of [
  path.join(root, 'shared/reward_policy.lua'),
  path.join(root, 'config.lua'),
  path.join(resources, '[qb]/qb-core/shared/items.lua'),
  path.join(resources, '[jvscripts]/jv-retifica/config.lua'),
]) run(fs.readFileSync(file, 'utf8'), '@' + file);
run(`
local P = EncounterRewardPolicy
assert(P.VERSION == 2 and P.CLAIM_TTL == 24 * 60 * 60)
assert(P.validateCatalog(QBCore.Shared.Items))
local retifica = Config.Retifica.EngineRemoval.PerformanceItems
local installation = {}
for category, variants in pairs(retifica.Options) do
  for _, variant in ipairs(variants) do
    installation[retifica.ItemPrefix .. retifica.CategoryItemPrefixes[category] .. '_' .. variant] = true
  end
end
local seen, count = {}, 0
for _, key in ipairs({'pecas_carro', 'pecas_moto'}) do
  local catalog = P.catalog(key)
  assert(#catalog.rewards == 26)
  for i, entry in ipairs(catalog.rewards) do
    assert(not seen[entry.item], 'duplicate catalog item')
    seen[entry.item], count = true, count + 1
    assert(entry.amount == 1 and entry.weight == 1)
    assert(installation[entry.item], 'reward cannot be installed through retifica')
    assert(QBCore.Shared.Items[entry.item].name == entry.item)
    assert(P.isAllowedItem(key, entry.item))
    assert(not P.isAllowedItem(key == 'pecas_carro' and 'pecas_moto' or 'pecas_carro', entry.item))
    local reward = P.draw(key, function(first, last)
      assert(first == 1 and last == 26, 'draw must be uniform across all 26 entries')
      return i
    end)
    assert(reward.item == entry.item and reward.amount == 1)
  end
  local info = P.itemInfo(key)
  assert(info.health == 100 and info.quality == 'new' and info.sourceType == 'performance')
  assert(info.isPerformance and info.quantity == nil and info.quantityTotal == nil)
  assert(info.vehicleType == (key == 'pecas_carro' and 'car' or 'motorcycle'))
  -- Copies exposed to configuration/UI must not affect authoritative draws.
  catalog.rewards[1].item, catalog.rewards[1].amount = 'water_bottle', 4
  assert(P.draw(key, function() return 1 end).item ~= 'water_bottle')
end
assert(count == 52)
for _, key in ipairs({'pecas_caminhao', 'encontro', 'custom', '', 'PECAS_CARRO'}) do
  assert(P.catalog(key) == nil and P.draw(key) == nil and P.itemInfo(key) == nil)
  assert(not P.validateCatalog(QBCore.Shared.Items, key))
end
for _, item in ipairs({'jv_retifica_piston','jv_piston_original','jv_piston_truck_forjado',
  'jv_piston_not_real','jv_turbo_t4236','metalscrap','event_ticket','water_bottle'}) do
  assert(not P.isAllowedItem('pecas_carro', item) and not P.isAllowedItem('pecas_moto', item))
end
assert(P.tables().pecas_caminhao.enabled == false)
QBCore.Shared.Items.jv_piston_forjado = nil
assert(not P.validateCatalog(QBCore.Shared.Items, 'pecas_carro'))
assert(P.validateCatalog(QBCore.Shared.Items, 'pecas_moto'))
assert(not P.validateCatalog(QBCore.Shared.Items))
assert(P.minimumSeconds(100,1300) == 600)
assert(P.minimumSeconds(100,101) == 1)
assert(P.minimumSeconds(100,103) == 2)
assert(P.minimumSeconds(100,100) == 1)
assert(P.minimumSeconds(100,99) == 1)
print('PASS catalog: 52 registered/installable items; fixed quantities, uniform draw, blocked alternatives and thresholds')
`, '@catalog-contracts');
lua.lua_close(L);
