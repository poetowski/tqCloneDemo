#!/usr/bin/env node
// Talks to the MCP servers from .mcp.json over stdio, outside a Claude Code session:
//   node tools/mcp_probe.mjs [godot|blender]                    start, list tools
//   node tools/mcp_probe.mjs blender get_scene_info '{}'        call one tool
//   node tools/mcp_probe.mjs godot --session calls.json         one server, many calls:
//       [{"tool": "read_scene", "args": {...}}, ...]; for godot it first waits (up to
//       90 s) until the editor plugin has connected (open the editor: npm run editor).
// Image results are saved to .shots/mcp_<tool>_<n>.png.
import { spawn } from 'node:child_process';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const config = JSON.parse(readFileSync(path.join(ROOT, '.mcp.json'), 'utf8')).mcpServers;
const [only, second, third] = process.argv.slice(2);

let calls = null;
if (second === '--session') calls = JSON.parse(readFileSync(third, 'utf8'));
else if (second) calls = [{ tool: second, args: JSON.parse(third ?? '{}') }];

function session(name, server) {
  return new Promise((resolve) => {
    const child = spawn(server.command, server.args, { cwd: ROOT, env: { ...process.env, ...(server.env ?? {}) }, stdio: ['pipe', 'pipe', 'pipe'] });
    const pending = new Map();
    let nextId = 10;
    let buffer = '';
    const send = (message) => child.stdin.write(JSON.stringify({ jsonrpc: '2.0', ...message }) + '\n');
    const request = (method, params) => new Promise((done) => {
      const id = nextId++;
      pending.set(id, done);
      send({ id, method, params });
    });
    child.stdout.on('data', (chunk) => {
      buffer += chunk.toString();
      let newline;
      while ((newline = buffer.indexOf('\n')) >= 0) {
        const line = buffer.slice(0, newline).trim();
        buffer = buffer.slice(newline + 1);
        if (!line.startsWith('{')) continue;
        const message = JSON.parse(line);
        if (pending.has(message.id)) {
          pending.get(message.id)(message);
          pending.delete(message.id);
        }
      }
    });
    const finish = (text) => {
      child.kill();
      resolve(text);
    };
    child.on('error', (error) => finish(`${name}: could not start (${error.message})`));
    const killer = setTimeout(() => finish(`${name}: timed out`), 300_000);
    (async () => {
      await request('initialize', { protocolVersion: '2024-11-05', capabilities: {}, clientInfo: { name: 'probe', version: '1' } });
      send({ method: 'notifications/initialized' });
      if (!calls) {
        const listed = await request('tools/list', {});
        const tools = (listed.result?.tools ?? []).map((t) => t.name);
        clearTimeout(killer);
        return finish(`${name}: up, ${tools.length} tools: ${tools.slice(0, 12).join(', ')}${tools.length > 12 ? ', ...' : ''}`);
      }
      if (name === 'godot') {
        for (let waited = 0; waited < 90; waited += 3) {
          const status = await request('tools/call', { name: 'get_godot_status', arguments: {} });
          if ((status.result?.content?.[0]?.text ?? '').includes('"connected": true')) break;
          await new Promise((r) => setTimeout(r, 3000));
        }
      }
      const out = [];
      let n = 0;
      for (const call of calls) {
        const reply = await request('tools/call', { name: call.tool, arguments: call.args ?? {} });
        const content = reply.result?.content ?? [];
        for (const part of content) {
          if (part.type === 'image') {
            mkdirSync(path.join(ROOT, '.shots'), { recursive: true });
            const file = path.join(ROOT, '.shots', `mcp_${call.tool}_${n++}.png`);
            writeFileSync(file, Buffer.from(part.data, 'base64'));
            out.push(`${call.tool}: image -> ${path.relative(ROOT, file)}`);
          }
        }
        const text = content.filter((c) => c.type === 'text').map((c) => c.text).join('\n');
        out.push(`${name}.${call.tool}: ${reply.error ? 'ERROR ' + JSON.stringify(reply.error) : text.slice(0, call.limit ?? 1500)}`);
        if (call.wait) await new Promise((r) => setTimeout(r, call.wait));
      }
      clearTimeout(killer);
      finish(out.join('\n'));
    })();
  });
}

for (const [name, server] of Object.entries(config)) {
  if (only && name !== only) continue;
  console.log(await session(name, server));
}
