city = [ord(i) for i in open("raw/city2.raw", "rb").read()]
sprites = []
start = [
    (0, 0, 6), 
    (0, 16, 6), (16, 16, 6), 
    (0, 32, 6), (16, 32, 6), (32, 32, 6),
    (0, 48, 6), (16, 48, 6), (32, 48, 6), (48, 48, 6),
    (0, 64, 6), (16, 64, 6), (32, 64, 6), (48, 64, 6), (64, 64, 6),
    (0, 14, 1), (14, 30, 1), (30, 44, 1), (44, 60, 1),
    (6, 37, 7)
    ]
# Pattern
for st_pack in start:
  st = st_pack[:2]
  c = st_pack[2]
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
# Colors
attr = []
for st_pack in start:
  st = st_pack[:2]
  c = st_pack[2]
  attr.extend([c] * 16)
attr.extend([0] * (512 - len(attr)))
attr.extend([0xD8])
f = open("top_building_attr.sc5", "wb")
f.write("".join(chr(i) for i in attr))
f.close()
# Attributes
attr = []
for f in xrange(-6, 21):
  frame = []
  pattern = 0
  for st_pack in start:
    st = st_pack[:2]
    c = st_pack[2]
    y = 180 - 38 - f * 8 + st[1] - 1
    if y == 0xD8:
      print "error in sprite"
    if y >= 192 or y <= -32:
      y = 192
    frame.extend([(y + 256) % 256, st[0], pattern, 0])
    pattern += 4
  frame.append(0xD8)
  attr.append(len(frame))
  attr.extend(frame)
  attr.append(0)
  print len(frame)
f = open("top_building_dyn_attr.bin", "wb")
f.write("".join(chr(i) for i in attr))
f.close()

