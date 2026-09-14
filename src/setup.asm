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
S162:       LDV  bTU                ; POKE настроек в «&HDDF5..&HE00»
            STV  cfg_TU
            LDV  bAM
            STV  cfg_AM
            LDV  bXS
            STV  cfg_XS
            LDV  bSV
            STV  cfg_SV
            LDV  bFL
            STV  cfg_FL
            LDV  bQS
            STV  cfg_QS
            LDV  bBD                ; -(BD>0)
            or   a
            jp   z,S164
            ld   a,1
S164:       STV  cfg_BD
            LDV  bDL
            STV  cfg_DL
            LDV  bBO
            STV  cfg_BO
            LDV  bSB
            STV  cfg_SB
            SETV cfg_magic,165
            SETV cfg_magic+1,195
S166:       LDV  bBD                ; RUN BARRAGE/SALVOP/SALVO/IRONCLAD
            STV  cfg_fam
            jp   game_run


; 2300: выход «в BASIC» — у Вектора его нет: текст как на SCREEN 0 и ожидание клавиши
S2300:      call disp_blank
            ld   bc,0
            ld   de,255*256+211
            ld   a,5
            call gfx_fill
            ld   a,1
            ld   (gfx_fg),a
            ld   a,5
            ld   (gfx_bg),a
            xor  a
            ld   (gfx_x),a
            ld   (gfx_y),a
            call putsi
            TXT  "SIGNING OFF. THANKS FOR PLAYING."
            xor  a
            ld   (gfx_x),a
            ld   a,8
            ld   (gfx_y),a
            ld   a,16                   ; подпись автора (была на панели загрузки 3814)
            ld   (gfx_y),a
            xor  a
            ld   (gfx_x),a
            call putsi
            TXT  "A GAME BY MEHMET BELGIN"
            xor  a
            ld   (gfx_x),a
            ld   a,24
            ld   (gfx_y),a
            call putsi
            TXT  "Ok"
            call disp_on
            call L3330
            call getkey
            jp   setup_run

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
            SETV pg_vis,2
            jp   disp_on

; 3500: меню
S3500:      ld   a,1                    ; COLOR 1: PF=5: PE=3: PK=1: PC=3
            ld   (gfx_fg),a
            ZEROV bMI
            call S3600
            ld   hl,s_loading_ver       ; PSET(128-4*LEN(A$),200),1: PRINT A$
            call str_len
            add  a,a
            add  a,a
            ld   b,a
            ld   a,128
            sub  b
            ld   b,a
            ld   c,200
            ld   a,1
            call gfx_pset
            ld   hl,s_loading_ver
            call gfx_puts
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
            ld   hl,s_q
            ld   de,s_rules
            ld   bc,64*256+198
            call S3512
            ld   hl,s_qq
            ld   de,s_exit
            ld   bc,152*256+198
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
S3549:      call upcase
            cp   'Q'
            jp   nz,S3550
            call S3595                  ; дальше разбирается уже новая клавиша
            call upcase
            cp   'Q'
            jp   z,S2300
S3550:      CPV  bK_,29
            jp   z,S3580
S3551:      cp   '?'
            jp   nz,S3552
            call S3700
            ret
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

; 3595: подтверждение выхода; A = следующая клавиша
S3595:      ld   bc,38*256+192
            ld   de,218*256+208
            ld   a,PF
            call gfx_fill
            ld   bc,44*256+196
            ld   a,PK
            call gfx_pset
            call putsi
            TXT  "EXIT TO BASIC? Q AGAIN"
            call getkey
            STV  bK_
            call S3520
            LDV  bK_
            ret

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
S3720:      ld   bc,40*256+196
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
rs_salvo:   db "SALVO",0
rs_salvop:  db "SALVO PLUS",0
rs_barrage: db "BARRAGE",0
rs_classic: db "CLASSIC",0
rs_pursuit: db "PURSUIT",0
rs_stealth: db "STEALTH",0
rs_anka:    db "ANKA (KIDS)",0
rs_3:       db "3",0
rs_1:       db "1",0
rs_1p:      db "1+",0
rs_1ship:   db "1/SHIP",0
rs_cs:      db "C/S",0
rs_ms:      db "M/S",0
rs_m:       db "M",0
rs_n:       db "N",0
rs_y:       db "Y",0
; 3606..3612
match_tab:  db 1,0
            dw sm_single
            db 3,1
            dw sm_bo3
            db 5,1
            dw sm_bo5
            db 7,1
            dw sm_bo7
sm_single:  db "SINGLE GAME",0
sm_bo3:     db "BEST OF 3",0
sm_bo5:     db "BEST OF 5",0
sm_bo7:     db "BEST OF 7",0
; 3700..3702: заголовки таблицы (x, y, текст)
rules_hdr:  db   104,12
            TXT  "RULES"
            db   8,28
            TXT  "RULESET"
            db   104,28
            TXT  "SHOT"
            db   168,28
            TXT  "REPORT"
            db   228,28
            TXT  "T"
            db 0
; 9130
rules_legend:
            TXT  "C = HITS PER SHIP PER SALVO"
            TXT  "M = HIT OR MISS PER SHOT"
            TXT  "S = SINKINGS ANNOUNCED"
            TXT  "1/SHIP = ONE PER SHIP AFLOAT"
            TXT  "+ = EXTRA SHOT AFTER A HIT"
            TXT  "T = SHIPS MAY TOUCH"
s_ruleset:  TXT  "RULESET"
s_match:    TXT  "MATCH"
s_q:        TXT  "?"
s_rules:    TXT  "RULES"
s_qq:       TXT  "Q"
s_exit:     TXT  "EXIT"
s_loading_ver: db "LOADING "
            include "../build/data/version.inc"
            TXT  " ..."


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
L161:       ld   hl,cfg_TU
            ld   a,(hl)
            STV  bTU
            inc  hl
            ld   a,(hl)
            STV  bAM
            inc  hl
            ld   a,(hl)
            STV  bXS
            inc  hl
            ld   a,(hl)
            STV  bSV
            inc  hl
            ld   a,(hl)
            STV  bFL
            inc  hl
            ld   a,(hl)
            STV  bQS
            inc  hl
            ld   a,(hl)
            STV  bBD
            inc  hl
            ld   a,(hl)
            STV  bDL
            inc  hl
            ld   a,(hl)
            STV  bBO
            inc  hl
            ld   a,(hl)
            STV  bSB
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
            call rnd16
            ret

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
