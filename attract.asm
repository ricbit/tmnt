; TMNT attract mode
; by Ricardo Bittencourt 2014

        output  attract.com
            
        org     0100h
        jp      start_main

; Required memory, in mapper 16kb selectors
selectors       equ     17

; Compile in debug mode or not
debug           equ     1

; ----------------------------------------------------------------
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
vdpr25          equ     0FFFAh  ; Copy of VDP register 25
bigfil          equ     0016Bh  ; Fill vram with a value
chgcpu          equ     00180h  ; Change CPU
hokvld          equ     0FB20h  ; Extended BIOS support
extbio          equ     0FFCAh  ; Extended BIOS entry point
get_p1          equ     00021h  ; Entry point for mapper get_p1
get_p2          equ     00027h  ; Entry point for mapper get_p2
put_p1          equ     0001eh  ; Entry point for mapper put_p1
put_p2          equ     00024h  ; Entry point for mapper put_p2
all_seg         equ     00000h  ; Allocate a mapper segment
disk_buffer     equ     04000h  ; Temp buffer for disk loading
vdp_vscroll     equ     00017h  ; VDP register for vertical scroll
vdp_hscroll_h   equ     0001Ah  ; VDP register for horizontal scroll, high
vdp_hscroll_l   equ     0001Bh  ; VDP register for horizontal scroll, low
vdp_sprite_patt equ     00006h  ; VDP register for sprite pattern base addr
vdp_hsplit_line equ     00013h  ; VDP register for horizontal split line
vdp_timp        equ     00008h  ; VDP logic operator TIMP
vdp_set_page    equ     00002h  ; VDP register for set page
vdp_hmmm_size   equ     00010h  ; Number of bytes required to perform a HMMM
vdp_status      equ     0000Fh  ; VDP register to select status
vdp_palette     equ     00010h  ; VDP register to select palette index
openmsx_control equ     0002Eh  ; OpenMSX debug control port
openmsx_data    equ     0002Fh  ; OpenMSX debug data port

; ----------------------------------------------------------------
; VRAM layout

; VRAM Layout at the beginning:
; 00000-057FF city2 pixels
; 06000-07FFF back building patterns
; 08000-0E9FF city1 pixels
; 0EA00-0FFFF city preload 2
; 10000-1017F top building patterns
; 10700-114FF cloud2 pixels
; 11900-1287F must be all zeros, don't use
; 13000-1321F moon attributes
; 13800-16AFF moon patterns
; 17000-1727F top building attributes
; 17400-1767F back building attributes
; 18000-1A87F cloud3 pixels
; 1C680-1E67F city2 preload
; 1E680-1FFFF city line mask

cloud2_addr             equ     10000h
cloud3_addr             equ     18000h
city1_addr              equ     08000h
city2_addr              equ     00000h
city2_preload           equ     1C680h
city2_preload_2         equ     0EA00h
moon_pattern_addr       equ     13800h
moon_attr_addr          equ     13200h
top_building_attr_addr  equ     17200h
top_building_patt_addr  equ     10000h
city_line_mask_addr     equ     1E680h
back_building_patt_addr equ     06000h
back_building_attr_addr equ     17600h
title_addr              equ     08000h
city2_continue1_addr    equ     1FC80h
city2_continue2_addr    equ     18000h
city2_continue3_addr    equ     1A800h
pixels_alley1a_addr     equ     1E000h 
pixels_alley1b_addr     equ     18000h 

; ----------------------------------------------------------------
; Animation constants

theme_start_frame               equ     750
pcm_timer_period                equ     23
moon_pattern_base_hscroll       equ     108
down4_sprite_start_frame        equ     825
cloud_scroll_start_frame        equ     794
expand_city_line_frame          equ     805
disable_moon_sprites_frame      equ     805
copy_city_mask_last_frame       equ     814
top_building_attr_size          equ     101
city_scroll1_first_frame        equ     833
city_scroll1_last_frame         equ     843
city_scroll2_infinite           equ     847
city_scroll2_last_frame         equ     852
city_scroll4_first_frame        equ     858

; ----------------------------------------------------------------
; Helpers for the states.

; Set a VDP register
        macro   VDPREG reg
        out     (099h), a
        ld      a, 128 + reg
        out     (099h), a
        endm

; Set entire palette
        macro   SET_PALETTE
        xor     a
        VDPREG  vdp_palette
        ld      bc, (16 * 2) * 256 + 09Ah
        otir
        endm

; Set VRAM address to write
        macro   SET_VRAM_WRITE addr
        ld      a, addr >> 14
        VDPREG  14
        ld      a, addr and 255
        out     (099h), a
        ld      a, ((addr >> 8) and 03Fh) or 64
        out     (099h), a
        endm

; Queue VRAM address to write
        macro   QUEUE_VRAM_WRITE addr
        ld      b, addr >> 14
        ld      d, addr and 255
        ld      e, ((addr >> 8) and 03Fh) or 64
        endm

; Set display page.
        macro   SET_PAGE page
        ld      a, (page << 5) or 011111b
        VDPREG  vdp_set_page
        endm

; Check if a virq has happened.
        macro   PREAMBLE_VERTICAL
        ex      af, af'
        in      a, (099h)
        and     a
        jp      p, return_irq
        endm

; Check if a hirq has happened.
        macro   PREAMBLE_HORIZONTAL
        ex      af, af'
        in      a, (099h)
        rrca
        jp      nc, return_irq
        endm

; Enable screen
        macro   ENABLE_SCREEN
        ld      a, (vdpr1)
        or      64
        ld      (vdpr1), a
        VDPREG  1
        endm

; Disable screen
        macro   DISABLE_SCREEN
        ld      a, (vdpr1)
        and     255 - 64
        ld      (vdpr1), a
        VDPREG  1
        endm

; Set the line where the hsplit will happen
        macro   HSPLIT_LINE line
        ld      a, line
        VDPREG  vdp_hsplit_line
        endm

; Select which VDP status will be the default
        macro   VDP_STATUS reg
        ld      a, reg
        ld      (current_vdp_status), a
        VDPREG  vdp_status
        endm

; Load the next handle in the irq pointer.
        macro   NEXT_HANDLE handle
        ld      hl, handle
        ld      (irq + 1), hl
        endm
       
; Disable h interrupt.
        macro   DISABLE_HIRQ
        ld      a, (vdpr0)
        and     255 - 16      
        ld      (vdpr0), a
        VDPREG  0
        endm

; Enable h interrupt.
        macro   ENABLE_HIRQ
        ld      a, (vdpr0)
        or      16
        ld      (vdpr0), a
        VDPREG  0
        endm

; Turn on sprites.
        macro   SPRITES_ON
        ld      a, (vdpr8)
        and     255 - 2
        ld      (vdpr8), a
        VDPREG  8
        endm

; Turn off sprites.
        macro   SPRITES_OFF
        ld      a, (vdpr8)
        or      2
        ld      (vdpr8), a
        VDPREG  8
        endm

; Set sprite size to 16x16.
        macro   SPRITES_16x16
        ld      a, (vdpr1)
        or      2
        ld      (vdpr1), a
        VDPREG  1
        endm

; Enable two-pages h scroll with no masking.
        macro   WIDE_SCROLL
        ld      a, (vdpr25)
        or      1
        and     255 - 2
        ld      (vdpr25), a
        VDPREG  25
        endm

; Set sprite attribute table.
        macro   SPRITE_ATTR addr
        assert  (addr and ((1 << 10) - 1)) == (1 << 9)
        ld      a, (((addr >> 10) and 1Fh) << 3) or 7
        VDPREG  5
        ld      a, addr >> 15
        VDPREG  11
        endm

; Set sprite pattern table.
        macro   SPRITE_PATTERN addr
        assert  (addr and ((1 << 11) - 1)) == 0
        ld      a, addr >> 11
        VDPREG vdp_sprite_patt
        endm
        
; Set a VDP register to auto-increment.
        macro   VDP_AUTOINC reg
        ld      a, reg
        VDPREG 17
        endm

; Set the value of the h scroll.
        macro   SET_HSCROLL value
        ld      a, (value + 7) / 8
        VDPREG vdp_hscroll_h
        ld      a, ((value + 7) and 01F8h) - value
        VDPREG vdp_hscroll_l
        endm

; Set the value of the h scroll using indirect register access.
        macro   FAST_SET_HSCROLL value
        ld      a, (value + 7) / 8
        out     (09Bh), a
        ld      a, ((value + 7) and 01F8h) - value
        out     (09Bh), a
        endm

; VDP Command HMMV: fill rectangle with a color.
        macro   VDP_HMMV dx, dy, nx, ny, color
        db      36
        db      dx and 255
        db      dx >> 8
        db      dy and 255
        db      dy >> 8
        db      nx and 255
        db      nx >> 8
        db      ny and 255
        db      ny >> 8
        db      color
        db      0
        db      0C0h
        endm

; VDP Command YMMM: copy rectangle VRAM->VRAM on the Y direction.
        macro   VDP_YMMM sy, dx, dy, ny
        db      34
        db      sy and 255
        db      sy >> 8
        db      dx and 255
        db      dx >> 8
        db      dy and 255
        db      dy >> 8
        db      0
        db      0
        db      ny and 255
        db      ny >> 8
        db      0
        db      0
        db      0E0h
        endm

; VDP Command LMMM: copy rectangle VRAM->VRAM using logic operators.
        macro   VDP_LMMM sx, sy, dx, dy, nx, ny, op
        db      32
        db      sx and 255
        db      sx >> 8
        db      sy and 255
        db      sy >> 8
        db      dx and 255
        db      dx >> 8
        db      dy and 255
        db      dy >> 8
        db      nx and 255
        db      nx >> 8
        db      ny and 255
        db      ny >> 8
        db      0
        db      0
        db      090h + op
        endm

; VDP Command HMMM: copy rectangle VRAM->VRAM using bytes.
        macro   VDP_HMMM sx, sy, dx, dy, nx, ny
        db      32
        db      sx and 255
        db      sx >> 8
        db      sy and 255
        db      sy >> 8
        db      dx and 255
        db      dx >> 8
        db      dy and 255
        db      dy >> 8
        db      nx and 255
        db      nx >> 8
        db      ny and 255
        db      ny >> 8
        db      0
        db      0
        db      0D0h
        endm

; Dump the contents of register A to openmsx console
        macro   DEBUG
        if debug == 1
        out     (openmsx_data), a
        endif
        endm

; Select a mapper block on page 2
        macro   MAPPER_P2 block
        ld      a, (mapper_selectors + block)
        call    fast_put_p2
        endm

; Create a hook for debugging purposes.
        macro   CREATE_HOOK addr, label
        ld      a, 0C3h
        ld      (addr), a
        ld      hl, label
        ld      (addr + 1), hl
        endm

; Compare the current frame with a given value
        macro   COMPARE_FRAME value
        ld      hl, (current_frame)
        ld      de, value
        or      a
        sbc     hl, de
        endm

; ----------------------------------------------------------------
; Animation states.

state_start:
current_frame:          dw      520
vertical_scroll:        db      0
horizontal_scroll:      db      0
palette_fade:           dw      cloud_fade_palette
palette_fade_counter:   db      16
cloud1_scroll:          db      158
cloud2_scroll:          db      146
cloud_tick:             db      1
city_split_line:        db      189 + 10 + 6
city_scroll:            dw      city_scroll_down5
top_building_current:   dw      top_building_dyn_attr
back_building_current:  dw      back_building_attr
back_building_size:     dw      back_building_dyn_size
back_building_cur_base: dw      back_building_base
back_building_cur_pal:  dw      back_building_palette
is_playing:             db      0
pcm_mapper_page:        dw      mapper_selectors
queue_pop:              dw      vdp_command_queue
queue_push:             dw      vdp_command_queue
current_city_beat:      dw      infinite_city_beat
cmd_infinite_city_1:    VDP_YMMM 51, 0, 768, 0
current_motion_blur:    dw      motion_blur_repeat
motion_blur_line:       db      187
state_end:
state_backup:           ds      state_end - state_start, 0

; ----------------------------------------------------------------
; Start of main program.

start_main:
        call    global_init
start_attract:
        call    local_init

        ; Install new interrupt handler.
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
        ld      (irq + 1), de
        ei

        ; Install foreground thread.
        ld      hl, foreground_next
        ld      (foreground + 1), hl

        ; Init turboR PCM.
        ld      a, 3
        out     (pmcntl), a
        in      a, (systml)

        ; Delay theme music until the correct frame.
delay_theme_music:
        COMPARE_FRAME theme_start_frame
        jr      nz, delay_theme_music

        ; Main theme music loop.
        xor     a
        out     (systml), a
        ld      a, 1
        ld      (is_playing), a
        ld      de, 04000h
change_sample_mapper:
        ; Set mapper page.
        push    hl
        ld      hl, (pcm_mapper_page)
        ld      a, (hl)
        inc     hl
        ld      (pcm_mapper_page), hl
        call    fast_put_p1
        pop     hl

        in      a, (systml)
sample_loop:
        ; Play a sample.
        ld      a, (de)
        out     (pcm), a

foreground:
        jp      foreground_next
foreground_next:
        ld      iy, (queue_pop)
        xor     a
        or      (iy + 1)
        jr      z, foreground_continue
        ld      (foreground_patch + 2), a
        ld      a, (iy + 0)
        ld      (foreground_patch + 1), a
foreground_patch:
        jp      0

foreground_continue:
        ; Avoid jitter by stopping foreground thread 
        ; a few ticks before the limit.
        in      a, (systml)
        cp      pcm_timer_period - 4
        jr      c, foreground
        ; Wait enough to hit 11025Hz.
1:
        in      a, (systml)
        cp      pcm_timer_period
        jr      c, 1b
        ld      iyl, a
        xor     a
        out     (systml), a

        ; Increment the pcm counter.
        ld      iyh, high advance_pcm
        ld      a, (iy)
        add     a, e
        ld      e, a
        ld      a, 0
        adc     a, d
        ld      d, a

        ; Check the pcm for mapper page change.
        bit     7, d
        jr      z, sample_loop
        set     6, d
        res     7, d
        jr      change_sample_mapper

finish_animation:
        ; Restore system irq.
        call    restore_irq

        ; Enable screen.
        di
        ENABLE_SCREEN
        ei

        ; Wait for a key and exit if not ESC.
        ld      iy, (mainrom)
        ld      ix, chget
        call    callf
        cp      27
        jp      nz, start_attract

        ; Restore environment.
        call    restore_environment
                
        ; Exit to DOS.
        ld      de, str_credits
        jp      abort

; ----------------------------------------------------------------
; Initialization.

global_init:
        ; Check if DOS2 is present.
        call    check_dos2
        ld      de, str_dos2_not_found
        jp      c, abort

        ; Check if MSX is a turboR.
        call    check_turbor
        ld      de, str_not_turbor
        jp      c, abort

        ; Enable R800 ROM.
        ld      a, 128 + 1
        ld      iy, (mainrom)
        ld      ix, chgcpu
        call    callf

        ; Get mapper support address.
        xor     a
        ld      de, 0402h
        call    extbio
        ; At this point C = number of free mapper pages.
        ld      a, 2
        add     a, c
        cp      selectors
        ld      de, str_not_enough_memory
        jp      c, abort
        ld      (mapper), hl
        ld      de, put_p1
        add     hl, de
        ld      (fast_put_p1 + 1), hl
        ld      hl, (mapper)
        ld      de, put_p2
        add     hl, de
        ld      (fast_put_p2 + 1), hl

        ; Put the two default pages into the mapper pool.
        ld      hl, (mapper)
        ld      de, get_p1
        add     hl, de
        call    call_hl
        ld      (mapper_selectors), a
        ld      hl, (mapper)
        ld      de, get_p2
        add     hl, de
        call    call_hl
        ld      (mapper_selectors + 1), a

        ; Allocate the remaining mapper selectors.
        ld      de, mapper_selectors + 2
        ld      b, selectors - 2
allocate_memory:
        push    bc
        ld      hl, (mapper)
        ld      bc, all_seg
        add     hl, bc
        xor     a
        ld      b, a
        call    call_hl
        ld      (de), a
        inc     de
        pop     bc
        djnz    allocate_memory

        ; Load mapper data.
        call    load_mapper_data

        ; Beep.
        ld      iy, (mainrom)
        ld      ix, beep
        call    callf

        ; Wait for a key.
        if      debug == 0
        ld      iy, (mainrom)
        ld      ix, chget
        call    callf
        endif

        ; Change to SCREEN 5.
        ld      iy, (subrom)
        ld      ix, chgmod
        ld      a, 5
        call    callf

        if debug == 1
        ; Init openmsx debug device
        ld      a, 16 + 4
        out     (openmsx_control), a
        ; Create hooks for breakpoints.
        CREATE_HOOK 0C000h, smart_zblit_start
        CREATE_HOOK 0C003h, foreground_ret
        CREATE_HOOK 0C006h, smart_palette_start
        CREATE_HOOK 0C009h, foreground_ret
        CREATE_HOOK 0C00Ch, smart_vdp_command_start
        CREATE_HOOK 0C00Fh, foreground_ret
        CREATE_HOOK 0C012h, smart_vdp_command_begin
        CREATE_HOOK 0C015h, smart_zblit_begin
        endif

        ; Backup animation state on startup.
        ld      hl, state_start
        ld      de, state_backup
        ld      bc, state_end - state_start
        ldir

        ret

; ----------------------------------------------------------------
; Initialization to be performed every time.

local_init:
        ; Disable screen.
        ld      iy, (mainrom)
        ld      ix, disscr
        call    callf

        ; Clear the vram.
        di
        ld      hl, cmd_erase_all_vram
        call    vdp_command
        ei

        ; Set border to color 0.
        di
        xor     a
        VDPREG  7

        ; Enable 192 lines.
        ld      a, (vdpr9)
        and     127
        ld      (vdpr9), a
        VDPREG  9

        ; Enable 16 colors and turn off sprites.
        ld      a, (vdpr8)
        or      32 + 2
        ld      (vdpr8), a
        VDPREG  8
        ei

        ; Copy cloud2 to vram.
        MAPPER_P2 9
        di
        SET_VRAM_WRITE cloud2_addr
        ei
        ld      hl, cloud_page2
        call    zblit

        ; Copy cloud3 to vram.
        di
        SET_VRAM_WRITE cloud3_addr
        ei
        ld      hl, cloud_page3
        call    zblit

        ; Copy moon sprite patterns to vram.
        MAPPER_P2 10
        di
        SET_VRAM_WRITE moon_pattern_addr
        ei
        ld      hl, moon_pattern
        call    zblit

        ; Copy moon sprite attributes to vram.
        di
        SET_VRAM_WRITE (moon_attr_addr - 512)
        ei
        ld      hl, moon_attr
        call    zblit

        ; Copy city1 to vram.
        di
        SET_VRAM_WRITE city1_addr
        ei
        ld      hl, city_page1
        call    zblit

        ; Copy city2 to vram.
        di
        SET_VRAM_WRITE city2_addr
        ei
        MAPPER_P2 13
        ld      hl, city2a
        call    zblit
        MAPPER_P2 12
        ld      hl, city2b
        call    zblit
        di
        SET_VRAM_WRITE city2_preload
        ei
        ld      hl, city2c
        call    zblit
        MAPPER_P2 14
        di
        SET_VRAM_WRITE city2_preload_2
        ei
        ld      hl, city2d
        call    zblit

        ; Copy top building sprite patterns to vram.
        di
        MAPPER_P2 11
        SET_VRAM_WRITE top_building_patt_addr
        ei
        ld      hl, top_building_pattern
        call    zblit

        ; Copy top building sprite attributes to vram.
        di
        SET_VRAM_WRITE (top_building_attr_addr - 512)
        ei
        ld      hl, top_building_attr
        call    zblit

        ; Copy city line mask to vram.
        di
        SET_VRAM_WRITE city_line_mask_addr
        ei
        ld      hl, city_line_mask
        call    zblit

        ; Copy back building sprite patterns to vram.
        di
        SET_VRAM_WRITE back_building_patt_addr
        ei
        ld      hl, back_building_patt
        call    zblit

        ; Copy back building sprite attributes to vram.
        di
        SET_VRAM_WRITE (back_building_attr_addr - 512)
        ei
        ld      hl, back_building_attr
        call    zblit

        ; Reset the animation.
        ld      de, state_start
        ld      hl, state_backup
        ld      bc, state_end - state_start
        ldir

        ret

; ----------------------------------------------------------------
; Load mapper data.

load_mapper_data:
        ; Print "loading" message.
        ld      de, str_loading
        ld      c, strout
        call    bdos

        ; Open file handle.
        ld      de, mapper_data_filename
        ld      c, open
        xor     a
        ld      b, a
        call    bdos
        call    check_bdos_error
        ld      a, b
        ld      (file_handle), a

        ld      b, selectors
        ld      hl, mapper_selectors
load_mapper_data_block:
        ; Set mapper page.
        push    bc
        push    hl
        ld      a, (hl)
        call    fast_put_p1

        ; Read 16kb from disk.
        ld      de, disk_buffer 
        ld      hl, 04000h
        ld      a, (file_handle)
        ld      b, a
        ld      c, read
        call    bdos
        call    check_bdos_error
        pop     hl
        inc     hl
        pop     bc

        ; Print a dot and loop
        push    bc
        push    hl
        ld      de, str_dot
        ld      c, strout
        call    bdos
        pop     hl
        pop     bc
        djnz    load_mapper_data_block        

        ; Close file.
        ld      a, (file_handle)
        ld      b, a
        ld      c, close
        call    bdos
        call    check_bdos_error

        ld      de, str_press_any_key
        ld      c, strout
        call    bdos
        ret

; ----------------------------------------------------------------
; State: end_animation
; Finish the animation.

end_animation:
        PREAMBLE_VERTICAL
        exx
        ld      hl, finish_animation
        ld      (foreground + 1), hl
        jp      frame_end

; ----------------------------------------------------------------
; State: title_bounce
; Top of TMNT logo bounces in the screen.

title_bounce:
        PREAMBLE_VERTICAL

        exx
        ; Adjust vertical scroll.
        ld      a, (vertical_scroll)
        ld      hl, title_bounce_data
        ld      e, a
        ld      d, 0
        add     hl, de
        ld      a, (hl)
        VDPREG vdp_vscroll
        ld      a, (vertical_scroll)
        inc     a
        ld      (vertical_scroll), a

        WIDE_SCROLL
        SET_HSCROLL 256

        ; If the logo is too low, disable screen
        ld      a, (hl)
        cp      80h
        jr      nc, title_bounce_v_disable

        HSPLIT_LINE 46
        ENABLE_SCREEN
        VDP_STATUS 1
        NEXT_HANDLE title_bounce_h_disable
        ENABLE_HIRQ
        jp      return_irq_exx

title_bounce_v_disable:
        HSPLIT_LINE 10
        DISABLE_SCREEN
        VDP_STATUS 1
        NEXT_HANDLE title_bounce_h_enable
        ENABLE_HIRQ
        jp      return_irq_exx

; H handler to disable screen
title_bounce_h_disable:
        PREAMBLE_HORIZONTAL
        DISABLE_SCREEN
        VDP_STATUS 0
        DISABLE_HIRQ
        jp      frame_end_exx

; H handler to enable screen
title_bounce_h_enable:
        PREAMBLE_HORIZONTAL
        ENABLE_SCREEN
        HSPLIT_LINE 46
        exx
        NEXT_HANDLE title_bounce_h_disable
        jp      return_irq_exx

; ----------------------------------------------------------------
; State: title_slide
; Bottom of TMNT logo slides from the right.

title_slide:
        PREAMBLE_VERTICAL
        ENABLE_SCREEN
        HSPLIT_LINE 47
        VDP_STATUS 1
        ENABLE_HIRQ
        SET_HSCROLL 256
        exx
        NEXT_HANDLE title_slide_scroll
        jp      return_irq_exx

title_slide_scroll:
        PREAMBLE_HORIZONTAL
        ; Adjust horizontal scroll
        exx
        ld      a, (horizontal_scroll)
        ld      e, a
        ld      d, 0
        ld      hl, title_slide_data
        add     hl, de
        add     hl, de
        ld      a, (hl)
        VDPREG vdp_hscroll_h
        inc     hl
        ld      a, (hl)
        VDPREG vdp_hscroll_l
        inc     e
        ld      a, e
        ld      (horizontal_scroll), a
        HSPLIT_LINE 118
        NEXT_HANDLE title_slide_disable
        jp      return_irq_exx

title_slide_disable:
        PREAMBLE_HORIZONTAL
        DISABLE_SCREEN
        VDP_STATUS 0
        DISABLE_HIRQ
        jp      frame_end_exx

; ----------------------------------------------------------------
; State: title_stand
; Show the entire logo.

title_stand:
        PREAMBLE_VERTICAL
        ENABLE_SCREEN
        SET_HSCROLL 256
        jp      frame_end_exx

; ----------------------------------------------------------------
; State: erase_title_vram
; Erase vram page 0 in order to prepare to draw the title.

erase_title_vram:
        PREAMBLE_VERTICAL
        exx
        ld      hl, cmd_erase_vram_page0
        call    smart_vdp_command
        VDP_STATUS 0
        jp      frame_end

; ----------------------------------------------------------------
; State: copy_title_vram
; Copy title data to vram.

copy_title_vram:
        PREAMBLE_VERTICAL
        SET_VRAM_WRITE title_addr
        MAPPER_P2 9
        xor     a
        ld      (vertical_scroll), a
        exx
        ld      hl, opening_title
        call    smart_zblit
        jp      frame_end

; ----------------------------------------------------------------
; State: disable_screen
; Turn off the screen.

disable_screen:
        PREAMBLE_VERTICAL
        DISABLE_SCREEN
        jp      frame_end_exx

; ----------------------------------------------------------------
; State: disable_screen
; Turn off the screen and set the palette to all blacks.

disable_screen_black:
        PREAMBLE_VERTICAL
        DISABLE_SCREEN
        exx
        ld      hl, black_palette
        call    smart_palette
        jp      frame_end

; ----------------------------------------------------------------
; State: cloud_setup
; Setup cloud animation.

cloud_setup:
        PREAMBLE_VERTICAL
        WIDE_SCROLL
        SPRITES_16x16
        SPRITE_ATTR moon_attr_addr
        exx
        jp      cloud_fade_moon_set_sprite

; ----------------------------------------------------------------
; State: cloud_fade_first
; First frame of fade in the clouds.

cloud_fade_first:
        PREAMBLE_VERTICAL
        ENABLE_SCREEN
        jr      cloud_fade_common

; ----------------------------------------------------------------
; State: cloud_fade
; Fade in the clouds.

cloud_fade:
        PREAMBLE_VERTICAL
cloud_fade_common:
        SET_PAGE 3
        SPRITES_ON
        exx
        ; Set v scroll.
        xor     a
        COMPARE_FRAME cloud_scroll_start_frame
        jr      c, 1f
        ld      a, (vertical_scroll)
        add     a, 2
        ld      (vertical_scroll), a
1:
        VDPREG vdp_vscroll
        ; Change palette every 6 frames.
        ld      hl, (palette_fade)
        ld      a, (palette_fade_counter)
        dec     a
        jr      nz, 2f
        ld      hl, (palette_fade)
        ld      de, 16 * 2
        add     hl, de
        ld      (palette_fade), hl
        ld      a, 6 + 1
2:
        ld      (palette_fade_counter), a
        call    smart_palette

        HSPLIT_LINE 14
        VDP_STATUS 1
        ENABLE_HIRQ
        ; Patch the scroll values for cloud 1.
        ld      a, (cloud1_scroll)
        ld      ix, cloud_fade_patch
        call    patch_scroll_values
        VDP_AUTOINC vdp_hscroll_h
        NEXT_HANDLE cloud_fade_first_top
        jp      return_irq_exx

cloud_fade_first_top:  
        PREAMBLE_HORIZONTAL
cloud_fade_patch:
        FAST_SET_HSCROLL 0
        HSPLIT_LINE 40
        exx
        ; Patch the scroll values for cloud 2.
        ld      a, (cloud2_scroll)
        ld      ix, cloud_fade_patch2
        call    patch_scroll_values
        VDP_AUTOINC vdp_hscroll_h
        NEXT_HANDLE cloud_fade_first_bottom
        jp      return_irq_exx

cloud_fade_first_bottom:  
        PREAMBLE_HORIZONTAL
        FAST_SET_HSCROLL 256
        HSPLIT_LINE 49
        exx
        NEXT_HANDLE cloud_fade_second_top
        VDP_AUTOINC vdp_hscroll_h
        jp      return_irq_exx

cloud_fade_second_top:
        PREAMBLE_HORIZONTAL
cloud_fade_patch2:
        FAST_SET_HSCROLL 0
        exx
        HSPLIT_LINE 79
        VDP_AUTOINC vdp_hscroll_h
        NEXT_HANDLE cloud_fade_second_bottom
        jp      return_irq_exx

cloud_fade_second_bottom:
        PREAMBLE_HORIZONTAL
        FAST_SET_HSCROLL 256
        ; Set v scroll.
        ld      a, (vertical_scroll)
        add     a, 256 - 80
        VDPREG vdp_vscroll
        SET_PAGE 1
        SPRITES_OFF
        exx
        ld      hl, (palette_fade)
        ld      de, city_fade_palette - cloud_fade_palette
        add     hl, de
        call    smart_palette
        HSPLIT_LINE 150 - 79
        NEXT_HANDLE cloud_fade_moon_sprites
        COMPARE_FRAME expand_city_line_frame
        jp      c, return_irq_exx
        ; Execute a vdp_command based on the frame number.
        ld      hl, (current_frame)
        ld      de, expand_city_line_frame
        or      a
        sbc     hl, de
        add     hl, hl
        ld      de, cloud_down2_commands
        add     hl, de
        ld      e, (hl)
        inc     hl
        ld      d, (hl)
        ld      a, d
        or      e
        jr      z, 1f
        ex      de, hl
        call    queue_vdp_command
1:
        DISABLE_HIRQ
        VDP_STATUS 0
        jp      frame_end

cloud_fade_moon_sprites:
        PREAMBLE_HORIZONTAL
        DISABLE_HIRQ
        exx
        COMPARE_FRAME expand_city_line_frame
        jr      c, cloud_fade_moon_set_sprite
        VDP_STATUS 0
        jp      frame_end

cloud_fade_moon_set_sprite:
        VDP_STATUS 0
        call    update_cloud_scroll
        ; Set sprite pattern base.
        ld      a, (cloud1_scroll)
        sub     moon_pattern_base_hscroll
        ld      d, a
        srl     a
        srl     a
        srl     a
        add     a, moon_pattern_addr >> 11
        VDPREG vdp_sprite_patt
        ; Set sprite attributes.
        ld      b, 8
        ld      a, d
        and     7
        rrca
        rrca
        rrca
        ld      hl, dynamic_moon_attr + 3
        ld      de, 4
1:
        ld      (hl), a
        add     a, e
        add     hl, de
        djnz    1b
        ; Copy moon attributes to VRAM.
        SET_VRAM_WRITE moon_attr_addr
        ld      hl, dynamic_moon_attr
        call    smart_zblit
        jp      frame_end

; ----------------------------------------------------------------
; Helpers for the cloud states.

update_cloud_scroll:        
        ; Scroll clouds every 4 frames.
        ld      hl, cloud1_scroll
        ld      a, (cloud_tick)
        dec     a
        jr      nz, 1f
        dec     (hl)
        inc     hl
        inc     (hl)
        dec     hl
        ld      a, 4 + 1
1:
        ld      (cloud_tick), a
        ret

patch_scroll_values:
        ; Patch scroll values for very fast response to HIRQ.
        ld      e, a
        ld      d, 0
        ld      hl, absolute_scroll
        add     hl, de
        add     hl, de
        ld      a, (hl)
        ld      (ix + 1), a
        inc     hl
        ld      a, (hl)
        ld      (ix + 5), a
        ret

set_absolute_scroll:
        ; Set an absolute horizontal scroll.
        ld      e, a
        ld      d, 0
        ld      hl, absolute_scroll
        add     hl, de
        add     hl, de
        ld      a, (hl)
        VDPREG vdp_hscroll_h
        inc     hl
        ld      a, (hl)
        VDPREG vdp_hscroll_l
        ret

update_top_building_sprite:
        ; Update the top building sprite attributes.
        QUEUE_VRAM_WRITE top_building_attr_addr
        ld      hl, (top_building_current)
        call    queue_zblit
        ld      hl, (top_building_current)
        ld      de, 2 + top_building_attr_size
        add     hl, de
        ld      (top_building_current), hl
        ret

; ----------------------------------------------------------------
; State: cloud_down2
; Start scrolling down the clouds, step 2.
; Cloud 1 still visible.

cloud_down2:
        PREAMBLE_VERTICAL
        SET_PAGE 3
        exx
        ; Should moon sprites be enabled?
        COMPARE_FRAME disable_moon_sprites_frame
        jr      nc, 1f
        SPRITES_ON
1:
        ; Set v scroll.
        ld      a, (vertical_scroll)
        add     a, 2
        ld      (vertical_scroll), a
        VDPREG vdp_vscroll
        ld      hl, cloud_palette_final
        call    smart_palette

        VDP_STATUS 1
        ENABLE_HIRQ
        ; Set directly the scroll values for cloud 1.
        ld      a, (cloud1_scroll)
        call    set_absolute_scroll
        HSPLIT_LINE 40
        ; Patch the scroll values for cloud 2.
        ld      a, (cloud2_scroll)
        ld      ix, cloud_fade_patch2
        call    patch_scroll_values
        VDP_AUTOINC vdp_hscroll_h
        NEXT_HANDLE cloud_fade_first_bottom
        jp      return_irq_exx

; ----------------------------------------------------------------
; State: cloud_down3
; Start scrolling down the clouds, step 3.
; Middle cloud visible.

cloud_down3:
        PREAMBLE_VERTICAL
        SET_PAGE 3
        SPRITES_OFF
        ; Set v scroll.
        ld      a, (vertical_scroll)
        add     a, 2
        ld      (vertical_scroll), a
        VDPREG vdp_vscroll
        exx
        ld      hl, cloud_palette_final
        call    smart_palette
        VDP_STATUS 1
        ENABLE_HIRQ
        ; Patch the scroll values for cloud 2.
        ld      a, (cloud2_scroll)
        ld      ix, cloud_down3_patch
        call    patch_scroll_values
        HSPLIT_LINE 49
        NEXT_HANDLE cloud_down3_second_top
        VDP_AUTOINC vdp_hscroll_h
        jp      return_irq_exx

cloud_down3_second_top:
        PREAMBLE_HORIZONTAL
cloud_down3_patch:
        FAST_SET_HSCROLL 0
        exx
        HSPLIT_LINE 70
        NEXT_HANDLE cloud_down3_set_vdp_hscroll
        jp      return_irq_exx

cloud_down3_set_vdp_hscroll:
        PREAMBLE_HORIZONTAL
        HSPLIT_LINE 79
        VDP_AUTOINC vdp_hscroll_h
        exx
        NEXT_HANDLE cloud_down3_second_bottom
        jp      return_irq_exx

cloud_down3_second_bottom:
        PREAMBLE_HORIZONTAL
        FAST_SET_HSCROLL 256
        ; Set v scroll.
        ld      a, (vertical_scroll)
        add     a, 256 - 80
        VDPREG vdp_vscroll
        SET_PAGE 1
        exx
        ld      hl, city_palette_final
        call    smart_palette
        call    update_cloud_scroll
        ld      a, (vertical_scroll)
        add     a, 100 - 80
        VDPREG  vdp_hsplit_line
        NEXT_HANDLE cloud_down3_vdp_command
        jp      return_irq_exx

cloud_down3_vdp_command:
        PREAMBLE_HORIZONTAL
        exx
        COMPARE_FRAME copy_city_mask_last_frame
        jr      nz, 1f
        ;ld      hl, cmd_copy_city_line_mask_5
        ;call    smart_vdp_command
1:
        VDP_STATUS 0
        DISABLE_HIRQ
        jp      frame_end

; ----------------------------------------------------------------
; State: cloud_down4_first
; Start scrolling down the clouds, step 4, first frame.
; Bottom cloud visible.

cloud_down4_first:
        PREAMBLE_VERTICAL
        SPRITE_ATTR top_building_attr_addr
        SPRITE_PATTERN top_building_patt_addr
        SPRITES_ON
        jr      cloud_down4_start

; ----------------------------------------------------------------
; State: cloud_down4
; Start scrolling down the clouds, step 4.
; Bottom cloud visible.

cloud_down4:
        PREAMBLE_VERTICAL
cloud_down4_start:
        SET_PAGE 3
        ; Set v scroll.
        ld      a, (vertical_scroll)
        add     a, 2
        ld      (vertical_scroll), a
        VDPREG vdp_vscroll
        exx
        ld      hl, cloud_palette_final
        call    smart_palette
        VDP_STATUS 1
        ENABLE_HIRQ
        ; Set directly the scroll values for cloud 2.
        ld      a, (cloud2_scroll)
        call    set_absolute_scroll
        HSPLIT_LINE 79
        VDP_AUTOINC vdp_hscroll_h
        NEXT_HANDLE cloud_down4_second_bottom
        jp      return_irq_exx

cloud_down4_second_bottom:
        PREAMBLE_HORIZONTAL
        FAST_SET_HSCROLL 256
        ; Set v scroll.
        ld      a, (vertical_scroll)
        add     a, 256 - 80
        VDPREG vdp_vscroll
        SET_PAGE 1
        exx
        ld      hl, city_palette_final
        call    smart_palette
        ; Update top building sprites only on the last frames.
        COMPARE_FRAME down4_sprite_start_frame
        jr      nc, 1f
        VDP_STATUS 0
        DISABLE_HIRQ
        call    update_cloud_scroll
        jp      frame_end
1:
        HSPLIT_LINE 100
        NEXT_HANDLE cloud_down4_sprites
        jp      return_irq_exx

cloud_down4_sprites:
        PREAMBLE_HORIZONTAL
        exx
        call    update_top_building_sprite
        VDP_STATUS 0
        DISABLE_HIRQ
        call    update_cloud_scroll
        jp      frame_end

; ----------------------------------------------------------------
; State: city_scroll1
; Scroll down the city with parallax, part 1.
; Back building set up before the split.

city_scroll1:
        PREAMBLE_VERTICAL
        SET_PAGE 1
        SPRITE_ATTR top_building_attr_addr
        SPRITE_PATTERN top_building_patt_addr
        SPRITES_ON
        ; Set v scroll.
        call    update_city_line
        VDPREG vdp_vscroll
        exx
        call    prepare_city_overlay
        call    update_top_building_sprite

        ld      hl, cmd_overlay_city_2
        call    queue_vdp_command
        ld      hl, cmd_overlay_city_3
        call    queue_vdp_command

        COMPARE_FRAME city_scroll1_first_frame
        jp      z, city_scroll1_exit_early

        call    set_back_building_palette
        call    queue_back_building_attr

        ; Copy city2 from page 0 to page 3.
        COMPARE_FRAME city_scroll1_last_frame
        call    nz, queue_infinite_city

        ; H split to city2.
        ld      a, (city_line)
        ld      b, a
        ld      a, (city_split_line)
        sub     10
        ld      (city_split_line), a
        add     a, b
        VDPREG vdp_hsplit_line
        VDP_STATUS 1
        ENABLE_HIRQ
        NEXT_HANDLE city_scroll1_foreground
        jp      return_irq_exx

city_scroll1_exit_early:
        ld      a, (city_split_line)
        sub     10
        ld      (city_split_line), a
        call    queue_infinite_city
        jp      frame_end

city_scroll1_foreground:
        PREAMBLE_HORIZONTAL
        ; Order is important here!
        ; 1: turn off sprites
        SPRITES_OFF
        ; 2: change scroll
        ld      a, (city_split_line)
        neg
        add     a, 204
        VDPREG  vdp_vscroll
        ; 3: change page
        SET_PAGE 3
        SPRITE_ATTR back_building_attr_addr
        exx
        ; Set back building base.
        ld      hl, (back_building_cur_base)
        ld      a, (hl)
        VDPREG vdp_sprite_patt
        inc     hl
        ld      (back_building_cur_base), hl
        SPRITES_ON
        COMPARE_FRAME city_scroll1_last_frame
        jr      z, 1f
        DISABLE_HIRQ
        VDP_STATUS 0
        jp      frame_end
1:
        call    update_city_line
        call    prepare_city_overlay
        call    update_top_building_sprite
        ld      a, 245
        VDPREG vdp_hsplit_line
        NEXT_HANDLE city_scroll1_late_exit
        jp      return_irq_exx

city_scroll1_late_exit:
        PREAMBLE_HORIZONTAL
        exx
        call    queue_back_building_attr
        DISABLE_HIRQ
        VDP_STATUS 0
        jp      frame_end

; ----------------------------------------------------------------
; Helpers for the city_scroll states.

update_city_line:
        ld      a, (vertical_scroll)
        add     a, 2
        ld      (vertical_scroll), a
        add     a, 256 - 80
        ld      (city_line), a
        ret

queue_infinite_city:
        ld      a, (cmd_infinite_city_1 + 9)
        ld      b, a
        ld      a, (cmd_infinite_city_1 + 1)
        add     a, b
        ld      (cmd_infinite_city_1 + 1), a
        ld      a, (cmd_infinite_city_1 + 5)
        add     a, b
        ld      (cmd_infinite_city_1 + 5), a
        ld      hl, (current_city_beat)
        ld      a, (hl)
        ld      (cmd_infinite_city_1 + 9), a
        inc     hl
        ld      (current_city_beat), hl
        ld      hl, cmd_infinite_city_1
        call    queue_vdp_command
        ret

queue_back_building_attr:
        ; Set back building attr.
        QUEUE_VRAM_WRITE (back_building_attr_addr - 512)
        ld      hl, (back_building_current)
        call    queue_zblit
        call    update_back_building_pointers
        QUEUE_VRAM_WRITE back_building_attr_addr
        ld      hl, (back_building_current)
        call    queue_zblit
        call    update_back_building_pointers
        ret

prepare_city_overlay:
        ; Queue the overlay commands.
        ld      a, (city_line)
        ld      b, a
        ld      a, (city_split_line)
        add     a, b
        sub     9
        ld      (cmd_overlay_city + 7), a
        ld      (cmd_overlay_city_2 + 1), a
        ld      (cmd_overlay_city_3 + 1), a
        ld      hl, cmd_overlay_city
        call    queue_vdp_command
        ret

set_back_building_palette:        
        ; Set palette of back building.
        ld      ix, (back_building_cur_pal)
        ld      e, (ix + 0)
        ld      d, 0
        inc     ix
        ld      (back_building_cur_pal), ix
        ld      a, 13
        VDPREG vdp_palette
        ld      hl, cityline_palette_0
        add     hl, de
        ld      b, 3
set_back_building_palette_patch:
        ld      ix, city_palette_final
        ld      a, (hl)
        add     a, a
        ld      e, a
        ld      d, 0
        add     ix, de
        ld      a, (ix + 0)
        out     (09Ah), a
        ld      a, (ix + 1)
        out     (09Ah), a
        inc     hl        
        djnz    set_back_building_palette_patch
        ret

update_back_building_pointers:
        ld      hl, (back_building_current)
        ld      ix, (back_building_size)
        ld      e, (ix + 0)
        ld      d, (ix + 1)
        add     hl, de
        ld      (back_building_current), hl
        inc     ix
        inc     ix
        ld      (back_building_size), ix
        ret

; ----------------------------------------------------------------
; State: city_scroll2
; Scroll down the city with parallax, part 2.
; Back building set up after the split.

city_scroll2:
        PREAMBLE_VERTICAL
        SET_PAGE 1
        SPRITE_ATTR top_building_attr_addr
        SPRITE_PATTERN top_building_patt_addr
        SPRITES_ON
        ; Set v scroll.
        ld      a, (city_line)
        VDPREG vdp_vscroll
        exx
        ; H split to city2.
        ld      a, (city_line)
        ld      b, a
        ld      a, (city_split_line)
        sub     10
        ld      (city_split_line), a
        add     a, b
        VDPREG vdp_hsplit_line
        VDP_STATUS 1
        ENABLE_HIRQ
        call    set_back_building_palette
        ld      hl, cmd_overlay_city_2
        call    queue_vdp_command
        ld      hl, cmd_overlay_city_3
        call    queue_vdp_command
        NEXT_HANDLE city_scroll2_foreground
        jp      return_irq_exx

city_scroll2_foreground:
        PREAMBLE_HORIZONTAL
        ; Order is important here!
        ; 1: turn off sprites
        SPRITES_OFF
        ; 2: change scroll
        ld      a, (city_split_line)
        neg
        add     a, 204
        VDPREG  vdp_vscroll
        ; 3: change page
        SET_PAGE 3
        SPRITE_ATTR back_building_attr_addr
        exx
        ; Set back building base.
        ld      hl, (back_building_cur_base)
        ld      a, (hl)
        VDPREG vdp_sprite_patt
        inc     hl
        ld      (back_building_cur_base), hl
        SPRITES_ON
        call    update_city_line
        call    prepare_city_overlay
        call    update_top_building_sprite
        ld      a, 255
        VDPREG vdp_hsplit_line
        NEXT_HANDLE city_scroll2_after_parallax
        jp      return_irq_exx

city_scroll2_after_parallax:
        PREAMBLE_HORIZONTAL
        exx
        SPRITES_OFF
        COMPARE_FRAME city_scroll2_last_frame
        jr      z, 1f
        ; Set back building sprite colors
        QUEUE_VRAM_WRITE (back_building_attr_addr - 512)
        ld      hl, (back_building_current)
        call    queue_zblit
        call    update_back_building_pointers

        ; Copy city2 from page 0 to page 3.
        COMPARE_FRAME city_scroll2_infinite
        call    nc, queue_infinite_city

        ; Set back building sprite attr
        QUEUE_VRAM_WRITE back_building_attr_addr
        ld      hl, (back_building_current)
        call    queue_zblit
        call    update_back_building_pointers
2:
        DISABLE_HIRQ
        VDP_STATUS 0
        jp      frame_end
1:
        call    queue_infinite_city
        jr      2b


; ----------------------------------------------------------------
; State: city_scroll3
; Scroll down the city with parallax, part 3.
; Back building with no split.

city_scroll3:
        PREAMBLE_VERTICAL
        ; Set v scroll.
        ld      a, (city_split_line)
        sub     10
        ld      (city_split_line), a
        neg
        add     a, 204
        VDPREG  vdp_vscroll
        exx
        SPRITES_ON
        call    queue_back_building_attr
        jp      frame_end

; ----------------------------------------------------------------
; State: city_scroll4
; Scroll down the city with parallax, part 4.
; No back building, no split.

city_scroll4:
        PREAMBLE_VERTICAL
        ; Set v scroll.
        ld      a, (city_split_line)
        sub     10
        ld      (city_split_line), a
        neg
        add     a, 204
        VDPREG  vdp_vscroll
        exx
        SPRITES_OFF

        COMPARE_FRAME city_scroll4_first_frame
        jp      nz, frame_end

        ld      hl, cmd_city_preload_2
        call    queue_vdp_command
        MAPPER_P2 14
        ld      hl, city2e
        QUEUE_VRAM_WRITE city2_continue1_addr
        call    queue_zblit
        ld      hl, city2f
        QUEUE_VRAM_WRITE city2_continue2_addr
        call    queue_zblit
        ld      a, 15
        call    queue_mapper
        ld      hl, city2g
        QUEUE_VRAM_WRITE city2_continue3_addr
        call    queue_zblit
        ld      a, 16
        call    queue_mapper
        ld      hl, alley1a
        QUEUE_VRAM_WRITE pixels_alley1a_addr
        call    queue_zblit
        ld      hl, alley1b
        QUEUE_VRAM_WRITE pixels_alley1b_addr
        call    queue_zblit
        jp      frame_end

; ----------------------------------------------------------------
; State: city_scroll5
; Scroll down the city with parallax, part 5.
; Split to motion blur.

city_scroll5:
        PREAMBLE_VERTICAL
        ; Set v scroll.
        ld      a, (city_split_line)
        sub     10
        ld      (city_split_line), a
        neg
        add     a, 204
        ld      (motion_blur_scroll), a
        VDPREG  vdp_vscroll
        exx
        ld      a, 192
        VDPREG vdp_hsplit_line
        VDP_STATUS 1
        ENABLE_HIRQ
        ld      hl, (current_motion_blur)
        ld      a, (hl)
        inc     hl
        ld      (current_motion_blur), hl
        ld      (motion_blur_counter), a
        NEXT_HANDLE city_scroll5_split
        jp      return_irq_exx

city_scroll5_split:
        PREAMBLE_HORIZONTAL
        ld      a, (motion_blur_scroll)
        sub     64
        ld      (motion_blur_scroll), a
        VDPREG vdp_vscroll
        exx
        ld      hl, motion_blur_counter
        dec     (hl)
        jp      nz, return_irq_exx
        DISABLE_HIRQ
        VDP_STATUS 0
        jp      frame_end

; ----------------------------------------------------------------
; State: alley_scroll1
; Motion blur on top, split to alley.

alley_scroll1:
        PREAMBLE_VERTICAL
        ; Set v scroll.
        ld      a, (motion_blur_line)
        add     a, 10
        and     63
        add     a, 128
        ld      (motion_blur_line), a
        ld      (motion_blur_scroll), a
        VDPREG  vdp_vscroll
        exx
        ld      a, 192
        VDPREG vdp_hsplit_line
        VDP_STATUS 1
        ENABLE_HIRQ
        ld      a, 3
        ld      (motion_blur_counter), a
        NEXT_HANDLE city_scroll5_split
        jp      return_irq_exx

; ----------------------------------------------------------------
; State: motion_blur
; Scroll the motion blur using minimum vram.

motion_blur:
        PREAMBLE_VERTICAL
        ; Set v scroll.
        ld      a, (motion_blur_line)
        add     a, 10
        and     63
        add     a, 128
        ld      (motion_blur_line), a
        ld      (motion_blur_scroll), a
        VDPREG  vdp_vscroll
        exx
        ld      a, 192
        VDPREG vdp_hsplit_line
        VDP_STATUS 1
        ENABLE_HIRQ
        ld      a, 3
        ld      (motion_blur_counter), a
        NEXT_HANDLE city_scroll5_split
        jp      return_irq_exx

; ----------------------------------------------------------------
; State: disable_screen_title
; Disable the screen just before the title

disable_screen_title:
        PREAMBLE_VERTICAL
        DISABLE_SCREEN
        SPRITES_OFF
        SET_PAGE 1
        exx
        ld      hl, title_palette
        call    smart_palette
        jp      frame_end

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
        ld      e, (hl)
        inc     hl
        ld      d, (hl)
        ld      (irq + 1), de
return_irq_exx:
        exx
return_irq:
        ex      af, af'
        ei
        ret

; ----------------------------------------------------------------
; Decompress graphics, assumes VRAM address is already set.
; Input: HL = address

zblit:
        ld      a, (hl)
        inc     hl
        or      a
        ret     z
        jp      m, zblit_rle
        ld      b, a
        ld      c, 098h
        otir
        jr      zblit
zblit_rle:
        sub     080h
        ld      b, a
        ld      a, (hl)
        inc     hl
1:
        out     (098h), a
        djnz    1b
        jr      zblit

; ----------------------------------------------------------------
; Start a VDP command.
; Input: HL=table with vdp commands

vdp_command:
        VDP_STATUS 2
1:
        in      a, (099h)
        rrca
        jr      c, 1b
        ; Set VDP to autoinc.
        ld      a, (hl)
        VDPREG  17
        ld      a, 47
        sub     (hl)
        ld      b, a
        ld      c, 09Bh
        inc     hl
        otir
2:
        in      a, (099h)
        rrca
        jr      c, 2b
        VDP_STATUS 0
        ret

; ----------------------------------------------------------------
; Queue a mapper change to execute as soon as possible.
; Input: A = mapper selector

queue_mapper:
        ld      ix, (queue_push)
        ld      hl, process_mapper
        ld      (ix + 0), l
        ld      (ix + 1), h
        ld      (ix + 2), a
        ld      de, 8
        add     ix, de
        ld      a, ixh
        and     0FEh
        ld      ixh, a
        ld      (queue_push), ix
        ret

process_mapper:
        ; Don't start if there's another foreground task running.
        ld      a, (foreground + 1)
        cp      low foreground_next
        jp      nz, foreground_continue
        ld      a, (foreground + 2)
        cp      high foreground_next
        jp      nz, foreground_continue

        ld      hl, mapper_selectors
        ld      c, (iy + 2)
        ld      b, 0
        add     hl, bc
        ld      a, (hl)
        call    fast_put_p2
        ld      (iy + 0), 0
        ld      (iy + 1), 0
        ld      (iy + 2), 0
        ld      bc, 8
        add     iy, bc
        ld      a, iyh
        and     0FEh
        ld      iyh, a
        ld      (queue_pop), iy
        jp      foreground_continue

; ----------------------------------------------------------------
; Queue a zblit to execute as soon as possible.
; Input: HL=table with vdp commands, BDE = decoded VRAM address

queue_zblit:
        ld      ix, (queue_push)
        ld      a, low process_zblit
        ld      (ix + 0), a
        ld      a, high process_zblit
        ld      (ix + 1), a
        ld      (ix + 2), l
        ld      (ix + 3), h
        ld      (ix + 4), b
        ld      (ix + 5), d
        ld      (ix + 6), e
        ld      de, 8
        add     ix, de
        ld      a, ixh
        and     0FEh
        ld      ixh, a
        ld      (queue_push), ix
        ret

        ; Process zblit.
process_zblit:
        ; Don't start if there's another foreground task running.
        ld      a, (foreground + 1)
        cp      low foreground_next
        jp      nz, foreground_continue
        ld      a, (foreground + 2)
        cp      high foreground_next
        jp      nz, foreground_continue
        di
        exx
        ld      a, (iy + 4)
        VDPREG  14
        ld      a, (iy + 5)
        out     (099h), a
        ld      a, (iy + 6)
        out     (099h), a
        ld      l, (iy + 2)
        ld      h, (iy + 3)
        ld      (iy + 0), 0
        ld      (iy + 1), 0
        ld      (iy + 2), 0
        ld      (iy + 3), 0
        ld      (iy + 4), 0
        ld      (iy + 5), 0
        ld      (iy + 6), 0
        ld      bc, 8
        add     iy, bc
        ld      a, iyh
        and     0FEh
        ld      iyh, a
        ld      (queue_pop), iy
        if      debug == 0
        call    smart_zblit_begin
        else
        call    0C015h
        endif
        exx
        ei
        jp      foreground_continue

smart_zblit_begin:        
        push    hl
        exx
        pop     hl
        exx
        ld      hl, foreground_zblit
        ld      (foreground + 1), hl
        ret

; ----------------------------------------------------------------
; Queue a VDP command to execute as soon as possible.
; Input: HL=table with vdp commands

queue_vdp_command:
        ld      ix, (queue_push)
        ld      de, process_vdp_command_queue
        ld      (ix + 0), e
        ld      (ix + 1), d
        ld      (ix + 2), l
        ld      (ix + 3), h
        ld      de, 8
        add     ix, de
        ld      a, ixh
        and     0FEh
        ld      ixh, a
        ld      (queue_push), ix
        ret

        ; Process vdp command queue.
process_vdp_command_queue:
        ; Don't start if there's another foreground task running.
        ld      a, (foreground + 1)
        cp      low foreground_next
        jp      nz, foreground_continue
        ld      a, (foreground + 2)
        cp      high foreground_next
        jp      nz, foreground_continue
        ; Don't start if there's another vdp command running.
        di
        ld      a, 2
        VDPREG vdp_status
        in      a, (099h)
        rrca
        jr      nc, 1f
        ; Not ready yet.
        ld      (iy + 0), low process_vdp_command_delay
        ld      (iy + 1), high process_vdp_command_delay
        ei
        jp      foreground_continue

process_vdp_command_delay:
        di
        in      a, (099h)
        rrca
        jr      nc, 1f
        ei
        jp      foreground_continue
        
1:
        ld      a, (current_vdp_status)
        VDPREG vdp_status
        exx
        ld      l, (iy + 2)
        ld      h, (iy + 3)
        ld      (iy + 0), 0
        ld      (iy + 1), 0
        ld      (iy + 2), 0
        ld      (iy + 3), 0
        ld      bc, 8
        add     iy, bc
        ld      a, iyh
        and     0FEh
        ld      iyh, a
        ld      (queue_pop), iy
        if      debug == 0
        call    smart_vdp_command_begin
        else
        call    0C012h
        endif
        exx
        ei
        jp      foreground_continue

; ----------------------------------------------------------------
; Start a VDP command without stopping the pcm sample.
; Input: HL=table with vdp commands
; Destroy: VDP Status

        if      debug == 0
smart_vdp_command:
        else
smart_vdp_command_start:
smart_vdp_command equ 0C00Ch
        endif

        ; Check for foreground overrun.
        push    hl
        call    check_foreground
        pop     hl
        ; Check for VDP overrun.
        VDP_STATUS 2
        in      a, (099h)
        rrca
        ld      de, str_vdp_error
        jp      c, graphic_abort
smart_vdp_command_begin:
        ; Set VDP to autoincrement. 
        ld      a, (hl)
        VDPREG 17
        ; Setup foreground thread.
        ld      a, 47
        sub     (hl)
        inc     hl
        push    hl
        exx
        pop     hl
        ld      b, a
        exx
        ld      hl, foreground_vdp_command
        ld      (foreground + 1), hl
        ret

foreground_vdp_command:
        ld      a, (hl)
        out     (09Bh), a
        inc     hl
        dec     b
        jp      nz, foreground_continue
        if      debug == 0
        jp      foreground_ret
        else
        jp      0C00Fh
        endif

; ----------------------------------------------------------------
; Decompress graphics without stopping the pcm sample.
; Input: HL=graphics

        if      debug == 0
smart_zblit:
        else
smart_zblit_start:
smart_zblit equ 0C000h
        endif

        ld      a, (is_playing)
        or      a
        jp      z, zblit

        push    hl
        exx
        pop     hl
        exx
        call    check_foreground
        ld      hl, foreground_zblit
        ld      (foreground + 1), hl
        ret

foreground_zblit:
        ld      a, (hl)
        inc     hl
        or      a
        if      debug == 0
        jp      z, foreground_ret
        else
        jp      z, 0C003h
        endif
        jp      m, foreground_rle_setup

        ; Setup zblit copy.
        ld      bc, foreground_copy_step
        ld      (foreground + 1), bc
        ld      b, a
        jp      foreground_continue

        ; Setup zblit rle.
foreground_rle_setup:
        ld      bc, foreground_rle_step
        ld      (foreground + 1), bc
        sub     080h
        ld      b, a
        jp      foreground_continue

foreground_copy_step:
        ld      a, (hl)
        inc     hl
        out     (098h), a
        dec     b
        jp      nz, foreground_continue
        ld      bc, foreground_zblit
        ld      (foreground + 1), bc
        jp      foreground_continue

foreground_rle_step:
        ld      a, (hl)
        out     (098h), a
        dec     b
        jp      nz, foreground_continue
        inc     hl
        ld      bc, foreground_zblit
        ld      (foreground + 1), bc
        jp      foreground_continue

; ----------------------------------------------------------------
; Set the palette without stopping the pcm sample.

        if      debug == 0
smart_palette:
        else
smart_palette_start:
smart_palette equ 0C006h
        endif
        ld      a, (is_playing)
        or      a
        jr      nz, 1f
        SET_PALETTE
        ret
1:
        xor     a
        VDPREG  vdp_palette
        push    hl
        exx
        pop     hl
        ld      b, 32
        exx
        call    check_foreground
        ld      hl, foreground_palette
        ld      (foreground + 1), hl
        ret

foreground_palette:
        ld      a, (hl)
        out     (09Ah), a
        inc     hl
        dec     b
        jp      nz, foreground_continue
        if      debug == 0
        ; fall through
        else
        jp      0C009h
        endif

foreground_ret:
        ld      hl, foreground_next
        ld      (foreground + 1), hl
        jp      (hl)

check_foreground:
        ld      hl, (foreground + 1)
        ld      de, foreground_next
        or      a
        sbc     hl, de
        ld      de, str_foreground_error
        jp      nz, graphic_abort
        ret

; ----------------------------------------------------------------
; Restore the VDP interrupt settings.

restore_irq:
        di

        ; Disable h interrupt.
        DISABLE_HIRQ

        ; Clear H-irq flag
        VDP_STATUS 1
        in      a, (099h)

        ; Clear V-irq flag
        VDP_STATUS 0
        in      a, (099h)

        ; Reload old interrupt handler
        ld      a, (save_irq)
        ld      (irq), a
        ld      hl, (save_irq + 1)
        ld      (irq + 1), hl
        ei
        ret

; Check if DOS2 is present.
; Output: SCF if DOS2 not found.
; Based on http://map.grauw.nl/resources/dos2_functioncalls.php#_dosver
check_dos2:
        ; Check for DOS2
        ld      c, dosver
        call    bdos
        add     a, 255
        ret     c
        ld      a, b
        cp      2
        ret     c
        ; Check for EXTBIO
        ld      a, (hokvld)
        rrca
        ccf
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
        ; Print the message.
        ld      c, strout
        call    bdos
        jp      restart

; Restore DOS2 environment, print error message, abort and return to dos.
; Input: de = error message terminated in $
graphic_abort:
        push    de
        call    restore_irq
        call    restore_environment
        pop     de
        jr      abort

restore_environment:
        ; Restore palette.
        ld      iy, (subrom)
        ld      ix, iniplt
        call    callf

        ; Restore text mode.
        ld      iy, (subrom)
        ld      ix, chgmod
        xor     a
        call    callf

        ; Restore mapper.
        ld      a, (mapper_selectors)
        call    fast_put_p1
        ld      a, (mapper_selectors + 1)
        jp      fast_put_p2

; Call HL.
call_hl:
        jp      (hl)

; Fast put page 1.
fast_put_p1:
        jp      0

; Fast put page 2.
fast_put_p2:
        jp      0

; ----------------------------------------------------------------
; Variables.

                        align   512
vdp_command_queue:      ds      256, 0
save_irq:               ds      3, 0
file_handle:            db      0
mapper:                 dw      0
save_palette:           dw      0
city_line:              db      0
current_vdp_status:     db      0
motion_blur_counter:    db      0
motion_blur_scroll:     db      0
mapper_selectors:       ds      selectors, 0

; ----------------------------------------------------------------
; Misc strings.

str_dos2_not_found:     db      "MSX-DOS 2 not found, sorry.", 13, 10, "$"
str_not_turbor:         db      "This MSX is not a turboR, sorry.", 13, 10, "$"
str_read_error:         db      "Error reading from disk, sorry.", 13, 10, "$"
str_not_enough_memory:  db      "Not enough memory, sorry.", 13, 10, "$"
str_foreground_error:   db      "Foreground thread overrun.", 13, 10, "$"
str_vdp_error:          db      "VDP command overrun.", 13, 10, "$"
str_loading:            db      "Loading$"
str_dot:                db      ".$"
str_press_any_key:      db      13, 10, "Press any key to start.$"
str_credits:            db      "TMNT Attract Mode 1.0", 13, 10
                        db      "by Ricardo Bittencourt 2014.", 13, 10, "$"
mapper_data_filename:   dz      "attract.dat"

; ----------------------------------------------------------------
; Data

title_palette:          incbin  "title_bounce_palette.bin"
title_bounce_data:      incbin  "title_bounce_scroll.bin"
title_slide_data:       incbin  "title_slide_scroll.bin"
cloud_fade_palette:     incbin  "cloud_fade_palette.bin"
city_fade_palette:      incbin  "city_fade_palette.bin"
absolute_scroll:        incbin  "absolute_scroll.bin"
city_line_mask:         incbin  "cityline.z5"
handles_begin:          include "handles.inc"
handles                 equ     handles_begin - 500 * 2
black_palette:          ds      16 * 2, 0
cloud_palette_final     equ     cloud_fade_palette + 512
city_palette_final      equ     city_fade_palette + 512
cityline_palette_0:     db      8, 1, 0
cityline_palette_1:     db      8, 11, 8
cityline_palette_2:     db      11, 11, 6

                        align   256
advance_pcm:            incbin  "advance_pcm.bin"

; Dynamic sprite attr data for the moon.
dynamic_moon_attr:
        db      8 * 4 + 1
        rept    4
        db      14, 72, 0, 0
        db      14, 72 + 16, 0, 0
        endr
        db      0xD8, 0

; Table of commands to be issued during cloud_down2.
cloud_down2_commands:
        dw cmd_expand_city_line_mask    ; 805    
        dw cmd_copy_city_line_mask      ; 806
        dw cmd_copy_city_line_mask_2    ; 807
        dw 0                            ; 808 
        dw cmd_copy_city_line_mask_3    ; 809
        dw 0                            ; 810
        dw 0                            ; 811
        dw 0                            ; 812    
        dw 0                            ; 813

; City scroll positions for state cloud_down5.
city_scroll_down5:        
        db      188, 188 + 2, 188 + 14, 188 + 36

; Copy city2 to page 3 to allow infinite scrolling.
infinite_city_beat:
        ; 833 834 835 836 837 838 839 840 841 842
        db 11, 10, 11, 10, 10, 10, 10, 10, 10, 10
        ; 847 848 849 850 851 852 
        db  3,  7,  8,  9,  10, 2

; How many times should we repeat the motion blur on each frame?
motion_blur_repeat:
        ; 884 885 886 887 888 889 890 891 892 893 894 895 
        db  1,  1,  1,  1,  1,  1,  2,  2,  2,  2,  2,  2
        ; 896 897 898 899 900 901 902
        db  2,  3,  3,  3,  3,  3,  3

; ----------------------------------------------------------------
; VDP commands

; Erase page 0 of vram.
cmd_erase_vram_page0:           
        VDP_HMMV 0, 0, 256, 192, 0

; Erase all vram.        
cmd_erase_all_vram:             
        VDP_HMMV 0, 0, 256, 1023, 0

; Expand the city line mask to cover 130 lines.
cmd_expand_city_line_mask:
        VDP_HMMM 64, 973, 64, 974, 174 - 64, 50

; Copy city2 over the city line mask.
cmd_copy_city_line_mask:
        VDP_HMMM 0, 0, 0, 973, 70, 51
cmd_copy_city_line_mask_2:
        VDP_LMMM 70, 0, 70, 973, 174 - 70, 51, vdp_timp
cmd_copy_city_line_mask_3:
        VDP_YMMM 0, 174, 973, 51
cmd_copy_city_line_mask_4:
        VDP_YMMM 51, 0, 768, 20

; Copy city2 over city1 to allow smooth screen split on city_scroll1.
cmd_overlay_city:
        VDP_LMMM 0, 0, 0, 256 + 100, 256, 3, vdp_timp
cmd_overlay_city_2:
        VDP_YMMM 256 + 100, 0, 256 + 973 - 768, 1
cmd_overlay_city_3:
        VDP_YMMM 256 + 100, 0, 973, 3

; Copy city preload2 to page 3.
cmd_city_preload_2:
        VDP_YMMM 256 + 212, 0, 973, 44

end_of_code:
        assert  end_of_code <= 04000h

; ----------------------------------------------------------------
; Mapper Data

        output  attract.dat

        macro   PAGE_BEGIN
        .phase   08000h
        endm

        macro   PAGE_END
        assert  $ <= 0C000h
        align   16384
        endm

; Mapper pages 0-8
theme_music:            incbin "theme.pcm"

; Mapper page 9
                        PAGE_BEGIN
opening_title:          incbin "tmnt.z5"
cloud_page2:            incbin "cloud2.z5"
cloud_page3:            incbin "cloud3.z5"
                        PAGE_END

; Mapper page 10
                        PAGE_BEGIN
city_page1:             incbin "city1.z5"
moon_pattern:           incbin "moon_pattern.z5"
moon_attr:              incbin "moon_attr.z5"
                        PAGE_END

; Mapper page 11
                        PAGE_BEGIN
top_building_pattern:   incbin "top_building_patt.z5"
top_building_attr:      incbin "top_building_attr.z5"
top_building_dyn_attr:  incbin "top_building_dyn_attr.bin"
back_building_patt:     incbin "back_building_patt.z5"
back_building_attr:     incbin "back_building_attr.z5"
back_building_dyn_size: incbin "back_building_size.bin"
back_building_base:     incbin "back_building_patt_base.bin"
back_building_palette:  incbin "back_building_palette.bin"
                        PAGE_END

; Mapper page 12
                        PAGE_BEGIN
city2b:                 incbin "city2b.z5"
city2c:                 incbin "city2c.z5"
                        PAGE_END

; Mapper page 13
                        PAGE_BEGIN
city2a:                 incbin "city2a.z5"
                        PAGE_END

; Mapper page 14
                        PAGE_BEGIN
city2d:                 incbin "city2d.z5"
city2e:                 incbin "city2e.z5"
city2f:                 incbin "city2f.z5"
                        PAGE_END

; Mapper page 15
                        PAGE_BEGIN
city2g:                 incbin "city2g.z5"
                        PAGE_END

; Mapper page 16
                        PAGE_BEGIN
alley1a:                incbin "alley1a.z5"
alley1b:                incbin "alley1b.z5"
                        PAGE_END

        end

