'use strict';
// Сборка обеих сторон сверки:
//   * оригиналы FOLD.BIN / FOLDSP.BIN / FOLDBAR.BIN (Z80) из ref/ironclad-msx —
//     тем же sjasmplus и теми же -D, что tools/asm.py оригинала, в build/orig/;
//     и проверка, что они побайтно равны бинарникам на release/IRONCLAD.DSK;
//   * перевод src/engine/engine.asm (i8080, ключ --i8080 — гейт на набор
//     команд) через tools/engine_diff/harness.asm в build/diff/.
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const ROOT = path.resolve(__dirname, '../..');
const REF = process.env.IRONCLAD_REF ||
  path.resolve(ROOT, fs.existsSync(path.join(ROOT, 'ref/ironclad-msx')) ? 'ref/ironclad-msx' : '../ref/ironclad-msx');
const SJASM = process.env.SJASMPLUS || path.join(ROOT, 'tools/sjasmplus');

function parseSym(file) {
  const sym = {};
  for (const line of fs.readFileSync(file, 'latin1').split('\n')) {
    const m = line.match(/^([^:\s]+):\s*EQU\s+0x([0-9A-Fa-f]+)/);
    if (m) sym[m[1]] = parseInt(m[2], 16);
  }
  return sym;
}

function run(args, cwd) {
  try {
    return execFileSync(SJASM, ['--nologo', '--msg=err', ...args], { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
  } catch (e) {
    throw new Error('sjasmplus: ' + (e.stdout || '') + (e.stderr || ''));
  }
}

const ORIG = {
  salvo: { bin: 'FOLD.BIN', defs: [] },
  sp: { bin: 'FOLDSP.BIN', defs: ['-DSPRULES=1'] },
  bar: { bin: 'FOLDBAR.BIN', defs: ['-DBARRULES=1'] },
};

// FAT12 MSX-DOS: достать файл с образа дискеты
function dskFile(dsk, name) {
  const d = fs.readFileSync(dsk);
  const bps = d.readUInt16LE(11), spc = d[13], res = d.readUInt16LE(14), nf = d[16];
  const nroot = d.readUInt16LE(17), spf = d.readUInt16LE(22);
  const fat = d.subarray(res * bps, (res + spf) * bps);
  const rootoff = (res + nf * spf) * bps, dataoff = rootoff + nroot * 32;
  const next = c => { const v = fat.readUInt16LE((c * 3) >> 1); return c & 1 ? v >> 4 : v & 0xfff; };
  for (let i = 0; i < nroot; i++) {
    const e = d.subarray(rootoff + i * 32, rootoff + i * 32 + 32);
    if (e[0] === 0 || e[0] === 0xe5) continue;
    const n = e.subarray(0, 8).toString('latin1').trim() + '.' + e.subarray(8, 11).toString('latin1').trim();
    if (n !== name) continue;
    let cl = e.readUInt16LE(26); const sz = e.readUInt32LE(28); const parts = [];
    while (cl < 0xff8) { parts.push(d.subarray(dataoff + (cl - 2) * spc * bps, dataoff + (cl - 1) * spc * bps)); cl = next(cl); }
    return Buffer.concat(parts).subarray(0, sz);
  }
  return null;
}

function buildOrig(outDir) {
  fs.mkdirSync(outDir, { recursive: true });
  const src = path.join(REF, 'src/z80/fold.asm');
  const dsk = path.join(REF, 'release/IRONCLAD.DSK');
  const res = {};
  for (const [v, o] of Object.entries(ORIG)) {
    const raw = path.join(outDir, o.bin + '.raw'), sym = path.join(outDir, o.bin + '.sym');
    run([...o.defs, '--raw=' + raw, '--sym=' + sym, src], outDir);
    const code = fs.readFileSync(raw);
    const s = parseSym(sym);
    const org = s.start;
    // BLOAD-заголовок как у tools/asm.py: FE start end exec
    const hdr = Buffer.from([0xfe, org & 255, org >> 8, (org + code.length - 1) & 255, (org + code.length - 1) >> 8, org & 255, org >> 8]);
    const bin = Buffer.concat([hdr, code]);
    fs.writeFileSync(path.join(outDir, o.bin), bin);
    let release = 'нет образа';
    if (fs.existsSync(dsk)) {
      const f = dskFile(dsk, o.bin);
      release = f && f.equals(bin) ? 'равен release' : 'ОТЛИЧАЕТСЯ от release';
    }
    res[v] = { code, org, sym: s, release };
  }
  return res;
}

function buildMine(outDir, engineDir) {
  fs.mkdirSync(outDir, { recursive: true });
  engineDir = engineDir || path.join(ROOT, 'src/engine');
  const sym = path.join(outDir, 'engine_test.sym');
  const lst = path.join(outDir, 'engine_test.lst');
  run(['--i8080', '-I', engineDir, '--outprefix=' + outDir + '/', '--sym=' + sym, '--lst=' + lst,
    path.join(__dirname, 'harness.asm')], outDir);
  const s = parseSym(sym);
  const code = fs.readFileSync(path.join(outDir, 'engine_test.bin'));
  const start = s['engine.eng_code_start'], end = s['engine.eng_code_end'];
  // метки кода перевода (для покрытия): всё из модуля engine в диапазоне кода
  const labels = {};
  for (const [k, a] of Object.entries(s)) {
    const n = k.startsWith('engine.') ? k.slice(7) : k;
    if (n === 'eng_code_start' || n === 'eng_code_end') continue;
    if (a >= start && a < end && (k.startsWith('engine.') || k.startsWith('eng_'))) {
      if (!(a in labels) || k.startsWith('eng_')) labels[a] = n;
    }
  }
  return { code, org: 0x100, sym: s, codeSize: end - start, bssSize: s.bss_end - s.bss_start, labels };
}

module.exports = { buildOrig, buildMine, parseSym, ROOT, REF };
