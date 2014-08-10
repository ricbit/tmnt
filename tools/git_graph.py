import subprocess
import re
import matplotlib.pyplot as plot
from datetime import datetime

git = subprocess.check_output("tools/git_graph.sh", shell=True)
commits = re.findall("(?s)Date:\s+\w+\s+(\w+.*?:\d\d) .*?(\d+)\s+attract", git)
x = [datetime.strptime(i[0] + " 2014", "%b %d %X %Y") 
     for i in reversed(commits)]
y = [i[1] for i in reversed(commits)]
fig = plot.figure()
fig.add_subplot(111)
plot.plot(x, y)
fig.autofmt_xdate()
plot.show()
