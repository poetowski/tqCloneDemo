#!/usr/bin/env node
// Dev commands for UNTHREADED, run through npm (see package.json):
//
//   npm run editor [-- <scene>]   open the project in the Godot editor (MCP needs it)
//   npm run game [-- <scene>]     play the game (or one scene) in a window; blocks
//   npm run import                import new or changed assets, headless
//   npm run models [-- <slug>..]  run the Blender asset scripts headless (palette,
//                                 characters, props, items, level), writing .glb
//                                 into assets/models/, then import; slugs filter
//   npm run icons                 render item/skill icons and UI art in Blender
//   npm run audio                 synthesize every sound in Blender (aud + numpy)
//   npm run assets                models + icons + audio + import: rebuild all art
//   npm run level                 rebuild src/world/elaion/elaion.tscn from the
//                                 layout data (tools/build_level.gd)
//   npm run render -- <glb|slug>  Blender preview render of a model into .shots/models/
//   npm run blender               open Blender with the MCP add-on (port 9876)
//   npm run canon                 every name registered in docs/CANON.md, none of
//                                 the "not ours" names anywhere, no broken doc links
//   npm run check                 import, then load every script/scene/resource
//   npm test [-- <gut args>]      run the GUT suite headless (-gselect=test_stats)
//   npm run shot [-- <scene>] [--out=x.png] [--frames=90] [--size=1280x720]
//                [--camera=x,y,z --look=x,y,z] [--player=x,y,z] [--scenario=name] [--timeout=240]
//                                 play a scene in a window, save a PNG, quit
//   npm run api                   dump the engine class reference to .godot-api/
//   npm run where                 print the Godot and Blender binaries in use
//
// Engines are pinned below; GODOT / BLENDER environment variables override them.

import { spawn } from 'node:child_process';
import { existsSync, mkdirSync, readdirSync, rmSync, statSync, utimesSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { checkCanon } from './canon.mjs';

const GODOT_VERSION = '4.7.2';
const BLENDER_VERSION = '5.2.3';
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const BLENDER_DIR = path.join(ROOT, 'tools', 'blender');
// Asset folders, built in this order; every .py inside is one build script.
const MODEL_FOLDERS = ['textures', 'characters', 'props', 'items', 'level'];
const ANSI = /\x1b\[[0-9;]*m/g;
const ERROR_LINE = /^\s*(SCRIPT ERROR|SHADER ERROR|USER ERROR|ERROR):/;
const WARNING_LINE = /^\s*(SCRIPT WARNING|USER WARNING|WARNING):/;

function godotBinary({ gui = false } = {}) {
  const fromEnv = process.env.GODOT;
  if (fromEnv) return gui ? fromEnv.replace(/_console\.exe$/i, '.exe') : fromEnv;
  if (process.platform === 'win32') {
    const dir = path.join(process.env.LOCALAPPDATA ?? '', 'Programs', 'Godot', GODOT_VERSION);
    const exe = path.join(dir, `Godot_v${GODOT_VERSION}-stable_win64${gui ? '' : '_console'}.exe`);
    if (existsSync(exe)) return exe;
  }
  return 'godot';
}

function blenderBinary() {
  if (process.env.BLENDER) return process.env.BLENDER;
  if (process.platform === 'win32') {
    const exe = path.join(process.env.LOCALAPPDATA ?? '', 'Programs', 'Blender', BLENDER_VERSION, 'blender.exe');
    if (existsSync(exe)) return exe;
  }
  return 'blender';
}

// Runs a Blender script headless with factory settings, so add-ons and
// preferences on this machine can't change what it builds.
function blender(script, extra = []) {
  return new Promise((resolve) => {
    const args = ['--background', '--factory-startup', '--python-exit-code', '1', '--python', script, '--', ...extra];
    const child = spawn(blenderBinary(), args, { cwd: ROOT, stdio: ['ignore', 'pipe', 'pipe'] });
    let output = '';
    const echo = (chunk) => {
      const text = chunk.toString();
      output += text;
      // Blender is chatty; keep our own lines and anything that smells like trouble.
      for (const line of text.split(/\r?\n/)) {
        if (/^\[(asset|kit|level|icons|audio|render|palette)\]|Error|Traceback|error:|File "/.test(line)) console.log(line);
      }
    };
    child.stdout.on('data', echo);
    child.stderr.on('data', echo);
    child.on('close', (code) => resolve({ code: code ?? 1, output }));
    child.on('error', (error) => {
      console.error(`[dev] could not start Blender (${blenderBinary()}): ${error.message}`);
      resolve({ code: 1, output });
    });
  });
}

// Runs Godot, echoing its output, and resolves with the exit code, the output
// and the error and warning lines found in it.
function godot(args, { timeoutMs = 0, gui = false, quiet = false } = {}) {
  return new Promise((resolve) => {
    const child = spawn(godotBinary({ gui }), args, { cwd: ROOT, stdio: ['ignore', 'pipe', 'pipe'] });
    let output = '';
    const echo = (stream) => (chunk) => {
      const text = chunk.toString();
      output += text;
      if (!quiet) stream.write(text);
    };
    child.stdout.on('data', echo(process.stdout));
    child.stderr.on('data', echo(process.stderr));
    const timer = timeoutMs
      ? setTimeout(() => {
          console.error(`\n[dev] Godot ran longer than ${timeoutMs / 1000}s; stopping it.`);
          child.kill();
        }, timeoutMs)
      : null;
    const finish = (code) => {
      if (timer) clearTimeout(timer);
      const lines = output.replace(ANSI, '').split(/\r?\n/);
      resolve({
        code,
        output,
        errors: lines.filter((line) => ERROR_LINE.test(line)),
        warnings: lines.filter((line) => WARNING_LINE.test(line)),
      });
    };
    child.on('error', (error) => {
      console.error(`[dev] could not start Godot (${godotBinary({ gui })}): ${error.message}`);
      finish(1);
    });
    child.on('close', (code) => finish(code ?? 1));
  });
}

function report(name, result) {
  const { code, errors, warnings } = result;
  console.log(`\n[dev] ${name}: exit ${code}, ${errors.length} error(s), ${warnings.length} warning(s)`);
  for (const line of errors) console.log(`  ${line.trim()}`);
  for (const line of warnings.slice(0, 40)) console.log(`  ${line.trim()}`);
  if (warnings.length > 40) console.log(`  ... ${warnings.length - 40} more warning(s)`);
  return code === 0 && errors.length === 0;
}

// The class registry (class_name scripts) and imports live in .godot/; refresh them
// when the cache is missing or any script or asset is newer than it.
async function ensureImported() {
  const stamp = path.join(ROOT, '.godot', 'global_script_class_cache.cfg');
  if (!existsSync(path.join(ROOT, '.godot', 'uid_cache.bin')) || !existsSync(stamp)) {
    console.log('[dev] .godot/ cache missing, importing first');
    return importAssets();
  }
  const since = statSync(stamp).mtimeMs;
  const newer = (dir) => {
    if (!existsSync(dir)) return false;
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      if (entry.name.startsWith('.')) continue;
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        if (newer(full)) return true;
      } else if (/\.(gd|glb|png|wav|tscn|tres|gdshader)$/.test(entry.name) && statSync(full).mtimeMs > since) {
        return true;
      }
    }
    return false;
  };
  if (['src', 'tools', 'tests', 'assets'].some((dir) => newer(path.join(ROOT, dir)))) {
    return importAssets();
  }
  return true;
}

async function importAssets() {
  return report('import', await godot(['--headless', '--path', ROOT, '--import'], { timeoutMs: 15 * 60_000, quiet: true }));
}

function toResPath(scene) {
  if (scene.startsWith('res://')) return scene;
  const relative = path.relative(ROOT, path.resolve(process.cwd(), scene)).split(path.sep).join('/');
  return `res://${relative}`;
}

function parseOptions(argv) {
  const options = {};
  const positional = [];
  for (const arg of argv) {
    const match = arg.match(/^--([a-z-]+)=(.*)$/);
    if (match) options[match[1]] = match[2];
    else positional.push(arg);
  }
  return { options, positional };
}

function scriptsIn(folder) {
  const dir = path.join(BLENDER_DIR, folder);
  if (!existsSync(dir)) return [];
  return readdirSync(dir)
    .filter((name) => name.endsWith('.py') && !name.startsWith('_'))
    .sort()
    .map((name) => path.join(dir, name));
}

async function runBlenderScripts(scripts) {
  const started = Date.now();
  for (const script of scripts) {
    const { code } = await blender(script);
    const rel = path.relative(ROOT, script);
    console.log(`[dev] blender ${rel}: exit ${code}`);
    if (code !== 0) return false;
  }
  console.log(`[dev] ${scripts.length} Blender script(s) in ${((Date.now() - started) / 1000).toFixed(1)}s`);
  return true;
}

const commands = {
  where() {
    console.log(`godot:   ${godotBinary()}`);
    console.log(`blender: ${blenderBinary()}`);
    return true;
  },

  editor(argv) {
    const { positional } = parseOptions(argv);
    const scene = positional[0] ? [toResPath(positional[0])] : [];
    spawn(godotBinary({ gui: true }), ['--path', ROOT, '--editor', ...scene], { detached: true, stdio: 'ignore' }).unref();
    console.log('[dev] editor starting');
    return true;
  },

  async game(argv) {
    const { options, positional } = parseOptions(argv);
    const scene = positional[0] ? [toResPath(positional[0])] : [];
    const passed = Object.entries(options).map(([k, v]) => `--${k}=${v}`);
    if (!(await ensureImported())) return false;
    return report('game', await godot(['--path', ROOT, ...scene, '--', ...passed]));
  },

  // npm run import [-- --force]: --force touches every model so all re-import (needed
  // after changing tools/import/post_import.gd; Godot only re-imports changed sources).
  async import(argv) {
    const { options, positional } = parseOptions(argv);
    if (options.force !== undefined || positional.includes('--force')) {
      const now = new Date();
      const touch = (dir) => {
        if (!existsSync(dir)) return;
        for (const entry of readdirSync(dir, { withFileTypes: true })) {
          const full = path.join(dir, entry.name);
          if (entry.isDirectory()) touch(full);
          else if (entry.name.endsWith('.glb')) utimesSync(full, now, now);
        }
      };
      touch(path.join(ROOT, 'assets', 'models'));
      // A new time alone isn't enough: Godot also compares each source's checksum
      // and skips unchanged files. Forget the checksums so every model really
      // goes through tools/import/post_import.gd again.
      const imported = path.join(ROOT, '.godot', 'imported');
      if (existsSync(imported)) {
        for (const name of readdirSync(imported)) {
          if (/\.glb-[0-9a-f]+\.md5$/.test(name)) rmSync(path.join(imported, name));
        }
      }
    }
    return importAssets();
  },

  // Builds every model, or only scripts whose file name matches a slug.
  async models(argv) {
    const { positional } = parseOptions(argv);
    let scripts = MODEL_FOLDERS.flatMap(scriptsIn);
    if (positional.length) {
      scripts = scripts.filter((script) => positional.some((slug) => path.basename(script, '.py') === slug));
      if (!scripts.length) {
        console.error(`[dev] no asset script named ${positional.join(', ')}`);
        return false;
      }
    }
    if (!(await runBlenderScripts(scripts))) return false;
    return importAssets();
  },

  async icons() {
    return (await runBlenderScripts(scriptsIn('render').filter((s) => !s.endsWith('preview.py')))) && importAssets();
  },

  async audio() {
    return (await runBlenderScripts(scriptsIn('audio'))) && importAssets();
  },

  async assets() {
    const scripts = [...MODEL_FOLDERS.flatMap(scriptsIn), ...scriptsIn('render').filter((s) => !s.endsWith('preview.py')), ...scriptsIn('audio')];
    return (await runBlenderScripts(scripts)) && importAssets();
  },

  // Rebuilds the level scene from data/level/*.json and the terrain's heightmap.
  async level() {
    if (!(await ensureImported())) return false;
    const result = await godot(['--headless', '--path', ROOT, '--script', 'res://tools/build_level.gd'], { timeoutMs: 10 * 60_000 });
    return report('level', result);
  },

  // Blender preview render of one model: npm run render -- hero  (or a .glb path)
  async render(argv) {
    const { options, positional } = parseOptions(argv);
    if (!positional[0]) {
      console.error('usage: npm run render -- <slug|path.glb> [--anim=name --frame=10] [--size=768]');
      return false;
    }
    const extra = [positional[0], ...Object.entries(options).map(([k, v]) => `--${k}=${v}`)];
    const { code } = await blender(path.join(BLENDER_DIR, 'render', 'preview.py'), extra);
    return code === 0;
  },

  // Opens Blender with the MCP for Blender add-on's telemetry and update check off.
  blender() {
    const env = { ...process.env, DISABLE_TELEMETRY: 'true', BLENDERMCP_NO_UPDATE_CHECK: '1' };
    spawn(blenderBinary(), [], { detached: true, stdio: 'ignore', env }).unref();
    console.log('[dev] Blender starting; the MCP add-on listens on localhost:9876');
    return true;
  },

  // Names, "not ours" names and doc links (tools/canon.mjs, docs/CANON.md).
  canon() {
    return checkCanon(ROOT);
  },

  async check() {
    if (!(await importAssets())) return false;
    const result = await godot(['--headless', '--path', ROOT, '--script', 'res://tools/check_project.gd'], { timeoutMs: 10 * 60_000 });
    return report('check', result);
  },

  async test(argv) {
    if (!(await ensureImported())) return false;
    const result = await godot(['--headless', '--path', ROOT, '--script', 'res://addons/gut/gut_cmdln.gd', ...argv], {
      timeoutMs: 15 * 60_000,
    });
    return report('test', result);
  },

  async shot(argv) {
    const { options, positional } = parseOptions(argv);
    const scene = positional[0] ? toResPath(positional[0]) : null;
    const name = options.scenario ?? (scene ? path.basename(scene, path.extname(scene)) : 'main');
    const out = path.resolve(ROOT, options.out ?? path.join('.shots', `${name}.png`));
    mkdirSync(path.dirname(out), { recursive: true });
    if (existsSync(out)) rmSync(out);
    if (!(await ensureImported())) return false;
    const args = ['--path', ROOT, '--resolution', options.size ?? '1280x720'];
    if (scene) args.push(scene);
    args.push('--', `--shot=${out}`, `--shot-frames=${options.frames ?? 90}`);
    for (const key of ['camera', 'look', 'player', 'scenario', 'zoom', 'yaw']) {
      if (options[key]) args.push(`--shot-${key}=${options[key]}`);
    }
    const ok = report('shot', await godot(args, { timeoutMs: Number(options.timeout ?? 240) * 1000 }));
    if (!existsSync(out) || statSync(out).size === 0) {
      console.log('[dev] no screenshot was written');
      return false;
    }
    console.log(`[dev] screenshot: ${out}`);
    return ok;
  },

  // An automated play-through of the whole zone, headless (no window), reported in
  // text: npm run tour [-- --speed=3 --minutes=10 --scenario=tour|playthrough|paths]
  // "tour" plays a seasoned level-8 hero (does the zone work?); "playthrough" a
  // level-1 hero who levels and equips like a player (is it fair?); "paths" checks
  // the navmesh: every route link walkable, no islands, nothing under the sea.
  async tour(argv) {
    const { options } = parseOptions(argv);
    if (!(await ensureImported())) return false;
    const minutes = Number(options.minutes ?? 10);
    const scenario = options.scenario ?? 'tour';
    const args = ['--headless', '--path', ROOT, 'res://src/world/elaion/elaion.tscn', '--', '--shot=tour', `--shot-frames=${Math.round(minutes * 60 * 60)}`,
      `--shot-scenario=${scenario}`, `--speed=${options.speed ?? 3}`];
    const result = await godot(args, { timeoutMs: (minutes * 60 + 60) * 1000, quiet: true });
    const shown = scenario === 'paths' ? /^\[paths\]|ERROR|SCRIPT ERROR/ : /^\[(auto|shot|balance)\]|ERROR|SCRIPT ERROR/;
    const lines = result.output.replace(ANSI, '').split(/\r?\n/).filter((line) => shown.test(line));
    for (const line of lines) console.log(line);
    if (scenario === 'paths') {
      const clean = /\[paths\] 0 broken link/.test(result.output) && /\[paths\] 0 of \d+ polygon\(s\) cut off from the start, 0 under the sea/.test(result.output)
        && /\[paths\] 0 stalled walk/.test(result.output);
      console.log(`\n[dev] paths: ${clean ? 'every link walks, no islands, nothing under the sea, no stalls' : 'NOT clean'}`);
      return report('tour', result) && clean;
    }
    const completed = result.output.includes('DEMO COMPLETED');
    console.log(`\n[dev] tour: ${completed ? 'the demo was completed' : 'the demo was NOT completed'}`);
    return report('tour', result) && completed;
  },

  async api() {
    const out = path.join(ROOT, '.godot-api');
    mkdirSync(out, { recursive: true });
    const code = await new Promise((resolve) => {
      const child = spawn(godotBinary(), ['--headless', '--doctool', out], { cwd: out, stdio: 'inherit' });
      child.on('close', (c) => resolve(c ?? 1));
      child.on('error', () => resolve(1));
    });
    if (code !== 0) return false;
    console.log(`[dev] Godot ${GODOT_VERSION} class reference: ${path.join(out, 'doc', 'classes')}`);
    return true;
  },
};

const [name, ...rest] = process.argv.slice(2);
const command = commands[name];
if (!command) {
  console.error(`usage: node tools/dev.mjs <${Object.keys(commands).join('|')}> [args]`);
  process.exit(2);
}
process.exit((await command(rest)) ? 0 : 1);
