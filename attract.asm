; TMNT attract mode
; by Ricardo Bittencourt 2014
; Last modification: 2014-06-07

; Sequence of animation frames
; 1301 - 1373 : title_bounce
; 1374 - 1401 : title_slide
; 1402 ->     : title_stand

        output  attract.com
            
        org     0100h

; MSX bios
restart         equ     00000h  ; Return to DOS
bdos            equ     00005h  ; BDOS entry point
dosver          equ     0006Fh  ; Get MSX-DOS version number
strout          equ     00009h  ; Print string terminated in $
open            equ     00043h  ; Open a file
read            equ     00048h  ; Read from a file
close           equ     00045h  ; Close a file
romslt          equ     0FFF7h  ; Slot of main rom (byte)
mainrom         equ     0FFF6h  ; Slot of main rom (word)
subrom          equ     0FAF7h  ; Slot of sub rom (word)
msxversion      equ     0002Dh  ; MSX version
rdslt           equ     0000Ch  ; Read a byte from a given slot
callf           equ     0001Ch  ; Call far
chgmod          equ     000D1h  ; Change SCREEN mode
chget           equ     0009Fh  ; Read keyboard
ldirvm          equ     0005Ch  ; Copy RAM to VRAM
setplt          equ     0014Dh  ; Set palette color
wrtvdp          equ     0012Dh  ; Write a VDP register
iniplt          equ     00141h  ; Reset the palette
irq             equ     00038h  ; irq vector
pcm             equ     000A4h  ; turboR PCM port
pmcntl          equ     000A5h  ; turboR PCM config
systml          equ     000E6h  ; turboR system timer
beep            equ     000C0h  ; Play a beep
disscr          equ     00041h  ; Disable screen
enascr          equ     00044h  ; Enable screen
vdpr0           equ     0F3DFh  ; Copy of VDP register 0
vdpr1           equ     0F3E0h  ; Copy of VDP register 1
vdpr9           equ     0FFE8h  ; Copy of VDP register 9
vdpr8           equ     0FFE7h  ; Copy of VDP register 8
bigfil          equ     0016Bh  ; Fill vram with a value

; Set a VDP register
; Input: A = value
; Destroys: A
        macro   VDPREG reg
        out     (099h), a
        ld      a, 128 + reg
        out     (099h), a
        endm

; Start of main program.
start:
        call    init
start_attract:
        ; Reset the animation
        xor     a
        ld      (vertical_scroll), a
        ld      hl, 1280
        ld      (current_frame), hl

        ; install new interrupt handler
        di
        ld      a, (irq)
        ld      (save_irq), a
        ld      hl, (irq + 1)
        ld      (save_irq + 1), hl

        ld      a, 0C3h
        ld      (irq), a
        ld      de, (current_frame)
        ld      hl, handles
        add     hl, de
        add     hl, de
        ld      e, (hl)
        inc     hl
        ld      d, (hl)
        ex      de, hl
        ld      (irq + 1), hl
        ei

        ; Init turboR PCM.
        ld      a, 3
        out     (pmcntl), a
        in      a, (systml)

        xor     a
        out     (systml), a

        ; main loop
        ld      hl, temp
        ld      bc, 36986
        in      a, (systml)
        ld      d, a
loop:
        ; Play a sample
        ld      a, (hl)
        out     (pcm), a

wait:   
        ; Wait enough to hit 11025Hz
        in      a, (systml)
        cp      23
        jr      c, wait
        xor     a
        out     (systml), a

        inc     hl
        dec     bc
        ld      a, b
        or      c
        jr      nz, loop

        ; Restore system irq
        call    restore_irq

        ; Enable screen
        di
        ld      a, (vdpr1)
        or      64
        VDPREG  1
        ei

        ; Wait for a key and exit if not ESC
        ld      iy, (mainrom)
        ld      ix, chget
        call    callf
        cp      27
        jp      nz, start_attract

        ; Restore palette.
        ld      iy, (subrom)
        ld      ix, iniplt
        call    callf

        ; Restore text mode.
        ld      iy, (subrom)
        ld      ix, chgmod
        xor     a
        call    callf
                
        ; Exit to DOS.
        jp      restart

; Initialization.
init:
        ; Check if DOS2 is present.
        call    check_dos2
        ld      de, str_dos2_not_found
        jp      c, abort

        ; Check if MSX is a turboR.
        call    check_turbor
        ld      de, str_not_turbor
        jp      c, abort

        ; Read opening screen.
        ld      de, opening_filename
        ld      hl, 256 * 192 / 2
        call    load_file

        ; Change to SCREEN 5.
        ld      iy, (subrom)
        ld      ix, chgmod
        ld      a, 5
        call    callf

        ; Disable screen
        ld      iy, (mainrom)
        ld      ix, disscr
        call    callf

        ; Clear the vram
        ld      iy, (mainrom)
        ld      ix, bigfil
        ld      hl, 0
        ld      bc, 08000h
        xor     a
        call    callf

        ; Set border to color 0.
        di
        xor     a
        VDPREG  7

        ; Enable 192 lines.
        ld      a, (vdpr9)
        and     127
        VDPREG  9

        ; Enable 16 colors and turn off sprites.
        ld      a, (vdpr8)
        or      32 + 2
        VDPREG  8
        ei

        ; Copy data to vram.
        ld      iy, (mainrom)
        ld      ix, ldirvm
        ld      hl, temp
        ld      de, 0
        ld      bc, 256 * 192 / 2
        call    callf

        ; Copy palette.
        ld      d, 0
        ld      hl, palette
        ld      b, 16
copy_palette:
        ld      a, (hl)
        inc     hl
        ld      e, (hl)
        inc     hl
        call    set_palette
        inc     d
        djnz    copy_palette

        ; load sample pcm data
        ld      de, title_music_filename
        ld      hl, 36986
        call    load_file

        ; Beep
        ld      iy, (mainrom)
        ld      ix, beep
        call    callf

        ; wait for a key
        ld      iy, (mainrom)
        ld      ix, chget
        call    callf

        ret

; ----------------------------------------------------------------
; Helpers for the states.

; Check if a virq has happened.
        macro   PREAMBLE_VERTICAL
        ex      af, af'
        in      a, (099h)
        and     a
        jp      p, return_irq
        endm

; Enable screen
        macro   ENABLE_SCREEN
        ld      a, (vdpr1)
        or      64
        VDPREG  1
        endm

; Disable screen
        macro   DISABLE_SCREEN
        ld      a, (vdpr1)
        and     255 - 64
        VDPREG  1
        endm

; ----------------------------------------------------------------
; State: title_bounce
; Top of TMNT logo bounces in the screen.
title_bounce:
        PREAMBLE_VERTICAL

        exx
        ; Adjust vertical scroll.
        ld      a, (vertical_scroll)
        ld      hl, scroll_data
        ld      e, a
        ld      d, 0
        add     hl, de
        ld      a, (hl)
        VDPREG  23
        ld      a, (vertical_scroll)
        inc     a
        ld      (vertical_scroll), a

        ; If the logo is too low, disable screen
        ld      a, (hl)
        cp      80h
        jr      nc, title_bounce_v_disable

        ; Program hsplit.
        ld      a, 46
        VDPREG  19

        ; Enable screen.
        ld      a, (vdpr1)
        or      64
        VDPREG  1

        ; install horizontal split
        ld      a, 1 
        VDPREG  15
        ld      hl, title_bounce_h_disable
        ld      (irq + 1), hl

        ; enable h interrupt.
        ld      a, (vdpr0)
        or      16
        VDPREG  0

        jp      return_irq_exx

title_bounce_v_disable:
        ; Program hsplit.
        ld      a, 10
        VDPREG  19

        ; Disable screen.
        ld      a, (vdpr1)
        or      255 - 64
        VDPREG  1

        ; install horizontal split
        ld      a, 1 
        VDPREG  15
        ld      hl, title_bounce_h_enable
        ld      (irq + 1), hl

        ; enable h interrupt.
        ld      a, (vdpr0)
        or      16
        VDPREG  0

        jp      return_irq_exx

; H handler to disable screen
title_bounce_h_disable:
        ex      af,af'
        in      a, (099h)
        rrca
        jp      nc, return_irq
        
        ; Disable screen
        ld      a, (vdpr1)
        and     128 + 63
        VDPREG  1

        ; Install vertical split
        ld      a, 0
        VDPREG  15

        ; Disable h interrupt.
        ld      a, (vdpr0)
        and     255 - 16      
        VDPREG  0

        jp      frame_end_exx

; H handler to enable screen
title_bounce_h_enable:
        ex      af,af'
        in      a, (099h)
        rrca
        jr      nc, return_irq
        
        ; Enable screen
        ld      a, (vdpr1)
        or      64
        VDPREG  1

        ; Program hsplit.
        ld      a, 46
        VDPREG  19

        ; install horizontal split
        exx
        ld      hl, title_bounce_h_disable
        ld      (irq + 1), hl
        jp      return_irq_exx

; ----------------------------------------------------------------
; State: title_stand
; Show the entire logo.

title_slide:
title_stand:
        PREAMBLE_VERTICAL
        ENABLE_SCREEN
        jp      frame_end_exx

; ----------------------------------------------------------------
; State: disable_screen
; Turn off the screen.

disable_screen:
        PREAMBLE_VERTICAL

        ; Disable screen
        ld      a, (vdpr1)
        and     128 + 63
        VDPREG  1
        jp      frame_end_exx

; ----------------------------------------------------------------

; Exit common to all frames
frame_end_exx:
        exx
frame_end:
        ld      de, (current_frame)
        inc     de
        ld      (current_frame), de
        ld      hl, handles
        add     hl, de
        add     hl, de
        ld      a, (hl)
        ld      (irq + 1), a
        inc     hl
        ld      a, (hl)
        ld      (irq + 2), a
return_irq_exx:
        exx
return_irq:
        ex      af, af'
        ei
        ret

; ----------------------------------------------------------------
; Utils

; Restore the VDP interrupt settings.
restore_irq:
        di

        ; Disable h interrupt.
        ld      a, (vdpr0)
        and     255 - 16      
        VDPREG  0

        ; Clear H-irq flag
        ld      a, 1
        VDPREG  15
        in      a, (099h)

        ; Clear V-irq flag
        ld      a, 0
        VDPREG  15
        in      a, (099h)

        ; Reload old interrupt handler
        ld      a, (save_irq)
        ld      (irq), a
        ld      hl, (save_irq + 1)
        ld      (irq + 1), hl
        ei
        ret

; Set one color of the palette.
; Input: D = color number, A = RB, E = 0G
set_palette:
        di
        push    af
        ld      a, d
        VDPREG  16
        pop     af
        out     (09Ah), a
        ld      a, e
        out     (09Ah), a
        ei
        ret

; Check if DOS2 is present.
; Output: SCF if DOS2 not found.
; Based on http://map.grauw.nl/resources/dos2_functioncalls.php#_dosver
check_dos2:
        ld      c, dosver
        call    bdos
        add     a, 255
        ret     c
        ld      a, b
        cp      2
        ret

; Check if turboR is present.
; Output: SCF if turboR not found.
check_turbor:
        ld      a, (romslt)
        ld      hl, msxversion
        call    rdslt
        cp      3
        ret

; Check bdos error and abort if necessary.
; Input: a = error if nz
; Destroy: de
check_bdos_error:
        ld      de, str_read_error
        or      a
        ret     z
        ; fall through

; Print error message, abort and return to dos.
; Input: de = error message terminated in $
abort:
        ld      c, strout
        call    bdos
        jp      restart

; Load a file.
; Input: DE = filename in asciiz, HL = size
load_file:
        push    hl
        ld      c, open
        xor     a
        ld      b, a
        call    bdos
        call    check_bdos_error

        ld      de, temp        
        pop     hl
        push    bc
        ld      c, read
        call    bdos
        call    check_bdos_error
        pop     bc

        ld      c, close
        call    bdos
        call    check_bdos_error
        ret

; Misc strings.
str_dos2_not_found:     db      "MSX-DOS 2 not found, sorry.$"
str_not_turbor:         db      "This MSX is not a turboR, sorry.$"
str_read_error:         db      "Error reading from disk, sorry.$"
opening_filename:       dz      "attract.001"
title_music_filename:   dz      "attract.002"

palette:                incbin  "title_bounce_palette.bin"
scroll_data:            incbin  "title_bounce_scroll.bin"
handles:                include "handles.inc"

; Variables.

save_irq:               db      0,0,0
vertical_scroll:        db      0
current_frame:          dw      1301

temp            equ     04000h

        end

