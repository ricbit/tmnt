line = 1368

def ymmm(dx, dy):
  return ((40 + 24) * dx) * dy / line

def lmmm(dx, dy):
  return ((64 + 32 + 24) * dx + 64) * dy / line

def hmmm(dx, dy):
  return ((64 + 24) * dx + 64) * dy / line
