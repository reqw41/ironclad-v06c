; ============================================================================
; game_bss.asm — переменные и массивы BASIC (DEFINT A-Z).
; Блок game_vars обнуляется при каждом «RUN» (старт игры/меню), как делает
; MSX-BASIC; блок persist (сессионная память движка, настройки из меню) — нет.
; Массивы, которые читает движок, — в раскладке MSX-BASIC: int16, A(i,j) = база + (i + j*(dim1+1))*2.
; Прочие — байтовые, где значения заведомо в 0..255 (или -128..127).
; ============================================================================

; ---------------------------------------------------------------- переживают RUN
persist_start:
            IFDEF ENGINE_STUB
            include "engine_stub_bss.inc"
            ELSE
            include "engine/engine_bss.inc"
            ENDIF
; ---------------------------------------------------------------- страница переменных
; От varpage до varpage_end — одна 256-байтная страница: к её байтам игра обращается
; командами LDV/STV (rst + младший байт адреса, см. util.asm). Порядок внутри — любой,
; кроме: имена BASIC (b??, s??) идут подряд (стенд трассы сравнивает переменную
; до следующего имени), cfg_TU..cfg_SB — в порядке SETUP.BAS (161 читает их подряд).
varpage:
; настройки, которые SETUP.BAS кладёт в &HDDF5..&HDE00 (161 читает их PEEK-ами)
cfg_TU:     ds 1
cfg_AM:     ds 1
cfg_XS:     ds 1
cfg_SV:     ds 1
cfg_FL:     ds 1
cfg_QS:     ds 1
cfg_BD:     ds 1        ; -(BD>0)
cfg_DL:     ds 1
cfg_BO:     ds 1
cfg_SB:     ds 1
cfg_magic:  ds 2        ; 165,195 = настройки заданы
cfg_fam:    ds 1        ; какую программу запустил SETUP: 0 IRONCLAD, 1 SALVO, 2 SALVOP, 3 BARRAGE
smem_magic: ds 2        ; &HDDF3/&HDDF4 = 165,195: сессионные счётчики движка заведены
persist_end:

; Массивы только сборки IRONCLAD.BAS (GA, GB, QX, QY) лежат в буфере кандидатов движка FA:
; FA нужен только сборкам залпов, эти — только STD; game_run обнуляет их для STD.
ARR_GA      equ ENG_FA              ; GA(7,4) int16
ARR_GB      equ ENG_FA+80           ; GB(7,5) int16
ARR_QX      equ ENG_FA+176          ; QX/QY (без DIM — неявно (10,10); используются SH<=6, I<=4)
ARR_QY      equ ENG_FA+236
STD_OVL_END equ ENG_FA+296

; ---------------------------------------------------------------- переменные BASIC (RUN обнуляет)
game_vars:
; ---------------------------------------------------------------- состояние страниц (порт), байты в странице
pg_vis:     ds 1        ; что сейчас в видеопамяти: 0/1 = страница игры, 2 = иной экран
ai_left:    ds 1        ; кадров до конца обязательного показа сообщения ИИ «ENEMY ...»
                        ; (ставят его выводы, ISR уменьшает до 0, ai_wait ждёт 0)
cur_on:     ds 1        ; курсор-спрайт (страница 0) виден
cur_x:      ds 1        ; KX, KY
cur_y:      ds 1
gh_on:      ds 1        ; призрак корабля на странице 1 (1664-1668)
gh_rw:      ds 1        ; копия RW,RX,RY,RH,SY,SX (1668) — в том же порядке, что bRW..bSX
gh_rx:      ds 1
gh_ry:      ds 1
gh_rh:      ds 1
gh_sy:      ds 1
gh_sx:      ds 1
gh_od:      ds 1        ; композит 3204: ориентация и тайлы кораблей
gh_s:       ds 1
sl_n:       ds 1        ; строка «GAME» (1396): сколько раз напечатана поверх (1 или 2)
rp_tmp:     ds 4
br_n:       ds 1
co_pg:      ds 1
cd_n:       ds 1
gh_i:       ds 1
gh_n:       ds 1
gh_c0:      ds 1
cw_pg:      ds 1
hr_q:       ds 1
hr_j:       ds 1
hr_x:       ds 1
hr_x0:      ds 1
hk_y:       ds 1
sm_k:       ds 1
gw_k:       ds 1        ; ga_walk (1961/1963): 0 или 2
; ---------------------------------------------------------------- переменные BASIC
; байтовые
bKA: ds 1
bCX: ds 1
bCY: ds 1
bAX: ds 1
bAY: ds 1
bS:  ds 1
bOD: ds 1
bLG: ds 1
bDX: ds 1
bDY: ds 1
bRW: ds 1
bRX: ds 1
bRY: ds 1
bRH: ds 1
bSY: ds 1
bSX: ds 1
            ASSERT bSX-bRW == 5 && bAY == bAX+1 && bCY == bCX+1 && bDY == bDX+1 && bRY == bRX+1
bCL: ds 1
bDP: ds 1
bKX: ds 1
bKY: ds 1
bFB: ds 1
bFL: ds 1
bAC: ds 1
bUA: ds 1
bLX: ds 1       ; может быть -1
bLY: ds 1
bLS: ds 1
bLO: ds 1
bP9: ds 1
bKM: ds 1
bR8: ds 1
bLK: ds 1
bO:  ds 1
bW:  ds 1
bCF: ds 1
bT4: ds 1
bU:  ds 1       ; со знаком
bV:  ds 1
bKN: ds 1
bRD: ds 1
bSH: ds 1
bSD: ds 1
bC:  ds 1       ; со знаком (1960: C=X-U1 бывает -1)
bR:  ds 1
            ASSERT bR == bC+1 && bKY == bKX+1
bAP: ds 1
bK:  ds 1
bP:  ds 1
bL:  ds 1       ; со знаком
bA:  ds 1       ; со знаком
bB:  ds 1
bQ:  ds 1       ; 160/176 или номер тайла
bN:  ds 1
bX2: ds 1
bY2: ds 1
bNS: ds 1
bNF: ds 1
bNA: ds 1
bKL: ds 1
bE9: ds 1
bTU: ds 1
bAM: ds 1
bXS: ds 1
bSV: ds 1
bQS: ds 1
bBD: ds 1
bBO: ds 1
bSB: ds 1
bNK: ds 1
bZT: ds 1
bBL: ds 1       ; со знаком
bPZ: ds 1
bR9: ds 1
bX9: ds 1
bDL: ds 1
bRP: ds 1
bTT: ds 1
bGN: ds 1
bGW: ds 1
bGC: ds 1
bFS: ds 1
bSL: ds 1
bTE: ds 1
bTP: ds 1
bWN: ds 1
bNT: ds 1
bNP: ds 1
bSU: ds 1
bTD: ds 1
bHX: ds 1
bHY: ds 1
bPA: ds 1
bTN: ds 1
bMY: ds 1
bMC: ds 1
bNH: ds 1
bYP: ds 1
bY0: ds 1
bE:  ds 1
bU1: ds 1       ; со знаком
bV1: ds 1
bU2: ds 1
bV2: ds 1
bHW: ds 1
bEK: ds 1
bSN: ds 1
bSW: ds 1
bFX: ds 1
bFY: ds 1
bBX: ds 1
bBY: ds 1
bD:  ds 1
bE1: ds 1
bE2: ds 1
bSM: ds 1
bTM: ds 1
bDA: ds 1
bAB: ds 1
bNC: ds 1
bWC: ds 1
bSK: ds 1
bSJ: ds 1
bFP: ds 1
bMD: ds 1
bAF: ds 1
bVP: ds 1
bS1: ds 1
bS2: ds 1
bSF: ds 1
bNV: ds 1
bAL: ds 1
bHZ: ds 1
bPG: ds 1
bRU_: ds 1
bKQ: ds 1       ; KQ$ (один знак или 0 = "")
bK_: ds 1       ; K$
bK2: ds 1       ; K2$
; 16-битные со знаком
bI:  ds 2
bJ:  ds 2
bT:  ds 2
bT2: ds 2
bT3: ds 2
bT5: ds 2
bSC: ds 2
bNB: ds 2
bX:  ds 2
bY:  ds 2
bM:  ds 2
bAT: ds 2
sS1: ds 2       ; S1$ (в блоке скаляров: render_full сохраняет его)
bA1: ds 1
bB1: ds 1
bA2: ds 1
bB2: ds 1
; меню (SETUP.BAS)
bMI:        ds 1
bMG:        ds 1
bBI:        ds 1
varpage_end:
            ASSERT high varpage == high (varpage_end-1)
bRT:        ds 2
sRN:        ds 2
sBM:        ds 2
; строки (0 в конце)
sMS: ds 64      ; MS$
sCO: ds 4       ; CO$
sCE: ds 4       ; CE$
sSS: ds 52      ; SS$ (до 11 кораблей по 4 знака)
sES: ds 52      ; ES$
sT:  ds 20      ; рабочий буфер склейки
; массивы движка (int16, раскладка MSX-BASIC)
ARR_MG: ds 144*2
ARR_CC: ds 8*2
ARR_CT: ds 8*2
ARR_OS: ds 8*2
ARR_PD: ds 8*2
ARR_BZ: ds 100*2
ARR_HK: ds 8*2
ARR_SZ: ds 12*2
ARR_PH: ds 12*2
ARR_TX: ds 11*2
ARR_TY: ds 11*2
ARR_PM: ds 100*2
ARR_CM: ds 100*2
ARR_PS: ds 100*2
ARR_CS: ds 100*2
            ASSERT ARR_CM == ARR_PM+200 && ARR_PS == ARR_CM+200
; байтовые массивы
ARR_GT: ds 11
ARR_RU: ds 10
ARR_PX: ds 12*5         ; PX(SH,I) = SH + I*12
ARR_PY: ds 12*5
ARR_QH: ds 12
ARR_HS: ds 12*5         ; HS(SH,J) = SH + J*12
            ASSERT ARR_HS == ARR_QH+12
ARR_SQ: ds 11
ARR_N:  ds 12*2         ; N$(I) — указатели на имена кораблей
; ---------------------------------------------------------------- состояние страниц (порт), вне страницы
cellrec:    ds 2*100*4  ; слои клеток страниц 0 и 1: 0..31 тайл, 32+n белая, 64+n жёлтая, 96+n красная цифра, FF пусто
at_rec:     ds 2*16     ; содержимое поля ЦЕЛЬ: на страницах 0/1 (строка, 0 = пусто)
gh_gt:      ds 5
msg_rec:    ds 2*(2+34) ; строки сообщений MY=192 и MY=202: цвет, флаг, текст
sl_v1:      ds 4        ; GN,BO,GW,GC первой печати
sl_v2:      ds 4        ; второй (2238)
cd_p:       ds 2
game_vars_end:
