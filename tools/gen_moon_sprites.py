raw = [ord(i) for i in open("moon.raw", "rb").read()]
colors = [1,3,6,7]
sprites = []
for c in colors:
  for oi in xrange(2):
    for i in xrange(2):
      for j in xrange(16):
        b = 0
        for ii in xrange(8):
          if raw[72 + oi * 16 + i * 8 + j * 256 + ii] == c:
            b |= 1 << ii
        sprites.append(b)
f = open("attract.005", "wb")
f.write("".join(chr(i) for i in sprites))
f.close()
