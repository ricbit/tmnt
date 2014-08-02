import sys

def compress(original, filename):
  out = []
  raw = []
  state = 0
  repeat_value = 0
  repeat_count = 0
  repeat_max = 63
  slide_start = 0
  slide_count = 0
  for pos, value in enumerate(original):
    if state == 0:
      if (pos > 128 and len(raw) >= 2 and 
          all(original[pos - 128 - i] == v for i,v in enumerate(
              [value, raw[-1], raw[-2]]))):
        if len(raw) > 2:
          out.append(len(raw) - 2)
          out.extend(raw[:-2])
        raw = []
        state = 2
        slide_count = 3
        slide_start = pos - 2 - 128
      elif len(raw) >= 2 and raw[-1] == raw[-2] == value:
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
        if repeat_count:
          out.append(128 + repeat_count)
          out.append(repeat_value)
        state = 0
        raw = [value]
      else:
        if repeat_count >= repeat_max:
          out.append(128 + repeat_max)
          out.append(repeat_value)
          repeat_count -= repeat_max
        repeat_count += 1
    elif state == 2:
      if value != original[slide_start + slide_count]:
        if slide_count:
          out.append(128 + 64 + slide_count)
        state = 0
        raw = [value]
      else:
        if slide_count >= 63:
          out.append(128 + 64 + 63)
          slide_count -= 63
          slide_start += 63
        slide_count += 1
  if state == 0 and raw:
    out.append(len(raw))
    out.extend(raw)
  elif state == 1 and repeat_count > 0:
    out.append(128 + repeat_count)
    out.append(repeat_value)
  elif state == 2 and slide_count > 0:
    out.append(128 + 64 + slide_count)
  out.append(0)
  f = open(sys.argv[2], "wb")
  f.write("".join(chr(i) for i in out))
  f.close()

if __name__ == "__main__":
  original = [ord(i) for i in open(sys.argv[1], "rb").read()]
  compress(original, sys.argv[2])


