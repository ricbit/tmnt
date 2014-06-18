import itertools, sys

raw = [ord(i) for i in open(sys.argv[1], "rb").read()]
grouped = []
for k, g in itertools.groupby(raw):
  grouped.append((len(list(g)), k))
f = open(sys.argv[2], "wb")
for k, g in itertools.groupby(grouped, lambda (k,g): -1 if k==1 else g):
  data = list(g)
  if k == -1:
    data = [g for k, g in data]
    while data:
      if len(data) > 127:
        f.write(chr(127))
        f.write("".join(chr(i) for i in data[:127]))
        data = data[127:]
      else:
        f.write(chr(len(data)))
        f.write("".join(chr(i) for i in data))
        data = []
  else:
    size, value = data[0]
    while size:
      if size > 127:
        f.write(chr(128+127))
        f.write(chr(value))
        size -= 127
      else:
        f.write(chr(128 + size))
        f.write(chr(value))
        size = 0
f.write(chr(0))
f.close()
