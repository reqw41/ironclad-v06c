; ============================================================================
; gsalvo.asm — перевод IRONCLAD.BAS: сборки SALVO/SALVOP/BARRAGE (BD=1),
; строки 3798..3893 и 4000..4339. POKE/PEEK/USR в движок — через символы движка.
; ============================================================================

; ---------------------------------------------------------------- 3798: итог своего залпа
L3798:      LDV  bSJ
            or   a
            jp   z,L3800
L3799:      ZEROV bN  ; FOR N=0 TO SJ-1: SH=SQ(N): GOSUB 3858: GOSUB 2622
L3799a:     LDV  bN
            ld   hl,ARR_SQ
            rst  00h
            ld   a,(hl)
            STV  bSH
            call L3858
            call L2622
            INCV bN
            LDV  bSJ
            cp   (hl)
            jp   nz,L3799a
L3800:      LDV  bSK                ; IF SK>0: FOR N=0 TO NF-1: P=GT(N): U=P\10: V=P MOD 10: GOSUB 3808
            or   a
            jp   z,L3801
            ZEROV bN
L3800a:     LDV  bN
            ld   hl,ARR_GT
            rst  00h
            ld   a,(hl)
            STV  bP
            call div10
            STV  bU
            ld   a,b
            STV  bV
            call L3808
            INCV bN
            LDV  bNF
            cp   (hl)
            jp   nz,L3800a
L3801:      LDV  bSL                ; NV=SL: GOSUB 3810
            STV  bNV
            call L3810
            LDV  bNF                ; "HITS:"+STR$(SK)+"/"+MID$(STR$(NF),2)+" ["+S1$+"]"
            ld   b,a
            LDV  bSK
            ld   hl,s_hits
            call hits_msg
            ld   hl,sSS                 ; IF SS$<>"" THEN MS$=MS$+" SANK: "+LEFT$(SS$,LEN(SS$)-1)
            ld   de,9                   ; сокращение: LEFT$(MS$,9)+MID$(MS$,14)
            call salvo_sank
L3803:      call L1305
            LDV  bSK
            or   a
            call nz,L3820
L3804:      call te_tt
            jp   nc,L3805
            ld   hl,s_press_space
            call ms_set
            call L1315
            ZEROV bKQ
L3805:      call inkey                  ; IF INKEY$<>"" THEN 3805
            jp   nz,L3805
            ret

; MS$ = строка HL + STR$(A) + "/" + MID$(STR$(B),2) + " [" + S1$ + "]"
hits_msg:   push bc
            push af
            call ms_set
            pop  af
            ld   l,a
            ld   h,0
            call ms_catnum
            ld   a,'/'
            call ms_catc
            pop  af
            call ms_catd
            call ms_cati
            TXT  " ["
            ld   hl,sS1
            call ms_cat
            ld   a,']'
            jp   ms_catc

; MS$ += " SANK: " + SS$ без последней запятой; если длиннее 31 — вырезать 4 знака
; HL = SS$/ES$, D = с какого знака (0-базно) вырезать: E=9 -> LEFT$(,9)+MID$(,14); E=15 -> LEFT$(,15)+MID$(,20)
salvo_sank:
            ld   a,(hl)
            or   a
            ret  z
            push de
            push hl
            call ms_cati
            TXT  " SANK: "
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
L3808:      LDV  bV
            ld   e,a
            LDV  bU
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
            SETV bSD,1
            LDV  bU
            STV  bC
            LDV  bV
            STV  bR
            jp   L1105

; 3810: NV=((NV-1) AND 31)+1: S1$=CHR$(48+NV): IF NV>9 THEN S1$=CHR$(55+NV)
L3810:      LDV  bNV
            dec  a
            and  31
            inc  a
            STV  bNV
            ld   b,48
            cp   10
            jp   c,L3810a
            ld   b,55
L3810a:     add  a,b
            STV  sS1
            ZEROV sS1+1
            ret

; 3820: панель — корабли противника (SALVO/BARRAGE; SALVOP -> 4158)
L3820:      CPV  bNK,8
            jp   nc,L4158
            SETV bI,1
L3821:      LDV  bI                 ; LINE(190,37+(I-1)*PZ)-(255,44+(I-1)*10),1,BF
            ZEROV bY0
            LDV  bI
            call y_i
            ld   c,a
            STV  bYP
            LDV  bI
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
            call gfx_fill
L3822:      LDV  bI                 ; SF: QH(I)>=SZ(I)
            ld   hl,ARR_QH
            rst  00h
            ld   b,(hl)
            call sz_i
            LDV  bI
            call pn_draw
L3825:      SETV hr_x0,216              ; квадратики / номера залпов HS(I,J-1)
            call hs_row
            INCV bI
            LDV  bZT
            cp   (hl)
            jp   nc,L3821
L3830:      jp   fg15

; 3825..3829 / 4160: квадратики/номера залпов HS(I,J-1) корабля I, строка bYP, x0 = hr_x0 (шаг 8)
hs_row:     LDV  bI
            ld   hl,ARR_QH
            rst  00h
            ld   a,(hl)
            STV  hr_q               ; QH(I)
            SETV hr_j,1
hsp_1:      call hr_xj
            ld   b,a                    ; J-1
            LDV  hr_q
            cp   b
            jp   z,hsp_n0               ; J<=QH ⇔ QH>J-1
            jp   nc,hsp_hit
hsp_n0:     ld   a,9                    ; LINE(x,y)-(x+4,y+6),9,BF
            call sq_draw
            jp   hsp_n
hsp_hit:    ld   a,b                    ; NV=HS(I,J-1): GOSUB 3810: COLOR 8: PSET(x,y): PRINT S1$
            call x12
            ld   b,a
            LDV  bI
            add  a,b
            ld   hl,ARR_HS
            rst  00h
            ld   a,(hl)
            call nv_red
hsp_n:      INCV hr_j
            call sz_i
            LDV  hr_j
            dec  a
            cp   c
            jp   c,hsp_1
            ret
; hr_x = hr_x0 + (J-1)*8 -> A = J-1 (портит B, C)
hr_xj:      LDV  hr_j
            dec  a
            ld   c,a
            add  a,a
            add  a,a
            add  a,a
            ld   b,a
            LDV  hr_x0
            add  a,b
            STV  hr_x
            ld   a,c
            ret
; LINE(hr_x,YP)-(hr_x+4,YP+6),A,BF
sq_draw:    push af
            LDV  hr_x
            ld   b,a
            add  a,4
            ld   d,a
            LDV  bYP
            ld   c,a
            add  a,6
            ld   e,a
            pop  af
            jp   gfx_fill
; NV=A: GOSUB 3810: COLOR 8: PSET(hr_x,bYP): PRINT S1$
nv_red:     STV  bNV
            call L3810
; COLOR 8: PSET(hr_x,bYP): PRINT S1$
red_s1:     ld   a,8
            ld   (gfx_fg),a
            LDV  hr_x
            ld   b,a
            LDV  bYP
            ld   c,a
            ld   a,8
            call gfx_pset
            ld   hl,sS1
            call gfx_puts
fg15:       ld   a,15
            ld   (gfx_fg),a
            ret

; ---------------------------------------------------------------- 3840: залп противника
L3840:      ZEROV bEK
            ld   (sES),a
            INCV bSN
            call ms_clear
            call L1305
            CPV  bFP,1
            jp   nz,L3843
            ZEROV bFP
            call msg2i
            TXT  "ENEMY REVIEWS LAST SALVO ..."
            call L4301
L3843:      call L4000
            ld   hl,ARR_HK              ; FOR K=1 TO ZT: HK(K)=0
            ld   de,16
            call memzero
L3844:      ZEROV bNC  ; FOR NC=0 TO NS-1: BX=TX(NC): BY=TY(NC): GOSUB 910
L3844a:     LDV  bNC
            call tx_a
            ld   a,b
            STV  bBX
            ld   a,c
            STV  bBY
            call L910
            call tp_tt                  ; IF TP>=TT THEN NC=NS-1
            jp   c,L3846
            LDV  bNS
            dec  a
            STV  bNC
L3846:      INCV bNC
            LDV  bNS
            cp   (hl)
            jp   z,L3847
            jp   nc,L3844a
L3847:      call tp_tt
            jp   nc,L3853
            SETV bFP,1
L3853:      LDV  bSN                ; NV=SN: "ENEMY HITS:"+STR$(EK)+"/"+NS+" ["+S1$+"]"
            STV  bNV
            call L3810
            LDV  bNS
            ld   b,a
            LDV  bEK
            ld   hl,s_enemy_hits
            call hits_msg
            ld   hl,sES
            ld   de,15
            call salvo_sank
L3854:      call L1315
            call tp_tt
            ret  nc
L3855:      ld   hl,s_press_space
            call ms_set
            call L1305
            ZEROV bKQ
L3856:      call inkey
            jp   nz,L3856
L3857:      call getkey                 ; TAB — листать страницы (без 1473), пробел — дальше
            STV  bK_
            cp   9
            jp   nz,L3857a
            LDV  bDP
            xor  1
            STV  bDP
            call page_show
            jp   L3857
L3857a:     cp   ' '
            jp   nz,L3857
            call ms_clear
            jp   L1305
; 3858: SS$=SS$+LEFT$(N$(SH),3)+","
L3858:      ld   de,sSS
; DE$ = DE$ + LEFT$(N$(SH),3) + ","
cat_sh3:    call str_end
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
            LDV  bSL
            ld   (hl),a
            inc  hl
            ld   (hl),0
            call rd_cxcy
L3872:      LDV  bSH
            or   a
            jp   nz,L3874
            ZEROV bHW
            ret
L3874:      SETV bHW,1
            call qh_sh                  ; QH(SH)=QH(SH)+1
            inc  (hl)
            ld   b,(hl)
            INCV bTE
            INCV bSK
            ld   a,b                    ; HS(SH,QH(SH)-1)=SL
            dec  a
            add  a,a
            add  a,a
            ld   c,a
            add  a,a
            add  a,c
            ld   c,a
            LDV  bSH
            add  a,c
            ld   hl,ARR_HS
            rst  00h
            LDV  bSL
            ld   (hl),a
L3876:      call qh_sh
            ld   b,(hl)
            call sz_sh
            ld   a,b
            cp   c
            ret  c
L3878:      LDV  bSJ                ; SJ=SJ+1: SQ(SJ-1)=SH
            ld   hl,ARR_SQ
            rst  00h
            LDV  bSH
            ld   (hl),a
            INCV bSJ
            ret

; 3880: отмена выстрела залпа (U)
L3880:      LDV  bNC
            or   a
            ret  z
L3881:      dec  a
            STV  bNC
            ld   hl,ARR_GT
            rst  00h
            ld   a,(hl)
            STV  bP
            call div10
            STV  bCX
            ld   a,b
            STV  bCY
            call cs_cxcy
            ld   a,(hl)
            and  15
            STV  bSH
            call cm_cxcy
            ld   (hl),0
            inc  hl
            ld   (hl),0
            call rd_cxcy
L3882:      LDV  bSH
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
            LDV  bSH
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
L3883:      call ms_seti
            TXT  "UNDO "
            LDV  bCX
            add  a,65
            call ms_catc
            LDV  bCY
            inc  a
            call ms_catd
            call L1305
            jp   L1473

; 3884: панель — свой корабль SH (SALVO/BARRAGE; SALVOP -> 4162)
L3884:      CPV  bNK,8
            jp   nc,L4162
            LDV  bSH                ; YP=107+(SH-1)*10
            dec  a
            add  a,a
            ld   b,a
            add  a,a
            add  a,a
            add  a,b
            add  a,107
            STV  bYP
L3885:      ld   c,a                    ; LINE(190,YP)-(255,YP+7),1,BF
            add  a,7
            ld   e,a
            ld   b,190
            ld   d,255
            ld   a,1
            call gfx_fill
            call ph_sh                  ; SF: PH(SH)>=SZ(SH)
            ld   b,c
            call sz_sh
            LDV  bSH
            call pn_draw
            SETV hr_x0,216
            call pm_row
            jp   fg15

; 3822..3824/3885..3887: CL=15 (потоплен, B>=C: 8): COLOR CL: PSET(190,YP): PRINT LEFT$(N$(A),3)
pn_draw:    push af
            SETV bCL,15
            ld   a,b
            cp   c
            jp   c,pn_1
            SETV bCL,8
pn_1:       LDV  bCL
            ld   (gfx_fg),a
            ld   e,a
            LDV  bYP
            ld   c,a
            ld   b,190
            ld   a,e
            call gfx_pset
            pop  af
            call n_a
            ld   de,sT
            call cat3
            ld   hl,sT
            jp   gfx_puts

; 3888..3891 / 4163: FOR J=1 TO SZ(SH): P=PM(PX(SH,J-1),PY(SH,J-1)):
;   IF (P AND 3)<2 -> квадратик 9, иначе NV=P\4 -> номер красным. x = hr_x0 + (J-1)*8
pm_row:     SETV hr_j,1
pr_1:       call hr_xj                  ; PX(SH,J-1), PY(SH,J-1)
            call x12
            ld   c,a
            LDV  bSH
            add  a,c
            call pxy_a
            call pm_xy
            STV  bP
            and  3
            cp   2
            jp   nc,pr_hit
            ld   a,9
            call sq_draw
            jp   pr_n
pr_hit:     LDV  bP                 ; NV=P\4
            rrca
            rrca
            and  3Fh
            call nv_red
pr_n:       INCV hr_j
            call sz_sh
            LDV  hr_j
            dec  a
            cp   c
            jp   c,pr_1
            ret

; ---------------------------------------------------------------- 4000: ИИ залпа (BASIC-часть)
L4000:      CPV  bSN,3
            jp   c,L4093
L4001:      ZEROV bKM  ; KM=1, если есть раненый (0<PH<SZ) среди 1..ZT
            SETV bK,1
L4001a:     call k_ph_sz                ; B = PH(K), C = SZ(K)
            ld   a,b
            or   a
            jp   z,L4002
            cp   c
            jp   nc,L4002
            SETV bKM,1
            jp   L4002x
L4002:      INCV bK
            LDV  bZT
            cp   (hl)
            jp   nc,L4001a
L4002x:     LDV  bKM
            or   a
            jp   nz,L4002b
            call msg2i
            TXT  "ENEMY PROBES OPEN SEA ..."
            jp   L4070
L4002b:     call msg2i
            TXT  "ENEMY CLOSES IN ..."
L4003:      ZEROV bNA  ; NA, KL, T5 = сумма CC(K)*SZ(K) живых K<=ZT
            ld   hl,0
            ld   (bT5),hl
            SETV bK,1
L4003a:     call k_ph_sz
            ld   a,b
            cp   c
            jp   nc,L4004
            INCV bNA
            LDV  bK
            STV  bKL
            ld   b,a
            LDV  bZT
            cp   b
            jp   c,L4004
            LDV  bK                 ; T5=T5+CC(K)*SZ(K)
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
L4004:      INCV bK
            LDV  bNK
            cp   (hl)
            jp   nc,L4003a
            CPV  bNA,1  ; IF NA=1 THEN IF PH(KL)>0 THEN POKE &HCFAB,KL
            jp   nz,L4005
            LDV  bKL
            ld   hl,ARR_PH
            add  a,a
            rst  00h
            ld   a,(hl)
            or   a
            jp   z,L4005
            LDV  bKL
            ld   (ENG_KL),a
L4005:      CPV  cfg_fam,2  ; 4005..4009 — только SALVO/BARRAGE
            jp   z,L4010
            ld   hl,0
            ld   (bT2),hl
            ld   (bT3),hl
            ZEROV bKM
            SETV bK,1
L4005a:     LDV  bK                 ; IF PD(K)=0 OR PH(K)=0 OR SZ(K)>3 OR SZ(K)<2 THEN 4009
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
            STV  bLK                ; LK=SZ(K): W=11-LK: J=PD(K)-1
            ld   b,a
            ld   a,11
            sub  b
            STV  bW
            dec  de
            ex   de,hl
            ld   (bJ),hl
            call pd_decode              ; -> O, X, Y
L4006:      call k_ph_sz                ; IF PH(K)>=SZ(K) THEN KM=KM+1
            ld   a,b
            cp   c
            jp   c,L4007
            INCV bKM
L4007:      ZEROV bT4  ; FOR T4=0 TO LK-1: U=X+T4*(1-O): V=Y+T4*O
L4007a:     LDV  bO
            or   a
            LDV  bT4
            ld   b,a
            ld   c,0
            jp   z,L4007b
            ld   c,b
            ld   b,0
L4007b:     LDV  bX
            add  a,b
            STV  bU
            LDV  bY
            add  a,c
            STV  bV
            ld   hl,(bT3)               ; T3=T3+1
            inc  hl
            ld   (bT3),hl
            LDV  bU                 ; на краю -> T2=T2+1
            or   a
            jp   z,L4007c
            cp   9
            jp   z,L4007c
            LDV  bV
            or   a
            jp   z,L4007c
            cp   9
            jp   nz,L4008
L4007c:     ld   hl,(bT2)
            inc  hl
            ld   (bT2),hl
L4008:      INCV bT4
            LDV  bLK
            cp   (hl)
            jp   nz,L4007a
L4009:      INCV bK
            LDV  bZT
            cp   (hl)
            jp   nc,L4005a
            xor  a                      ; POKE &HCFFA,0: IF KM>1 THEN IF T2*5>=T3*3 THEN POKE &HCFFA,1
            ld   (ENG_RK),a
            CPV  bKM,2
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
L4010:      ZEROV bE9  ; E9=0: IF NA>1 THEN IF BL=0 THEN IF T5<=NF+NF THEN POKE &HCFAB,255: E9=1
            CPV  bNA,2
            jp   c,L4012
            LDV  bBL
            or   a
            jp   nz,L4012
            LDV  bNF
            add  a,a
            ld   e,a
            ld   d,0
            ld   hl,(bT5)
            call cmp_hl_de
            jp   z,L4010a
            jp   nc,L4012
L4010a:     ld   a,255
            ld   (ENG_KL),a
            SETV bE9,1
L4012:      CPV  cfg_fam,2
            jp   z,L4013
            CPV  bNA,1  ; SALVO/BARRAGE: IF NA=1 OR E9=1 THEN USR5 ELSE USR8
            jp   z,L4012a
            CPV  bE9,1
            jp   z,L4012a
            call eng_probesel
            jp   L4050
L4012a:     call eng_sample
            jp   L4050
L4013:      call eng_sample             ; SALVOP: T2=USR5(0)
L4014:      CPV  bE9,1
            jp   z,L4050
            ZEROV bKL  ; KL = раненый с наименьшим CC(K)>0; T5 = это CC
            ld   hl,32767
            ld   (bT5),hl
            SETV bK,1
L4014a:     call k_ph_sz
            ld   a,b
            or   a
            jp   z,L4015
            cp   c
            jp   nc,L4015
            LDV  bK
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
            LDV  bK
            STV  bKL
L4015:      INCV bK
            LDV  bZT
            cp   (hl)
            jp   nc,L4014a
            LDV  bKL                ; IF KL>0 AND T5=1 THEN POKE &HCFAB,KL
            or   a
            jp   z,L4050
            ld   hl,(bT5)
            dec  hl
            ld   a,h
            or   l
            jp   nz,L4050
            LDV  bKL
            ld   (ENG_KL),a
L4050:      LDV  bNF                ; POKE &HCF99,NF: T2=USR3(0): NS=NF
            ld   (ENG_NF),a
            call eng_pickn
            LDV  bNF
            STV  bNS
            ret

; B = PH(K), C = SZ(K) (младшие байты)
k_ph_sz:    LDV  bK
            add  a,a
            ld   hl,ARR_SZ
            rst  00h
            ld   c,(hl)
            ld   a,ARR_PH-ARR_SZ
            rst  00h
            ld   b,(hl)
            ret

; J (номер кандидата корабля длины LK) -> O, X, Y:
; IF J<10*W THEN O=0: Y=J\W: X=J-Y*W ELSE J=J-10*W: O=1: X=J\W: Y=J-X*W
pd_decode:  LDV  bW
            ld   b,a
            add  a,a
            ld   c,a
            add  a,a
            add  a,a
            add  a,c                    ; 10W (<= 90)
            ld   c,a
            LDV  bJ                 ; J < 200
            cp   c
            jp   nc,pdd_v
            ZEROV bO
            LDV  bJ
            call divb                   ; A = J\W, C = J MOD W
            STV  bY
            ld   a,c
            STV  bX
            jp   pdd_e
pdd_v:      sub  c
            STV  bJ
            SETV bO,1
            LDV  bJ
            call divb
            STV  bX
            ld   a,c
            STV  bY
pdd_e:      ZEROV bX+1  ; X, Y — слова со знаком (здесь >= 0)
            STV  bY+1
            STV  bJ+1
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
            STV  bRD
            ld   (ENG_RD),a
            LDV  bNF
            ld   (ENG_NF),a
            xor  a                      ; POKE &HCF9A,-(R8=1 AND SN<14)
            ld   b,a
            CPV  bR8,1
            jp   nz,L4070a
            CPV  bSN,14
            jp   nc,L4070a
            ld   b,1
L4070a:     ld   a,b
            ld   (ENG_RIM),a
L4071:      call eng_explore
            LDV  bNF
            STV  bNS
            ret

; 4093: первые залпы — случайные клетки в шахматном порядке, не кучно
L4093:      ZEROV bT
L4093a:     ZEROV bT2
            STV  bT2+1
L4094:      ld   hl,(bT2)
            inc  hl
            ld   (bT2),hl
            ld   a,10
            call rnd_n
            STV  bC
            ld   a,10
            call rnd_n
            STV  bR
            ld   e,a                    ; IF PM(C,R)<>0 THEN 4094
            LDV  bC
            call pm_xy
            or   a
            jp   nz,L4094
            CPV  bT2,30  ; ELSE IF T2<30 AND ((C+R+SN) AND 1)=1 THEN 4094
            jp   nc,L4094b
            LDV  bSN
            ld   b,a
            LDV  bC
            add  a,b
            ld   b,a
            LDV  bR
            add  a,b
            and  1
            jp   nz,L4094
L4094b:     CPV  bR8,1  ; ELSE IF R8=1 AND T2<25 AND не на краю THEN 4094
            jp   nz,L4095
            CPV  bT2,25
            jp   nc,L4095
            LDV  bC
            or   a
            jp   z,L4095
            cp   9
            jp   z,L4095
            LDV  bR
            or   a
            jp   z,L4095
            cp   9
            jp   nz,L4094
L4095:      ZEROV bCF  ; CF=0: FOR J=0 TO T-1: IF |TX(J)-C|+|TY(J)-R|<3 THEN CF=1
            STV  bJ
            LDV  bT
            or   a
            jp   z,L4096                ; FOR J=0 TO -1 — тело не выполняется
L4095a:     LDV  bJ
            add  a,a
            ld   hl,ARR_TX
            rst  00h
            LDV  bC
            sub  (hl)
            call absa
            ld   b,a
            LDV  bJ
            add  a,a
            ld   hl,ARR_TY
            rst  00h
            LDV  bR
            sub  (hl)
            call absa
            add  a,b
            cp   3
            jp   nc,L4096a
            SETV bCF,1
            jp   L4096
L4096a:     INCV bJ
            LDV  bT
            cp   (hl)
            jp   nz,L4095a
L4096:      CPV  bCF,1  ; IF CF=1 AND T2<40 THEN 4094
            jp   nz,L4096b
            CPV  bT2,40
            jp   c,L4094
L4096b:     LDV  bC                 ; TX(T)=C: TY(T)=R
            ld   b,a
            LDV  bR
            ld   e,a
            LDV  bT
            call txy_set
            INCV bT
            LDV  bNF
            cp   (hl)
            jp   nz,L4093a
            STV  bNS
            ret
absa:       or   a
            ret  p
            cpl
            inc  a
            ret

; 4097: начало партии для движка
L4097:      ld   hl,0                   ; T=0: FOR K=1 TO ZT: OS(K)=T: LK=SZ(K): CT(K)=20*(11-LK): CC(K)=CT(K): T=T+CT(K): PD(K)=0
            ld   (bT),hl
            SETV bK,1
L4097a:     LDV  bK
            add  a,a
            ld   hl,ARR_OS
            rst  00h
            LDV  bT
            ld   (hl),a
            inc  hl
            LDV  bT+1
            ld   (hl),a
            call k_ph_sz
            ld   a,c
            STV  bLK
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
            LDV  bK
            add  a,a
            ld   hl,ARR_CT
            rst  00h
            ld   (hl),e
            inc  hl
            ld   (hl),d
            LDV  bK
            add  a,a
            ld   hl,ARR_CC
            rst  00h
            ld   (hl),e
            inc  hl
            ld   (hl),d
            ld   hl,(bT)
            add  hl,de
            ld   (bT),hl
            LDV  bK
            add  a,a
            ld   hl,ARR_PD
            rst  00h
            ld   (hl),0
            inc  hl
            ld   (hl),0
            INCV bK
            LDV  bZT
            cp   (hl)
            jp   nc,L4097a
            call L4107
L4098:      call eng_fainit             ; T2=USR7(0): SN=0: FP=0: R8=0
            ZEROV bSN
            STV  bFP
            STV  bR8
L4099:      ZEROV bI  ; RU(I) = мест кораблей через строку/столбец I
L4099a:     ZEROV bT
            SETV bK,1
L4099b:     call k_ph_sz
            ld   a,10                   ; W=MIN(I,10-SZ)
            sub  c
            ld   b,a
            LDV  bI
            cp   b
            jp   c,L4100
            ld   a,b
L4100:      STV  bW
            LDV  bI                 ; T3=MAX(I-SZ+1,0)
            sub  c
            inc  a
            jp   p,L4101
            xor  a
L4101:      ld   b,a
            LDV  bW                 ; IF W>=T3 THEN T=T+W-T3+1
            cp   b
            jp   c,L4102
            sub  b
            inc  a
            ld   b,a
            LDV  bT
            add  a,b
            STV  bT
L4102:      INCV bK
            LDV  bZT
            cp   (hl)
            jp   nc,L4099b
            LDV  bI                 ; RU(I)=T
            ld   hl,ARR_RU
            rst  00h
            LDV  bT
            ld   (hl),a
            INCV bI
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
            STV  bT2
            cp   14
            ret  nc
L4104:      ZEROV bT3
            SETV bK,1
L4104a:     ZEROV bT
L4104b:     LDV  bT                 ; U=PX(K,T): V=PY(K,T)
            add  a,a
            add  a,a
            ld   b,a
            add  a,a
            add  a,b
            ld   b,a
            LDV  bK
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
L4104c:     INCV bT3
L4105:      INCV bT
            call k_ph_sz
            LDV  bT
            cp   c
            jp   c,L4104b
            INCV bK
            LDV  bNK
            cp   (hl)
            jp   nc,L4104a
            LDV  bT2                ; POKE &HDDF0,T2+1: POKE &HDDF1,PEEK(&HDDF1)+T3
            inc  a
            ld   (SMEMG),a
            LDV  bT3
            ld   b,a
            ld   a,(SMEMR)
            add  a,b
            ld   (SMEMR),a
            ret
; 4107: выученная привычка «на краю»
L4107:      ld   a,(SMEMG)
            STV  bT2
            xor  a
            ld   (SMEMB),a
            CPV  bT2,2
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
            LDV  bTT
            ld   e,a
            ld   d,0
            call mul16
            LDV  bT2
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
L4156:      CPV  bI,8
            jp   nc,L4156d
            add  a,a
            ld   hl,t4156-2
            rst  00h
            ld   a,(hl)
            STV  bR9
            inc  hl
            ld   a,(hl)
            STV  bX9
            ret
t4156:      db 0,216, 1,216, 2,216, 3,216, 4,216, 4,240, 5,216     ; I=1..7: R9, X9
L4156d:     SETV bR9,6  ; R9=6: X9=216+(I-8)*10
            LDV  bI
            sub  8
            add  a,a
            ld   b,a
            add  a,a
            add  a,a
            add  a,b
            add  a,216
            STV  bX9
            ret
; 4158: панель противника (11 кораблей)
L4158:      ld   bc,190*256+34
            ld   de,255*256+89
            ld   a,1
            call gfx_fill
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
            call gfx_pset
            pop  hl
            call gfx_puts
            inc  hl
            pop  bc
            dec  b
            jp   nz,L4158a
L4160:      SETV bI,1
L4160a:     call L4156
            LDV  bR9                ; YP=34+R9*8
            add  a,a
            add  a,a
            add  a,a
            add  a,34
            STV  bYP
            LDV  bX9
            STV  hr_x0
            call hs_row
            INCV bI
            LDV  bNK
            cp   (hl)
            jp   nc,L4160a
            jp   fg15
; 4162: свой корабль SH (11 кораблей)
L4162:      LDV  bSH
            STV  bI
            call L4156
            LDV  bR9                ; YP=105+R9*8
            add  a,a
            add  a,a
            add  a,a
            add  a,105
            STV  bYP
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
            LDV  bX9
            add  a,b
            pop  de
            ld   d,a
            LDV  bX9
            ld   b,a
            LDV  bYP
            ld   c,a
            ld   a,1
            call gfx_fill
            LDV  bX9
            STV  hr_x0
            call pm_row
            jp   fg15
; 4170
L4170:      ld   hl,bBL
            dec  (hl)
            ret
; 9031: подписи панели SALVO PLUS (y, текст)
panel_sp:   db   34
            TXT  "CAR"
            db   42
            TXT  "BAT"
            db   50
            TXT  "CRU"
            db   58
            TXT  "SUB"
            db   66
            TXT  "DES"
            db   82
            TXT  "BOT"
            db   105
            TXT  "CAR"
            db   113
            TXT  "BAT"
            db   121
            TXT  "CRU"
            db   129
            TXT  "SUB"
            db   137
            TXT  "DES"
            db   153
            TXT  "BOT"

; ---------------------------------------------------------------- 4300: разбор отчёта о прошлом залпе
L4301:      LDV  bNS                ; T2=USR0(NS)
            ld   l,a
            ld   h,0
            call eng_fold
L4320:      ZEROV bFL
            SETV bK,1
L4320a:     LDV  bK                 ; IF PD(K)>0 OR CC(K)<>1 THEN 4329
            add  a,a
            ld   hl,ARR_PD
            rst  00h
            call hl_pos
            jp   nz,L4329
            LDV  bK
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
            STV  bLK
            ld   b,a
            ld   a,11
            sub  b
            STV  bW
            LDV  bK                 ; найти единственного живого кандидата в FA(OS..OS+CT-1)
            add  a,a
            ld   hl,ARR_OS
            rst  00h
            ld   e,(hl)
            inc  hl
            ld   d,(hl)
            ex   de,hl
            ld   (bI),hl
            ex   de,hl
            LDV  bK
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
            LDV  bK
            add  a,a
            ld   hl,ARR_PD
            rst  00h
            ld   (hl),e
            inc  hl
            ld   (hl),d
            SETV bFL,1
            LDV  bX                 ; A1=X-1: B1=Y-1: A2/B2 по ориентации
            dec  a
            STV  bA1
            LDV  bY
            dec  a
            STV  bB1
            LDV  bO
            or   a
            jp   nz,L4323a
            LDV  bLK
            ld   b,a
            LDV  bX
            add  a,b
            STV  bA2
            LDV  bY
            inc  a
            STV  bB2
            jp   L4324
L4323a:     LDV  bX
            inc  a
            STV  bA2
            LDV  bLK
            ld   b,a
            LDV  bY
            add  a,b
            STV  bB2
L4324:      LDV  bA1                ; FOR U=A1 TO A2: FOR V=B1 TO B2
            STV  bU
L4324a:     LDV  bB1
            STV  bV
L4324b:     CPV  bU,10
            jp   nc,L4328
            CPV  bV,10
            jp   nc,L4328
L4325:      SETV bKN,1  ; FOR KN=1 TO ZT: IF KN<>K THEN USR1(KN*256+U*16+V)
L4325a:     LDV  bK
            ld   b,a
            LDV  bKN
            cp   b
            jp   z,L4326
            ld   h,a
            LDV  bU
            add  a,a
            add  a,a
            add  a,a
            add  a,a
            ld   b,a
            LDV  bV
            add  a,b
            ld   l,a
            call eng_kill1
L4326:      INCV bKN
            LDV  bZT
            cp   (hl)
            jp   nc,L4325a
            LDV  bX                 ; на самом корабле буй не ставится: O=0 — V=Y и X<=U<X+LK,
            ld   b,a                ; O=1 — то же с парами (X,U) и (Y,V) наоборот
            LDV  bU
            ld   c,a
            LDV  bY
            ld   d,a
            LDV  bV
            ld   e,a
            LDV  bO
            or   a
            jp   z,L4326o
            ld   a,b
            ld   b,d
            ld   d,a
            ld   a,c
            ld   c,e
            ld   e,a
L4326o:     ld   a,e
            cp   d
            jp   nz,L4327
            ld   a,c
            sub  b
            jp   c,L4327
            ld   b,a
            LDV  bLK
            cp   b
            jp   z,L4327
            jp   c,L4327
            jp   L4328
L4327:      LDV  bV                 ; IF PM(U,V)=0 AND BZ(U,V)<>3 THEN буй (176)
            ld   e,a
            LDV  bU
            call open_xy
            jp   nz,L4328
            LDV  bU
            STV  bC
            LDV  bV
            STV  bR
            ld   a,176
            call buoy_cr
L4328:      INCV bV
            LDV  bB2
            cp   (hl)
            jp   p,L4324b
            INCV bU
            LDV  bA2
            cp   (hl)
            jp   p,L4324a
L4329:      INCV bK
            LDV  bZT
            cp   (hl)
            jp   nc,L4320a
            CPV  bFL,1
            jp   z,L4320
L4336:      LDV  bBL                ; IF BL>0 THEN RETURN
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
            STV  bC
            ld   a,b
            STV  bR
            ld   e,b
            ld   a,c
            call open_xy
            jp   nz,L4339
            ld   a,160
            call buoy_cr
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

s_hits:         TXT  "HITS:"
s_press_space:  TXT  "Press SPACE to continue ..."
s_enemy_hits:   TXT  "ENEMY HITS:"
