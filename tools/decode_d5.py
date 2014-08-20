import sys
raw = [ord(i) for i in open(sys.argv[1], "rb").read()]
pos = 0
while raw[pos] != 0:
  if raw[pos] >= 128 + 64:
    print "page: ", raw[pos] & 0x3F
    pos += 1
  elif raw[pos] >= 128:
    print "addr: ", ((raw[pos] & 0x3F) << 8) + raw[pos + 1]
    pos += 2
  else:
    size = raw[pos]
    print "raw ", size
    pos += size + 1
