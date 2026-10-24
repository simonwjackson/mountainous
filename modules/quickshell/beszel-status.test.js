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
assert.equal(request.params.name, "list_systems");
assert.deepEqual(request.params.arguments, {});
process.stdout.write(process.env.RESPONSE || "");
process.exit(Number(process.env.CURL_EXIT || 0));
`, {mode: 0o700});
    function run(response, tokenFile = token, exit = 0) {
        const result = spawnSync("bash", [helper], {encoding: "utf8", env: {
            ...process.env, PATH: directory + ":" + process.env.PATH,
            BESZEL_MCP_TOKEN_FILE: tokenFile, CALLED: called, RESPONSE: response, CURL_EXIT: String(exit)
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
    console.log("beszel-status: missing credentials skip network; private header, SSE/JSON, HTTP/tool errors and timeouts pass");
} finally {
    fs.rmSync(directory, {recursive: true, force: true});
}
