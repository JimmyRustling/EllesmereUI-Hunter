// FHK Gear tests (E1 static + E2 mocked). Run from anywhere: node Interface/AddOns/FHKGear/tests/run.js
// 1. Every Lua file parses as Lua 5.1 and is ASCII-only. 2. tests/gear_test.lua runs under fengari.
const path = require('path'), fs = require('fs'), cp = require('child_process');
const addon = path.resolve(__dirname, '..');
const mods = path.join(process.env.TEMP || '', 'fhk-ellesmere-validation/node_modules');
function need(name) {
  try { return require(name); } catch { return require(path.join(mods, name)); }
}
let cli;
try { cli = require.resolve('fengari-node-cli/src/lua-cli.js'); }
catch { cli = path.join(mods, 'fengari-node-cli/src/lua-cli.js'); }
const luaparse = need('luaparse');
const toc = fs.readFileSync(path.join(addon, 'FHKGear.toc'), 'utf8').split(/\r?\n/).filter(l => l && !l.startsWith('#'));
let files = 0;
for (const rel of toc) {
  const file = path.join(addon, rel.replace(/\\/g, '/'));
  const text = fs.readFileSync(file, 'utf8');
  if (/[^\x00-\x7F]/.test(text)) throw new Error(rel + ': non-ASCII character');
  luaparse.parse(text, { luaVersion: '5.1' });
  if (/\bSetScript\(\s*['"]OnUpdate/.test(text)) throw new Error(rel + ': OnUpdate script (performance rule)');
  files++;
}
const load = 'FHK_TEST_TOC={' + toc.map(p => JSON.stringify(p.replace(/\\/g, '/'))).join(',') + '};dofile("tests/gear_test.lua")';
const r = cp.spawnSync(process.execPath, [cli, '-e', load], { cwd: addon, encoding: 'utf8' });
process.stdout.write(r.stdout || ''); process.stderr.write(r.stderr || '');
if (r.status !== 0 || !/PASS: \d+ gear checks/.test(r.stdout || '')) process.exit(1);
console.log(`PASS: ${files} TOC files parse as Lua 5.1, ASCII only, no OnUpdate`);
