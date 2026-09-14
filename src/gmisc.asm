; ============================================================================
; gmisc.asm — перевод IRONCLAD.BAS: 2010..2645, 3304..3472, 3900..3960;
; полная перерисовка страницы после экрана помощи/победы (render_full).
; ============================================================================

; ---------------------------------------------------------------- 381/2062: корабль SH в PS, PX, PY
ship_to_ps:
            ZEROV bI
stp_1:      call tx_i                   ; B = TX(I), C = TY(I)
            push bc
            LDV  bI
            ld   hl,ARR_GT
            rst  00h
            ld   l,(hl)                 ; SH+16*GT(I)
            ld   h,0
            add  hl,hl
            add  hl,hl
            add  hl,hl
            add  hl,hl
            LDV  bSH
            rst  00h
            ex   de,hl
            pop  bc
            push bc
            ld   a,b
            push de
            ld   e,c
            ld   bc,ARR_PS
            call w10
            pop  de
            ld   (hl),e
            inc  hl
            ld   (hl),d
            pop  bc
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
            ld   hl,s_placing
            call ms_set
            call L1305
            LDV  bRW
            or   a
            jp   z,L2020
            call gh_erase
            ZEROV bRW
L2020:      ld   hl,(bAT)
            inc  hl
            ld   (bAT),hl
            ld   de,-1001
            add  hl,de
            jp   nc,L2030
            ld   hl,s_no_room
            call ms_set
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
            ld   hl,s_nothing_undo
            call ms_set
            jp   L1305
L2110:      ld   hl,bSH
            dec  (hl)
            ld   hl,bNP
            dec  (hl)
L2112:      ZEROV bI  ; PS(PX(SH,I),PY(SH,I))=0
L2112a:     call pxy_off
            ld   de,ARR_PX
            add  hl,de
            ld   a,(hl)
            ld   de,60
            add  hl,de
            ld   e,(hl)
            ld   bc,ARR_PS
            call w10
            ld   (hl),0
            inc  hl
            ld   (hl),0
            INCV bI
            call sz_sh
            LDV  bI
            cp   c
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
            add  a,a
            add  a,a
            ld   b,a
            add  a,a
            add  a,b
            ld   b,a
            LDV  bN
            add  a,b
            ld   hl,ARR_PX
            rst  00h
            ld   b,(hl)
            ld   de,60
            add  hl,de
            ld   c,(hl)
            LDV  bI
            add  a,a
            ld   hl,ARR_TX
            rst  00h
            ld   (hl),b
            inc  hl
            ld   (hl),0
            LDV  bI
            add  a,a
            ld   hl,ARR_TY
            rst  00h
            ld   (hl),c
            inc  hl
            ld   (hl),0
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
            ld   hl,ARR_PX
            rst  00h
            ld   a,(hl)
            STV  bCX
            ld   b,a
            ld   de,60
            add  hl,de
            ld   a,(hl)
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
            jp   L2235
L2220:      ld   bc,ARR_CS              ; вскрыть корабль противника на странице 0
            call w10cr
            call ld_hl_de
            call shr4_de
            ld   a,e
            STV  bQ
            xor  a
            ld   d,0
            call cr_op
            LDV  bQ
            and  31
            ld   d,a
            xor  a
            call cr_tp
            ld   bc,ARR_CM
            call w10cr
            call ld_hl_de
            ex   de,hl
            ld   (bM),hl
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
            xor  a
            jp   cr_tp
L2235:      ld   hl,s_enemy_wins
            SETV bMC,8
            CPV  bWN,1
            jp   nz,L2235a
            ld   hl,s_you_win
            SETV bMC,9
L2235a:     push hl
L2236:      ld   hl,bGC                 ; IF WN=1 THEN GW=GW+1 ELSE GC=GC+1
            CPV  bWN,1
            jp   nz,L2236a
            ld   hl,bGW
L2236a:     inc  (hl)
L2237:      pop  hl                     ; MS$=SPACE$((31-LEN(MS$))\2)+MS$
            push hl
            call str_len
            ld   b,a
            ld   a,31
            sub  b
            or   a
            rra
            ld   b,a
            ld   hl,sMS
L2237a:     ld   a,b
            or   a
            jp   z,L2237b
            ld   (hl),' '
            inc  hl
            dec  b
            jp   L2237a
L2237b:     ex   de,hl
            pop  hl
            call str_copy
L2238:      CPV  bSB,1
            call z,L1396
L2240:      call L1306
L2246:      ZEROV bMD  ; MD=(GW+GW>BO OR GC+GC>BO)
            LDV  bBO
            ld   b,a
            LDV  bGW
            add  a,a
            cp   b
            jp   z,L2246a
            jp   nc,L2246b
L2246a:     LDV  bGC
            add  a,a
            cp   b
            jp   z,L2250
            jp   c,L2250
L2246b:     SETV bMD,-1
L2250:      ZEROV bAF  ; AF=0: IF MD THEN BLOAD картинки на страницу 2: AF=1
            LDV  bMD
            or   a
            jp   z,L2251
            ld   a,DLY_LOAD             ; на MSX картинка грузится с диска, пока видна доска
            call wait_frames
            IFNDEF NOIMG
            SETV bAF,1  ; без файла картинки AF=0 (ON ERROR GOTO 2258)
            ENDIF
L2251:      CPV  bAF,1
            jp   nz,L2251a
            call show_end_image         ; GOSUB 2508: VP=2: SET PAGE 2,2
            SETV bVP,2
            jp   L2252
L2251a:     ZEROV bVP
            call page_show
L2252:      call L3330
L2260:      call getkey
            STV  bK_
L2265:      cp   9
            jp   z,L2266
            call disp_blank
            call L2505
            LDV  bDP
            call page_show
            call disp_on
            LDV  bMD
            or   a
            jp   nz,L2270
            jp   L2254
L2266:      LDV  bVP                ; VP=VP+1: IF VP>2 THEN VP=0
            inc  a
            cp   3
            jp   c,L2267
            xor  a
L2267:      STV  bVP
            cp   2                      ; IF VP=2 AND AF=0 THEN VP=0
            jp   nz,L2268
            LDV  bAF
            or   a
            jp   nz,L2268
            ZEROV bVP
L2268:      CPV  bVP,2
            jp   nz,L2268a
            call show_end_image
            jp   L2260
L2268a:     call disp_blank
            call L2505
            LDV  bVP
            call page_show
            call disp_on
            jp   L2260
L2254:      ld   hl,s_loading_next
            call ms_set
            call L1315
            INCV bGN
            LDV  bFS
            xor  1
            STV  bFS
L2255:      ld   hl,ARR_PS              ; PS, PM, CM = 0
            ld   de,200
            call memzero
            ld   hl,ARR_PM
            ld   de,200
            call memzero
            ld   hl,ARR_CM
            ld   de,200
            call memzero
L2256:      ld   hl,ARR_PH              ; PH, QH, HS = 0
            ld   de,24
            call memzero
            ld   hl,ARR_QH
            ld   de,12
            call memzero
            ld   hl,ARR_HS
            ld   de,60
            call memzero
L2257:      jp   L221
L2270:      ld   hl,s_loading_menu
            call ms_set
            call L1315
            jp   setup_run              ; RUN "SETUP.BAS"

DLY_LOAD    equ 50                      ; ~1 с: картинка победы грузилась с диска

; экран победы/поражения (страница 2): VICTORY.SC5 / DEFEAT.SC5 (GOSUB 2508 — палитра 9042)
; 8 цв.: 3 плоскости с $8000. 4 цв.: 2 плоскости с $A000, в $8000 — поля экрана белым
; (слот 4 = белый бордюр MSX), бордюр Вектора — индекс 8.
show_end_image:
            call disp_blank
            SETV pg_vis,2
            IFNDEF NOIMG
            CPV  bWN,1
            jp   z,sei_v
            ld   hl,img_defeat
            ld   de,pal_defeat
            ld   a,DEFEAT_PLANES
            jp   sei_1
sei_v:      ld   hl,img_victory
            ld   de,pal_victory
            ld   a,VICTORY_PLANES
sei_1:      push de
            cp   3
            jp   z,sei_3
            ld   de,0A000h
            call dzx0
            call end_margins
            ld   a,BORDER_4C
            jp   sei_2
sei_3:      ld   de,8000h
            call dzx0
            xor  a
sei_2:      ld   (vec_border),a
            pop  hl
            call pal_set
            call end_captions
            ENDIF
            jp   disp_on

; подписи экрана итога (в оригинале нарисованы в картинке, строки 168..203):
; заголовок — жирно с шагом 8, клавиши и пояснения — шагом 6, фон — цвет 5
end_captions:
            ld   hl,cmap_defeat
            ld   de,cap_defeat
            CPV  bWN,1
            jp   nz,ec_1
            ld   hl,cmap_victory
            ld   de,cap_victory
ec_1:       ld   (cur_cmap),hl
            ld   a,5
            ld   (gfx_bg),a
            push de
            call ec_line                ; заголовок
            ld   hl,cap_keys
ec_2:       ld   a,(hl)
            or   a
            jp   z,ec_3
            ex   de,hl
            call ec_line
            ex   de,hl
            jp   ec_2
ec_3:       pop  de
            ld   a,8
            ld   (gfx_pitch),a
            xor  a
            ld   (gfx_bold),a
            inc  a
            ld   (gfx_bg),a
            ret
; DE -> x, y, цвет, жирно(0/1), текст, 0  ->  DE за нулём
ec_line:    ex   de,hl
            ld   b,(hl)
            inc  hl
            ld   c,(hl)
            inc  hl
            ld   a,(hl)
            ld   (gfx_fg),a
            inc  hl
            ld   a,(hl)
            ld   (gfx_bold),a
            inc  hl
            push hl
            or   a
            ld   a,6
            jp   z,ecl_1
            ld   a,8
ecl_1:      ld   (gfx_pitch),a
            ld   a,b
            ld   (gfx_x),a
            ld   a,c
            ld   (gfx_y),a
            pop  hl
            call gfx_puts ; gfx_puts
            inc  hl
            ex   de,hl
            ret
cap_victory: db 52,168,1,1,"YOU ARE VICTORIOUS!",0
cap_defeat:  db 8,168,1,1,"YOUR FLEET HAS BEEN DESTROYED.",0
cap_keys:    db 68,186,2,0,"TAB:",0
             db 98,186,7,0,"REVIEW THE BOARDS",0
             db 56,197,2,0,"SPACE:",0
             db 98,197,7,0,"CONTINUE",0
             db 0

; плоскость $8000 для 4-цветной картинки: поля экрана (строки памяти 0..21 и 234..255) = FF
end_margins:
            ld   hl,8000h
em_1:       ld   a,l
            cp   22
            jp   c,em_ff
            cp   234
            jp   nc,em_ff
            ld   (hl),0
            jp   em_2
em_ff:      ld   (hl),0FFh
em_2:       inc  hl
            ld   a,h
            cp   0A0h
            jp   nz,em_1
            ret

; HL, DE = длина: обнулить
memzero:    ld   (hl),0
            inc  hl
            dec  de
            ld   a,d
            or   e
            jp   nz,memzero
            ret

; ---------------------------------------------------------------- 2350: выход в меню
L2350:      ld   hl,s_terminate
            call ms_set
            call L1305
            ZEROV bAB
L2352:      call getkey
            STV  bK_
L2354:      call upcase
            cp   'Q'
            jp   nz,L2356
            SETV bAB,1
L2356:      call ms_clear
            jp   L1305
L2360:      ld   hl,s_loading_menu
            call ms_set
            call L1315
            jp   setup_run

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
L3440:      ld   a,2
            call rnd_n
            STV  bOD
            call sz_sh
            ld   a,c
            STV  bS
            LDV  bOD
            or   a
            jp   nz,L3441
            LDV  bS
            ld   b,a
            ld   a,11
            sub  b
            call rnd_n
            STV  bCX
            ld   a,10
            call rnd_n
            STV  bCY
            ret
L3441:      ld   a,10
            call rnd_n
            STV  bCX
            LDV  bS
            ld   b,a
            ld   a,11
            sub  b
            call rnd_n
            STV  bCY
            ret

; 3460/3470: AL = кораблей на плаву (своих: PH(I)<SZ(I); противника: QH(I)<SZ(I))
L3460:      ZEROV bAL
            inc  a
            STV  bI
L3460a:     LDV  bI
            ld   hl,ARR_PH
            add  a,a
            rst  00h
            ld   b,(hl)
            call sz_i
            ld   a,b
            cp   c
            jp   nc,L3462
            INCV bAL
L3462:      INCV bI
            LDV  bNK
            cp   (hl)
            jp   nc,L3460a
            ret
L3470:      ZEROV bAL
            inc  a
            STV  bI
L3470a:     LDV  bI
            ld   hl,ARR_QH
            rst  00h
            ld   b,(hl)
            call sz_i
            ld   a,b
            cp   c
            jp   nc,L3472
            INCV bAL
L3472:      INCV bI
            LDV  bNK
            cp   (hl)
            jp   nc,L3470a
            ret

; ---------------------------------------------------------------- 3900: помощь по клавишам (страница 2)
L3900:      SETV pg_vis,2
            call cls1
            ld   bc,6*256+6
            ld   de,249*256+205
            ld   a,3
            call gfx_box
            ld   bc,104*256+14
            ld   a,15
            call gfx_pset
            ld   a,15
            ld   (gfx_fg),a
            ld   hl,s_keys
            call gfx_puts
L3901:      SETV hk_y,36  ; колонка 110 (в оригинале — в CX, см. docs)
            ld   hl,keys_tab
L3903:      ld   a,(hl)
            cp   '!'
            jp   z,L3910
L3905:      push hl
            call str_len                ; X=110-8*LEN(A$)
            add  a,a
            add  a,a
            add  a,a
            ld   b,a
            ld   a,110
            sub  b
            ld   b,a
            LDV  hk_y
            ld   c,a
            ld   a,15
            call gfx_pset
            pop  hl
            call gfx_puts
            inc  hl
            push hl
            ld   a,':'
            call gfx_putc
            LDV  hk_y
            ld   c,a
            ld   b,126
            ld   a,5
            call gfx_pset
            pop  hl
            call gfx_puts
            inc  hl
            LDV  hk_y
            add  a,18
            STV  hk_y
            jp   L3903
L3910:      ld   bc,40*256+190
            ld   a,11
            call gfx_pset
            ld   hl,s_press_key_back
            call gfx_puts
L3920:      call getkey
            STV  bK_
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
            ex   de,hl
            LDV  bM
            ld   b,a
            LDV  bM+1
            or   b
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
L3946:      SETV bSD,1
            call cr_cxcy
            jp   L1105

; 3960: MS$="PLACE "+N$(SH)+SPACE$(19-LEN(N$(SH)))+"?:HELP": ... подсказка клавиш
L3960:      ld   hl,s_place
            call ms_set
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
L3960b:     ld   hl,s_help
            call ms_cat
            call L1305
            ld   hl,s_place_keys
            call ms_set
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
            LDV  sl_n               ; строка счёта 1396 — как была напечатана
            push af
            ZEROV sl_n
            LDV  bSB
            push af
            ZEROV bSB
            call L1355s
            pop  af
            STV  bSB
            pop  af
            STV  sl_n
            CPV  bSB,1
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
            CPV  bBD,1
            jp   nz,rf_2
            call L3820
            SETV bSH,1
rf_sh:      call L3884
            INCV bSH
            LDV  bNK
            cp   (hl)
            jp   nc,rf_sh
rf_2:       SETV bMY,192
            call msg_draw_my
            SETV bMY,202
            call msg_draw_my
            ld   hl,ARR_MG
            ld   de,bKA
            ld   bc,bMI-bKA
            call memcpy
            ld   bc,0                   ; клетки, призрак, курсор, AT:
rf_c:       push bc
            call cell_redraw
            pop  bc
            inc  c
            ld   a,c
            cp   10
            jp   nz,rf_c
            ld   c,0
            inc  b
            ld   a,b
            cp   10
            jp   nz,rf_c
            call gh_draw
            LDV  pg_vis
            or   a
            jp   nz,rf_3
            LDV  cur_on
            or   a
            call nz,cur_draw
rf_3:       call at_draw_vis
            ld   a,15
            ld   (gfx_fg),a
            jp   disp_on


s_placing:      db "PLACING FLEET ...",0
s_no_room:      db "NO ROOM",0
s_nothing_undo: db "NOTHING TO UNDO",0
s_enemy_wins:   db "ENEMY WINS",0
s_you_win:      db "YOU WIN",0
s_loading_next: db "LOADING NEXT GAME ...",0
s_loading_menu: db "LOADING MENU ...",0
s_terminate:    db "TERMINATE GAME? Q AGAIN",0
s_keys:         db "KEYS",0
s_press_key_back: db "Press a key to go back",0
s_place:        db "PLACE ",0
s_help:         db "?:HELP",0
s_place_keys:   db "SPC:DROP R:TURN U:UNDO Z:AUTO",0
; 9070: подписи клавиш (пары строк, "!" — конец)
keys_tab:   db "ARROWS",0,"MOVE",0
            db "SPACE",0,"FIRE OR DROP",0
            db "R",0,"TURN SHIP",0
            db "U",0,"UNDO",0
            db "Z",0,"AUTO-PLACE",0
            db "X",0,"BUOY MARK",0
            db "TAB",0,"SWITCH VIEW",0
            db "Q",0,"MENU (TWICE)",0
            db "!",0
