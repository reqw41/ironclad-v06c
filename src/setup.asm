; ============================================================================
; setup.asm — перевод ref/ironclad-msx/SETUP.BAS (меню). Метка Snnnn = строка nnnn.
; ============================================================================

; Оверлей: исполняется с OVL_BASE (см. main.asm), вход — S110 (из setup_run, game.asm).
S110:       ld   a,15                   ; SCREEN 5: COLOR 15,1,1
            ld   (gfx_fg),a
            ld   a,5                    ; 3406: COLOR 1,5,5 — фон текста 5
            ld   (gfx_bg),a
S120:       ld   a,3                    ; RP=0: DL=3: ...
            STV  bDL
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
            ld   a,165
            STV  cfg_magic
            ld   a,195
            STV  cfg_magic+1
S166:       LDV  bBD                ; RUN BARRAGE/SALVOP/SALVO/IRONCLAD
            STV  cfg_fam
            jp   game_run


; 2300: выход «в BASIC» — у Вектора его нет: текст как на SCREEN 0 и ожидание клавиши
S2300:      call disp_blank
            ld   bc,0
            ld   de,255*256+211
            ld   a,5
            rst  20h
            ld   a,1
            ld   (gfx_fg),a
            ld   a,5
            ld   (gfx_bg),a
            xor  a
            ld   (gfx_x),a
            ld   (gfx_y),a
            ld   hl,s_signing_off
            rst  18h
            xor  a
            ld   (gfx_x),a
            ld   a,8
            ld   (gfx_y),a
            ld   a,16                   ; подпись автора (была на панели загрузки 3814)
            ld   (gfx_y),a
            xor  a
            ld   (gfx_x),a
            ld   hl,s_author
            rst  18h
            xor  a
            ld   (gfx_x),a
            ld   a,24
            ld   (gfx_y),a
            ld   hl,s_ok
            rst  18h
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
            rst  20h
            ENDIF
            ld   a,2
            STV  pg_vis
            jp   disp_on

; 3500: меню
S3500:      ld   a,1                    ; COLOR 1: PF=5: PE=3: PK=1: PC=3
            ld   (gfx_fg),a
            xor  a
            STV  bMI
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
            rst  10h
            ld   hl,s_loading_ver
            rst  18h
            call S3520
S3503:      call L3330
S3504:      call S3540
            LDV  bMG
            cp   1
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
            rst  10h
            pop  hl
            rst  18h
            ld   a,':'
            call gfx_putc
            pop  bc
            ld   a,b
            add  a,16
            ld   b,a
            ld   a,PC
            rst  10h
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
            rst  20h
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
            rst  20h
            xor  a
            STV  bI
S3527:      ld   a,PC                   ; CL=PC: IF I=MI THEN CL=PK
            STV  bCL
            LDV  bMI
            ld   b,a
            LDV  bI
            cp   b
            jp   nz,S3528
            ld   a,PK
            STV  bCL
S3528:      ld   a,160                  ; YR=160: IF I=1 THEN YR=182
            STV  bYP
            LDV  bI
            or   a
            jp   z,S3530
            ld   a,182
            STV  bYP
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
            rst  10h
            ld   hl,s_ruleset
            LDV  bI
            or   a
            jp   z,S3531a
            ld   hl,s_match
S3531a:     rst  18h
            ld   hl,bI
            inc  (hl)
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
            rst  10h
            pop  hl
            rst  18h
            pop  bc                     ; X=105: X2=205: GOSUB 3590
; 3590: треугольники-стрелки: FOR I=0 TO 3: LINE(X+I,Y+3-I)-(X+I,Y+3+I),2: LINE(X2+3-I,...)
S3590:      ld   a,c
            STV  bY0
            xor  a
            STV  bJ
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
            rst  20h
            pop  de
            pop  bc
            LDV  bJ
            ld   b,a
            ld   a,208
            sub  b
            ld   b,a
            ld   d,a
            ld   a,2
            rst  20h
            ld   hl,bJ
            inc  (hl)
            ld   a,(hl)
            cp   4
            jp   c,S3590a
            ret

; 3540: клавиши меню
S3540:      xor  a
            STV  bMG
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
S3550:      LDV  bK_
            cp   29
            jp   z,S3580
S3551:      cp   '?'
            jp   nz,S3552
            call S3700
            ret
S3552:      cp   ' '
            jp   z,S3552a
            cp   13
            ret  nz
S3552a:     ld   a,1
            STV  bMG
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
            rst  20h
            ld   bc,44*256+196
            ld   a,PK
            rst  10h
            ld   hl,s_exit_basic
            rst  18h
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
S3602:      ld   a,3                    ; DL=3: IF RP=6 THEN DL=1
            STV  bDL
            LDV  bRP
            cp   6
            jp   nz,S3606
            ld   a,1
            STV  bDL
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
            ld   a,2
            STV  pg_vis
            ld   bc,0
            ld   de,255*256+211
            ld   a,PF
            rst  20h
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
            rst  10h
            pop  hl
            rst  18h
            inc  hl
            jp   S3702
S3704:      ld   a,44                   ; Y=44: 7 наборов
            STV  bY0
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
S3708:      ld   a,128                  ; легенда
            STV  bY0
            ld   hl,rules_legend
            ld   b,6
S3708a:     push bc
            push hl
            ld   b,8
            LDV  bY0
            ld   c,a
            ld   a,PC
            rst  10h
            pop  hl
            rst  18h
            inc  hl
            LDV  bY0
            add  a,11
            STV  bY0
            pop  bc
            dec  b
            jp   nz,S3708a
S3720:      ld   bc,40*256+196
            ld   a,PK
            rst  10h
            ld   hl,s_press_key_back
            rst  18h
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
            rst  10h
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
rules_hdr:  db 104,12,"RULES",0
            db 8,28,"RULESET",0
            db 104,28,"SHOT",0
            db 168,28,"REPORT",0
            db 228,28,"T",0
            db 0
; 9130
rules_legend:
            db "C = HITS PER SHIP PER SALVO",0
            db "M = HIT OR MISS PER SHOT",0
            db "S = SINKINGS ANNOUNCED",0
            db "1/SHIP = ONE PER SHIP AFLOAT",0
            db "+ = EXTRA SHOT AFTER A HIT",0
            db "T = SHIPS MAY TOUCH",0
s_ruleset:  db "RULESET",0
s_match:    db "MATCH",0
s_q:        db "?",0
s_rules:    db "RULES",0
s_qq:       db "Q",0
s_exit:     db "EXIT",0
s_exit_basic: db "EXIT TO BASIC? Q AGAIN",0
s_author:   db "A GAME BY MEHMET BELGIN",0
s_signing_off: db "SIGNING OFF. THANKS FOR PLAYING.",0
s_ok:       db "Ok",0
s_loading_ver: db "LOADING "
            include "../build/data/version.inc"
            db " ...",0
