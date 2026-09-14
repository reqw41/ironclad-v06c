; ============================================================================
; game.asm — перевод ref/ironclad-msx/src/IRONCLAD.BAS: строки 100..992.
; Метка Lnnnn = строка nnnn исходника. Одна программа на все четыре сборки
; оригинала (IRONCLAD/SALVO/SALVOP/BARRAGE): где сборки различаются, решает
; cfg_fam (0 IRONCLAD, 1 SALVO, 2 SALVOP, 3 BARRAGE) — см. tools/build.py оригинала.
; Сборка IRONCLAD.BAS = семейство STD (BD=0), остальные три — BD=1.
; ============================================================================

; ---------------------------------------------------------------- «RUN» программы игры
game_run:
            ld   sp,STACK_TOP
            call run_clear
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
            LDV  smem_magic
            cp   165
            jp   nz,L138a
            LDV  smem_magic+1
            cp   195
            jp   z,L154
L138a:      xor  a
            ld   (SMEMG),a
            ld   (SMEMR),a
            ld   (SMEMB),a
            ld   a,165
            STV  smem_magic
            ld   a,195
            STV  smem_magic+1
L154:       ld   a,1
            STV  bAM
            STV  bBO
            ld   a,5
            STV  bNK
            STV  bZT
            ld   a,10
            STV  bPZ
L155:       LDV  cfg_fam            ; только SALVOP
            cp   2
            jp   nz,L158
            ld   a,11
            STV  bNK
            ld   a,7
            STV  bZT
            ld   a,4
            STV  bBL
L158:       LDV  cfg_magic
            cp   165
            jp   nz,L163
            LDV  cfg_magic+1
            cp   195
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
            LDV  bNK
            cp   8
            jp   nc,L164
            ld   hl,ships_anka          ; RESTORE 9025
            LDV  bDL
            cp   1
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
            LDV  bDL
            cp   1
            jp   nz,L165
            ld   a,6
            STV  bNK
            ld   a,9
            STV  bPZ
L165:       xor  a                      ; GX,GY,TR,SP — константы
            STV  bDP
L166:       pop  hl                     ; TT=0: FOR I=1 TO NK: READ N$(I),SZ(I): TT=TT+SZ(I)
            xor  a
            STV  bTT
            ld   a,1
            STV  bI
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
L187:       call cur_hide               ; 3304: курсор-спрайт спрятан
L195:       ld   a,1
            STV  bGN
            xor  a
            STV  bGW
            STV  bGC
            ld   a,2
            call rnd_n
            STV  bFS
            LDV  bDL
            cp   1
            jp   nz,L221
            xor  a
            STV  bFS
L221:       xor  a
            STV  bSL
L230:       xor  a
            STV  bTE
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
L250:       ld   a,1                    ; DP=1: экран погашен, палитра, чистая страница 1
            STV  bDP
            call disp_blank
            ld   a,1
            STV  pg_vis
            call L2505
            ld   a,15                   ; COLOR 15,1,1
            ld   (gfx_fg),a
            ld   a,1
            ld   (gfx_bg),a
            call cls1
            call disp_on
L260:       call L1355
L270:       ld   a,1
            STV  bSD
            call L1152
            xor  a
            STV  bSD
            call L1152
            call L1206
            call L1473
L271:       LDV  bBD
            or   a
            jp   z,L275
            call L3820
            ld   a,1
            STV  bSH
L271a:      call L3884
            ld   hl,bSH
            inc  (hl)
            LDV  bNK
            cp   (hl)
            jp   nc,L271a
L275:                                   ; COPY стр.1 -> стр.2: снимок держат записи клеток
L280:       call L305
L290:       xor  a
            STV  bHZ
            call L1694
            LDV  bBD
            or   a
            call nz,L4097
L291:       xor  a
            STV  bDP
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
            ld   a,2
            STV  pg_vis
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
            xor  a
            STV  gh_on
            ret

; LINE(0,0)-(255,211),1,BF
cls1:
            ld   bc,0
            ld   de,255*256+211
            ld   a,1
            jp   gfx_fill

; ---------------------------------------------------------------- 305: расстановка игрока
L305:       ld   a,1
            STV  bSH
            xor  a
            STV  bCX
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
            LDV  bDL
            cp   1
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
            ld   a,-1
            STV  bLX
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
            LDV  bAB
            cp   1
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
L370:       LDV  bLG
            cp   1
            jp   z,L380
L375:       ld   hl,s_blocked
            rst  28h
            call L1305
            jp   L328
L380:       call L1652
L381:       call ship_to_ps
L382:       call L1683
L383:       call gh_forget              ; RW=0 (призрак затирается кораблём)
            xor  a
            STV  bRW
            call ship_draw1
L384:       ld   hl,bNP
            inc  (hl)
            call L2635                  ; COPY стр.1 -> стр.2 — снимок держат записи клеток
L386:       ld   hl,bSH
            inc  (hl)
            xor  a
            STV  bCX
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
tx_i:
            LDV  bI
            ld   hl,ARR_TX
            add  a,a
            rst  00h
            ld   b,(hl)
            LDV  bI
            ld   hl,ARR_TY
            add  a,a
            rst  00h
            ld   c,(hl)
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
L430:       ld   a,1
            STV  bSH
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
L482:       xor  a                      ; CS(TX,TY)=SH+16*GT
            STV  bI
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
            ld   hl,bI
            inc  (hl)
            LDV  bTN
            cp   (hl)
            jp   nz,L482a
L483:       LDV  cfg_fam            ; только IRONCLAD.BAS: QX(SH,I)=TX: QY(SH,I)=TY
            or   a
            jp   nz,L484
            xor  a
            STV  bI
L483a:      call tx_i
            call pxy_off
            ld   de,ARR_QX
            add  hl,de
            ld   (hl),b
            ld   de,ARR_QY-ARR_QX
            add  hl,de
            ld   (hl),c
            ld   hl,bI
            inc  (hl)
            LDV  bTN
            cp   (hl)
            jp   nz,L483a
L484:       call L1683
L490:       ld   hl,bSH
            inc  (hl)
            ld   hl,0
            ld   (bAT),hl
            LDV  bNK
            ld   hl,bSH
            cp   (hl)
            jp   nc,L440
L495:       ret

; ---------------------------------------------------------------- 500: ходы
L500:       ld   hl,s_you_fire_first
            LDV  bFS
            cp   1
            jp   nz,L500a
            ld   hl,s_enemy_fires_first
L500a:      push hl
            call ms_clear
L501:       LDV  bDL                ; IF DL>1 AND GN=1 THEN MS$="COIN TOSS: "+MS$
            cp   2
            jp   c,L501a
            LDV  bGN
            cp   1
            jp   nz,L501a
            ld   hl,s_coin_toss
            call ms_cat
L501a:      pop  hl
            call ms_cat
L502:       call L1305
            LDV  bFS
            cp   1
            call z,L702
L504:       LDV  bTT
            ld   b,a
            LDV  bTP
            cp   b
            jp   c,L510
            ld   a,2
            STV  bWN
            jp   L2210
L510:       call L602
L520:       LDV  bTT
            ld   b,a
            LDV  bTE
            cp   b
            jp   c,L530
            ld   a,1
            STV  bWN
            jp   L2210
L530:       call L702
L540:       LDV  bTT
            ld   b,a
            LDV  bTP
            cp   b
            jp   c,L550
            ld   a,2
            STV  bWN
            jp   L2210
L550:       jp   L510

; ---------------------------------------------------------------- 602: ход игрока
L602:       ld   a,1
            STV  bNF
            LDV  bSV
            cp   1
            jp   nz,L603
            call L3460
            LDV  bAL
            STV  bNF
L603:       LDV  bSV
            cp   3
            jp   c,L604
            STV  bNF
L604:       xor  a
            STV  bNC
            call ms_clear
            call L1305
            call L1315
            LDV  bBD
            cp   1
            jp   nz,L610
            ld   hl,bSL
            inc  (hl)
            xor  a
            STV  bSK
            ld   (sSS),a
            STV  bSJ
L610:       ld   a,1
            STV  bFB
            call L3330
L615:       LDV  bDP
            cp   1
            jp   nz,L617
            xor  a
            STV  bDP
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
            xor  a
            STV  bFL
L622:       call cur_show               ; PUT SPRITE 0,(KX,KY-1),11 на странице 0
L630:       call L1410
L640:       LDV  bAC
            cp   3
            jp   nz,L643
            call L2350
            LDV  bAB
            cp   1
            jp   z,L2360
            jp   L620
L643:       cp   7
            jp   nz,L644
            call L3940
            jp   L620
L644:       cp   5
            jp   nz,L645
            LDV  bBD
            cp   1
            jp   nz,L645
            LDV  bWC
            or   a
            jp   nz,L645
            call L3880
            jp   L620
L645:       LDV  bAC
            cp   1
            jp   nz,L620
L646:       LDV  bWC
            cp   1
            jp   nz,L647
            xor  a
            STV  bWC
            ret
L647:       LDV  bDP
            cp   1
            jp   z,L620
L650:       call cm_cxcy                ; IF CM(CX,CY)>0 THEN "ALREADY FIRED"
            call hl_pos
            jp   z,L655
            ld   hl,s_already_fired
            rst  28h
            call L1305
            jp   L620
L655:       xor  a
            STV  bFB
            call L3322
            LDV  bCX
            ld   b,a
            LDV  bCY
            ld   c,a
            ld   de,sCO
            call mk_coord
            LDV  bBD
            cp   1
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
            LDV  bTT
            ld   b,a
            LDV  bTE
            cp   b
            jp   c,L668
            LDV  bBD
            or   a
            jp   z,L672
L668:       LDV  bXS
            cp   1
            jp   nz,L669
            LDV  bHW
            cp   1
            jp   z,L610
L669:       ld   hl,bNC
            inc  (hl)
            LDV  bNF
            ld   b,a
            ld   a,(hl)
            cp   b
            jp   c,L610
L672:       LDV  bBD
            cp   1
            jp   nz,L674
            call L3798
            LDV  bTT
            ld   b,a
            LDV  bTE
            cp   b
            jp   nc,L674
            ld   a,1
            STV  bWC
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
            ld   a,'0'-10+10
            ld   (de),a
            inc  de
            xor  a
            ld   (de),a
            ret
mc_1:       add  a,'0'
            ld   (de),a
            inc  de
            xor  a
            ld   (de),a
            ret

; ---------------------------------------------------------------- 702: ход противника
L702:       ld   a,1
            STV  bNF
            LDV  bSV
            cp   1
            jp   nz,L703
            call L3470
            LDV  bAL
            STV  bNF
L703:       LDV  bSV
            cp   3
            jp   c,L704
            STV  bNF
L704:       xor  a
            STV  bNC
L710:       ld   hl,s_enemy_plotting
            rst  28h
            call L1315
L715:       LDV  bDP
            or   a
            jp   nz,L716
            ld   a,1
            STV  bDP
            call page_show
            call L1473
L716:       LDV  bBD
            cp   1
            jp   nz,L718
            call L3840
            jp   L735
L718:       LDV  bQS                ; 718..724 — только IRONCLAD.BAS
            cp   1
            jp   nz,L718a
            call L1940
            call L910
            jp   L720
L718a:      LDV  bDL
            cp   1
            jp   nz,L718b
            call L1967
            call L910
            jp   L720
L718b:      call L1810
            call L910
L720:       LDV  bTT
            ld   b,a
            LDV  bTP
            cp   b
            jp   nc,L735
L722:       LDV  bXS
            cp   1
            jp   nz,L724
            LDV  bHW
            cp   1
            jp   nz,L724
            LDV  bDL
            cp   2
            jp   nc,L718
L724:       ld   hl,bNC
            inc  (hl)
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
            LDV  bBD
            cp   1
            jp   z,L3870
L820:       LDV  bSH
            or   a
            jp   nz,L850
L830:       xor  a
            STV  bHW
            call cm_cxcy
            ld   (hl),1
            inc  hl
            ld   (hl),0
            ld   a,1
            STV  bSD
            call cr_cxcy
            call L1105
            call L2605
L840:       ld   hl,s_you_fire
            rst  28h
            ld   hl,sCO
            call ms_cat
            ld   hl,s_miss
            call ms_cat
            call L1305
            ret
L850:       ld   a,1
            STV  bHW
            call cm_cxcy
            ld   (hl),2
            inc  hl
            ld   (hl),0
            call qh_sh
            inc  (hl)
            ld   hl,bTE
            inc  (hl)
            ld   a,1
            STV  bSD
            call cr_cxcy
            call L1105
L860:       call qh_sh
            ld   b,(hl)
            call sz_sh
            ld   a,b
            cp   c
            jp   nc,L878
L870:       call L2615
L870a:      ld   hl,s_you_fire
            rst  28h
            ld   hl,sCO
            call ms_cat
            ld   hl,s_hit
            call ms_cat
            call L1305
            ret
L878:       LDV  bQS
            or   a
            jp   z,L882
L879:       call L2615
            jp   L870a
L882:       call L1706
            call L2622
L890:       ld   hl,s_sunk_enemy
            rst  28h
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
L940:       xor  a
            STV  bHW
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
            ld   hl,s_enemy_fires
            rst  28h
            ld   hl,sCE
            call ms_cat
            ld   hl,s_miss
            call ms_cat
            call L1315
L952:       ret
; SD=0: C=FX: R=FY: GOSUB 1105
L940c:      xor  a
            STV  bSD
            LDV  bFX
            STV  bC
            LDV  bFY
            STV  bR
            jp   L1105
L960:       ld   a,1
            STV  bHW
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
            ld   hl,bTP
            inc  (hl)
            call L940c
L961:       LDV  bBD
            cp   1
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
            ld   a,1
            STV  bNT
L970:       call ph_sh
            ld   b,c
            call sz_sh
            ld   a,b
            cp   c
            jp   nc,L980
            LDV  cfg_fam
            or   a
            jp   z,L975
L974:       call L2615                  ; сборки BD
            ld   hl,bEK
            inc  (hl)
            jp   L976
L975:       call L2615                  ; IRONCLAD.BAS
            ld   hl,bEK
            inc  (hl)
            call L977
L976:       LDV  bBD
            cp   1
            jp   z,L3884
            jp   L1280
L977:       ld   hl,s_enemy_fires
            rst  28h
            ld   hl,sCE
            call ms_cat
            ld   hl,s_hit
            call ms_cat
            jp   L1315
L980:       xor  a
            STV  bNT
            inc  a
            STV  bSW
            STV  bTD
            call sz_sh
            LDV  bSU
            add  a,c
            STV  bSU
            call L2622
            LDV  bBD
            cp   1
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
L990:       ld   hl,bEK
            inc  (hl)
            LDV  bBD
            cp   1
            jp   nz,L991
            ld   de,sES                 ; ES$=ES$+LEFT$(N$(SH),3)+","
            call str_end
            call n_sh
            call cat3
            ld   a,','
            ld   (de),a
            inc  de
            xor  a
            ld   (de),a
            jp   L992
L991:       ld   hl,s_enemy_sank
            rst  28h
            call n_sh
            call ms_cat
            call L1315
L992:       LDV  bBD
            cp   1
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
s_blocked:          db "BLOCKED",0
s_you_fire_first:   db "YOU FIRE FIRST",0
s_enemy_fires_first: db "ENEMY FIRES FIRST",0
s_coin_toss:        db "COIN TOSS: ",0
s_already_fired:    db "ALREADY FIRED",0
s_enemy_plotting:   db "ENEMY IS PLOTTING...",0
s_you_fire:         db "YOU FIRE ",0
s_miss:             db " - MISS",0
s_hit:              db " - HIT",0
s_sunk_enemy:       db "SUNK - ENEMY ",0
s_enemy_fires:      db "ENEMY FIRES ",0
s_enemy_sank:       db "ENEMY SANK YOUR ",0

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
