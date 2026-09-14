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
            ld   a,(cfg_fam)
            ld   b,0
            cp   2
            jp   nz,gr_1
            inc  b
gr_1:       ld   a,b
            ld   (eng_sp),a
            ld   a,(cfg_fam)
            ld   b,0
            cp   3
            jp   nz,gr_2
            inc  b
gr_2:       ld   a,b
            ld   (eng_bar),a
            ; 138 (сборки BD): сессионные счётчики движка заводятся один раз за включение
            ld   a,(cfg_fam)
            or   a
            jp   nz,L138
            ld   hl,ARR_GA              ; STD: RUN обнуляет GA, GB, QX, QY (они в FA движка)
            ld   de,STD_OVL_END-ARR_GA
            call memzero
            jp   L154
L138:
            ld   a,(smem_magic)
            cp   165
            jp   nz,L138a
            ld   a,(smem_magic+1)
            cp   195
            jp   z,L154
L138a:      xor  a
            ld   (SMEMG),a
            ld   (SMEMR),a
            ld   (SMEMB),a
            ld   a,165
            ld   (smem_magic),a
            ld   a,195
            ld   (smem_magic+1),a
L154:       ld   a,1
            ld   (bAM),a
            ld   (bBO),a
            ld   a,5
            ld   (bNK),a
            ld   (bZT),a
            ld   a,10
            ld   (bPZ),a
L155:       ld   a,(cfg_fam)            ; только SALVOP
            cp   2
            jp   nz,L158
            ld   a,11
            ld   (bNK),a
            ld   a,7
            ld   (bZT),a
            ld   a,4
            ld   (bBL),a
L158:       ld   a,(cfg_magic)
            cp   165
            jp   nz,L163
            ld   a,(cfg_magic+1)
            cp   195
            jp   nz,L163
L161:       ld   hl,cfg_TU
            ld   a,(hl)
            ld   (bTU),a
            inc  hl
            ld   a,(hl)
            ld   (bAM),a
            inc  hl
            ld   a,(hl)
            ld   (bXS),a
            inc  hl
            ld   a,(hl)
            ld   (bSV),a
            inc  hl
            ld   a,(hl)
            ld   (bFL),a
            inc  hl
            ld   a,(hl)
            ld   (bQS),a
            inc  hl
            ld   a,(hl)
            ld   (bBD),a
            inc  hl
            ld   a,(hl)
            ld   (bDL),a
            inc  hl
            ld   a,(hl)
            ld   (bBO),a
            inc  hl
            ld   a,(hl)
            ld   (bSB),a
L163:       ld   hl,ships_sp            ; RESTORE 9028
            ld   a,(bNK)
            cp   8
            jp   nc,L164
            ld   hl,ships_anka          ; RESTORE 9025
            ld   a,(bDL)
            cp   1
            jp   z,L164
            ld   hl,ships_std           ; RESTORE 9020
            ld   a,(bFL)
            or   a
            jp   z,L164
            ld   hl,ships_alt           ; RESTORE 9030
L164:       push hl
            ld   a,(cfg_fam)            ; только IRONCLAD.BAS
            or   a
            jp   nz,L165
            ld   a,(bDL)
            cp   1
            jp   nz,L165
            ld   a,6
            ld   (bNK),a
            ld   a,9
            ld   (bPZ),a
L165:       xor  a                      ; GX,GY,TR,SP — константы
            ld   (bDP),a
L166:       pop  hl                     ; TT=0: FOR I=1 TO NK: READ N$(I),SZ(I): TT=TT+SZ(I)
            xor  a
            ld   (bTT),a
            ld   a,1
            ld   (bI),a
L166a:      ld   e,(hl)                 ; имя
            inc  hl
            ld   d,(hl)
            inc  hl
            push hl
            ld   a,(bI)
            ld   hl,ARR_N
            add  a,a
            call add_a_hl
            ld   (hl),e
            inc  hl
            ld   (hl),d
            pop  hl
            ld   c,(hl)                 ; размер
            inc  hl
            push hl
            ld   a,(bI)
            ld   hl,ARR_SZ
            add  a,a
            call add_a_hl
            ld   (hl),c
            inc  hl
            ld   (hl),0
            ld   a,(bTT)
            add  a,c
            ld   (bTT),a
            pop  hl
            ld   a,(bNK)
            ld   b,a
            ld   a,(bI)
            cp   b
            jp   z,L172
            inc  a
            ld   (bI),a
            jp   L166a
L172:       ld   hl,(frame_cnt)         ; R=RND(-PEEK(&HFC9E)-1): зерно от таймера
            ld   a,l
            or   1
            ld   l,a
            ld   (rnd_seed),hl
            call rnd16
L187:       call cur_hide               ; 3304: курсор-спрайт спрятан
L195:       ld   a,1
            ld   (bGN),a
            xor  a
            ld   (bGW),a
            ld   (bGC),a
            ld   a,2
            call rnd_n
            ld   (bFS),a
            ld   a,(bDL)
            cp   1
            jp   nz,L221
            xor  a
            ld   (bFS),a
L221:       xor  a
            ld   (bSL),a
L230:       xor  a
            ld   (bTE),a
            ld   (bTP),a
            ld   (bCX),a
            ld   (bCY),a
            ld   (bOD),a
            ld   (bWN),a
            ld   (bFB),a
            ld   (bRW),a
            ld   (bNT),a
            ld   (bNP),a
            ld   (bSU),a
            ld   (bHX),a
            ld   (bHY),a
            inc  a
            ld   (bTD),a
            ld   a,2
            call rnd_n
            ld   (bPA),a
            ld   a,(bZT)
            ld   b,a
            ld   a,(bNK)
            sub  b
            ld   (bBL),a
L240:       call L410
L250:       ld   a,1                    ; DP=1: экран погашен, палитра, чистая страница 1
            ld   (bDP),a
            call disp_blank
            ld   a,1
            ld   (pg_vis),a
            call L2505
            ld   a,15                   ; COLOR 15,1,1
            ld   (gfx_fg),a
            ld   a,1
            ld   (gfx_bg),a
            call cls1
            call disp_on
L260:       call L1355
L270:       ld   a,1
            ld   (bSD),a
            call L1152
            xor  a
            ld   (bSD),a
            call L1152
            call L1206
            call L1473
L271:       ld   a,(bBD)
            or   a
            jp   z,L275
            call L3820
            ld   a,1
            ld   (bSH),a
L271a:      call L3884
            ld   hl,bSH
            inc  (hl)
            ld   a,(bNK)
            cp   (hl)
            jp   nc,L271a
L275:                                   ; COPY стр.1 -> стр.2: снимок держат записи клеток
L280:       call L305
L290:       xor  a
            ld   (bHZ),a
            call L1694
            ld   a,(bBD)
            or   a
            call nz,L4097
L291:       xor  a
            ld   (bDP),a
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
            ld   (pg_vis),a
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
            ld   (gh_on),a
            ret

; LINE(0,0)-(255,211),1,BF
cls1:
            ld   bc,0
            ld   de,255*256+211
            ld   a,1
            jp   gfx_fill

; ---------------------------------------------------------------- 305: расстановка игрока
L305:       ld   a,1
            ld   (bSH),a
            xor  a
            ld   (bCX),a
            ld   (bCY),a
            ld   (bOD),a
            ld   (bFB),a
            ld   (bRW),a
            ld   (bLS),a
            ld   (bNP),a
            dec  a
            ld   (bLO),a
            ld   (bLX),a
            ld   (bLY),a
            call L1694
            call L3330
L306:       ld   a,(cfg_fam)            ; только IRONCLAD.BAS: ANKA расставляет сам
            or   a
            jp   nz,L310
            ld   a,(bDL)
            cp   1
            jp   nz,L310
            call L2010
            jp   L390
L310:       call L3960
L314:       call L1473
L320:       call L1615
L322:       ld   a,(bLS)
            ld   b,a
            ld   a,(bSH)
            cp   b
            jp   nz,L322a
            ld   a,(bLO)
            ld   b,a
            ld   a,(bOD)
            cp   b
            jp   z,L326
L322a:      call L1652
            call L3204
            ld   a,(bSH)
            ld   (bLS),a
            ld   a,(bOD)
            ld   (bLO),a
            ld   a,-1
            ld   (bLX),a
L326:       ld   a,(bLX)
            ld   b,a
            ld   a,(bAX)
            cp   b
            jp   nz,L328
            ld   a,(bLY)
            ld   b,a
            ld   a,(bAY)
            cp   b
            jp   z,L335
L328:       call L1662
            ld   a,(bAX)
            ld   (bLX),a
            ld   a,(bAY)
            ld   (bLY),a
L335:       call L1410
L340:       ld   a,(bAC)
            or   a
            jp   z,L320
            cp   3
            jp   nz,L345
            call L2350
            ld   a,(bAB)
            cp   1
            jp   z,L2360
            jp   L320
L345:       cp   2
            jp   nz,L350
            ld   a,(bOD)
            xor  1
            ld   (bOD),a
            jp   L320
L350:       cp   4
            jp   nz,L356
L352:       call L2010
            ld   a,(bNK)
            ld   b,a
            ld   a,(bSH)
            cp   b
            jp   z,L310
            jp   c,L310
            jp   L390
L356:       cp   5
            jp   nz,L365
L358:       call L2108
            jp   L310
L365:       call L1615
L370:       ld   a,(bLG)
            cp   1
            jp   z,L380
L375:       ld   hl,s_blocked
            call ms_set
            call L1305
            jp   L328
L380:       call L1652
L381:       call ship_to_ps
L382:       call L1683
L383:       call gh_forget              ; RW=0 (призрак затирается кораблём)
            xor  a
            ld   (bRW),a
            call ship_draw1
L384:       ld   hl,bNP
            inc  (hl)
            call L2635                  ; COPY стр.1 -> стр.2 — снимок держат записи клеток
L386:       ld   hl,bSH
            inc  (hl)
            xor  a
            ld   (bCX),a
            ld   (bCY),a
            ld   (bOD),a
            ld   a,(bNK)
            cp   (hl)
            jp   nc,L310
L390:       call ms_clear
            call L1305
            call L1315
            ret

; B = TX(I), C = TY(I)
tx_i:
            ld   a,(bI)
            ld   hl,ARR_TX
            add  a,a
            call add_a_hl
            ld   b,(hl)
            ld   a,(bI)
            ld   hl,ARR_TY
            add  a,a
            call add_a_hl
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
            ld   a,(bI)
            add  a,a
            add  a,a
            ld   l,a
            add  a,a
            add  a,l                    ; 12I
            ld   l,a
            ld   a,(bSH)
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
            ld   (bSH),a
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
L470:       ld   a,(bLG)
            or   a
            jp   z,L440
L480:       call L1652
L482:       xor  a                      ; CS(TX,TY)=SH+16*GT
            ld   (bI),a
L482a:      call tx_i
            push bc
            ld   a,(bI)
            ld   hl,ARR_GT
            call add_a_hl
            ld   l,(hl)
            ld   h,0
            add  hl,hl
            add  hl,hl
            add  hl,hl
            add  hl,hl
            ld   a,(bSH)
            call add_a_hl
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
            ld   a,(bTN)
            cp   (hl)
            jp   nz,L482a
L483:       ld   a,(cfg_fam)            ; только IRONCLAD.BAS: QX(SH,I)=TX: QY(SH,I)=TY
            or   a
            jp   nz,L484
            xor  a
            ld   (bI),a
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
            ld   a,(bTN)
            cp   (hl)
            jp   nz,L483a
L484:       call L1683
L490:       ld   hl,bSH
            inc  (hl)
            ld   hl,0
            ld   (bAT),hl
            ld   a,(bNK)
            ld   hl,bSH
            cp   (hl)
            jp   nc,L440
L495:       ret

; ---------------------------------------------------------------- 500: ходы
L500:       ld   hl,s_you_fire_first
            ld   a,(bFS)
            cp   1
            jp   nz,L500a
            ld   hl,s_enemy_fires_first
L500a:      push hl
            call ms_clear
L501:       ld   a,(bDL)                ; IF DL>1 AND GN=1 THEN MS$="COIN TOSS: "+MS$
            cp   2
            jp   c,L501a
            ld   a,(bGN)
            cp   1
            jp   nz,L501a
            ld   hl,s_coin_toss
            call ms_cat
L501a:      pop  hl
            call ms_cat
L502:       call L1305
            ld   a,(bFS)
            cp   1
            call z,L702
L504:       ld   a,(bTT)
            ld   b,a
            ld   a,(bTP)
            cp   b
            jp   c,L510
            ld   a,2
            ld   (bWN),a
            jp   L2210
L510:       call L602
L520:       ld   a,(bTT)
            ld   b,a
            ld   a,(bTE)
            cp   b
            jp   c,L530
            ld   a,1
            ld   (bWN),a
            jp   L2210
L530:       call L702
L540:       ld   a,(bTT)
            ld   b,a
            ld   a,(bTP)
            cp   b
            jp   c,L550
            ld   a,2
            ld   (bWN),a
            jp   L2210
L550:       jp   L510

; ---------------------------------------------------------------- 602: ход игрока
L602:       ld   a,1
            ld   (bNF),a
            ld   a,(bSV)
            cp   1
            jp   nz,L603
            call L3460
            ld   a,(bAL)
            ld   (bNF),a
L603:       ld   a,(bSV)
            cp   3
            jp   c,L604
            ld   (bNF),a
L604:       xor  a
            ld   (bNC),a
            call ms_clear
            call L1305
            call L1315
            ld   a,(bBD)
            cp   1
            jp   nz,L610
            ld   hl,bSL
            inc  (hl)
            xor  a
            ld   (bSK),a
            ld   (sSS),a
            ld   (bSJ),a
L610:       ld   a,1
            ld   (bFB),a
            call L3330
L615:       ld   a,(bDP)
            cp   1
            jp   nz,L617
            xor  a
            ld   (bDP),a
            call page_show
L617:       call L1473
L620:       ld   a,(bCX)                ; KX=GX+CX*16: KY=GY+CY*16: FL=0
            ld   b,a
            ld   a,(bCY)
            ld   c,a
            call cell_xy
            ld   a,b
            ld   (bKX),a
            ld   a,c
            ld   (bKY),a
            xor  a
            ld   (bFL),a
L622:       call cur_show               ; PUT SPRITE 0,(KX,KY-1),11 на странице 0
L630:       call L1410
L640:       ld   a,(bAC)
            cp   3
            jp   nz,L643
            call L2350
            ld   a,(bAB)
            cp   1
            jp   z,L2360
            jp   L620
L643:       cp   7
            jp   nz,L644
            call L3940
            jp   L620
L644:       cp   5
            jp   nz,L645
            ld   a,(bBD)
            cp   1
            jp   nz,L645
            ld   a,(bWC)
            or   a
            jp   nz,L645
            call L3880
            jp   L620
L645:       ld   a,(bAC)
            cp   1
            jp   nz,L620
L646:       ld   a,(bWC)
            cp   1
            jp   nz,L647
            xor  a
            ld   (bWC),a
            ret
L647:       ld   a,(bDP)
            cp   1
            jp   z,L620
L650:       call cm_cxcy                ; IF CM(CX,CY)>0 THEN "ALREADY FIRED"
            call hl_pos
            jp   z,L655
            ld   hl,s_already_fired
            call ms_set
            call L1305
            jp   L620
L655:       xor  a
            ld   (bFB),a
            call L3322
            ld   a,(bCX)
            ld   b,a
            ld   a,(bCY)
            ld   c,a
            ld   de,sCO
            call mk_coord
            ld   a,(bBD)
            cp   1
            jp   nz,L660
            ld   a,(bCX)                ; GT(NC)=CX*10+CY
            add  a,a
            ld   b,a
            add  a,a
            add  a,a
            add  a,b
            ld   b,a
            ld   a,(bCY)
            add  a,b
            ld   b,a
            ld   a,(bNC)
            ld   hl,ARR_GT
            call add_a_hl
            ld   (hl),b
L660:       call L2645
            ld   a,DLY_120
            call wait_frames            ; FOR I=1 TO 120: NEXT I
L665:       call L810
L667:       ld   a,(cfg_fam)            ; 667, 668 — только IRONCLAD.BAS
            or   a
            jp   nz,L669
            ld   a,(bTT)
            ld   b,a
            ld   a,(bTE)
            cp   b
            jp   c,L668
            ld   a,(bBD)
            or   a
            jp   z,L672
L668:       ld   a,(bXS)
            cp   1
            jp   nz,L669
            ld   a,(bHW)
            cp   1
            jp   z,L610
L669:       ld   hl,bNC
            inc  (hl)
            ld   a,(bNF)
            ld   b,a
            ld   a,(hl)
            cp   b
            jp   c,L610
L672:       ld   a,(bBD)
            cp   1
            jp   nz,L674
            call L3798
            ld   a,(bTT)
            ld   b,a
            ld   a,(bTE)
            cp   b
            jp   nc,L674
            ld   a,1
            ld   (bWC),a
            jp   L610
L674:       ret

; HL = &CM(CX,CY)
cm_cxcy:
            ld   a,(bCY)
            ld   e,a
            ld   a,(bCX)
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
            ld   (bNF),a
            ld   a,(bSV)
            cp   1
            jp   nz,L703
            call L3470
            ld   a,(bAL)
            ld   (bNF),a
L703:       ld   a,(bSV)
            cp   3
            jp   c,L704
            ld   (bNF),a
L704:       xor  a
            ld   (bNC),a
L710:       ld   hl,s_enemy_plotting
            call ms_set
            call L1315
L715:       ld   a,(bDP)
            or   a
            jp   nz,L716
            ld   a,1
            ld   (bDP),a
            call page_show
            call L1473
L716:       ld   a,(bBD)
            cp   1
            jp   nz,L718
            call L3840
            jp   L735
L718:       ld   a,(bQS)                ; 718..724 — только IRONCLAD.BAS
            cp   1
            jp   nz,L718a
            call L1940
            call L910
            jp   L720
L718a:      ld   a,(bDL)
            cp   1
            jp   nz,L718b
            call L1967
            call L910
            jp   L720
L718b:      call L1810
            call L910
L720:       ld   a,(bTT)
            ld   b,a
            ld   a,(bTP)
            cp   b
            jp   nc,L735
L722:       ld   a,(bXS)
            cp   1
            jp   nz,L724
            ld   a,(bHW)
            cp   1
            jp   nz,L724
            ld   a,(bDL)
            cp   2
            jp   nc,L718
L724:       ld   hl,bNC
            inc  (hl)
            ld   a,(bNF)
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
            ld   (bSH),a
            ld   a,(bBD)
            cp   1
            jp   z,L3870
L820:       ld   a,(bSH)
            or   a
            jp   nz,L850
L830:       xor  a
            ld   (bHW),a
            call cm_cxcy
            ld   (hl),1
            inc  hl
            ld   (hl),0
            ld   a,1
            ld   (bSD),a
            call cr_cxcy
            call L1105
            call L2605
L840:       ld   hl,s_you_fire
            call ms_set
            ld   hl,sCO
            call ms_cat
            ld   hl,s_miss
            call ms_cat
            call L1305
            ret
L850:       ld   a,1
            ld   (bHW),a
            call cm_cxcy
            ld   (hl),2
            inc  hl
            ld   (hl),0
            call qh_sh
            inc  (hl)
            ld   hl,bTE
            inc  (hl)
            ld   a,1
            ld   (bSD),a
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
            call ms_set
            ld   hl,sCO
            call ms_cat
            ld   hl,s_hit
            call ms_cat
            call L1305
            ret
L878:       ld   a,(bQS)
            or   a
            jp   z,L882
L879:       call L2615
            jp   L870a
L882:       call L1706
            call L2622
L890:       ld   hl,s_sunk_enemy
            call ms_set
            call n_sh
            call ms_cat
            call L1305
            call L1270
            ret

; HL = &CS(CX,CY)
cs_cxcy:
            ld   a,(bCY)
            ld   e,a
            ld   a,(bCX)
            ld   bc,ARR_CS
            jp   w10
; C=CX: R=CY
cr_cxcy:
            ld   a,(bCX)
            ld   (bC),a
            ld   a,(bCY)
            ld   (bR),a
            ret
; HL = &QH(SH)
qh_sh:
            ld   a,(bSH)
            ld   hl,ARR_QH
            jp   add_a_hl
; C = SZ(SH)
sz_sh:
            ld   a,(bSH)
            ld   hl,ARR_SZ
            add  a,a
            call add_a_hl
            ld   c,(hl)
            ret
; HL = N$(SH)
n_sh:
            ld   a,(bSH)
n_a:        ld   hl,ARR_N
            add  a,a
            call add_a_hl
            ld   a,(hl)
            inc  hl
            ld   h,(hl)
            ld   l,a
            ret
; C = PH(SH), HL -> PH(SH)
ph_sh:
            ld   a,(bSH)
            ld   hl,ARR_PH
            add  a,a
            call add_a_hl
            ld   c,(hl)
            ret

; ---------------------------------------------------------------- 910: выстрел противника
L910:       ld   a,(bBX)
            ld   (bFX),a
            ld   b,a
            ld   a,(bBY)
            ld   (bFY),a
            ld   c,a
            ld   de,sCE
            call mk_coord
L920:       call ps_fxfy                ; SH=PS(FX,FY) MOD 16
            ld   a,(hl)
            and  15
            ld   (bSH),a
L930:       or   a
            jp   nz,L960
L940:       xor  a
            ld   (bHW),a
            call pm_fxfy                ; PM(FX,FY)=1+4*SN
            ld   a,(bSN)
            add  a,a
            add  a,a
            inc  a
            ld   (hl),a
            inc  hl
            ld   (hl),0
            call L940c
            call L2605
L950:       ld   a,(cfg_fam)            ; только IRONCLAD.BAS
            or   a
            jp   nz,L952
            ld   a,(bBD)
            or   a
            jp   nz,L952
            ld   hl,s_enemy_fires
            call ms_set
            ld   hl,sCE
            call ms_cat
            ld   hl,s_miss
            call ms_cat
            call L1315
L952:       ret
; SD=0: C=FX: R=FY: GOSUB 1105
L940c:      xor  a
            ld   (bSD),a
            ld   a,(bFX)
            ld   (bC),a
            ld   a,(bFY)
            ld   (bR),a
            jp   L1105
L960:       ld   a,1
            ld   (bHW),a
            call pm_fxfy                ; PM(FX,FY)=2+4*SN
            ld   a,(bSN)
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
L961:       ld   a,(bBD)
            cp   1
            jp   nz,L962
            ld   a,(bZT)
            ld   b,a
            ld   a,(bSH)
            cp   b
            jp   z,L961a
            jp   nc,L962
L961a:      ld   a,(bSH)                ; HK(SH)=HK(SH)+1
            ld   hl,ARR_HK
            add  a,a
            call add_a_hl
            inc  (hl)
L962:       ld   a,(cfg_fam)            ; только IRONCLAD.BAS
            or   a
            jp   nz,L965
            ld   a,(bBD)
            or   a
            jp   nz,L965
            ld   a,(bTU)
            or   a
            call z,L1925
L965:       ld   a,(bNT)
            or   a
            jp   nz,L970
            ld   a,(bFX)
            ld   (bHX),a
            ld   a,(bFY)
            ld   (bHY),a
            ld   a,1
            ld   (bNT),a
L970:       call ph_sh
            ld   b,c
            call sz_sh
            ld   a,b
            cp   c
            jp   nc,L980
            ld   a,(cfg_fam)
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
L976:       ld   a,(bBD)
            cp   1
            jp   z,L3884
            jp   L1280
L977:       ld   hl,s_enemy_fires
            call ms_set
            ld   hl,sCE
            call ms_cat
            ld   hl,s_hit
            call ms_cat
            jp   L1315
L980:       xor  a
            ld   (bNT),a
            inc  a
            ld   (bSW),a
            ld   (bTD),a
            call sz_sh
            ld   a,(bSU)
            add  a,c
            ld   (bSU),a
            call L2622
            ld   a,(bBD)
            cp   1
            jp   nz,L980a
            call L1795
            jp   L981
L980a:      call L1755
            ld   a,(bTU)
            or   a
            jp   nz,L981
            ld   a,(bAM)
            or   a
            call z,L1930
L981:       ld   a,(bZT)                ; IF SH>ZT THEN GOSUB 4170
            ld   b,a
            ld   a,(bSH)
            cp   b
            jp   z,L990
            jp   c,L990
            call L4170
L990:       ld   hl,bEK
            inc  (hl)
            ld   a,(bBD)
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
            call ms_set
            call n_sh
            call ms_cat
            call L1315
L992:       ld   a,(bBD)
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
fxfy:       ld   a,(bFY)
            ld   e,a
            ld   a,(bFX)
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
