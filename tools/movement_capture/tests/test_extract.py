"""Accuracy tests for extract.py on synthetic cl_showpos-style videos with known values.

Run:  .venv\\Scripts\\python.exe -m unittest discover -s tests -v      (from tools/movement_capture)
Set MC_SKIP_RAPIDOCR=1 to skip the slower RapidOCR test.
"""
from __future__ import annotations

import csv
import json
import math
import os
import shutil
import sys
import tempfile
import unittest

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, ROOT)

import extract  # noqa: E402
import mc_ocr  # noqa: E402
import mc_post  # noqa: E402
import synth  # noqa: E402

LAYOUT = mc_ocr.load_layout(os.path.join(ROOT, "layouts", "showpos_default.json"))
TMP = tempfile.mkdtemp(prefix="mc_test_")


def read_out(path):
    with open(path, newline="") as f:
        rows = list(csv.DictReader(f))

    def col(k):
        return np.array([float(r[k]) if r[k] != "" else np.nan for r in rows])
    return rows, col


def label_frames_from_truth(truth, vel_mode, n_min=4):
    """Pick uncorrupted frames until every digit, '.', '-' is covered (what a user would label)."""
    need = set("0123456789.-")
    have = set()
    chosen = []
    n = len(truth["frame"])
    order = list(range(5, n, max(1, n // 12)))
    for i in order:
        if truth["corrupted"][i] > 0:
            continue
        lines = synth.overlay_lines([truth["pos_x"][i], truth["pos_y"][i], truth["pos_z"][i]],
                                    [truth["vel_x"][i], truth["vel_y"][i], truth["vel_z"][i]],
                                    [truth["ang_pitch"][i], truth["ang_yaw"][i], truth["ang_roll"][i]], vel_mode)
        new = set("".join(lines)) & need
        if len(chosen) < n_min or not new <= have:
            chosen.append((int(truth["frame"][i]), lines))
            have |= new
        if have >= need and len(chosen) >= n_min:
            break
    return chosen


def train_templates(video, roi, labels):
    v = extract.Video(video)
    samples = [(mc_ocr.crop(v.frame(f), roi), lines) for f, lines in labels]
    v.close()
    t = mc_ocr.TemplateOCR(LAYOUT)
    rep = t.train(samples)
    path = os.path.join(TMP, os.path.basename(video) + "_tpl.npz")
    t.save(path)
    return mc_ocr.TemplateOCR(LAYOUT, path), rep


ROI = [12, 16, 400, 110]  # covers synth TEXT_ORIGIN (24,40) with 4 lines of 24 px


def smooth_mask(v):
    """Frames where the true velocity is locally linear (no dash step / landing kink)."""
    m = np.zeros(len(v), dtype=bool)
    for i in range(2, len(v) - 2):
        w = v[i - 2:i + 3]
        m[i] = np.all(np.abs(np.diff(w, 2)) < 2.0)
    return m


class TestParsing(unittest.TestCase):
    def test_glued_numbers_and_confusables(self):
        v = mc_ocr.parse_lines(["pos:-783.992758.89204.16", "ang: -2.26 1O3.67 0.00", "vel: 129,93 723.98 -0.5O"], LAYOUT)
        self.assertAlmostEqual(v["pos_x"], -783.99)
        self.assertAlmostEqual(v["pos_y"], 2758.89)
        self.assertAlmostEqual(v["pos_z"], 204.16)
        self.assertAlmostEqual(v["ang_yaw"], 103.67)
        self.assertAlmostEqual(v["vel_x"], 129.93)
        self.assertAlmostEqual(v["vel_z"], -0.50)

    def test_scalar_velocity_alt(self):
        v = mc_ocr.parse_lines(["pos: 1.00 2.00 3.00", "vel: 250.00"], LAYOUT)
        self.assertEqual(v["vel_scalar"], 250.0)
        self.assertNotIn("vel_x", v)

    def test_wrong_count_is_rejected(self):
        v = mc_ocr.parse_lines(["pos: 1.00 2.00", "vel: 1.00 2.00"], LAYOUT)
        self.assertNotIn("pos_x", v)
        self.assertNotIn("vel_x", v)

    def test_full_regex_and_line_index(self):
        lay = json.loads(json.dumps(LAYOUT))
        lay["fields"] = [
            {"key": "p", "full_regex": r"X=(?P<pos_x>-?\d+\.\d+) Y=(?P<pos_y>-?\d+\.\d+) Z=(?P<pos_z>-?\d+\.\d+)", "names": ["pos_x", "pos_y", "pos_z"], "alt_names": []},
            {"key": "v", "line_index": 1, "names": ["vel_scalar"], "alt_names": []},
        ]
        v = mc_ocr.parse_lines(["X=1.50 Y=-2.25 Z=3.00", "300.00"], lay)
        self.assertEqual((v["pos_x"], v["pos_y"], v["pos_z"], v["vel_scalar"]), (1.5, -2.25, 3.0, 300.0))


class TestPost(unittest.TestCase):
    def test_hampel_keeps_step_removes_spike(self):
        x = np.array([0.0] * 10 + [700.0] * 10)
        x[15] = 7000.0
        m = mc_post.hampel(x, np.ones(len(x), bool), 3, 4.0, 3.0)
        self.assertTrue(m[15])
        self.assertEqual(int(m.sum()), 1)

    def test_monotonic_time(self):
        t, fixes = mc_post.monotonic_times([0, 1, 2, 3], 60.0, [0.0, 16.6, 16.6, 10.0])
        self.assertEqual(fixes, 2)
        self.assertTrue(np.all(np.diff(t) > 0))


class TestSyntheticVideos(unittest.TestCase):
    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(TMP, ignore_errors=True)

    def _check_positions(self, out_csv, truth, tag, min_valid=0.95, tol=0.011):
        rows, col = read_out(out_csv)
        self.assertEqual(len(rows), len(truth["frame"]), tag + ": one row per frame")
        valid = col("valid") > 0
        clean = truth["corrupted"] == 0
        frac_valid_clean = valid[clean].mean()
        self.assertGreaterEqual(frac_valid_clean, min_valid, tag + ": valid fraction on clean frames")
        err = np.max(np.abs(np.stack([col("pos_" + a) - truth["pos_" + a] for a in "xyz"])), axis=0)
        bad = valid & (err > tol)
        # a misread that survives cleaning must be rare and small
        self.assertLessEqual(bad.sum(), max(1, int(0.01 * len(rows))), tag + ": wrong accepted positions %s" % np.flatnonzero(bad))
        if bad.any():
            self.assertLess(err[bad].max(), 1.0, tag + ": largest accepted position error")
        return rows, col, valid, err

    def test_template_vector_60fps_with_glitches(self):
        video = os.path.join(TMP, "vec60.mp4")
        truth = synth.read_truth(synth.make_video(video, seconds=3.0, fps=60, vel_mode="vector", glitch=0.05, seed=3))
        labels = label_frames_from_truth(truth, "vector")
        ocr, rep = train_templates(video, ROI, labels)
        self.assertEqual(rep["missing_chars"], [], "templates cover every digit")
        out = os.path.join(TMP, "vec60.csv")
        s = extract.run_extract(video, ROI, ocr.layout, ocr, out, quiet=True)
        rows, col, valid, err = self._check_positions(out, truth, "vec60")
        verr = np.max(np.abs(np.stack([col("vel_" + a) - truth["vel_" + a] for a in "xyz"])), axis=0)
        self.assertLessEqual((valid & (verr > 0.011)).sum(), max(1, int(0.01 * len(rows))), "velocity readout accuracy")
        sh = np.hypot(truth["vel_x"], truth["vel_y"])
        self.assertLess(np.nanmax(np.abs(col("speed_h") - sh)[valid & (verr <= 0.011)]), 0.02, "speed_h from vector readout")
        self.assertEqual(s["velocity_source"], "readout-vector")
        cor = truth["corrupted"] > 0
        self.assertGreater(cor.sum(), 0)
        # a glitched frame is either rejected or read (nearly) right, never accepted with a big error
        self.assertTrue(np.all(~valid[cor] | (np.maximum(err, verr)[cor] < 1.0)), "glitched frames rejected or correct")
        print("\n[vec60] %s" % json.dumps({k: s[k] for k in ("frames", "parsed", "valid_rows", "duplicates", "outlier_values_rejected", "seconds")}))

    def test_template_scalar_120fps_duplicates_and_stutter(self):
        video = os.path.join(TMP, "sc120.mp4")
        truth = synth.read_truth(synth.make_video(video, seconds=2.5, fps=120, render_fps=60, vel_mode="scalar", glitch=0.02, stutter=0.02, seed=5))
        labels = label_frames_from_truth(truth, "scalar")
        ocr, rep = train_templates(video, ROI, labels)
        out = os.path.join(TMP, "sc120.csv")
        s = extract.run_extract(video, ROI, ocr.layout, ocr, out, quiet=True)
        rows, col, valid, err = self._check_positions(out, truth, "sc120", min_valid=0.40)  # ~half the frames are duplicates
        self.assertGreater(s["duplicates"], 0.4 * len(rows), "duplicate frames detected")
        self.assertEqual(s["velocity_source"], "derived-from-position")
        vs = col("vel_scalar")
        ok = np.isfinite(vs)
        self.assertLess(np.max(np.abs(vs[ok] - truth["vel_scalar"][ok])), 0.011 + 1e-9, "scalar vel readout")
        # derived horizontal speed vs truth where the true motion is smooth
        true_h = np.hypot(truth["vel_x"], truth["vel_y"])
        sm = smooth_mask(true_h) & smooth_mask(truth["vel_z"]) & valid
        dh = np.abs(col("speed_h") - true_h)[sm]
        self.assertGreater(sm.sum(), 50)
        self.assertLess(np.median(dh), 1.5, "derived speed_h median error u/s")
        self.assertLess(np.percentile(dh, 90), 4.0, "derived speed_h p90 error u/s")
        # time strictly increasing
        self.assertTrue(np.all(np.diff(col("t")) > 0))
        print("\n[sc120] %s median|dv|=%.3f p90=%.3f" % (json.dumps({k: s[k] for k in ("frames", "parsed", "valid_rows", "duplicates", "outlier_values_rejected")}), np.median(dh), np.percentile(dh, 90)))

    @unittest.skipIf(os.environ.get("MC_SKIP_RAPIDOCR") == "1", "MC_SKIP_RAPIDOCR=1")
    def test_rapidocr_auto_calibrate_and_extract(self):
        video = os.path.join(TMP, "rapid.mp4")
        truth = synth.read_truth(synth.make_video(video, seconds=1.5, fps=60, vel_mode="vector", glitch=0.04, seed=7))
        roi_json = os.path.join(TMP, "roi.json")
        rc = extract.main(["calibrate", video, "--out", roi_json, "--frames", "10,40,80"])
        self.assertEqual(rc, 0)
        roi = extract.parse_roi(roi_json)
        x, y, w, h = roi
        # must contain the pos/ang/vel lines: x from 24, baselines 64..112 (text height ~14)
        self.assertLessEqual(x, 26)
        self.assertLessEqual(y, 64 - 14)
        self.assertGreaterEqual(x + w, 300)
        self.assertGreaterEqual(y + h, 40 + 3 * 24 + 3)
        out = os.path.join(TMP, "rapid.csv")
        backend = mc_ocr.RapidOCRBackend(LAYOUT)
        s = extract.run_extract(video, roi, LAYOUT, backend, out, quiet=True)
        self._check_positions(out, truth, "rapidocr", min_valid=0.93)
        print("\n[rapidocr] %s" % json.dumps({k: s[k] for k in ("frames", "parsed", "valid_rows", "outlier_values_rejected", "seconds")}))


if __name__ == "__main__":
    unittest.main(verbosity=2)
