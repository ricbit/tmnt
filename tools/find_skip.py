import re, sys
log = open(sys.argv[1], "rt").read()
de = [int(v) for v in re.findall("DE = (\d+)", log)]
prev = 0
for value in de:
  if prev != value - 1:
    print prev, " -> ", (value - prev)
  prev = value
