import sys

z = [ord(i) for i in open(sys.argv[1], "rb").read()]
pos = 0
f = open(sys.argv[2], "wb")
while True:
  if z[pos] == 0:
    break
  if z[pos] >= 128:
    size = z[pos] - 128
    f.write("".join([chr(z[pos + 1])] * size))
    pos += 2
  else:
    size = z[pos]
    f.write("".join(chr(i) for i in z[pos + 1: pos + 1 + size]))
    pos += size + 1
f.close()
