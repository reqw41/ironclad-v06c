; ============================================================================
; game.asm — перевод ref/ironclad-msx/src/IRONCLAD.BAS: строки 100..992.
; Метка Lnnnn = строка nnnn исходника. Одна программа на все четыре сборки
; оригинала (IRONCLAD/SALVO/SALVOP/BARRAGE): где сборки различаются, решает
; cfg_fam (0 IRONCLAD, 1 SALVO, 2 SALVOP, 3 BARRAGE) — см. tools/build.py оригинала.
; Сборка IRONCLAD.BAS = семейство STD (BD=0), остальные три — BD=1.
; ============================================================================

; ---------------------------------------------------------------- «RUN "SETUP.BAS"»: оверлей меню
setup_main:
setup_run:
            ld   sp,STACK_TOP
            call run_clear
            ld   hl,ovl_menu_zx0
            ld   de,ovl_menu
            call dzx0
            jp   S110

; ---------------------------------------------------------------- «RUN» программы игры
game_run:
            ld   sp,STACK_TOP
            call run_clear
            call gr_init                ; 133..172 — в оверлее меню (он ещё на месте)
            call tiles_load             ; меню стояло поверх тайлов
L187:       call cur_hide               ; 3304: курсор-спрайт спрятан
L195:       SETV bGN,1
            ZEROV bGW
            STV  bGC
            ld   a,2
            call rnd_n
            STV  bFS
            CPV  bDL,1
            jp   nz,L221
            ZEROV bFS
L221:       ZEROV bSL
L230:       ZEROV bTE
            STV  bTP
            STV  bCX
            STV  bCY
            STV  bOD
            STV  bWN
            STV  bFB
            STV  bRW
            STV  bNT
            STV  bNP
            STV  bSU
            STV  bHX
            STV  bHY
            inc  a
            STV  bTD
            ld   a,2
            call rnd_n
            STV  bPA
            LDV  bZT
            ld   b,a
            LDV  bNK
            sub  b
            STV  bBL
L240:       call L410
L250:       SETV bDP,1  ; DP=1: экран погашен, палитра, чистая страница 1
            call disp_blank
            SETV pg_vis,1
            call L2505
            ld   a,15                   ; COLOR 15,1,1
            ld   (gfx_fg),a
            ld   a,1
            ld   (gfx_bg),a
            call cls1
            call disp_on
L260:       call L1355
L270:       SETV bSD,1
            call L1152
            ZEROV bSD
            call L1152
            call L1206
            call L1473
L271:       LDV  bBD
            or   a
            jp   z,L275
            call L3820
            SETV bSH,1
L271a:      call L3884
            INCV bSH
            LDV  bNK
            cp   (hl)
            jp   nc,L271a
L275:                                   ; COPY стр.1 -> стр.2: снимок держат записи клеток
L280:       call L305
L290:       ZEROV bHZ
            call L1694
            LDV  bBD
            or   a
            call nz,L4097
L291:       ZEROV bDP
            call page_show
            jp   L500

; RUN: все переменные BASIC обнулить (строки пусты); страницы — чистый лист
run_clear:
            ld   hl,game_vars
            ld   de,game_vars_end-game_vars
rc_1:       xor  a
            ld   (hl),a
            inc  hl
            dec  de
            ld   a,d
            or   e
            jp   nz,rc_1
            SETV pg_vis,2
            jp   rec_clear

; все записи клеток обеих страниц = пусто, поля AT: пусты
rec_clear:
            ld   hl,cellrec
            ld   de,800
rcl_1:      ld   (hl),0FFh
            inc  hl
            dec  de
            ld   a,d
            or   e
            jp   nz,rcl_1
            ld   hl,at_rec
            ld   b,16
rcl_2:      ld   (hl),0
            inc  hl
            dec  b
            jp   nz,rcl_2
            ZEROV gh_on
            ret

; LINE(0,0)-(255,211),1,BF
cls1:
            ld   bc,0
            ld   de,255*256+211
            ld   a,1
            jp   gfx_fill

; ---------------------------------------------------------------- 305: расстановка игрока
L305:       SETV bSH,1
            ZEROV bCX
            STV  bCY
            STV  bOD
            STV  bFB
            STV  bRW
            STV  bLS
            STV  bNP
            dec  a
            STV  bLO
            STV  bLX
            STV  bLY
            call L1694
            call L3330
L306:       LDV  cfg_fam            ; только IRONCLAD.BAS: ANKA расставляет сам
            or   a
            jp   nz,L310
            CPV  bDL,1
            jp   nz,L310
            call L2010
            jp   L390
L310:       call L3960
L314:       call L1473
L320:       call L1615
L322:       LDV  bLS
            ld   b,a
            LDV  bSH
            cp   b
            jp   nz,L322a
            LDV  bLO
            ld   b,a
            LDV  bOD
            cp   b
            jp   z,L326
L322a:      call L1652
            call L3204
            LDV  bSH
            STV  bLS
            LDV  bOD
            STV  bLO
            SETV bLX,-1
L326:       LDV  bLX
            ld   b,a
            LDV  bAX
            cp   b
            jp   nz,L328
            LDV  bLY
            ld   b,a
            LDV  bAY
            cp   b
            jp   z,L335
L328:       call L1662
            LDV  bAX
            STV  bLX
            LDV  bAY
            STV  bLY
L335:       call L1410
L340:       LDV  bAC
            or   a
            jp   z,L320
            cp   3
            jp   nz,L345
            call L2350
            CPV  bAB,1
            jp   z,L2360
            jp   L320
L345:       cp   2
            jp   nz,L350
            LDV  bOD
            xor  1
            STV  bOD
            jp   L320
L350:       cp   4
            jp   nz,L356
L352:       call L2010
            LDV  bNK
            ld   b,a
            LDV  bSH
            cp   b
            jp   z,L310
            jp   c,L310
            jp   L390
L356:       cp   5
            jp   nz,L365
L358:       call L2108
            jp   L310
L365:       call L1615
L370:       CPV  bLG,1
            jp   z,L380
L375:       call msg1i
            TXT  "BLOCKED"
            jp   L328
L380:       call L1652
L381:       call ship_to_ps
L382:       call L1683
L383:       call gh_forget              ; RW=0 (призрак затирается кораблём)
            ZEROV bRW
            call ship_draw1
L384:       INCV bNP
            call L2635                  ; COPY стр.1 -> стр.2 — снимок держат записи клеток
L386:       INCV bSH
            ZEROV bCX
            STV  bCY
            STV  bOD
            LDV  bNK
            cp   (hl)
            jp   nc,L310
L390:       call ms_clear
            call L1305
            call L1315
            ret

; B = TX(I), C = TY(I)
tx_i:       LDV  bI
; B = TX(A), C = TY(A)
tx_a:       add  a,a
            ld   hl,ARR_TX
            rst  00h
            ld   b,(hl)
            ld   a,ARR_TY-ARR_TX
            rst  00h
            ld   c,(hl)
            ret
; TX(A)=B: TY(A)=E (слова, старший байт 0); портит A, HL
txy_set:    add  a,a
            ld   hl,ARR_TX
            rst  00h
            ld   (hl),b
            inc  hl
            ld   (hl),0
            ld   a,ARR_TY-ARR_TX-1
            rst  00h
            ld   (hl),e
            inc  hl
            ld   (hl),0
            ret
; BZ(C,R)=3: Q=A: SD=0: GOSUB 1105 — буй на странице игрока
buoy_cr:    STV  bQ
            ld   bc,ARR_BZ
            call w10cr
            ld   (hl),3
            inc  hl
            ld   (hl),0
            ZEROV bSD
            jp   L1105

; A = A*12 (портит C)
x12:        add  a,a
            add  a,a
            ld   c,a
            add  a,a
            add  a,c
            ret
; A = PX(k), E = PY(k), HL -> PY(k): k = A (= SH + I*12) / HL (pxy_hl)
pxy_hl:     ld   de,ARR_PX
            add  hl,de
            jp   pxy_2
pxy_a:      ld   hl,ARR_PX
            rst  00h
pxy_2:      ld   a,(hl)
            ld   de,60
            add  hl,de
            ld   e,(hl)
            ret

; PX(SH,I)=B: PY(SH,I)=C
px_set:
            call pxy_off
            ld   de,ARR_PX
            add  hl,de
            ld   (hl),b
            ld   de,ARR_PY-ARR_PX
            add  hl,de
            ld   (hl),c
            ret
; HL = SH + I*12
pxy_off:
            LDV  bI
            add  a,a
            add  a,a
            ld   l,a
            add  a,a
            add  a,l                    ; 12I
            ld   l,a
            LDV  bSH
            add  a,l
            ld   l,a
            ld   h,0
            ret

; HL = BC + (A + 10*E)*2 — адрес элемента int16-массива (x,y) 10x10
w10:
            ld   l,a
            ld   a,e
            add  a,a
            ld   d,a
            add  a,a
            add  a,a
            add  a,d
            add  a,l
            ld   l,a
            ld   h,0
            add  hl,hl
            add  hl,bc
            ret

; ---------------------------------------------------------------- 410: расстановка противника
L410:       call L1694
L420:       ld   hl,ARR_CS              ; CS()=0
            ld   b,200
L420a:      ld   (hl),0
            inc  hl
            dec  b
            jp   nz,L420a
L430:       SETV bSH,1
            ld   hl,0
            ld   (bAT),hl
L440:       ld   hl,(bAT)
            inc  hl
            ld   (bAT),hl
            ld   de,-1001
            add  hl,de
            jp   c,L410                 ; AT>1000
L450:       call L3440
L460:       call L1615
L470:       LDV  bLG
            or   a
            jp   z,L440
L480:       call L1652
L482:       ZEROV bI  ; CS(TX,TY)=SH+16*GT
L482a:      call tx_i
            push bc
            LDV  bI
            ld   hl,ARR_GT
            rst  00h
            ld   l,(hl)
            ld   h,0
            add  hl,hl
            add  hl,hl
            add  hl,hl
            add  hl,hl
            LDV  bSH
            rst  00h
            ex   de,hl
            pop  bc
            ld   a,b
            push de
            ld   e,c
            ld   bc,ARR_CS
            call w10
            pop  de
            ld   (hl),e
            inc  hl
            ld   (hl),d
            INCV bI
            LDV  bTN
            cp   (hl)
            jp   nz,L482a
L483:       LDV  cfg_fam            ; только IRONCLAD.BAS: QX(SH,I)=TX: QY(SH,I)=TY
            or   a
            jp   nz,L484
            ZEROV bI
L483a:      call tx_i
            call pxy_off
            ld   de,ARR_QX
            add  hl,de
            ld   (hl),b
            ld   de,ARR_QY-ARR_QX
            add  hl,de
            ld   (hl),c
            INCV bI
            LDV  bTN
            cp   (hl)
            jp   nz,L483a
L484:       call L1683
L490:       INCV bSH
            ld   hl,0
            ld   (bAT),hl
            LDV  bNK
            ld   hl,bSH
            cp   (hl)
            jp   nc,L440
L495:       ret

; ---------------------------------------------------------------- 500: ходы
L500:       ld   hl,s_you_fire_first
            CPV  bFS,1
            jp   nz,L500a
            ld   hl,s_enemy_fires_first
L500a:      push hl
            call ms_clear
L501:       CPV  bDL,2  ; IF DL>1 AND GN=1 THEN MS$="COIN TOSS: "+MS$
            jp   c,L501a
            CPV  bGN,1
            jp   nz,L501a
            call ms_cati
            TXT  "COIN TOSS: "
L501a:      pop  hl
            call ms_cat
L502:       call L1305
            CPV  bFS,1
            call z,L702
L504:       call tp_tt
            jp   c,L510
            SETV bWN,2
            jp   L2210
L510:       call L602
L520:       call te_tt
            jp   c,L530
            SETV bWN,1
            jp   L2210
L530:       call L702
L540:       jp   L504                   ; 540..550 = 504: IF TP>=TT THEN WN=2: GOTO 2210 ELSE 510
; A = TP, флаги cp TT / A = TE, флаги cp TT
tp_tt:      LDV  bTT
            ld   b,a
            LDV  bTP
            cp   b
            ret
te_tt:      LDV  bTT
            ld   b,a
            LDV  bTE
            cp   b
            ret
; 602/703: NF=1: IF SV=1 THEN GOSUB HL (3460/3470): NF=AL; IF SV>=3 THEN NF=SV; NC=0
nf_calc:    SETV bNF,1
            CPV  bSV,1
            jp   nz,nfc_1
            call scn_c
            LDV  bAL
            STV  bNF
nfc_1:      CPV  bSV,3
            jp   c,nfc_2
            STV  bNF
nfc_2:      ZEROV bNC
            ret
; MS$ = "YOU FIRE " + CO$ + HL: GOSUB 1305
fire1:      push hl
            ld   hl,s_you_fire
            ld   de,sCO
            call ms_2
            jp   L1305
; MS$ = "ENEMY FIRES " + CE$ + HL: GOSUB 1315
fire2:      push hl
            ld   hl,s_enemy_fires
            ld   de,sCE
            call ms_2
            jp   L1315
; MS$ = HL + DE + [SP+2]
ms_2:       push de
            call ms_set
            pop  hl
            call ms_cat
            pop  de
            pop  hl
            push de
            jp   ms_cat
; SD=1: C=CX: R=CY: GOSUB 1105
rd_cxcy:    SETV bSD,1
            call cr_cxcy
            jp   L1105

; ---------------------------------------------------------------- 602: ход игрока
L602:       ld   hl,L3460               ; 602..604
            call nf_calc
            call ms_clear
            call L1305
            call L1315
            CPV  bBD,1
            jp   nz,L610
            INCV bSL
            ZEROV bSK
            ld   (sSS),a
            STV  bSJ
L610:       SETV bFB,1
            call L3330
L615:       CPV  bDP,1
            jp   nz,L617
            ZEROV bDP
            call page_show
L617:       call L1473
L620:       LDV  bCX                ; KX=GX+CX*16: KY=GY+CY*16: FL=0
            ld   b,a
            LDV  bCY
            ld   c,a
            call cell_xy
            ld   a,b
            STV  bKX
            ld   a,c
            STV  bKY
            ZEROV bFL
L622:       call cur_show               ; PUT SPRITE 0,(KX,KY-1),11 на странице 0
L630:       call L1410
L640:       CPV  bAC,3
            jp   nz,L643
            call L2350
            CPV  bAB,1
            jp   z,L2360
            jp   L620
L643:       cp   7
            jp   nz,L644
            call L3940
            jp   L620
L644:       cp   5
            jp   nz,L645
            CPV  bBD,1
            jp   nz,L645
            LDV  bWC
            or   a
            jp   nz,L645
            call L3880
            jp   L620
L645:       CPV  bAC,1
            jp   nz,L620
L646:       CPV  bWC,1
            jp   nz,L647
            ZEROV bWC
            ret
L647:       CPV  bDP,1
            jp   z,L620
L650:       call cm_cxcy                ; IF CM(CX,CY)>0 THEN "ALREADY FIRED"
            call hl_pos
            jp   z,L655
            call msg1i
            TXT  "ALREADY FIRED"
            jp   L620
L655:       ZEROV bFB
            call L3322
            LDV  bCX
            ld   b,a
            LDV  bCY
            ld   c,a
            ld   de,sCO
            call mk_coord
            CPV  bBD,1
            jp   nz,L660
            LDV  bCX                ; GT(NC)=CX*10+CY
            add  a,a
            ld   b,a
            add  a,a
            add  a,a
            add  a,b
            ld   b,a
            LDV  bCY
            add  a,b
            ld   b,a
            LDV  bNC
            ld   hl,ARR_GT
            rst  00h
            ld   (hl),b
L660:       call L2645
            ld   a,DLY_120
            call wait_frames            ; FOR I=1 TO 120: NEXT I
L665:       call L810
L667:       LDV  cfg_fam            ; 667, 668 — только IRONCLAD.BAS
            or   a
            jp   nz,L669
            call te_tt
            jp   c,L668
            LDV  bBD
            or   a
            jp   z,L672
L668:       CPV  bXS,1
            jp   nz,L669
            CPV  bHW,1
            jp   z,L610
L669:       INCV bNC
            LDV  bNF
            ld   b,a
            ld   a,(hl)
            cp   b
            jp   c,L610
L672:       CPV  bBD,1
            jp   nz,L674
            call L3798
            call te_tt
            jp   nc,L674
            SETV bWC,1
            jp   L610
L674:       ret

; HL = &CM(CX,CY)
cm_cxcy:
            LDV  bCY
            ld   e,a
            LDV  bCX
            ld   bc,ARR_CM
            jp   w10
; (HL) int16 > 0 ? -> NZ если > 0
hl_pos:
            ld   e,(hl)
            inc  hl
            ld   a,(hl)
            or   a
            jp   m,hp_no
            or   e
            ret
hp_no:      xor  a
            ret

; CO$=CHR$(65+B)+MID$(STR$(C+1),2) -> DE
mk_coord:
            ld   a,b
            add  a,65
            ld   (de),a
            inc  de
            ld   a,c
            inc  a
            cp   10
            jp   c,mc_1
            ld   a,'1'
            ld   (de),a
            inc  de
            xor  a
mc_1:       add  a,'0'
            ld   (de),a
            inc  de
            xor  a
            ld   (de),a
            ret

; ---------------------------------------------------------------- 702: ход противника
L702:       ld   hl,L3470               ; 702..704
            call nf_calc
L710:       call msg2i
            TXT  "ENEMY IS PLOTTING..."
L715:       LDV  bDP
            or   a
            jp   nz,L716
            SETV bDP,1
            call page_show
            call L1473
L716:       CPV  bBD,1
            jp   nz,L718
            call L3840
            jp   L735
L718:       CPV  bQS,1  ; 718..724 — только IRONCLAD.BAS
            jp   nz,L718a
            call L1940
            call L910
            jp   L720
L718a:      CPV  bDL,1
            jp   nz,L718b
            call L1967
            call L910
            jp   L720
L718b:      call L1810
            call L910
L720:       call tp_tt
            jp   nc,L735
L722:       CPV  bXS,1
            jp   nz,L724
            CPV  bHW,1
            jp   nz,L724
            CPV  bDL,2
            jp   nc,L718
L724:       INCV bNC
            LDV  bNF
            ld   b,a
            ld   a,(hl)
            cp   b
            jp   c,L718
L735:       ld   b,DLY_1500             ; FOR I=1 TO 1500: IF INKEY$<>"" THEN I=1500
L735a:      push bc
            call inkey
            pop  bc
            jp   nz,L740
            ei
            halt
            dec  b
            jp   nz,L735a
L740:       ret

; ---------------------------------------------------------------- 810: выстрел игрока
L810:       call cs_cxcy                ; SH=CS(CX,CY) MOD 16
            ld   a,(hl)
            and  15
            STV  bSH
            CPV  bBD,1
            jp   z,L3870
L820:       LDV  bSH
            or   a
            jp   nz,L850
L830:       ZEROV bHW
            call cm_cxcy
            ld   (hl),1
            inc  hl
            ld   (hl),0
            call rd_cxcy
            call L2605
L840:       ld   hl,s_miss
            jp   fire1
L850:       SETV bHW,1
            call cm_cxcy
            ld   (hl),2
            inc  hl
            ld   (hl),0
            call qh_sh
            inc  (hl)
            INCV bTE
            call rd_cxcy
L860:       call qh_sh
            ld   b,(hl)
            call sz_sh
            ld   a,b
            cp   c
            jp   nc,L878
L870:       call L2615
L870a:      ld   hl,s_hit
            jp   fire1
L878:       LDV  bQS
            or   a
            jp   z,L882
L879:       call L2615
            jp   L870a
L882:       call L1706
            call L2622
L890:       call ms_seti
            TXT  "SUNK - ENEMY "
            call n_sh
            call ms_cat
            call L1305
            call L1270
            ret

; HL = &CS(CX,CY)
cs_cxcy:
            LDV  bCY
            ld   e,a
            LDV  bCX
            ld   bc,ARR_CS
            jp   w10
; C=CX: R=CY
cr_cxcy:
            LDV  bCX
            STV  bC
            LDV  bCY
            STV  bR
            ret
; HL = &QH(SH)
qh_sh:
            LDV  bSH
            ld   hl,ARR_QH
            jp   add_a_hl
; C = SZ(SH)
sz_sh:
            LDV  bSH
            ld   hl,ARR_SZ
            add  a,a
            rst  00h
            ld   c,(hl)
            ret
; HL = N$(SH)
n_sh:
            LDV  bSH
n_a:        ld   hl,ARR_N
            add  a,a
            rst  00h
            ld   a,(hl)
            inc  hl
            ld   h,(hl)
            ld   l,a
            ret
; C = PH(SH), HL -> PH(SH)
ph_sh:
            LDV  bSH
            ld   hl,ARR_PH
            add  a,a
            rst  00h
            ld   c,(hl)
            ret

; ---------------------------------------------------------------- 910: выстрел противника
L910:       LDV  bBX
            STV  bFX
            ld   b,a
            LDV  bBY
            STV  bFY
            ld   c,a
            ld   de,sCE
            call mk_coord
L920:       call ps_fxfy                ; SH=PS(FX,FY) MOD 16
            ld   a,(hl)
            and  15
            STV  bSH
L930:       or   a
            jp   nz,L960
L940:       ZEROV bHW
            call pm_fxfy                ; PM(FX,FY)=1+4*SN
            LDV  bSN
            add  a,a
            add  a,a
            inc  a
            ld   (hl),a
            inc  hl
            ld   (hl),0
            call L940c
            call L2605
L950:       LDV  cfg_fam            ; только IRONCLAD.BAS
            or   a
            jp   nz,L952
            LDV  bBD
            or   a
            jp   nz,L952
            ld   hl,s_miss
            jp   fire2
L952:       ret
; SD=0: C=FX: R=FY: GOSUB 1105
L940c:      ZEROV bSD
            LDV  bFX
            STV  bC
            LDV  bFY
            STV  bR
            jp   L1105
L960:       SETV bHW,1
            call pm_fxfy                ; PM(FX,FY)=2+4*SN
            LDV  bSN
            add  a,a
            add  a,a
            add  a,2
            ld   (hl),a
            inc  hl
            ld   (hl),0
            call ph_sh
            inc  (hl)
            INCV bTP
            call L940c
L961:       CPV  bBD,1
            jp   nz,L962
            LDV  bZT
            ld   b,a
            LDV  bSH
            cp   b
            jp   z,L961a
            jp   nc,L962
L961a:      LDV  bSH                ; HK(SH)=HK(SH)+1
            ld   hl,ARR_HK
            add  a,a
            rst  00h
            inc  (hl)
L962:       LDV  cfg_fam            ; только IRONCLAD.BAS
            or   a
            jp   nz,L965
            LDV  bBD
            or   a
            jp   nz,L965
            LDV  bTU
            or   a
            call z,L1925
L965:       LDV  bNT
            or   a
            jp   nz,L970
            LDV  bFX
            STV  bHX
            LDV  bFY
            STV  bHY
            SETV bNT,1
L970:       call ph_sh
            ld   b,c
            call sz_sh
            ld   a,b
            cp   c
            jp   nc,L980
L974:       call L2615                  ; 974/975
            INCV bEK
            LDV  cfg_fam
            or   a
            call z,L977                 ; IRONCLAD.BAS
L976:       CPV  bBD,1
            jp   z,L3884
            jp   L1280
L977:       ld   hl,s_hit
            jp   fire2
L980:       ZEROV bNT
            inc  a
            STV  bSW
            STV  bTD
            call sz_sh
            LDV  bSU
            add  a,c
            STV  bSU
            call L2622
            CPV  bBD,1
            jp   nz,L980a
            call L1795
            jp   L981
L980a:      call L1755
            LDV  bTU
            or   a
            jp   nz,L981
            LDV  bAM
            or   a
            call z,L1930
L981:       LDV  bZT                ; IF SH>ZT THEN GOSUB 4170
            ld   b,a
            LDV  bSH
            cp   b
            jp   z,L990
            jp   c,L990
            call L4170
L990:       INCV bEK
            CPV  bBD,1
            jp   nz,L991
            ld   de,sES                 ; ES$=ES$+LEFT$(N$(SH),3)+","
            call cat_sh3
            jp   L992
L991:       call ms_seti
            TXT  "ENEMY SANK YOUR "
            call n_sh
            call ms_cat
            call L1315
L992:       CPV  bBD,1
            jp   z,L3884
            jp   L1280

; первые 3 знака строки HL -> DE (DE на выходе -> нуль)
cat3:
            ld   b,3
c3_1:       ld   a,(hl)
            or   a
            jp   z,c3_2
            ld   (de),a
            inc  hl
            inc  de
            dec  b
            jp   nz,c3_1
c3_2:       xor  a
            ld   (de),a
            ret

; HL = &PS(FX,FY), &PM(FX,FY)
ps_fxfy:
            ld   bc,ARR_PS
            jp   fxfy
pm_fxfy:
            ld   bc,ARR_PM
fxfy:       LDV  bFY
            ld   e,a
            LDV  bFX
            jp   w10

; ---------------------------------------------------------------- строки MS$
; MS$ = строка HL
ms_set:
            ld   de,sMS
            jp   str_copy
; Текст — прямо за вызовом (TXT), продолжение — за текстом:
; ms_seti: MS$ = текст; ms_cati: MS$ = MS$ + текст; msg1i/msg2i: MS$ = текст: GOSUB 1305/1315
ms_seti:    pop  hl
            call ms_set
            inc  hl
            jp   (hl)
ms_cati:    pop  hl
            call ms_cat
            inc  hl
            jp   (hl)
msg1i:      pop  hl
            call ms_set
            inc  hl
            push hl
            jp   L1305
msg2i:      pop  hl
            call ms_set
            inc  hl
            push hl
            jp   L1315
; MS$ = ""
ms_clear:
            xor  a
            ld   (sMS),a
            ret
; MS$ = MS$ + строка HL
ms_cat:
            push hl
            ld   de,sMS
            call str_end
            pop  hl
            jp   str_copy
; MS$ = MS$ + знак A
ms_catc:
            push af
            ld   de,sMS
            call str_end
            pop  af
            ld   (de),a
            inc  de
            xor  a
            ld   (de),a
            ret
; MS$ = MS$ + STR$(HL)
ms_catnum:
            push hl
            ld   de,sMS
            call str_end
            pop  hl
            jp   str_num
; MS$ = MS$ + MID$(STR$(A),2) (A >= 0)
ms_catd:
            ld   l,a
            ld   h,0
            push hl
            ld   de,sMS
            call str_end
            pop  hl
            jp   str_digits

; ---------------------------------------------------------------- тексты
s_you_fire_first:   TXT  "YOU FIRE FIRST"
s_enemy_fires_first: TXT  "ENEMY FIRES FIRST"
s_you_fire:         TXT  "YOU FIRE "
s_miss:             TXT  " - MISS"
s_hit:              TXT  " - HIT"
s_enemy_fires:      TXT  "ENEMY FIRES "

sh_carrier:     db "CARRIER",0
sh_battleship:  db "BATTLESHIP",0
sh_cruiser:     db "CRUISER",0
sh_submarine:   db "SUBMARINE",0
sh_destroyer:   db "DESTROYER",0
sh_bot:         db "BOT",0
sh_frigate:     db "FRIGATE",0
sh_corvette:    db "CORVETTE",0
sh_cutter:      db "CUTTER",0
sh_launch:      db "LAUNCH",0
sh_skiff:       db "SKIFF",0
