import sys

pal = [ord(i) for i in open(sys.argv[1]).read()]
f = open(sys.argv[2], "wb")
for j in xrange(16):
  f.write(chr((pal[j*3+0]>>5) * 16 + (pal[j*3+2]>>5)))
  f.write(chr(pal[j*3+1]>>5))
f.close()
