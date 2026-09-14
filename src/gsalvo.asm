; ============================================================================
; gsalvo.asm — перевод IRONCLAD.BAS: сборки SALVO/SALVOP/BARRAGE (BD=1),
; строки 3798..3893 и 4000..4339. POKE/PEEK/USR в движок — через символы движка.
; ============================================================================

; ---------------------------------------------------------------- 3798: итог своего залпа
L3798:      ld   a,(bSJ)
            or   a
            jp   z,L3800
L3799:      xor  a                      ; FOR N=0 TO SJ-1: SH=SQ(N): GOSUB 3858: GOSUB 2622
            ld   (bN),a
L3799a:     ld   a,(bN)
            ld   hl,ARR_SQ
            rst  00h
            ld   a,(hl)
            ld   (bSH),a
            call L3858
            call L2622
            ld   hl,bN
            inc  (hl)
            ld   a,(bSJ)
            cp   (hl)
            jp   nz,L3799a
L3800:      ld   a,(bSK)                ; IF SK>0: FOR N=0 TO NF-1: P=GT(N): U=P\10: V=P MOD 10: GOSUB 3808
            or   a
            jp   z,L3801
            xor  a
            ld   (bN),a
L3800a:     ld   a,(bN)
            ld   hl,ARR_GT
            rst  00h
            ld   a,(hl)
            ld   (bP),a
            call div10
            ld   (bU),a
            ld   a,b
            ld   (bV),a
            call L3808
            ld   hl,bN
            inc  (hl)
            ld   a,(bNF)
            cp   (hl)
            jp   nz,L3800a
L3801:      ld   a,(bSL)                ; NV=SL: GOSUB 3810
            ld   (bNV),a
            call L3810
            ld   hl,s_hits              ; "HITS:"+STR$(SK)+"/"+MID$(STR$(NF),2)+" ["+S1$+"]"
            rst  28h
            ld   a,(bSK)
            ld   l,a
            ld   h,0
            call ms_catnum
            ld   a,'/'
            call ms_catc
            ld   a,(bNF)
            call ms_catd
            ld   hl,s_lbr
            call ms_cat
            ld   hl,sS1
            call ms_cat
            ld   a,']'
            call ms_catc
            ld   hl,sSS                 ; IF SS$<>"" THEN MS$=MS$+" SANK: "+LEFT$(SS$,LEN(SS$)-1)
            ld   de,9                   ; сокращение: LEFT$(MS$,9)+MID$(MS$,14)
            call salvo_sank
L3803:      call L1305
            ld   a,(bSK)
            or   a
            call nz,L3820
L3804:      ld   a,(bTT)
            ld   b,a
            ld   a,(bTE)
            cp   b
            jp   nc,L3805
            ld   hl,s_press_space
            rst  28h
            call L1315
            xor  a
            ld   (bKQ),a
L3805:      call inkey                  ; IF INKEY$<>"" THEN 3805
            jp   nz,L3805
            ret

; MS$ += " SANK: " + SS$ без последней запятой; если длиннее 31 — вырезать 4 знака
; HL = SS$/ES$, D = с какого знака (0-базно) вырезать: E=9 -> LEFT$(,9)+MID$(,14); E=15 -> LEFT$(,15)+MID$(,20)
salvo_sank:
            ld   a,(hl)
            or   a
            ret  z
            push de
            push hl
            ld   hl,s_sank
            call ms_cat
            pop  hl
            call ms_cat
            ld   de,sMS                 ; убрать завершающую запятую
            call str_end
            dec  de
            xor  a
            ld   (de),a
            pop  de
            ld   hl,sMS
            call str_len
            cp   32
            ret  c
            ld   a,e                    ; сдвинуть хвост с позиции E+4 на E
            ld   hl,sMS
            rst  00h
            ld   d,h
            ld   e,l
            inc  hl
            inc  hl
            inc  hl
            inc  hl
            jp   str_copy

; A = P -> A = P\10, B = P MOD 10
div10:      ld   b,0
d10_1:      cp   10
            jp   c,d10_2
            sub  10
            inc  b
            jp   d10_1
d10_2:      ld   c,a
            ld   a,b
            ld   b,c
            ret

; 3808: IF CM(U,V)>32 THEN RETURN ELSE CM(U,V)=CM(U,V)+32: SD=1: C=U: R=V: GOSUB 1105
L3808:      ld   a,(bV)
            ld   e,a
            ld   a,(bU)
            ld   bc,ARR_CM
            call w10
            ld   e,(hl)
            inc  hl
            ld   a,(hl)
            dec  hl
            or   a
            jp   m,L3808a
            ld   a,e
            cp   33
            ret  nc
L3808a:     ld   a,e
            add  a,32
            ld   (hl),a
            inc  hl
            ld   a,(hl)
            adc  a,0
            ld   (hl),a
            ld   a,1
            ld   (bSD),a
            ld   a,(bU)
            ld   (bC),a
            ld   a,(bV)
            ld   (bR),a
            jp   L1105

; 3810: NV=((NV-1) AND 31)+1: S1$=CHR$(48+NV): IF NV>9 THEN S1$=CHR$(55+NV)
L3810:      ld   a,(bNV)
            dec  a
            and  31
            inc  a
            ld   (bNV),a
            ld   b,48
            cp   10
            jp   c,L3810a
            ld   b,55
L3810a:     add  a,b
            ld   (sS1),a
            xor  a
            ld   (sS1+1),a
            ret

; 3820: панель — корабли противника (SALVO/BARRAGE; SALVOP -> 4158)
L3820:      ld   a,(bNK)
            cp   8
            jp   nc,L4158
            ld   a,1
            ld   (bI),a
L3821:      ld   a,(bI)                 ; LINE(190,37+(I-1)*PZ)-(255,44+(I-1)*10),1,BF
            xor  a
            ld   (bY0),a
            ld   a,(bI)
            call y_i
            ld   c,a
            ld   (bYP),a
            ld   a,(bI)
            dec  a
            add  a,a
            ld   b,a
            add  a,a
            add  a,a
            add  a,b
            add  a,44
            ld   e,a
            ld   b,190
            ld   d,255
            ld   a,1
            rst  20h
L3822:      ld   a,(bI)                 ; SF: QH(I)>=SZ(I)
            ld   hl,ARR_QH
            rst  00h
            ld   b,(hl)
            call sz_i
            ld   a,15
            ld   (bCL),a
            ld   a,b
            cp   c
            jp   c,L3824
            ld   a,8
            ld   (bCL),a
L3824:      ld   a,(bCL)                ; COLOR CL: PSET(190,y): PRINT LEFT$(N$(I),3)
            ld   (gfx_fg),a
            ld   a,(bYP)
            ld   c,a
            ld   b,190
            ld   a,(bCL)
            rst  10h
            ld   a,(bI)
            call n_a
            ld   de,sT
            call cat3
            ld   hl,sT
            rst  18h
L3825:      ld   hl,ARR_QH              ; квадратики / номера залпов HS(I,J-1)
            ld   de,ARR_HS
            call hs_row
            ld   hl,bI
            inc  (hl)
            ld   a,(bZT)
            cp   (hl)
            jp   nc,L3821
L3830:      ld   a,15
            ld   (gfx_fg),a
            ret

; 3825..3829 для корабля bI, строка bYP, x0=216 (шаг 8)
hs_row:     ld   a,(bI)
            rst  00h
            ld   a,(hl)
            ld   (hr_q),a               ; QH(I)
            ld   a,1
            ld   (hr_j),a
hr_1:       ld   a,(hr_j)
            dec  a
            add  a,a
            add  a,a
            add  a,a
            add  a,216
            ld   (hr_x),a
            ld   a,(hr_q)
            ld   b,a
            ld   a,(hr_j)
            cp   b
            jp   z,hr_hit
            jp   c,hr_hit
            ld   a,(hr_x)               ; LINE(x,y)-(x+4,y+6),9,BF
            ld   b,a
            add  a,4
            ld   d,a
            ld   a,(bYP)
            ld   c,a
            add  a,6
            ld   e,a
            ld   a,9
            rst  20h
            jp   hr_n
hr_hit:     ld   a,(hr_j)               ; NV=HS(I,J-1): GOSUB 3810: COLOR 8: PSET(x,y): PRINT S1$
            dec  a
            add  a,a
            add  a,a
            ld   b,a
            add  a,a
            add  a,b
            ld   b,a
            ld   a,(bI)
            add  a,b
            ld   hl,ARR_HS
            rst  00h
            ld   a,(hl)
            ld   (bNV),a
            call L3810
            call red_s1
hr_n:       ld   hl,hr_j
            inc  (hl)
            call sz_i
            ld   a,(hr_j)
            dec  a
            cp   c
            jp   c,hr_1
            ret
; COLOR 8: PSET(hr_x,bYP): PRINT S1$
red_s1:     ld   a,8
            ld   (gfx_fg),a
            ld   a,(hr_x)
            ld   b,a
            ld   a,(bYP)
            ld   c,a
            ld   a,8
            rst  10h
            ld   hl,sS1
            rst  18h
            ld   a,15
            ld   (gfx_fg),a
            ret

; ---------------------------------------------------------------- 3840: залп противника
L3840:      xor  a
            ld   (bEK),a
            ld   (sES),a
            ld   hl,bSN
            inc  (hl)
            call ms_clear
            call L1305
            ld   a,(bFP)
            cp   1
            jp   nz,L3843
            xor  a
            ld   (bFP),a
            ld   hl,s_reviews
            rst  28h
            call L1315
            call L4301
L3843:      call L4000
            ld   hl,ARR_HK              ; FOR K=1 TO ZT: HK(K)=0
            ld   de,16
            call memzero
L3844:      xor  a                      ; FOR NC=0 TO NS-1: BX=TX(NC): BY=TY(NC): GOSUB 910
            ld   (bNC),a
L3844a:     ld   a,(bNC)
            add  a,a
            ld   hl,ARR_TX
            rst  00h
            ld   a,(hl)
            ld   (bBX),a
            ld   a,(bNC)
            add  a,a
            ld   hl,ARR_TY
            rst  00h
            ld   a,(hl)
            ld   (bBY),a
            call L910
            ld   a,(bTT)                ; IF TP>=TT THEN NC=NS-1
            ld   b,a
            ld   a,(bTP)
            cp   b
            jp   c,L3846
            ld   a,(bNS)
            dec  a
            ld   (bNC),a
L3846:      ld   hl,bNC
            inc  (hl)
            ld   a,(bNS)
            cp   (hl)
            jp   z,L3847
            jp   nc,L3844a
L3847:      ld   a,(bTT)
            ld   b,a
            ld   a,(bTP)
            cp   b
            jp   nc,L3853
            ld   a,1
            ld   (bFP),a
L3853:      ld   a,(bSN)                ; NV=SN: "ENEMY HITS:"+STR$(EK)+"/"+NS+" ["+S1$+"]"
            ld   (bNV),a
            call L3810
            ld   hl,s_enemy_hits
            rst  28h
            ld   a,(bEK)
            ld   l,a
            ld   h,0
            call ms_catnum
            ld   a,'/'
            call ms_catc
            ld   a,(bNS)
            call ms_catd
            ld   hl,s_lbr
            call ms_cat
            ld   hl,sS1
            call ms_cat
            ld   a,']'
            call ms_catc
            ld   hl,sES
            ld   de,15
            call salvo_sank
L3854:      call L1315
            ld   a,(bTT)
            ld   b,a
            ld   a,(bTP)
            cp   b
            ret  nc
L3855:      ld   hl,s_press_space
            rst  28h
            call L1305
            xor  a
            ld   (bKQ),a
L3856:      call inkey
            jp   nz,L3856
L3857:      call getkey                 ; TAB — листать страницы (без 1473), пробел — дальше
            ld   (bK_),a
            cp   9
            jp   nz,L3857a
            ld   a,(bDP)
            xor  1
            ld   (bDP),a
            call page_show
            jp   L3857
L3857a:     cp   ' '
            jp   nz,L3857
            call ms_clear
            jp   L1305
; 3858: SS$=SS$+LEFT$(N$(SH),3)+","
L3858:      ld   de,sSS
            call str_end
            call n_sh
            call cat3
            ld   a,','
            ld   (de),a
            inc  de
            xor  a
            ld   (de),a
            ret

; 3870: выстрел игрока в залпе
L3870:      call cm_cxcy                ; CM(CX,CY)=SL
            ld   a,(bSL)
            ld   (hl),a
            inc  hl
            ld   (hl),0
            ld   a,1
            ld   (bSD),a
            call cr_cxcy
            call L1105
L3872:      ld   a,(bSH)
            or   a
            jp   nz,L3874
            xor  a
            ld   (bHW),a
            ret
L3874:      ld   a,1
            ld   (bHW),a
            call qh_sh                  ; QH(SH)=QH(SH)+1
            inc  (hl)
            ld   b,(hl)
            ld   hl,bTE
            inc  (hl)
            ld   hl,bSK
            inc  (hl)
            ld   a,b                    ; HS(SH,QH(SH)-1)=SL
            dec  a
            add  a,a
            add  a,a
            ld   c,a
            add  a,a
            add  a,c
            ld   c,a
            ld   a,(bSH)
            add  a,c
            ld   hl,ARR_HS
            rst  00h
            ld   a,(bSL)
            ld   (hl),a
L3876:      call qh_sh
            ld   b,(hl)
            call sz_sh
            ld   a,b
            cp   c
            ret  c
L3878:      ld   a,(bSJ)                ; SJ=SJ+1: SQ(SJ-1)=SH
            ld   hl,ARR_SQ
            rst  00h
            ld   a,(bSH)
            ld   (hl),a
            ld   hl,bSJ
            inc  (hl)
            ret

; 3880: отмена выстрела залпа (U)
L3880:      ld   a,(bNC)
            or   a
            ret  z
L3881:      dec  a
            ld   (bNC),a
            ld   hl,ARR_GT
            rst  00h
            ld   a,(hl)
            ld   (bP),a
            call div10
            ld   (bCX),a
            ld   a,b
            ld   (bCY),a
            call cs_cxcy
            ld   a,(hl)
            and  15
            ld   (bSH),a
            call cm_cxcy
            ld   (hl),0
            inc  hl
            ld   (hl),0
            ld   a,1
            ld   (bSD),a
            call cr_cxcy
            call L1105
L3882:      ld   a,(bSH)
            or   a
            jp   z,L3883
            call qh_sh
            dec  (hl)
            ld   b,(hl)
            ld   hl,bTE
            dec  (hl)
            ld   hl,bSK
            dec  (hl)
            ld   a,b                    ; HS(SH,QH(SH))=0
            add  a,a
            add  a,a
            ld   c,a
            add  a,a
            add  a,c
            ld   c,a
            ld   a,(bSH)
            add  a,c
            ld   hl,ARR_HS
            rst  00h
            ld   (hl),0
            call sz_sh                  ; IF QH(SH)=SZ(SH)-1 THEN SJ=SJ-1
            dec  c
            ld   a,b
            cp   c
            jp   nz,L3883
            ld   hl,bSJ
            dec  (hl)
L3883:      ld   hl,s_undo
            rst  28h
            ld   a,(bCX)
            add  a,65
            call ms_catc
            ld   a,(bCY)
            inc  a
            call ms_catd
            call L1305
            jp   L1473

; 3884: панель — свой корабль SH (SALVO/BARRAGE; SALVOP -> 4162)
L3884:      ld   a,(bNK)
            cp   8
            jp   nc,L4162
            ld   a,(bSH)                ; YP=107+(SH-1)*10
            dec  a
            add  a,a
            ld   b,a
            add  a,a
            add  a,a
            add  a,b
            add  a,107
            ld   (bYP),a
L3885:      ld   c,a                    ; LINE(190,YP)-(255,YP+7),1,BF
            add  a,7
            ld   e,a
            ld   b,190
            ld   d,255
            ld   a,1
            rst  20h
            call ph_sh                  ; SF: PH(SH)>=SZ(SH)
            ld   b,c
            call sz_sh
            ld   a,15
            ld   (bCL),a
            ld   a,b
            cp   c
            jp   c,L3887
            ld   a,8
            ld   (bCL),a
L3887:      ld   a,(bCL)
            ld   (gfx_fg),a
            ld   a,(bYP)
            ld   c,a
            ld   b,190
            ld   a,(bCL)
            rst  10h
            call n_sh
            ld   de,sT
            call cat3
            ld   hl,sT
            rst  18h
            ld   a,216
            ld   (hr_x0),a
            call pm_row
            ld   a,15
            ld   (gfx_fg),a
            ret

; 3888..3891 / 4163: FOR J=1 TO SZ(SH): P=PM(PX(SH,J-1),PY(SH,J-1)):
;   IF (P AND 3)<2 -> квадратик 9, иначе NV=P\4 -> номер красным. x = hr_x0 + (J-1)*8
pm_row:     ld   a,1
            ld   (hr_j),a
pr_1:       ld   a,(hr_j)
            dec  a
            ld   b,a
            add  a,a
            add  a,a
            add  a,a
            ld   c,a
            ld   a,(hr_x0)
            add  a,c
            ld   (hr_x),a
            ld   a,b                    ; PX(SH,J-1), PY(SH,J-1)
            add  a,a
            add  a,a
            ld   c,a
            add  a,a
            add  a,c
            ld   c,a
            ld   a,(bSH)
            add  a,c
            ld   hl,ARR_PX
            rst  00h
            ld   a,(hl)
            ld   de,60
            add  hl,de
            ld   e,(hl)
            call pm_xy
            ld   (bP),a
            and  3
            cp   2
            jp   nc,pr_hit
            ld   a,(hr_x)
            ld   b,a
            add  a,4
            ld   d,a
            ld   a,(bYP)
            ld   c,a
            add  a,6
            ld   e,a
            ld   a,9
            rst  20h
            jp   pr_n
pr_hit:     ld   a,(bP)                 ; NV=P\4
            rrca
            rrca
            and  3Fh
            ld   (bNV),a
            call L3810
            call red_s1
pr_n:       ld   hl,hr_j
            inc  (hl)
            call sz_sh
            ld   a,(hr_j)
            dec  a
            cp   c
            jp   c,pr_1
            ret

; ---------------------------------------------------------------- 4000: ИИ залпа (BASIC-часть)
L4000:      ld   a,(bSN)
            cp   3
            jp   c,L4093
L4001:      xor  a                      ; KM=1, если есть раненый (0<PH<SZ) среди 1..ZT
            ld   (bKM),a
            ld   a,1
            ld   (bK),a
L4001a:     call k_ph_sz                ; B = PH(K), C = SZ(K)
            ld   a,b
            or   a
            jp   z,L4002
            cp   c
            jp   nc,L4002
            ld   a,1
            ld   (bKM),a
            jp   L4002x
L4002:      ld   hl,bK
            inc  (hl)
            ld   a,(bZT)
            cp   (hl)
            jp   nc,L4001a
L4002x:     ld   a,(bKM)
            or   a
            jp   nz,L4002b
            ld   hl,s_probes
            rst  28h
            call L1315
            jp   L4070
L4002b:     ld   hl,s_closes
            rst  28h
            call L1315
L4003:      xor  a                      ; NA, KL, T5 = сумма CC(K)*SZ(K) живых K<=ZT
            ld   (bNA),a
            ld   hl,0
            ld   (bT5),hl
            ld   a,1
            ld   (bK),a
L4003a:     call k_ph_sz
            ld   a,b
            cp   c
            jp   nc,L4004
            ld   hl,bNA
            inc  (hl)
            ld   a,(bK)
            ld   (bKL),a
            ld   b,a
            ld   a,(bZT)
            cp   b
            jp   c,L4004
            ld   a,(bK)                 ; T5=T5+CC(K)*SZ(K)
            add  a,a
            ld   hl,ARR_CC
            rst  00h
            ld   e,(hl)
            inc  hl
            ld   d,(hl)
            ld   l,c
            ld   h,0
            call mul16
            ex   de,hl
            ld   hl,(bT5)
            add  hl,de
            ld   (bT5),hl
L4004:      ld   hl,bK
            inc  (hl)
            ld   a,(bNK)
            cp   (hl)
            jp   nc,L4003a
            ld   a,(bNA)                ; IF NA=1 THEN IF PH(KL)>0 THEN POKE &HCFAB,KL
            cp   1
            jp   nz,L4005
            ld   a,(bKL)
            ld   hl,ARR_PH
            add  a,a
            rst  00h
            ld   a,(hl)
            or   a
            jp   z,L4005
            ld   a,(bKL)
            ld   (ENG_KL),a
L4005:      ld   a,(cfg_fam)            ; 4005..4009 — только SALVO/BARRAGE
            cp   2
            jp   z,L4010
            ld   hl,0
            ld   (bT2),hl
            ld   (bT3),hl
            xor  a
            ld   (bKM),a
            ld   a,1
            ld   (bK),a
L4005a:     ld   a,(bK)                 ; IF PD(K)=0 OR PH(K)=0 OR SZ(K)>3 OR SZ(K)<2 THEN 4009
            add  a,a
            ld   hl,ARR_PD
            rst  00h
            ld   e,(hl)
            inc  hl
            ld   d,(hl)
            ld   a,d
            or   e
            jp   z,L4009
            call k_ph_sz
            ld   a,b
            or   a
            jp   z,L4009
            ld   a,c
            cp   4
            jp   nc,L4009
            cp   2
            jp   c,L4009
            ld   (bLK),a                ; LK=SZ(K): W=11-LK: J=PD(K)-1
            ld   b,a
            ld   a,11
            sub  b
            ld   (bW),a
            dec  de
            ex   de,hl
            ld   (bJ),hl
            call pd_decode              ; -> O, X, Y
L4006:      call k_ph_sz                ; IF PH(K)>=SZ(K) THEN KM=KM+1
            ld   a,b
            cp   c
            jp   c,L4007
            ld   hl,bKM
            inc  (hl)
L4007:      xor  a                      ; FOR T4=0 TO LK-1: U=X+T4*(1-O): V=Y+T4*O
            ld   (bT4),a
L4007a:     ld   a,(bO)
            or   a
            ld   a,(bT4)
            ld   b,a
            ld   c,0
            jp   z,L4007b
            ld   c,b
            ld   b,0
L4007b:     ld   a,(bX)
            add  a,b
            ld   (bU),a
            ld   a,(bY)
            add  a,c
            ld   (bV),a
            ld   hl,(bT3)               ; T3=T3+1
            inc  hl
            ld   (bT3),hl
            ld   a,(bU)                 ; на краю -> T2=T2+1
            or   a
            jp   z,L4007c
            cp   9
            jp   z,L4007c
            ld   a,(bV)
            or   a
            jp   z,L4007c
            cp   9
            jp   nz,L4008
L4007c:     ld   hl,(bT2)
            inc  hl
            ld   (bT2),hl
L4008:      ld   hl,bT4
            inc  (hl)
            ld   a,(bLK)
            cp   (hl)
            jp   nz,L4007a
L4009:      ld   hl,bK
            inc  (hl)
            ld   a,(bZT)
            cp   (hl)
            jp   nc,L4005a
            xor  a                      ; POKE &HCFFA,0: IF KM>1 THEN IF T2*5>=T3*3 THEN POKE &HCFFA,1
            ld   (ENG_RK),a
            ld   a,(bKM)
            cp   2
            jp   c,L4010
            ld   hl,(bT2)
            ld   de,5
            call mul16
            push hl
            ld   hl,(bT3)
            ld   de,3
            call mul16
            ex   de,hl
            pop  hl
            call cmp_hl_de
            jp   c,L4010
            ld   a,1
            ld   (ENG_RK),a
L4010:      xor  a                      ; E9=0: IF NA>1 THEN IF BL=0 THEN IF T5<=NF+NF THEN POKE &HCFAB,255: E9=1
            ld   (bE9),a
            ld   a,(bNA)
            cp   2
            jp   c,L4012
            ld   a,(bBL)
            or   a
            jp   nz,L4012
            ld   a,(bNF)
            add  a,a
            ld   e,a
            ld   d,0
            ld   hl,(bT5)
            call cmp_hl_de
            jp   z,L4010a
            jp   nc,L4012
L4010a:     ld   a,255
            ld   (ENG_KL),a
            ld   a,1
            ld   (bE9),a
L4012:      ld   a,(cfg_fam)
            cp   2
            jp   z,L4013
            ld   a,(bNA)                ; SALVO/BARRAGE: IF NA=1 OR E9=1 THEN USR5 ELSE USR8
            cp   1
            jp   z,L4012a
            ld   a,(bE9)
            cp   1
            jp   z,L4012a
            call eng_probesel
            jp   L4050
L4012a:     call eng_sample
            jp   L4050
L4013:      call eng_sample             ; SALVOP: T2=USR5(0)
L4014:      ld   a,(bE9)
            cp   1
            jp   z,L4050
            xor  a                      ; KL = раненый с наименьшим CC(K)>0; T5 = это CC
            ld   (bKL),a
            ld   hl,32767
            ld   (bT5),hl
            ld   a,1
            ld   (bK),a
L4014a:     call k_ph_sz
            ld   a,b
            or   a
            jp   z,L4015
            cp   c
            jp   nc,L4015
            ld   a,(bK)
            add  a,a
            ld   hl,ARR_CC
            rst  00h
            ld   e,(hl)
            inc  hl
            ld   d,(hl)
            ld   a,d
            or   e
            jp   z,L4015
            ld   a,d
            or   a
            jp   m,L4015
            ld   hl,(bT5)               ; CC(K)<T5
            ex   de,hl
            push hl
            call cmp_hl_de
            pop  hl
            jp   nc,L4015
            ld   (bT5),hl
            ld   a,(bK)
            ld   (bKL),a
L4015:      ld   hl,bK
            inc  (hl)
            ld   a,(bZT)
            cp   (hl)
            jp   nc,L4014a
            ld   a,(bKL)                ; IF KL>0 AND T5=1 THEN POKE &HCFAB,KL
            or   a
            jp   z,L4050
            ld   hl,(bT5)
            dec  hl
            ld   a,h
            or   l
            jp   nz,L4050
            ld   a,(bKL)
            ld   (ENG_KL),a
L4050:      ld   a,(bNF)                ; POKE &HCF99,NF: T2=USR3(0): NS=NF
            ld   (ENG_NF),a
            call eng_pickn
            ld   a,(bNF)
            ld   (bNS),a
            ret

; B = PH(K), C = SZ(K) (младшие байты)
k_ph_sz:    ld   a,(bK)
            add  a,a
            ld   hl,ARR_PH
            rst  00h
            ld   b,(hl)
            ld   a,(bK)
            add  a,a
            ld   hl,ARR_SZ
            rst  00h
            ld   c,(hl)
            ret

; J (номер кандидата корабля длины LK) -> O, X, Y:
; IF J<10*W THEN O=0: Y=J\W: X=J-Y*W ELSE J=J-10*W: O=1: X=J\W: Y=J-X*W
pd_decode:  ld   a,(bW)
            ld   b,a
            add  a,a
            ld   c,a
            add  a,a
            add  a,a
            add  a,c                    ; 10W (<= 90)
            ld   c,a
            ld   a,(bJ)                 ; J < 200
            cp   c
            jp   nc,pdd_v
            xor  a
            ld   (bO),a
            ld   a,(bJ)
            call divb                   ; A = J\W, C = J MOD W
            ld   (bY),a
            ld   a,c
            ld   (bX),a
            jp   pdd_e
pdd_v:      sub  c
            ld   (bJ),a
            ld   a,1
            ld   (bO),a
            ld   a,(bJ)
            call divb
            ld   (bX),a
            ld   a,c
            ld   (bY),a
pdd_e:      xor  a                      ; X, Y — слова со знаком (здесь >= 0)
            ld   (bX+1),a
            ld   (bY+1),a
            ld   (bJ+1),a
            ret
; A = A \ B, C = A MOD B
divb:       ld   c,0
dvb_1:       cp   b
            jp   c,dvb_2
            sub  b
            inc  c
            jp   dvb_1
dvb_2:       ld   d,a
            ld   a,c
            ld   c,d
            ret

; 4070: разведка
L4070:      ld   a,8
            call rnd_n
            ld   (bRD),a
            ld   (ENG_RD),a
            ld   a,(bNF)
            ld   (ENG_NF),a
            xor  a                      ; POKE &HCF9A,-(R8=1 AND SN<14)
            ld   b,a
            ld   a,(bR8)
            cp   1
            jp   nz,L4070a
            ld   a,(bSN)
            cp   14
            jp   nc,L4070a
            ld   b,1
L4070a:     ld   a,b
            ld   (ENG_RIM),a
L4071:      call eng_explore
            ld   a,(bNF)
            ld   (bNS),a
            ret

; 4093: первые залпы — случайные клетки в шахматном порядке, не кучно
L4093:      xor  a
            ld   (bT),a
L4093a:     xor  a
            ld   (bT2),a
            ld   (bT2+1),a
L4094:      ld   hl,(bT2)
            inc  hl
            ld   (bT2),hl
            ld   a,10
            call rnd_n
            ld   (bC),a
            ld   a,10
            call rnd_n
            ld   (bR),a
            ld   e,a                    ; IF PM(C,R)<>0 THEN 4094
            ld   a,(bC)
            call pm_xy
            or   a
            jp   nz,L4094
            ld   a,(bT2)                ; ELSE IF T2<30 AND ((C+R+SN) AND 1)=1 THEN 4094
            cp   30
            jp   nc,L4094b
            ld   a,(bSN)
            ld   b,a
            ld   a,(bC)
            add  a,b
            ld   b,a
            ld   a,(bR)
            add  a,b
            and  1
            jp   nz,L4094
L4094b:     ld   a,(bR8)                ; ELSE IF R8=1 AND T2<25 AND не на краю THEN 4094
            cp   1
            jp   nz,L4095
            ld   a,(bT2)
            cp   25
            jp   nc,L4095
            ld   a,(bC)
            or   a
            jp   z,L4095
            cp   9
            jp   z,L4095
            ld   a,(bR)
            or   a
            jp   z,L4095
            cp   9
            jp   nz,L4094
L4095:      xor  a                      ; CF=0: FOR J=0 TO T-1: IF |TX(J)-C|+|TY(J)-R|<3 THEN CF=1
            ld   (bCF),a
            ld   (bJ),a
            ld   a,(bT)
            or   a
            jp   z,L4096                ; FOR J=0 TO -1 — тело не выполняется
L4095a:     ld   a,(bJ)
            add  a,a
            ld   hl,ARR_TX
            rst  00h
            ld   a,(bC)
            sub  (hl)
            call absa
            ld   b,a
            ld   a,(bJ)
            add  a,a
            ld   hl,ARR_TY
            rst  00h
            ld   a,(bR)
            sub  (hl)
            call absa
            add  a,b
            cp   3
            jp   nc,L4096a
            ld   a,1
            ld   (bCF),a
            jp   L4096
L4096a:     ld   hl,bJ
            inc  (hl)
            ld   a,(bT)
            cp   (hl)
            jp   nz,L4095a
L4096:      ld   a,(bCF)                ; IF CF=1 AND T2<40 THEN 4094
            cp   1
            jp   nz,L4096b
            ld   a,(bT2)
            cp   40
            jp   c,L4094
L4096b:     ld   a,(bT)                 ; TX(T)=C: TY(T)=R
            add  a,a
            ld   hl,ARR_TX
            rst  00h
            ld   a,(bC)
            ld   (hl),a
            inc  hl
            ld   (hl),0
            ld   a,(bT)
            add  a,a
            ld   hl,ARR_TY
            rst  00h
            ld   a,(bR)
            ld   (hl),a
            inc  hl
            ld   (hl),0
            ld   hl,bT
            inc  (hl)
            ld   a,(bNF)
            cp   (hl)
            jp   nz,L4093a
            ld   (bNS),a
            ret
absa:       or   a
            ret  p
            cpl
            inc  a
            ret

; 4097: начало партии для движка
L4097:      ld   hl,0                   ; T=0: FOR K=1 TO ZT: OS(K)=T: LK=SZ(K): CT(K)=20*(11-LK): CC(K)=CT(K): T=T+CT(K): PD(K)=0
            ld   (bT),hl
            ld   a,1
            ld   (bK),a
L4097a:     ld   a,(bK)
            add  a,a
            ld   hl,ARR_OS
            rst  00h
            ld   a,(bT)
            ld   (hl),a
            inc  hl
            ld   a,(bT+1)
            ld   (hl),a
            call k_ph_sz
            ld   a,c
            ld   (bLK),a
            ld   b,a
            ld   a,11
            sub  b                      ; 11-LK
            ld   l,a
            ld   h,0
            add  hl,hl
            add  hl,hl
            ld   d,h
            ld   e,l
            add  hl,hl
            add  hl,hl
            add  hl,de                  ; *20
            ex   de,hl
            ld   a,(bK)
            add  a,a
            ld   hl,ARR_CT
            rst  00h
            ld   (hl),e
            inc  hl
            ld   (hl),d
            ld   a,(bK)
            add  a,a
            ld   hl,ARR_CC
            rst  00h
            ld   (hl),e
            inc  hl
            ld   (hl),d
            ld   hl,(bT)
            add  hl,de
            ld   (bT),hl
            ld   a,(bK)
            add  a,a
            ld   hl,ARR_PD
            rst  00h
            ld   (hl),0
            inc  hl
            ld   (hl),0
            ld   hl,bK
            inc  (hl)
            ld   a,(bZT)
            cp   (hl)
            jp   nc,L4097a
            call L4107
L4098:      call eng_fainit             ; T2=USR7(0): SN=0: FP=0: R8=0
            xor  a
            ld   (bSN),a
            ld   (bFP),a
            ld   (bR8),a
L4099:      xor  a                      ; RU(I) = мест кораблей через строку/столбец I
            ld   (bI),a
L4099a:     xor  a
            ld   (bT),a
            ld   a,1
            ld   (bK),a
L4099b:     call k_ph_sz
            ld   a,10                   ; W=MIN(I,10-SZ)
            sub  c
            ld   b,a
            ld   a,(bI)
            cp   b
            jp   c,L4100
            ld   a,b
L4100:      ld   (bW),a
            ld   a,(bI)                 ; T3=MAX(I-SZ+1,0)
            sub  c
            inc  a
            jp   p,L4101
            xor  a
L4101:      ld   b,a
            ld   a,(bW)                 ; IF W>=T3 THEN T=T+W-T3+1
            cp   b
            jp   c,L4102
            sub  b
            inc  a
            ld   b,a
            ld   a,(bT)
            add  a,b
            ld   (bT),a
L4102:      ld   hl,bK
            inc  (hl)
            ld   a,(bZT)
            cp   (hl)
            jp   nc,L4099b
            ld   a,(bI)                 ; RU(I)=T
            ld   hl,ARR_RU
            rst  00h
            ld   a,(bT)
            ld   (hl),a
            ld   hl,bI
            inc  (hl)
            ld   a,(hl)
            cp   10
            jp   c,L4099a
            ld   c,0                    ; POKE MC(C*12+R+13) = RU(C)+RU(R)
L4102a:     ld   b,0
L4102b:     ld   a,c
            ld   hl,ARR_RU
            rst  00h
            ld   d,(hl)
            ld   a,b
            ld   hl,ARR_RU
            rst  00h
            ld   a,(hl)
            add  a,d
            push af
            ld   a,c                    ; C*12+R
            add  a,a
            add  a,a
            ld   d,a
            add  a,a
            add  a,d
            add  a,b
            ld   hl,ENG_MC+13
            rst  00h
            pop  af
            ld   (hl),a
            inc  b
            ld   a,b
            cp   10
            jp   c,L4102b
            inc  c
            ld   a,c
            cp   10
            jp   c,L4102a
            ret

; 4103: сессионная память — учесть клетки на краю у своего флота
L4103:      ld   a,(SMEMG)
            ld   (bT2),a
            cp   14
            ret  nc
L4104:      xor  a
            ld   (bT3),a
            ld   a,1
            ld   (bK),a
L4104a:     xor  a
            ld   (bT),a
L4104b:     ld   a,(bT)                 ; U=PX(K,T): V=PY(K,T)
            add  a,a
            add  a,a
            ld   b,a
            add  a,a
            add  a,b
            ld   b,a
            ld   a,(bK)
            add  a,b
            ld   hl,ARR_PX
            rst  00h
            ld   a,(hl)
            ld   de,60
            add  hl,de
            ld   e,(hl)
            or   a
            jp   z,L4104c
            cp   9
            jp   z,L4104c
            ld   a,e
            or   a
            jp   z,L4104c
            cp   9
            jp   nz,L4105
L4104c:     ld   hl,bT3
            inc  (hl)
L4105:      ld   hl,bT
            inc  (hl)
            call k_ph_sz
            ld   a,(bT)
            cp   c
            jp   c,L4104b
            ld   hl,bK
            inc  (hl)
            ld   a,(bNK)
            cp   (hl)
            jp   nc,L4104a
            ld   a,(bT2)                ; POKE &HDDF0,T2+1: POKE &HDDF1,PEEK(&HDDF1)+T3
            inc  a
            ld   (SMEMG),a
            ld   a,(bT3)
            ld   b,a
            ld   a,(SMEMR)
            add  a,b
            ld   (SMEMR),a
            ret
; 4107: выученная привычка «на краю»
L4107:      ld   a,(SMEMG)
            ld   (bT2),a
            xor  a
            ld   (SMEMB),a
            ld   a,(bT2)
            cp   2
            ret  c
L4108:      ld   b,55
            cp   2
            jp   nz,L4109
            ld   b,63
L4109:      ld   a,(SMEMR)              ; IF PEEK(&HDDF1)*100 > T3*TT*T2 THEN POKE &HDDF2,1
            ld   l,a
            ld   h,0
            ld   de,100
            push bc
            call mul16
            pop  bc
            push hl
            ld   l,b
            ld   h,0
            ld   a,(bTT)
            ld   e,a
            ld   d,0
            call mul16
            ld   a,(bT2)
            ld   e,a
            ld   d,0
            call mul16
            ex   de,hl
            pop  hl
            call cmp_hl_de
            ret  z
            ret  c
            ld   a,1
            ld   (SMEMB),a
            ret

; ---------------------------------------------------------------- 4156..4164: панель SALVO PLUS
; 4156: строка R9 и столбец X9 корабля I
L4156:      ld   a,(bI)
            cp   5
            jp   nc,L4156a
            dec  a
            ld   (bR9),a
            ld   a,216
            ld   (bX9),a
            ret
L4156a:     jp   nz,L4156b
            ld   a,4
            ld   (bR9),a
            ld   a,216
            ld   (bX9),a
            ret
L4156b:     cp   6
            jp   nz,L4156c
            ld   a,4
            ld   (bR9),a
            ld   a,240
            ld   (bX9),a
            ret
L4156c:     cp   7
            jp   nz,L4156d
            ld   a,5
            ld   (bR9),a
            ld   a,216
            ld   (bX9),a
            ret
L4156d:     ld   a,6                    ; R9=6: X9=216+(I-8)*10
            ld   (bR9),a
            ld   a,(bI)
            sub  8
            add  a,a
            ld   b,a
            add  a,a
            add  a,a
            add  a,b
            add  a,216
            ld   (bX9),a
            ret
; 4158: панель противника (11 кораблей)
L4158:      ld   bc,190*256+34
            ld   de,255*256+89
            ld   a,1
            rst  20h
            ld   a,15
            ld   (gfx_fg),a
            ld   hl,panel_sp            ; RESTORE 9031: 12 подписей
            ld   b,12
L4158a:     push bc
            ld   c,(hl)
            inc  hl
            push hl
            ld   b,190
            ld   a,15
            rst  10h
            pop  hl
            rst  18h
            inc  hl
            pop  bc
            dec  b
            jp   nz,L4158a
L4160:      ld   a,1
            ld   (bI),a
L4160a:     call L4156
            ld   a,(bR9)                ; YP=34+R9*8
            add  a,a
            add  a,a
            add  a,a
            add  a,34
            ld   (bYP),a
            ld   a,(bX9)
            ld   (hr_x0),a
            call hs_row_sp
            ld   hl,bI
            inc  (hl)
            ld   a,(bNK)
            cp   (hl)
            jp   nc,L4160a
            ld   a,15
            ld   (gfx_fg),a
            ret
; 4160: квадратики/номера корабля I с x0 = X9
hs_row_sp:  ld   a,(bI)
            ld   hl,ARR_QH
            rst  00h
            ld   a,(hl)
            ld   (hr_q),a
            ld   a,1
            ld   (hr_j),a
hsp_1:       ld   a,(hr_j)
            dec  a
            add  a,a
            add  a,a
            add  a,a
            ld   b,a
            ld   a,(hr_x0)
            add  a,b
            ld   (hr_x),a
            ld   a,(hr_q)
            ld   b,a
            ld   a,(hr_j)
            cp   b
            jp   z,hsp_hit
            jp   c,hsp_hit
            ld   a,(hr_x)
            ld   b,a
            add  a,4
            ld   d,a
            ld   a,(bYP)
            ld   c,a
            add  a,6
            ld   e,a
            ld   a,9
            rst  20h
            jp   hsp_n
hsp_hit:     ld   a,(hr_j)               ; NV=HS(I,J-1)
            dec  a
            add  a,a
            add  a,a
            ld   b,a
            add  a,a
            add  a,b
            ld   b,a
            ld   a,(bI)
            add  a,b
            ld   hl,ARR_HS
            rst  00h
            ld   a,(hl)
            ld   (bNV),a
            call L3810
            call red_s1
hsp_n:       ld   hl,hr_j
            inc  (hl)
            call sz_i
            ld   a,(hr_j)
            dec  a
            cp   c
            jp   c,hsp_1
            ret
; 4162: свой корабль SH (11 кораблей)
L4162:      ld   a,(bSH)
            ld   (bI),a
            call L4156
            ld   a,(bR9)                ; YP=105+R9*8
            add  a,a
            add  a,a
            add  a,a
            add  a,105
            ld   (bYP),a
            ld   c,a                    ; LINE(X9,YP)-(X9+SZ(SH)*8-4,YP+6),1,BF
            add  a,6
            ld   e,a
            push de
            call sz_sh
            ld   a,c
            add  a,a
            add  a,a
            add  a,a
            sub  4
            ld   b,a
            ld   a,(bX9)
            add  a,b
            pop  de
            ld   d,a
            ld   a,(bX9)
            ld   b,a
            ld   a,(bYP)
            ld   c,a
            ld   a,1
            rst  20h
            ld   a,(bX9)
            ld   (hr_x0),a
            call pm_row
            ld   a,15
            ld   (gfx_fg),a
            ret
; 4170
L4170:      ld   hl,bBL
            dec  (hl)
            ret
; 9031: подписи панели SALVO PLUS (y, текст)
panel_sp:   db 34,"CAR",0, 42,"BAT",0, 50,"CRU",0, 58,"SUB",0, 66,"DES",0, 82,"BOT",0
            db 105,"CAR",0, 113,"BAT",0, 121,"CRU",0, 129,"SUB",0, 137,"DES",0, 153,"BOT",0

; ---------------------------------------------------------------- 4300: разбор отчёта о прошлом залпе
L4301:      ld   a,(bNS)                ; T2=USR0(NS)
            ld   l,a
            ld   h,0
            call eng_fold
L4320:      xor  a
            ld   (bFL),a
            ld   a,1
            ld   (bK),a
L4320a:     ld   a,(bK)                 ; IF PD(K)>0 OR CC(K)<>1 THEN 4329
            add  a,a
            ld   hl,ARR_PD
            rst  00h
            call hl_pos
            jp   nz,L4329
            ld   a,(bK)
            add  a,a
            ld   hl,ARR_CC
            rst  00h
            ld   a,(hl)
            cp   1
            jp   nz,L4329
            inc  hl
            ld   a,(hl)
            or   a
            jp   nz,L4329
L4321:      call k_ph_sz                ; LK=SZ(K): W=11-LK
            ld   a,c
            ld   (bLK),a
            ld   b,a
            ld   a,11
            sub  b
            ld   (bW),a
            ld   a,(bK)                 ; найти единственного живого кандидата в FA(OS..OS+CT-1)
            add  a,a
            ld   hl,ARR_OS
            rst  00h
            ld   e,(hl)
            inc  hl
            ld   d,(hl)
            ex   de,hl
            ld   (bI),hl
            ex   de,hl
            ld   a,(bK)
            add  a,a
            ld   hl,ARR_CT
            rst  00h
            ld   c,(hl)
            inc  hl
            ld   b,(hl)                 ; BC = CT(K)
            ld   hl,ENG_FA
            add  hl,de
L4321a:     ld   a,(hl)
            cp   1
            jp   z,L4321b
            inc  hl
            dec  bc
            ld   a,b
            or   c
            jp   nz,L4321a
            jp   L4322                  ; не нашли: J остаётся прежним (как в оригинале)
L4321b:     ld   de,-ENG_FA             ; J=I-OS(K)
            add  hl,de
            ex   de,hl
            ld   hl,(bI)
            call neg_hl
            add  hl,de
            ld   (bJ),hl
L4322:      ld   hl,(bJ)                ; T2=J
            ld   (bT2),hl
            call pd_decode
L4323:      ld   hl,(bT2)               ; PD(K)=T2+1: FL=1
            inc  hl
            ex   de,hl
            ld   a,(bK)
            add  a,a
            ld   hl,ARR_PD
            rst  00h
            ld   (hl),e
            inc  hl
            ld   (hl),d
            ld   a,1
            ld   (bFL),a
            ld   a,(bX)                 ; A1=X-1: B1=Y-1: A2/B2 по ориентации
            dec  a
            ld   (bA1),a
            ld   a,(bY)
            dec  a
            ld   (bB1),a
            ld   a,(bO)
            or   a
            jp   nz,L4323a
            ld   a,(bLK)
            ld   b,a
            ld   a,(bX)
            add  a,b
            ld   (bA2),a
            ld   a,(bY)
            inc  a
            ld   (bB2),a
            jp   L4324
L4323a:     ld   a,(bX)
            inc  a
            ld   (bA2),a
            ld   a,(bLK)
            ld   b,a
            ld   a,(bY)
            add  a,b
            ld   (bB2),a
L4324:      ld   a,(bA1)                ; FOR U=A1 TO A2: FOR V=B1 TO B2
            ld   (bU),a
L4324a:     ld   a,(bB1)
            ld   (bV),a
L4324b:     ld   a,(bU)
            cp   10
            jp   nc,L4328
            ld   a,(bV)
            cp   10
            jp   nc,L4328
L4325:      ld   a,1                    ; FOR KN=1 TO ZT: IF KN<>K THEN USR1(KN*256+U*16+V)
            ld   (bKN),a
L4325a:     ld   a,(bK)
            ld   b,a
            ld   a,(bKN)
            cp   b
            jp   z,L4326
            ld   h,a
            ld   a,(bU)
            add  a,a
            add  a,a
            add  a,a
            add  a,a
            ld   b,a
            ld   a,(bV)
            add  a,b
            ld   l,a
            call eng_kill1
L4326:      ld   hl,bKN
            inc  (hl)
            ld   a,(bZT)
            cp   (hl)
            jp   nc,L4325a
            ld   a,(bO)                 ; на самом корабле буй не ставится
            or   a
            jp   nz,L4326a
            ld   a,(bY)
            ld   b,a
            ld   a,(bV)
            cp   b
            jp   nz,L4327
            ld   a,(bX)
            ld   b,a
            ld   a,(bU)
            cp   b
            jp   c,L4327
            sub  b
            ld   b,a
            ld   a,(bLK)
            cp   b
            jp   z,L4327
            jp   c,L4327
            jp   L4328
L4326a:     ld   a,(bX)
            ld   b,a
            ld   a,(bU)
            cp   b
            jp   nz,L4327
            ld   a,(bY)
            ld   b,a
            ld   a,(bV)
            cp   b
            jp   c,L4327
            sub  b
            ld   b,a
            ld   a,(bLK)
            cp   b
            jp   z,L4327
            jp   c,L4327
            jp   L4328
L4327:      ld   a,(bV)                 ; IF PM(U,V)=0 AND BZ(U,V)<>3 THEN буй (176)
            ld   e,a
            ld   a,(bU)
            call open_xy
            jp   nz,L4328
            ld   a,(bV)
            ld   e,a
            ld   a,(bU)
            ld   bc,ARR_BZ
            call w10
            ld   (hl),3
            inc  hl
            ld   (hl),0
            ld   a,176
            ld   (bQ),a
            ld   a,(bU)
            ld   (bC),a
            ld   a,(bV)
            ld   (bR),a
            xor  a
            ld   (bSD),a
            call L1105
L4328:      ld   hl,bV
            inc  (hl)
            ld   a,(bB2)
            cp   (hl)
            jp   p,L4324b
            ld   hl,bU
            inc  (hl)
            ld   a,(bA2)
            cp   (hl)
            jp   p,L4324a
L4329:      ld   hl,bK
            inc  (hl)
            ld   a,(bZT)
            cp   (hl)
            jp   nc,L4320a
            ld   a,(bFL)
            cp   1
            jp   z,L4320
L4336:      ld   a,(bBL)                ; IF BL>0 THEN RETURN
            or   a
            jp   z,L4338
            ret  p
L4338:      ld   c,0                    ; клетки без кандидатов (MC=0) — буи 160
L4338a:     ld   b,0
L4338b:     push bc
            ld   a,c
            add  a,a
            add  a,a
            ld   d,a
            add  a,a
            add  a,d
            add  a,b
            ld   hl,ENG_MC+13
            rst  00h
            ld   a,(hl)
            or   a
            jp   nz,L4339
            ld   a,c
            ld   (bC),a
            ld   a,b
            ld   (bR),a
            ld   e,b
            ld   a,c
            call open_xy
            jp   nz,L4339
            ld   bc,ARR_BZ
            call w10cr
            ld   (hl),3
            inc  hl
            ld   (hl),0
            ld   a,160
            ld   (bQ),a
            xor  a
            ld   (bSD),a
            call L1105
L4339:      pop  bc
            inc  b
            ld   a,b
            cp   10
            jp   c,L4338b
            inc  c
            ld   a,c
            cp   10
            jp   c,L4338a
            ret

s_hits:         db "HITS:",0
s_lbr:          db " [",0
s_sank:         db " SANK: ",0
s_press_space:  db "Press SPACE to continue ...",0
s_reviews:      db "ENEMY REVIEWS LAST SALVO ...",0
s_enemy_hits:   db "ENEMY HITS:",0
s_undo:         db "UNDO ",0
s_probes:       db "ENEMY PROBES OPEN SEA ...",0
s_closes:       db "ENEMY CLOSES IN ...",0
