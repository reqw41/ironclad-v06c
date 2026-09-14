; ============================================================================
; ovl_end.asm — оверлей 2: помощь по клавишам (3900..3920) и конец партии (2235..2270,
; экран итога 2508). Хранится сжатым (ZX0), ovl2_load (gmisc.asm) распаковывает его в хвост
; буфера тайлов — за оверлеем меню (адреса меток не пересекаются). Пока он в буфере, тайлы и
; глифы испорчены: всё, что их рисует (page_show/show_pg -> render_full, клетки), оверлей
; зовёт только через резидентные обёртки o_showpg/o_next, которые возвращают тайлы (а
; o_showpg — затем и оверлей). Из самого оверлея зовутся только: текст (gfx_puts/putc/pset,
; шрифт — вне буфера), gfx_fill/box, str_*, L1300/L1306/L1396 (строки сообщений и счёта),
; L3330/getkey, disp_*, pal_set, dzx0 (картинки), memzero; page_show(0) в 2251a — только
; при pg_vis=0, где он сразу возвращается.
; ============================================================================

; ---------------------------------------------------------------- 3900: помощь по клавишам (страница 2)
o2_help:    SETV pg_vis,2
            call cls1
            ld   bc,6*256+6
            ld   de,249*256+205
            ld   a,3
            call gfx_box
            ld   bc,104*256+14
            ld   a,15
            call gfx_pset
            call fg15
            call putsi
            TXT  "KEYS"
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
            ret

; 9070: подписи клавиш (пары строк, "!" — конец)
keys_tab:   TXT  "ARROWS"
            TXT  "MOVE"
            TXT  "SPACE"
            TXT  "FIRE OR DROP"
            TXT  "R"
            TXT  "TURN SHIP"
            TXT  "U"
            TXT  "UNDO"
            TXT  "Z"
            TXT  "AUTO-PLACE"
            TXT  "X"
            TXT  "BUOY MARK"
            TXT  "TAB"
            TXT  "SWITCH VIEW"
            TXT  "Q"
            TXT  "MENU (TWICE)"
            TXT  "!"

; ---------------------------------------------------------------- 2235..2270: конец партии
o2_L2235:
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
            IFNDEF NOIMG
            SETV bAF,1  ; без файла картинки AF=0 (ON ERROR GOTO 2258)
            ENDIF
L2251:      CPV  bAF,1
            jp   nz,L2251a
            call show_end_image         ; GOSUB 2508: VP=2: SET PAGE 2,2
            SETV bVP,2
            jp   L2252
L2251a:     ZEROV bVP                  ; page_show(0) при pg_vis=0 (2211) — сразу RET, тайлы не рисует
            call page_show
L2252:      call L3330
L2260:      call getkey
            STV  bK_
L2265:      cp   9
            jp   z,L2266
            LDV  bDP
            call o_showpg               ; (тайлы — через резидентную обёртку)
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
L2268a:     LDV  bVP
            call o_showpg
            jp   L2260
L2254:      INCV bGN                    ; (MS$="LOADING NEXT GAME ..." — загрузки с диска нет)
            LDV  bFS
            xor  1
            STV  bFS
L2255:      ld   hl,ARR_PM              ; PS, PM, CM = 0 (лежат подряд: PM, CM, PS)
            ld   de,600
            call memzero
L2256:      ld   hl,ARR_PH              ; PH, QH, HS = 0 (QH, HS — подряд)
            ld   de,24
            call memzero
            ld   hl,ARR_QH
            ld   de,72
            call memzero
L2257:      jp   o_next                 ; 221 — с тайлами
L2270:      jp   setup_run              ; RUN "SETUP.BAS" (без «LOADING MENU ...» — загрузки с диска нет)

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
cap_victory: db   52,168,1,1
             TXT  "YOU ARE VICTORIOUS!"
cap_defeat:  db   8,168,1,1
             TXT  "YOUR FLEET HAS BEEN DESTROYED."
cap_keys:    db   68,186,2,0
             TXT  "TAB:"
             db   98,186,7,0
             TXT  "REVIEW THE BOARDS"
             db   56,197,2,0
             TXT  "SPACE:"
             db   98,197,7,0
             TXT  "CONTINUE"
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


