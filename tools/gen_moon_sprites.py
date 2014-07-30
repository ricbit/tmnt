cloud = [ord(i) for i in open("raw/cloud2.raw", "rb").read()]
raw = [ord(i) for i in open("raw/moon.raw", "rb").read()]
colors = [1,3,6,7]
sprites = []
startx, starty = 72, 15
for cloudx in xrange(108, 159):
  for c in colors:
    for oi in xrange(2):
      for i in xrange(2):
        for j in xrange(16):
          b = 0
          for ii in xrange(8):
            pos = startx + oi * 16 + i * 8 + (j + starty) * 256 + ii
            if raw[pos] == c and cloud[pos + cloudx] == 0:
              b |= 1 << (7 - ii)
          sprites.append(b)
f = open("moon_pattern.sc5", "wb")
f.write("".join(chr(i) for i in sprites))
f.close()
attr = []
for c in colors:
  attr.extend([c] * 32)
attr.extend([0] * (512 - len(colors) * 32))
pattern = 0
for c in colors:
  attr.extend([starty - 1, startx, pattern, 0])
  attr.extend([starty - 1, startx + 16, pattern + 4, 0])
  pattern += 8
f = open("moon_attr.sc5", "wb")
f.write("".join(chr(i) for i in attr))
f.close()

