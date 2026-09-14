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
; vNS1 = NSHIPS+1 по флагу eng_sp (заменяет константу NSHIPS оригинала)
setup:
                ld      a,(eng_sp)      ; 0 / 1
                add     a,a
                add     a,NSH_CL+1      ; 6 / 8
                ld      (vNS1),a
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
                call    clrmo
                ld      hl,vST
                inc     (hl)
                ret

; vK += 1; CY = vK < NSHIPS+1
nextk:
                ld      hl,vK
                inc     (hl)
                ld      a,(hl)
                inc     hl              ; vNS1
                cp      (hl)
                ret

; ---------------------------------------------------------------- USR0: fold
@eng_fold:
                call    setup
                call    clrmap
                ld      a,l             ; NS
                and     0Fh
                ret     z
                ld      b,a
                ld      c,0
fmark:
                push    bc
                ld      a,c
                ld      hl,ARR_TX
                call    getel
                push    af
                ld      a,c
                ld      hl,ARR_TY
                call    getel
                ld      e,a
                pop     af
                ld      d,a
                call    mapptr
                ld      (hl),1
                pop     bc
                inc     c
                dec     b
                jp      nz,fmark

                ld      a,1
                ld      (vK),a
fship:
                ld      hl,ARR_HK
                call    kel
                ld      (vH),a
                call    scan
                call    nextk
                jp      c,fship
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
                ld      (vKI),hl
                pop     hl
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
                ld      hl,(vKI)
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
; Сохраняет BC.
famw:
                push    bc
                push    af
                call    shipset         ; HL -> FA(OS(K))
                pop     bc              ; B = m
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
                pop     bc
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
                call    setup
                ld      a,(vKL)
                or      a
                jp      z,pknorm
                ld      b,a
                ld      a,1
                ld      (vMODE),a
                ld      hl,2000
                ld      (vWT),hl
                ld      a,b
                cp      255
                jp      nz,pkone
                ld      a,1
pkall:
                ld      (vK),a
                push    af
                call    scan
                pop     af
                inc     a
                ld      hl,vNS1
                cp      (hl)
                jp      c,pkall
                jp      pkdone
pkone:
                ld      (vK),a
                call    scan
pkdone:
                xor     a
                ld      (vMODE),a
                ld      (vKL),a
pknorm:
                xor     a
                ld      (vT),a
; Клетки P9 = 13..130: указатель в HL, лучший счёт BS в BC; vBS, vP9 = 131
; и vBXW (при каждом новом лучшем) пишутся, как у оригинала.
pnshot:
                ld      bc,-1           ; BS = -1
                ld      hl,ARR_MG+2*13
pncell:
                ld      e,(hl)
                inc     hl
                ld      d,(hl)          ; DE = MG(P9)
                inc     hl
                ld      a,b             ; MG(P9) > BS (со знаком)?
                xor     d
                jp      m,pndiff
                ld      a,c             ; знаки равны: беззнаково
                sub     e
                ld      a,b
                sbc     a,d
                jp      nc,pnnext       ; равные: остаётся более ранняя
                jp      pnnew
pndiff:
                ld      a,d             ; знаки разные: больше, если MG >= 0
                or      a
                jp      m,pnnext
pnnew:
                ld      b,d
                ld      c,e
                push    hl
                ld      de,-(ARR_MG+2)  ; BXW = (HL-2 - ARR_MG)/2
                add     hl,de
                ld      a,h
                or      a
                rra
                ld      h,a
                ld      a,l
                rra
                ld      l,a
                ld      (vBXW),hl
                pop     hl
pnnext:
                ld      a,l             ; 118 слов < 256 байт: младший байт
                cp      low (ARR_MG+2*131)  ; адреса конца однозначен
                jp      nz,pncell
                ld      h,b
                ld      l,c
                ld      (vBS),hl
                ld      hl,131
                ld      (vP9),hl

                ld      hl,(vBXW)       ; BX -> столбец и строка
                ld      b,0
                ld      de,-12
pndiv:
                add     hl,de           ; CY <=> HL >= 12 (до вычитания)
                jp      nc,pndone
                inc     b
                jp      pndiv
pndone:
                ld      de,12
                add     hl,de           ; остаток
                dec     b               ; B = X
                ld      a,l
                dec     a
                ld      c,a             ; C = Y
                ld      a,(vT)
                ld      hl,ARR_TX
                call    elptr
                ld      (hl),b          ; со знаком: клетка поля даёт -1
                inc     hl
                ld      a,b
                rla
                sbc     a,a
                ld      (hl),a
                ld      a,(vT)
                ld      hl,ARR_TY
                call    elptr
                ld      (hl),c
                inc     hl
                ld      a,c
                rla
                sbc     a,a
                ld      (hl),a
                ld      hl,(vBXW)       ; MG(BX) = -9
                add     hl,hl
                ld      de,ARR_MG
                add     hl,de
                ld      (hl),-9
                inc     hl
                ld      (hl),-1
                ld      hl,vT
                inc     (hl)
                ld      a,(hl)
                ld      hl,vNF
                cp      (hl)
                jp      c,pnshot
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
                xor     a
                ld      (vC),a
extcol:
                xor     a
                ld      (vR),a
                ld      e,a
                ld      a,(vC)          ; P9 = C*12 + 13
                call    pidx
                ld      (vP9),hl
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
                ld      hl,(vP9)        ; MO(P9) не должно нести метку хода
                ld      de,MOBUF
                add     hl,de
                ld      a,(vST)
                cp      (hl)
                jp      z,extnext

                ld      hl,(vP9)        ; SC = MC(P9)*8
                ld      de,MCBUF
                add     hl,de
                ld      l,(hl)
                ld      h,0
                add     hl,hl
                add     hl,hl
                add     hl,hl
                ld      a,(vRD)
                ld      b,a
                call    jit
                ld      e,a
                ld      d,0
                add     hl,de
                ld      a,(vRIM)        ; бонусы края: случайная «личность»
                ld      b,a             ; и выученная привычка
                ld      a,(SMEMB)
                or      b
                jp      z,extsc
                ld      a,(vC)
                or      a
                jp      z,extrim
                cp      9
                jp      z,extrim
                ld      a,(vR)
                or      a
                jp      z,extrim
                cp      9
                jp      nz,extsc
extrim:
                ld      a,b             ; +192, если личность — край
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
                ld      a,(vC)
                ld      (vBX),a
                ld      a,(vR)
                ld      (vBY),a
extnext:
                ld      hl,(vP9)
                inc     hl
                ld      (vP9),hl
                ld      hl,vR
                inc     (hl)
                ld      a,(hl)
                cp      10
                jp      c,extcell
                ld      hl,vC
                inc     (hl)
                ld      a,(hl)
                cp      10
                jp      c,extcol

                ld      a,(vT)          ; TX(T) = BX, TY(T) = BY
                ld      hl,ARR_TX
                call    elptr
                ld      a,(vBX)
                ld      (hl),a
                inc     hl
                ld      (hl),0
                ld      a,(vT)
                ld      hl,ARR_TY
                call    elptr
                ld      a,(vBY)
                ld      (hl),a
                inc     hl
                ld      (hl),0
                ld      a,(vBY)         ; метка MO(BX*12 + BY + 13)
                ld      e,a
                ld      a,(vBX)
                call    pidx
                ld      de,MOBUF
                add     hl,de
                ld      a,(vST)
                ld      (hl),a
                ld      hl,vT
                inc     (hl)
                ld      a,(hl)
                ld      hl,vNF
                cp      (hl)
                jp      c,extshot
                ret

; ------------------------------------------------- USR4: маргинальные веса
; Каждый живой кандидат добавляет 2880/CC(K) (не меньше 1) своим клеткам.
@eng_marg:
                call    setup
marg:
                ld      a,1
                ld      (vK),a
mgship:
                ld      hl,ARR_CC
                call    kel16
                ld      b,d
                ld      c,e
                ld      a,b             ; кандидатов нет — нечего взвешивать
                or      c
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
                jp      c,mgship
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

; HL = HL / BC без знака (BC <> 0), сдвигом с вычитанием.  Портит A, DE.
; Оригинал делил повторным вычитанием: частное то же (при BC = 0 оригинал
; зависал бы — у нас частное FFFFh), а время не зависит от величины частного
; (6000/1 было 6000 итераций).  Остаток после k шагов < 2^k, поэтому сдвиг
; остатка на шагах 1..16 никогда не выходит за 16 бит — 17-й бит не нужен.
div16:
                ex      de,hl           ; DE = делимое -> частное
                ld      hl,0            ; остаток
                ld      a,16
dvlp:
                push    af
                ex      de,hl
                add     hl,hl           ; частное/делимое <<= 1, CY = старший бит
                ex      de,hl
                ld      a,l
                rla
                ld      l,a
                ld      a,h
                rla
                ld      h,a             ; остаток = остаток*2 + CY
                ld      a,l
                sub     c
                ld      l,a
                ld      a,h
                sbc     a,b
                ld      h,a
                jp      nc,dvone
                add     hl,bc           ; не вычлось — вернуть
                jp      dvnx
dvone:
                inc     e               ; бит частного
dvnx:
                pop     af
                dec     a
                jp      nz,dvlp
                ex      de,hl
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
                ld      hl,ARR_CC
                call    kelp
                ld      a,(hl)
                sub     1
                ld      (hl),a
                inc     hl
                ld      a,(hl)
                sbc     a,0
                ld      (hl),a
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
                ld      hl,ARR_MG
                add     hl,de
                add     hl,de
                inc     hl              ; HL -> старший байт MG(первая клетка)
                ld      a,(vSTEP)
                add     a,a
                ld      c,a             ; C = 2*шаг (24 или 2)
                ld      a,(vLK)
                ld      b,a
                ex      de,hl
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
                ld      hl,MOBUF        ; MO, MC — 288 нулей подряд, за ними FA
                ld      b,288/4
                xor     a
                call    fill4
                inc     a
                ld      b,0             ; 1024
                call    fill4
                ld      b,96/4          ; + 96 = 1120
                call    fill4
                xor     a
                ld      (vST),a
                ld      (vKL),a
                ld      (vRK),a
                ret

; --------------------------------------------- USR8: зонд + разведка
; Раненый найденный корабль — вес 25000 (добор), раненый неоднозначный —
; ОДИН зонд +12000 в клетку, делящую его кандидатов ближе всего пополам;
; остальное в MG — разведочные счета MC*8+дрожание.  BARRAGE ещё добавляет
; каждой клетке, способной добить ненайденный корабль, 6000/(need*CC).
@eng_probesel:
                call    setup
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
                cp      b
                jp      z,psnext
                ld      c,a
                ld      a,(eng_bar)
                or      a
                jp      z,ps1
                ld      a,c
                sub     b               ; SZ-PH: попаданий ещё нужно
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
                ld      c,e             ; BARRAGE: вес 6000/CC/need
                ld      b,d
                ld      hl,6000
                call    div16
                ld      a,(vNEED)
                ld      c,a
                ld      b,0
                call    div16
                call    scanwt
psp2:
                call    clrmo
                ld      a,2
                call    scanm
                ld      hl,-1
                ld      (vBS),hl
                ld      hl,13
pscell:
                ld      (vP9),hl
                call    mgat
                inc     hl
                ld      a,(hl)
                rla
                jp      c,pscnext       ; клетка вне игры
                ld      hl,(vP9)
                ld      de,MOBUF
                add     hl,de
                ld      a,(hl)
                or      a
                jp      z,pscnext
                add     a,a             ; 2n (в байте, как в оригинале)
                ld      e,a
                ld      d,0
                ld      hl,(vCCK)
                ld      a,e             ; BC = 2n - CC
                sub     l
                ld      c,a
                ld      a,d
                sbc     a,h
                ld      b,a
                jp      nc,psabs
                ld      a,c             ; |2n - CC|
                cpl
                ld      c,a
                ld      a,b
                cpl
                ld      b,a
                inc     bc
psabs:
                ld      hl,(vBS)
                ld      a,c
                sub     l
                ld      a,b
                sbc     a,h             ; CY <=> |d| < BS
                jp      nc,pscnext
                ld      h,b
                ld      l,c
                ld      (vBS),hl
                ld      hl,(vP9)
                ld      (vBXW),hl
pscnext:
                ld      hl,(vP9)
                inc     hl
                ld      a,l
                cp      131
                jp      nz,pscell
                ld      (vP9),hl
                ld      hl,(vBS)
                ld      a,h
                and     l
                inc     a
                jp      z,psnext        ; ни одной клетки
                ld      hl,(vBXW)       ; MG(BX) += 12000
                call    mgat
                ld      e,(hl)
                inc     hl
                ld      d,(hl)
                push    hl
                ld      hl,12000
                add     hl,de
                ex      de,hl
                pop     hl
                ld      (hl),d
                dec     hl
                ld      (hl),e
psnext:
                call    nextk
                jp      c,psship
                ret

; HL = ARR_MG + 2*HL (-> слово MG).  Портит BC.
mgat:
                add     hl,hl
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
                xor     a
                ld      (vC),a
mmc:
                xor     a
                ld      (vR),a
mmr:
                call    pmtest
                jp      nz,mmnext
                ld      hl,0
                ld      a,(vSMC)
                or      a
                jp      z,mmj
                call    padidx
                ld      de,MCBUF
                add     hl,de
                ld      l,(hl)
                ld      h,0
                add     hl,hl
                add     hl,hl
                add     hl,hl           ; MC*8
mmj:
                push    hl
                ld      a,(vRDS)
                ld      b,a
                call    jit
                pop     hl
                ld      e,a
                ld      d,0
                add     hl,de
                push    hl
                call    padidx
                add     hl,hl
                ld      de,ARR_MG
                add     hl,de
                pop     de
                ld      (hl),e
                inc     hl
                ld      (hl),d
mmnext:
                ld      hl,vR
                inc     (hl)
                ld      a,(hl)
                cp      10
                jp      c,mmr
                ld      hl,vC
                inc     (hl)
                ld      a,(hl)
                cp      10
                jp      c,mmc
                ret

; A = (C*5 + R*3 + B) AND 7.  Портит C, E.
jit:
                ld      a,(vC)
                ld      c,a
                add     a,a
                add     a,a
                add     a,c             ; C*5
                ld      c,a
                ld      a,(vR)
                ld      e,a
                add     a,a
                add     a,e             ; R*3
                add     a,c
                add     a,b
                and     7
                ret

; HL = 2*(vC + 10*vR) — смещение клетки в массиве 10x10;
; Z = PM(C,R) = 0.  HL сохраняется, портит A, DE.
pmtest:
                ld      a,(vR)
                ld      l,a
                add     a,a
                add     a,a
                add     a,l
                add     a,a             ; 10R (R <= 9)
                ld      l,a
                ld      a,(vC)
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
; элемент массива по номеру корабля: kel16 — DE = X(vK), kel — A = X(vK)
; (младший байт), kelp — HL -> X(vK); HL = база массива.  Сохраняют BC.
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

kelp:
                ld      a,(vK)
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
                ld      bc,ARR_MG
                add     hl,bc
                ret

; HL = индекс с полями для (vC,vR) = C*12 + R + 13.  Сохраняет BC.
padidx:
                ld      a,(vR)
                ld      e,a
                ld      a,(vC)
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
                call    setup
                call    sortso
                xor     a
                call    mgseedx         ; MG = -1 / дрожание
                xor     a
                ld      (vGG),a
                ld      a,6
                ld      (vSA),a
smploop:
                ld      a,(vGG)
                cp      3
                jp      nc,smpend
                call    onesamp
                ld      hl,vSA
                dec     (hl)
                jp      nz,smploop
smpend:
                ld      a,(vGG)
                cp      3
                ret     nc
                jp      marg

; --- SO[0..NSHIPS-1] = номера кораблей по возрастанию CC
sortso:
                ld      hl,vSOA
                ld      a,(vNS1)
                dec     a
                ld      b,a             ; NSHIPS
                ld      a,1
ss0:
                ld      (hl),a
                inc     hl
                inc     a
                dec     b
                jp      nz,ss0
                xor     a
                ld      (vSI),a
ssi:
                ld      a,(vSI)
                inc     a
                ld      (vSJ),a
ssj:
                ld      a,(vSJ)
                inc     a
                ld      hl,vNS1
                cp      (hl)            ; SJ < NSHIPS
                jp      nc,ssinext
                ld      a,(vSJ)
                call    ccof
                ld      (vSCJ),hl
                ld      a,(vSI)
                call    ccof
                ex      de,hl           ; DE = CC(SO[I])
                ld      hl,(vSCJ)       ; HL = CC(SO[J])
                ld      a,l
                sub     e
                ld      a,h
                sbc     a,d
                jp      nc,ssjnext      ; CC(SO[J]) >= CC(SO[I])
                ld      a,(vSI)         ; поменять местами
                ld      e,a
                ld      d,0
                ld      hl,vSOA
                add     hl,de
                push    hl
                ld      a,(vSJ)
                ld      e,a
                ld      hl,vSOA
                add     hl,de
                pop     de
                ld      a,(de)
                ld      c,(hl)
                ld      (hl),a
                ld      a,c
                ld      (de),a
ssjnext:
                ld      hl,vSJ
                inc     (hl)
                jp      ssj
ssinext:
                ld      hl,vSI
                inc     (hl)
                ld      a,(hl)
                inc     a
                inc     a
                ld      hl,vNS1
                cp      (hl)            ; SI < NSHIPS-1
                jp      c,ssi
                ret

; A = номер слота -> HL = CC(SO[A])
ccof:
                ld      e,a
                ld      d,0
                ld      hl,vSOA
                add     hl,de
                ld      a,(hl)
                ld      hl,ARR_CC
                call    getel16
                ex      de,hl
                ret

; --- одна совместная выборка: поставить все корабли, затем зачесть клетки
onesamp:
                xor     a
                ld      (vQNC),a
                call    bumpst
                ld      a,(vNS1)
                dec     a
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
                or      a
                ret     z               ; [одна сторона: после удачной выборки QNC = сумма длин >= 5]
                ld      b,a
                ld      hl,vZX
osadd:
                push    bc
                ld      e,(hl)
                inc     hl
                ld      d,(hl)
                inc     hl
                push    hl
                ex      de,hl
                add     hl,hl
                ld      de,ARR_MG
                add     hl,de
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
                call    pldraw          ; vJ0 <- равномерно среди ЖИВЫХ
                jp      c,plnext        ; живых нет
                call    decode          ; vJ0 -> vIBB, vS9
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
plrdo:
                call    pldraw
                jp      c,plrgive       ; [одна сторона: первый pldraw удался, CC не менялся — живой есть]
                call    decode
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
                jp      plok
plnext:
                ld      hl,vT2
                dec     (hl)
                jp      nz,platt
                scf
                ret
plok:
                ld      a,(vLK)         ; записать клетки корабля в vZX
                ld      b,a
                ld      hl,(vIBB)
                ld      (vP9),hl
                ld      a,(vQNC)
                ld      e,a
                ld      d,0
                ld      hl,vZX
                add     hl,de
                add     hl,de
                ex      de,hl           ; DE -> слот ZX
plrec:
                ld      hl,(vP9)
                ex      de,hl           ; HL -> слот, DE = клетка
                ld      (hl),e
                inc     hl
                ld      (hl),d
                inc     hl
                push    hl
                ld      hl,(vS9)
                add     hl,de
                ld      (vP9),hl
                pop     de
                ld      hl,vQNC
                inc     (hl)
                dec     b
                jp      nz,plrec

                ld      hl,(vS9)        ; W2 = 13 - S9: боковой сосед
                ld      b,h
                ld      c,l
                ld      a,13
                sub     c
                ld      l,a
                ld      a,0
                sbc     a,b
                ld      h,a
                ld      (vW2),hl
                ld      hl,(vIBB)       ; метить от IB - S9, LK + 2 клеток
                ld      a,l
                sub     c
                ld      l,a
                ld      a,h
                sbc     a,b
                ld      h,a
                ld      de,MOBUF
                add     hl,de
                ld      a,(vLK)
                add     a,2
                ld      b,a
                ld      a,(vST)
                ld      c,a
plstamp:
                ld      (hl),c
                ex      de,hl           ; DE = p
                ld      hl,(vW2)
                ld      a,e
                sub     l
                ld      l,a
                ld      a,d
                sbc     a,h
                ld      h,a
                ld      (hl),c          ; p - W2
                ld      hl,(vW2)
                add     hl,de
                ld      (hl),c          ; p + W2
                ld      hl,(vS9)
                add     hl,de           ; p + S9
                dec     b
                jp      nz,plstamp
                or      a
                ret

; шаг xorshift над HL (портит A, D); тело rnd16 — оно же в цикле отбраковки
; pldraw, где семя живёт в HL (ненулевое семя в ноль не переходит: все три
; шага обратимы, поэтому проверка на 0 нужна только на первом шаге)
                MACRO   ENG_XSHIFT
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
                ENDM

; Равномерный выбор среди ЖИВЫХ кандидатов корабля vK: r в [0, CC), затем
; r-й живой флаг FA.  CY только при CC = 0.  CC обязан равняться числу
; живых флагов (его ведёт fold).
pldraw:
                ld      a,(vK)
                ld      hl,ARR_CC
                call    getel16
                ld      a,d
                or      e
                jp      nz,pld1
                scf
                ret
pld1:
                ld      c,e             ; CC <= 180 — байт
                call    rnd16
                ld      a,l
                cp      c
                jp      c,pldok
pldr:
                ENG_XSHIFT                  ; следующий rnd16 — семя в HL
                ld      a,l
                cp      c
                jp      nc,pldr         ; r в [0, CC)
                ld      (vSEED),hl
pldok:
                inc     a
                ld      b,a             ; остановиться на (r+1)-м живом
                ld      hl,(vOSK)
                ld      de,FABUF
                add     hl,de
pldscan:
                ld      a,(hl)
                inc     hl
                or      a
                jp      z,pldscan
                dec     b
                jp      nz,pldscan
                dec     hl
pldhit:
                ld      a,(vOSK)        ; J0 = мл. байт (ptr - FABUF - OS(K))
                ld      b,a
                ld      a,l
                sub     low FABUF
                sub     b
                ld      (vJ0),a
                or      a
                ret

; vJ0 (номер кандидата внутри корабля) -> vIBB, vS9, vC, vR
decode:
                ld      a,(vJ0)
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
                add     a,a
                add     a,a
                add     a,c
                add     a,a             ; 10W
                ld      b,a
                ld      a,l
                sub     b
                jp      c,jdacr
                ld      l,a             ; вниз: X = j'/W, Y = j' mod W
                call    divsm
                ld      d,a
                ld      b,1
                jp      jdfin
jdacr:
                call    divsm           ; поперёк: Y = j/W, X = j mod W
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
                ld      a,(vS9)
                cp      12
                ld      a,(vC)
                ld      b,a
                ld      a,(vR)
                jp      z,rck1
                ld      c,a             ; вниз: поменять оси
                ld      a,b
                ld      b,c
rck1:                                   ; A = поперечная ось, B = продольная
                or      a
                ret     z
                cp      9
                ret     z
                ld      a,b
                or      a
                ret     z
                ld      c,a
                ld      a,(vLK)
                add     a,c
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
                ENG_XSHIFT
                ld      (vSEED),hl
                ret

eng_code_end:
                ASSERT  eng_code_end - eng_code_start <= 3584

                ENDMODULE
