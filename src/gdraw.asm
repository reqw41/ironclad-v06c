; ============================================================================
; gdraw.asm — перевод IRONCLAD.BAS: строки 1105..1795 (клетки, панель, сообщения,
; ввод, расстановка) и 3950.
; ============================================================================

DLY_120     equ 5           ; FOR I=1 TO 120: NEXT I — ~0.1 с MSX-BASIC
DLY_400     equ 15          ; FOR I=1 TO 400 — ~0.3 с
DLY_1500    equ 56          ; FOR I=1 TO 1500 — ~1.1 с

; A = страница, D = код: клетка (bC, bR)
cr_op:      ld   hl,cell_op
            jp   cr_x
cr_tp0:     xor  a                      ; страница 0
cr_tp:      ld   hl,cell_tp
cr_x:       push af
            LDV  bC
            ld   b,a
            LDV  bR
            ld   c,a
            pop  af
            jp   (hl)
; HL = &массив(C,R): BC = база
w10cr:      LDV  bR
            ld   e,a
            LDV  bC
            jp   w10

; ---------------------------------------------------------------- 1105: клетка (C,R)
L1105:      ld   hl,bC                  ; DX, DY = пиксели клетки (C,R)
            ld   de,bDX
            call cxy_pair
L1110:      CPV  bSD,1
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
            LDV  bQ
            call sh4a
            ld   d,a
            ld   a,1
            jp   cr_tp
L1121:      ld   d,a                    ; 1 промах — непрозрачно; 2 попадание, 3 потоплен — TPSET
            cp   1
            ld   a,1
            jp   nz,L1121a
            call cr_op
            jp   L1124
L1121a:     call cr_tp
L1124:      CPV  bBD,1  ; IF BD=1 THEN NV=PM(C,R)\4: IF 0<NV<33 -> белая цифра NV
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
            STV  bNV
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
L1132:      call m_cm                   ; M=CM(C,R) (1132 и 1146 одинаково): 0 — RETURN, <0 — 3950
            ld   a,h
            or   l
            ret  z
            ld   a,h
            or   a
            jp   m,L3950
L1131:      CPV  bBD,1
            jp   z,L1147
L1133:      ld   a,l
            cp   3
            jp   nz,L1136
            call q_cs                   ; Q=CS(C,R)\16: IF Q>0 -> тайл корабля
            or   a
            jp   z,L1136
            and  31
            ld   d,a
            xor  a
            call cr_tp
L1136:      CPV  bM,1                   ; M=1 — промах (непрозрачно), 2/3 — тайл M (TPSET)
            ld   d,a
            ld   a,0
            jp   z,cr_op
            jp   cr_tp
L1147:      ld   a,l                    ; M <= 128
            cp   65
            jp   c,L1148
            dec  a                      ; M=((M-1) AND 31)+1 -> красная цифра M
            and  31
            ld   d,a
            inc  a
            STV  bM
            ld   a,d
            add  a,96
            ld   d,a
            jp   cr_tp0
L1148:      cp   33
            jp   c,L1149
            add  a,64-33                ; жёлтая цифра M-33
            ld   d,a
            jp   cr_tp0
L1149:      add  a,32-1                 ; белая цифра M-1
            ld   d,a
            jp   cr_tp0

; 3950: IF M=-3 THEN буй (176,TR) ELSE (160,TR), TPSET, стр. 0
L3950:      CPV  bM,-3
            ld   d,11
            jp   z,L3950a
            ld   d,10
L3950a:     jp   cr_tp0

; HL = M = CM(C,R)
m_cm:       ld   bc,ARR_CM
            call w10cr
            call ld_hl_de
            ex   de,hl
            ld   (bM),hl
            ret
; Q = CS(C,R)\16 -> A
q_cs:       ld   bc,ARR_CS
            call w10cr
            call ld_hl_de
            call shr4_de
            ld   a,e
            STV  bQ
            ret
; I=I+1: CY, если I < SZ(SH)
next_i_sz:  INCV bI
            call sz_sh
            LDV  bI
            cp   c
            ret
; B = QH(I), C = SZ(I)
i_qh_sz:    LDV  bI
            ld   hl,ARR_QH
            rst  00h
            ld   b,(hl)
            jp   sz_i
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
L1152:      LDV  bSD                ; PG=0: IF SD=0 THEN PG=1
            xor  1
            STV  bPG
L1154:      call cells_water
L1156:      CPV  bSD,1
            ret  z
            LDV  bNP
            or   a
            ret  z
L1158:      SETV bN,1
L1158a:     ZEROV bI
L1160:      LDV  bI                 ; C=PX(N,I): R=PY(N,I)
            call x12
            ld   b,a
            LDV  bN
            add  a,b
            call pxy_a
            STV  bC
            ld   a,e
            STV  bR
            call L1105
L1162:      LDV  bN
            call sz_a
            ld   b,c
            INCV bI
            ld   a,(hl)
            cp   b
            jp   c,L1160
            INCV bN
            LDV  bNP
            cp   (hl)
            jp   nc,L1158a
L1164:      ret

; ---------------------------------------------------------------- 1206: панель флотов
L1206:      ld   bc,190*256+16          ; LINE(190,16)-(255,160),1,BF
            ld   de,255*256+160
            ld   a,1
            call gfx_fill
            ZEROV bP
L1208:      LDV  bP                 ; Y0=70*P (P=0/1): CL=8+P
            rrca
            sbc  a,a
            and  70
L1208a:     STV  bY0
            LDV  bP
            add  a,8
            STV  bCL
            LDV  bY0                ; LINE(190,20+Y0)-(255,20+Y0),CL
            add  a,20
            ld   c,a
            ld   e,a
            LDV  bCL
            call pfill
            LDV  bY0                ; LINE(190,33+Y0)-(255,33+Y0),CL
            add  a,33
            ld   c,a
            ld   e,a
            LDV  bCL
            call pfill
L1212:      LDV  bCL                ; COLOR CL: PSET(192,23+Y0): PRINT "ENEMY"/"YOURS"
            ld   (gfx_fg),a
            LDV  bY0
            add  a,23
            ld   c,a
            ld   b,192
            LDV  bCL
            call gfx_pset
            ld   hl,s_enemy
            LDV  bP
            or   a
            jp   z,L1212a
            ld   hl,s_yours
L1212a:     call gfx_puts
L1215:      call fg15
            CPV  bBD,1
            jp   z,L1231
L1216:      SETV bI,1  ; FOR I=1 TO NK
L1216a:     LDV  bI
            call y_i                    ; y = 37+Y0+(I-1)*PZ
            ld   c,a
            ld   b,192
            ld   a,15
            call gfx_pset
            LDV  bI
            call pn3
L1220:      call i_ph_sz                ; NH=PH(I): IF P=0 THEN NH=0: IF QH(I)>=SZ(I) THEN NH=5
            ld   a,b
            STV  bNH
            LDV  bP
            or   a
            jp   nz,L1225
            ZEROV bNH
            call i_qh_sz
            ld   a,b
            cp   c
            jp   c,L1225
            SETV bNH,5
L1225:      LDV  bI
            call y_i
            STV  bYP
            call bars                   ; FOR J=1 TO SZ(I): квадратики
            INCV bI
            LDV  bNK
            cp   (hl)
            jp   nc,L1216a
L1231:      INCV bP
            ld   a,(hl)
            cp   2
            jp   c,L1208
L1255:      ret

; (DE), (DE+1) = x, y клетки ((HL), (HL+1)) — пары соседних переменных
cxy_pair:   ld   b,(hl)
            inc  hl
            ld   c,(hl)
            call cell_xy
            ex   de,hl
            ld   (hl),b
            inc  hl
            ld   (hl),c
            ret
; LINE(190,C)-(255,E),A,BF — полоса панели флотов
pfill:      ld   b,190
            ld   d,255
            jp   gfx_fill
; PRINT LEFT$(N$(A),3)
pn3:        call n_a
            ld   de,sT
            call cat3
            ld   hl,sT
            jp   gfx_puts
; A = 37+Y0+(A-1)*PZ
y_i:        ld   d,a
            LDV  bPZ
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
yi_2:       LDV  bY0
            add  a,37
            add  a,c
            ret
; C = SZ(I)
sz_i:       LDV  bI
sz_a:       ld   hl,ARR_SZ
            add  a,a
            rst  00h
            ld   c,(hl)
            ret

; 1225/1284: FOR J=1 TO SZ(корабль): CL=9: IF J<=NH THEN CL=8:
;            LINE(216+(J-1)*8,YP)-(220+(J-1)*8,YP+6),CL,BF   (размер: bars_n)
bars:       call sz_i
            ld   a,c
bars_n:     STV  br_n
            SETV hr_x0,216
            SETV hr_j,1
br_1:       call hr_xj                  ; A = J-1
            ld   b,a
            LDV  bNH
            cp   b
            ld   a,9
            jp   z,br_2
            jp   c,br_2
            ld   a,8                    ; J<=NH
br_2:       STV  bCL
            call sq_draw
            INCV hr_j
            LDV  br_n
            cp   (hl)
            jp   nc,br_1
            ret

; 1270/1280 (IRONCLAD.BAS): полоска корабля SH противника (потоплен) / своего
L1270:      ZEROV bY0
            LDV  bSH
            call y_i
            STV  bYP
            call sz_sh
            ld   a,c
            STV  bNH
            jp   L1282
L1280:      SETV bY0,70
            LDV  bSH
            call y_i
            STV  bYP
            call ph_sh
            ld   a,c
            STV  bNH
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
L1301:      LDV  bMY                ; запомнить строку (для перерисовки страницы)
            call msg_slot
            LDV  bMC
            ld   (hl),a
            inc  hl
            ex   de,hl
            ld   hl,sMS
            call str_copy
msg_draw_my:                            ; LINE(0,MY)-(255,MY+8),1,BF: COLOR MC: PSET(4,MY): PRINT MS$
            CPV  pg_vis,2
            ret  nc
            LDV  bMY
            ld   c,a
            add  a,8
            ld   e,a
            ld   b,0
            ld   d,255
            ld   a,1
            call gfx_fill
            LDV  bMY
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
            ld   e,a
            LDV  bMY
            ld   c,a
            ld   b,4
            ld   a,e
            call gfx_pset
            pop  hl
            call gfx_puts
L1302:      jp   fg15
L1305:      SETV bMY,192
            SETV bMC,11
            jp   L1300
L1306:      SETV bMY,192
            jp   L1300
L1315:      call ai_wait                ; порт: прежнее сообщение ИИ в этой строке — не меньше 60 кадров
            SETV bMY,202
            SETV bMC,15
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
            ZEROV sl_n
            call cls1
            call hdr_draw
            call L1355s
L1372:      CPV  bSB,1                  ; (после подписей сетки — места не пересекаются)
            ret  nz
            jp   L1396
; общая часть 1370..1385 (без заголовка и без строки счёта 1396)
L1355s:     ld   bc,232*256+4           ; PSET(232,4),12: PRINT "TAB"
            ld   a,12
            call gfx_pset
            call putsi
            TXT  "ТАБ"
L1375:      ZEROV bI  ; FOR I=0 TO 9: PSET(GX+I*16+4,18),15: PRINT CHR$(65+I)
L1375a:     LDV  bI                 ; 1380 (тем же циклом): PSET(2,GY+I*16+4),15: PRINT RIGHT$(STR$(I+1),2)
            add  a,a
            add  a,a
            add  a,a
            add  a,a
            push af
            add  a,GX+4
            ld   b,a
            ld   c,18
            ld   a,15
            call gfx_pset
            LDV  bI
            add  a,65
            call gfx_putc
            pop  af
            add  a,GY+4
            ld   c,a
            ld   b,2
            ld   a,15
            call gfx_pset
            LDV  bI
            inc  a
            ld   b,' '
            cp   10
            jp   c,L1380b
            ld   b,'1'
            sub  10
L1380b:     push af
            ld   a,b
            call gfx_putc
            pop  af
            add  a,'0'
            call gfx_putc
L1380c:     INCV bI
            ld   a,(hl)
            cp   10
            jp   c,L1375a
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
L1396b:     LDV  bGN
            ld   (hl),a
            inc  hl
            LDV  bBO
            ld   (hl),a
            inc  hl
            LDV  bGW
            ld   (hl),a
            inc  hl
            LDV  bGC
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
            ld   l,(hl)
            ld   h,0
            call str_num
            pop  hl
            ld   bc,sl_sep
slp_1:      ld   a,(bc)                 ; "/", " ", "-" + MID$(STR$(поле),2)
            ld   (de),a
            inc  de
            inc  bc
            inc  hl
            push hl
            push bc
            ld   l,(hl)
            ld   h,0
            call str_digits
            pop  bc
            pop  hl
            ld   a,c
            cp   low (sl_sep+3)
            jp   nz,slp_1
            ld   hl,sT
            jp   gfx_puts
sl_sep:     db   "/ -"

; ---------------------------------------------------------------- 1410: ввод
L1410:      ZEROV bAC
L1415:      LDV  bKQ                ; IF KQ$<>"" THEN K$=KQ$: KQ$="": GOTO 1425
            or   a
            jp   z,L1415a
            STV  bK_
            ZEROV bKQ
            jp   L1425
L1415a:     call inkey                  ; K$=INKEY$: IF K$<>"" THEN 1425
            STV  bK_
            jp   nz,L1425
L1416:      CPV  bUA,1
            jp   nz,L1417
            ZEROV bUA
            call L1473
L1417:      ei
            halt
            jp   L1415
L1425:      LDV  bK_
            STV  bKA
            cp   9
            jp   nz,L1430
            LDV  bDP                ; TAB: DP=1-DP: SET PAGE DP,DP: GOSUB 1473
            xor  1
            STV  bDP
            call page_show
            call L1473
            jp   L1415
L1430:      cp   28                     ; 28 ->: CX<9 — CX+1; 29 <-: CX>0 — CX-1;
            jp   c,L1437                ; 30 ^: CY>0 — CY-1; 31 v: CY<9 — CY+1
            cp   32
            jp   nc,L1437
            ld   hl,bCX
            sub  28                     ; 0 CX+, 1 CX-, 2 CY-, 3 CY+
            cp   2
            jp   c,L1432
            inc  hl                     ; bCY
            xor  3                      ; 2 -> 1 (назад), 3 -> 0 (вперёд)
L1432:      or   a
            jp   nz,L1435
            ld   a,(hl)                 ; вперёд
            cp   9
            jp   nc,L1437
            inc  (hl)
            jp   L1437
L1435:      ld   a,(hl)                 ; назад
            or   a
            jp   z,L1437
            dec  (hl)
L1437:      CPV  bKA,28
            jp   c,L1441
            cp   32
            jp   nc,L1441
L1438:      call inkey                  ; K2$=INKEY$: IF K2$=K$ THEN 1430 ELSE KQ$=K2$
            STV  bK2
            ld   b,a
            LDV  bK_
            cp   b
            jp   z,L1430
            ld   a,b
            STV  bKQ
L1439:      SETV bUA,1
L1440:      ZEROV bAC
            ret
L1441:      LDV  bK_
            cp   ' '
            jp   z,L1441a
            cp   13
            jp   nz,L1444
L1441a:     SETV bAC,1
            ret
L1444:      ld   hl,t1444-1             ; R -> AC=2, B -> 7, M -> 3, A -> 4, U -> 5 (UCASE не нужен:
                                        ; kbd_code строчных не даёт, коды <= 5Fh)
L1444a:     inc  hl
            ld   b,(hl)
            inc  b
            dec  b
            jp   z,L1451
            inc  hl
            cp   b
            jp   nz,L1444a
            ld   a,(hl)
            STV  bAC
            ret
L1451:      cp   '?'
            jp   nz,L1415
            call L3900
            ZEROV bAC
            ret
t1444:      db   'R',2,'B',7,'M',3,'A',4,'U',5,0   ; клавиши Р, Б, М, А, У (коды латинские)

; ---------------------------------------------------------------- 1473: поле AT:
L1473:      LDV  bCX                ; CO$=CHR$(65+CX)+MID$(STR$(CY+1),2)
            ld   b,a
            LDV  bCY
            ld   c,a
            ld   de,sCO
            call mk_coord
            LDV  bDP                ; запись AT: страницы DP
            call at_ptr_a
            ld   (hl),0
L1475:      LDV  bFB                ; IF (FB=0 AND DP<>1) OR (FB=1 AND DP<>0) THEN пусто
            ld   b,a
            LDV  bDP
            cp   b
            jp   z,L1478                ; FB=DP -> поле пустое, иначе «AT:»+CO$
L1476:      ld   de,s_at                ; «AT:»+CO$
            ex   de,hl
            call str_copy
            ld   hl,sCO
            call str_copy
L1478:      call at_draw
            ZEROV bAC
            ret

; ---------------------------------------------------------------- 1615: влезает ли корабль
L1615:      call sz_sh                  ; S=SZ(SH): AX=CX: AY=CY
            ld   a,c
            STV  bS
            LDV  bCX
            STV  bAX
            LDV  bCY
            STV  bAY
L1618:      ld   hl,bAX                 ; IF AX+S-1>9 THEN AX=10-S (OD=1 — то же с AY)
            LDV  bOD
            or   a
            jp   z,L1620
            inc  hl                     ; bAY
L1620:      LDV  bS
            ld   b,a
            ld   a,(hl)
            add  a,b
            dec  a
            cp   10
            jp   c,L1622
            ld   a,10
            sub  b
            ld   (hl),a
L1622:      SETV bLG,1
            LDV  bAY                ; BZ(AX+I,AY) либо BZ(AX,AY+I)
            ld   e,a
            LDV  bAX
            ld   bc,ARR_BZ
            call w10
            ld   de,2                   ; шаг по X
            LDV  bOD
            or   a
            jp   z,L1624
            ld   de,20                  ; шаг по Y
L1624:      LDV  bS
            ld   b,a
            ZEROV bI
L1624a:     ld   a,(hl)
            cp   1
            jp   nz,L1625
            inc  hl
            ld   a,(hl)
            dec  hl
            or   a
            jp   nz,L1625
            ZEROV bLG
L1625:      add  hl,de
            push hl
            INCV bI
            pop  hl
            dec  b
            jp   nz,L1624a
            ret

; ---------------------------------------------------------------- 1652: клетки и тайлы корабля
L1652:      ZEROV bI
L1652a:     LDV  bI                 ; IF OD=0 THEN TX=AX+I: TY=AY ELSE TX=AX: TY=AY+I
            ld   c,a
            LDV  bAX
            ld   b,a
            LDV  bAY
            ld   d,a
            LDV  bOD
            or   a
            jp   nz,L1652b
            ld   a,b
            add  a,c
            ld   b,a
            jp   L1652c
L1652b:     ld   a,d
            add  a,c
            ld   d,a
L1652c:     ld   e,d
            ld   a,c
            call txy_set
            ld   a,c
            inc  a
            STV  bI
            ld   hl,bS
            cp   (hl)
            jp   c,L1652a
L1656:      ZEROV bI
L1656a:     LDV  bOD                ; GT(I)=4+OD*3: IF S=5 THEN GT(I)=14+OD
            ld   b,a
            add  a,a
            add  a,b
            ld   e,a                    ; E = 3*OD
            add  a,4
            ld   c,a
            CPV  bS,5
            jp   nz,L1657
            ld   a,b
            add  a,14
            ld   c,a
L1657:      CPV  bI,1  ; IF I=1 AND S>2 THEN GT(I)=12+OD
            jp   nz,L1658
            CPV  bS,3
            jp   c,L1658
            ld   a,b
            add  a,12
            ld   c,a
L1658:      LDV  bI                 ; IF I=0 THEN 5+OD*3 ELSE IF I=S-1 AND S<>5 THEN 6+OD*3
            or   a
            jp   nz,L1658a
            ld   a,e
            add  a,5
            ld   c,a
            jp   L1659
L1658a:     LDV  bS
            dec  a
            ld   d,a
            LDV  bI
            cp   d
            jp   nz,L1659
            CPV  bS,5
            jp   z,L1659
            ld   a,e
            add  a,6
            ld   c,a
L1659:      CPV  bS,1  ; IF S=1 THEN 22 ELSE IF SH=4 AND S=3 THEN 16+OD+2*I
            jp   nz,L1659a
            ld   c,22
            jp   L1660
L1659a:     CPV  bSH,4
            jp   nz,L1660
            CPV  bS,3
            jp   nz,L1660
            LDV  bI
            add  a,a
            add  a,b
            add  a,16
            ld   c,a
L1660:      LDV  bI
            ld   hl,ARR_GT
            rst  00h
            ld   (hl),c
            INCV bI                     ; NEXT I: пока I < S
            LDV  bS
            cp   (hl)
            jp   z,L1660a
            jp   nc,L1656a
L1660a:
            LDV  bS
            STV  bTN
            ret

; ---------------------------------------------------------------- 1662: призрак корабля
L1662:      LDV  bRW                ; IF RW>0 THEN восстановить из «страницы 2»
            or   a
            call nz,gh_erase
L1664:      ld   hl,bAX                 ; RX=GX+AX*16: RY=GY+AY*16
            ld   de,bRX
            call cxy_pair
            LDV  bS                 ; RW=S*16: RH=16: SY=32: SX=0: IF OD=1 THEN RW=16: RH=S*16: SY=48
            add  a,a
            add  a,a
            add  a,a
            add  a,a
            ld   b,a
            STV  bRW
            SETV bRH,16
            SETV bSY,32
            ZEROV bSX
            CPV  bOD,1
            jp   nz,L1666
            SETV bRW,16
            ld   a,b
            STV  bRH
            SETV bSY,48
L1666:      LDV  bLG                ; IF LG=0 THEN IF OD=1 THEN SX=16 ELSE SY=128
            or   a
            jp   nz,L1668
            CPV  bOD,1
            jp   nz,L1666a
            SETV bSX,16
            jp   L1668
L1666a:     SETV bSY,128
L1668:      ld   hl,bRW                 ; COPY композита -> страница 1
            ld   de,gh_rw
            ld   bc,6
            call memcpy
            SETV gh_on,1
            jp   gh_draw
; RW=0: призрак затёрт (не восстанавливать)
gh_forget:  ZEROV gh_on
            ret

; 3204: собрать композит корабля (тайлы вода + GT(I)) — хранится как gh_od/gh_s/gh_gt
L3204:      LDV  bOD
            STV  gh_od
            LDV  bS
            STV  gh_s
            ld   hl,ARR_GT
            ld   de,gh_gt
            ld   bc,5
            jp   memcpy

; ---------------------------------------------------------------- 1683: запретная зона вокруг корабля
L1683:      SETV bE,1  ; E=1: IF TU=1 THEN E=0
            CPV  bTU,1
            jp   nz,L1684
            ZEROV bE
L1684:      LDV  bE                 ; U1=TX(0)-E: V1=TY(0)-E: U2=TX(TN-1)+E: V2=TY(TN-1)+E
            ld   d,a
            xor  a
            call tx_a
            ld   a,b
            sub  d
            STV  bU1
            ld   a,c
            sub  d
            STV  bV1
            LDV  bTN
            dec  a
            call tx_a
            ld   a,b
            add  a,d
            STV  bU2
            ld   a,c
            add  a,d
            STV  bV2
            call clamp_uv
L1689:      LDV  bU1                ; FOR U=U1 TO U2: FOR V=V1 TO V2: BZ(U,V)=1
            STV  bU
L1689a:     LDV  bV1
            STV  bV
L1689b:     LDV  bV
            ld   e,a
            LDV  bU
            ld   bc,ARR_BZ
            call w10
            ld   (hl),1
            inc  hl
            ld   (hl),0
            INCV bV
            LDV  bV2
            cp   (hl)
            jp   p,L1689b
            INCV bU
            LDV  bU2
            cp   (hl)
            jp   p,L1689a
            ret
; 1685..1688: U1,V1 >= 0; U2,V2 <= 9
clamp_uv:   LDV  bU1
            or   a
            jp   p,cu_1
            ZEROV bU1
cu_1:       LDV  bV1
            or   a
            jp   p,cu_2
            ZEROV bV1
cu_2:       CPV  bU2,10
            jp   c,cu_3
            SETV bU2,9
cu_3:       CPV  bV2,10
            ret  c
            SETV bV2,9
            ret

; 1694: BZ()=0
L1694:      ld   hl,ARR_BZ
            ld   de,200
            jp   memzero

; ---------------------------------------------------------------- 1706/1755: корабль потоплен
L1706:      SETV bSD,1
            jp   L1756
L1755:      ZEROV bSD
L1756:      SETV bE,1  ; E=1: IF AM=0 OR BD=1 THEN E=0
            LDV  bAM
            or   a
            jp   z,L1756a
            CPV  bBD,1
            jp   nz,L1757
L1756a:     ZEROV bE
L1757:      ZEROV bI  ; FOR I=0 TO SZ(SH)-1
L1757a:     call pxy_off                ; SD=1: CM(QX(SH,I),QY(SH,I))=3
            ld   de,ARR_QX              ; SD=0: PM(PX,PY)=PM-(PM AND 3)+3
            ld   bc,ARR_CM
            CPV  bSD,1
            jp   z,L1757c
            ld   de,ARR_PX
            ld   bc,ARR_PM
L1757c:     add  hl,de
            call pxy_2                  ; A = X(SH,I), E = Y(SH,I) (Y = X + 60 у обоих)
            call w10
            CPV  bSD,1
            jp   nz,L1757b
            ld   (hl),3
            inc  hl
            ld   (hl),0
            jp   L1758
L1757b:     ld   a,(hl)
            or   3
            ld   (hl),a
L1758:      call next_i_sz
            jp   c,L1757a
            call sz_sh                  ; концы корабля: элемент 0 и SZ-1
            dec  c
            ld   a,c
            STV  rp_tmp+1
            ld   hl,ARR_QX
            CPV  bSD,1
            jp   z,L1758a
            ld   hl,ARR_PX
L1758a:     ld   (rp_tmp+2),hl          ; база X (Y = база + 60)
            LDV  bE
            ld   c,a
            LDV  bSH                ; U1=X(SH,0)-E: V1=Y(SH,0)-E
            call l1758_xy
            ld   a,b
            sub  c
            STV  bU1
            ld   a,d
            sub  c
            STV  bV1
            LDV  rp_tmp+1           ; U2=X(SH,SZ-1)+E: V2=Y(SH,SZ-1)+E
            add  a,a
            add  a,a
            ld   b,a
            add  a,a
            add  a,b
            ld   b,a
            LDV  bSH
            add  a,b
            call l1758_xy
            ld   a,b
            add  a,c
            STV  bU2
            ld   a,d
            add  a,c
            STV  bV2
            call clamp_uv
L1765:      LDV  bU1
            STV  bU
L1765a:     LDV  bV1
            STV  bV
L1765b:     LDV  bV
            ld   e,a
            LDV  bU
            ld   bc,ARR_CM
            ld   d,a
            CPV  bSD,1
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
L1770:      LDV  bU
            STV  bC
            LDV  bV
            STV  bR
            call L1105
L1775:      INCV bV
            LDV  bV2
            cp   (hl)
            jp   p,L1765b
            INCV bU
            LDV  bU2
            cp   (hl)
            jp   p,L1765a
            ret
; A = SH + I*12 -> B = X(база), D = Y(база+60)
l1758_xy:   ld   hl,(rp_tmp+2)
            rst  00h
            ld   b,(hl)
            ld   de,60
            add  hl,de
            ld   d,(hl)
            ret

; 1795 (сборки BD): потопленный свой корабль — PM -> 3 и перерисовать
L1795:      ZEROV bI
L1795a:     call pxy_off
            call pxy_hl
            STV  bC
            ld   a,e
            STV  bR
            ld   bc,ARR_PM
            call w10cr
            ld   a,(hl)
            or   3
            ld   (hl),a
            call L1105
            call next_i_sz
            jp   c,L1795a
            ret

s_enemy:    TXT  "ВРАГ"
s_yours:    TXT  "ВАШИ"
s_game:     TXT  "ИГРА"
s_at:       TXT  "ЦЕЛЬ:"
