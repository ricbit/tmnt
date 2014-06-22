f = open("advance_pcm.bin", "wb")
for i in xrange(256):
  f.write(chr((i + 23/2) / 23))
f.close()
