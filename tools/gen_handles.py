handle = [ 
    (575,  "cloud_fade"),
    (711,  "cloud_slide"),
    (792,  "disable_screen"),
    (1290, "disable_screen_title"),
    (1301, "title_bounce"),
    (1374, "title_slide"),
    (1402, "title_stand"),
    (3000, "unreachable")
]

pos = 0
cur = "disable_screen"
for i in xrange(2000):
  if i >= handle[pos][0]:
    cur = handle[pos][1]
    pos += 1
  print "\t\tdw\t%s\t; %d" % (cur, i)
        
