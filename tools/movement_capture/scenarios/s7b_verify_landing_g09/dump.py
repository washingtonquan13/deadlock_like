import sys, os, glob, csv
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "s6_slidejump"))
from load import load
import numpy as np
p=sys.argv[1]; a=float(sys.argv[2]); b=float(sys.argv[3])
tk,sp,pos=load(p)
for i in range(len(tk)):
    if a<=tk[i]<=b: print("%6.1f %7.1f  z %8.1f"%(tk[i],sp[i],pos[i,2]))
