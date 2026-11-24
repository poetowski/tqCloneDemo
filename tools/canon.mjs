// The canon check (`npm run canon`, first step of `npm run verify`). Keeps the world
// consistent as it grows (docs/CANON.md):
//   1. every proper name the game data shows a player is registered in docs/CANON.md
//   2. no name from CANON.md's "Not ours" list appears in the game, data, code or docs
//      (except the few files that record the rule itself)
//   3. every relative link in the docs points at a file that exists
// No dependencies; reads files only.

import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import path from 'node:path';

const CANON = 'docs/CANON.md';
// Files allowed to mention "Not ours" names: the ones that state or record the rule.
const MAY_MENTION = new Set(['docs/CANON.md', 'docs/DECISIONS.md', 'docs/ROADMAP.md', 'CLAUDE.md']);
const SCANNED_DIRS = ['data', 'docs', 'src', 'tools', 'tests'];
const SCANNED_FILES = ['CLAUDE.md', 'README.md', 'project.godot'];
const TEXT = /\.(md|json|gd|py|mjs|tscn|tres|cfg|gdshader|txt)$/;

function readJson(root, file) {
  return JSON.parse(readFileSync(path.join(root, file), 'utf8'));
}

function entries(data) {
  return Object.entries(data).filter(([key]) => !key.startsWith('_'));
}

// Every name the data puts in front of a player, with where it comes from.
function namesInData(root) {
  const names = [];
  const add = (name, from) => name && names.push({ name, from });
  for (const [id, e] of entries(readJson(root, 'data/enemies.json'))) add(e.name, `data/enemies.json ${id}`);
  for (const [id, b] of entries(readJson(root, 'data/items/bases.json'))) add(b.name, `data/items/bases.json ${id}`);
  for (const [id, u] of entries(readJson(root, 'data/items/uniques.json'))) add(u.name, `data/items/uniques.json ${id}`);
  for (const a of readJson(root, 'data/items/affixes.json').affixes) add(a.name, `data/items/affixes.json ${a.id}`);
  for (const [id, s] of entries(readJson(root, 'data/skills.json'))) add(s.name, `data/skills.json ${id}`);
  for (const [id, q] of entries(readJson(root, 'data/quests.json'))) add(q.title, `data/quests.json ${id}`);
  for (const [id, d] of entries(readJson(root, 'data/dialogue.json'))) add(d.name, `data/dialogue.json ${id}`);
  const levels = path.join(root, 'data', 'level');
  for (const file of readdirSync(levels).filter((f) => f.endsWith('_layout.json'))) {
    for (const item of readJson(root, `data/level/${file}`).items) {
      if (item.type === 'zone' || item.type === 'shrine') add(item.name, `data/level/${file} ${item.type}`);
    }
  }
  // Champion titles live with the enemy code.
  const enemy = readFileSync(path.join(root, 'src/actors/enemies/enemy.gd'), 'utf8');
  const titles = enemy.match(/CHAMPION_TITLES[^=]*=\s*\[([^\]]*)\]/);
  for (const title of titles ? titles[1].match(/"([^"]+)"/g) ?? [] : []) add(title.slice(1, -1), 'enemy.gd CHAMPION_TITLES');
  return names;
}

// Registered names: everything in **bold** or `code` above "## Not ours"; the
// forbidden names: the `code` spans below it.
function readCanon(root) {
  const text = readFileSync(path.join(root, CANON), 'utf8');
  const split = text.indexOf('\n## Not ours');
  const registry = split >= 0 ? text.slice(0, split) : text;
  const notOurs = split >= 0 ? text.slice(split) : '';
  const registered = new Set();
  // (A name may wrap onto the next line of the markdown: join it back.)
  for (const m of registry.matchAll(/\*\*([^*]+)\*\*|`([^`]+)`/g)) registered.add((m[1] ?? m[2]).replace(/\s+/g, ' ').trim());
  const forbidden = [...notOurs.matchAll(/`([^`]+)`/g)].map((m) => m[1].replace(/\s+/g, ' ').trim());
  return { registered, forbidden };
}

function* walk(root, dir) {
  const full = path.join(root, dir);
  if (!existsSync(full)) return;
  for (const name of readdirSync(full)) {
    const rel = `${dir}/${name}`;
    if (statSync(path.join(root, rel)).isDirectory()) yield* walk(root, rel);
    else if (TEXT.test(name)) yield rel;
  }
}

function escape(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

export function checkCanon(root) {
  const problems = [];
  const { registered, forbidden } = readCanon(root);

  const fromData = namesInData(root);
  for (const { name, from } of fromData) {
    if (!registered.has(name)) problems.push(`not in ${CANON}: "${name}" (${from})`);
  }

  const files = [...SCANNED_DIRS.flatMap((d) => [...walk(root, d)]), ...SCANNED_FILES.filter((f) => existsSync(path.join(root, f)))];
  const patterns = forbidden.map((name) => ({ name, re: new RegExp(`(?<![\\w'])${escape(name)}(?![\\w'])`) }));
  for (const file of files) {
    if (MAY_MENTION.has(file)) continue;
    const lines = readFileSync(path.join(root, file), 'utf8').split('\n');
    lines.forEach((line, i) => {
      for (const { name, re } of patterns) if (re.test(line)) problems.push(`"${name}" is not ours: ${file}:${i + 1}`);
    });
  }

  let links = 0;
  for (const file of files.filter((f) => f.endsWith('.md'))) {
    const text = readFileSync(path.join(root, file), 'utf8');
    for (const m of text.matchAll(/\]\(([^)\s]+)\)/g)) {
      const target = m[1].split('#')[0];
      if (!target || /^[a-z]+:/i.test(target)) continue;
      links += 1;
      if (!existsSync(path.join(root, path.dirname(file), decodeURIComponent(target)))) problems.push(`broken link in ${file}: ${m[1]}`);
    }
  }

  for (const p of problems) console.log(`[canon] ${p}`);
  console.log(`[canon] ${fromData.length} names from the data, ${registered.size} registered; ${forbidden.length} names not ours, `
    + `${files.length} files scanned; ${links} doc links; ${problems.length} problem(s)`);
  return problems.length === 0;
}
