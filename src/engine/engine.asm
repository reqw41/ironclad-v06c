; ============================================================================
; engine.asm — движок ИИ залпов IRONCLAD, перевод Z80 -> i8080 для Вектора-06Ц.
;
; Оригинал: ref/ironclad-msx/src/z80/fold.asm + sampler.inc (три бинарника
; FOLD.BIN / FOLDSP.BIN / FOLDBAR.BIN из одного исходника через IFDEF).
; Здесь ОДИН код на все три варианта: вариант выбирается на ходу байтами
;   eng_sp  = 1  правила SALVO PLUS: NSHIPS=7, проверка буёв BZ в explore;
;   eng_bar = 1  правила BARRAGE: вес добивания 6000/(need*CC) в probesel.
; Буфер FA всегда на 1120 байт (размер SALVO PLUS).
;
; Подключаемый файл без ORG; данные — в engine_bss.inc (подключает игра).
; Игра определяет символы массивов (раскладка BASIC: int16 little-endian,
; A(i,j) = база + (i + j*(dim1+1))*2, корабли нумеруются с 1):
;   ARR_MG int16[144]  ARR_PH int16[12]  ARR_CC int16[8]  ARR_OS int16[8]
;   ARR_SZ int16[12]   ARR_HK int16[8]   ARR_TX int16[11] ARR_TY int16[11]
;   ARR_BZ int16[100]  ARR_PM int16[100]   (BZ(C,R), PM(C,R): (C+10R)*2)
; и ENG_JIFFY — адрес 16-битного счётчика (бывший JIFFY 0FC9Eh MSX), из
; которого берётся семя, если vSEED = 0 (0 там — семя 0ACE1h).
;
; Точки входа (аргумент USR — в HL; возвращаемое значение не используется):
;   eng_fold     USR0  HL = NS            свёртка залпа
;   eng_kill1    USR1  HL = KN*256+U*16+V снять кандидатов KN, покрывающих (U,V)
;   eng_explore  USR2                     разведочный залп (vRD, vNF, vRIM)
;   eng_pickn    USR3                     NF лучших клеток MG -> TX/TY (vKL)
;   eng_marg     USR4  (BASIC не зовёт)   маргинальные веса в MG
;   eng_sample   USR5                     совместная выборка флота -> MG
;   eng_fainit   USR7                     сброс кандидатов в начале партии
;   eng_probesel USR8  (не SALVO PLUS)    зонд + добор разведкой -> MG
; USR6 (samp1) в оригинале никем не вызывался — выброшен.
;
; Регистры и флаги на входе/выходе не сохраняются (как и в оригинале).
; Стек — 18 байт с адресом возврата.  Прерывания не запрещаются, код не
; самомодифицируется.
; Идиомы замены: djnz -> dec b/jp nz (dec b ставит Z, но не трогает CY;
; djnz не трогал ничего — после каждой замены проверено, что за циклом флаги
; не читаются); jr -> jp; sbc hl,rr -> вычитание через A; ld rr,(nn) для
; BC/DE -> через HL и ex de,hl; ldir -> fill4.
; Где счёт переделан ради скорости (scan, kill1, pickn, pldraw, div16) —
; итоговое состояние то же, что у оригинала; см. docs/ENGINE.md.
; Гейт: node tools/engine_diff/run.js (сверка с Z80-оригиналом).
; ============================================================================

                MODULE  engine

eng_code_start:

NSH_CL          equ     5               ; кораблей в SALVO / BARRAGE
NSH_SP          equ     7               ; кораблей в SALVO PLUS

; ---------------------------------------------------------------- пролог
; A = NSHIPS по флагу eng_sp (заменяет константу NSHIPS оригинала)
nsh:
                ld      a,(eng_sp)      ; 0 / 1
                add     a,a
                add     a,NSH_CL        ; 5 / 7
                ret
                ASSERT  NSH_SP == NSH_CL+2

; карта выстрелов живёт в первых 144 байтах MG; её чистят только fold и kill1
; (заодно vMODE = 0).  Сохраняет HL; A = 0.
clrmap:
                push    hl
                ld      hl,ARR_MG
                call    clr144
                ld      (vMODE),a
                pop     hl
                ret

; плоскость меток MO
clrmo:
                ld      hl,MOBUF
clr144:
                ld      b,144/4
                xor     a
; HL = адрес, B = число байт / 4 (0 = 1024), A = значение.  Сохраняет C, DE.
fill4:
                ld      (hl),a
                inc     hl
                ld      (hl),a
                inc     hl
                ld      (hl),a
                inc     hl
                ld      (hl),a
                inc     hl
                dec     b
                jp      nz,fill4
                ret

; ST = ST + 1 с переносом: 0 значит «не помечено», при переполнении плоскость
; стирается и счёт начинается с 1
bumpst:
                ld      hl,vST
                inc     (hl)
                ret     nz
                call    clrmo           ; HL -> vST (он сразу за MO)
                inc     (hl)
                ret

; vK += 1; NC = vK <= NSHIPS (продолжать)
nextk:
                ld      hl,vK
                inc     (hl)
                call    nsh
                cp      (hl)
                ret

; ---------------------------------------------------------------- USR0: fold
@eng_fold:
                call    clrmap
                ld      a,l             ; NS
                and     0Fh
                ret     z
                ld      c,a
fmark:                                  ; выстрелы NS-1..0 (порядок меток не важен)
                dec     c
                push    bc
                ld      a,c
                ld      hl,ARR_TY
                call    getel
                ld      b,a
                ld      a,c
                ld      hl,ARR_TX
                call    getel
                ld      d,a
                ld      e,b
                call    mapptr
                ld      (hl),1
                pop     bc
                inc     c
                dec     c
                jp      nz,fmark

                ld      a,1
                ld      (vK),a
fship:
                ld      hl,ARR_HK
                call    kel
                ld      (vH),a
                call    scan
                call    nextk
                jp      nc,fship
                ret

; ------------------------------------------------- USR1: снять покрытие клетки
; Оригинал ставил в карту выстрелов одну клетку и гнал scan по всем 20W
; кандидатам корабля KN с H=0 — погибал каждый живой, покрывающий клетку.
; Здесь cand (тот же режим 0, та же карта) зовётся только для живых из двух
; строк FA, где лежат все покрывающие: поперёк — строка Y = y0 (W штук),
; вниз — столбец X = x0 (W штук); непокрывающих отсеет сумма карты.  Итог
; тот же, включая vFAP = FA(OS+20W), vSTEP = 1, vLK, vW, карту в MG и vIDX:
; оригинал писал его для КАЖДОГО живого кандидата перед проверкой, так что
; это индекс последнего живого кандидата корабля в порядке scan (klast).
@eng_kill1:
                call    clrmap
                ld      (vH),a
                push    hl
                ld      a,h
                ld      (vK),a
                ld      a,20            ; klast: последний живой из 20W
                call    famw            ; HL -> FA(OS+20W), A = 20W
                ld      b,a
kl1:
                dec     hl
                ld      a,(hl)
                or      a
                jp      nz,klhit
                dec     b
                jp      nz,kl1
                ld      hl,(vIDX)       ; живых нет — vIDX не меняется
                jp      klset
klhit:
                dec     b
                ld      a,b             ; j
                call    jdec            ; HL = индекс первой клетки
klset:
                ex      (sp),hl         ; HL = аргумент, в стеке — индекс для vIDX
                ld      a,l
                and     0Fh
                ld      e,a             ; V
                ld      a,l
                rrca
                rrca
                rrca
                rrca
                and     0Fh
                ld      d,a             ; U
                call    mapptr          ; A = (U+1)*12 + (V+1), HL -> карта
                ld      (hl),1          ; карта, как у оригинала
                ld      l,a
                ld      c,12
                call    divsm           ; A = x0+1, E = y0+1 (V+1 >= 12 — соседний столбец)
                dec     a
                cp      10
                jp      nc,k1end        ; клетка поля — кандидаты её не покрывают
                ld      b,a             ; x0
                ld      a,e
                dec     a
                cp      10
                jp      nc,k1end
                push    bc
                call    krow            ; поперёк: строка FA номер y0
                pop     bc
                ld      a,b
                add     a,10
                call    krow            ; вниз: строка FA номер 10 + x0
k1end:
                pop     hl
                ld      (vIDX),hl
                ld      hl,1
                ld      (vSTEP),hl
                ld      a,20
                call    famw
                ld      (vFAP),hl       ; где scan кончал
                ret

; kill1: A = m — номер строки FA корабля (W кандидатов подряд); её живые ->
; cand.  Портит всё.
krow:
                call    famw            ; HL -> FA(OS + m*W), A = j первого
                push    hl
                call    jdec            ; HL = индекс, B = шаг
                ld      e,l
                ld      a,b
                pop     hl
                ld      c,1
                jp      shrows

; A = m -> HL -> FA(OS(K) + m*W), A = m*W (байт); ставит vLK, vW.
famw:
                ld      b,a
                call    shipset         ; HL -> FA(OS(K)); BC сохранён
                ld      a,(vW)
                ld      c,a
                xor     a
                inc     b
fm1:
                dec     b
                jp      z,fm2
                add     a,c
                jp      fm1
fm2:
                ld      e,a
                ld      d,0
                add     hl,de
                ret

; корабль vK: vLK = SZ(K), vW = 11 - LK; DE = OS(K), HL -> FA(OS(K)).
; Сохраняет BC.
shipset:
                ld      hl,ARR_SZ
                call    kel
                ld      (vLK),a
                cpl
                add     a,12            ; 11 - LK
                ld      (vW),a
                ld      hl,ARR_OS
                call    kel16
                ld      hl,FABUF
                add     hl,de
                ret

; -------------------------------------------------- USR3: NF лучших клеток
; Добивание: vKL = корабль (или 255 = все) — его живые клетки получают вес
; 2000 до выбора; vKL обнуляется.
@eng_pickn:
                ld      a,(vKL)
                or      a
                jp      z,pknorm
                ld      b,a             ; корабли от B до C
                ld      c,a
                inc     a
                jp      nz,pkl          ; не 255: один
                ld      b,1             ; 255: все
                call    nsh
                ld      c,a
pkl:
                ld      a,b
                ld      (vK),a
                push    bc
                ld      hl,2000
                call    scanwt
                pop     bc
                ld      a,b
                inc     b
                cp      c
                jp      nz,pkl
                xor     a
                ld      (vKL),a
pknorm:
                xor     a
                ld      (vT),a
; клетки P9 = 13..130: наибольший MG (со знаком; из равных — более ранняя)
pnshot:
                ld      de,pnh
                call    p9best
                ld      hl,(vBXW)       ; MG(BX) = -9
                call    mgat
                ld      (hl),-9
                inc     hl
                ld      (hl),-1
                ld      a,(vBXW)        ; BX (<= 130) -> столбец и строка
                ld      l,a
                ld      c,12
                call    divsm           ; A = X+1, E = Y+1
                dec     a
                ld      b,a             ; X (клетка поля даёт -1)
                dec     e
                ld      c,e             ; Y
                call    stnext
                jp      c,pnshot
                ret

; pickn: HL -> MG(P9) -> CY = MG(P9) > BS (со знаком), HL = MG(P9)
pnh:
                ld      e,(hl)
                inc     hl
                ld      d,(hl)
                ld      hl,(vBS)
                call    sgt
                ex      de,hl
                ret

; Лучшая клетка P9 = 13..130, как в циклах pickn/probesel оригинала: BS = -1,
; для каждой P9 зовётся обработчик (DE) с HL -> MG(P9); он возвращает CY =
; «лучше», HL = счёт — тогда BS = счёт, BXW = P9.  В конце vP9 = 131.
p9best:
                ld      hl,-1
                ld      (vBS),hl
                ld      hl,13
p9cell:
                ld      (vP9),hl
                push    de
                call    mgat
                call    jpde
                pop     de
                jp      nc,p9next
                ld      (vBS),hl
                ld      hl,(vP9)
                ld      (vBXW),hl
p9next:
                ld      hl,(vP9)
                inc     hl
                ld      a,l
                cp      131
                jp      nz,p9cell
                ld      (vP9),hl
                ret
jpde:
                push    de
                ret

; TX(T) = B, TY(T) = C (слова со знаком); T += 1; CY = T < NF
stnext:
                ld      a,b
                ld      hl,ARR_TX
                call    st1
                ld      a,c
                ld      hl,ARR_TY
                call    st1
                ld      hl,vT
                inc     (hl)
                ld      a,(hl)
                ld      hl,vNF
                cp      (hl)
                ret
; HL[vT] = A со знаком.  Сохраняет BC.
st1:
                push    af
                ld      a,(vT)
                call    elptr
                pop     af
                ld      (hl),a
                inc     hl
                rla
                sbc     a,a
                ld      (hl),a
                ret

; CY = 1, если DE > HL (16 бит со знаком).  Портит A.
sgt:
                ld      a,h
                xor     d
                jp      p,sgt1          ; знаки равны: беззнаковое сравнение
                ld      a,d
                rla                     ; CY = знак DE
                ccf                     ; DE >= 0 > HL
                ret
sgt1:
                ld      a,l
                sub     e
                ld      a,h
                sbc     a,d             ; CY <=> HL < DE
                ret

; ------------------------------------------------------- USR2: разведка
;   SC = MC(P9)*8 + ((C*5 + R*3 + RD) AND 7), +192/+64 на краю по флагам
; Клетки, уже выбранные в этом ходу, помечены в MO текущим vST.
@eng_explore:
                call    bumpst
                xor     a
                ld      (vT),a
extshot:
                ld      hl,-1
                ld      (vBS),hl
                ld      hl,0
                ld      (vC),hl         ; C = R = 0
extcell:
                call    pmtest          ; PM(C,R) должно быть 0
                jp      nz,extnext
                ld      a,(eng_sp)      ; SALVO PLUS: BZ(C,R)=3 — доказанная
                or      a               ; пустая вода, туда не стреляем
                jp      z,extmo
                ld      de,ARR_BZ
                add     hl,de
                ld      a,(hl)
                cp      3
                jp      z,extnext
extmo:
                call    padidx          ; MO(P9) не должно нести метку хода
                ld      de,MOBUF
                add     hl,de
                ld      a,(vST)
                cp      (hl)
                jp      z,extnext
                call    mc8             ; SC = MC(P9)*8 + дрожание
                ld      a,(vRD)
                call    jadd
                ld      a,(vC)          ; край: C или R = 0 или 9
                dec     a
                cp      8
                jp      nc,extrim
                ld      a,(vR)
                dec     a
                cp      8
                jp      c,extsc
extrim:
                ld      a,(vRIM)        ; +192, если личность — край
                or      a
                jp      z,extmem
                ld      de,192
                add     hl,de
extmem:
                ld      a,(SMEMB)       ; +64, если привычка выучена
                or      a
                jp      z,extsc
                ld      de,64
                add     hl,de
extsc:
                ex      de,hl           ; DE = SC
                ld      hl,(vBS)
                call    sgt             ; SC > BS ?
                jp      nc,extnext
                ex      de,hl
                ld      (vBS),hl
                ld      hl,(vC)         ; BX, BY = C, R
                ld      (vBX),hl
extnext:
                call    nextcr
                jp      c,extcell
                ld      hl,(vBX)        ; метка MO(BX*12 + BY + 13)
                ld      b,l
                ld      c,h
                ld      e,h
                ld      a,l
                call    pidx
                ld      de,MOBUF
                add     hl,de
                ld      a,(vST)
                ld      (hl),a
                call    stnext          ; TX(T) = BX, TY(T) = BY
                jp      c,extshot
                ld      hl,131          ; vP9: где кончал перебор оригинала
                ld      (vP9),hl
                ret

; следующая клетка обхода C = 0..9 (внешний), R = 0..9 (внутренний);
; CY = продолжать.  В конце C = R = 10, как у оригинала.
nextcr:
                ld      hl,vR
                inc     (hl)
                ld      a,(hl)
                cp      10
                ret     c
                dec     hl              ; vC
                inc     (hl)
                ld      a,(hl)
                cp      10
                ret     nc
                inc     hl
                ld      (hl),0          ; R = 0; CY = 1
                ret

; HL = MC(C,R)*8
mc8:
                call    padidx
                ld      de,MCBUF
                add     hl,de
                ld      l,(hl)
                ld      h,0
                add     hl,hl
                add     hl,hl
                add     hl,hl
                ret

; HL += (C*5 + R*3 + A) AND 7 — дрожание.  Портит BC, DE.
jadd:
                ex      de,hl
                ld      hl,(vC)         ; L = C, H = R
                ld      b,a
                ld      a,l
                add     a,a
                add     a,a
                add     a,l             ; C*5
                add     a,h
                add     a,h
                add     a,h             ; + R*3
                add     a,b
                and     7
                ld      l,a
                ld      h,0
                add     hl,de
                ret

; ------------------------------------------------- USR4: маргинальные веса
; Каждый живой кандидат добавляет 2880/CC(K) (не меньше 1) своим клеткам.
@eng_marg:
marg:
                ld      a,1
                ld      (vK),a
mgship:
                ld      hl,ARR_CC
                call    kel16
                ld      a,d             ; кандидатов нет — нечего взвешивать
                or      e
                jp      z,mgnext
                ld      hl,2880
                call    div16
                ld      a,h
                or      l
                jp      nz,mgok
                inc     hl              ; 0 -> 1
mgok:
                call    scanwt
mgnext:
                call    nextk
                jp      nc,mgship
                xor     a               ; и без единого scan — как у оригинала
                ld      (vMODE),a
                ret

; scan в режиме 1 с весом HL (vWT), затем vMODE = 0
scanwt:
                ld      (vWT),hl
                ld      a,1
; scan в режиме A, затем vMODE = 0
scanm:
                ld      (vMODE),a
                call    scan
                xor     a
                ld      (vMODE),a
                ret

; HL = HL / DE без знака повторным вычитанием, как у оригинала: время растёт
; с частным (2880/1 — 2880 шагов по 32 такта).  При DE = 0 частное 0
; (оригинал зависал — вне инвариантов игры).  Портит BC, DE.
div16:
                ld      a,e
                cpl
                ld      e,a
                ld      a,d
                cpl
                ld      d,a
                inc     de              ; DE = -делитель
                ld      bc,-1
dvl:
                inc     bc
                add     hl,de           ; CY <=> вычлось без заёма
                jp      c,dvl
                ld      h,b
                ld      l,c
                ret

; ---------------------------------------------------------------- scan: корабль K
; Перебор всех 20W кандидатов корабля vK в порядке оригинала.  Мёртвые
; (FA = 0) пропускаются прямо в цикле: указатель FA — в HL, индекс первой
; клетки — в E (13..142, байт), cand зовётся только для живых.
; На выходе, как у оригинала: vFAP = FA(OS+20W), vSTEP = 1, vLK, vW.
scan:
                call    shipset         ; HL -> FA(OS(K))
                ld      a,12            ; поперёк: Y внешний, X внутренний (+12)
                call    shalf
                ld      a,1             ; вниз: X внешний, Y внутренний (+1)
                call    shalf
                ld      (vFAP),hl
                ret

; половина перебора: A = шаг клеток кандидата (vSTEP: 12 / 1), HL -> FA;
; 10 строк по W кандидатов, индекс первой клетки с 13; следующая строка —
; +13-шаг (поперёк: следующий Y, вниз: следующий столбец X)
shalf:
                ld      e,13
                ld      c,10
; то же с E = индекс первой клетки, C = число строк.  Живые (FA <> 0) ->
; cand (vFAP = HL, DE = индекс).
shrows:
                push    hl
                ld      l,a
                ld      h,0
                ld      (vSTEP),hl
                pop     hl
                ld      b,a
sh_o:
                ld      a,(vW)
                ld      d,a
                push    de
srow:
                ld      a,(hl)
                or      a
                jp      z,srnext
                push    hl
                push    de
                push    bc
                ld      (vFAP),hl
                ld      d,0
                call    cand
                pop     bc
                pop     de
                pop     hl
srnext:
                inc     hl
                ld      a,e
                add     a,b
                ld      e,a
                dec     d
                jp      nz,srow
                pop     de
                ld      a,13
                sub     b
                add     a,e
                ld      e,a
                dec     c
                jp      nz,sh_o
                ret

; ---------------------------------------------------------------- кандидат
; Живой кандидат: vFAP -> FA(I), DE = индекс первой клетки, vSTEP = шаг.
cand:
                ld      a,(vMODE)
                dec     a
                jp      z,candmg
                dec     a
                jp      z,candn1

                ex      de,hl           ; режим 0: сумма карты выстрелов
                ld      (vIDX),hl
                ex      de,hl
                ld      hl,ARR_MG
                call    crun
                xor     a
covsum:
                add     a,(hl)
                add     hl,de
                dec     b
                jp      nz,covsum
                ld      hl,vH
                cp      (hl)
                ret     z

                ld      hl,(vFAP)       ; убить кандидата
                ld      (hl),0
                ld      hl,ARR_CC       ; CC(K) - 1
                call    kel16           ; DE = CC, HL -> старший байт
                dec     de
                ld      (hl),d
                dec     hl
                ld      (hl),e
                ld      hl,(vIDX)
                ex      de,hl
                ld      hl,MCBUF
                call    crun
mcloop:
                dec     (hl)
                add     hl,de
                dec     b
                jp      nz,mcloop
                ret

; режим 2 (probesel): число живых кандидатов на клетку — байтами в MO
candn1:
                ld      hl,MOBUF
                call    crun
n1cell:
                inc     (hl)
                add     hl,de
                dec     b
                jp      nz,n1cell
                ret

; HL += DE (-> первая клетка кандидата в плоскости), DE = vSTEP, B = vLK
crun:
                add     hl,de
                ex      de,hl
                ld      hl,(vSTEP)
                ex      de,hl
                ld      a,(vLK)
                ld      b,a
                ret

; режим 1: добавить вес vWT каждой покрытой клетке MG, ещё не запрещённой
; (отрицательные клетки вне игры).  Сумма НЕ насыщается — бюджет весов
; расписан в fold.asm оригинала у candmg.
candmg:
                ld      hl,ARR_MG+1
                add     hl,de
                call    crun            ; HL -> старший байт MG(первая клетка)
                ex      de,hl
                add     hl,hl
                ld      c,l             ; C = 2*шаг (24 или 2)
                ld      hl,(vWT)
                ex      de,hl           ; DE = вес
mgcell:
                ld      a,(hl)
                or      a
                jp      m,mgskip        ; знак: клетка вне игры
                dec     hl
                ld      a,(hl)
                add     a,e
                ld      (hl),a
                inc     hl
                ld      a,(hl)
                adc     a,d
                ld      (hl),a
mgskip:
                ld      a,l
                add     a,c
                ld      l,a
                jp      nc,mgnc
                inc     h
mgnc:
                dec     b
                jp      nz,mgcell
                ret

; ------------------------------------------------- USR7: сброс кандидатов
; Начало партии: все кандидаты живы, MC и MO чисты, метка хода 0.
; FA заполняется на все 1120 байт (в SALVO/BARRAGE используются 760).
@eng_fainit:
                ld      hl,FABUF        ; FA, MC, MO, vST — подряд
                ld      a,1
                ld      b,0             ; 1024
                call    fill4
                ld      b,96/4          ; + 96 = 1120
                call    fill4
                ld      b,288/4         ; MC и MO
                xor     a
                call    fill4
                ld      (hl),a          ; vST
                ld      (vKL),a
                ld      (vRK),a
                ret

; --------------------------------------------- USR8: зонд + разведка
; Раненый найденный корабль — вес 25000 (добор), раненый неоднозначный —
; ОДИН зонд +12000 в клетку, делящую его кандидатов ближе всего пополам;
; остальное в MG — разведочные счета MC*8+дрожание.  BARRAGE ещё добавляет
; каждой клетке, способной добить ненайденный корабль, 6000/(need*CC).
@eng_probesel:
                ld      a,1
                call    mgseedx         ; MG = разведочные счета
                ld      a,1
                ld      (vK),a
psship:
                ld      hl,ARR_PH
                call    kel
                or      a
                jp      z,psnext
                ld      b,a
                ld      hl,ARR_SZ
                call    kel
                sub     b               ; SZ-PH: попаданий ещё нужно
                jp      z,psnext
                ld      c,a
                ld      a,(eng_bar)
                or      a
                jp      z,ps1
                ld      a,c
                ld      (vNEED),a
ps1:
                ld      hl,ARR_CC
                call    kel16
                ex      de,hl
                ld      (vCCK),hl
                ex      de,hl
                ld      a,e             ; CC = 1?
                dec     a
                or      d
                jp      nz,psprobe
                ld      hl,25000        ; найден: добор
                call    scanwt
                jp      psnext
psprobe:
                ld      a,(eng_bar)
                or      a
                jp      z,psp2
                ld      hl,6000         ; BARRAGE: вес 6000/CC/need
                call    div16
                ld      a,(vNEED)
                ld      e,a
                ld      d,0
                call    div16
                call    scanwt
psp2:
                call    clrmo
                ld      a,2
                call    scanm
                ld      de,psh
                call    p9best
                ld      hl,(vBS)
                ld      a,h
                and     l
                inc     a
                jp      z,psnext        ; ни одной клетки
                ld      hl,(vBXW)       ; MG(BX) += 12000
                call    mgat
                ld      a,(hl)
                add     a,low 12000
                ld      (hl),a
                inc     hl
                ld      a,(hl)
                adc     a,high 12000
                ld      (hl),a
psnext:
                call    nextk
                jp      nc,psship
                ret

; probesel: HL -> MG(P9) -> CY = клетка в игре, покрыта (n = MO(P9) > 0) и
; |2n - CC| < BS (без знака); HL = |2n - CC|
psh:
                inc     hl
                ld      a,(hl)
                rla
                ccf
                ret     nc              ; клетка вне игры
                ld      hl,(vP9)
                ld      de,MOBUF
                add     hl,de
                ld      a,(hl)
                or      a
                ret     z               ; NC
                add     a,a             ; 2n (в байте, как в оригинале)
                ld      e,a
                ld      d,0
                ld      hl,(vCCK)
                ld      a,l             ; HL = CC - 2n
                sub     e
                ld      l,a
                ld      a,h
                sbc     a,d
                ld      h,a
                jp      nc,psabs
                xor     a               ; |2n - CC| = 0 - HL
                sub     l
                ld      l,a
                sbc     a,a
                sub     h
                ld      h,a
psabs:
                ex      de,hl
                ld      hl,(vBS)
                ex      de,hl
                jp      sgt1            ; CY <=> |d| < BS

; HL = ARR_MG + 2*HL (-> слово MG).  Портит BC.
mgat:
                add     hl,hl
mgat1:
                ld      bc,ARR_MG
                add     hl,bc
                ret

; ------------------------------------------------ MG = -1, затем счета клеток
; A = 0: живым клеткам дрожание (mgseed сэмплера)
; A = 1: живым клеткам MC*8 + дрожание (mgseedmc probesel)
; Обстрелянные клетки (PM <> 0) и поля остаются -1.
mgseedx:
                ld      (vSMC),a
                ld      hl,ARR_MG
                ld      a,0FFh
                ld      b,288/4
                call    fill4
                call    rnd16
                ld      a,l
                and     7
                ld      (vRDS),a
                ld      hl,0
                ld      (vC),hl         ; C = R = 0
mmr:
                call    pmtest
                jp      nz,mmnext
                ld      hl,0
                ld      a,(vSMC)
                or      a
                call    nz,mc8          ; MC*8
                ld      a,(vRDS)
                call    jadd            ; + дрожание
                push    hl
                call    padidx
                call    mgat
                pop     de
                ld      (hl),e
                inc     hl
                ld      (hl),d
mmnext:
                call    nextcr
                jp      c,mmr
                ret

; HL = 2*(vC + 10*vR) — смещение клетки в массиве 10x10;
; Z = PM(C,R) = 0.  HL сохраняется, портит A, DE.
pmtest:
                ld      hl,(vC)         ; L = C, H = R
                ld      a,h
                add     a,a
                add     a,a
                add     a,h
                add     a,a             ; 10R (R <= 9)
                add     a,l
                ld      l,a
                ld      h,0
                add     hl,hl
                push    hl
                ld      de,ARR_PM
                add     hl,de
                ld      a,(hl)
                inc     hl
                or      (hl)
                pop     hl
                ret

; ---------------------------------------------------------------- помощники
; HL += 2*A.  Сохраняет BC; DE = A.
; элемент массива по номеру корабля: kel16 — DE = X(vK) (HL -> старший
; байт), kel — A = X(vK) (младший байт); HL = база массива.  Сохраняют BC.
kel16:
                ld      a,(vK)
getel16:
                call    elptr
                ld      e,(hl)
                inc     hl
                ld      d,(hl)
                ret

kel:
                ld      a,(vK)
getel:
                call    elptr
                ld      a,(hl)
                ret

elptr:
                ld      e,a
                ld      d,0
                add     hl,de
                add     hl,de
                ret

; A = (D+1)*12 + (E+1) = 12D + E + 13, HL = ARR_MG + A.  В байте: у
; оригинала D+1 и E+1 тоже байтовые, а сумма < 256 (TX, TY <= 11; U, V <= 15).
; Портит BC.
mapptr:
                ld      a,d
                call    pidx
                ld      a,l
                jp      mgat1

; HL = индекс с полями для (vC,vR) = C*12 + R + 13.  Сохраняет BC.
padidx:
                ld      hl,(vC)         ; L = C, H = R
                ld      e,h
                ld      a,l
; HL = A*12 + E + 13 (в байте: A, E <= 9 — не больше 130).  Сохраняет BC, DE.
pidx:
                ld      l,a
                add     a,a
                add     a,l
                add     a,a
                add     a,a             ; 12A
                add     a,e
                add     a,13
                ld      l,a
                ld      h,0
                ret

; ============================================================================
; USR5: совместная выборка.  До шести совместных расстановок всего живого
; флота (законных, без касаний); MG получает +16 за каждое покрытие клетки.
; Меньше трёх удачных — под MG подкладываются маргинальные веса (marg).
@eng_sample:
                call    sortso
                xor     a
                call    mgseedx         ; MG = -1 / дрожание
                ld      hl,6*256
                ld      (vGG),hl        ; GG = 0, SA = 6
smploop:                                ; первая выборка — всегда (GG = 0)
                call    onesamp
                ld      a,(vGG)
                cp      3
                ld      hl,vSA
                dec     (hl)            ; CY сохраняется
                ret     nc              ; три удачных
                jp      nz,smploop
                jp      marg            ; попытки кончились

; --- SO[0..NSHIPS-1] = номера кораблей по возрастанию CC
sortso:
                call    nsh
                ld      b,a             ; NSHIPS
                ld      hl,vSOA
                ld      a,1
ss0:
                ld      (hl),a
                inc     hl
                inc     a
                dec     b
                jp      nz,ss0
                xor     a
                ld      (vSI),a
ssj:                                    ; A = SJ-1
                inc     a
                ld      (vSJ),a
                ld      b,a
                call    nsh
                cp      b               ; SJ < NSHIPS (SJ <= NSHIPS всегда)
                ld      a,b
                jp      z,ssinext
                call    ccof            ; HL -> SO[J], DE = CC(SO[J])
                push    hl
                ex      de,hl
                ld      (vSCJ),hl
                ld      a,(vSI)
                call    ccof            ; HL -> SO[I], DE = CC(SO[I])
                ex      (sp),hl
                push    hl
                ld      hl,(vSCJ)
                call    sgt1            ; CY <=> CC(SO[J]) < CC(SO[I])
                pop     de              ; -> SO[J]
                pop     hl              ; -> SO[I]
                jp      nc,ssjnext      ; CC(SO[J]) >= CC(SO[I])
                ld      a,(de)          ; поменять местами
                ld      c,(hl)
                ld      (hl),a
                ld      a,c
                ld      (de),a
ssjnext:
                ld      a,(vSJ)
                jp      ssj
ssinext:
                ld      hl,vSI
                inc     (hl)
                call    nsh
                sub     (hl)
                cp      2               ; SI < NSHIPS-1
                ld      a,(hl)
                jp      nc,ssj
                ret

; A = номер слота -> HL -> SO[A], DE = CC(SO[A])
ccof:
                ld      e,a
                ld      d,0
                ld      hl,vSOA
                add     hl,de
                push    hl
                ld      a,(hl)
                ld      hl,ARR_CC
                call    getel16
                pop     hl
                ret

; --- одна совместная выборка: поставить все корабли, затем зачесть клетки
onesamp:
                xor     a
                ld      (vQNC),a
                call    bumpst
                call    nsh
                ld      (vO2),a
                ld      hl,vSOA
                ld      (vSOP),hl
osship:
                ld      hl,(vSOP)
                ld      a,(hl)
                ld      (vK),a
                call    place
                ret     c
                ld      hl,(vSOP)
                inc     hl
                ld      (vSOP),hl
                ld      hl,vO2
                dec     (hl)
                jp      nz,osship
                ld      hl,vGG
                inc     (hl)
                ld      a,(vQNC)        ; каждая клетка выборки +16
                ld      b,a             ; (QNC = сумма длин кораблей, не 0)
                ld      hl,vZX
osadd:
                push    bc
                ld      e,(hl)
                inc     hl
                ld      d,(hl)
                inc     hl
                push    hl
                ex      de,hl
                call    mgat
                inc     hl
                ld      a,(hl)
                dec     hl
                rla                     ; мёртвая вода не участвует
                jp      c,osskip
                ld      a,(hl)
                add     a,16
                ld      (hl),a
                inc     hl
                ld      a,(hl)
                adc     a,0
                ld      (hl),a
osskip:
                pop     hl
                pop     bc
                dec     b
                jp      nz,osadd
                ret

; --- поставить корабль vK; CY = все восемь попыток не удались
place:
                call    shipset
                ex      de,hl
                ld      (vOSK),hl

                ld      a,8
                ld      (vT2),a
platt:
                call    pldraw          ; vJ0 <- равномерно среди ЖИВЫХ, -> vIBB, vS9
                jp      c,plnext        ; живых нет
; vRK: найденные корабли этой партии доказали расстановку у края — кандидат,
; не касающийся края, получает до двух перерисовок в пользу края
                ld      a,(vRK)
                or      a
                jp      z,plcoll
                call    rimchk
                jp      z,plcoll        ; уже у края
                ld      a,(vJ0)
                ld      (vJ0F),a
                ld      a,2
                ld      (vRDL),a
plrdo:                                  ; CC тот же, что у первого удачного
                call    pldraw          ; pldraw — живой есть (у оригинала
                                        ; jr c,plrgive, не срабатывающий никогда)
                call    rimchk
                jp      z,plcoll        ; у края — берём
                ld      hl,vRDL
                dec     (hl)
                jp      nz,plrdo
plrgive:
                ld      a,(vJ0F)        ; оставить первого
                ld      (vJ0),a
                call    decode
plcoll:
                ld      hl,(vS9)        ; касается уже поставленных?
                ex      de,hl
                ld      hl,(vIBB)
                ld      bc,MOBUF
                add     hl,bc
                ld      a,(vLK)
                ld      b,a
                ld      a,(vST)
plcf:
                cp      (hl)
                jp      z,plnext
                add     hl,de
                dec     b
                jp      nz,plcf

                ld      a,(vQNC)        ; записать клетки корабля в vZX
                ld      hl,vZX
                call    elptr           ; HL -> слот ZX
                ld      a,(vLK)
                ld      b,a
                ex      de,hl
                ld      hl,(vIBB)
                ex      de,hl           ; DE = клетка
plrec:
                ld      (hl),e
                inc     hl
                ld      (hl),d
                inc     hl
                push    hl
                ld      hl,(vS9)
                add     hl,de
                ex      de,hl
                pop     hl
                dec     b
                jp      nz,plrec
                ex      de,hl
                ld      (vP9),hl        ; IBB + LK*S9, как у оригинала
                ld      hl,vQNC
                ld      a,(vLK)
                add     a,(hl)
                ld      (hl),a

; метка в MO клеток корабля и соседей: у оригинала — LK+2 клеток p от
; IB-S9 с шагом S9, в каждой p, p-W2, p+W2 (W2 = 13-S9, боковой сосед).
; Здесь то же множество тремя линиями: от IB-S9-W2 = IB-13, +W2, +2*W2.
                ld      a,(vS9)
                cpl
                add     a,14            ; W2 = 13 - S9 (1 / 12)
                ld      l,a
                ld      h,0
                ld      (vW2),hl
                ld      hl,(vIBB)
                ld      de,MOBUF-13
                add     hl,de           ; HL -> MO(IB - 13)
                ld      c,3
plst:
                push    hl
                ex      de,hl
                ld      hl,(vS9)
                ex      de,hl           ; DE = S9
                ld      a,(vLK)
                add     a,2
                ld      b,a
                ld      a,(vST)
plstamp:
                ld      (hl),a
                add     hl,de
                dec     b
                jp      nz,plstamp
                pop     hl
                ex      de,hl
                ld      hl,(vW2)
                add     hl,de           ; следующая линия: +W2
                dec     c
                jp      nz,plst
                or      a
                ret
plnext:
                ld      hl,vT2
                dec     (hl)
                jp      nz,platt
                scf
                ret

; Равномерный выбор среди ЖИВЫХ кандидатов корабля vK: r в [0, CC), затем
; r-й живой флаг FA.  CY только при CC = 0.  CC обязан равняться числу
; живых флагов (его ведёт fold).
pldraw:
                ld      hl,ARR_CC
                call    kel16
                ld      a,d
                or      e
                scf
                ret     z               ; CC = 0
                ld      c,e             ; CC <= 180 — байт
pldr:
                call    rnd16
                ld      a,l
                cp      c
                jp      nc,pldr         ; r в [0, CC)
                inc     a
                ld      b,a             ; остановиться на (r+1)-м живом
                ld      c,-1            ; C = номер кандидата J0
                ld      hl,(vOSK)
                ld      de,FABUF
                add     hl,de
pldscan:
                inc     c
                ld      a,(hl)
                inc     hl
                or      a
                jp      z,pldscan
                dec     b
                jp      nz,pldscan
                ld      a,c
                ld      (vJ0),a
; A = vJ0 (номер кандидата внутри корабля) -> vIBB, vS9, vC, vR.  NC: у
; настоящего кандидата (X, Y <= 9) в pidx переноса нет.
decode:
                call    jdec
                ld      (vIBB),hl
                ld      l,b
                ld      h,0
                ld      (vS9),hl
                ld      l,d
                ld      h,e
                ld      (vC),hl         ; vC = X, vR = Y
                ret

; A = j (номер кандидата внутри корабля, по vW) -> D = X, E = Y,
; B = шаг клеток (12 поперёк / 1 вниз), HL = индекс первой клетки 12X+Y+13
jdec:
                ld      l,a
                ld      a,(vW)
                ld      c,a
                call    divsm           ; A = j/W, E = j mod W
                sub     10
                jp      c,jdacr
                ld      d,a             ; вниз (j >= 10W): X = j/W - 10, Y = j mod W
                ld      b,1
                jp      jdfin
jdacr:
                add     a,10            ; поперёк: Y = j/W, X = j mod W
                ld      d,e
                ld      e,a
                ld      b,12
jdfin:
                ld      a,d
                jp      pidx

; L / C -> A частное, E остаток
divsm:
                ld      b,0
dv1:
                ld      a,l
                sub     c
                jp      c,dv2
                ld      l,a
                inc     b
                jp      dv1
dv2:
                ld      e,l
                ld      a,b
                ret

; Z = декодированный кандидат (vC,vR,vS9,vLK) касается края поля.
rimchk:
                ld      hl,(vC)         ; L = C, H = R
                ld      a,(vS9)
                cp      12
                jp      z,rck1          ; поперёк: поперечная ось R, продольная C
                ld      a,l             ; вниз: поменять оси
                ld      l,h
                ld      h,a
rck1:                                   ; H = поперечная ось, L = продольная
                ld      a,h
                or      a
                ret     z
                cp      9
                ret     z
                ld      a,l
                or      a
                ret     z
                ld      a,(vLK)
                add     a,l
                cp      10              ; продольная + LK - 1 = 9
                ret

; xorshift16 оригинала (сдвиг 7 урезан до младшего байта — повторён точно):
;   H ^= L>>1; L ^= (L&1)<<7;  L ^= H>>1;  H ^= L.   Сохраняет BC, E.
rnd16:
                ld      hl,(vSEED)
                ld      a,h
                or      l
                jp      nz,rnz
                ld      hl,(ENG_JIFFY)
                ld      a,h
                or      l
                jp      nz,rnz
                ld      hl,0ACE1h
rnz:
                ld      a,l
                rrca                    ; бит 7 = L.0, биты 6..0 = L>>1
                ld      d,a
                and     7Fh
                xor     h
                ld      h,a
                ld      a,d
                and     80h
                xor     l
                ld      l,a
                ld      a,h             ; CY = 0: его сбросил xor выше
                rra                     ; H>>1
                xor     l
                ld      l,a
                xor     h
                ld      h,a
                ld      (vSEED),hl
                ret

eng_code_end:
                ASSERT  eng_code_end - eng_code_start <= 3584

                ENDMODULE
