; ============================================================================
; gdraw.asm — перевод IRONCLAD.BAS: строки 1105..1795 (клетки, панель, сообщения,
; ввод, расстановка) и 3950.
; ============================================================================

DLY_120     equ 5           ; FOR I=1 TO 120: NEXT I — ~0.1 с MSX-BASIC
DLY_400     equ 15          ; FOR I=1 TO 400 — ~0.3 с
DLY_1500    equ 56          ; FOR I=1 TO 1500 — ~1.1 с

; A = страница, D = код: клетка (bC, bR)
cr_op:      push af
            ld   a,(bC)
            ld   b,a
            ld   a,(bR)
            ld   c,a
            pop  af
            jp   cell_op
cr_tp:      push af
            ld   a,(bC)
            ld   b,a
            ld   a,(bR)
            ld   c,a
            pop  af
            jp   cell_tp
; HL = &массив(C,R): BC = база
w10cr:      ld   a,(bR)
            ld   e,a
            ld   a,(bC)
            jp   w10

; ---------------------------------------------------------------- 1105: клетка (C,R)
L1105:      ld   a,(bC)
            ld   b,a
            ld   a,(bR)
            ld   c,a
            call cell_xy
            ld   a,b
            ld   (bDX),a
            ld   a,c
            ld   (bDY),a
L1110:      ld   a,(bSD)
            cp   1
            jp   z,L1130
L1115:      ld   a,1                    ; вода, стр. 1
            ld   d,0
            call cr_op
L1118:      ld   bc,ARR_PS              ; M=PS(C,R)\16: IF M>0 -> тайл корабля, TPSET
            call w10cr
            call ld_hl_de
            call shr4_de
            ex   de,hl
            ld   (bM),hl
            ld   a,h
            or   l
            jp   z,L1119
            ld   a,l
            and  31
            ld   d,a
            ld   a,1
            call cr_tp
L1119:      ld   bc,ARR_PM              ; M=PM(C,R) AND 3
            call w10cr
            ld   a,(hl)
            and  3
            ld   l,a
            ld   h,0
            ld   (bM),hl
            or   a
            jp   nz,L1121
L1120:      ld   bc,ARR_BZ              ; IF BZ(C,R)=3 -> буй (Q,TR), TPSET
            call w10cr
            ld   a,(hl)
            cp   3
            ret  nz
            inc  hl
            ld   a,(hl)
            or   a
            ret  nz
            ld   a,(bQ)
            rrca
            rrca
            rrca
            rrca
            and  0Fh
            ld   d,a
            ld   a,1
            jp   cr_tp
L1121:      cp   1
            jp   nz,L1121a
            ld   a,1                    ; промах — непрозрачно
            ld   d,1
            call cr_op
            jp   L1124
L1121a:     ld   d,a                    ; 2 попадание, 3 потоплен — TPSET
            ld   a,1
            call cr_tp
L1124:      ld   a,(bBD)                ; IF BD=1 THEN NV=PM(C,R)\4: IF 0<NV<33 -> белая цифра NV
            cp   1
            ret  nz
            ld   bc,ARR_PM
            call w10cr
            call ld_hl_de
            ld   a,e                    ; PM >= 0, \4
            rra
            rra
            and  3Fh
            ld   b,a
            ld   a,d
            rrca
            rrca
            and  0C0h
            or   b
            ld   (bNV),a
            ld   b,a
            ld   a,d
            and  0FCh
            ret  nz                     ; NV >= 64
            ld   a,b
            or   a
            ret  z
            cp   33
            ret  nc
            add  a,32-1
            ld   d,a
            ld   a,1
            jp   cr_tp
L1130:      xor  a                      ; вода, стр. 0
            ld   d,0
            call cr_op
L1131:      ld   a,(bBD)
            cp   1
            jp   z,L1146
L1132:      ld   bc,ARR_CM
            call w10cr
            call ld_hl_de
            ex   de,hl
            ld   (bM),hl
            ld   a,h
            or   l
            ret  z
            ld   a,h
            or   a
            jp   m,L3950
L1133:      ld   a,l
            cp   3
            jp   nz,L1136
            ld   bc,ARR_CS              ; Q=CS(C,R)\16: IF Q>0 -> тайл корабля
            call w10cr
            call ld_hl_de
            call shr4_de
            ld   a,e
            ld   (bQ),a
            or   a
            jp   z,L1136
            and  31
            ld   d,a
            xor  a
            call cr_tp
L1136:      ld   a,(bM)
            cp   1
            jp   nz,L1139
            xor  a
            ld   d,1
            jp   cr_op
L1139:      cp   2
            jp   nz,L1142
            xor  a
            ld   d,2
            jp   cr_tp
L1142:      xor  a
            ld   d,3
            jp   cr_tp
L1146:      ld   bc,ARR_CM
            call w10cr
            call ld_hl_de
            ex   de,hl
            ld   (bM),hl
            ld   a,h
            or   l
            ret  z
            ld   a,h
            or   a
            jp   m,L3950
L1147:      ld   a,l                    ; M <= 128
            cp   65
            jp   c,L1148
            dec  a                      ; M=((M-1) AND 31)+1 -> красная цифра M
            and  31
            ld   d,a
            inc  a
            ld   (bM),a
            ld   a,d
            add  a,96
            ld   d,a
            xor  a
            jp   cr_tp
L1148:      cp   33
            jp   c,L1149
            add  a,64-33                ; жёлтая цифра M-33
            ld   d,a
            xor  a
            jp   cr_tp
L1149:      add  a,32-1                 ; белая цифра M-1
            ld   d,a
            xor  a
            jp   cr_tp

; 3950: IF M=-3 THEN буй (176,TR) ELSE (160,TR), TPSET, стр. 0
L3950:      ld   a,(bM)
            cp   -3
            ld   d,11
            jp   z,L3950a
            ld   d,10
L3950a:     xor  a
            jp   cr_tp

; DE = (HL) int16
ld_hl_de:   ld   e,(hl)
            inc  hl
            ld   d,(hl)
            ret
; DE = DE >> 4 (DE >= 0)
shr4_de:    ld   b,4
s4_1:       ld   a,d
            or   a
            rra
            ld   d,a
            ld   a,e
            rra
            ld   e,a
            dec  b
            jp   nz,s4_1
            ret

; ---------------------------------------------------------------- 1152: сетка страницы SD
L1152:      ld   a,(bSD)                ; PG=0: IF SD=0 THEN PG=1
            xor  1
            ld   (bPG),a
L1154:      call cells_water
L1156:      ld   a,(bSD)
            cp   1
            ret  z
            ld   a,(bNP)
            or   a
            ret  z
L1158:      ld   a,1
            ld   (bN),a
L1158a:     xor  a
            ld   (bI),a
L1160:      ld   a,(bN)                 ; C=PX(N,I): R=PY(N,I)
            ld   b,a
            ld   a,(bI)
            add  a,a
            add  a,a
            ld   c,a
            add  a,a
            add  a,c
            add  a,b
            ld   hl,ARR_PX
            call add_a_hl
            ld   a,(hl)
            ld   (bC),a
            ld   de,ARR_PY-ARR_PX
            add  hl,de
            ld   a,(hl)
            ld   (bR),a
            call L1105
L1162:      ld   a,(bN)
            ld   hl,ARR_SZ
            add  a,a
            call add_a_hl
            ld   b,(hl)
            ld   hl,bI
            inc  (hl)
            ld   a,(hl)
            cp   b
            jp   c,L1160
            ld   hl,bN
            inc  (hl)
            ld   a,(bNP)
            cp   (hl)
            jp   nc,L1158a
L1164:      ret

; ---------------------------------------------------------------- 1206: панель флотов
L1206:      ld   bc,190*256+16          ; LINE(190,16)-(255,160),1,BF
            ld   de,255*256+160
            ld   a,1
            call gfx_fill
            xor  a
            ld   (bP),a
L1208:      ld   a,(bP)                 ; Y0=70*P: CL=8+P
            or   a
            ld   a,0
            jp   z,L1208a
            ld   a,70
L1208a:     ld   (bY0),a
            ld   a,(bP)
            add  a,8
            ld   (bCL),a
            ld   a,(bY0)                ; LINE(190,20+Y0)-(255,20+Y0),CL
            add  a,20
            ld   c,a
            ld   e,a
            ld   b,190
            ld   d,255
            ld   a,(bCL)
            call gfx_fill
            ld   a,(bY0)                ; LINE(190,33+Y0)-(255,33+Y0),CL
            add  a,33
            ld   c,a
            ld   e,a
            ld   b,190
            ld   d,255
            ld   a,(bCL)
            call gfx_fill
L1212:      ld   a,(bCL)                ; COLOR CL: PSET(192,23+Y0): PRINT "ENEMY"/"YOURS"
            ld   (gfx_fg),a
            ld   a,(bY0)
            add  a,23
            ld   c,a
            ld   b,192
            ld   a,(bCL)
            call gfx_pset
            ld   hl,s_enemy
            ld   a,(bP)
            or   a
            jp   z,L1212a
            ld   hl,s_yours
L1212a:     call gfx_puts
L1215:      ld   a,15
            ld   (gfx_fg),a
            ld   a,(bBD)
            cp   1
            jp   z,L1231
L1216:      ld   a,1                    ; FOR I=1 TO NK
            ld   (bI),a
L1216a:     ld   a,(bI)
            call y_i                    ; y = 37+Y0+(I-1)*PZ
            ld   c,a
            ld   b,192
            ld   a,15
            call gfx_pset
            ld   a,(bI)
            call n_a
            ld   de,sT
            call cat3
            ld   hl,sT
            call gfx_puts
L1220:      ld   a,(bI)                 ; NH=PH(I): IF P=0 THEN NH=0: IF QH(I)>=SZ(I) THEN NH=5
            ld   hl,ARR_PH
            add  a,a
            call add_a_hl
            ld   a,(hl)
            ld   (bNH),a
            ld   a,(bP)
            or   a
            jp   nz,L1225
            xor  a
            ld   (bNH),a
            ld   a,(bI)
            ld   hl,ARR_QH
            call add_a_hl
            ld   b,(hl)
            call sz_i
            ld   a,b
            cp   c
            jp   c,L1225
            ld   a,5
            ld   (bNH),a
L1225:      ld   a,(bI)
            call y_i
            ld   (bYP),a
            call bars                   ; FOR J=1 TO SZ(I): квадратики
            ld   hl,bI
            inc  (hl)
            ld   a,(bNK)
            cp   (hl)
            jp   nc,L1216a
L1231:      ld   hl,bP
            inc  (hl)
            ld   a,(hl)
            cp   2
            jp   c,L1208
L1255:      ret

; A = 37+Y0+(A-1)*PZ
y_i:        ld   d,a
            ld   a,(bPZ)
            ld   b,a
            ld   a,d
            ld   c,0
yi_1:       dec  a
            jp   z,yi_2
            ld   d,a
            ld   a,c
            add  a,b
            ld   c,a
            ld   a,d
            jp   yi_1
yi_2:       ld   a,(bY0)
            add  a,37
            add  a,c
            ret
; C = SZ(I)
sz_i:       ld   a,(bI)
sz_a:       ld   hl,ARR_SZ
            add  a,a
            call add_a_hl
            ld   c,(hl)
            ret

; 1225/1284: FOR J=1 TO SZ(корабль): CL=9: IF J<=NH THEN CL=8:
;            LINE(216+(J-1)*8,YP)-(220+(J-1)*8,YP+6),CL,BF   (размер: bars_n)
bars:       call sz_i
            ld   a,c
bars_n:     ld   (br_n),a
            ld   a,1
            ld   (br_j),a
br_1:       ld   a,(bNH)
            ld   b,a
            ld   a,(br_j)
            cp   b
            ld   a,8
            jp   z,br_2
            jp   c,br_2
            ld   a,9
br_2:       ld   (bCL),a
            ld   a,(br_j)
            dec  a
            add  a,a
            add  a,a
            add  a,a
            add  a,216
            ld   b,a
            add  a,4
            ld   d,a
            ld   a,(bYP)
            ld   c,a
            add  a,6
            ld   e,a
            ld   a,(bCL)
            call gfx_fill
            ld   hl,br_j
            inc  (hl)
            ld   a,(br_n)
            cp   (hl)
            jp   nc,br_1
            ret

; 1270/1280 (IRONCLAD.BAS): полоска корабля SH противника (потоплен) / своего
L1270:      xor  a
            ld   (bY0),a
            ld   a,(bSH)
            call y_i
            ld   (bYP),a
            call sz_sh
            ld   a,c
            ld   (bNH),a
            jp   L1282
L1280:      ld   a,70
            ld   (bY0),a
            ld   a,(bSH)
            call y_i
            ld   (bYP),a
            call ph_sh
            ld   a,c
            ld   (bNH),a
L1282:      call sz_sh
            ld   a,c
            jp   bars_n

; ---------------------------------------------------------------- 1300: сообщения
L1300:      ld   hl,sMS                 ; IF LEN(MS$)>31 THEN MS$=LEFT$(MS$,31)
            call str_len
            cp   32
            jp   c,L1301
            xor  a
            ld   (sMS+31),a
L1301:      ld   a,(bMY)                ; запомнить строку (для перерисовки страницы)
            call msg_slot
            ld   a,(bMC)
            ld   (hl),a
            inc  hl
            ex   de,hl
            ld   hl,sMS
            call str_copy
msg_draw_my:                            ; LINE(0,MY)-(255,MY+8),1,BF: COLOR MC: PSET(4,MY): PRINT MS$
            ld   a,(pg_vis)
            cp   2
            ret  nc
            ld   a,(bMY)
            ld   c,a
            add  a,8
            ld   e,a
            ld   b,0
            ld   d,255
            ld   a,1
            call gfx_fill
            ld   a,(bMY)
            call msg_slot
            ld   a,(hl)
            inc  hl
            ld   c,a
            ld   a,(hl)
            or   a
            jp   z,L1302
            push hl
            ld   a,c
            ld   (gfx_fg),a
            ld   a,(bMY)
            ld   c,a
            ld   b,4
            ld   a,(gfx_fg)
            call gfx_pset
            pop  hl
            call gfx_puts
L1302:      ld   a,15
            ld   (gfx_fg),a
            ret
L1305:      ld   a,192
            ld   (bMY),a
            ld   a,11
            ld   (bMC),a
            jp   L1300
L1306:      ld   a,192
            ld   (bMY),a
            jp   L1300
L1315:      ld   a,202
            ld   (bMY),a
            ld   a,15
            ld   (bMC),a
            jp   L1300
; HL = запись строки сообщений для MY=A
msg_slot:   ld   hl,msg_rec
            cp   192
            ret  z
            ld   hl,msg_rec+36
            ret

; ---------------------------------------------------------------- 1355: статика страницы
; В оригинале — на обе страницы (FOR AP): здесь экран один; записи клеток обеих страниц
; становятся пустыми (LINE(0,0)-(255,211),1,BF чистит и страницу, которой не видно).
L1355:      call rec_clear
            xor  a
            ld   (sl_n),a
            call cls1
            call hdr_draw
            call L1355s
            ret
; общая часть 1370..1385 (без заголовка)
L1355s:     ld   bc,232*256+4           ; PSET(232,4),12: PRINT "TAB"
            ld   a,12
            call gfx_pset
            ld   hl,s_tab
            call gfx_puts
L1372:      ld   a,(bSB)
            cp   1
            call z,L1396
L1375:      xor  a                      ; FOR I=0 TO 9: PSET(GX+I*16+4,18),15: PRINT CHR$(65+I)
            ld   (bI),a
L1375a:     ld   a,(bI)
            add  a,a
            add  a,a
            add  a,a
            add  a,a
            add  a,GX+4
            ld   b,a
            ld   c,18
            ld   a,15
            call gfx_pset
            ld   a,(bI)
            add  a,65
            call gfx_putc
            ld   hl,bI
            inc  (hl)
            ld   a,(hl)
            cp   10
            jp   c,L1375a
L1380:      xor  a                      ; FOR I=0 TO 9: PSET(2,GY+I*16+4),15: PRINT RIGHT$(STR$(I+1),2)
            ld   (bI),a
L1380a:     ld   a,(bI)
            add  a,a
            add  a,a
            add  a,a
            add  a,a
            add  a,GY+4
            ld   c,a
            ld   b,2
            ld   a,15
            call gfx_pset
            ld   a,(bI)
            inc  a
            cp   10
            jp   nc,L1380b
            push af
            ld   a,' '
            call gfx_putc
            pop  af
            add  a,'0'
            call gfx_putc
            jp   L1380c
L1380b:     ld   a,'1'
            call gfx_putc
            ld   a,'0'
            call gfx_putc
L1380c:     ld   hl,bI
            inc  (hl)
            ld   a,(hl)
            cp   10
            jp   c,L1380a
L1385:      ld   bc,(GX-1)*256+GY-1     ; LINE(GX-1,GY-1)-(GX+160,GY+160),12,B
            ld   de,(GX+160)*256+GY+160
            ld   a,12
            jp   gfx_box

; 1396: PSET(128,4),9: PRINT "GAME"+STR$(GN)+"/"+MID$(STR$(BO),2)+" "+MID$(STR$(GW),2)+"-"+MID$(STR$(GC),2)
; Печать поверх без стирания (как в оригинале: 2238 перепечатывает счёт поверх).
L1396:      ld   hl,sl_n
            ld   a,(hl)
            cp   2
            jp   nc,L1396a
            inc  (hl)
L1396a:     ld   hl,sl_v1
            cp   1
            jp   c,L1396b
            ld   hl,sl_v2
L1396b:     ld   a,(bGN)
            ld   (hl),a
            inc  hl
            ld   a,(bBO)
            ld   (hl),a
            inc  hl
            ld   a,(bGW)
            ld   (hl),a
            inc  hl
            ld   a,(bGC)
            ld   (hl),a
            dec  hl
            dec  hl
            dec  hl
; напечатать строку счёта по записи HL (GN,BO,GW,GC)
sl_print:   push hl
            ld   bc,128*256+4
            ld   a,9
            call gfx_pset
            ld   hl,s_game
            ld   de,sT
            call str_copy
            pop  hl
            push hl
            ld   a,(hl)
            ld   l,a
            ld   h,0
            call str_num
            ld   a,'/'
            ld   (de),a
            inc  de
            pop  hl
            inc  hl
            push hl
            ld   a,(hl)
            ld   l,a
            ld   h,0
            call str_digits
            ld   a,' '
            ld   (de),a
            inc  de
            pop  hl
            inc  hl
            push hl
            ld   a,(hl)
            ld   l,a
            ld   h,0
            call str_digits
            ld   a,'-'
            ld   (de),a
            inc  de
            pop  hl
            inc  hl
            ld   a,(hl)
            ld   l,a
            ld   h,0
            call str_digits
            ld   hl,sT
            jp   gfx_puts

; ---------------------------------------------------------------- 1410: ввод
L1410:      xor  a
            ld   (bAC),a
L1415:      ld   a,(bKQ)                ; IF KQ$<>"" THEN K$=KQ$: KQ$="": GOTO 1425
            or   a
            jp   z,L1415a
            ld   (bK_),a
            xor  a
            ld   (bKQ),a
            jp   L1425
L1415a:     call inkey                  ; K$=INKEY$: IF K$<>"" THEN 1425
            ld   (bK_),a
            jp   nz,L1425
L1416:      ld   a,(bUA)
            cp   1
            jp   nz,L1417
            xor  a
            ld   (bUA),a
            call L1473
L1417:      ei
            halt
            jp   L1415
L1425:      ld   a,(bK_)
            ld   (bKA),a
            cp   9
            jp   nz,L1430
            ld   a,(bDP)                ; TAB: DP=1-DP: SET PAGE DP,DP: GOSUB 1473
            xor  1
            ld   (bDP),a
            call page_show
            call L1473
            jp   L1415
L1430:      cp   28
            jp   nz,L1432
            ld   a,(bCX)
            cp   9
            jp   nc,L1437
            inc  a
            ld   (bCX),a
            jp   L1437
L1432:      cp   29
            jp   nz,L1434
            ld   a,(bCX)
            or   a
            jp   z,L1437
            dec  a
            ld   (bCX),a
            jp   L1437
L1434:      cp   30
            jp   nz,L1436
            ld   a,(bCY)
            or   a
            jp   z,L1437
            dec  a
            ld   (bCY),a
            jp   L1437
L1436:      cp   31
            jp   nz,L1437
            ld   a,(bCY)
            cp   9
            jp   nc,L1437
            inc  a
            ld   (bCY),a
L1437:      ld   a,(bKA)
            cp   28
            jp   c,L1441
            cp   32
            jp   nc,L1441
L1438:      call inkey                  ; K2$=INKEY$: IF K2$=K$ THEN 1430 ELSE KQ$=K2$
            ld   (bK2),a
            ld   b,a
            ld   a,(bK_)
            cp   b
            jp   z,L1430
            ld   a,b
            ld   (bKQ),a
L1439:      ld   a,1
            ld   (bUA),a
L1440:      xor  a
            ld   (bAC),a
            ret
L1441:      ld   a,(bK_)
            cp   ' '
            jp   z,L1441a
            cp   13
            jp   nz,L1444
L1441a:     ld   a,1
            ld   (bAC),a
            ret
L1444:      call upcase
            cp   'R'
            ld   b,2
            jp   z,L1449a
            cp   'X'
            ld   b,7
            jp   z,L1449a
            cp   'Q'
            ld   b,3
            jp   z,L1449a
            cp   'Z'
            ld   b,4
            jp   z,L1449a
            cp   'U'
            ld   b,5
            jp   z,L1449a
L1451:      cp   '?'
            jp   nz,L1415
            call L3900
            xor  a
            ld   (bAC),a
            ret
L1449a:     ld   a,b
            ld   (bAC),a
            ret
upcase:     cp   'a'
            ret  c
            cp   'z'+1
            ret  nc
            sub  32
            ret

; ---------------------------------------------------------------- 1473: поле AT:
L1473:      ld   a,(bCX)                ; CO$=CHR$(65+CX)+MID$(STR$(CY+1),2)
            ld   b,a
            ld   a,(bCY)
            ld   c,a
            ld   de,sCO
            call mk_coord
            ld   a,(bDP)                ; запись AT: страницы DP
            add  a,a
            add  a,a
            add  a,a
            ld   hl,at_rec
            call add_a_hl
            ld   (hl),0
L1475:      ld   a,(bFB)                ; IF (FB=0 AND DP<>1) OR (FB=1 AND DP<>0) THEN пусто
            ld   b,a
            ld   a,(bDP)
            cp   b
            jp   z,L1478                ; FB=DP -> поле пустое, иначе «AT:»+CO$
L1476:      ld   de,s_at                ; «AT:»+CO$
            ex   de,hl
            call str_copy
            ld   hl,sCO
            call str_copy
L1478:      call at_draw
            xor  a
            ld   (bAC),a
            ret

; ---------------------------------------------------------------- 1615: влезает ли корабль
L1615:      call sz_sh                  ; S=SZ(SH): AX=CX: AY=CY
            ld   a,c
            ld   (bS),a
            ld   a,(bCX)
            ld   (bAX),a
            ld   a,(bCY)
            ld   (bAY),a
L1618:      ld   a,(bOD)
            or   a
            jp   nz,L1620
            ld   a,(bS)                 ; IF AX+S-1>9 THEN AX=10-S
            ld   b,a
            ld   a,(bAX)
            add  a,b
            dec  a
            cp   10
            jp   c,L1622
            ld   a,10
            sub  b
            ld   (bAX),a
            jp   L1622
L1620:      ld   a,(bS)
            ld   b,a
            ld   a,(bAY)
            add  a,b
            dec  a
            cp   10
            jp   c,L1622
            ld   a,10
            sub  b
            ld   (bAY),a
L1622:      ld   a,1
            ld   (bLG),a
            ld   a,(bAY)                ; BZ(AX+I,AY) либо BZ(AX,AY+I)
            ld   e,a
            ld   a,(bAX)
            ld   bc,ARR_BZ
            call w10
            ld   de,2                   ; шаг по X
            ld   a,(bOD)
            or   a
            jp   z,L1624
            ld   de,20                  ; шаг по Y
L1624:      ld   a,(bS)
            ld   b,a
            xor  a
            ld   (bI),a
L1624a:     ld   a,(hl)
            cp   1
            jp   nz,L1625
            inc  hl
            ld   a,(hl)
            dec  hl
            or   a
            jp   nz,L1625
            xor  a
            ld   (bLG),a
L1625:      add  hl,de
            push hl
            ld   hl,bI
            inc  (hl)
            pop  hl
            dec  b
            jp   nz,L1624a
            ret

; ---------------------------------------------------------------- 1652: клетки и тайлы корабля
L1652:      xor  a
            ld   (bI),a
L1652a:     ld   a,(bI)                 ; IF OD=0 THEN TX=AX+I: TY=AY ELSE TX=AX: TY=AY+I
            ld   c,a
            ld   a,(bAX)
            ld   b,a
            ld   a,(bAY)
            ld   d,a
            ld   a,(bOD)
            or   a
            jp   nz,L1652b
            ld   a,b
            add  a,c
            ld   b,a
            jp   L1652c
L1652b:     ld   a,d
            add  a,c
            ld   d,a
L1652c:     ld   a,c
            add  a,a
            ld   hl,ARR_TX
            call add_a_hl
            ld   (hl),b
            inc  hl
            ld   (hl),0
            ld   a,c
            add  a,a
            ld   hl,ARR_TY
            call add_a_hl
            ld   (hl),d
            inc  hl
            ld   (hl),0
            ld   a,c
            inc  a
            ld   (bI),a
            ld   hl,bS
            cp   (hl)
            jp   c,L1652a
L1656:      xor  a
            ld   (bI),a
L1656a:     ld   a,(bOD)                ; GT(I)=4+OD*3: IF S=5 THEN GT(I)=14+OD
            ld   b,a
            add  a,a
            add  a,b
            add  a,4
            ld   c,a
            ld   a,(bS)
            cp   5
            jp   nz,L1657
            ld   a,b
            add  a,14
            ld   c,a
L1657:      ld   a,(bI)                 ; IF I=1 AND S>2 THEN GT(I)=12+OD
            cp   1
            jp   nz,L1658
            ld   a,(bS)
            cp   3
            jp   c,L1658
            ld   a,b
            add  a,12
            ld   c,a
L1658:      ld   a,(bI)                 ; IF I=0 THEN 5+OD*3 ELSE IF I=S-1 AND S<>5 THEN 6+OD*3
            or   a
            jp   nz,L1658a
            ld   a,b
            add  a,a
            add  a,b
            add  a,5
            ld   c,a
            jp   L1659
L1658a:     ld   a,(bS)
            dec  a
            ld   d,a
            ld   a,(bI)
            cp   d
            jp   nz,L1659
            ld   a,(bS)
            cp   5
            jp   z,L1659
            ld   a,b
            add  a,a
            add  a,b
            add  a,6
            ld   c,a
L1659:      ld   a,(bS)                 ; IF S=1 THEN 22 ELSE IF SH=4 AND S=3 THEN 16+OD+2*I
            cp   1
            jp   nz,L1659a
            ld   c,22
            jp   L1660
L1659a:     ld   a,(bSH)
            cp   4
            jp   nz,L1660
            ld   a,(bS)
            cp   3
            jp   nz,L1660
            ld   a,(bI)
            add  a,a
            add  a,b
            add  a,16
            ld   c,a
L1660:      ld   a,(bI)
            ld   hl,ARR_GT
            call add_a_hl
            ld   (hl),c
            ld   a,(bI)
            inc  a
            ld   (bI),a
            ld   hl,bS
            cp   (hl)
            jp   c,L1656a
            ld   a,(bS)
            ld   (bTN),a
            ret

; ---------------------------------------------------------------- 1662: призрак корабля
L1662:      ld   a,(bRW)                ; IF RW>0 THEN восстановить из «страницы 2»
            or   a
            call nz,gh_erase
L1664:      ld   a,(bAX)                ; RX=GX+AX*16: RY=GY+AY*16
            ld   b,a
            ld   a,(bAY)
            ld   c,a
            call cell_xy
            ld   a,b
            ld   (bRX),a
            ld   a,c
            ld   (bRY),a
            ld   a,(bS)                 ; RW=S*16: RH=16: SY=32: SX=0: IF OD=1 THEN RW=16: RH=S*16: SY=48
            add  a,a
            add  a,a
            add  a,a
            add  a,a
            ld   b,a
            ld   (bRW),a
            ld   a,16
            ld   (bRH),a
            ld   a,32
            ld   (bSY),a
            xor  a
            ld   (bSX),a
            ld   a,(bOD)
            cp   1
            jp   nz,L1666
            ld   a,16
            ld   (bRW),a
            ld   a,b
            ld   (bRH),a
            ld   a,48
            ld   (bSY),a
L1666:      ld   a,(bLG)                ; IF LG=0 THEN IF OD=1 THEN SX=16 ELSE SY=128
            or   a
            jp   nz,L1668
            ld   a,(bOD)
            cp   1
            jp   nz,L1666a
            ld   a,16
            ld   (bSX),a
            jp   L1668
L1666a:     ld   a,128
            ld   (bSY),a
L1668:      ld   a,(bRX)                ; COPY композита -> страница 1
            ld   (gh_rx),a
            ld   a,(bRY)
            ld   (gh_ry),a
            ld   a,(bRW)
            ld   (gh_rw),a
            ld   a,(bRH)
            ld   (gh_rh),a
            ld   a,(bSX)
            ld   (gh_sx),a
            ld   a,(bSY)
            ld   (gh_sy),a
            ld   a,1
            ld   (gh_on),a
            jp   gh_draw
; RW=0: призрак затёрт (не восстанавливать)
gh_forget:  xor  a
            ld   (gh_on),a
            ret

; 3204: собрать композит корабля (тайлы вода + GT(I)) — хранится как gh_od/gh_s/gh_gt
L3204:      ld   a,(bOD)
            ld   (gh_od),a
            ld   a,(bS)
            ld   (gh_s),a
            ld   hl,ARR_GT
            ld   de,gh_gt
            ld   b,5
L3204a:     ld   a,(hl)
            ld   (de),a
            inc  hl
            inc  de
            dec  b
            jp   nz,L3204a
            ret

; ---------------------------------------------------------------- 1683: запретная зона вокруг корабля
L1683:      ld   a,1                    ; E=1: IF TU=1 THEN E=0
            ld   (bE),a
            ld   a,(bTU)
            cp   1
            jp   nz,L1684
            xor  a
            ld   (bE),a
L1684:      ld   a,(bE)                 ; U1=TX(0)-E: V1=TY(0)-E: U2=TX(TN-1)+E: V2=TY(TN-1)+E
            ld   c,a
            ld   a,(ARR_TX)
            sub  c
            ld   (bU1),a
            ld   a,(ARR_TY)
            sub  c
            ld   (bV1),a
            ld   a,(bTN)
            dec  a
            add  a,a
            ld   hl,ARR_TX
            call add_a_hl
            ld   a,(hl)
            add  a,c
            ld   (bU2),a
            ld   a,(bTN)
            dec  a
            add  a,a
            ld   hl,ARR_TY
            call add_a_hl
            ld   a,(hl)
            add  a,c
            ld   (bV2),a
            call clamp_uv
L1689:      ld   a,(bU1)                ; FOR U=U1 TO U2: FOR V=V1 TO V2: BZ(U,V)=1
            ld   (bU),a
L1689a:     ld   a,(bV1)
            ld   (bV),a
L1689b:     ld   a,(bV)
            ld   e,a
            ld   a,(bU)
            ld   bc,ARR_BZ
            call w10
            ld   (hl),1
            inc  hl
            ld   (hl),0
            ld   hl,bV
            inc  (hl)
            ld   a,(bV2)
            cp   (hl)
            jp   p,L1689b
            ld   hl,bU
            inc  (hl)
            ld   a,(bU2)
            cp   (hl)
            jp   p,L1689a
            ret
; 1685..1688: U1,V1 >= 0; U2,V2 <= 9
clamp_uv:   ld   a,(bU1)
            or   a
            jp   p,cu_1
            xor  a
            ld   (bU1),a
cu_1:       ld   a,(bV1)
            or   a
            jp   p,cu_2
            xor  a
            ld   (bV1),a
cu_2:       ld   a,(bU2)
            cp   10
            jp   c,cu_3
            ld   a,9
            ld   (bU2),a
cu_3:       ld   a,(bV2)
            cp   10
            ret  c
            ld   a,9
            ld   (bV2),a
            ret

; 1694: BZ()=0
L1694:      ld   hl,ARR_BZ
            ld   b,200
L1694a:     ld   (hl),0
            inc  hl
            dec  b
            jp   nz,L1694a
            ret

; ---------------------------------------------------------------- 1706/1755: корабль потоплен
L1706:      ld   a,1
            ld   (bSD),a
            jp   L1756
L1755:      xor  a
            ld   (bSD),a
L1756:      ld   a,1                    ; E=1: IF AM=0 OR BD=1 THEN E=0
            ld   (bE),a
            ld   a,(bAM)
            or   a
            jp   z,L1756a
            ld   a,(bBD)
            cp   1
            jp   nz,L1757
L1756a:     xor  a
            ld   (bE),a
L1757:      xor  a                      ; FOR I=0 TO SZ(SH)-1
            ld   (bI),a
L1757a:     call pxy_off
            ld   a,(bSD)
            cp   1
            jp   nz,L1757b
            ld   de,ARR_QX              ; CM(QX(SH,I),QY(SH,I))=3
            add  hl,de
            ld   b,(hl)
            ld   de,ARR_QY-ARR_QX
            add  hl,de
            ld   e,(hl)
            ld   a,b
            ld   bc,ARR_CM
            call w10
            ld   (hl),3
            inc  hl
            ld   (hl),0
            jp   L1758
L1757b:     ld   de,ARR_PX              ; PM(PX,PY)=PM-(PM AND 3)+3
            add  hl,de
            ld   b,(hl)
            ld   de,ARR_PY-ARR_PX
            add  hl,de
            ld   e,(hl)
            ld   a,b
            ld   bc,ARR_PM
            call w10
            ld   a,(hl)
            or   3
            ld   (hl),a
L1758:      ld   hl,bI
            inc  (hl)
            call sz_sh
            ld   a,(bI)
            cp   c
            jp   c,L1757a
            call sz_sh                  ; концы корабля: элемент 0 и SZ-1
            dec  c
            ld   a,c
            ld   (rp_tmp+1),a
            ld   hl,ARR_QX
            ld   a,(bSD)
            cp   1
            jp   z,L1758a
            ld   hl,ARR_PX
L1758a:     ld   (rp_tmp+2),hl          ; база X (Y = база + 60)
            ld   a,(bE)
            ld   c,a
            ld   a,(bSH)                ; U1=X(SH,0)-E: V1=Y(SH,0)-E
            call l1758_xy
            ld   a,b
            sub  c
            ld   (bU1),a
            ld   a,d
            sub  c
            ld   (bV1),a
            ld   a,(rp_tmp+1)           ; U2=X(SH,SZ-1)+E: V2=Y(SH,SZ-1)+E
            add  a,a
            add  a,a
            ld   b,a
            add  a,a
            add  a,b
            ld   b,a
            ld   a,(bSH)
            add  a,b
            call l1758_xy
            ld   a,b
            add  a,c
            ld   (bU2),a
            ld   a,d
            add  a,c
            ld   (bV2),a
            call clamp_uv
L1765:      ld   a,(bU1)
            ld   (bU),a
L1765a:     ld   a,(bV1)
            ld   (bV),a
L1765b:     ld   a,(bV)
            ld   e,a
            ld   a,(bU)
            ld   bc,ARR_CM
            ld   d,a
            ld   a,(bSD)
            cp   1
            ld   a,d
            jp   z,L1765c
            ld   bc,ARR_PM              ; 1766: IF SD=0 THEN IF PM(U,V)=0 THEN PM(U,V)=1
L1765c:     call w10                    ; 1765: IF SD=1 THEN IF CM(U,V)=0 THEN CM(U,V)=1
            ld   a,(hl)
            inc  hl
            or   (hl)
            jp   nz,L1770
            ld   (hl),0
            dec  hl
            ld   (hl),1
L1770:      ld   a,(bU)
            ld   (bC),a
            ld   a,(bV)
            ld   (bR),a
            call L1105
L1775:      ld   hl,bV
            inc  (hl)
            ld   a,(bV2)
            cp   (hl)
            jp   p,L1765b
            ld   hl,bU
            inc  (hl)
            ld   a,(bU2)
            cp   (hl)
            jp   p,L1765a
            ret
; A = SH + I*12 -> B = X(база), D = Y(база+60)
l1758_xy:   ld   hl,(rp_tmp+2)
            call add_a_hl
            ld   b,(hl)
            ld   de,60
            add  hl,de
            ld   d,(hl)
            ret

; 1795 (сборки BD): потопленный свой корабль — PM -> 3 и перерисовать
L1795:      xor  a
            ld   (bI),a
L1795a:     call pxy_off
            ld   de,ARR_PX
            add  hl,de
            ld   a,(hl)
            ld   (bC),a
            ld   de,ARR_PY-ARR_PX
            add  hl,de
            ld   a,(hl)
            ld   (bR),a
            ld   bc,ARR_PM
            call w10cr
            ld   a,(hl)
            or   3
            ld   (hl),a
            call L1105
            ld   hl,bI
            inc  (hl)
            call sz_sh
            ld   a,(bI)
            cp   c
            jp   c,L1795a
            ret

s_enemy:    db "ENEMY",0
s_yours:    db "YOURS",0
s_tab:      db "TAB",0
s_game:     db "GAME",0
s_at:       db "AT:",0
