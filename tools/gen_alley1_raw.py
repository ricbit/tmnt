# Convert city2 rgb to screen 5.

raw = open("/home/ricbit/work/tmnt/raw/alley1.raw", "rb").read()

def save_city(filename, start, size):
  f = open(filename, "wb")
  start *= 256
  for i in xrange(128 * size):
    a = (ord(raw[start + i*2 + 0]) << 4) + ord(raw[start + i*2 + 1])
    f.write(chr(a))
  f.close()

save_city("/home/ricbit/work/tmnt/alley1a.sc5", 0, 64)
save_city("/home/ricbit/work/tmnt/alley1b.sc5", 64, 16)

