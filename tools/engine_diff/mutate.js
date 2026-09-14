#!/usr/bin/env node
'use strict';
// Проверка, что стенд не слеп: в копию перевода вносятся намеренные ошибки
// (по одной), и сверка обязана найти РАСХОЖДЕНИЯ (не просто упасть на
// покрытии).  Плюс гейт обязан упасть на пустой выборке.
//
// node tools/engine_diff/mutate.js [--sessions N] [--random N]
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const os = require('os');
const { ROOT } = require('./build.js');

const args = process.argv.slice(2);
const opt = (n, d) => { const i = args.indexOf('--' + n); return i < 0 ? d : args[i + 1]; };
const SESS = opt('sessions', '2'), RND = opt('random', '40');
const SRC = path.join(ROOT, 'src/engine');

// [имя, что заменить (точный фрагмент, обязан встречаться 1 раз), на что]
const MUT = [
  // pickn
  ['pickn: сравнение наоборот', 'call    sgt             ; MG(P9) > BS ?\n                jp      nc,pnnext', 'call    sgt             ; MG(P9) > BS ?\n                jp      c,pnnext'],
  ['pickn: новый лучший без BXW', 'ld      hl,(vP9)\n                ld      (vBXW),hl\npnnext:', 'ld      hl,(vP9)\n                nop\n                nop\n                nop\npnnext:'],
  ['pickn: X без dec (со знаком)', 'dec     a\n                ld      b,a             ; X', 'nop\n                ld      b,a             ; X'],
  ['pickn: MG(BX) = -8 вместо -9', 'ld      (hl),-9', 'ld      (hl),-8'],
  ['pickn: 255 -> все корабли, но первый 2', 'ld      b,1             ; 255: все', 'ld      b,2             ; 255: все'],
  // explore / sgt
  ['sgt: потерян ccf (флаг)', 'rla                     ; CY = знак DE\n                ccf', 'rla                     ; CY = знак DE\n                nop'],
  ['sgt1: sbc -> sub (потерян заём)', 'sub     e\n                ld      a,h\n                sbc     a,d             ; CY <=> HL < DE', 'sub     e\n                ld      a,h\n                sub     d               ; CY <=> HL < DE'],
  ['explore: край 9 -> 8', 'ld      a,(vR)\n                dec     a\n                cp      8', 'ld      a,(vR)\n                dec     a\n                cp      7'],
  ['SALVO PLUS: буй cp 3 -> cp 2', 'ld      a,(hl)\n                cp      3\n                jp      z,extnext', 'ld      a,(hl)\n                cp      2\n                jp      z,extnext'],
  ['bumpst: после переполнения 2', 'call    clrmo           ; HL -> vST (он сразу за MO)\n                inc     (hl)', 'call    clrmo           ; HL -> vST (он сразу за MO)\n                inc     (hl)\n                inc     (hl)'],
  // fold / scan / cand
  ['fold: маска NS 0Fh -> 07h', 'ld      a,l             ; NS\n                and     0Fh', 'ld      a,l             ; NS\n                and     07h'],
  ['mapptr: оси перепутаны', 'mapptr:\n                ld      a,d\n                call    pidx', 'mapptr:\n                ld      a,e\n                call    pidx'],
  ['scan: живой пропущен (jz -> jnz)', 'or      a\n                jp      z,srnext', 'or      a\n                jp      nz,srnext'],
  ['shalf: шаг строки 13-шаг -> 14-шаг', 'ld      a,13\n                sub     b', 'ld      a,14\n                sub     b'],
  ['jdec: шаг вниз 1 -> 2', 'ld      b,1\n                jp      jdfin', 'ld      b,2\n                jp      jdfin'],
  ['cand: отсев наоборот', 'ld      hl,vH\n                cp      (hl)\n                ret     z', 'ld      hl,vH\n                cp      (hl)\n                ret     nz'],
  ['candmg: знак клетки наоборот', 'jp      m,mgskip        ; знак: клетка вне игры', 'jp      p,mgskip        ; знак: клетка вне игры'],
  ['candmg: adc -> add (потерян перенос)', 'ld      a,(hl)\n                adc     a,d\n                ld      (hl),a', 'ld      a,(hl)\n                add     a,d\n                ld      (hl),a'],
  // kill1
  ['kill1: клетка по 13 вместо 12 (перенос V+1 >= 12 в соседний столбец)', 'ld      l,a\n                ld      c,12\n                call    divsm           ; A = x0+1', 'ld      l,a\n                ld      c,13\n                call    divsm           ; A = x0+1'],
  ['kill1: столбец вниз 9+x0 вместо 10+x0', 'add     a,10\n                call    krow', 'add     a,9\n                call    krow'],
  ['kill1: отсечка x0 < 11 вместо < 10', 'cp      10\n                jp      nc,k1end        ; клетка поля', 'cp      11\n                jp      nc,k1end        ; клетка поля'],
  ['kill1: без строки поперёк', 'push    bc\n                call    krow', 'push    bc\n                nop\n                nop\n                nop'],
  ['klast: j на единицу больше', 'klhit:\n                dec     b', 'klhit:\n                nop'],
  ['kill1: vIDX не восстановлен', 'ld      hl,(vKI)\n                ld      (vIDX),hl', 'ld      hl,(vKI)\n                nop\n                nop\n                nop'],
  ['cand: sbc -> sub в CC (потерян заём)', 'ld      a,(hl)\n                sub     1\n                ld      (hl),a\n                inc     hl\n                ld      a,(hl)\n                sbc     a,0', 'ld      a,(hl)\n                sub     1\n                ld      (hl),a\n                inc     hl\n                ld      a,(hl)\n                sub     0'],
  // marg / div16 / probesel
  ['div16: частное на 1 больше', 'ld      bc,-1\ndvl:', 'ld      bc,0\ndvl:'],
  ['div16: делитель без +1 (обратный код)', 'inc     de              ; DE = -делитель', 'nop'],
  ['probesel: 12000 -> 12001', 'add     a,low 12000', 'add     a,low 12001'],
  ['probesel: +12000 без переноса в старший байт', 'adc     a,high 12000', 'add     a,high 12000'],
  ['probesel: sbc -> sub (потерян заём)', 'sub     l\n                ld      a,b\n                sbc     a,h             ; CY <=> |d| < BS', 'sub     l\n                ld      a,b\n                sub     h               ; CY <=> |d| < BS'],
  ['BARRAGE: 6000 -> 5000', 'ld      hl,6000', 'ld      hl,5000'],
  ['SALVO PLUS: NSHIPS 7 -> 6', 'ld      a,(eng_sp)      ; 0 / 1\n                add     a,a', 'ld      a,(eng_sp)      ; 0 / 1\n                nop'],
  // sampler
  ['rnd16: маска 7Fh -> 3Fh', 'and     7Fh', 'and     3Fh'],
  ['rnd16: rrca -> rra (CY течёт)', 'rrca                    ; бит 7 = L.0', 'rra                     ; бит 7 = L.0'],
  ['pldraw: отбраковка только r = CC (jp nc -> jp z)', 'cp      c\n                jp      nc,pldr', 'cp      c\n                jp      z,pldr'],
  ['pldraw: r вместо r+1', 'jp      nc,pldr         ; r в [0, CC)\n                inc     a', 'jp      nc,pldr         ; r в [0, CC)\n                nop'],
  ['rnd16: семя не сохранено', 'ld      (vSEED),hl', 'nop\n                nop\n                nop'],
  ['sample: без запаса попыток (SA не уменьшается)', 'ld      hl,vSA\n                dec     (hl)', 'ld      hl,vSA\n                inc     (hl)'],
  ['plrec: P9 не пишется', 'ex      de,hl\n                ld      (vP9),hl', 'ex      de,hl\n                nop\n                nop\n                nop'],
  ['place: 7 попыток вместо 8', 'ld      a,8\n                ld      (vT2),a', 'ld      a,7\n                ld      (vT2),a'],
  ['sortso: порядок наоборот', 'jp      nc,ssjnext      ; CC(SO[J]) >= CC(SO[I])', 'jp      c,ssjnext       ; CC(SO[J]) >= CC(SO[I])'],
  ['plstamp: LK+1 вместо LK+2', 'ld      a,(vLK)\n                add     a,2', 'ld      a,(vLK)\n                add     a,1'],
  ['fainit: FA на 1116 байт', 'ld      b,96/4          ; + 96 = 1120', 'ld      b,92/4          ; + 96 = 1120'],
];

function runGate(extra) {
  return new Promise(res => {
    const ch = spawn(process.execPath, [path.join(__dirname, 'run.js'), '--quiet', ...extra], { stdio: ['ignore', 'pipe', 'pipe'] });
    let err = '';
    ch.stderr.on('data', d => { err += d; });
    ch.stdout.on('data', () => {});
    ch.on('close', status => res({ status, stderr: err }));
  });
}

async function main() {
  const rows = [];
  let ok = true;
  // 1) пустая выборка
  {
    const js = path.join(ROOT, 'build/mut/empty.json');
    fs.mkdirSync(path.dirname(js), { recursive: true });
    const r = await runGate(['--sessions', '0', '--random', '0', '--fast', '--json', js]);
    const s = JSON.parse(fs.readFileSync(js, 'utf8'));
    const caught = r.status !== 0 && s.why.some(w => w.includes('пустая выборка'));
    rows.push(['пустая выборка (0 случаев)', caught ? 'ГЕЙТ УПАЛ' : 'НЕ УПАЛ', s.why[0] || '']);
    if (!caught) ok = false;
  }
  // 2) мутации — параллельно
  const src = fs.readFileSync(path.join(SRC, 'engine.asm'), 'utf8');
  const out = new Array(MUT.length);
  let next = 0;
  async function worker() {
    for (;;) {
      const i = next++;
      if (i >= MUT.length) return;
      const [name, from, to] = MUT[i];
      const dir = path.join(ROOT, 'build/mut', String(i));
      fs.rmSync(dir, { recursive: true, force: true });
      fs.mkdirSync(dir, { recursive: true });
      const n = src.split(from).length - 1;
      if (n !== 1) { out[i] = [name, `фрагмент найден ${n} раз`, '']; continue; }
      fs.writeFileSync(path.join(dir, 'engine.asm'), src.replace(from, to));
      fs.copyFileSync(path.join(SRC, 'engine_bss.inc'), path.join(dir, 'engine_bss.inc'));
      const js = path.join(dir, 'sum.json');
      const r = await runGate(['--engine-dir', dir, '--build-sub', 'mut/' + i + '/b', '--sessions', SESS, '--random', RND, '--fast', '--json', js]);
      if (!fs.existsSync(js)) { out[i] = [name, 'стенд не отработал', (r.stderr || '').split('\n')[0]]; continue; }
      const s = JSON.parse(fs.readFileSync(js, 'utf8'));
      const bad = s.rows.filter(x => x.bad > 0);
      const nbad = bad.reduce((a, x) => a + x.bad, 0);
      out[i] = [name, nbad ? `поймана: ${nbad} случаев` : 'НЕ ПОЙМАНА', bad.map(x => `${x.v}/${x.e}:${x.bad}`).join(' ')];
    }
  }
  const J = Math.max(1, Math.min(8, os.cpus().length - 1));
  await Promise.all(Array.from({ length: J }, worker));
  for (const r of out) { rows.push(r); if (!r[1].startsWith('поймана')) ok = false; }
  console.log('мутация | итог | где расхождения (вариант/вход:случаев)');
  for (const r of rows) console.log(`${r[0]} | ${r[1]} | ${r[2]}`);
  console.log(ok ? `\nСТЕНД НЕ СЛЕП: все ${MUT.length} мутаций пойманы, пустая выборка валит гейт` : '\nПРОБЛЕМА: есть непойманные мутации');
  process.exit(ok ? 0 : 1);
}
main();
