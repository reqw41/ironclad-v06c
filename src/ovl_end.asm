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
            ld   bc,X_KEYS_HDR*256+14
            ld   a,15
            call gfx_pset
            call fg15
            call putsi
            TXT  "КЛАВИШИ","KEYS"
L3901:      SETV hk_y,36  ; колонка 110 (в оригинале — в CX, см. docs)
            ld   hl,keys_tab
L3903:      ld   a,(hl)
            cp   '!'
            jp   z,L3910
L3905:      push hl
            call str_len                ; X=94-8*LEN(A$) (в оригинале 110 и 126 — русские пояснения длиннее)
            add  a,a
            add  a,a
            add  a,a
            ld   b,a
            ld   a,X_HELP_KEY
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
            ld   b,X_HELP_TXT
            ld   a,5
            call gfx_pset
            pop  hl
            call gfx_puts
            inc  hl
            LDV  hk_y
            add  a,18
            STV  hk_y
            jp   L3903
L3910:      ld   bc,X_PRESSKEY*256+190
            ld   a,11
            call gfx_pset
            ld   hl,s_press_key_back
            call gfx_puts
L3920:      call getkey
            STV  bK_
            ret

; 9070: подписи клавиш (пары строк, "!" — конец)
keys_tab:   TXT  "СТРЕЛКИ","ARROWS"
            TXT  "КУРСОР","MOVE"
            TXT  "ПРОБЕЛ","SPACE"
            TXT  "ОГОНЬ / ПОСТАВИТЬ","FIRE OR DROP"
            TXT  "Р","R"
            TXT  "РАЗВЕРНУТЬ","TURN SHIP"
            TXT  "У","U"
            TXT  "УБРАТЬ ПОСЛЕДНИЙ","UNDO"
            TXT  "А","Z"
            TXT  "АВТОРАССТАНОВКА","AUTO-PLACE"
            TXT  "Б","X"
            TXT  "БУЙ (МЕТКА)","BUOY MARK"
            TXT  "ТАБ","TAB"
            TXT  "ДРУГОЕ ПОЛЕ","SWITCH VIEW"
            TXT  "М","Q"
            TXT  "МЕНЮ (ДВАЖДЫ)","MENU (TWICE)"
            TXN  "!"

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
            call o2_showpg
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
            call o2_showpg
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

; страница A (доски) после картинки итога: поля экрана — снова слот 0 (cls1 льёт только 212
; видимых строк MSX), тайлы — через резидентную обёртку
o2_showpg:
            IFNDEF DISK                 ; (у дисковой версии поля экрана — индекс 0 всегда)
            push af
            xor  a
            call end_margins
            pop  af
            ENDIF
            jp   o_showpg

; экран победы/поражения (страница 2): VICTORY.SC5 / DEFEAT.SC5 (GOSUB 2508 — палитра 9042),
; 6 цветов картинки + белый: данные во всех плоскостях экрана с $8000; белый — свой слот (его
; номер — в cmap картинки для цвета 1): поля экрана (строки памяти 0..21, 234..255) заливает
; end_margins, бордюр Вектора — индекс 2*слот (как COLOR 15,1,1 MSX: бордюр белый).
show_end_image:
            call disp_blank
            SETV pg_vis,2
            IFDEF DISK
            ; 16 цветов с дискеты: палитра 9042 как есть, белый бордюр — индекс 0 палитры (цвет 1),
            ; поля экрана в картинке — нули, то есть тоже белые
            ld   de,FD_DEFEAT
            ld   hl,pal_defeat
            CPV  bWN,1
            jp   nz,sei_d
            ld   de,FD_VICTORY
            ld   hl,pal_victory
sei_d:      push hl
            call disk_pic
            xor  a
            ld   (vec_border),a
            pop  hl
            call pal_set
            call end_captions
            ELSE
            IFNDEF NOIMG
            ld   hl,img_defeat
            ld   de,pal_defeat
            ld   bc,cmap_defeat+1
            CPV  bWN,1
            jp   nz,sei_1
            ld   hl,img_victory
            ld   de,pal_victory
            ld   bc,cmap_victory+1
sei_1:      push de
            ld   a,(bc)                 ; слот белого (цвет 1) << 5
            push af
            ld   de,8000h               ; данные — все плоскости экрана подряд с $8000
            call dzx0
            pop  af
            push af
            call end_margins            ; поля экрана — белым
            pop  af
            rrca
            rrca
            rrca
            rrca
            ld   (vec_border),a         ; бордюр — белый (индекс 2*слот), как COLOR 15,1,1 MSX
            pop  hl
            call pal_set
            call end_captions
            ENDIF
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
cap_victory: db   X_CAP_WIN,168,1,1              ; по центру: x = (256 - 8*длина)/2
             TXT  "ПОБЕДА ЗА ВАМИ!","YOU ARE VICTORIOUS!"
cap_defeat:  db   X_CAP_LOSE,168,1,1
             TXT  "ВАШ ФЛОТ УНИЧТОЖЕН.","YOUR FLEET HAS BEEN DESTROYED."
cap_keys:    db   X_CAP_TAB,186,2,0              ; клавиши кончаются на x=101, пояснения с 107 (блок по центру)
             TXT  "ТАБ:","TAB:"
             db   X_CAP_TXT,186,7,0
             TXT  "ПОСМОТРЕТЬ ПОЛЯ","REVIEW THE BOARDS"
             db   X_CAP_SPC,197,2,0
             TXT  "ПРОБЕЛ:","SPACE:"
             db   X_CAP_TXT,197,7,0
             TXT  "ДАЛЬШЕ","CONTINUE"
             db 0

; поля экрана (строки памяти 0..21 и 234..255) — цвет слота A во всех плоскостях (данные
; картинки в полях — нули)
            IFNDEF DISK
end_margins:                            ; A = слот << 5 (биты 7,6,5 — плоскости $8000,$A000,$C000)
            ld   c,a
            ld   hl,8000h+234           ; столбец: строки 234..255, затем 0..21 (L переполняется)
em_p:       ld   a,c                    ; байт полей этой плоскости: FF, если бит слота 1
            rlca
            ld   c,a
            sbc  a,a
            ld   b,a
em_1:       ld   (hl),b
            inc  l
            ld   a,l
            cp   22
            jp   nz,em_1
            ld   l,234
            inc  h                      ; следующий столбец
            ld   a,h
            and  1Fh
            jp   nz,em_1
            ld   a,h                    ; начало следующей плоскости
            cp   80h+NPL*20h
            jp   nz,em_p
            ret
            ENDIF


