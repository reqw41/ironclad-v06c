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
  ['pickn: сравнение наоборот', 'sbc     a,d\n                jp      nc,pnnext       ; равные', 'sbc     a,d\n                jp      c,pnnext        ; равные'],
  ['pickn: разные знаки наоборот', 'ld      a,d             ; знаки разные: больше, если MG >= 0\n                or      a\n                jp      m,pnnext', 'ld      a,d             ; знаки разные: больше, если MG >= 0\n                or      a\n                jp      p,pnnext'],
  ['pickn: BXW без or a перед rra (флаг)', 'ld      a,h\n                or      a\n                rra\n                ld      h,a', 'ld      a,h\n                rra\n                ld      h,a'],
  ['pndiv: jp nc -> jp z (флаг)', 'add     hl,de           ; CY <=> HL >= 12 (до вычитания)\n                jp      nc,pndone', 'add     hl,de           ; CY <=> HL >= 12 (до вычитания)\n                jp      z,pndone'],
  // explore / sgt
  ['sgt: потерян ccf (флаг)', 'rla                     ; CY = знак DE\n                ccf', 'rla                     ; CY = знак DE\n                nop'],
  ['sgt1: sbc -> sub (потерян заём)', 'sub     e\n                ld      a,h\n                sbc     a,d             ; CY <=> HL < DE', 'sub     e\n                ld      a,h\n                sub     d               ; CY <=> HL < DE'],
  ['explore: край 9 -> 8', 'ld      a,(vR)\n                or      a\n                jp      z,extrim\n                cp      9', 'ld      a,(vR)\n                or      a\n                jp      z,extrim\n                cp      8'],
  ['SALVO PLUS: буй cp 3 -> cp 2', 'ld      a,(hl)\n                cp      3\n                jp      z,extnext', 'ld      a,(hl)\n                cp      2\n                jp      z,extnext'],
  ['bumpst: после переполнения 2', 'call    clrmo\n                ld      hl,vST\n                inc     (hl)', 'call    clrmo\n                ld      hl,vST\n                inc     (hl)\n                inc     (hl)'],
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
  ['kill1: клетка по 13 вместо 12 (перенос V+1 >= 12 в соседний столбец)', 'ld      l,a\n                ld      c,12\n                call    divsm', 'ld      l,a\n                ld      c,13\n                call    divsm'],
  ['kill1: столбец вниз 9+x0 вместо 10+x0', 'add     a,10\n                call    krow', 'add     a,9\n                call    krow'],
  ['kill1: отсечка x0 < 11 вместо < 10', 'cp      10\n                jp      nc,k1end        ; клетка поля', 'cp      11\n                jp      nc,k1end        ; клетка поля'],
  ['kill1: без строки поперёк', 'push    bc\n                call    krow', 'push    bc\n                nop\n                nop\n                nop'],
  ['klast: j на единицу больше', 'klhit:\n                dec     b', 'klhit:\n                nop'],
  ['kill1: vIDX не восстановлен', 'ld      hl,(vKI)\n                ld      (vIDX),hl', 'ld      hl,(vKI)\n                nop\n                nop\n                nop'],
  ['cand: sbc -> sub в CC (потерян заём)', 'ld      a,(hl)\n                sub     1\n                ld      (hl),a\n                inc     hl\n                ld      a,(hl)\n                sbc     a,0', 'ld      a,(hl)\n                sub     1\n                ld      (hl),a\n                inc     hl\n                ld      a,(hl)\n                sub     0'],
  // marg / div16 / probesel
  ['div16: 15 шагов вместо 16', 'ld      hl,0            ; остаток\n                ld      a,16', 'ld      hl,0            ; остаток\n                ld      a,15'],
  ['probesel: 12000 -> 12001', 'ld      hl,12000', 'ld      hl,12001'],
  ['probesel: sbc -> sub (потерян заём)', 'sub     l\n                ld      a,b\n                sbc     a,h             ; CY <=> |d| < BS', 'sub     l\n                ld      a,b\n                sub     h               ; CY <=> |d| < BS'],
  ['BARRAGE: 6000 -> 5000', 'ld      hl,6000', 'ld      hl,5000'],
  ['SALVO PLUS: NSHIPS 7 -> 6', 'ld      a,(eng_sp)      ; 0 / 1\n                add     a,a', 'ld      a,(eng_sp)      ; 0 / 1\n                nop'],
  // sampler
  ['rnd16: маска 7Fh -> 3Fh', 'and     7Fh', 'and     3Fh'],
  ['rnd16: rrca -> rra (CY течёт)', 'rrca                    ; бит 7 = L.0', 'rra                     ; бит 7 = L.0'],
  ['pldraw: первый шаг без cp (r не проверен)', 'call    rnd16\n                ld      a,l\n                cp      c\n                jp      c,pldok', 'call    rnd16\n                ld      a,l\n                cp      c\n                jp      nc,pldok'],
  ['pldraw: r вместо r+1', 'pldok:\n                inc     a', 'pldok:\n                nop'],
  ['pldraw: семя не сохранено после отбраковки', 'jp      nc,pldr         ; r в [0, CC)\n                ld      (vSEED),hl', 'jp      nc,pldr         ; r в [0, CC)\n                nop\n                nop\n                nop'],
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
