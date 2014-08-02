# Convert city2 rgb to screen 5.

import convert_raw

raw = open("/home/ricbit/work/tmnt/raw/city2.raw", "rb").read()

convert_raw.save_sc5(raw, "/home/ricbit/work/tmnt/city2a.sc5", 70, 128)
convert_raw.save_sc5(raw, "/home/ricbit/work/tmnt/city2b.sc5", 198, 192 - 128)
convert_raw.save_sc5(raw, "/home/ricbit/work/tmnt/city2c.sc5", 262, 64)
convert_raw.save_sc5(raw, "/home/ricbit/work/tmnt/city2d.sc5", 326, 44)
convert_raw.save_sc5(raw, "/home/ricbit/work/tmnt/city2e.sc5", 370, 7)
convert_raw.save_sc5(raw, "/home/ricbit/work/tmnt/city2f.sc5", 377, 80)
convert_raw.save_sc5(raw, "/home/ricbit/work/tmnt/city2g.sc5", 457, 120)

