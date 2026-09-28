import numpy as np
ROWS={"pos":(42,66),"vel":(104,128)}
P,O=17.07,2.0
NC=37
def cells(img,row):
    y0,y1=ROWS[row]; g=img[y0-2:y1+2].astype(float)
    out=[]
    for k in range(NC):
        x0=int(round(O+k*P))-2; c=np.zeros((28,21)); s=g[:,max(0,x0):x0+21]; c[:,:s.shape[1]]=s; out.append(c)
    return out
T={}
def learn(img,row,text):
    for c,ch in zip(cells(img,row),("      "+text).ljust(NC)):
        if ch!=" ": T.setdefault(ch,[]).append(c[2:-2,2:-2])
def ncc(a,b):
    a=a-a.mean(); b=b-b.mean(); d=np.sqrt((a*a).sum()*(b*b).sum()); return (a*b).sum()/d if d>0 else 0
def classify(c):
    if (c[2:-2,2:-2]>200).sum()<4: return " ",1.0
    best=(" ",-1)
    for ch,ts in T.items():
        for t in ts:
            for dy in range(5):
                for dx in range(5):
                    s=ncc(c[dy:dy+24,dx:dx+17],t)
                    if s>best[1]: best=(ch,s)
    return best
def read(img,row):
    r=[classify(c) for c in cells(img,row)[6:]]
    return "".join(ch for ch,_ in r).strip(), min(s for _,s in r)
