set throttle off
set running 0
set current_frame 0
set vdp_command_running 0
set fast_emulation 0
set last_sample -1
set freq_hist [dict create]

# Parse sym file.
set symfile [open "attract.sym" r]
set symlines [split [read $symfile] "\n"]
close $symfile
set symlabel [dict create]
foreach line $symlines {
  if {[regexp {([^:]+): equ (0x[0-9A-F]+)} $line _ name value]} {
    dict append symlabel $name [expr $value]
  }
}

proc readmemw {addr} {
  expr {
    [debug read "memory" $addr] + 
    256 * [debug read "memory" [expr {$addr + 1}]]
  }
}

debug set_bp [dict get $symlabel play_sample] {$running} {
  #puts stderr [format %x [reg de]]
  if {$last_sample > 0} {
    set freq [expr int(0.01 / ([machine_info time] - $last_sample))]
    dict incr freq_hist $freq
  }
  set last_sample [machine_info time]
}

debug probe set_bp VDP.IRQhorizontal {
  $running == 1 && [debug read {VDP regs} 15] != 1
} {
  puts stderr "HIRQ but VDP status is [debug read {VDP regs} 15]"
  exit
}

debug probe set_bp VDP.IRQvertical {
  $running == 1 && $current_frame != [readmemw 0x103]
} {
  set current_frame [readmemw 0x103]
  puts stderr "Frame $current_frame"
  if {[debug read {VDP regs} 15] != 0} {
    puts stderr "VIRQ but VDP status is [debug read {VDP regs} 15]"
    exit
  }
}

debug set_bp 0xC000 {$current_frame >= 750} {
  puts stderr "smart_zblit starting at [machine_info VDP_msx_y_pos]"
}

debug set_bp 0xC003 {} {
  puts stderr "smart_zblit ending at [machine_info VDP_msx_y_pos]"
}

debug set_bp 0xC006 {$current_frame >= 750} {
  puts stderr "smart_palette starting at [machine_info VDP_msx_y_pos]"
}

debug set_bp 0xC009 {} {
  puts stderr "smart_palette ending at [machine_info VDP_msx_y_pos]"
}

debug set_bp 0xC00C {$current_frame >= 750} {
  puts stderr "smart_vdp_command starting at [machine_info VDP_msx_y_pos]"
}

debug set_bp 0xC012 {$current_frame >= 750} {
  puts stderr "smart_vdp_command queued at [machine_info VDP_msx_y_pos]"
}

debug set_bp 0xC015 {$current_frame >= 750} {
  puts stderr "smart_zblit queued at [machine_info VDP_msx_y_pos]"
}

debug set_bp 0xC00F {} {
  puts stderr "smart_vdp_command ending at [machine_info VDP_msx_y_pos]"
  if {$fast_emulation == 0} {
    set vdp_command_running [
      debug set_condition {
        $vdp_command_running != 0 && 
        [expr {[debug read {VDP status regs} 2] & 1}] == 0
      } {
        debug remove_condition $vdp_command_running
        set vdp_command_running 0
        puts stderr "smart_vdp_command stopping at [machine_info VDP_msx_y_pos]"
      }
    ]
  }
}

debug set_watchpoint write_mem 0x104 {[readmemw 0x103] == 521} {
  record start "/home/ricbit/work/tmnt/tmntmsx.avi"
  set running 1
}

debug set_watchpoint write_mem 0x104 {[readmemw 0x103] == 1100} {
  record stop
  puts stderr "Histogram of frequencies:"
  foreach freq [lsort -integer [dict keys $freq_hist]] {
    puts stderr "freq [expr 100 * $freq] -> [dict get $freq_hist $freq]"
  }
  quit
}

