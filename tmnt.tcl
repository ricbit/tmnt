set throttle off
set running 0
set current_frame 0
set vdp_command_running 0
set fast_emulation 0

proc readmemw {addr} {
  expr {
    [debug read "memory" $addr] + 
    256 * [debug read "memory" [expr {$addr + 1}]]
  }
}

debug probe set_bp VDP.IRQvertical {
  $running == 1 && $current_frame != [readmemw 0x103]
} {
  set current_frame [readmemw 0x103]
  puts stderr "Frame $current_frame"
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

debug set_bp 0xC00F {} {
  set vdp_command_running 1
  puts stderr "smart_vdp_command ending at [machine_info VDP_msx_y_pos]"
}

debug set_watchpoint write_mem 0x104 {[readmemw 0x103] == 521} {
  record start "/home/ricbit/work/tmnt/tmntmsx.avi"
  set running 1
  if {$fast_emulation == 0} {
    debug set_condition {
      $vdp_command_running == 1 && 
      [expr {[debug read {VDP status regs} 2] & 1}] == 0
    } {
      set vdp_command_running 0
      puts stderr "smart_vdp_command stopping at [machine_info VDP_msx_y_pos]"
    }
  }
}

debug set_watchpoint write_mem 0x104 {[readmemw 0x103] == 900} {
  record stop
  quit
}
