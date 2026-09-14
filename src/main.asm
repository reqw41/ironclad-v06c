; ============================================================================
; IRONCLAD — порт с MSX2 на Вектор-06Ц. Точка сборки.
;   tools/sjasmplus --i8080 --sld=build/ironclad.sld --lst=build/ironclad.lst src/main.asm
; Образ .rom грузится с $0100 и стартует с $0100.
; ============================================================================
            DEVICE NOSLOT64K
            include "macros.asm"
            IFDEF NOIMG
            DEFINE NOTITLE
            ENDIF

; Память (8-цветный режим): $0000..$00FF — вектор RST7, маска тайла, переменные библиотеки;
; $0100..$7FFF — код и данные (образ .rom); $8000..$DFFF — экран (3 плоскости);
; $E000..$FFFF — плоскость, которой нет на экране: переменные, массивы, стек.
STACK_TOP   equ 0                   ; стек растёт вниз от $FFFF
HIBSS       equ 0E000h
LOWBSS      equ 0060h
            include "lowbss.asm"

            org  100h
start:
            di
            ld   sp,STACK_TOP
            ; обнулить BSS
            ld   hl,bss_start
            ld   de,bss_end-bss_start
bz_1:       xor  a
            ld   (hl),a
            inc  hl
            dec  de
            ld   a,d
            or   e
            jp   nz,bz_1
            ld   hl,LOWBSS              ; и переменные под $0100
            ld   b,100h-LOWBSS
lz_1:       ld   (hl),0
            inc  hl
            dec  b
            jp   nz,lz_1
            ld   hl,rst0_code           ; RST 0 = add_a_hl прямо в векторе (с nop,nop: слово по $0000 = 0)
            ld   de,0
            ld   bc,rst0_end-rst0_code
            call memcpy
            ld   hl,rst_tab             ; векторы RST 1..6 -> частые подпрограммы
            ld   de,8
rvs_1:       ld   a,(hl)
            or   a
            jp   z,rvs_2
            ld   a,0C3h
            ld   (de),a
            inc  de
            ld   a,(hl)
            ld   (de),a
            inc  hl
            inc  de
            ld   a,(hl)
            ld   (de),a
            inc  hl
            ld   a,e
            add  a,6
            ld   e,a
            jp   rvs_1
rvs_2:       ld   hl,font_zx0            ; шрифт -> BSS
            ld   de,font_data
            call dzx0
            IFDEF LIBTEST
            call tiles_load
            ENDIF
            call vec_init
            ld   a,8
            ld   (gfx_pitch),a
            ld   hl,1
            ld   (rnd_seed),hl
            IFDEF LIBTEST
            jp   libtest
            ELSE
            jp   setup_main
            ENDIF

rst_tab:    dw rst_ldv, rst_cpv, rst_incv, rst_setv, rst_zerov, rst_stv
            db 0
; RST 0: HL += A. Два nop в начале: байты $0000/$0001 = 0 (нулевой указатель на строку = "")
rst0_code:  nop
            nop
            add  a,l
            ld   l,a
            ret  nc
            inc  h
            ret
rst0_end:
add_a_hl    equ 2
            include "vec.asm"
            include "gfx.asm"
            include "snd.asm"
            include "zx0.asm"
            include "util.asm"

            IFDEF LIBTEST
            include "libtest.asm"
            ELSE
            include "page.asm"
            include "game.asm"
            include "gdraw.asm"
            include "gai.asm"
            include "gmisc.asm"
            include "gsalvo.asm"
            IFDEF ENGINE_STUB
            include "engine_stub.asm"
            ELSE
            include "engine/engine.asm"
            include "engine_glue.asm"
            ENDIF
            ENDIF

; ---------------------------------------------------------------- данные
            include "../build/data/palettes.inc"
            include "../build/data/font.inc"
            include "../build/data/dict.inc"
            include "../build/data/tiles.inc"
tiles_zx0:  incbin "../build/data/tiles.zx0"
font_zx0:   incbin "../build/data/font.zx0"
            IFNDEF NOIMG
            IFNDEF NOTITLE
img_title:  incbin "../build/data/title.zx0"
            ENDIF
img_defeat: incbin "../build/data/defeat.zx0"
img_victory: incbin "../build/data/victory.zx0"
            ENDIF
            IFNDEF LIBTEST
            IFNDEF OVL_PASS1
ovl_menu_zx0: incbin "../build/ovl_menu.zx0"   ; оверлей меню (последним: адреса выше не зависят от его размера)
            ENDIF
            ENDIF

image_end:
            ASSERT image_end <= 8000h
            ; ---------------------------------------------------------------- BSS (в плоскости $E000)
            org  HIBSS
bss_start:
            include "bss.asm"
bss_end:
            ASSERT bss_end <= 0FF00h            ; 256 Б на стек
            ASSERT bMI-bKA <= 288               ; render_full сохраняет скаляры в ARR_MG

            IFNDEF LIBTEST
            ; ---------------------------------------------------------------- оверлей меню
            ; SETUP.BAS исполняется из области тайлов (в меню тайлы не рисуются; game_run
            ; распаковывает их заново). build.sh: проход 1 (-DOVL_PASS1) пишет build/ovl_menu.bin,
            ; salvador сжимает его в build/ovl_menu.zx0, проход 2 кладёт сжатое в образ.
            org  OVL_BASE
ovl_menu:
            include "setup.asm"
ovl_menu_end:
            ASSERT ovl_menu_end <= OVL_END
            SAVEBIN "build/ovl_menu.bin", ovl_menu, ovl_menu_end-ovl_menu
            ENDIF

            SAVEBIN "build/ironclad.rom", 100h, image_end-100h
            DISPLAY "образ: ", /D, image_end-100h, " Б (свободно до $8000: ", /D, 8000h-image_end, "); BSS: ", /D, bss_end-bss_start, " Б (свободно в $E000: ", /D, 10000h-bss_end, ")"
