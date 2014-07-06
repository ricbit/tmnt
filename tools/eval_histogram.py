import sys
data = [ord(i) for i in open(sys.argv[1], "rb").read()]
hist = {i:0 for i in xrange(256)}
cur = 0
for d in data:
  hist[(d - cur + 256) % 256] += 1
  cur = d
hist_sorted = [(v, k) for k, v in hist.iteritems()]
hist_sorted.sort(reverse=True)
n = 6
low = sum(v for v,k in hist_sorted[:(1<<n)-1])
high = sum(v for v,k in hist_sorted[(1<<n)-1:])
print low, high
print (low * n + high * (n + 8)) / 8

