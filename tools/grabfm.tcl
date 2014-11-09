set throttle off
set mute on
set running 0
set psg_register 0
set fm_register 0
set music_data ""

debug set_bp 0x4601 {$running == 0} {
  set running 1

  debug set_watchpoint write_io 0x7C {} {
    set fm_register [reg A]
  }
  debug set_watchpoint write_io 0x7D {} {
    append music_data [format "%c%c" $fm_register [reg A]]
  }
  debug set_watchpoint write_io 0xA0 {} {
    set psg_register [reg A]
  }
  debug set_watchpoint write_io 0xA1 {} {
    append music_data [format "%c%c" [expr 0x80 + $psg_register] [reg A]]
  }
  debug set_bp 0xFD9F {} {
    append music_data [format "%c" 0xFF]
  }
  debug set_bp 0xFF07 {} {
    debug set_condition {[expr [peek 0xFB3F] & 0x7F] == 0} {
      set file_handle [open "info_music.fm" "w"]
      fconfigure $file_handle -encoding binary
      puts -nonewline $file_handle $music_data
      close $file_handle
      quit
    }
  }
}
