import sys

original = [ord(i) for i in open(sys.argv[1], "rb").read()]
out = []
last128 = []
raw = []
state = 0
repeat_value = 0
repeat_count = 0
for value in original:
  if state == 0:
    if len(raw) >= 2 and raw[-1] == raw[-2] == value:
      if len(raw) > 2:
        out.append(len(raw) - 2)
        out.extend(raw[:-2])
      raw = []
      repeat_value = value
      repeat_count = 3
      state = 1
    else:
      raw.append(value)
      if len(raw) == 127:
        out.append(127)
        out.extend(raw)
        raw = []
  elif state == 1:
    if value != repeat_value:
      out.append(128 + repeat_count)
      out.append(repeat_value)
      state = 0
      raw = [value]
    else:
      if repeat_count > 127:
        out.append(128 + 127)
        out.append(repeat_value)
        repeat_count -= 127
      repeat_count += 1
  last128.append(value)
  if len(last128) > 128:
    last128 = last128[-128:]
if state == 0 and raw:
  out.append(len(raw))
  out.extend(raw)
elif state == 1 and repeat_count > 0:
  out.append(128 + repeat_count)
  out.append(repeat_value)
out.append(0)
f = open(sys.argv[2], "wb")
f.write("".join(chr(i) for i in out))
f.close()
