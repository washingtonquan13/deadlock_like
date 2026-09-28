import numpy as np, ocr2 as ocr, re, csv
L=[(1,90,'-463.09 -9261.72 1112.84','482.79 (482.79)'),(2,0,'801.44 -9237.75 1279.47','0.00 (354.62)'),(3,0,'-1029.72 -8860.34 1287.50','4.52 (79.72)'),(4,0,'77.12 -6626.31 829.16','0.00 (268.02)'),(4,227,'119.53 -5164.00 652.91','558.90 (606.69)'),(3,158,'-1040.56 -7576.94 874.78','678.82 (754.69)')]
V={i:np.load(f'v{i}.npy') for i in range(1,5)}
for i,k,p,v in L: ocr.learn(V[i][k],'pos',p); ocr.learn(V[i][k],'vel',v)
labs=[];TM=[]
for ch,ts in ocr.T.items():
    for t in ts:
        t=t-t.mean(); t/=np.linalg.norm(t)+1e-9; TM.append(t.ravel()); labs.append(ch)
TM=np.array(TM)
def cls(c):
    if (c[2:-2,2:-2]>200).sum()<4: return " ",1.0
    W=np.array([c[dy:dy+24,dx:dx+17].ravel() for dy in range(5) for dx in range(5)])
    W=W-W.mean(1,keepdims=True); W/=np.linalg.norm(W,axis=1,keepdims=True)+1e-9
    s=(W@TM.T).max(0); j=s.argmax(); return labs[j],s[j]
num=re.compile(r"-?\d+\.\d\d")
for i in range(1,5):
    rows=[]
    for fr,img in enumerate(V[i]):
        out=[fr]; ok=True; ms=1
        for row in ("pos","vel"):
            r=[cls(c) for c in ocr.cells(img,row)[6:]]
            t="".join(a for a,_ in r).strip(); ms=min(ms,min(b for _,b in r))
            n=num.findall(t); out+= [float(x) for x in n]
        if len(out)!=6: out=[fr]+[np.nan]*5
        rows.append(out+[round(ms,2)])
    np.savetxt(f"v{i}.csv",np.array(rows),delimiter=",",fmt="%.2f",header="frame,x,y,z,vel,velmax,score",comments="")
    a=np.array(rows); print(i,len(a),"nan",np.isnan(a[:,1]).sum(),"lowscore",(a[:,6]<0.5).sum())
