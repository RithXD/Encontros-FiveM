const fs = require('node:fs');
const path = require('node:path');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require(process.env.FENGARI_PATH || 'fengari');
const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
function run(source, name) {
  if (lauxlib.luaL_loadbuffer(L, to_luastring(source), null, to_luastring(name)) !== lua.LUA_OK || lua.lua_pcall(L, 0, 0, 0) !== lua.LUA_OK)
    throw Error(to_jsstring(lua.lua_tostring(L, -1)));
}
const read = file => fs.readFileSync(path.join(__dirname, '..', file), 'utf8');
run(read('tests/server_stubs.lua'), '@server_stubs');
for (const file of ['shared/reward_policy.lua', 'server/attendance.lua', 'server/schema.lua', 'server/locations.lua']) run(read(file), '@' + file);
run('function BootMain()\n' + read('server/main.lua') + '\nend', '@server/main.lua');
lua.lua_pushstring(L, to_luastring(read('config.lua')));
lua.lua_setglobal(L, to_luastring('RealConfigSource'));
run(read('tests/locations_assertions.lua'), '@locations_assertions');
lua.lua_close(L);
