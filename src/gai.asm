; ============================================================================
; gai.asm — перевод IRONCLAD.BAS: противник сборки IRONCLAD.BAS (1810..1973).
; PM в этой сборке 0..3 (SN не растёт), в сборках BD — до 2+4*SN < 256:
; старший байт PM всегда 0, сравниваем младший.
; ============================================================================

; HL = (A + 10*E)*2
off10:      ld   l,a
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
            ret
; A = PM(A,E) (младший байт)
pm_xy:      call off10
            ld   de,ARR_PM
            add  hl,de
            ld   a,(hl)
            ret
; Z, если PM(A,E)=0 и BZ(A,E)<>3 («открытая вода»)
open_xy:    call off10
            push hl
            ld   de,ARR_PM
            add  hl,de
            ld   a,(hl)
            pop  hl
            or   a
            ret  nz
            ld   de,ARR_BZ
            add  hl,de
            ld   a,(hl)
            cp   3
            jp   z,ox_no
            xor  a
            ret
ox_no:      or   a
            ret
; Z, если PM(A,E)=2 или открытая вода
hitopen_xy: push af
            push de
            call pm_xy
            pop  de
            cp   2
            jp   z,ho_y
            pop  af
            jp   open_xy
ho_y:       pop  af
            xor  a
            ret
; слово bX / bY = знаковый байт A
st_x:       ld   l,a
            add  a,a
            sbc  a,a
            ld   h,a
            ld   (bX),hl
            ret
st_y:       ld   l,a
            add  a,a
            sbc  a,a
            ld   h,a
            ld   (bY),hl
            ret
; SC>NB (со знаком) ? -> CY
sc_gt_nb:   ld   hl,(bNB)
            ex   de,hl
            ld   hl,(bSC)
            call cmp_hl_de              ; CY = SC<NB, Z = равны
            jp   z,sg_no
            ccf                         ; CY = SC>NB
            ret
sg_no:      or   a
            ret
; SC = SC*A + INT(RND(1)*A)
sc_mul_rnd: STV  sm_k
            ld   hl,(bSC)
            ld   e,a
            ld   d,0
            call mul16
            ld   (bSC),hl
            LDV  sm_k
            call rnd_n
            ld   hl,(bSC)
            rst  00h
            ld   (bSC),hl
            ret

; ---------------------------------------------------------------- 1810: добивание
L1810:      LDV  bSU                ; IF TP-SU<=0 THEN 1902
            ld   b,a
            LDV  bTP
            cp   b
            jp   z,L1902
            jp   c,L1902
L1811:      LDV  bHY                ; IF PM(HX,HY)=2 THEN 1814 ELSE найти любую PM=2
            ld   e,a
            LDV  bHX
            call pm_xy
            cp   2
            jp   z,L1814
            ld   hl,pm_is2
            call scan_cells
            jp   nc,L1814
            ld   a,b
            STV  bHX
            ld   a,c
            STV  bHY
L1814:      ld   hl,-1
            ld   (bNB),hl
            ZEROV bD
L1814a:     LDV  bD                 ; U1=1-D: V1=D: A=HX: B=HY
            ld   b,a
            ld   a,1
            sub  b
            STV  bU1
            ld   a,b
            STV  bV1
            LDV  bHX
            STV  bA
            LDV  bHY
            STV  bB
L1815:      LDV  bU1                ; назад по линии попаданий
            ld   c,a
            LDV  bA
            sub  c
            jp   m,L1816
            ld   d,a
            LDV  bV1
            ld   c,a
            LDV  bB
            sub  c
            jp   m,L1816
            ld   e,a
            push de
            ld   a,d
            call pm_xy
            pop  de
            cp   2
            jp   nz,L1816
            ld   a,d
            STV  bA
            ld   a,e
            STV  bB
            jp   L1815
L1816:      LDV  bHX
            STV  bC
            LDV  bHY
            STV  bR
L1817:      LDV  bU1                ; вперёд
            ld   c,a
            LDV  bC
            add  a,c
            cp   10
            jp   nc,L1818
            ld   d,a
            LDV  bV1
            ld   c,a
            LDV  bR
            add  a,c
            cp   10
            jp   nc,L1818
            ld   e,a
            push de
            ld   a,d
            call pm_xy
            pop  de
            cp   2
            jp   nz,L1818
            ld   a,d
            STV  bC
            ld   a,e
            STV  bR
            jp   L1817
L1818:      LDV  bA                 ; S=C-A+R-B+1: E1=0: U=A-U1: V=B-V1
            ld   b,a
            LDV  bC
            sub  b
            ld   b,a
            LDV  bB
            ld   c,a
            LDV  bR
            sub  c
            add  a,b
            inc  a
            STV  bS
            ZEROV bE1
            LDV  bU1
            ld   b,a
            LDV  bA
            sub  b
            STV  bU
            LDV  bV1
            ld   b,a
            LDV  bB
            sub  b
            STV  bV
L1819:      LDV  bU
            or   a
            jp   m,L1820
            LDV  bV
            or   a
            jp   m,L1820
            CPV  bE1,4
            jp   nc,L1820
            LDV  bV
            ld   e,a
            LDV  bU
            call hitopen_xy
            jp   nz,L1820
            INCV bE1
            call uv_minus
            jp   L1819
L1820:      ZEROV bE2  ; E2=0: U=C+U1: V=R+V1
            LDV  bU1
            ld   b,a
            LDV  bC
            add  a,b
            STV  bU
            LDV  bV1
            ld   b,a
            LDV  bR
            add  a,b
            STV  bV
L1821:      CPV  bU,10
            jp   nc,L1822
            CPV  bV,10
            jp   nc,L1822
            CPV  bE2,4
            jp   nc,L1822
            LDV  bV
            ld   e,a
            LDV  bU
            call hitopen_xy
            jp   nz,L1822
            INCV bE2
            call uv_plus
            jp   L1821
L1822:      LDV  bE1                ; IF E1=0 THEN 1830 ELSE X=A-U1: Y=B-V1
            or   a
            jp   z,L1830
            LDV  bU1
            ld   b,a
            LDV  bA
            sub  b
            call st_x
            LDV  bV1
            ld   b,a
            LDV  bB
            sub  b
            call st_y
            LDV  bY
            ld   e,a
            LDV  bX
            call open_xy
            jp   nz,L1830
L1823:      LDV  bE1                ; счёт мест: M<=E1, T=L-E2
            ld   b,a
            LDV  bE2
            ld   c,a
            call hscore
L1827:      call hs_take
L1830:      LDV  bE2
            or   a
            jp   z,L1839
            LDV  bU1
            ld   b,a
            LDV  bC
            add  a,b
            call st_x
            LDV  bV1
            ld   b,a
            LDV  bR
            add  a,b
            call st_y
            LDV  bY
            ld   e,a
            LDV  bX
            call open_xy
            jp   nz,L1839
L1831:      LDV  bE2
            ld   b,a
            LDV  bE1
            ld   c,a
            call hscore
L1835:      call hs_take
L1839:      INCV bD
            ld   a,(hl)
            cp   2
            jp   c,L1814a
            LDV  bNB+1              ; IF NB>=0 THEN RETURN
            or   a
            ret  p
; первая клетка (I=0..9 внешний, J=0..9 внутренний), где процедура HL (A = I, E = J) даёт Z:
; CY=1 — нашли, B = I, C = J. Как после FOR в оригинале: I = J = 10 (слова)
scan_cells: ld   b,0
scn_1:      ld   c,0
scn_2:      push bc
            push hl
            ld   a,b
            ld   e,c
            call scn_c
            pop  hl
            pop  bc
            jp   z,scn_y
            inc  c
            ld   a,c
            cp   10
            jp   c,scn_2
            inc  b
            ld   a,b
            cp   10
            jp   c,scn_1
scn_y:      push af
            ld   hl,10
            ld   (bI),hl
            ld   (bJ),hl
            pop  af
            scf
            ret  z
            ccf
            ret
scn_c:      jp   (hl)
pm_is2:     call pm_xy
            cp   2
            ret
pm_is0:     call pm_xy
            or   a
            ret
; 1908..1914: сколько подряд (не больше 4) открытых клеток от (D,E) с шагом (B,C) в поле;
; A = счёт, D/E — клетка остановки
cnt_open:   xor  a
co_1:       push af
            ld   a,d
            cp   10
            jp   nc,co_x
            ld   a,e
            cp   10
            jp   nc,co_x
            push bc
            push de
            ld   a,d
            call open_xy
            pop  de
            pop  bc
            jp   nz,co_x
            ld   a,d
            add  a,b
            ld   d,a
            ld   a,e
            add  a,c
            ld   e,a
            pop  af
            inc  a
            cp   4
            jp   c,co_1
            ret
co_x:       pop  af
            ret
; IF SC>NB THEN NB=SC: BX=D: BY=E
nb_take:    push de
            call sc_gt_nb
            pop  de
            ret  nc
            ld   hl,(bSC)
            ld   (bNB),hl
            ld   a,d
            STV  bBX
            ld   a,e
            STV  bBY
            ret

L1840:      ZEROV bD  ; FOR D=0 TO 3: соседняя открытая клетка
L1840a:     call L1890
            LDV  bU1
            ld   b,a
            LDV  bHX
            add  a,b
            call st_x
            LDV  bV1
            ld   b,a
            LDV  bHY
            add  a,b
            call st_y
            CPV  bX,10
            jp   nc,L1841               ; X<0 тоже сюда (как беззнаковое >= 10)
            CPV  bY,10
            jp   nc,L1841
            ld   e,a
            LDV  bX
            call open_xy
            jp   nz,L1841
            LDV  bX
            STV  bBX
            LDV  bY
            STV  bBY
            ret
L1841:      INCV bD
            ld   a,(hl)
            cp   4
            jp   c,L1840a
            ; сквозной проход в 1890 (как в оригинале: NEXT D, затем строка 1890 и RETURN)
L1890:      LDV  bD                 ; U1,V1 по направлению D (D=4 — после NEXT D: как D=3)
            add  a,a
            ld   hl,t1890
            rst  00h
            ld   a,(hl)
            STV  bU1
            inc  hl
            ld   a,(hl)
            STV  bV1
L1891:      ret
t1890:      db -1,0, 1,0, 0,-1, 0,1, 0,1

; U=U-U1: V=V-V1 / U=U+U1: V=V+V1
uv_minus:   LDV  bU1
            ld   b,a
            LDV  bU
            sub  b
            STV  bU
            LDV  bV1
            ld   b,a
            LDV  bV
            sub  b
            STV  bV
            ret
uv_plus:    LDV  bU1
            ld   b,a
            LDV  bU
            add  a,b
            STV  bU
            LDV  bV1
            ld   b,a
            LDV  bV
            add  a,b
            STV  bV
            ret

; 1823..1826 / 1831..1834: SC = сумма по живым K=1..5 мест корабля L=SZ(K)-S,
; где M=min(L,B) и T=max(L-C,1): если M>=T, то SC += M-T+1
hscore:     ld   hl,0
            ld   (bSC),hl
            SETV bK,1
hs_k:       push bc
            call k_ph_sz
            ld   d,b                    ; PH(K)
            ld   e,c                    ; SZ(K)
            pop  bc
            ld   a,d
            cp   e
            jp   nc,hs_n                ; PH>=SZ — потоплен
            LDV  bS
            ld   d,a
            ld   a,e
            sub  d                      ; L=SZ(K)-S
            jp   m,hs_n
            jp   z,hs_n                 ; L<1
            STV  bL
            sub  c                      ; T=L-C
            jp   m,hs_t1
            jp   nz,hs_t2
hs_t1:      ld   a,1                    ; T<1 -> T=1
hs_t2:      ld   d,a                    ; D=T
            LDV  bL
            cp   b
            jp   c,hs_m
            ld   a,b                    ; M=min(L,B)
hs_m:       cp   d
            jp   c,hs_n                 ; M<T
            sub  d
            inc  a                      ; M-T+1
            ld   hl,(bSC)
            rst  00h
            ld   (bSC),hl
hs_n:       LDV  bK
            inc  a
            STV  bK
            cp   6
            jp   c,hs_k
            ret
; 1827/1835: IF SC>0 THEN SC=SC*10+INT(RND(1)*10): IF SC>NB THEN NB=SC: BX=X: BY=Y
hs_take:    ld   hl,(bSC)
            ld   a,h
            or   l
            ret  z
            ld   a,10
            call sc_mul_rnd
            LDV  bX
            ld   d,a
            LDV  bY
            ld   e,a
            jp   nb_take

; ---------------------------------------------------------------- 1902: поиск по вероятностям
L1902:      LDV  bTD
            or   a
            jp   z,L1906
            ZEROV bTD  ; TD=0: GA(A,B) для A,B=0..4
            STV  bA
L1902a:     ZEROV bB
L1902b:     ld   hl,0
            ld   (bT),hl
            SETV bK,1
L1902c:     call k_ph_sz                ; IF PH(K)>=SZ(K) THEN 1905
            ld   a,b
            cp   c
            jp   nc,L1905
            ld   a,c                    ; L=SZ(K): X=MIN(A,L-1): Y=MIN(B,L-1)
            STV  bL
            dec  a
            ld   c,a
            LDV  bA
            cp   c
            jp   c,L1903
            ld   a,c
L1903:      ld   b,a
            LDV  bB
            cp   c
            jp   c,L1904
            ld   a,c
L1904:      add  a,b                    ; IF X+Y-L+2>0 THEN T=T+X+Y-L+2
            add  a,2
            ld   hl,bL
            sub  (hl)
            jp   m,L1905
            jp   z,L1905
            ld   hl,(bT)
            rst  00h
            ld   (bT),hl
L1905:      INCV bK
            ld   a,(hl)
            cp   6
            jp   c,L1902c
            call ga_ab                  ; GA(A,B)=T
            LDV  bT
            ld   (hl),a
            inc  hl
            LDV  bT+1
            ld   (hl),a
            INCV bB
            ld   a,(hl)
            cp   5
            jp   c,L1902b
            INCV bA
            ld   a,(hl)
            cp   5
            jp   c,L1902a
L1906:      ld   hl,-1
            ld   (bNB),hl
            SETV bSM,1
L1906a:     ld   a,100                  ; P=INT(RND(1)*100): I=P\10: J=P MOD 10
            call rnd_n
            STV  bP
            call div10
            STV  bI
            ld   a,b
            STV  bJ
            ZEROV bJ+1
            STV  bI+1
            LDV  bJ                 ; IF PM(I,J)<>0 OR BZ(I,J)=3 THEN 1919
            ld   e,a
            LDV  bI
            call open_xy
            jp   nz,L1919
L1907:      ld   bc,0FF00h              ; A = свободных влево (по X): U от I-1
            call co_u
            STV  bA
L1909:      ld   bc,0100h               ; B = вправо: U от I+1
            call co_u
            STV  bB
L1911:      call ga_ab                  ; SC=GA(A,B): A=0: V=J-1
            ld   a,(hl)
            inc  hl
            ld   h,(hl)
            ld   l,a
            ld   (bSC),hl
            ld   bc,00FFh               ; A = вверх (по Y): V от J-1
            call co_v
            STV  bA
L1913:      ld   bc,0001h               ; B = вниз: V от J+1
            call co_v
            STV  bB
L1915:      call ga_ab                  ; SC=SC+GA(A,B)
            ld   e,(hl)
            inc  hl
            ld   d,(hl)
            ld   hl,(bSC)
            add  hl,de
            ld   (bSC),hl
            ld   a,h
            or   l
            jp   nz,L1916
            LDV  bI                 ; SC=0: здесь корабля быть не может — буй
            STV  bC
            LDV  bJ
            STV  bR
            ld   a,160
            call buoy_cr
            jp   L1919
L1916:      ld   a,10
            call sc_mul_rnd
            call nb_ij
L1919:      INCV bSM
            ld   a,(hl)
            cp   21
            jp   c,L1906a
            LDV  bNB+1
            or   a
            ret  p
L1920:      ld   hl,open_xy             ; первая открытая клетка
            call scan_cells
            jp   nc,L1921x
            ld   a,b
            STV  bBX
            ld   a,c
            STV  bBY
            ld   hl,0
            ld   (bNB),hl
L1921x:     LDV  bNB+1
            or   a
            ret  p
L1922:      ld   a,10                   ; случайная нестрелянная
            call rnd_n
            STV  bBX
            ld   a,10
            call rnd_n
            STV  bBY
            ld   e,a
            LDV  bBX
            call pm_xy
            or   a
            jp   nz,L1922
L1924:      ret

; HL = &GA(A,B) = ARR_GA + (A + 8B)*2
ga_ab:      LDV  bB
            add  a,a
            add  a,a
            add  a,a
            ld   b,a
            LDV  bA
            add  a,b
            add  a,a
            ld   hl,ARR_GA
            jp   add_a_hl

; ---------------------------------------------------------------- 1925: буи по диагоналям попадания
L1925:      LDV  bFX                ; FOR X=FX-1 TO FX+1 STEP 2
            dec  a
            STV  bX
L1925a:     LDV  bFY                ; FOR Y=FY-1 TO FY+1 STEP 2
            dec  a
            STV  bY
L1925b:     call buoy_xy
            LDV  bFY
            inc  a
            ld   b,a
            LDV  bY
            add  a,2
            STV  bY
            cp   b
            jp   z,L1925b
            jp   c,L1925b
            LDV  bFX
            inc  a
            ld   b,a
            LDV  bX
            add  a,2
            STV  bX
            cp   b
            jp   z,L1925a
            jp   c,L1925a
            ret
; IF 0<=X<=9 AND 0<=Y<=9 THEN IF PM(X,Y)=0 AND BZ(X,Y)<>3 THEN BZ(X,Y)=3: SD=0: C=X: R=Y: Q=176: GOSUB 1105
; (X, Y — младшие байты, со знаком)
buoy_xy:    CPV  bX,10
            ret  nc
            CPV  bY,10
            ret  nc
            ld   e,a
            LDV  bX
            call open_xy
            ret  nz
            LDV  bX
            STV  bC
            LDV  bY
            STV  bR
            ld   a,176
            jp   buoy_cr

; ---------------------------------------------------------------- 1930: буи вокруг потопленного
L1930:      ZEROV bI
L1930a:     call pxy_off                ; PX(SH,I), PY(SH,I)
            ld   de,ARR_PX
            add  hl,de
            ld   a,(hl)
            STV  rp_tmp
            ld   de,60
            add  hl,de
            ld   a,(hl)
            STV  rp_tmp+1
            LDV  rp_tmp             ; FOR X=PX-1 TO PX+1
            dec  a
            STV  bX
L1930b:     LDV  rp_tmp+1           ; FOR Y=PY-1 TO PY+1
            dec  a
            STV  bY
L1930c:     call buoy_xy
            LDV  rp_tmp+1
            ld   b,a
            LDV  bY
            inc  a
            STV  bY
            dec  a
            cp   b
            jp   m,L1930c
            jp   z,L1930c
            LDV  rp_tmp
            ld   b,a
            LDV  bX
            inc  a
            STV  bX
            dec  a
            cp   b
            jp   m,L1930b
            jp   z,L1930b
            call next_i_sz
            jp   c,L1930a
            ret

; ---------------------------------------------------------------- 1940: STEALTH (только «попал/мимо», корабли касаются)
L1940:      ld   hl,(ARR_GB+(7+4*8)*2)  ; IF GB(7,4)=0 THEN GB(7,I)=6^I
            ld   a,h
            or   l
            jp   nz,L1941
            ld   hl,1
            ld   (ARR_GB+(7+0*8)*2),hl
            ld   hl,6
            ld   (ARR_GB+(7+1*8)*2),hl
            ld   hl,36
            ld   (ARR_GB+(7+2*8)*2),hl
            ld   hl,216
            ld   (ARR_GB+(7+3*8)*2),hl
            ld   hl,1296
            ld   (ARR_GB+(7+4*8)*2),hl
L1941:      ld   hl,-1
            ld   (bNB),hl
            ZEROV bTM
            STV  bI
L1941a:     ZEROV bJ
L1941b:     LDV  bJ                 ; IF PM(I,J)<>0 THEN 1946
            ld   e,a
            LDV  bI
            call pm_xy
            or   a
            jp   nz,L1946
L1942:      ZEROV bT  ; T=1, если по соседству попадание (PM>1)
            LDV  bI
            or   a
            jp   z,L1943
            dec  a
            call nb_hit
L1943:      CPV  bI,9
            jp   z,L1944
            inc  a
            call nb_hit
L1944:      LDV  bJ
            or   a
            jp   z,L1945
            dec  a
            ld   e,a
            LDV  bI
            call nb_hit2
L1945:      CPV  bJ,9
            jp   z,L1946
            inc  a
            ld   e,a
            LDV  bI
            call nb_hit2
L1946:      CPV  bT,1  ; IF T=1 THEN T=0: TM=1: X=I: Y=J: GOSUB 1960: IF SC>NB ...
            jp   nz,L1947
            ZEROV bT
            inc  a
            STV  bTM
            LDV  bI
            call st_x
            LDV  bJ
            call st_y
            call L1960
            call nb_ij
L1947:      INCV bJ
            ld   a,(hl)
            cp   10
            jp   c,L1941b
            INCV bI
            ld   a,(hl)
            cp   10
            jp   c,L1941a
            CPV  bTM,1
            ret  z
L1948:      SETV bSM,1
L1948a:     ld   a,100
            call rnd_n
            STV  bP
            call div10
            call st_x                   ; X=P\10
            ld   a,b
            call st_y                   ; Y=P MOD 10
            LDV  bY                 ; IF PM(X,Y)<>0 OR ((X+Y+PA) AND 1)=1 THEN 1950
            ld   e,a
            LDV  bX
            call pm_xy
            or   a
            jp   nz,L1950
            LDV  bPA
            ld   b,a
            LDV  bX
            add  a,b
            ld   b,a
            LDV  bY
            add  a,b
            and  1
            jp   nz,L1950
L1949:      call L1960
            LDV  bX
            ld   d,a
            LDV  bY
            ld   e,a
            call nb_take
L1950:      INCV bSM
            ld   a,(hl)
            cp   21
            jp   c,L1948a
            LDV  bNB+1
            or   a
            ret  p
L1951:      ld   hl,pm_is0              ; первая нестрелянная
            call scan_cells
            ret  nc
            ld   a,b
            STV  bBX
            ld   a,c
            STV  bBY
            ret
; IF SC>NB THEN NB=SC: BX=I: BY=J
nb_ij:      LDV  bI
            ld   d,a
            LDV  bJ
            ld   e,a
            jp   nb_take
; 1908/1910: от (I±1, J) шагом (B,C): A = счёт, U = столбец остановки
co_u:       LDV  bI
            add  a,b
            ld   d,a
            LDV  bJ
            ld   e,a
            call cnt_open
            push af
            ld   a,d
            STV  bU
            pop  af
            ret
; 1912/1914: от (I, J±1) шагом (B,C): A = счёт, V = строка остановки
co_v:       LDV  bJ
            add  a,c
            ld   e,a
            LDV  bI
            ld   d,a
            call cnt_open
            push af
            ld   a,e
            STV  bV
            pop  af
            ret
; T=1, если PM(A,J)>1 / PM(A,E)>1
nb_hit:     ld   e,a
            LDV  bJ
            ld   d,a
            ld   a,e
            ld   e,d
nb_hit2:    call pm_xy
            cp   2
            ret  c
            SETV bT,1
            ret

; 1960: SC клетки (X,Y) по сериям попаданий (веса GB(7,n) = 6^n)
L1960:      ld   hl,0
            ld   (bSC),hl
            ZEROV bD
L1960a:     LDV  bD                 ; U1=1-D: V1=D: A=0: C=X-U1: R=Y-V1: GA(0,0)=0
            ld   b,a
            ld   a,1
            sub  b
            STV  bU1
            ld   a,b
            STV  bV1
            ZEROV bA
            ld   hl,0
            ld   (ARR_GA),hl
            LDV  bU1
            ld   b,a
            LDV  bX
            sub  b
            STV  bC
            LDV  bV1
            ld   b,a
            LDV  bY
            sub  b
            STV  bR
L1961:      CPV  bA,4  ; IF A<4 AND C>=0 AND R>=0 THEN IF PM(C,R)<>1 THEN ...
            jp   nc,L1962
            LDV  bC
            or   a
            jp   m,L1962
            LDV  bR
            or   a
            jp   m,L1962
            ld   e,a
            LDV  bC
            call pm_xy
            cp   1
            jp   z,L1962
            ld   c,0                    ; -(PM(C,R)>1)
            jp   c,L1961a               ; PM=0
            inc  c
L1961a:     LDV  bA                 ; GA(0,A+1)=GA(0,A)+c
            add  a,a
            add  a,a
            add  a,a
            add  a,a
            ld   hl,ARR_GA
            rst  00h
            ld   a,(hl)
            add  a,c
            ld   de,16
            add  hl,de
            ld   (hl),a
            inc  hl
            ld   (hl),0
            INCV bA
            LDV  bU1
            ld   b,a
            LDV  bC
            sub  b
            STV  bC
            LDV  bV1
            ld   b,a
            LDV  bR
            sub  b
            STV  bR
            jp   L1961
L1962:      ZEROV bB  ; B=0: C=X+U1: R=Y+V1: GA(1,0)=0
            ld   hl,0
            ld   (ARR_GA+2),hl
            LDV  bU1
            ld   b,a
            LDV  bX
            add  a,b
            STV  bC
            LDV  bV1
            ld   b,a
            LDV  bY
            add  a,b
            STV  bR
L1963:      CPV  bB,4
            jp   nc,L1964
            CPV  bC,10
            jp   nc,L1964
            CPV  bR,10
            jp   nc,L1964
            ld   e,a
            LDV  bC
            call pm_xy
            cp   1
            jp   z,L1964
            ld   c,0
            jp   c,L1963a
            inc  c
L1963a:     LDV  bB                 ; GA(1,B+1)=GA(1,B)+c
            add  a,a
            add  a,a
            add  a,a
            add  a,a
            ld   hl,ARR_GA+2
            rst  00h
            ld   a,(hl)
            add  a,c
            ld   de,16
            add  hl,de
            ld   (hl),a
            inc  hl
            ld   (hl),0
            INCV bB
            LDV  bU1
            ld   b,a
            LDV  bC
            add  a,b
            STV  bC
            LDV  bV1
            ld   b,a
            LDV  bR
            add  a,b
            STV  bR
            jp   L1963
L1964:      SETV bK,1  ; FOR K=1 TO 5: L=SZ(K): FOR M=0 TO L-1: N=L-1-M
L1964a:     LDV  bK
            ld   hl,ARR_SZ
            add  a,a
            rst  00h
            ld   a,(hl)
            STV  bL
            ZEROV bM
            STV  bM+1
L1964b:     LDV  bM
            ld   b,a
            LDV  bL
            dec  a
            sub  b
            STV  bN                 ; N=L-1-M
            LDV  bA                 ; IF M<=A AND N<=B THEN SC=SC+GB(7,GA(0,M)+GA(1,N))
            cp   b
            jp   c,L1965
            LDV  bB
            ld   c,a
            LDV  bN
            cp   c
            jp   z,L1964c
            jp   nc,L1965
L1964c:     ld   a,b                    ; GA(0,M)
            add  a,a
            add  a,a
            add  a,a
            add  a,a
            ld   hl,ARR_GA
            rst  00h
            ld   c,(hl)
            LDV  bN                 ; + GA(1,N)
            add  a,a
            add  a,a
            add  a,a
            add  a,a
            ld   hl,ARR_GA+2
            rst  00h
            ld   a,(hl)
            add  a,c                    ; индекс n
            add  a,a
            add  a,a
            add  a,a
            add  a,a                    ; n*16
            ld   hl,ARR_GB+14
            rst  00h
            ld   e,(hl)
            inc  hl
            ld   d,(hl)
            ld   hl,(bSC)
            add  hl,de
            ld   (bSC),hl
L1965:      INCV bM
            LDV  bL
            ld   b,a
            ld   a,(hl)
            cp   b
            jp   c,L1964b
            INCV bK
            ld   a,(hl)
            cp   6
            jp   c,L1964a
            INCV bD
            ld   a,(hl)
            cp   2
            jp   c,L1960a
            ld   a,8                    ; SC=SC*8+INT(RND(1)*8)
            jp   sc_mul_rnd

; ---------------------------------------------------------------- 1967: ANKA (детский)
L1967:      SETV bHW,1
            ZEROV bI
L1967a:     ZEROV bJ
L1967b:     LDV  bJ                 ; IF (PM(I,J) AND 3)<>2 THEN 1972
            ld   e,a
            LDV  bI
            call pm_xy
            and  3
            cp   2
            jp   nz,L1972
L1968:      ld   a,4                    ; DA=INT(RND(1)*4): FOR T=0 TO 3: D=(DA+T) AND 3
            call rnd_n
            STV  bDA
            ZEROV bT
L1968a:     LDV  bDA
            ld   b,a
            LDV  bT
            add  a,b
            and  3
            STV  bD
            call L1890
            LDV  bU1                ; X=I+U1: Y=J+V1
            ld   b,a
            LDV  bI
            add  a,b
            call st_x
            LDV  bV1
            ld   b,a
            LDV  bJ
            add  a,b
            call st_y
            CPV  bX,10  ; вне поля -> 1971
            jp   nc,L1971
            CPV  bY,10
            jp   nc,L1971
L1969:      ld   e,a                    ; IF PM(X,Y)=0 THEN BX=X: BY=Y: HW=0: T=3: I=9: J=9
            LDV  bX
            call pm_xy
            or   a
            jp   nz,L1971
            LDV  bX
            STV  bBX
            LDV  bY
            STV  bBY
            ZEROV bHW
            SETV bT,3
            SETV bI,9
            STV  bJ
L1971:      INCV bT
            ld   a,(hl)
            cp   4
            jp   c,L1968a
L1972:      INCV bJ
            ld   a,(hl)
            cp   10
            jp   c,L1967b
            INCV bI
            ld   a,(hl)
            cp   10
            jp   c,L1967a
            LDV  bHW
            or   a
            ret  z
L1973:      jp   L1922
