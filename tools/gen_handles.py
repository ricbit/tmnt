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
    (863,  "disable_screen_black"),
    (864,  "disable_screen"),
    (1270, "erase_title_vram"),
    (1271, "copy_title_vram"),
    (1272, "disable_screen"),
    (1290, "disable_screen_title"),
    (1301, "title_bounce"),
    (1374, "title_slide"),
    (1402, "title_stand"),
    (1500, "end_animation")
]

pos = 0
cur = "disable_screen_black"
for i in xrange(1 + max(i for i,j in handle)):
  if i >= handle[pos][0]:
    cur = handle[pos][1]
    pos += 1
  print "\t\tdw\t%s\t; %d" % (cur, i)
        
