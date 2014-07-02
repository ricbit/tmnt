import sys

raw = [ord(i) for i in open(sys.argv[1]).read()]
final = []
for i in xrange(16 * 3):
  final.append(raw[i] >> 5)
offset = 3
f = open(sys.argv[2], "wb")
pal = []
for i in xrange(offset, offset + 16 + 1):
  pal = []
  for j in final:
    pal.append(int(j / float(offset + 16) * i))
  for j in xrange(16):
    f.write(chr(pal[j*3+0] * 16 + pal[j*3+2]))
    f.write(chr(pal[j*3+1]))
for i in xrange(16):
  for j in xrange(16):
    f.write(chr(pal[j*3+0] * 16 + pal[j*3+2]))
    f.write(chr(pal[j*3+1]))
f.close()
