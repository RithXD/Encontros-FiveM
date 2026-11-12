// Self-contained policy checks; installation/catalog integration is separate.
const fs = require('node:fs');
const path = require('node:path');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require(process.env.FENGARI_PATH || 'fengari');
const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
function run(source, name) {
  if (lauxlib.luaL_loadbuffer(L, to_luastring(source), null, to_luastring(name)) !== lua.LUA_OK
      || lua.lua_pcall(L, 0, 0, 0) !== lua.LUA_OK) throw Error(to_jsstring(lua.lua_tostring(L, -1)));
}
run('vector3 = function(x,y,z) return {x=x,y=y,z=z} end; vector4 = function(x,y,z,w) return {x=x,y=y,z=z,w=w} end', '@vectors');
for (const file of ['shared/reward_policy.lua', 'config.lua']) run(fs.readFileSync(path.join(__dirname, '..', file), 'utf8'), '@' + file);
run(`
local P = EncounterRewardPolicy
assert(P.MINIMUM_ATTENDANCE_PERCENT == 60)
assert(P.minimumSeconds(1000,1060) == 36)
assert(P.minimumSeconds(1000,1061) == 37)
assert(P.minimumSeconds(1000,2200) == 720)
assert(P.minimumSeconds(1000,1000) == 1)
assert(P.minimumSeconds(1000,999) == 1)
assert(Config.Blips.resenha.label == 'Resenha')
assert(Config.RewardTables.dinheiro.kind == 'money')
assert(P.validateCatalog(nil, 'dinheiro'))
assert(P.moneyAmount(1) == 1 and P.moneyAmount(1000000) == 1000000)
for _, value in ipairs({0,-1,1.5,1000001,'bad',math.huge,0/0}) do assert(P.moneyAmount(value) == nil) end
assert(P.moneyAmount(nil) == nil)
Config.MoneyReward = {minimum=50,maximum=200,default=100}
local catalog = P.catalog('dinheiro')
assert(catalog.minimum == 50 and catalog.maximum == 200 and catalog.default == 100)
assert(P.moneyAmount(49) == nil and P.moneyAmount(201) == nil)
assert(P.moneyAmount(50) == 50 and P.moneyAmount(200) == 200)
assert(P.draw('dinheiro') == nil and not P.isAllowedItem('dinheiro','cash'))
print('Reward policy passed: real-duration 60% threshold, money limits, Resenha configuration')
`, '@policy');
lua.lua_close(L);
