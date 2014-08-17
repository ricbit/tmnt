top = [ord(i) for i in open("raw/top.act", "rb").read()]
bottom = [ord(i) for i in open("raw/bottom.act", "rb").read()]

def get(palette, i):
  return palette[i * 3 : i * 3 + 3]

def swap(palette, i, j):
  save = palette[i * 3 : i * 3 + 3]
  palette[i * 3 : i * 3 + 3] = palette[j * 3 : j * 3 + 3]
  palette[j * 3 : j * 3 + 3] = save

def search(top, bottom):
  current = 1
  for i in xrange(1, 16):
    for j in xrange(i + 1, 16):
      if get(top, i) == get(bottom, j):
        swap(top, i, current)
        swap(bottom, j, current)
        print i, current
        current += 1
        break

def save(palette, name):
  f = open(name, "wb")
  f.write("".join(chr(i) for i in palette))
  f.close()

search(top, bottom)

save(top, "raw/top.act")
save(bottom, "raw/bottom.act")
