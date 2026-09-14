; ============================================================================
; macros.asm — компактный доступ к байтам страницы переменных (varpage, см. game_bss.asm):
; 2 байта вместо 3. Регистры, кроме A (у LDV), и флаги не меняются.
; ============================================================================
            MACRO LDV adr
            rst  08h
            db   low (adr)
            ASSERT high (adr) == high varpage
            ENDM
            MACRO STV adr
            rst  30h
            db   low (adr)
            ASSERT high (adr) == high varpage
            ENDM
; CPV v,K: A = (v), флаги — от cp K (= LDV v / cp K)
            MACRO CPV adr,k
            rst  10h
            db   low (adr), k
            ASSERT high (adr) == high varpage
            ENDM
; INCV v: HL = v, inc (hl) (= ld hl,v / inc (hl)); A не меняется
            MACRO INCV adr
            rst  18h
            db   low (adr)
            ASSERT high (adr) == high varpage
            ENDM
; SETV v,K: (v) = A = K, флаги не меняются (= ld a,K / STV v)
            MACRO SETV adr,k
            rst  20h
            db   low (adr), k
            ASSERT high (adr) == high varpage
            ENDM
; ZEROV v: (v) = A = 0, флаги как у xor a (= xor a / STV v)
            MACRO ZEROV adr
            rst  28h
            db   low (adr)
            ASSERT high (adr) == high varpage
            ENDM

; ---------------------------------------------------------------- тексты
; Строки в исходниках — UTF-8, заглавные русские буквы; U() переводит их во внутреннюю
; кодировку шрифта (таблица ENC из build/data/dict.lua, см. tools/mkdata.py): 20h..40h — как
; ASCII, А = 41h ... Я = 5Eh, Й = 5Fh (Ё = Е). Латиница и прочее — ошибка сборки.
; TXT "строка" — строка, сжатая словарём (build/data/dict.lua, строит tools/mkdata.py):
; байт >= 80h — слово словаря (dict в dict.inc), 0 — конец. Разбор — оптимальный (ДП).
; TXR "строка" — те же знаки без словаря и без 0 (для кода, читающего байты подряд).
            LUA PASS1
            dofile("build/data/dict.lua")
            function U(s)
              s = s:match('^"(.*)"$') or s
              local o = {}
              for _, c in utf8.codes(s) do
                local b = ENC[c]
                if not b then
                  if c >= 32 and c <= 64 then b = c
                  else error("знак вне шрифта: " .. utf8.char(c) .. " в строке " .. s) end
                end
                o[#o + 1] = string.char(b)
              end
              return table.concat(o)
            end
            function R(s)
              s = U(s)
              for i = 1, #s do _pc("db " .. s:byte(i)) end
            end
            function T(s)
              s = U(s)
              local n = #s
              local bc, bw, ch = {}, {}, {}
              bc[n + 1], bw[n + 1] = 0, 0
              for i = n, 1, -1 do
                local c, w, k0 = bc[i + 1] + 1, bw[i + 1], nil
                for k, wd in ipairs(DICT) do
                  local l = #wd
                  if s:sub(i, i + l - 1) == wd then
                    local c2, w2 = bc[i + l] + 1, bw[i + l] + 1
                    if c2 < c or (c2 == c and w2 < w) then c, w, k0 = c2, w2, k end
                  end
                end
                bc[i], bw[i], ch[i] = c, w, k0
              end
              local i = 1
              while i <= n do
                if ch[i] then _pc("db " .. (127 + ch[i])); i = i + #DICT[ch[i]]
                else _pc("db " .. s:byte(i)); i = i + 1 end
              end
              _pc("db 0")
            end
            ENDLUA
            MACRO TXT str
            DEFINE+ _TXTA str
            LUA ALLPASS
            T(sj.get_define("_TXTA"))
            ENDLUA
            ENDM
            MACRO TXR str
            DEFINE+ _TXTA str
            LUA ALLPASS
            R(sj.get_define("_TXTA"))
            ENDLUA
            ENDM
