city = [ord(i) for i in open("city2.raw", "rb").read()]
colors = [6, 9]
sprites = []
start = [(0, 0), (0, 16), (16, 16), (0, 32), (16, 32), (32, 32)]
for st in start:
  for c in colors:
    for i in xrange(2):
      for j in xrange(16):
        b = 0
        for ii in xrange(8):
          pos = st[0] + i * 8 + (j + st[1]) * 256 + ii
          if city[pos] == c:
            b |= 1 << (7 - ii)
        sprites.append(b)
f = open("top_building_patt.sc5", "wb")
f.write("".join(chr(i) for i in sprites))
f.close()
attr = []
for st in start:
  for c in colors:
    attr.extend([c] * 16)
attr.extend([0] * (512 - len(attr)))
attr.extend([0xD8] + [0] * 63)
for f in xrange(-6, 21):
  frame = []
  pattern = 0
  for st in start:
    for c in colors:
      y = 180 - 38 - f * 8 + st[1] - 1
      if y == 0xD8:
        print "error in sprite"
      if y >= 192 or y <= -32:
        y = 192
      frame.extend([(y + 256) % 256, st[0], pattern, 0])
      pattern += 4
  frame.append(0xD8)
  frame.extend([0] * (64 - len(frame)))
  attr.extend(frame)
f = open("top_building_attr.sc5", "wb")
f.write("".join(chr(i) for i in attr))
f.close()

