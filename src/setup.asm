; ============================================================================
; setup.asm — перевод ref/ironclad-msx/SETUP.BAS (меню). Метка Snnnn = строка nnnn.
; ============================================================================

; Оверлей: исполняется с OVL_BASE (см. main.asm), вход — S110 (из setup_run, game.asm).
S110:       ld   a,15                   ; SCREEN 5: COLOR 15,1,1
            ld   (gfx_fg),a
            ld   a,5                    ; 3406: COLOR 1,5,5 — фон текста 5
            ld   (gfx_bg),a
S120:       SETV bDL,3  ; RP=0: DL=3: ...
S140:       call S3406
S150:       call S3500
S155:                                   ; панель загрузки (3800, 155) убрана по решению владельца
S162:       ld   bc,t_cfgv              ; POKE настроек в «&HDDF5..&HE00»
            ld   hl,cfg_TU
S162a:      ld   a,(bc)
            ld   e,a
            ld   d,high varpage
            ld   a,(de)
            ld   (hl),a
            inc  hl
            inc  bc
            ld   a,c
            cp   low (t_cfgv+10)
            jp   nz,S162a
            LDV  bBD                ; -(BD>0)
            or   a
            jp   z,S164
            ld   a,1
S164:       STV  cfg_BD
            SETV cfg_magic,165
            SETV cfg_magic+1,195
S166:       LDV  bBD                ; RUN BARRAGE/SALVOP/SALVO/IRONCLAD
            STV  cfg_fam
            call foot_clr               ; подвал меню — только в меню
            jp   game_run


; 3406: палитра, титул с диска на страницу 0 (пока видна пустая страница 1 цветом 5)
S3406:      call disp_blank
            ld   hl,cmap_menu           ; COLOR 1,5,5: 3430 (8 слотов меню, бордюр — слот 0 = цвет 5)
            ld   (cur_cmap),hl
            xor  a
            ld   (vec_border),a
            ld   hl,pal_menu
            call pal_set
            IFNDEF NOTITLE
            ld   hl,img_title           ; BLOAD "IRONCLAD.SC5" (окно меню уже стёрто, QR — отдельно)
            ld   de,8000h
            call dzx0
            ELSE
            ld   bc,0                   ; без файла (ON ERROR GOTO 3424): пустая страница цветом 5
            ld   de,255*256+211
            ld   a,5
            call gfx_fill
            ENDIF
            ld   a,(gfx_fg)             ; подвал под картинкой (строки MSX 212..233): автор и версия
            push af
            ld   a,PC
            ld   (gfx_fg),a
            ld   bc,20*256+216
            call gfx_pset               ; (y >= 212 — точку не ставит, только курсор)
            call putsi
            TXT  "ИГРА МЕХМЕТА БЕЛГИНА, "
            call putsi
            include "../build/data/version.inc"
            pop  af
            ld   (gfx_fg),a
            SETV pg_vis,2
            jp   disp_on

; стереть подвал меню: строки памяти 10..17 (MSX y 216..223) всех плоскостей — цвет фона
foot_clr:   ld   hl,8000h+17
fcl_1:      ld   b,8
            xor  a
fcl_2:      ld   (hl),a
            dec  l
            dec  b
            jp   nz,fcl_2
            ld   l,17
            inc  h
            ld   a,h
            cp   0E0h
            jp   nz,fcl_1
            ret

; 3500: меню
S3500:      ld   a,1                    ; COLOR 1: PF=5: PE=3: PK=1: PC=3
            ld   (gfx_fg),a
            ZEROV bMI
            call S3600
                                        ; 3502 «LOADING V1.4 ...» убрана: загрузки с диска нет (версия — у подписи автора)
            call S3520
S3503:      call L3330
S3504:      call S3540
            CPV  bMG,1
            ret  z
            call S3526
            jp   S3504

; 3512: PSET(X,Y),KL: PRINT A$;":";: PSET(CX+16,Y),VL: PRINT B$ — HL = A$, DE = B$, B = CX, C = Y
S3512:      push de
            push bc
            push hl
            call str_len
            add  a,a
            add  a,a
            add  a,a
            ld   e,a
            pop  hl
            pop  bc
            push bc
            push hl
            ld   a,b
            sub  e
            ld   b,a
            ld   a,PK
            call gfx_pset
            pop  hl
            call gfx_puts
            ld   a,':'
            call gfx_putc
            pop  bc
            ld   a,b
            add  a,16
            ld   b,a
            ld   a,PC
            call gfx_pset
            pop  hl
            jp   gfx_puts

PF          equ 5
PE          equ 3
PK          equ 1
PC          equ 3

; 3520: окно меню
S3520:      ld   bc,34*256+150
            ld   de,222*256+210
            ld   a,PF
            call gfx_fill
            ld   bc,34*256+150
            ld   de,222*256+210
            ld   a,PE
            call gfx_box
            ld   hl,s_q                 ; «?: ПРАВИЛА» по центру окна (выхода в BASIC у Вектора нет)
            ld   de,s_rules
            ld   bc,96*256+198
            call S3512
            ; fallthrough
; 3526: строки RULESET / MATCH
S3526:      ld   bc,38*256+156
            ld   de,218*256+192
            ld   a,PF
            call gfx_fill
            ZEROV bI
S3527:      SETV bCL,PC  ; CL=PC: IF I=MI THEN CL=PK
            LDV  bMI
            ld   b,a
            LDV  bI
            cp   b
            jp   nz,S3528
            SETV bCL,PK
S3528:      SETV bYP,160  ; YR=160: IF I=1 THEN YR=182
            LDV  bI
            or   a
            jp   z,S3530
            SETV bYP,182
S3530:      LDV  bMI                ; IF I=MI THEN LINE(40,YR-3)-(212,YR+10),PE,B
            ld   b,a
            LDV  bI
            cp   b
            jp   nz,S3531
            LDV  bYP
            sub  3
            ld   c,a
            add  a,13
            ld   e,a
            ld   b,40
            ld   d,212
            ld   a,PE
            call gfx_box
S3531:      LDV  bYP                ; PSET(44,YR),CL: PRINT MID$("RULESETMATCH",I*7+1,7)
            ld   c,a
            ld   b,44
            LDV  bCL
            call gfx_pset
            ld   hl,s_ruleset
            LDV  bI
            or   a
            jp   z,S3531a
            ld   hl,s_match
S3531a:     call gfx_puts
            INCV bI
            ld   a,(hl)
            cp   2
            jp   c,S3527
S3533:      ld   hl,(sRN)               ; XV=157-4*LEN(RN$): PSET(XV,160),2: PRINT RN$
            ld   c,160
            call S3533p
            ld   hl,(sBM)
            ld   c,182
S3533p:     push bc
            push hl
            call str_len
            add  a,a
            add  a,a
            ld   b,a
            ld   a,157
            sub  b
            ld   b,a
            pop  hl
            pop  de
            push de
            push hl
            ld   c,e
            ld   a,2
            call gfx_pset
            pop  hl
            call gfx_puts
            pop  bc                     ; X=105: X2=205: GOSUB 3590
; 3590: треугольники-стрелки: FOR I=0 TO 3: LINE(X+I,Y+3-I)-(X+I,Y+3+I),2: LINE(X2+3-I,...)
S3590:      ld   a,c
            STV  bY0
            ZEROV bJ
S3590a:     LDV  bJ
            ld   b,a
            LDV  bY0
            add  a,3
            sub  b
            ld   c,a
            LDV  bY0
            add  a,3
            add  a,b
            ld   e,a
            ld   a,105
            add  a,b
            ld   b,a
            ld   d,a
            push bc
            push de
            ld   a,2
            call gfx_fill
            pop  de
            pop  bc
            LDV  bJ
            ld   b,a
            ld   a,208
            sub  b
            ld   b,a
            ld   d,a
            ld   a,2
            call gfx_fill
            INCV bJ
            ld   a,(hl)
            cp   4
            jp   c,S3590a
            ret

; 3540: клавиши меню
S3540:      ZEROV bMG
            call getkey
            STV  bK_
S3544:      cp   30
            jp   nz,S3546
            LDV  bMI
            dec  a
            jp   p,S3544a
            ld   a,1
S3544a:     STV  bMI
            ret
S3546:      cp   31
            jp   nz,S3548
            LDV  bMI
            inc  a
            cp   2
            jp   c,S3546a
            xor  a
S3546a:     STV  bMI
            ret
S3548:      cp   28
            jp   z,S3560
S3550:      CPV  bK_,29
            jp   z,S3580
S3551:      cp   '?'
            jp   nz,S3552
            jp   S3700
S3552:      cp   ' '
            jp   z,S3552a
            cp   13
            ret  nz
S3552a:     SETV bMG,1
            ret
S3560:      LDV  bMI                ; вправо: RP+1 / BI+1 с переносом
            or   a
            jp   nz,S3562
            LDV  bRP
            inc  a
            cp   7
            jp   c,S3560a
            xor  a
S3560a:     STV  bRP
            jp   S3600
S3562:      LDV  bBI
            inc  a
            cp   4
            jp   c,S3562a
            xor  a
S3562a:     STV  bBI
            jp   S3600
S3580:      LDV  bMI                ; влево
            or   a
            jp   nz,S3582
            LDV  bRP
            dec  a
            jp   p,S3580a
            ld   a,6
S3580a:     STV  bRP
            jp   S3600
S3582:      LDV  bBI
            dec  a
            jp   p,S3582a
            ld   a,3
S3582a:     STV  bBI
            jp   S3600

; 3600: данные набора правил RP, матч BI
S3600:      LDV  bRP
            ld   hl,rules_tab
            ld   b,a
            or   a
            jp   z,S3600b
S3600a:     ld   de,RT_SIZE
            add  hl,de
            dec  b
            jp   nz,S3600a
S3600b:     ld   (bRT),hl
            ld   e,(hl)                 ; RN$
            inc  hl
            ld   d,(hl)
            inc  hl
            ex   de,hl
            ld   (sRN),hl
            ex   de,hl
            ld   de,rt_vars             ; TU,AM,XS,SV,FL,QS,BD — по своим переменным
            ld   b,7
S3600c:     push bc
            ld   a,(de)
            ld   c,a
            inc  de
            ld   a,(de)
            ld   b,a
            inc  de
            ld   a,(hl)
            ld   (bc),a
            inc  hl
            pop  bc
            dec  b
            jp   nz,S3600c
S3602:      SETV bDL,3  ; DL=3: IF RP=6 THEN DL=1
            CPV  bRP,6
            jp   nz,S3606
            SETV bDL,1
S3606:      LDV  bBI                ; BO, SB, BM$
            add  a,a
            add  a,a
            ld   hl,match_tab
            rst  00h
            ld   a,(hl)
            STV  bBO
            inc  hl
            ld   a,(hl)
            STV  bSB
            inc  hl
            ld   a,(hl)
            inc  hl
            ld   h,(hl)
            ld   l,a
            ld   (sBM),hl
            ret

; 3700: таблица правил (страница 1)
S3700:      call disp_blank
            call foot_clr
            SETV pg_vis,2
            ld   bc,0
            ld   de,255*256+211
            ld   a,PF
            call gfx_fill
            ld   bc,6*256+6
            ld   de,249*256+205
            ld   a,PE
            call gfx_box
            ld   hl,rules_hdr
S3702:      ld   a,(hl)                 ; x, y, текст (0 в x = конец)
            or   a
            jp   z,S3704
            ld   b,a
            inc  hl
            ld   c,(hl)
            inc  hl
            push hl
            ld   a,PK
            call gfx_pset
            pop  hl
            call gfx_puts
            inc  hl
            jp   S3702
S3704:      SETV bY0,44  ; Y=44: 7 наборов
            ld   hl,rules_tab
            ld   b,7
S3706:      push bc
            push hl
            ld   e,(hl)                 ; RN$
            inc  hl
            ld   d,(hl)
            ld   b,8
            call S3706p
            pop  hl
            push hl
            ld   de,9                   ; S1$, S2$, S3$
            add  hl,de
            ld   e,(hl)
            inc  hl
            ld   d,(hl)
            inc  hl
            push hl
            ld   b,104
            call S3706p
            pop  hl
            ld   e,(hl)
            inc  hl
            ld   d,(hl)
            inc  hl
            push hl
            ld   b,176
            call S3706p
            pop  hl
            ld   e,(hl)
            inc  hl
            ld   d,(hl)
            ld   b,228
            call S3706p
            LDV  bY0
            add  a,11
            STV  bY0
            pop  hl
            ld   de,RT_SIZE
            add  hl,de
            pop  bc
            dec  b
            jp   nz,S3706
S3708:      SETV bY0,128  ; легенда
            ld   hl,rules_legend
            ld   b,6
S3708a:     push bc
            push hl
            ld   b,8
            LDV  bY0
            ld   c,a
            ld   a,PC
            call gfx_pset
            pop  hl
            call gfx_puts
            inc  hl
            LDV  bY0
            add  a,11
            STV  bY0
            pop  bc
            dec  b
            jp   nz,S3708a
S3720:      ld   bc,44*256+196
            ld   a,PK
            call gfx_pset
            ld   hl,s_press_key_back
            call gfx_puts
            call disp_on
S3722:      call getkey
S3724:      call S3406                  ; SET PAGE 0,0: титул с меню снова на экране
            call S3520
            jp   S3600
; PSET(B,Y0),PC: PRINT строка DE
S3706p:     LDV  bY0
            ld   c,a
            push de
            ld   a,PC
            call gfx_pset
            pop  hl
            jp   gfx_puts

rt_vars:    dw bTU,bAM,bXS,bSV,bFL,bQS,bBD
; 9100: наборы правил: RN$, TU,AM,XS,SV,FL,QS,BD, S1$,S2$,S3$
RT_SIZE     equ 15
rules_tab:  dw rs_salvo
            db 0,1,0,3,0,0,1
            dw rs_3,rs_cs,rs_n
            dw rs_salvop
            db 0,1,0,3,0,0,2
            dw rs_3,rs_cs,rs_n
            dw rs_barrage
            db 0,1,0,1,0,0,3
            dw rs_1ship,rs_cs,rs_n
            dw rs_classic
            db 0,1,0,0,0,0,0
            dw rs_1,rs_ms,rs_n
            dw rs_pursuit
            db 0,1,1,0,1,0,0
            dw rs_1p,rs_ms,rs_n
            dw rs_stealth
            db 1,0,0,0,0,1,0
            dw rs_1,rs_m,rs_y
            dw rs_anka
            db 0,1,1,0,0,0,0
            dw rs_1p,rs_ms,rs_n
rs_salvo:   TXT  "ЗАЛП"
rs_salvop:  TXT  "ЗАЛП ПЛЮС"
rs_barrage: TXT  "ШКВАЛ"
rs_classic: TXT  "КЛАССИКА"
rs_pursuit: TXT  "ПОГОНЯ"
rs_stealth: TXT  "СКРЫТНО"
rs_anka:    TXT  "АНКА (ДЕТИ)"
rs_3:       TXT  "3"
rs_1:       TXT  "1"
rs_1p:      TXT  "1+"
rs_1ship:   TXT  "1/КОР"
rs_cs:      TXT  "К/П"
rs_ms:      TXT  "Р/П"
rs_m:       TXT  "Р"
rs_n:       TXT  "Н"
rs_y:       TXT  "Д"
; 3606..3612
match_tab:  db 1,0
            dw sm_single
            db 3,1
            dw sm_bo3
            db 5,1
            dw sm_bo5
            db 7,1
            dw sm_bo7
sm_single:  TXT  "ОДНА ИГРА"
sm_bo3:     TXT  "ИЗ 3 ПАРТИЙ"
sm_bo5:     TXT  "ИЗ 5 ПАРТИЙ"
sm_bo7:     TXT  "ИЗ 7 ПАРТИЙ"
; 3700..3702: заголовки таблицы (x, y, текст)
rules_hdr:  db   100,12
            TXT  "ПРАВИЛА"
            db   8,28
            TXT  "ВАРИАНТ"
            db   104,28
            TXT  "ВЫСТР"
            db   168,28
            TXT  "ОТЧЕТ"
            db   228,28
            TXT  "С"
            db 0
; 9130
rules_legend:
            TXT  "К = ПОПАДАНИЯ ПО КОР. ЗА ЗАЛП"     ; строка — не длиннее 30 знаков (рамка)
            TXT  "Р = РЕЗУЛЬТАТ КАЖДОГО ВЫСТРЕЛА"
            TXT  "П = СООБЩАЮТ О ПОТОПЛЕНИИ"
            TXT  "1/КОР = ПО ВЫСТРЕЛУ С КОРАБЛЯ"
            TXT  "+ = ЗА ПОПАДАНИЕ ЕЩЕ ВЫСТРЕЛ"
            TXT  "С = КОРАБЛИ МОГУТ КАСАТЬСЯ"
s_ruleset:  TXT  "ВАРИАНТ"
s_match:    TXT  "МАТЧ"
s_q:        TXT  "?"
s_rules:    TXT  "ПРАВИЛА"


; переменные настроек в порядке cfg_TU..cfg_SB (161/162)
t_cfgv:     db   low bTU, low bAM, low bXS, low bSV, low bFL, low bQS, low bBD, low bDL, low bBO, low bSB
            ASSERT high t_cfgv == high (t_cfgv+10)

; ---------------------------------------------------------------- «RUN» игры: 133..172 (из game_run)
; Исполняется из оверлея: game_run зовёт это до распаковки тайлов поверх оверлея.
gr_init:
            ; 133/134/135: BLOAD движка своей сборки -> флаги движка
            LDV  cfg_fam
            ld   b,0
            cp   2
            jp   nz,gr_1
            inc  b
gr_1:       ld   a,b
            ld   (eng_sp),a
            LDV  cfg_fam
            ld   b,0
            cp   3
            jp   nz,gr_2
            inc  b
gr_2:       ld   a,b
            ld   (eng_bar),a
            ; 138 (сборки BD): сессионные счётчики движка заводятся один раз за включение
            LDV  cfg_fam
            or   a
            jp   nz,L138
            ld   hl,ARR_GA              ; STD: RUN обнуляет GA, GB, QX, QY (они в FA движка)
            ld   de,STD_OVL_END-ARR_GA
            call memzero
            jp   L154
L138:
            CPV  smem_magic,165
            jp   nz,L138a
            CPV  smem_magic+1,195
            jp   z,L154
L138a:      xor  a
            ld   (SMEMG),a
            ld   (SMEMR),a
            ld   (SMEMB),a
            SETV smem_magic,165
            SETV smem_magic+1,195
L154:       SETV bAM,1
            STV  bBO
            SETV bNK,5
            STV  bZT
            SETV bPZ,10
L155:       CPV  cfg_fam,2  ; только SALVOP
            jp   nz,L158
            SETV bNK,11
            SETV bZT,7
            SETV bBL,4
L158:       CPV  cfg_magic,165
            jp   nz,L163
            CPV  cfg_magic+1,195
            jp   nz,L163
L161:       ld   bc,t_cfgv              ; TU..SB = PEEK(&HDDF5..)
            ld   hl,cfg_TU
L161a:      ld   a,(bc)
            ld   e,a
            ld   d,high varpage
            ld   a,(hl)
            ld   (de),a
            inc  hl
            inc  bc
            ld   a,c
            cp   low (t_cfgv+10)
            jp   nz,L161a
L163:       ld   hl,ships_sp            ; RESTORE 9028
            CPV  bNK,8
            jp   nc,L164
            ld   hl,ships_anka          ; RESTORE 9025
            CPV  bDL,1
            jp   z,L164
            ld   hl,ships_std           ; RESTORE 9020
            LDV  bFL
            or   a
            jp   z,L164
            ld   hl,ships_alt           ; RESTORE 9030
L164:       push hl
            LDV  cfg_fam            ; только IRONCLAD.BAS
            or   a
            jp   nz,L165
            CPV  bDL,1
            jp   nz,L165
            SETV bNK,6
            SETV bPZ,9
L165:       ZEROV bDP  ; GX,GY,TR,SP — константы
L166:       pop  hl                     ; TT=0: FOR I=1 TO NK: READ N$(I),SZ(I): TT=TT+SZ(I)
            ZEROV bTT
            SETV bI,1
L166a:      ld   e,(hl)                 ; имя
            inc  hl
            ld   d,(hl)
            inc  hl
            push hl
            LDV  bI
            ld   hl,ARR_N
            add  a,a
            rst  00h
            ld   (hl),e
            inc  hl
            ld   (hl),d
            pop  hl
            ld   c,(hl)                 ; размер
            inc  hl
            push hl
            LDV  bI
            ld   hl,ARR_SZ
            add  a,a
            rst  00h
            ld   (hl),c
            inc  hl
            ld   (hl),0
            LDV  bTT
            add  a,c
            STV  bTT
            pop  hl
            LDV  bNK
            ld   b,a
            LDV  bI
            cp   b
            jp   z,L172
            inc  a
            STV  bI
            jp   L166a
L172:       ld   hl,(frame_cnt)         ; R=RND(-PEEK(&HFC9E)-1): зерно от таймера
            ld   a,l
            or   1
            ld   l,a
            ld   (rnd_seed),hl
            jp   rnd16

; 9020..9030: флоты (имя, размер)
ships_std:  dw sh_carrier
            db 5
            dw sh_battleship
            db 4
            dw sh_cruiser
            db 3
            dw sh_submarine
            db 3
            dw sh_destroyer
            db 2
ships_anka: dw sh_carrier
            db 5
            dw sh_carrier
            db 5
            dw sh_battleship
            db 4
            dw sh_battleship
            db 4
            dw sh_cruiser
            db 3
            dw sh_submarine
            db 3
ships_sp:   dw sh_carrier
            db 5
            dw sh_battleship
            db 4
            dw sh_cruiser
            db 3
            dw sh_submarine
            db 3
            dw sh_destroyer
            db 2
            dw sh_destroyer
            db 2
            dw sh_destroyer
            db 2
            dw sh_bot
            db 1
            dw sh_bot
            db 1
            dw sh_bot
            db 1
            dw sh_bot
            db 1
ships_alt:  dw sh_frigate
            db 4
            dw sh_corvette
            db 3
            dw sh_cutter
            db 3
            dw sh_launch
            db 2
            dw sh_skiff
            db 2
