"""OCR backends and readout parsing for the cl_showpos capture pipeline.

Two backends read the text lines inside the ROI:
  * "template": glyph template matching. Templates are learned from a few user-labeled frames
    (train-templates). Fast, deterministic, best for a fixed HUD font.
  * "rapidocr": RapidOCR (pip, ONNX runtime). No training, slower, can misread; the
    post-processing outlier filter in mc_post.py catches most single-frame misreads.

Parsing is driven by a layout JSON (layouts/showpos_default.json) because the in-game readout
format is not verified.
"""
from __future__ import annotations

import json
import math
import re
from dataclasses import dataclass, field

import cv2
import numpy as np

GLYPH_W = 14
GLYPH_H = 22

# OCR confusables, applied only to the numeric part of a line (after the label).
_CONFUSABLES = str.maketrans({
    "O": "0", "o": "0", "D": "0", "Q": "0",
    "l": "1", "I": "1", "|": "1", "i": "1", "!": "1",
    "S": "5", "s": "5",
    "B": "8",
    "Z": "2", "z": "2",
    ",": ".",
    "−": "-", "–": "-", "—": "-", "_": "-", "~": "-",
})


# ----------------------------------------------------------------------------------------------
# layout
# ----------------------------------------------------------------------------------------------

def load_layout(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        lay = json.load(f)
    lay.setdefault("decimals", None)
    lay.setdefault("up_axis", "z")
    lay.setdefault("units_per_meter", 39.3701)
    lay.setdefault("binarize", {})
    lay["binarize"].setdefault("method", "fixed")
    lay["binarize"].setdefault("threshold", 170)
    lay["binarize"].setdefault("upscale", 2)
    lay["binarize"].setdefault("invert", False)
    lay.setdefault("segment", {})
    lay["segment"].setdefault("min_line_px", 6)
    lay["segment"].setdefault("line_merge_gap_px", 2)
    lay["segment"].setdefault("space_gap_frac", 0.33)
    for fd in lay["fields"]:
        fd.setdefault("alt_names", [])
        fd.setdefault("optional", False)
    return lay


def all_columns(layout: dict) -> list[str]:
    cols: list[str] = []
    for fd in layout["fields"]:
        for n in fd["names"]:
            if n not in cols:
                cols.append(n)
        for alt in fd["alt_names"]:
            for n in alt:
                if n not in cols:
                    cols.append(n)
    return cols


def number_regex(layout: dict) -> str:
    d = layout.get("decimals")
    if d is None:
        return r"[-+]?\d+(?:\.\d+)?"
    return r"[-+]?\d+\.\d{%d}" % int(d)


def parse_lines(lines: list[str], layout: dict) -> dict:
    """Maps OCR lines to column values. Missing / unparsable fields are absent from the result."""
    out: dict = {}
    num_re = re.compile(number_regex(layout))
    for idx_field, fd in enumerate(layout["fields"]):
        if "full_regex" in fd:
            rx = re.compile(fd["full_regex"], re.IGNORECASE)
            for ln in lines:
                m = rx.search(ln)
                if m:
                    try:
                        for k, v in m.groupdict().items():
                            if v is not None:
                                out[k] = float(v.translate(_CONFUSABLES))
                    except ValueError:
                        pass
                    break
            continue
        candidates: list[str] = []
        if "line_index" in fd:
            li = int(fd["line_index"])
            if 0 <= li < len(lines):
                candidates.append(lines[li])
        else:
            lab = re.compile(fd["label"], re.IGNORECASE)
            for ln in lines:
                m = lab.search(ln)
                if m:
                    candidates.append(ln[m.end():])
                    break
        for rest in candidates:
            txt = rest.translate(_CONFUSABLES)
            if layout.get("decimals") is None:
                nums = re.findall(r"[-+]?\d+(?:\.\d+)?", txt)
            else:
                # known decimals: numbers may be glued together by OCR ("12.34-5.67")
                nums = num_re.findall(txt.replace(" ", " "))
            vals = []
            for s in nums:
                try:
                    vals.append(float(s))
                except ValueError:
                    pass
            for names in [fd["names"]] + list(fd["alt_names"]):
                if len(vals) == len(names):
                    for n, v in zip(names, vals):
                        out[n] = v
                    break
    return out


# ----------------------------------------------------------------------------------------------
# image helpers
# ----------------------------------------------------------------------------------------------

def crop(frame: np.ndarray, roi) -> np.ndarray:
    x, y, w, h = [int(v) for v in roi]
    H, W = frame.shape[:2]
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(W, x + w), min(H, y + h)
    return frame[y0:y1, x0:x1]


def upscaled_gray(img: np.ndarray, cfg: dict) -> np.ndarray:
    gray = img if img.ndim == 2 else cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    up = float(cfg.get("upscale", 2))
    if up != 1.0:
        gray = cv2.resize(gray, None, fx=up, fy=up, interpolation=cv2.INTER_CUBIC)
    return gray


def glyph_features(img: np.ndarray, binary: np.ndarray, cfg: dict) -> np.ndarray:
    """Soft (grey-level) glyph image used for matching: keeps stroke detail that a hard threshold
    loses after video compression (e.g. the waist of an '8'). Pixels far from any foreground
    pixel are zeroed so the moving background does not leak in."""
    gray = upscaled_gray(img, cfg).astype(np.float32)
    thr = float(cfg.get("threshold", 170))
    soft = np.clip((gray - (thr - 80.0)) / 120.0, 0.0, 1.0)
    if cfg.get("invert", False):
        soft = 1.0 - soft
    near = cv2.dilate((binary > 0).astype(np.uint8), np.ones((3, 3), np.uint8)) > 0
    return (soft * near * 255.0).astype(np.uint8)


def binarize(img: np.ndarray, cfg: dict) -> np.ndarray:
    gray = img if img.ndim == 2 else cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    up = float(cfg.get("upscale", 2))
    if up != 1.0:
        gray = cv2.resize(gray, None, fx=up, fy=up, interpolation=cv2.INTER_CUBIC)
    if cfg.get("method", "fixed") == "otsu":
        _, b = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY | cv2.THRESH_OTSU)
    else:
        _, b = cv2.threshold(gray, int(cfg.get("threshold", 170)), 255, cv2.THRESH_BINARY)
    if cfg.get("invert", False):
        b = 255 - b
    return b


def _runs(mask: np.ndarray) -> list[tuple[int, int]]:
    """[start, end) runs of True."""
    runs = []
    n = len(mask)
    i = 0
    while i < n:
        if mask[i]:
            j = i
            while j < n and mask[j]:
                j += 1
            runs.append((i, j))
            i = j
        else:
            i += 1
    return runs


def segment_lines(binary: np.ndarray, seg: dict) -> list[tuple[int, int]]:
    rows = (binary > 0).sum(axis=1) > 0
    runs = _runs(rows)
    merged: list[list[int]] = []
    gap = int(seg.get("line_merge_gap_px", 2))
    for a, b in runs:
        if merged and a - merged[-1][1] <= gap:
            merged[-1][1] = b
        else:
            merged.append([a, b])
    min_h = int(seg.get("min_line_px", 6))
    return [(a, b) for a, b in merged if b - a >= min_h]


@dataclass
class Glyph:
    x0: int
    x1: int
    vec: np.ndarray
    ratio: float          # width / ink height
    space_before: bool = False
    height: float = 0.0   # ink height in px
    rel_h: float = 1.0    # ink height / median ink height of the line


def _glyph_vec(frows: np.ndarray, brows: np.ndarray, x0: int, x1: int) -> tuple[np.ndarray, float, float]:
    """Feature vector of one glyph cropped tight to its ink (so lines with and without descenders
    give the same vectors). Returns (unit vector, width/height ratio, ink height)."""
    ink = np.flatnonzero((brows[:, x0:x1] > 0).any(axis=1))
    y0, y1 = (int(ink[0]), int(ink[-1]) + 1) if len(ink) else (0, brows.shape[0])
    g = frows[y0:y1, x0:x1].astype(np.float32) / 255.0
    h, w = g.shape
    ratio = w / max(1.0, float(h))
    g = cv2.resize(g, (GLYPH_W, GLYPH_H), interpolation=cv2.INTER_AREA)
    v = g.flatten()
    v = v - v.mean()
    n = np.linalg.norm(v)
    if n > 1e-6:
        v = v / n
    return v, ratio, float(h)


def segment_glyphs(binary: np.ndarray, band: tuple[int, int], seg: dict, split_w: float | None = None,
                   feat: np.ndarray | None = None) -> list[Glyph]:
    a, b = band
    rows = binary[a:b]
    frows = feat[a:b] if feat is not None else rows
    cols = (rows > 0).sum(axis=0) > 0
    runs = _runs(cols)
    h = b - a
    # split over-wide runs (touching glyphs after compression blur) at the weakest columns
    if split_w and split_w > 0:
        out_runs = []
        colsum = (rows > 0).sum(axis=0)
        for x0, x1 in runs:
            w = x1 - x0
            n = int(round(w / split_w))
            if n >= 2 and w > 1.45 * split_w:
                cuts = [x0]
                for k in range(1, n):
                    c = x0 + int(round(k * w / n))
                    lo, hi = max(x0 + 1, c - 2), min(x1 - 1, c + 3)
                    best = lo + int(np.argmin(colsum[lo:hi])) if hi > lo else c
                    cuts.append(best)
                cuts.append(x1)
                for k in range(len(cuts) - 1):
                    if cuts[k + 1] > cuts[k]:
                        out_runs.append((cuts[k], cuts[k + 1]))
            else:
                out_runs.append((x0, x1))
        runs = out_runs
    glyphs: list[Glyph] = []
    space_px = max(2.0, float(seg.get("space_gap_frac", 0.33)) * h)
    prev_x1 = None
    for x0, x1 in runs:
        v, r, gh = _glyph_vec(frows, rows, x0, x1)
        sp = prev_x1 is not None and (x0 - prev_x1) >= space_px
        glyphs.append(Glyph(x0, x1, v, r, sp, gh))
        prev_x1 = x1
    if glyphs:
        ref = float(np.median([g.height for g in glyphs])) or 1.0
        for g in glyphs:
            g.rel_h = g.height / ref
    return glyphs


# ----------------------------------------------------------------------------------------------
# template backend
# ----------------------------------------------------------------------------------------------

class TemplateOCR:
    """Glyph-template OCR for a fixed-font overlay. Trained from a few labeled frames of the user's
    own recording (same resolution / HUD scale), so it adapts to the real font without guessing it.
    Matching is nearest-neighbour over all training glyphs (cosine on soft grey-level glyphs) with a
    width-ratio penalty. After the field label separator (default ':') only numeric characters are
    allowed, which removes letter/digit confusions inside the numbers."""
    name = "template"
    MAX_PER_CHAR = 60

    def __init__(self, layout: dict, templates_path: str | None = None):
        self.layout = layout
        self.chars: list[str] = []
        self.vecs: np.ndarray | None = None
        self.ratios: np.ndarray | None = None
        self.labels: np.ndarray | None = None  # index into self.chars per template row
        self.rel_h: np.ndarray | None = None
        self.split_w: float | None = None
        if templates_path:
            self.load(templates_path)

    def _prep(self, img):
        b = binarize(img, self.layout["binarize"])
        f = glyph_features(img, b, self.layout["binarize"])
        return b, f

    # -- training --------------------------------------------------------------------------
    def train(self, samples: list[tuple[np.ndarray, list[str]]]) -> dict:
        """samples: (roi image, labeled lines top-to-bottom). Returns a report dict."""
        acc: dict[str, list[tuple[np.ndarray, float]]] = {}
        report = {"lines_used": 0, "lines_skipped": [], "chars": {}}
        widths = []
        for si, (img, lines) in enumerate(samples):
            b, f = self._prep(img)
            bands = segment_lines(b, self.layout["segment"])
            labeled = [ln for ln in lines if ln.strip()]
            if len(bands) != len(labeled):
                report["lines_skipped"].append({"sample": si, "reason": "found %d text lines, labels have %d" % (len(bands), len(labeled))})
                continue
            for band, text in zip(bands, labeled):
                chars = [c for c in text if not c.isspace()]
                gl = segment_glyphs(b, band, self.layout["segment"], feat=f)
                if len(gl) != len(chars):
                    report["lines_skipped"].append({"sample": si, "text": text, "reason": "segmented %d glyphs for %d chars" % (len(gl), len(chars))})
                    continue
                report["lines_used"] += 1
                for g, c in zip(gl, chars):
                    acc.setdefault(c, []).append((g.vec, g.ratio, g.rel_h))
                    if c.isdigit():
                        widths.append(g.x1 - g.x0)
        if not acc:
            raise RuntimeError("template training found no usable labeled lines: %s" % report["lines_skipped"])
        self.chars = sorted(acc.keys())
        vecs, ratios, rels, labels = [], [], [], []
        for ci, c in enumerate(self.chars):
            items = acc[c][: self.MAX_PER_CHAR]
            for v, r, rh in items:
                vecs.append(v)
                ratios.append(r)
                rels.append(rh)
                labels.append(ci)
            report["chars"][c] = len(acc[c])
        self.vecs = np.stack(vecs).astype(np.float32)
        self.ratios = np.array(ratios, dtype=np.float32)
        self.labels = np.array(labels, dtype=np.int32)
        self.rel_h = np.array(rels, dtype=np.float32)
        self.split_w = float(np.median(widths)) if widths else None
        report["missing_chars"] = [c for c in "0123456789.-" if c not in self.chars]
        return report

    def save(self, path: str) -> None:
        np.savez(path, chars=np.array(self.chars), vecs=self.vecs, ratios=self.ratios, labels=self.labels, rel_h=self.rel_h,
                 split_w=np.array([self.split_w if self.split_w else 0.0]),
                 binarize=json.dumps(self.layout["binarize"]), segment=json.dumps(self.layout["segment"]))

    def load(self, path: str) -> None:
        d = np.load(path, allow_pickle=False)
        self.chars = [str(c) for c in d["chars"]]
        self.vecs = d["vecs"]
        self.ratios = d["ratios"]
        self.labels = d["labels"]
        self.rel_h = d["rel_h"]
        sw = float(d["split_w"][0])
        self.split_w = sw if sw > 0 else None
        # the binarization used at training time must be reused
        self.layout = dict(self.layout)
        self.layout["binarize"] = json.loads(str(d["binarize"]))
        self.layout["segment"] = json.loads(str(d["segment"]))

    # -- recognition -----------------------------------------------------------------------
    def read(self, img: np.ndarray) -> tuple[list[str], float]:
        """Returns (lines, confidence in [0,1]: the worst glyph similarity)."""
        b, f = self._prep(img)
        bands = segment_lines(b, self.layout["segment"])
        sep = self.layout.get("label_separator", ":")
        numeric = set("0123456789.-+")
        is_num = np.array([self.chars[l] in numeric for l in self.labels])
        lines = []
        worst = 1.0
        for band in bands:
            gl = segment_glyphs(b, band, self.layout["segment"], self.split_w, feat=f)
            s = []
            after_sep = False
            for g in gl:
                sims = self.vecs @ g.vec
                # penalize width mismatch so '.', '1', ':' and '-' separate cleanly
                score = (sims - 0.35 * np.abs(np.log((g.ratio + 1e-2) / (self.ratios + 1e-2)))
                         - 0.35 * np.abs(np.log((g.rel_h + 1e-2) / (self.rel_h + 1e-2))))
                if after_sep and is_num.any():
                    score = np.where(is_num, score, -np.inf)
                k = int(np.argmax(score))
                ch = self.chars[int(self.labels[k])]
                worst = min(worst, float(max(0.0, sims[k])))
                if g.space_before:
                    s.append(" ")
                s.append(ch)
                if sep and ch == sep:
                    after_sep = True
            lines.append("".join(s))
        return lines, worst


# ----------------------------------------------------------------------------------------------
# rapidocr backend
# ----------------------------------------------------------------------------------------------

class RapidOCRBackend:
    name = "rapidocr"

    def __init__(self, layout: dict, upscale: float = 2.0):
        from rapidocr_onnxruntime import RapidOCR  # imported lazily: heavy
        self.engine = RapidOCR()
        self.layout = layout
        self.upscale = upscale

    def detect(self, img: np.ndarray) -> list[tuple[list, str, float]]:
        res, _ = self.engine(img, use_cls=False)
        return res or []

    def read(self, img: np.ndarray) -> tuple[list[str], float]:
        """Line mode (fast, ~30 ms/line): split lines with the layout binarizer, then run the
        recognizer only. Falls back to detector mode (~0.7 s/frame) when no line is found."""
        bcfg = self.layout["binarize"]
        up = float(bcfg.get("upscale", 2))
        b = binarize(img, bcfg)
        bands = segment_lines(b, self.layout["segment"])
        if not bands:
            return self.read_detect(img)
        lines, conf = [], 1.0
        for a, bb in bands:
            y0 = max(0, int(a / up) - 3)
            y1 = min(img.shape[0], int(math.ceil(bb / up)) + 3)
            cols = np.flatnonzero((b[a:bb] > 0).sum(axis=0) > 0)
            x0 = max(0, int(cols[0] / up) - 4) if len(cols) else 0
            x1 = min(img.shape[1], int(math.ceil(cols[-1] / up)) + 5) if len(cols) else img.shape[1]
            line = cv2.copyMakeBorder(img[y0:y1, x0:x1], 4, 4, 8, 8, cv2.BORDER_REPLICATE)
            res, _ = self.engine(line, use_det=False, use_cls=False)
            if res:
                text, score = res[0][0], float(res[0][1])
                lines.append(text)
                conf = min(conf, score)
        return lines, conf

    def read_detect(self, img: np.ndarray) -> tuple[list[str], float]:
        up = cv2.resize(img, None, fx=self.upscale, fy=self.upscale, interpolation=cv2.INTER_CUBIC) if self.upscale != 1 else img
        # pad: detectors dislike text touching the border
        up = cv2.copyMakeBorder(up, 16, 16, 16, 16, cv2.BORDER_REPLICATE)
        res = self.detect(up)
        return group_lines(res)


def group_lines(res: list) -> tuple[list[str], float]:
    """Groups detector boxes into top-to-bottom lines, left-to-right within a line."""
    if not res:
        return [], 0.0
    items = []
    for box, text, score in res:
        ys = [p[1] for p in box]
        xs = [p[0] for p in box]
        items.append(((min(ys) + max(ys)) / 2.0, max(ys) - min(ys), min(xs), text, float(score)))
    items.sort(key=lambda t: t[0])
    med_h = float(np.median([t[1] for t in items])) if items else 1.0
    lines: list[list] = []
    for it in items:
        if lines and abs(it[0] - lines[-1][0][0]) < 0.5 * med_h:
            lines[-1].append(it)
        else:
            lines.append([it])
    out = []
    conf = 1.0
    for ln in lines:
        ln.sort(key=lambda t: t[2])
        out.append(" ".join(t[3] for t in ln))
        conf = min(conf, min(t[4] for t in ln))
    return out, conf


def make_backend(name: str, layout: dict, templates: str | None = None):
    if name == "template":
        if not templates:
            raise SystemExit("--backend template needs --templates <file.npz> (see train-templates)")
        return TemplateOCR(layout, templates)
    if name == "rapidocr":
        return RapidOCRBackend(layout)
    raise SystemExit("unknown backend %r" % name)
