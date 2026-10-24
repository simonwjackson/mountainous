const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const {spawnSync} = require("node:child_process");
const helper = process.argv[2] || __dirname + "/beszel-status.sh";
const directory = fs.mkdtempSync(path.join(os.tmpdir(), "beszel-status-test-"));
try {
    const token = path.join(directory, "token");
    const called = path.join(directory, "called");
    fs.writeFileSync(token, "test-only-credential\n", {mode: 0o600});
    // A configured curl process makes all tests offline, including the missing
    // credential path. Assert the real helper's request and credential boundary.
    fs.writeFileSync(path.join(directory, "curl"), `#!${process.execPath}
const assert = require("node:assert/strict");
const fs = require("node:fs");
const args = process.argv.slice(2);
fs.writeFileSync(process.env.CALLED, "called");
assert.equal(args.includes("test-only-credential"), false);
assert.equal(args[0], "--disable", "ignore curlrc logging/authentication overrides");
assert.equal(args[args.indexOf("--max-time") + 1], "10");
assert.equal(args[args.indexOf("--header") + 1], "@/dev/fd/3");
assert.equal(fs.readFileSync(3, "utf8"), "Authorization: Bearer test-only-credential\\n");
assert.equal(args.includes("https://beszel-mcp.hummingbird-lake.ts.net/mcp"), true);
const request = JSON.parse(args[args.indexOf("--data") + 1]);
assert.equal(request.method, "tools/call");
const tool = request.params.name;
fs.appendFileSync(process.env.CALLED + ".tools", tool + " " + JSON.stringify(request.params.arguments) + "\\n");
if (process.env.RESPONSES) {
    // Host mode: one canned reply per read-only tool.
    const reply = JSON.parse(process.env.RESPONSES)[tool];
    assert.ok(reply, "unexpected tool " + tool);
    process.stdout.write(reply.body);
    process.exit(reply.exit || 0);
}
assert.equal(tool, "list_systems");
assert.deepEqual(request.params.arguments, {});
process.stdout.write(process.env.RESPONSE || "");
process.exit(Number(process.env.CURL_EXIT || 0));
`, {mode: 0o700});
    function run(response, tokenFile = token, exit = 0, args = [], responses = "") {
        const result = spawnSync("bash", [helper, ...args], {encoding: "utf8", env: {
            ...process.env, PATH: directory + ":" + process.env.PATH,
            BESZEL_MCP_TOKEN_FILE: tokenFile, CALLED: called, RESPONSE: response, CURL_EXIT: String(exit),
            RESPONSES: responses
        }});
        assert.equal(result.status, 0, result.stderr);
        assert.equal(result.stderr, "");
        return result.stdout.trim();
    }
    assert.equal(run("", path.join(directory, "missing")), "unavailable");
    assert.equal(fs.existsSync(called), false, "missing credentials must not make any network call");
    assert.equal(run("", ""), "unavailable");
    assert.equal(fs.existsSync(called), false);
    assert.equal(run("", directory), "unavailable");
    const empty = path.join(directory, "empty");
    fs.writeFileSync(empty, "", {mode: 0o600});
    assert.equal(run("", empty), "unavailable");
    assert.equal(fs.existsSync(called), false);
    const systems = [{name: "unzen", status: "up", diskPercent: 30}];
    const reply = {jsonrpc: "2.0", id: 1, result: {content: [{type: "text", text: JSON.stringify({systems})}]}};
    assert.deepEqual(JSON.parse(run("event: message\r\ndata: " + JSON.stringify(reply) + "\r\n\r\n\n200")), systems);
    assert.deepEqual(JSON.parse(run(JSON.stringify(reply) + "\n200")), systems, "JSON transport is also valid MCP");
    for (const body of [
        {error: {message: "tool failed"}},
        {result: {isError: true, content: [{text: "denied"}]}},
        {result: {content: [{text: "not json"}]}},
        {result: {content: [{text: '{"systems":{}}'}]}},
        {result: {content: [{text: '{"systems":[{"name":"unzen","status":"invalid"}]}'}]}}
    ]) assert.equal(run("data: " + JSON.stringify(body) + "\n\n\n200"), "error");
    assert.equal(run("malformed\n200"), "error");
    assert.equal(run("denied\n401"), "error");
    assert.equal(run("maintenance\n503"), "error");
    assert.equal(run("\n000", token, 28), "unavailable");
    assert.equal(run("\n000", token, 7), "unavailable");
    assert.equal(fs.existsSync(called), true);
    // Host drill-down: three read-only calls, the token on fd 3 each time.
    const sse = value => "event: message\r\ndata: " + JSON.stringify({jsonrpc: "2.0", id: 1,
        result: {content: [{type: "text", text: JSON.stringify(value)}]}}) + "\r\n\r\n\n200";
    const metrics = {system: "unzen", points: [
        {recordedAt: "2026-10-24 14:17:27.640Z", cpuPercent: 8.9, memoryPercent: 10.5, diskPercent: 33.2, networkSentMbPerSec: 0.01},
        {recordedAt: "2026-10-24 14:18:27.640Z", cpuPercent: 4, memoryPercent: 10.4, diskPercent: 33.2, networkSentMbPerSec: 0, networkReceivedMbPerSec: 0.02}]};
    const services = {system: "unzen", count: 1, services: [{name: "snapraid-sync.service", state: "Failed"}]};
    const devices = {count: 2, devices: [
        {system: "unzen", name: "/dev/sdc", model: "ST12000VN0008", serial: "secret-serial", capacityGb: 12000, smartState: "FAILED", healthy: false,
         temperatureC: 47, powerOnHours: 18877, attributes: [{name: "Reallocated_Sector_Ct", failing: true}, {name: "Power_On_Hours", failing: false}]},
        {system: "ibuki", name: "/dev/sda", smartState: "PASSED", healthy: true}]};
    const all = {get_system_metrics: {body: sse(metrics)}, list_services: {body: sse(services)}, list_smart_devices: {body: sse(devices)}};
    fs.rmSync(called + ".tools", {force: true});
    const detail = JSON.parse(run("", token, 0, ["host", "unzen"], JSON.stringify(all)));
    assert.equal(detail.system, "unzen");
    assert.deepEqual(detail.metrics, [
        {t: "2026-10-24 14:17:27.640Z", cpu: 8.9, mem: 10.5, disk: 33.2, net: 0.01},
        {t: "2026-10-24 14:18:27.640Z", cpu: 4, mem: 10.4, disk: 33.2, net: 0.02}]);
    assert.deepEqual(detail.failed, ["snapraid-sync.service"]);
    assert.equal(detail.smart.length, 1, "only the expanded host's disks");
    assert.equal(detail.smart[0].serial, undefined, "serials stay on the hub");
    assert.deepEqual(detail.smart[0].attributes, [{name: "Reallocated_Sector_Ct", failing: true}]);
    const calls = fs.readFileSync(called + ".tools", "utf8").trim().split("\n");
    assert.deepEqual(calls, [
        'get_system_metrics {"system":"unzen","range":"1h","maxPoints":30}',
        'list_services {"system":"unzen","state":"Failed"}',
        "list_smart_devices {}"]);
    // A failed part is null; the others still arrive.
    const partial = JSON.parse(run("", token, 0, ["host", "unzen"], JSON.stringify({...all, list_services: {body: "denied\n401"}})));
    assert.equal(partial.failed, null);
    assert.equal(partial.smart.length, 1);
    const none = {body: "\n000", exit: 28};
    assert.equal(run("", token, 0, ["host", "unzen"], JSON.stringify({get_system_metrics: none, list_services: none, list_smart_devices: none})), "unavailable");
    const bad = {body: "maintenance\n503"};
    assert.equal(run("", token, 0, ["host", "unzen"], JSON.stringify({get_system_metrics: bad, list_services: bad, list_smart_devices: bad})), "error");
    // Host names never reach a shell or a request unvalidated.
    fs.rmSync(called + ".tools", {force: true});
    for (const name of ["", "-x", "a b", "$(id)", "unzen;rm", "a".repeat(64), "../x"]) {
        assert.equal(run("", token, 0, ["host", name], JSON.stringify(all)), "error", JSON.stringify(name));
    }
    assert.equal(fs.existsSync(called + ".tools"), false, "invalid names make no call");
    assert.equal(run("", token, 0, ["delete", "unzen"]), "error", "unknown forms make no call");
    assert.equal(fs.existsSync(called + ".tools"), false);
    assert.equal(run("", path.join(directory, "missing"), 0, ["host", "unzen"]), "unavailable");
    // The script contains read-only tools only.
    const source = fs.readFileSync(helper, "utf8");
    for (const tool of source.match(/request [a-z_]+/g)) {
        assert.ok(["request list_systems", "request get_system_metrics", "request list_services", "request list_smart_devices"].includes(tool), tool);
    }
    console.log("beszel-status: missing credentials skip network; private header, SSE/JSON, HTTP/tool errors, timeouts and the read-only host drill-down pass");
} finally {
    fs.rmSync(directory, {recursive: true, force: true});
}
