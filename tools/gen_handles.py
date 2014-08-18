handle = [
    (574,  "cloud_setup"),
    (575,  "cloud_fade_first"),
    (576,  "cloud_fade"),
    (801,  "cloud_down2"),
    (814,  "cloud_down3"),
    (818,  "cloud_down4_first"),
    (819,  "cloud_down4"),
    (833,  "city_scroll1"),
    (844,  "city_scroll2"),
    (853,  "city_scroll3"),
    (858,  "city_scroll4"),
    (884,  "city_scroll5"),
    (903,  "motion_blur"),
    (922,  "alley_scroll1"),
    (941,  "alley_scroll2"),
    (949,  "alley_scroll3"),
    (966,  "alley_stand"),
    (1002, "blinking_manhole"),
    (1033, "exploding_manhole"),
    (1044, "blinking_alley"),
    (1130, "disable_screen_black"),
    (1131, "disable_screen"),
    (1137, "disable_screen_212"),
    (1138, "turtles_slide"),
    (1163, "turtles_stand"),
    (1281, "erase_title_vram"),
    (1282, "disable_screen"),
    (1290, "enable_blue_border"),
    (1301, "title_bounce"),
    (1374, "title_slide"),
    (1402, "title_stand"),
    (1500, "end_animation")
]

pos = 0
cur = "disable_screen_black"
for i in xrange(500, 1 + max(i for i,j in handle)):
  if i >= handle[pos][0]:
    cur = handle[pos][1]
    pos += 1
  print "\t\tdw\t%s\t; %d" % (cur, i)
        
