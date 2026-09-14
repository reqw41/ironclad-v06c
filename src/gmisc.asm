; ============================================================================
; gmisc.asm — перевод IRONCLAD.BAS: 2010..2645, 3304..3472, 3900..3960;
; полная перерисовка страницы после экрана помощи/победы (render_full).
; ============================================================================

; ---------------------------------------------------------------- 381/2062: корабль SH в PS, PX, PY
ship_to_ps:
            ZEROV bI
stp_1:      ld   hl,ARR_PS               ; PS(TX,TY)=SH+16*GT(I): PX(SH,I)=TX: PY(SH,I)=TY
            call shgt_set
            call px_set
            INCV bI
            LDV  bTN
            cp   (hl)
            jp   nz,stp_1
            ret
; 383/2064: FOR I=0 TO TN-1: C=TX(I): R=TY(I): SD=0: GOSUB 1105
ship_draw1:
            ZEROV bI
sd1_1:      ZEROV bSD
            call tx_i
            ld   a,b
            STV  bC
            ld   a,c
            STV  bR
            call L1105
            INCV bI
            LDV  bTN
            cp   (hl)
            jp   nz,sd1_1
            ret

; ---------------------------------------------------------------- 2010: авторасстановка
L2010:      ld   hl,0
            ld   (bAT),hl
            call msg1i
            TXT  "PLACING FLEET ..."
            LDV  bRW
            or   a
            jp   z,L2020
            call gh_erase
            ZEROV bRW
L2020:      call at_inc
            jp   nc,L2030
            call ms_seti
            TXT  "NO ROOM"
            jp   L1305
L2030:      call L3440
L2040:      call L1615
L2050:      LDV  bLG
            or   a
            jp   z,L2020
L2060:      call L1652
L2062:      call ship_to_ps
L2064:      call L1683
            INCV bNP
            call ship_draw1
L2070:      INCV bSH
            ld   hl,0
            ld   (bAT),hl
            LDV  bNK
            ld   hl,bSH
            cp   (hl)
            jp   nc,L2020
L2080:      ZEROV bRW
            STV  bSD
            call gh_forget
L2085:      jp   L2635                  ; COPY стр.1 -> стр.2: записи клеток

; ---------------------------------------------------------------- 2108: отмена
L2108:      CPV  bSH,2
            jp   nc,L2110
            call ms_seti
            TXT  "NOTHING TO UNDO"
            jp   L1305
L2110:      ld   hl,bSH
            dec  (hl)
            ld   hl,bNP
            dec  (hl)
L2112:      ZEROV bI  ; PS(PX(SH,I),PY(SH,I))=0
L2112a:     call pxy_off
            call pxy_hl
            ld   bc,ARR_PS
            call w10
            ld   (hl),0
            inc  hl
            ld   (hl),0
            call next_i_sz
            jp   c,L2112a
L2114:      call L1694
L2115:      CPV  bSH,2
            jp   c,L2124
L2116:      LDV  bSH                ; FOR N=1 TO SH-1: TN=SZ(N): TX/TY = PX/PY(N,I): GOSUB 1683
            STV  rp_tmp+3
            SETV bN,1
L2116a:     LDV  bN
            call sz_a
            ld   a,c
            STV  bTN
            ZEROV bI
L2118:      LDV  bI                 ; TX(I)=PX(N,I): TY(I)=PY(N,I)
            call x12
            ld   b,a
            LDV  bN
            add  a,b
            call pxy_a
            ld   b,a
            LDV  bI
            call txy_set
            INCV bI
            LDV  bTN
            cp   (hl)
            jp   nz,L2118
L2120:      call L1683
L2122:      INCV bN
            LDV  rp_tmp+3
            cp   (hl)
            jp   nz,L2116a
L2124:      ZEROV bRW
            STV  bLS
            dec  a
            STV  bLO
            STV  bLX
            STV  bLY
            call gh_forget
L2126:      ZEROV bSD
            call L1152
L2128:                                  ; COPY стр.1 -> стр.2: записи клеток
L2130:      LDV  bSH                ; CX=PX(SH,0): CY=PY(SH,0): OD=1: IF PX(SH,0)<>PX(SH,1) THEN OD=0
            call pxy_a
            STV  bCX
            ld   b,a
            ld   a,e
            STV  bCY
            SETV bOD,1
            LDV  bSH
            add  a,12
            ld   hl,ARR_PX
            rst  00h
            ld   a,(hl)
            cp   b
            ret  z
            ZEROV bOD
            ret

; ---------------------------------------------------------------- 2210: конец партии
L2210:      ZEROV bFB
            CPV  bBD,1
            call z,L4103
L2211:      call L3322
            ZEROV bDP
            call page_show
L2215:      ZEROV bC  ; FOR C=0 TO 9: FOR R=0 TO 9: IF CS(C,R)>0 THEN GOSUB 2220
L2215a:     ZEROV bR
L2215b:     ld   bc,ARR_CS
            call w10cr
            call hl_pos
            call nz,L2220
            INCV bR
            ld   a,(hl)
            cp   10
            jp   c,L2215b
            INCV bC
            ld   a,(hl)
            cp   10
            jp   c,L2215a
            jp   L2235r
L2220:      call q_cs                   ; вскрыть корабль противника на странице 0
            xor  a
            ld   d,0
            call cr_op
            LDV  bQ
            and  31
            ld   d,a
            call cr_tp0
            call m_cm
L2222:      CPV  bBD,1
            jp   nz,L2225
            ld   a,h                    ; IF M>0 THEN GOSUB 1147
            or   a
            ret  m
            or   l
            ret  z
            ld   a,l
            jp   L1147
L2225:      ld   a,l                    ; IRONCLAD.BAS: M=2 -> попадание, M=3 -> потоплен
            cp   2
            jp   z,L2225a
            cp   3
            ret  nz
L2225a:     ld   d,a
            jp   cr_tp0
; 2235..2270 и экран итога (2508) — в оверлее 2 (ovl_end.asm): здесь только обёртки,
; которым оверлей отдаёт всё, что рисует тайлы и глифы (они в том же буфере)
L2235r:     call ovl2_load
            jp   o2_L2235
; оверлей 2 (помощь, итог) -> хвост буфера тайлов, за оверлеем меню
ovl2_load:  ld   hl,ovl_end_zx0
            ld   de,ovl_end
            jp   dzx0
; show_pg (страница A) из оверлея: тайлы и глифы на место, страница, оверлей обратно
o_showpg:   push af
            call tiles_load
            pop  af
            call show_pg
            jp   ovl2_load
; экран погашен: палитра игры, страница A, экран включён
show_pg:    push af
            call disp_blank
            call L2505
            pop  af
            call page_show
            jp   disp_on
; 2257 -> 221 (следующая партия): тайлы на место
o_next:     call tiles_load
            jp   L221

; ---------------------------------------------------------------- 2350: выход в меню
L2350:      call msg1i
            TXT  "TERMINATE GAME? Q AGAIN"
            ZEROV bAB
L2352:      call getkey
            STV  bK_
L2354:      call upcase
            cp   'Q'
            jp   nz,L2356
            SETV bAB,1
L2356:      call ms_clear
            jp   L1305
L2360:      jp   setup_run              ; RUN "SETUP.BAS" (без «LOADING MENU ...»)

; ---------------------------------------------------------------- 2505/2508: палитры
L2505:      ld   hl,cmap_game           ; цвета игры (8 слотов), бордюр — слот 0
            ld   (cur_cmap),hl
            xor  a
            ld   (vec_border),a
            ld   hl,pal_game
            jp   pal_set

; ---------------------------------------------------------------- 2600: звуки
L2605:      ld   a,17
            ld   c,5
            jp   snd_noise
L2615:      ld   a,25
            ld   c,14
            jp   snd_noise
L2622:      ld   a,30
            ld   c,31
            call snd_noise
L2625:      ld   a,DLY_400
            call wait_frames
L2627:      ld   hl,mus_sunk
            jp   mus_start
L2635:      ld   hl,mus_blip
            jp   mus_start
L2645:      ld   a,6
            ld   c,2
            jp   snd_noise

; ---------------------------------------------------------------- 3322/3330
L3322:      jp   cur_hide               ; PUT SPRITE 0,(0,200),0 на странице 0
L3330:      ZEROV bKQ  ; KQ$="": выбрать буфер клавиш
L3330a:     call inkey
            jp   nz,L3330a
            ret

; ---------------------------------------------------------------- 3440: случайное место корабля
L3440:      ld   a,2                    ; OD=RND: OD=0 — CX=RND(11-S): CY=RND(10), OD=1 — CX=RND(10): CY=RND(11-S)
            call rnd_n
            STV  bOD
            call sz_sh
            ld   a,c
            STV  bS
            ld   b,a
            ld   a,11
            sub  b
            ld   b,a
            ld   c,10
            LDV  bOD
            or   a
            jp   z,L3441
            ld   a,b
            ld   b,c
            ld   c,a
L3441:      push bc
            ld   a,b
            call rnd_n
            STV  bCX
            pop  bc
            ld   a,c
            call rnd_n
            STV  bCY
            ret

; 3460/3470: AL = кораблей на плаву (своих: PH(I)<SZ(I); противника: QH(I)<SZ(I))
L3460:      ld   hl,i_ph_sz
            jp   al_cnt
L3470:      ld   hl,i_qh_sz
; AL = число I=1..NK, у которых (процедура HL: B = попаданий, C = SZ(I)) B < C
al_cnt:     push hl
            ZEROV bAL
            inc  a
            STV  bI
al_1:       pop  hl
            push hl
            call scn_c
            ld   a,b
            cp   c
            jp   nc,al_2
            INCV bAL
al_2:       INCV bI
            LDV  bNK
            cp   (hl)
            jp   nc,al_1
            pop  hl
            ret

; ---------------------------------------------------------------- 3900: помощь по клавишам (страница 2)
L3900:      call ovl2_load              ; 3900..3920 — в оверлее 2: рисует помощь, ждёт клавишу
            call o2_help
            call tiles_load             ; оверлей стоял поверх тайлов и глифов — до перерисовки
L3922:      LDV  bDP
            call page_show
            LDV  bFB
            or   a
            jp   z,L3960
            call ms_clear
            call L1305
            jp   L1315

; ---------------------------------------------------------------- 3940: буй игрока (X)
L3940:      LDV  bFB
            or   a
            ret  z
L3942:      call cm_cxcy
            ld   e,(hl)
            inc  hl
            ld   d,(hl)
            dec  hl
            ex   de,hl
            ld   (bM),hl
            ld   b,l
            ld   a,h
            or   l
            ex   de,hl
            jp   nz,L3942a
            ld   (hl),-3                ; M=0 -> -3
            inc  hl
            ld   (hl),-1
            jp   L3946
L3942a:     CPV  bM+1,0FFh
            jp   nz,L3943
            ld   a,b
            cp   -3
            jp   nz,L3943
            ld   (hl),-4                ; -3 -> -4
            jp   L3946
L3943:      LDV  cfg_fam
            or   a
            jp   z,L3944
            CPV  bM+1,0FFh  ; сборки BD: -4 -> 0, 1..64 -> +64, 65..128 -> -64
            jp   nz,L3943a
            ld   a,b
            cp   -4
            ret  nz
            jp   L3943z
L3943a:     ld   a,b                    ; M > 0 (старший байт 0)
            cp   65
            jp   nc,L3943b
            add  a,64
            ld   (hl),a
            jp   L3946
L3943b:     cp   129
            ret  nc
            sub  64
            ld   (hl),a
            jp   L3946
L3944:      CPV  bM+1,0FFh  ; IRONCLAD.BAS: -4 -> 0, иначе ничего
            ret  nz
            ld   a,b
            cp   -4
            ret  nz
L3943z:     ld   (hl),0
            inc  hl
            ld   (hl),0
L3946:      jp   rd_cxcy

; 3960: MS$="PLACE "+N$(SH)+SPACE$(19-LEN(N$(SH)))+"?:HELP": ... подсказка клавиш
L3960:      call ms_seti
            TXT  "PLACE "
            call n_sh
            push hl
            call ms_cat
            pop  hl
            call str_len
            ld   b,a
            ld   a,19
            sub  b
            ld   b,a
L3960a:     ld   a,b
            or   a
            jp   z,L3960b
            push bc
            ld   a,' '
            call ms_catc
            pop  bc
            dec  b
            jp   L3960a
L3960b:     call ms_cati
            TXT  "?:HELP"
            call L1305
            call ms_seti
            TXT  "SPC:DROP R:TURN U:UNDO Z:AUTO"
            jp   L1315

; ---------------------------------------------------------------- перерисовка страницы (порт)
; После экрана поверх (помощь, победа) страница pg_vis собирается заново:
; статика 1355, панель теми же подпрограммами, строки сообщений, клетки, призрак, курсор, AT:.
render_full:
            call disp_blank
            ld   hl,bKA                 ; переменные BASIC не должны меняться
            ld   de,ARR_MG              ; MG — рабочий массив движка, вне хода противника свободен
            ld   bc,bMI-bKA
            call memcpy
            call cls1
            call hdr_draw
            call L1355s
            CPV  bSB,1                  ; строка счёта 1396 — как была напечатана
            jp   nz,rf_1
            LDV  sl_n
            or   a
            jp   z,rf_1
            ld   hl,sl_v1
            call sl_print
            CPV  sl_n,2
            jp   c,rf_1
            ld   hl,sl_v2
            call sl_print
rf_1:       call L1206
            call panel_bd
rf_2:       SETV bMY,192
            call msg_draw_my
            SETV bMY,202
            call msg_draw_my
            ld   hl,ARR_MG
            ld   de,bKA
            ld   bc,bMI-bKA
            call memcpy
            ld   hl,cell_redraw         ; клетки, призрак, курсор, AT:
            call for_cells
            call gh_draw
            LDV  pg_vis
            or   a
            jp   nz,rf_3
            LDV  cur_on
            or   a
            call nz,cur_draw
rf_3:       call at_draw_vis
            call fg15
            jp   disp_on


s_enemy_wins:   TXT  "ENEMY WINS"
s_you_win:      TXT  "YOU WIN"
s_press_key_back: TXT  "Press a key to go back"
