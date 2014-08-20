import subprocess
import re
import matplotlib.pyplot as plot
from datetime import datetime

git = subprocess.check_output("tools/git_graph.sh", shell=True)
commits = re.findall("(?s)Date:\s+\w+\s+(\w+.*?:\d\d) .*?(\d+)\s+attract", git)
commits = [(datetime.strptime(i[0] + " 2014", "%b %d %X %Y"), i[1])
           for i in commits]
commits.sort()
fig = plot.figure()
fig.add_subplot(111)
plot.plot([i[0] for i in commits], [i[1] for i in commits])
fig.autofmt_xdate()
plot.show()
