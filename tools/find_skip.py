import re, sys
log = open(sys.argv[1], "rt").read()
de = [(int(a), int(b)) for a,b in 
      re.findall("(?ms)DE = (\d+).*?emutime: (\d+)", log)]
prev = 0
prev_emutime = 0
for value, emutime in de:
  delta = emutime - prev_emutime
  prev_emutime = emutime
  #if prev != value - 1:
  if delta < 300 or delta > 400:
    print prev, " -> ", (value - prev), " delta ", delta
  prev = value
