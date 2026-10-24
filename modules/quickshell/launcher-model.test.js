const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const source = process.argv[2] || path.join(__dirname, 'launcher-model.js');
const model = vm.createContext({});
vm.runInContext(fs.readFileSync(source, 'utf8'), model);
const plain = x => JSON.parse(JSON.stringify(x));
const argv = ['a program', '', '--flag=x y', "'quoted'", '$HOME', '${USER}', '$(touch /tmp/unsafe)', '; echo unsafe', 'a\\b', 'a\nb'];
const meta = {id: '../../Bad id;$', name: 'Example', icon: 'example', kind: 'app'};
assert.deepEqual(plain(model.scopeCommand(argv, meta.id, 'nonce')).slice(-argv.length), argv);
assert(model.scopeCommand(argv, meta.id, 'nonce').includes('--expand-environment=no'));
assert(model.scopeCommand(argv, meta.id, 'nonce').includes('--slice=app.slice'));
assert(model.scopeCommand(argv, meta.id, 'nonce').find(x => x.startsWith('--unit=')).match(/^--unit=app-[a-zA-Z0-9_-]+-nonce$/));
for (const bad of [[], [''], ['x', 1], ['x\0y'], null, 'echo x']) assert.equal(model.validArgv(bad), false);
assert.equal(model.validArgv(argv), true);
for (const input of ['', '{broken', '{}', 'null', '[1,{},null]']) assert.deepEqual(plain(model.readRecent(input)), []);
const repaired = model.record(model.readRecent('{corrupt'), ['repaired'], meta, 99);
assert.deepEqual(plain(model.readRecent(JSON.stringify(repaired))), [{...meta, argv:['repaired'], lastLaunched:99}]);
const first = model.record([], argv, meta, 100);
assert.deepEqual(plain(first), [{...meta, argv, lastLaunched: 100}]);
assert.deepEqual(plain(model.record(first, ['ignored'], {...meta, kind: 'command'}, 101)), plain(first));
let recent = [];
for (let i = 0; i < 15; ++i) recent = model.record(recent, ['app', String(i)], {...meta, id: String(i)}, i + 1);
assert.equal(recent.length, 10);
assert.deepEqual(plain(recent.map(x => x.lastLaunched)), [15,14,13,12,11,10,9,8,7,6]);
recent = model.record(recent, ['app', 'again'], {...meta, id: '10'}, 20);
assert.equal(recent.length, 10);
assert.equal(recent[0].id, '10');
assert.equal(recent.filter(x => x.id === '10').length, 1);
assert.deepEqual(plain(model.readRecent(JSON.stringify(recent.slice().reverse().concat(recent, {id:'bad'})))), plain(recent));
assert.deepEqual(plain(model.entryArgv({command:['app','literal $x']})), ['app','literal $x']);
assert.deepEqual(plain(model.entryArgv({command:['app'], workingDirectory:'/a b', runInTerminal:true})), ['ghostty','-e','env','--chdir=/a b','app']);
const root = process.argv[3] || __dirname;
function scan(dir) {
    for (const item of fs.readdirSync(dir, {withFileTypes:true})) {
        if (item.isDirectory()) { if (!['dev','theme-dev','builder-dev','notification-dev'].includes(item.name)) scan(path.join(dir,item.name)); continue; }
        if (!item.name.endsWith('.qml')) continue;
        const text = fs.readFileSync(path.join(dir,item.name), 'utf8');
        assert(!/\.execute\s*\(/.test(text), `${item.name}: DesktopEntry.execute bypasses Launcher`);
        for (const call of text.matchAll(/Quickshell\.execDetached\s*\(\s*([^;]+)/g)) {
            if (item.name === "Launcher.qml" && call[1].startsWith("Model.scopeCommand(")) continue;
            const literal = call[1].match(/^\["([^"]+)"/);
            assert(literal, `${item.name}: detached argv must go through Launcher`);
            assert(['rm','hyprctl','hypr-zen','hypr-split','hypr-scale','qs','desktop-theme','mountainous-screenshot','notify-send','mountainous-brightness'].includes(literal[1]), `${item.name}: unscoped command ${literal[1]}`);
        }
    }
}
scan(root);
console.log('Launcher argv, recent missing/corrupt/full, DesktopEntry and launch-site checks passed');
