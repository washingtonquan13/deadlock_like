"""cl_showpos screen-recording -> per-frame CSV.

Subcommands (none of them is interactive):

  calibrate      find or set the readout ROI, save it to JSON, write a preview PNG to check it
  label-dump     save ROI crops of chosen frames + a labels JSON pre-filled with OCR guesses
                 (edit the JSON by hand so every line is exactly what the screen shows)
  train-templates learn glyph templates from the corrected labels JSON
  extract        read every frame, parse, clean, write the CSV + a summary JSON

Run with the venv interpreter:  .venv\\Scripts\\python.exe extract.py <subcommand> -h
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time

import cv2
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import mc_ocr  # noqa: E402
import mc_post  # noqa: E402

DEFAULT_LAYOUT = os.path.join(HERE, "layouts", "showpos_default.json")


# ----------------------------------------------------------------------------------------------
# video helpers
# ----------------------------------------------------------------------------------------------

class Video:
    def __init__(self, path: str):
        if not os.path.isfile(path):
            raise SystemExit("video not found: %s" % path)
        self.path = path
        self.cap = cv2.VideoCapture(path)
        if not self.cap.isOpened():
            raise SystemExit("OpenCV could not open %s (codec not supported by the pip OpenCV build? re-encode to H.264 mp4)" % path)
        self.fps = float(self.cap.get(cv2.CAP_PROP_FPS)) or 0.0
        self.count = int(self.cap.get(cv2.CAP_PROP_FRAME_COUNT))
        self.width = int(self.cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        self.height = int(self.cap.get(cv2.CAP_PROP_FRAME_HEIGHT))

    def frame(self, idx: int) -> np.ndarray:
        self.cap.set(cv2.CAP_PROP_POS_FRAMES, idx)
        ok, fr = self.cap.read()
        if not ok:
            raise SystemExit("could not read frame %d of %s" % (idx, self.path))
        return fr

    def iterate(self, start: int = 0, end: int | None = None, every: int = 1):
        """Sequential decode (much faster than seeking). Yields (index, msec, frame)."""
        self.cap.set(cv2.CAP_PROP_POS_FRAMES, start)
        i = start
        while end is None or i < end:
            ok, fr = self.cap.read()
            if not ok:
                break
            msec = float(self.cap.get(cv2.CAP_PROP_POS_MSEC))
            if (i - start) % every == 0:
                yield i, msec, fr
            i += 1

    def close(self):
        self.cap.release()


def parse_roi(s: str) -> list[int]:
    """'x,y,w,h' or a path to a ROI JSON written by calibrate."""
    if os.path.isfile(s):
        with open(s, "r", encoding="utf-8") as f:
            return [int(v) for v in json.load(f)["roi"]]
    parts = [p for p in re.split(r"[,\s]+", s.strip()) if p]
    if len(parts) != 4:
        raise SystemExit("--roi must be x,y,w,h or a ROI JSON file")
    return [int(float(p)) for p in parts]


def parse_frames(s: str | None, count: int, default_n: int = 5) -> list[int]:
    if s:
        return [int(v) for v in s.split(",") if v.strip()]
    if count <= 0:
        return [0]
    return sorted(set(int(round(k * (count - 1) / max(1, default_n - 1))) for k in range(default_n)))


# ----------------------------------------------------------------------------------------------
# calibrate
# ----------------------------------------------------------------------------------------------

def auto_roi(video: Video, layout: dict, frames: list[int], margin: int) -> tuple[list[int] | None, list]:
    """Runs RapidOCR on whole frames and returns the union box of lines matching the layout
    labels (pos / vel / ang ...), padded by `margin` px."""
    ocr = mc_ocr.RapidOCRBackend(layout, upscale=1.0)
    labels = [re.compile(fd["label"], re.IGNORECASE) for fd in layout["fields"] if "label" in fd]
    boxes = []
    hits = []
    for fi in frames:
        fr = video.frame(fi)
        for box, text, score in ocr.detect(fr):
            if any(l.search(text) for l in labels) and re.search(r"\d", text):
                xs = [p[0] for p in box]
                ys = [p[1] for p in box]
                boxes.append((min(xs), min(ys), max(xs), max(ys)))
                hits.append({"frame": fi, "text": text, "score": float(score)})
    if not boxes:
        return None, hits
    b = np.array(boxes)
    x0, y0 = int(b[:, 0].min()) - margin, int(b[:, 1].min()) - margin
    x1, y1 = int(b[:, 2].max()) + margin, int(b[:, 3].max()) + margin
    # widen to the right: numbers grow when the player moves far from the origin
    x1 = x1 + int(0.25 * (x1 - x0))
    x0, y0 = max(0, x0), max(0, y0)
    x1, y1 = min(video.width, x1), min(video.height, y1)
    return [x0, y0, x1 - x0, y1 - y0], hits


def cmd_calibrate(a) -> int:
    layout = mc_ocr.load_layout(a.layout)
    v = Video(a.video)
    frames = parse_frames(a.frames, v.count, 5)
    hits = []
    if a.roi:
        roi = parse_roi(a.roi)
        source = "manual"
    else:
        roi, hits = auto_roi(v, layout, frames, a.margin)
        source = "auto-rapidocr"
        if roi is None:
            print("auto calibration found no readout text. Pass --roi x,y,w,h (see the grid in the preview).")
    out_dir = os.path.dirname(os.path.abspath(a.out)) or "."
    os.makedirs(out_dir, exist_ok=True)
    fr = v.frame(frames[0])
    prev = fr.copy()
    # 100 px grid to help reading coordinates for a manual --roi
    for x in range(0, v.width, 100):
        cv2.line(prev, (x, 0), (x, v.height), (80, 80, 80), 1)
        cv2.putText(prev, str(x), (x + 2, 12), cv2.FONT_HERSHEY_PLAIN, 0.9, (0, 255, 255), 1)
    for y in range(0, v.height, 100):
        cv2.line(prev, (0, y), (v.width, y), (80, 80, 80), 1)
        cv2.putText(prev, str(y), (2, y + 12), cv2.FONT_HERSHEY_PLAIN, 0.9, (0, 255, 255), 1)
    base = os.path.splitext(os.path.abspath(a.out))[0]
    if roi is not None:
        x, y, w, h = roi
        cv2.rectangle(prev, (x, y), (x + w, y + h), (0, 0, 255), 2)
        for fi in frames:
            cv2.imwrite("%s_crop_f%d.png" % (base, fi), mc_ocr.crop(v.frame(fi), roi))
        with open(a.out, "w", encoding="utf-8") as f:
            json.dump({"roi": roi, "video": os.path.abspath(a.video), "video_size": [v.width, v.height],
                       "fps": v.fps, "source": source, "frames_checked": frames, "ocr_hits": hits}, f, indent=2)
        print("ROI %s saved to %s" % (roi, a.out))
    cv2.imwrite(base + "_preview.png", prev)
    print("preview: %s_preview.png" % base)
    v.close()
    return 0 if roi is not None else 2


# ----------------------------------------------------------------------------------------------
# label-dump / train-templates
# ----------------------------------------------------------------------------------------------

def cmd_label_dump(a) -> int:
    layout = mc_ocr.load_layout(a.layout)
    v = Video(a.video)
    roi = parse_roi(a.roi)
    frames = parse_frames(a.frames, v.count, 4)
    base = os.path.splitext(os.path.abspath(a.out))[0]
    ocr = None
    try:
        ocr = mc_ocr.RapidOCRBackend(layout)
    except Exception as e:  # rapidocr missing is fine: user types labels by hand
        print("rapidocr unavailable (%s); labels will be empty" % e)
    entries = []
    for fi in frames:
        img = mc_ocr.crop(v.frame(fi), roi)
        png = "%s_f%d.png" % (base, fi)
        cv2.imwrite(png, img)
        b = mc_ocr.binarize(img, layout["binarize"])
        cv2.imwrite("%s_f%d_bin.png" % (base, fi), b)
        n_lines = len(mc_ocr.segment_lines(b, layout["segment"]))
        guess = ocr.read(img)[0] if ocr else []
        entries.append({"frame": fi, "image": png, "segmented_lines": n_lines, "lines": guess})
    with open(a.out, "w", encoding="utf-8") as f:
        json.dump({"video": os.path.abspath(a.video), "roi": roi,
                   "_instructions": "Correct every 'lines' entry to exactly what the crop shows, top to bottom, one string per text line. "
                                    "'segmented_lines' is how many lines the binarizer sees; it must equal len(lines) or that frame is skipped "
                                    "(tune layout binarize.threshold if it differs).",
                   "labels": entries}, f, indent=2)
    print("wrote %s (%d frames). Correct the 'lines' by hand, then run train-templates." % (a.out, len(entries)))
    v.close()
    return 0


def cmd_train(a) -> int:
    layout = mc_ocr.load_layout(a.layout)
    with open(a.labels, "r", encoding="utf-8") as f:
        lab = json.load(f)
    video = a.video or lab.get("video")
    v = Video(video)
    roi = parse_roi(a.roi) if a.roi else lab["roi"]
    samples = []
    for e in lab["labels"]:
        samples.append((mc_ocr.crop(v.frame(int(e["frame"])), roi), list(e["lines"])))
    t = mc_ocr.TemplateOCR(layout)
    rep = t.train(samples)
    t.save(a.out)
    print(json.dumps(rep, indent=2))
    if rep["missing_chars"]:
        print("WARNING: no template for %s. Label more frames that contain them." % "".join(rep["missing_chars"]))
    v.close()
    return 0


# ----------------------------------------------------------------------------------------------
# extract
# ----------------------------------------------------------------------------------------------

def run_extract(video_path: str, roi, layout: dict, backend, out_csv: str, start: int = 0, end: int | None = None,
                every: int = 1, fps_override: float | None = None, time_source: str = "fps", post_opts: dict | None = None,
                debug_dir: str | None = None, quiet: bool = False) -> dict:
    v = Video(video_path)
    fps = fps_override or v.fps
    if not fps or fps <= 0:
        raise SystemExit("video reports no fps; pass --fps")
    cols = mc_ocr.all_columns(layout)
    frames, msec, texts = [], [], []
    raw = {c: [] for c in cols}
    confs = []
    t0 = time.time()
    for i, ms, fr in v.iterate(start, end, every):
        img = mc_ocr.crop(fr, roi)
        lines, conf = backend.read(img)
        vals = mc_ocr.parse_lines(lines, layout)
        frames.append(i)
        msec.append(ms)
        texts.append(" | ".join(lines))
        confs.append(conf)
        for c in cols:
            raw[c].append(vals.get(c, float("nan")))
        if debug_dir and not all(k in vals for k in ("pos_x", "pos_y", "pos_z")):
            os.makedirs(debug_dir, exist_ok=True)
            cv2.imwrite(os.path.join(debug_dir, "unparsed_f%06d.png" % i), img)
        if not quiet and len(frames) % 200 == 0:
            print("  %d frames (%.1f f/s)" % (len(frames), len(frames) / max(1e-6, time.time() - t0)))
    v.close()
    t, fixes = mc_post.monotonic_times(frames, fps, msec if time_source == "msec" else None)
    opts = {"hampel_window": 3, "hampel_k": 4.0, "tol_pos": 3.0, "tol_vel": 3.0, "tol_ang": 1.0}
    if post_opts:
        opts.update(post_opts)
    rows, summary = mc_post.process(frames, t, raw, layout, opts)
    os.makedirs(os.path.dirname(os.path.abspath(out_csv)) or ".", exist_ok=True)
    mc_post.write_csv(out_csv, rows)
    summary.update({
        "video": os.path.abspath(video_path), "roi": list(roi), "fps": fps, "time_source": time_source,
        "time_fixes": fixes, "backend": backend.name, "cleaning": opts,
        "units": "game units (u) and u/s as printed by the overlay; 1 u = 1/units_per_meter m",
        "units_per_meter": layout.get("units_per_meter"), "up_axis": layout.get("up_axis"),
        "min_ocr_confidence": float(np.min(confs)) if confs else None,
        "seconds": round(time.time() - t0, 2),
    })
    with open(os.path.splitext(out_csv)[0] + "_summary.json", "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2)
    with open(os.path.splitext(out_csv)[0] + "_ocr_text.txt", "w", encoding="utf-8") as f:
        for fi, tx in zip(frames, texts):
            f.write("%d\t%s\n" % (fi, tx))
    return summary


def cmd_extract(a) -> int:
    layout = mc_ocr.load_layout(a.layout)
    roi = parse_roi(a.roi)
    backend = mc_ocr.make_backend(a.backend, layout, a.templates)
    post = {"hampel_window": a.hampel_window, "hampel_k": a.hampel_k, "tol_pos": a.tol_pos, "tol_vel": a.tol_vel, "tol_ang": a.tol_ang}
    s = run_extract(a.video, roi, backend.layout if hasattr(backend, "layout") else layout, backend, a.out, a.start_frame,
                    a.end_frame, a.every, a.fps, a.time_source, post, a.debug_dir)
    print(json.dumps(s, indent=2))
    if s["valid_rows"] < 0.5 * max(1, s["frames"]):
        print("WARNING: fewer than half the frames are valid. Check the ROI preview, layout regexes and binarize threshold.")
        return 3
    return 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    c = sub.add_parser("calibrate", help="find/set the readout ROI and save it to JSON")
    c.add_argument("video")
    c.add_argument("--out", required=True, help="ROI JSON path (a _preview.png and crops are written next to it)")
    c.add_argument("--roi", help="x,y,w,h in video pixels; omit to auto-detect with RapidOCR")
    c.add_argument("--frames", help="comma list of frame indices to check (default: 5 spread over the clip)")
    c.add_argument("--margin", type=int, default=8)
    c.add_argument("--layout", default=DEFAULT_LAYOUT)
    c.set_defaults(fn=cmd_calibrate)

    d = sub.add_parser("label-dump", help="save ROI crops and a labels JSON to correct by hand")
    d.add_argument("video")
    d.add_argument("--roi", required=True)
    d.add_argument("--frames", help="comma list (default: 4 spread over the clip). Pick frames whose digits cover 0-9, '.', '-'")
    d.add_argument("--out", required=True)
    d.add_argument("--layout", default=DEFAULT_LAYOUT)
    d.set_defaults(fn=cmd_label_dump)

    t = sub.add_parser("train-templates", help="learn glyph templates from corrected labels")
    t.add_argument("--labels", required=True)
    t.add_argument("--video", help="defaults to the video named in the labels JSON")
    t.add_argument("--roi", help="defaults to the ROI in the labels JSON")
    t.add_argument("--out", required=True, help="templates .npz")
    t.add_argument("--layout", default=DEFAULT_LAYOUT)
    t.set_defaults(fn=cmd_train)

    e = sub.add_parser("extract", help="read every frame and write the CSV")
    e.add_argument("video")
    e.add_argument("--roi", required=True, help="x,y,w,h or the ROI JSON from calibrate")
    e.add_argument("--out", required=True, help="output CSV")
    e.add_argument("--backend", choices=["template", "rapidocr"], default="rapidocr")
    e.add_argument("--templates", help="templates .npz (backend template)")
    e.add_argument("--layout", default=DEFAULT_LAYOUT)
    e.add_argument("--start-frame", type=int, default=0)
    e.add_argument("--end-frame", type=int, default=None)
    e.add_argument("--every", type=int, default=1)
    e.add_argument("--fps", type=float, default=None, help="override the container fps")
    e.add_argument("--time-source", choices=["fps", "msec"], default="fps",
                   help="fps: t = frame/fps (CFR recordings). msec: container timestamps, forced monotonic (VFR)")
    e.add_argument("--hampel-window", type=int, default=3, help="neighbours per side for outlier rejection")
    e.add_argument("--hampel-k", type=float, default=4.0)
    e.add_argument("--tol-pos", type=float, default=3.0, help="absolute outlier tolerance, u")
    e.add_argument("--tol-vel", type=float, default=3.0, help="absolute outlier tolerance, u/s")
    e.add_argument("--tol-ang", type=float, default=1.0, help="absolute outlier tolerance, degrees")
    e.add_argument("--debug-dir", help="save crops of frames that failed to parse")
    e.set_defaults(fn=cmd_extract)

    a = ap.parse_args(argv)
    return int(a.fn(a) or 0)


if __name__ == "__main__":
    sys.exit(main())
