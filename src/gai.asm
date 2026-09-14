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
sc_mul_rnd: ld   (sm_k),a
            ld   hl,(bSC)
            ld   e,a
            ld   d,0
            call mul16
            ld   (bSC),hl
            ld   a,(sm_k)
            call rnd_n
            ld   hl,(bSC)
            rst  08h
            ld   (bSC),hl
            ret

; ---------------------------------------------------------------- 1810: добивание
L1810:      ld   a,(bSU)                ; IF TP-SU<=0 THEN 1902
            ld   b,a
            ld   a,(bTP)
            cp   b
            jp   z,L1902
            jp   c,L1902
L1811:      ld   a,(bHY)                ; IF PM(HX,HY)=2 THEN 1814 ELSE найти любую PM=2
            ld   e,a
            ld   a,(bHX)
            call pm_xy
            cp   2
            jp   z,L1814
            ld   b,0
L1811a:     ld   c,0
L1811b:     push bc
            ld   a,b
            ld   e,c
            call pm_xy
            pop  bc
            cp   2
            jp   nz,L1812
            ld   a,b
            ld   (bHX),a
            ld   a,c
            ld   (bHY),a
            jp   L1812x
L1812:      inc  c
            ld   a,c
            cp   10
            jp   c,L1811b
            inc  b
            ld   a,b
            cp   10
            jp   c,L1811a
L1812x:     ld   hl,10                  ; I, J после циклов
            ld   (bI),hl
            ld   (bJ),hl
L1814:      ld   hl,-1
            ld   (bNB),hl
            xor  a
            ld   (bD),a
L1814a:     ld   a,(bD)                 ; U1=1-D: V1=D: A=HX: B=HY
            ld   b,a
            ld   a,1
            sub  b
            ld   (bU1),a
            ld   a,b
            ld   (bV1),a
            ld   a,(bHX)
            ld   (bA),a
            ld   a,(bHY)
            ld   (bB),a
L1815:      ld   a,(bU1)                ; назад по линии попаданий
            ld   c,a
            ld   a,(bA)
            sub  c
            jp   m,L1816
            ld   d,a
            ld   a,(bV1)
            ld   c,a
            ld   a,(bB)
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
            ld   (bA),a
            ld   a,e
            ld   (bB),a
            jp   L1815
L1816:      ld   a,(bHX)
            ld   (bC),a
            ld   a,(bHY)
            ld   (bR),a
L1817:      ld   a,(bU1)                ; вперёд
            ld   c,a
            ld   a,(bC)
            add  a,c
            cp   10
            jp   nc,L1818
            ld   d,a
            ld   a,(bV1)
            ld   c,a
            ld   a,(bR)
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
            ld   (bC),a
            ld   a,e
            ld   (bR),a
            jp   L1817
L1818:      ld   a,(bA)                 ; S=C-A+R-B+1: E1=0: U=A-U1: V=B-V1
            ld   b,a
            ld   a,(bC)
            sub  b
            ld   b,a
            ld   a,(bB)
            ld   c,a
            ld   a,(bR)
            sub  c
            add  a,b
            inc  a
            ld   (bS),a
            xor  a
            ld   (bE1),a
            ld   a,(bU1)
            ld   b,a
            ld   a,(bA)
            sub  b
            ld   (bU),a
            ld   a,(bV1)
            ld   b,a
            ld   a,(bB)
            sub  b
            ld   (bV),a
L1819:      ld   a,(bU)
            or   a
            jp   m,L1820
            ld   a,(bV)
            or   a
            jp   m,L1820
            ld   a,(bE1)
            cp   4
            jp   nc,L1820
            ld   a,(bV)
            ld   e,a
            ld   a,(bU)
            call hitopen_xy
            jp   nz,L1820
            ld   hl,bE1
            inc  (hl)
            call uv_minus
            jp   L1819
L1820:      xor  a                      ; E2=0: U=C+U1: V=R+V1
            ld   (bE2),a
            ld   a,(bU1)
            ld   b,a
            ld   a,(bC)
            add  a,b
            ld   (bU),a
            ld   a,(bV1)
            ld   b,a
            ld   a,(bR)
            add  a,b
            ld   (bV),a
L1821:      ld   a,(bU)
            cp   10
            jp   nc,L1822
            ld   a,(bV)
            cp   10
            jp   nc,L1822
            ld   a,(bE2)
            cp   4
            jp   nc,L1822
            ld   a,(bV)
            ld   e,a
            ld   a,(bU)
            call hitopen_xy
            jp   nz,L1822
            ld   hl,bE2
            inc  (hl)
            call uv_plus
            jp   L1821
L1822:      ld   a,(bE1)                ; IF E1=0 THEN 1830 ELSE X=A-U1: Y=B-V1
            or   a
            jp   z,L1830
            ld   a,(bU1)
            ld   b,a
            ld   a,(bA)
            sub  b
            call st_x
            ld   a,(bV1)
            ld   b,a
            ld   a,(bB)
            sub  b
            call st_y
            ld   a,(bY)
            ld   e,a
            ld   a,(bX)
            call open_xy
            jp   nz,L1830
L1823:      ld   a,(bE1)                ; счёт мест: M<=E1, T=L-E2
            ld   b,a
            ld   a,(bE2)
            ld   c,a
            call hscore
L1827:      call hs_take
L1830:      ld   a,(bE2)
            or   a
            jp   z,L1839
            ld   a,(bU1)
            ld   b,a
            ld   a,(bC)
            add  a,b
            call st_x
            ld   a,(bV1)
            ld   b,a
            ld   a,(bR)
            add  a,b
            call st_y
            ld   a,(bY)
            ld   e,a
            ld   a,(bX)
            call open_xy
            jp   nz,L1839
L1831:      ld   a,(bE2)
            ld   b,a
            ld   a,(bE1)
            ld   c,a
            call hscore
L1835:      call hs_take
L1839:      ld   hl,bD
            inc  (hl)
            ld   a,(hl)
            cp   2
            jp   c,L1814a
            ld   a,(bNB+1)              ; IF NB>=0 THEN RETURN
            or   a
            ret  p
L1840:      xor  a                      ; FOR D=0 TO 3: соседняя открытая клетка
            ld   (bD),a
L1840a:     call L1890
            ld   a,(bU1)
            ld   b,a
            ld   a,(bHX)
            add  a,b
            call st_x
            ld   a,(bV1)
            ld   b,a
            ld   a,(bHY)
            add  a,b
            call st_y
            ld   a,(bX)
            cp   10
            jp   nc,L1841               ; X<0 тоже сюда (как беззнаковое >= 10)
            ld   a,(bY)
            cp   10
            jp   nc,L1841
            ld   e,a
            ld   a,(bX)
            call open_xy
            jp   nz,L1841
            ld   a,(bX)
            ld   (bBX),a
            ld   a,(bY)
            ld   (bBY),a
            ret
L1841:      ld   hl,bD
            inc  (hl)
            ld   a,(hl)
            cp   4
            jp   c,L1840a
            ; сквозной проход в 1890 (как в оригинале: NEXT D, затем строка 1890 и RETURN)
L1890:      xor  a                      ; U1,V1 по направлению D
            ld   (bU1),a
            ld   (bV1),a
            ld   a,(bD)
            or   a
            jp   nz,L1890a
            ld   a,-1
            ld   (bU1),a
            ret
L1890a:     cp   1
            jp   nz,L1890b
            ld   a,1
            ld   (bU1),a
            ret
L1890b:     cp   2
            jp   nz,L1890c
            ld   a,-1
            ld   (bV1),a
            ret
L1890c:     ld   a,1
            ld   (bV1),a
L1891:      ret

; U=U-U1: V=V-V1 / U=U+U1: V=V+V1
uv_minus:   ld   a,(bU1)
            ld   b,a
            ld   a,(bU)
            sub  b
            ld   (bU),a
            ld   a,(bV1)
            ld   b,a
            ld   a,(bV)
            sub  b
            ld   (bV),a
            ret
uv_plus:    ld   a,(bU1)
            ld   b,a
            ld   a,(bU)
            add  a,b
            ld   (bU),a
            ld   a,(bV1)
            ld   b,a
            ld   a,(bV)
            add  a,b
            ld   (bV),a
            ret

; 1823..1826 / 1831..1834: SC = сумма по живым K=1..5 мест корабля L=SZ(K)-S,
; где M=min(L,B) и T=max(L-C,1): если M>=T, то SC += M-T+1
hscore:     ld   hl,0
            ld   (bSC),hl
            ld   a,1
            ld   (bK),a
hs_k:       ld   a,(bK)
            ld   hl,ARR_PH
            add  a,a
            rst  08h
            ld   d,(hl)                 ; PH(K)
            ld   a,(bK)
            ld   hl,ARR_SZ
            add  a,a
            rst  08h
            ld   e,(hl)                 ; SZ(K)
            ld   a,d
            cp   e
            jp   nc,hs_n                ; PH>=SZ — потоплен
            ld   a,(bS)
            ld   d,a
            ld   a,e
            sub  d                      ; L=SZ(K)-S
            jp   m,hs_n
            jp   z,hs_n                 ; L<1
            ld   (bL),a
            sub  c                      ; T=L-C
            jp   m,hs_t1
            jp   nz,hs_t2
hs_t1:      ld   a,1                    ; T<1 -> T=1
hs_t2:      ld   d,a                    ; D=T
            ld   a,(bL)
            cp   b
            jp   c,hs_m
            ld   a,b                    ; M=min(L,B)
hs_m:       cp   d
            jp   c,hs_n                 ; M<T
            sub  d
            inc  a                      ; M-T+1
            ld   hl,(bSC)
            rst  08h
            ld   (bSC),hl
hs_n:       ld   a,(bK)
            inc  a
            ld   (bK),a
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
            call sc_gt_nb
            ret  nc
            ld   hl,(bSC)
            ld   (bNB),hl
            ld   a,(bX)
            ld   (bBX),a
            ld   a,(bY)
            ld   (bBY),a
            ret

; ---------------------------------------------------------------- 1902: поиск по вероятностям
L1902:      ld   a,(bTD)
            or   a
            jp   z,L1906
            xor  a                      ; TD=0: GA(A,B) для A,B=0..4
            ld   (bTD),a
            ld   (bA),a
L1902a:     xor  a
            ld   (bB),a
L1902b:     ld   hl,0
            ld   (bT),hl
            ld   a,1
            ld   (bK),a
L1902c:     ld   a,(bK)                 ; IF PH(K)>=SZ(K) THEN 1905
            ld   hl,ARR_PH
            add  a,a
            rst  08h
            ld   d,(hl)
            ld   a,(bK)
            ld   hl,ARR_SZ
            add  a,a
            rst  08h
            ld   e,(hl)
            ld   a,d
            cp   e
            jp   nc,L1905
            ld   a,e                    ; L=SZ(K): X=MIN(A,L-1): Y=MIN(B,L-1)
            ld   (bL),a
            dec  a
            ld   c,a
            ld   a,(bA)
            cp   c
            jp   c,L1903
            ld   a,c
L1903:      ld   b,a
            ld   a,(bB)
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
            rst  08h
            ld   (bT),hl
L1905:      ld   hl,bK
            inc  (hl)
            ld   a,(hl)
            cp   6
            jp   c,L1902c
            call ga_ab                  ; GA(A,B)=T
            ld   a,(bT)
            ld   (hl),a
            inc  hl
            ld   a,(bT+1)
            ld   (hl),a
            ld   hl,bB
            inc  (hl)
            ld   a,(hl)
            cp   5
            jp   c,L1902b
            ld   hl,bA
            inc  (hl)
            ld   a,(hl)
            cp   5
            jp   c,L1902a
L1906:      ld   hl,-1
            ld   (bNB),hl
            ld   a,1
            ld   (bSM),a
L1906a:     ld   a,100                  ; P=INT(RND(1)*100): I=P\10: J=P MOD 10
            call rnd_n
            ld   (bP),a
            ld   b,0
L1906b:     sub  10
            jp   c,L1906c
            inc  b
            jp   L1906b
L1906c:     add  a,10
            ld   (bJ),a
            xor  a
            ld   (bJ+1),a
            ld   (bI+1),a
            ld   a,b
            ld   (bI),a
            ld   a,(bJ)                 ; IF PM(I,J)<>0 OR BZ(I,J)=3 THEN 1919
            ld   e,a
            ld   a,(bI)
            call open_xy
            jp   nz,L1919
L1907:      xor  a                      ; A = свободных влево (по X)
            ld   (bA),a
            ld   a,(bI)
            dec  a
            ld   (bU),a
L1908:      ld   a,(bU)
            or   a
            jp   m,L1909
            ld   a,(bA)
            cp   4
            jp   nc,L1909
            ld   a,(bJ)
            ld   e,a
            ld   a,(bU)
            call open_xy
            jp   nz,L1909
            ld   hl,bA
            inc  (hl)
            ld   hl,bU
            dec  (hl)
            jp   L1908
L1909:      xor  a                      ; B = вправо
            ld   (bB),a
            ld   a,(bI)
            inc  a
            ld   (bU),a
L1910:      ld   a,(bU)
            cp   10
            jp   nc,L1911
            ld   a,(bB)
            cp   4
            jp   nc,L1911
            ld   a,(bJ)
            ld   e,a
            ld   a,(bU)
            call open_xy
            jp   nz,L1911
            ld   hl,bB
            inc  (hl)
            ld   hl,bU
            inc  (hl)
            jp   L1910
L1911:      call ga_ab                  ; SC=GA(A,B): A=0: V=J-1
            ld   a,(hl)
            inc  hl
            ld   h,(hl)
            ld   l,a
            ld   (bSC),hl
            xor  a
            ld   (bA),a
            ld   a,(bJ)
            dec  a
            ld   (bV),a
L1912:      ld   a,(bV)
            or   a
            jp   m,L1913
            ld   a,(bA)
            cp   4
            jp   nc,L1913
            ld   a,(bV)
            ld   e,a
            ld   a,(bI)
            call open_xy
            jp   nz,L1913
            ld   hl,bA
            inc  (hl)
            ld   hl,bV
            dec  (hl)
            jp   L1912
L1913:      xor  a
            ld   (bB),a
            ld   a,(bJ)
            inc  a
            ld   (bV),a
L1914:      ld   a,(bV)
            cp   10
            jp   nc,L1915
            ld   a,(bB)
            cp   4
            jp   nc,L1915
            ld   a,(bV)
            ld   e,a
            ld   a,(bI)
            call open_xy
            jp   nz,L1915
            ld   hl,bB
            inc  (hl)
            ld   hl,bV
            inc  (hl)
            jp   L1914
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
            ld   a,(bJ)                 ; SC=0: здесь корабля быть не может — буй
            ld   e,a
            ld   a,(bI)
            ld   bc,ARR_BZ
            call w10
            ld   (hl),3
            inc  hl
            ld   (hl),0
            xor  a
            ld   (bSD),a
            ld   a,(bI)
            ld   (bC),a
            ld   a,(bJ)
            ld   (bR),a
            ld   a,160
            ld   (bQ),a
            call L1105
            jp   L1919
L1916:      ld   a,10
            call sc_mul_rnd
            call sc_gt_nb
            jp   nc,L1919
            ld   hl,(bSC)
            ld   (bNB),hl
            ld   a,(bI)
            ld   (bBX),a
            ld   a,(bJ)
            ld   (bBY),a
L1919:      ld   hl,bSM
            inc  (hl)
            ld   a,(hl)
            cp   21
            jp   c,L1906a
            ld   a,(bNB+1)
            or   a
            ret  p
L1920:      ld   b,0                    ; первая открытая клетка
L1920a:     ld   c,0
L1920b:     push bc
            ld   a,b
            ld   e,c
            call open_xy
            pop  bc
            jp   nz,L1921
            ld   a,b
            ld   (bBX),a
            ld   a,c
            ld   (bBY),a
            ld   hl,0
            ld   (bNB),hl
            jp   L1921x
L1921:      inc  c
            ld   a,c
            cp   10
            jp   c,L1920b
            inc  b
            ld   a,b
            cp   10
            jp   c,L1920a
L1921x:     ld   hl,10
            ld   (bI),hl
            ld   (bJ),hl
            ld   a,(bNB+1)
            or   a
            ret  p
L1922:      ld   a,10                   ; случайная нестрелянная
            call rnd_n
            ld   (bBX),a
            ld   a,10
            call rnd_n
            ld   (bBY),a
            ld   e,a
            ld   a,(bBX)
            call pm_xy
            or   a
            jp   nz,L1922
L1924:      ret

; HL = &GA(A,B) = ARR_GA + (A + 8B)*2
ga_ab:      ld   a,(bB)
            add  a,a
            add  a,a
            add  a,a
            ld   b,a
            ld   a,(bA)
            add  a,b
            add  a,a
            ld   hl,ARR_GA
            jp   add_a_hl

; ---------------------------------------------------------------- 1925: буи по диагоналям попадания
L1925:      ld   a,(bFX)                ; FOR X=FX-1 TO FX+1 STEP 2
            dec  a
            ld   (bX),a
L1925a:     ld   a,(bFY)                ; FOR Y=FY-1 TO FY+1 STEP 2
            dec  a
            ld   (bY),a
L1925b:     call buoy_xy
            ld   a,(bFY)
            inc  a
            ld   b,a
            ld   a,(bY)
            add  a,2
            ld   (bY),a
            cp   b
            jp   z,L1925b
            jp   c,L1925b
            ld   a,(bFX)
            inc  a
            ld   b,a
            ld   a,(bX)
            add  a,2
            ld   (bX),a
            cp   b
            jp   z,L1925a
            jp   c,L1925a
            ret
; IF 0<=X<=9 AND 0<=Y<=9 THEN IF PM(X,Y)=0 AND BZ(X,Y)<>3 THEN BZ(X,Y)=3: SD=0: C=X: R=Y: Q=176: GOSUB 1105
; (X, Y — младшие байты, со знаком)
buoy_xy:    ld   a,(bX)
            cp   10
            ret  nc
            ld   a,(bY)
            cp   10
            ret  nc
            ld   e,a
            ld   a,(bX)
            call open_xy
            ret  nz
            ld   a,(bY)
            ld   e,a
            ld   a,(bX)
            ld   bc,ARR_BZ
            call w10
            ld   (hl),3
            inc  hl
            ld   (hl),0
            xor  a
            ld   (bSD),a
            ld   a,(bX)
            ld   (bC),a
            ld   a,(bY)
            ld   (bR),a
            ld   a,176
            ld   (bQ),a
            jp   L1105

; ---------------------------------------------------------------- 1930: буи вокруг потопленного
L1930:      xor  a
            ld   (bI),a
L1930a:     call pxy_off                ; PX(SH,I), PY(SH,I)
            ld   de,ARR_PX
            add  hl,de
            ld   a,(hl)
            ld   (rp_tmp),a
            ld   de,60
            add  hl,de
            ld   a,(hl)
            ld   (rp_tmp+1),a
            ld   a,(rp_tmp)             ; FOR X=PX-1 TO PX+1
            dec  a
            ld   (bX),a
L1930b:     ld   a,(rp_tmp+1)           ; FOR Y=PY-1 TO PY+1
            dec  a
            ld   (bY),a
L1930c:     call buoy_xy
            ld   a,(rp_tmp+1)
            ld   b,a
            ld   a,(bY)
            inc  a
            ld   (bY),a
            dec  a
            cp   b
            jp   m,L1930c
            jp   z,L1930c
            ld   a,(rp_tmp)
            ld   b,a
            ld   a,(bX)
            inc  a
            ld   (bX),a
            dec  a
            cp   b
            jp   m,L1930b
            jp   z,L1930b
            ld   hl,bI
            inc  (hl)
            call sz_sh
            ld   a,(bI)
            cp   c
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
            xor  a
            ld   (bTM),a
            ld   (bI),a
L1941a:     xor  a
            ld   (bJ),a
L1941b:     ld   a,(bJ)                 ; IF PM(I,J)<>0 THEN 1946
            ld   e,a
            ld   a,(bI)
            call pm_xy
            or   a
            jp   nz,L1946
L1942:      xor  a                      ; T=1, если по соседству попадание (PM>1)
            ld   (bT),a
            ld   a,(bI)
            or   a
            jp   z,L1943
            dec  a
            call nb_hit
L1943:      ld   a,(bI)
            cp   9
            jp   z,L1944
            inc  a
            call nb_hit
L1944:      ld   a,(bJ)
            or   a
            jp   z,L1945
            dec  a
            ld   e,a
            ld   a,(bI)
            call nb_hit2
L1945:      ld   a,(bJ)
            cp   9
            jp   z,L1946
            inc  a
            ld   e,a
            ld   a,(bI)
            call nb_hit2
L1946:      ld   a,(bT)                 ; IF T=1 THEN T=0: TM=1: X=I: Y=J: GOSUB 1960: IF SC>NB ...
            cp   1
            jp   nz,L1947
            xor  a
            ld   (bT),a
            inc  a
            ld   (bTM),a
            ld   a,(bI)
            call st_x
            ld   a,(bJ)
            call st_y
            call L1960
            call sc_gt_nb
            jp   nc,L1947
            ld   hl,(bSC)
            ld   (bNB),hl
            ld   a,(bI)
            ld   (bBX),a
            ld   a,(bJ)
            ld   (bBY),a
L1947:      ld   hl,bJ
            inc  (hl)
            ld   a,(hl)
            cp   10
            jp   c,L1941b
            ld   hl,bI
            inc  (hl)
            ld   a,(hl)
            cp   10
            jp   c,L1941a
            ld   a,(bTM)
            cp   1
            ret  z
L1948:      ld   a,1
            ld   (bSM),a
L1948a:     ld   a,100
            call rnd_n
            ld   (bP),a
            ld   b,0
L1948b:     sub  10
            jp   c,L1948c
            inc  b
            jp   L1948b
L1948c:     add  a,10
            call st_y                   ; Y=P MOD 10
            ld   a,b
            call st_x                   ; X=P\10
            ld   a,(bY)                 ; IF PM(X,Y)<>0 OR ((X+Y+PA) AND 1)=1 THEN 1950
            ld   e,a
            ld   a,(bX)
            call pm_xy
            or   a
            jp   nz,L1950
            ld   a,(bPA)
            ld   b,a
            ld   a,(bX)
            add  a,b
            ld   b,a
            ld   a,(bY)
            add  a,b
            and  1
            jp   nz,L1950
L1949:      call L1960
            call sc_gt_nb
            jp   nc,L1950
            ld   hl,(bSC)
            ld   (bNB),hl
            ld   a,(bX)
            ld   (bBX),a
            ld   a,(bY)
            ld   (bBY),a
L1950:      ld   hl,bSM
            inc  (hl)
            ld   a,(hl)
            cp   21
            jp   c,L1948a
            ld   a,(bNB+1)
            or   a
            ret  p
L1951:      ld   b,0                    ; первая нестрелянная
L1951a:     ld   c,0
L1951b:     push bc
            ld   a,b
            ld   e,c
            call pm_xy
            pop  bc
            or   a
            jp   nz,L1952
            ld   a,b
            ld   (bBX),a
            ld   a,c
            ld   (bBY),a
            jp   L1952x
L1952:      inc  c
            ld   a,c
            cp   10
            jp   c,L1951b
            inc  b
            ld   a,b
            cp   10
            jp   c,L1951a
L1952x:     ld   hl,10
            ld   (bI),hl
            ld   (bJ),hl
            ret
; T=1, если PM(A,J)>1 / PM(A,E)>1
nb_hit:     ld   e,a
            ld   a,(bJ)
            ld   d,a
            ld   a,e
            ld   e,d
nb_hit2:    call pm_xy
            cp   2
            ret  c
            ld   a,1
            ld   (bT),a
            ret

; 1960: SC клетки (X,Y) по сериям попаданий (веса GB(7,n) = 6^n)
L1960:      ld   hl,0
            ld   (bSC),hl
            xor  a
            ld   (bD),a
L1960a:     ld   a,(bD)                 ; U1=1-D: V1=D: A=0: C=X-U1: R=Y-V1: GA(0,0)=0
            ld   b,a
            ld   a,1
            sub  b
            ld   (bU1),a
            ld   a,b
            ld   (bV1),a
            xor  a
            ld   (bA),a
            ld   hl,0
            ld   (ARR_GA),hl
            ld   a,(bU1)
            ld   b,a
            ld   a,(bX)
            sub  b
            ld   (bC),a
            ld   a,(bV1)
            ld   b,a
            ld   a,(bY)
            sub  b
            ld   (bR),a
L1961:      ld   a,(bA)                 ; IF A<4 AND C>=0 AND R>=0 THEN IF PM(C,R)<>1 THEN ...
            cp   4
            jp   nc,L1962
            ld   a,(bC)
            or   a
            jp   m,L1962
            ld   a,(bR)
            or   a
            jp   m,L1962
            ld   e,a
            ld   a,(bC)
            call pm_xy
            cp   1
            jp   z,L1962
            ld   c,0                    ; -(PM(C,R)>1)
            jp   c,L1961a               ; PM=0
            inc  c
L1961a:     ld   a,(bA)                 ; GA(0,A+1)=GA(0,A)+c
            add  a,a
            add  a,a
            add  a,a
            add  a,a
            ld   hl,ARR_GA
            rst  08h
            ld   a,(hl)
            add  a,c
            ld   de,16
            add  hl,de
            ld   (hl),a
            inc  hl
            ld   (hl),0
            ld   hl,bA
            inc  (hl)
            ld   a,(bU1)
            ld   b,a
            ld   a,(bC)
            sub  b
            ld   (bC),a
            ld   a,(bV1)
            ld   b,a
            ld   a,(bR)
            sub  b
            ld   (bR),a
            jp   L1961
L1962:      xor  a                      ; B=0: C=X+U1: R=Y+V1: GA(1,0)=0
            ld   (bB),a
            ld   hl,0
            ld   (ARR_GA+2),hl
            ld   a,(bU1)
            ld   b,a
            ld   a,(bX)
            add  a,b
            ld   (bC),a
            ld   a,(bV1)
            ld   b,a
            ld   a,(bY)
            add  a,b
            ld   (bR),a
L1963:      ld   a,(bB)
            cp   4
            jp   nc,L1964
            ld   a,(bC)
            cp   10
            jp   nc,L1964
            ld   a,(bR)
            cp   10
            jp   nc,L1964
            ld   e,a
            ld   a,(bC)
            call pm_xy
            cp   1
            jp   z,L1964
            ld   c,0
            jp   c,L1963a
            inc  c
L1963a:     ld   a,(bB)                 ; GA(1,B+1)=GA(1,B)+c
            add  a,a
            add  a,a
            add  a,a
            add  a,a
            ld   hl,ARR_GA+2
            rst  08h
            ld   a,(hl)
            add  a,c
            ld   de,16
            add  hl,de
            ld   (hl),a
            inc  hl
            ld   (hl),0
            ld   hl,bB
            inc  (hl)
            ld   a,(bU1)
            ld   b,a
            ld   a,(bC)
            add  a,b
            ld   (bC),a
            ld   a,(bV1)
            ld   b,a
            ld   a,(bR)
            add  a,b
            ld   (bR),a
            jp   L1963
L1964:      ld   a,1                    ; FOR K=1 TO 5: L=SZ(K): FOR M=0 TO L-1: N=L-1-M
            ld   (bK),a
L1964a:     ld   a,(bK)
            ld   hl,ARR_SZ
            add  a,a
            rst  08h
            ld   a,(hl)
            ld   (bL),a
            xor  a
            ld   (bM),a
            ld   (bM+1),a
L1964b:     ld   a,(bM)
            ld   b,a
            ld   a,(bL)
            dec  a
            sub  b
            ld   (bN),a                 ; N=L-1-M
            ld   a,(bA)                 ; IF M<=A AND N<=B THEN SC=SC+GB(7,GA(0,M)+GA(1,N))
            cp   b
            jp   c,L1965
            ld   a,(bB)
            ld   c,a
            ld   a,(bN)
            cp   c
            jp   z,L1964c
            jp   nc,L1965
L1964c:     ld   a,b                    ; GA(0,M)
            add  a,a
            add  a,a
            add  a,a
            add  a,a
            ld   hl,ARR_GA
            rst  08h
            ld   c,(hl)
            ld   a,(bN)                 ; + GA(1,N)
            add  a,a
            add  a,a
            add  a,a
            add  a,a
            ld   hl,ARR_GA+2
            rst  08h
            ld   a,(hl)
            add  a,c                    ; индекс n
            add  a,a
            add  a,a
            add  a,a
            add  a,a                    ; n*16
            ld   hl,ARR_GB+14
            rst  08h
            ld   e,(hl)
            inc  hl
            ld   d,(hl)
            ld   hl,(bSC)
            add  hl,de
            ld   (bSC),hl
L1965:      ld   hl,bM
            inc  (hl)
            ld   a,(bL)
            ld   b,a
            ld   a,(hl)
            cp   b
            jp   c,L1964b
            ld   hl,bK
            inc  (hl)
            ld   a,(hl)
            cp   6
            jp   c,L1964a
            ld   hl,bD
            inc  (hl)
            ld   a,(hl)
            cp   2
            jp   c,L1960a
            ld   a,8                    ; SC=SC*8+INT(RND(1)*8)
            jp   sc_mul_rnd

; ---------------------------------------------------------------- 1967: ANKA (детский)
L1967:      ld   a,1
            ld   (bHW),a
            xor  a
            ld   (bI),a
L1967a:     xor  a
            ld   (bJ),a
L1967b:     ld   a,(bJ)                 ; IF (PM(I,J) AND 3)<>2 THEN 1972
            ld   e,a
            ld   a,(bI)
            call pm_xy
            and  3
            cp   2
            jp   nz,L1972
L1968:      ld   a,4                    ; DA=INT(RND(1)*4): FOR T=0 TO 3: D=(DA+T) AND 3
            call rnd_n
            ld   (bDA),a
            xor  a
            ld   (bT),a
L1968a:     ld   a,(bDA)
            ld   b,a
            ld   a,(bT)
            add  a,b
            and  3
            ld   (bD),a
            call L1890
            ld   a,(bU1)                ; X=I+U1: Y=J+V1
            ld   b,a
            ld   a,(bI)
            add  a,b
            call st_x
            ld   a,(bV1)
            ld   b,a
            ld   a,(bJ)
            add  a,b
            call st_y
            ld   a,(bX)                 ; вне поля -> 1971
            cp   10
            jp   nc,L1971
            ld   a,(bY)
            cp   10
            jp   nc,L1971
L1969:      ld   e,a                    ; IF PM(X,Y)=0 THEN BX=X: BY=Y: HW=0: T=3: I=9: J=9
            ld   a,(bX)
            call pm_xy
            or   a
            jp   nz,L1971
            ld   a,(bX)
            ld   (bBX),a
            ld   a,(bY)
            ld   (bBY),a
            xor  a
            ld   (bHW),a
            ld   a,3
            ld   (bT),a
            ld   a,9
            ld   (bI),a
            ld   (bJ),a
L1971:      ld   hl,bT
            inc  (hl)
            ld   a,(hl)
            cp   4
            jp   c,L1968a
L1972:      ld   hl,bJ
            inc  (hl)
            ld   a,(hl)
            cp   10
            jp   c,L1967b
            ld   hl,bI
            inc  (hl)
            ld   a,(hl)
            cp   10
            jp   c,L1967a
            ld   a,(bHW)
            or   a
            ret  z
L1973:      ld   a,10
            call rnd_n
            ld   (bBX),a
            ld   a,10
            call rnd_n
            ld   (bBY),a
            ld   e,a
            ld   a,(bBX)
            call pm_xy
            or   a
            jp   nz,L1973
            ret
