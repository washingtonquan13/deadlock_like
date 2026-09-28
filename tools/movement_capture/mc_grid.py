"""Fixed-grid template reader for the cl_showpos readout.

The readout is a monospace font drawn at a fixed place, so every character sits in a known cell:
cell (line, col) spans x = x0 + pitch*col .. + pitch, y = top[line] + y_off .. + height (ROI pixels).
Each cell is thresholded and compared (L1) with a template per character, allowing a shift of up to
`slack` px (strokes are 1-2 px wide, so a 1 px offset would otherwise ruin the match); an empty cell is a space.
Templates are learned from cells whose label is known (lines the general OCR read in the exact
'%.2f' format), so nothing is hand-drawn. Values are parsed from the per-line strings with a strict
format check; a line that fails the check is reported as missing, never guessed.

Grid measured 2026-09-27 at 1920x1080 (ROI 0,217,567,146): pitch 17.015 px (glyph-centroid fit), value text starts at col 6,
line tops 16/48/80/112 (name/pos/ang/vel).
"""
from __future__ import annotations

import re

import numpy as np

CHARS = "0123456789.-() "
LINES = {"pos": 1, "ang": 2, "vel": 3}
FMT = {
    "pos": re.compile(r"^(-?\d+\.\d\d) (-?\d+\.\d\d) (-?\d+\.\d\d)$"),
    "ang": re.compile(r"^(-?\d+\.\d\d) (-?\d+\.\d\d) (-?\d+\.\d\d)$"),
    "vel": re.compile(r"^(-?\d+\.\d\d) \((-?\d+\.\d\d)\)$"),
}
NAMES = {"pos": ["pos_x", "pos_y", "pos_z"], "ang": ["ang_pitch", "ang_yaw", "ang_roll"],
         "vel": ["vel_scalar", "vel_scalar2"]}
DEFAULT_GRID = {"x0": 1.28, "pitch": 17.015, "col0": 6, "ncols": 26, "tops": [16, 48, 80, 112], "y_off": -4,
                "height": 30, "width": 17, "threshold": 200, "slack": 2}


class GridReader:
    name = "grid"

    def __init__(self, templates: str | dict | None = None, grid: dict | None = None):
        self.grid = dict(DEFAULT_GRID)
        if grid:
            self.grid.update(grid)
        self.tmpl = None
        if isinstance(templates, str):
            z = np.load(templates, allow_pickle=True)
            self.tmpl = {c: z["t_%d" % ord(c)] for c in CHARS if "t_%d" % ord(c) in z}
            self.grid.update(z["grid"].item())
        elif isinstance(templates, dict):
            self.tmpl = templates

    def cells(self, img: np.ndarray, key: str) -> np.ndarray:
        """-> (ncols, height + 2*slack, width + 2*slack) binary cells of the value part of one line, each with
        `slack` px of margin so a template can be matched at small offsets."""
        g = self.grid
        m = int(g["slack"])
        if img.ndim == 3:
            img = img.max(axis=2)
        H, W = g["height"] + 2 * m, g["width"] + 2 * m
        y0 = g["tops"][LINES[key]] + g["y_off"] - m
        pad = np.pad(img, ((H, H), (W, W)))
        out = np.zeros((g["ncols"], H, W), np.float32)
        for k in range(g["ncols"]):
            x = int(round(g["x0"] + g["pitch"] * (g["col0"] + k))) - m
            out[k] = pad[y0 + H: y0 + 2 * H, x + W: x + 2 * W] >= g["threshold"]
        return out

    def _dist(self, cell: np.ndarray, T: np.ndarray) -> np.ndarray:
        """min over offsets of L1(template, cell window) -> (ntemplates,)"""
        g = self.grid
        m, h, w = int(g["slack"]), g["height"], g["width"]
        best = None
        for dy in range(-min(m, 1), min(m, 1) + 1):
            for dx in range(-m, m + 1):
                win = cell[m + dy: m + dy + h, m + dx: m + dx + w]
                d = np.abs(T - win[None]).sum(axis=(1, 2))
                best = d if best is None else np.minimum(best, d)
        return best

    def read_line(self, img: np.ndarray, key: str) -> str:
        cs = self.cells(img, key)
        chars = list(self.tmpl.keys())
        T = np.stack([self.tmpl[c] for c in chars])
        return "".join(chars[int(np.argmin(self._dist(c, T)))] for c in cs).rstrip()

    def read(self, img: np.ndarray) -> dict:
        vals = {}
        for key in LINES:
            m = FMT[key].match(self.read_line(img, key))
            if m:
                for n, v in zip(NAMES[key], m.groups()):
                    vals[n] = float(v)
        return vals


def train(samples: list[tuple[np.ndarray, str, str]], grid: dict | None = None, out: str | None = None) -> dict:
    """samples: (img, line_key, value_text) with value_text exactly as drawn (single spaces).
    Each labelled cell is aligned to its character's running template (best offset within the slack)
    before averaging, two passes. Returns {char: mean binary cell}; empty cells give the space template."""
    r = GridReader(grid=grid)
    g = r.grid
    m, h, w = int(g["slack"]), g["height"], g["width"]
    by: dict[str, list] = {}
    for img, key, text in samples:
        cs = r.cells(img, key)
        text = text.ljust(g["ncols"])[: g["ncols"]]
        for ch, c in zip(text, cs):
            if ch in CHARS:
                by.setdefault(ch, []).append(c)
    tmpl = {ch: v[0][m: m + h, m: m + w].copy() for ch, v in by.items()}
    for _ in range(2):
        for ch, v in by.items():
            acc = []
            for c in v:
                best, bw = None, None
                for dy in range(-min(m, 1), min(m, 1) + 1):
                    for dx in range(-m, m + 1):
                        win = c[m + dy: m + dy + h, m + dx: m + dx + w]
                        d = float(np.abs(tmpl[ch] - win).sum())
                        if best is None or d < best:
                            best, bw = d, win
                acc.append(bw)
            tmpl[ch] = np.mean(acc, axis=0).astype(np.float32)
    if out:
        np.savez_compressed(out, grid=np.array(g, dtype=object), **{"t_%d" % ord(c): t for c, t in tmpl.items()})
    return tmpl


def autolabel(frames, layout: dict, every: int = 2) -> list[tuple[np.ndarray, str, str]]:
    """Labels for train(): runs the general OCR (RapidOCR) on binarised single lines and keeps only lines
    that match the exact '%.2f' format. Wrong-but-well-formed reads are rare and are outvoted in the mean."""
    import math
    import cv2
    import mc_ocr
    from rapidocr_onnxruntime import RapidOCR
    eng = RapidOCR()
    num = r"(-?\d+\.\d\d)"
    pats = {"pos": re.compile(r"^pos:\s*%s\s+%s\s+%s$" % (num, num, num)),
            "ang": re.compile(r"^ang:\s*%s\s+%s\s+%s$" % (num, num, num)),
            "vel": re.compile(r"^vel:\s*%s\s*\(%s\).{0,6}$" % (num, num))}  # the OCR adds junk after ")"
    up = float(layout["binarize"].get("upscale", 2))
    out = []
    for i in range(0, len(frames), every):
        img = frames[i]
        b = mc_ocr.binarize(img, layout["binarize"])
        for a, bb in mc_ocr.segment_lines(b, layout["segment"]):
            y0, y1 = max(0, int(a / up) - 3), min(img.shape[0], int(math.ceil(bb / up)) + 3)
            L = cv2.resize(255 - mc_ocr.binarize(img[y0:y1], layout["binarize"]), None, fx=1 / up, fy=1 / up)
            L = cv2.copyMakeBorder(L, 8, 8, 12, 12, cv2.BORDER_REPLICATE)
            res, _ = eng(cv2.cvtColor(L, cv2.COLOR_GRAY2BGR), use_det=False, use_cls=False)
            if not res:
                continue
            s = re.sub(r"\s+", " ", res[0][0].replace("（", "(").replace("）", ")").strip())
            for k, p in pats.items():
                mt = p.match(s)
                if mt:
                    gr = mt.groups()
                    out.append((img, k, " ".join(gr) if k != "vel" else "%s (%s)" % gr))
    return out
