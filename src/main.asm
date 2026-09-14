; ============================================================================
; IRONCLAD — порт с MSX2 на Вектор-06Ц. Точка сборки.
;   tools/sjasmplus --i8080 --sld=build/ironclad.sld --lst=build/ironclad.lst src/main.asm
; Образ .rom грузится с $0100 и стартует с $0100.
; ============================================================================
            DEVICE NOSLOT64K

STACK_TOP   equ 8000h

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
            call vec_init
            ld   hl,1
            ld   (rnd_seed),hl
            IFDEF LIBTEST
            jp   libtest
            ELSE
            jp   setup_main
            ENDIF

            include "vec.asm"
            include "gfx.asm"
            include "snd.asm"
            include "zx0.asm"
            include "util.asm"

            IFDEF LIBTEST
            include "libtest.asm"
            ELSE
            include "page.asm"
            include "setup.asm"
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
            include "../build/data/tiles.inc"
            include "../build/data/qr.inc"
            IFNDEF NOIMG
img_title:  incbin "../build/data/title.zx0"
img_defeat: incbin "../build/data/defeat.zx0"
img_victory: incbin "../build/data/victory.zx0"
            ENDIF

image_end:
            ; ---------------------------------------------------------------- BSS
bss_start:
            include "bss.asm"
bss_end:
            ASSERT bss_end <= STACK_TOP - 256

            SAVEBIN "build/ironclad.rom", 100h, image_end-100h
            DISPLAY "образ: ", /D, image_end-100h, " Б; BSS: ", /D, bss_end-bss_start, " Б; свободно под стек: ", /D, STACK_TOP-bss_end
