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
; Идиомы замены: djnz -> dec b/jp nz (dec b ставит Z, но не трогает CY;
; djnz не трогал ничего — после каждой замены проверено, что за циклом флаги
; не читаются); jr -> jp; sbc hl,rr -> вычитание через A; ld rr,(nn) для
; BC/DE -> через HL и ex de,hl; ldir -> fillb.
; ============================================================================

                MODULE  engine

eng_code_start:

NSH_CL          equ     5               ; кораблей в SALVO / BARRAGE
NSH_SP          equ     7               ; кораблей в SALVO PLUS

; ---------------------------------------------------------------- пролог
; vNS1 = NSHIPS+1 по флагу eng_sp (заменяет константу NSHIPS оригинала)
setup:
                ld      a,(eng_sp)
                or      a
                ld      a,NSH_CL+1
                jp      z,setup1
                ld      a,NSH_SP+1
setup1:
                ld      (vNS1),a
                ret

; HL = адрес, B = число байт (0 = 256), A = значение.  Сохраняет C, DE.
fillb:
                ld      (hl),a
                inc     hl
                dec     b
                jp      nz,fillb
                ret

; карта выстрелов живёт в первых 144 байтах MG; её чистят только fold и kill1
clrmap:
                ld      hl,ARR_MG
                ld      b,144
                xor     a
                jp      fillb

; плоскость меток MO
clrmo:
                ld      hl,MOBUF
                ld      b,144
                xor     a
                jp      fillb

; ST = ST + 1 с переносом: 0 значит «не помечено», при переполнении плоскость
; стирается и счёт начинается с 1
bumpst:
                ld      a,(vST)
                inc     a
                jp      nz,bst1
                call    clrmo
                ld      a,1
bst1:
                ld      (vST),a
                ret

; ---------------------------------------------------------------- USR0: fold
@eng_fold:
                push    hl
                call    setup
                call    clrmap
                xor     a
                ld      (vMODE),a
                pop     hl
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
                ld      a,(vK)
                ld      hl,ARR_HK
                call    getel
                ld      (vH),a
                call    scan
                ld      hl,vK
                inc     (hl)
                ld      a,(hl)
                inc     hl              ; vNS1
                cp      (hl)
                jp      c,fship
                ret

; ------------------------------------------------- USR1: снять покрытие клетки
@eng_kill1:
                push    hl
                call    setup
                call    clrmap
                xor     a
                ld      (vMODE),a
                pop     hl
                ld      a,h
                ld      (vK),a
                ld      a,l
                rrca
                rrca
                rrca
                rrca
                and     0Fh
                ld      d,a
                ld      a,l
                and     0Fh
                ld      e,a
                call    mapptr
                ld      (hl),1
                xor     a
                ld      (vH),a
                jp      scan

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
pnshot:
                ld      hl,-1           ; BS = -1
                ld      (vBS),hl
                ld      hl,13
                ld      (vP9),hl
pncell:
                ld      hl,(vP9)
                add     hl,hl
                ld      de,ARR_MG
                add     hl,de
                ld      e,(hl)
                inc     hl
                ld      d,(hl)          ; DE = MG(P9)
                ld      hl,(vBS)
                call    sgt             ; CY: MG(P9) > BS (со знаком)
                jp      nc,pnnext       ; равные: остаётся более ранняя
                ex      de,hl
                ld      (vBS),hl
                ld      hl,(vP9)
                ld      (vBXW),hl
pnnext:
                ld      hl,(vP9)
                inc     hl
                ld      (vP9),hl
                ld      a,l             ; P9 идёт 13..131, H = 0
                cp      131
                jp      nz,pncell

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
                ld      (vMODE),a
                ld      (vK),a
mgship:
                ld      a,(vK)
                ld      hl,ARR_CC
                call    elptr
                ld      c,(hl)
                inc     hl
                ld      b,(hl)
                ld      a,b             ; кандидатов нет — нечего взвешивать
                or      c
                jp      z,mgnext
                ld      hl,2880
                call    div16
                ld      a,h
                or      l
                jp      nz,mgok
                ld      hl,1
mgok:
                ld      (vWT),hl
                call    scan
mgnext:
                ld      hl,vK
                inc     (hl)
                ld      a,(hl)
                inc     hl              ; vNS1
                cp      (hl)
                jp      c,mgship
                xor     a
                ld      (vMODE),a
                ret

; HL = HL / BC без знака (BC <> 0), сдвигом с вычитанием.  Портит A, DE.
; Оригинал делил повторным вычитанием: частное то же, а время не зависит
; от величины частного (6000/1 было 6000 итераций).
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
                jp      c,dvsub         ; 17-й бит: остаток заведомо >= BC
                ld      a,l
                sub     c
                ld      l,a
                ld      a,h
                sbc     a,b
                ld      h,a
                jp      nc,dvone
                add     hl,bc           ; не вычлось — вернуть
                jp      dvnx
dvsub:
                ld      a,l
                sub     c
                ld      l,a
                ld      a,h
                sbc     a,b
                ld      h,a
dvone:
                inc     e               ; бит частного
dvnx:
                pop     af
                dec     a
                jp      nz,dvlp
                ex      de,hl
                ret

; ---------------------------------------------------------------- scan: корабль K
scan:
                ld      a,(vK)
                ld      hl,ARR_SZ
                call    getel
                ld      (vLK),a
                ld      b,a
                ld      a,11
                sub     b
                ld      (vW),a

                ld      a,(vK)
                ld      hl,ARR_OS
                call    getel16
                ld      hl,FABUF
                add     hl,de
                ld      (vFAP),hl

; --- поперёк: Y внешний 0..9, X внутренний 0..W-1, индекс с 13, +12 на X
                ld      hl,12
                ld      (vSTEP),hl
                ld      de,13
                ld      c,10
sacross:
                ld      a,(vW)
                ld      b,a
                push    de
sacell:
                push    bc
                push    de
                call    cand
                pop     de
                ld      hl,12
                add     hl,de
                ex      de,hl
                pop     bc
                dec     b
                jp      nz,sacell
                pop     de
                inc     de              ; тот же X=0, следующий Y
                dec     c
                jp      nz,sacross

; --- вниз: X внешний 0..9, Y внутренний 0..W-1, индекс с 13, +1 на Y
                ld      hl,1
                ld      (vSTEP),hl
                ld      de,13
                ld      c,10
sdown:
                ld      a,(vW)
                ld      b,a
                push    de
sdcell:
                push    bc
                push    de
                call    cand
                pop     de
                inc     de
                pop     bc
                dec     b
                jp      nz,sdcell
                pop     de
                ld      hl,12
                add     hl,de           ; следующий столбец X
                ex      de,hl
                dec     c
                jp      nz,sdown
                ret

; ---------------------------------------------------------------- кандидат
; DE = индекс первой клетки; vFAP -> FA(I); vSTEP = шаг
cand:
                ld      hl,(vFAP)
                ld      a,(hl)
                or      a
                jp      z,cdone
                ld      a,(vMODE)
                cp      2
                jp      z,candn1
                or      a
                jp      nz,candmg

                ex      de,hl           ; режим 0: сумма карты выстрелов
                ld      (vIDX),hl
                ld      de,ARR_MG
                add     hl,de
                ex      de,hl
                ld      hl,(vSTEP)
                ex      de,hl           ; HL -> карта, DE = шаг
                ld      a,(vLK)
                ld      b,a
                xor     a
covsum:
                add     a,(hl)
                add     hl,de
                dec     b
                jp      nz,covsum
                ld      hl,vH
                cp      (hl)
                jp      z,cdone

                ld      hl,(vFAP)       ; убить кандидата
                ld      (hl),0
                ld      a,(vK)
                ld      hl,ARR_CC
                call    elptr
                ld      a,(hl)
                sub     1
                ld      (hl),a
                inc     hl
                ld      a,(hl)
                sbc     a,0
                ld      (hl),a
                ld      hl,(vSTEP)
                ex      de,hl
                ld      hl,(vIDX)
                ld      bc,MCBUF
                add     hl,bc
                ld      a,(vLK)
                ld      b,a
mcloop:
                dec     (hl)
                add     hl,de
                dec     b
                jp      nz,mcloop
                jp      cdone

; режим 2 (probesel): число живых кандидатов на клетку — байтами в MO
candn1:
                ld      hl,MOBUF
                add     hl,de
                ex      de,hl
                ld      hl,(vSTEP)
                ex      de,hl
                ld      a,(vLK)
                ld      b,a
n1cell:
                inc     (hl)
                add     hl,de
                dec     b
                jp      nz,n1cell
                jp      cdone

; режим 1: добавить вес vWT каждой покрытой клетке MG, ещё не запрещённой
; (отрицательные клетки вне игры).  Сумма НЕ насыщается — бюджет весов
; расписан в fold.asm оригинала у candmg.
candmg:
                ld      hl,ARR_MG
                add     hl,de
                add     hl,de
                ex      de,hl
                ld      hl,(vSTEP)
                add     hl,hl
                ex      de,hl           ; HL -> MG, DE = 2*шаг
                ld      a,(vLK)
                ld      b,a
mgcell:
                inc     hl
                ld      a,(hl)
                dec     hl
                rla                     ; знак: клетка вне игры
                jp      c,mgskip
                push    de
                ld      e,(hl)
                inc     hl
                ld      d,(hl)
                push    hl
                ld      hl,(vWT)
                add     hl,de
                ex      de,hl
                pop     hl
                ld      (hl),d
                dec     hl
                ld      (hl),e
                pop     de
mgskip:
                add     hl,de
                dec     b
                jp      nz,mgcell
cdone:
                ld      hl,(vFAP)
                inc     hl
                ld      (vFAP),hl
                ret

; ------------------------------------------------- USR7: сброс кандидатов
; Начало партии: все кандидаты живы, MC и MO чисты, метка хода 0.
; FA заполняется на все 1120 байт (в SALVO/BARRAGE используются 760).
@eng_fainit:
                ld      hl,FABUF
                ld      a,1
                ld      c,7
fai1:
                ld      b,160           ; 7*160 = 1120
                call    fillb
                dec     c
                jp      nz,fai1
                ld      hl,MCBUF
                ld      b,144
                xor     a
                call    fillb
                call    clrmo
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
                ld      a,(vK)
                ld      hl,ARR_PH
                call    getel
                or      a
                jp      z,psnext
                ld      b,a
                ld      a,(vK)
                ld      hl,ARR_SZ
                call    getel
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
                ld      a,(vK)
                ld      hl,ARR_CC
                call    getel16
                ex      de,hl
                ld      (vCCK),hl
                ex      de,hl
                ld      a,d
                or      a
                jp      nz,psprobe
                ld      a,e
                cp      1
                jp      nz,psprobe
                ld      a,1             ; найден: добор
                ld      (vMODE),a
                ld      hl,25000
                ld      (vWT),hl
                call    scan
                xor     a
                ld      (vMODE),a
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
                ld      (vWT),hl
                ld      a,1
                ld      (vMODE),a
                call    scan
                xor     a
                ld      (vMODE),a
psp2:
                call    clrmo
                ld      a,2
                ld      (vMODE),a
                call    scan
                xor     a
                ld      (vMODE),a
                ld      hl,-1
                ld      (vBS),hl
                ld      hl,13
                ld      (vP9),hl
pscell:
                ld      hl,(vP9)
                add     hl,hl
                ld      de,ARR_MG
                add     hl,de
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
                ld      (vP9),hl
                ld      a,l
                cp      131
                jp      nz,pscell
                ld      hl,(vBS)
                ld      a,h
                and     l
                inc     a
                jp      z,psnext        ; ни одной клетки
                ld      hl,(vBXW)       ; MG(BX) += 12000
                add     hl,hl
                ld      de,ARR_MG
                add     hl,de
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
                ld      hl,vK
                inc     (hl)
                ld      a,(hl)
                inc     hl              ; vNS1
                cp      (hl)
                jp      c,psship
                ret

; ------------------------------------------------ MG = -1, затем счета клеток
; A = 0: живым клеткам дрожание (mgseed сэмплера)
; A = 1: живым клеткам MC*8 + дрожание (mgseedmc probesel)
; Обстрелянные клетки (PM <> 0) и поля остаются -1.
mgseedx:
                ld      (vSMC),a
                ld      hl,ARR_MG
                ld      a,0FFh
                ld      b,0
                call    fillb           ; 256 байт
                ld      b,32
                call    fillb           ; + 32 = 288
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
elptr:
                ld      e,a
                ld      d,0
                add     hl,de
                add     hl,de
                ret

getel:
                call    elptr
                ld      a,(hl)
                ret

getel16:
                call    elptr
                ld      e,(hl)
                inc     hl
                ld      d,(hl)
                ret

; HL = ARR_MG + (D+1)*12 + (E+1)   (D+1, E+1 — в байте, как в оригинале)
mapptr:
                ld      a,d
                inc     a
                ld      l,a
                ld      h,0
                add     hl,hl
                add     hl,hl
                ld      b,h
                ld      c,l
                add     hl,hl
                add     hl,bc
                ld      a,e
                inc     a
                ld      c,a
                ld      b,0
                add     hl,bc
                ld      bc,ARR_MG
                add     hl,bc
                ret

; HL = индекс с полями для (vC,vR) = C*12 + R + 13.  Сохраняет BC.
padidx:
                ld      a,(vR)
                ld      e,a
                ld      a,(vC)
; HL = A*12 + E + 13 (16 бит).  Сохраняет BC, портит DE.
pidx:
                ld      d,0
                push    de              ; E = строка
                ld      l,a
                ld      h,d
                add     hl,hl
                add     hl,hl           ; 4A
                ld      d,h
                ld      e,l
                add     hl,hl
                add     hl,de           ; 12A
                pop     de
                add     hl,de
                ld      de,13
                add     hl,de
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
                ret     z
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
                ld      a,(vK)
                ld      hl,ARR_SZ
                call    getel
                ld      (vLK),a
                ld      b,a
                ld      a,11
                sub     b
                ld      (vW),a
                ld      a,(vK)
                ld      hl,ARR_OS
                call    getel16
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
                jp      c,plrgive
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
pldr:
                call    rnd16
                ld      a,l
                cp      c
                jp      nc,pldr         ; r в [0, CC)
                inc     a
                ld      b,a             ; остановиться на (r+1)-м живом
                ld      hl,(vOSK)
                ld      de,FABUF
                add     hl,de
pldscan:
                ld      a,(hl)
                or      a
                jp      z,pldnx
                dec     b
                jp      z,pldhit
pldnx:
                inc     hl
                jp      pldscan
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
                ld      a,(vW)
                ld      b,a
                add     a,a
                add     a,a
                add     a,a
                add     a,b
                add     a,b             ; 10*W
                ld      c,a
                ld      a,(vJ0)
                cp      c
                jp      nc,decdown
                ld      a,(vW)          ; поперёк: Y = J0/W, X = J0-Y*W
                ld      c,a
                ld      a,(vJ0)
                ld      l,a
                call    divsm
                ld      (vR),a          ; Y
                ld      a,e
                ld      (vC),a          ; X
                ld      hl,12
                jp      decfin
decdown:
                sub     c               ; вниз: X = J/W, Y = J-X*W
                ld      l,a
                ld      a,(vW)
                ld      c,a
                call    divsm
                ld      (vC),a          ; X
                ld      a,e
                ld      (vR),a          ; Y
                ld      hl,1
decfin:
                ld      (vS9),hl
                call    padidx
                ld      (vIBB),hl
                ret

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
                ld      a,h
                or      a
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
