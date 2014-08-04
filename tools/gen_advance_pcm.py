f = open("advance_pcm.bin", "wb")
for i in xrange(768):
  adv = 11 * i
  f.write(chr(adv % 256))
  f.write(chr(adv / 256))
f.close()
