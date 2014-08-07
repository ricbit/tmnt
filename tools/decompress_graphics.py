import sys

z = [ord(i) for i in open(sys.argv[1], "rb").read()]
pos = 0
decoded = []
f = open(sys.argv[2], "wb")
while True:
  if z[pos] == 0:
    break
  if z[pos] >= 128 + 64:
    size = z[pos] - 128 - 64 + 3
    print "copy ", size
    f.write("".join(chr(i) for i in decoded[- 128 : - 128 + size]))
    decoded.extend(decoded[- 128 : - 128 + size])
    pos += 1
  elif z[pos] >= 128:
    size = z[pos] - 128 + 3
    print "repeat ", size
    f.write("".join([chr(z[pos + 1])] * size))
    decoded.extend([z[pos + 1]] * size)
    pos += 2
  else:
    size = z[pos]
    print "direct ", size
    f.write("".join(chr(i) for i in z[pos + 1: pos + 1 + size]))
    decoded.extend(z[pos + 1: pos + 1 + size])
    pos += size + 1
f.close()
