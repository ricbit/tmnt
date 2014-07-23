city = [ord(i) for i in open("raw/city2.raw", "rb").read()]
sprites = []
start = [
    (0, 0, 9), 
    (0, 16, 9), (16, 16, 9), 
    (0, 32, 9), (16, 32, 9), (32, 32, 9),
    (0, 48, 9), (16, 48, 9), (32, 48, 9), (48, 48, 9),
    (0, 64, 9), (16, 64, 9), (32, 64, 9), (48, 64, 9), (64, 64, 9),
    (0, 14, 1), (14, 30, 1), (30, 44, 1), (44, 60, 1),
    (6, 37, 6), (6, 37 + 16, 6), (6, 37 + 32, 6),
    (6, 48, 1), (6, 48 + 16, 1), (6, 48 + 32, 1)
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
        if city[pos] == c or (city[pos] == 7 and c in [6, 1]):
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
  attr.extend([c + (0x40 if c == 1 else 0)] * 16)
attr.extend([0] * (512 - len(attr)))
attr.extend([0xD8])
f = open("top_building_attr.sc5", "wb")
f.write("".join(chr(i) for i in attr))
f.close()
# Attributes
attr = []
for f in xrange(-6, 28):
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
print "frame : ", len(frame)
f = open("top_building_dyn_attr.bin", "wb")
f.write("".join(chr(i) for i in attr))
f.close()

