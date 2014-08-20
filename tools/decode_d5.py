import sys

raw = [ord(i) for i in open(sys.argv[1], "rb").read()]
out = [0] * (128 * 256)
start = 0x18000
page = 0
pos = 0
while raw[pos] != 0:
  if raw[pos] >= 128 + 64:
    page = raw[pos] & 0x3F
    pos += 1
  elif raw[pos] >= 128:
    addr = ((raw[pos] & 0x3F) << 8) + raw[pos + 1]
    pos += 2
  else:
    size = raw[pos]
    dest = (page << 14) + addr - start
    out[dest : dest + size] = raw[pos + 1 : pos + size + 1]
    pos += size + 1
f = open(sys.argv[2], "wb")
f.write("".join(chr(i) for i in out))
f.close()
