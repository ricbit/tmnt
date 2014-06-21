handle = [
    (574,  "cloud_setup"),
    (575,  "cloud_fade"),
    (794,  "disable_screen_black"),
    (795,  "disable_screen"),
    (1271, "erase_title_vram"),
    (1272, "copy_title_vram"),
    (1273, "disable_screen"),
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
        
