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
run(read('tests/client_notice_stubs.lua'), '@client_notice_stubs');
run(read('tests/client_npc_stubs.lua'), '@client_npc_stubs');
run('function BootClient()\n' + read('client/main.lua') + '\nend', '@client/main.lua');
run(read('tests/client_npc_assertions.lua'), '@client_npc_assertions');
lua.lua_close(L);
