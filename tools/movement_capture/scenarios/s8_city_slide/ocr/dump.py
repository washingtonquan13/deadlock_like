"""Crop the cl_showpos overlay of every clip in rec/<subdir> into <prefix><n>.npy.
usage: python dump.py [subdir=sliding_1] [prefix=v]"""
import subprocess, numpy as np, imageio_ffmpeg, sys, glob, os
F=imageio_ffmpeg.get_ffmpeg_exe()
sub=sys.argv[1] if len(sys.argv)>1 else "sliding_1"; pre=sys.argv[2] if len(sys.argv)>2 else "v"
R=os.path.join(os.environ.get("REC","C:/Godot Projects/deadlock_like/deadlock_like/tools/movement_capture/rec"),sub)
W,H=640,140
for i,p in enumerate(sorted(glob.glob(os.path.join(R,"*.mp4"))),1):
    r=subprocess.run([F,"-v","error","-i",p,"-vf",f"crop={W}:{H}:0:220","-f","rawvideo","-pix_fmt","rgb24","-"],capture_output=True)
    a=np.frombuffer(r.stdout,np.uint8).reshape(-1,H,W,3)
    np.save(f"{pre}{i}.npy",a.min(axis=3)); print(pre,i,os.path.basename(p),a.shape)
