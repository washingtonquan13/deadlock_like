import subprocess, numpy as np, imageio_ffmpeg, sys
F=imageio_ffmpeg.get_ffmpeg_exe()
R="C:/Godot Projects/deadlock_like/deadlock_like/tools/movement_capture/rec/"
names=["2026-09-28 10-38-26","2026-09-28 10-38-33","2026-09-28 10-38-42","2026-09-28 10-38-51"]
W,H=640,140
for i,n in enumerate(names,1):
    p=subprocess.run([F,"-v","error","-i",R+n+".mp4","-vf",f"crop={W}:{H}:0:220","-f","rawvideo","-pix_fmt","rgb24","-"],capture_output=True)
    a=np.frombuffer(p.stdout,np.uint8).reshape(-1,H,W,3)
    np.save(f"v{i}.npy",a.min(axis=3)); print(i,a.shape)
