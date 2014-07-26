# Convert city2 rgb to screen 5.

raw = open("/home/ricbit/work/tmnt/raw/city2.raw", "rb").read()

def save_city(filename, start, size):
  f = open(filename, "wb")
  start *= 256
  for i in xrange(128 * size):
    a = (ord(raw[start + i*2 + 0]) << 4) + ord(raw[start + i*2 + 1])
    f.write(chr(a))
  f.close()

save_city("/home/ricbit/work/tmnt/city2a.sc5", 70, 128)
save_city("/home/ricbit/work/tmnt/city2b.sc5", 70 + 128, 73)
save_city("/home/ricbit/work/tmnt/city2c.sc5", 70 + 201, 128)

