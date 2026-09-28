"""Low-level game I/O for the capture driver (Windows only).

Everything here goes through ordinary OS input and screen capture: synthetic key presses
(keybd_event, scan codes), relative mouse motion (mouse_event, which the game reads; SendInput
did not register in the 2026-09-27 test), and Desktop Duplication capture of the cl_showpos
readout. Nothing reads game memory, files or network traffic.

Every sender checks that the game window is in front first and raises NotForeground otherwise,
so keys never land in another program. F10 aborts a running trial (checked between events).
"""
from __future__ import annotations

import ctypes
import os
import sys
import threading
import time
from ctypes import wintypes

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import mc_ocr  # noqa: E402

u32 = ctypes.windll.user32
k32 = ctypes.windll.kernel32
try:
    ctypes.windll.shcore.SetProcessDpiAwareness(2)  # physical pixels, so the ROI matches the screen
except Exception:
    pass
ctypes.windll.winmm.timeBeginPeriod(1)

KEYEVENTF_KEYUP = 0x0002
MOUSEEVENTF_MOVE = 0x0001
VK = {
    "w": 0x57, "a": 0x41, "s": 0x53, "d": 0x44, "space": 0x20, "lshift": 0xA0, "shift": 0x10, "lctrl": 0xA2,
    "ctrl": 0x11, "c": 0x43, "e": 0x45, "q": 0x51, "r": 0x52, "f": 0x46, "enter": 0x0D, "return": 0x0D,
    "f1": 0x70, "f2": 0x71, "f3": 0x72, "f4": 0x73, "f5": 0x74, "f6": 0x75, "f7": 0x76, "f8": 0x77,
    "f9": 0x78, "f10": 0x79, "f11": 0x7A, "f12": 0x7B, "backspace": 0x08, "escape": 0x1B,
}


class NotForeground(RuntimeError):
    pass


class Aborted(RuntimeError):
    pass


# ----------------------------------------------------------------------------------------------
# foreground guard
# ----------------------------------------------------------------------------------------------

def foreground_exe() -> str:
    hwnd = u32.GetForegroundWindow()
    pid = wintypes.DWORD()
    u32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
    h = k32.OpenProcess(0x1000, False, pid.value)  # PROCESS_QUERY_LIMITED_INFORMATION
    if not h:
        return ""
    try:
        buf = ctypes.create_unicode_buffer(1024)
        n = wintypes.DWORD(1024)
        k32.QueryFullProcessImageNameW(h, 0, buf, ctypes.byref(n))
        return os.path.basename(buf.value).lower()
    finally:
        k32.CloseHandle(h)


def require_game(exe: str = "deadlock.exe") -> None:
    fg = foreground_exe()
    if fg != exe:
        raise NotForeground("the game is not in front (foreground: %r). Click into the game and retry." % fg)


def game_window(exe: str = "deadlock.exe"):
    """The game's main window: the largest visible titled top-level window of `exe` (None if not running)."""
    found = []
    WNDENUMPROC = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)

    def cb(hwnd, _):
        if u32.IsWindowVisible(hwnd) and u32.GetWindowTextLengthW(hwnd) > 0:
            pid = wintypes.DWORD()
            u32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
            h = k32.OpenProcess(0x1000, False, pid.value)
            if h:
                buf = ctypes.create_unicode_buffer(1024)
                n = wintypes.DWORD(1024)
                k32.QueryFullProcessImageNameW(h, 0, buf, ctypes.byref(n))
                k32.CloseHandle(h)
                if os.path.basename(buf.value).lower() == exe:
                    r = wintypes.RECT()
                    u32.GetWindowRect(hwnd, ctypes.byref(r))
                    found.append(((r.right - r.left) * (r.bottom - r.top), hwnd))
        return True

    u32.EnumWindows(WNDENUMPROC(cb), 0)
    return max(found)[1] if found else None


def focus_game(exe: str = "deadlock.exe", verbose: bool = False) -> bool:
    """Brings the game's main window to the front (only when asked; runs never refocus on their own).
    Tries escalating methods, because a fullscreen 'Windows Input Experience' (textinputhost) window can sit in
    front and a plain SetForegroundWindow is then refused."""
    hwnd = game_window(exe)
    if hwnd is None:
        return False

    def ok(name):
        time.sleep(0.3)
        good = foreground_exe() == exe
        if verbose:
            print("focus_game: %s -> %s (foreground %s)" % (name, good, foreground_exe()))
        return good

    if foreground_exe() == exe:
        return True
    # 1. Windows only lets the process that received the last input change the foreground: a bare Alt tap counts
    u32.keybd_event(0x12, 0, 0, 0)
    u32.keybd_event(0x12, 0, KEYEVENTF_KEYUP, 0)
    u32.SetForegroundWindow(hwnd)
    if ok("alt + SetForegroundWindow"):
        return True
    # 2. share input state with the current foreground thread, then raise and activate
    fg_tid = u32.GetWindowThreadProcessId(u32.GetForegroundWindow(), None)
    me = k32.GetCurrentThreadId()
    attached = bool(fg_tid) and fg_tid != me and u32.AttachThreadInput(me, fg_tid, True)
    try:
        u32.BringWindowToTop(hwnd)
        u32.ShowWindow(hwnd, 5)  # SW_SHOW
        u32.SetForegroundWindow(hwnd)
        u32.SetActiveWindow(hwnd)
        u32.SetFocus(hwnd)
    finally:
        if attached:
            u32.AttachThreadInput(me, fg_tid, False)
    if ok("AttachThreadInput"):
        return True
    # 3. a click activates the window under it without any foreground-lock checks. The input host that steals the
    # foreground is cloaked (invisible), so the game is what is hit at its centre; only click when that is true.
    # In game this is one primary-fire click (sandbox only).
    r = wintypes.RECT()
    u32.GetWindowRect(hwnd, ctypes.byref(r))
    pt = wintypes.POINT((r.left + r.right) // 2, (r.top + r.bottom) // 2)
    if u32.GetAncestor(u32.WindowFromPoint(pt), 2) != hwnd:  # GA_ROOT
        if verbose:
            print("focus_game: something else is at the game's centre, not clicking")
        return False
    u32.SetCursorPos(pt.x, pt.y)
    u32.mouse_event(0x0002, 0, 0, 0, 0)  # MOUSEEVENTF_LEFTDOWN
    time.sleep(0.03)
    u32.mouse_event(0x0004, 0, 0, 0, 0)  # MOUSEEVENTF_LEFTUP
    return ok("click at the game's centre")


def check_abort() -> None:
    if u32.GetAsyncKeyState(VK["f10"]) & 0x8000:
        raise Aborted("F10 pressed")


# ----------------------------------------------------------------------------------------------
# keyboard / mouse
# ----------------------------------------------------------------------------------------------

def vk_of(name: str) -> int:
    n = name.lower()
    if n in VK:
        return VK[n]
    if len(n) == 1:
        return u32.VkKeyScanW(ord(n)) & 0xFF
    raise KeyError("unknown key %r" % name)


def key_down(name: str) -> None:
    vk = vk_of(name)
    u32.keybd_event(vk, u32.MapVirtualKeyW(vk, 0), 0, 0)


def key_up(name: str) -> None:
    vk = vk_of(name)
    u32.keybd_event(vk, u32.MapVirtualKeyW(vk, 0), KEYEVENTF_KEYUP, 0)


def tap(name: str, hold: float = 0.03) -> None:
    key_down(name)
    time.sleep(hold)
    key_up(name)


def mouse_dx(counts: int, chunk: int = 20) -> None:
    """Relative horizontal mouse motion. Chunks of <= 20 counts, the size the calibration used
    (1000 and 1200 counts gave the same deg/count), in case large single events are treated differently."""
    s = 1 if counts > 0 else -1
    left = abs(int(counts))
    while left > 0:
        c = min(chunk, left)
        u32.mouse_event(MOUSEEVENTF_MOVE, s * c, 0, 0, 0)
        left -= c


def type_text(text: str) -> None:
    for ch in text:
        r = u32.VkKeyScanW(ord(ch))
        vk, shift = r & 0xFF, (r >> 8) & 1
        if shift:
            u32.keybd_event(0x10, u32.MapVirtualKeyW(0x10, 0), 0, 0)
        u32.keybd_event(vk, u32.MapVirtualKeyW(vk, 0), 0, 0)
        u32.keybd_event(vk, u32.MapVirtualKeyW(vk, 0), KEYEVENTF_KEYUP, 0)
        if shift:
            u32.keybd_event(0x10, u32.MapVirtualKeyW(0x10, 0), KEYEVENTF_KEYUP, 0)
        time.sleep(0.004)


def console(cmds: list[str], console_key: str = "f7", exe: str = "deadlock.exe") -> None:
    """Opens the console, types each command + Enter, closes it. Assumes it starts closed."""
    require_game(exe)
    tap(console_key)
    time.sleep(0.35)
    for c in cmds:
        type_text(c)
        tap("enter")
        time.sleep(0.12)
    tap(console_key)
    time.sleep(0.25)


def precise_sleep_until(t_target: float) -> None:
    while True:
        d = t_target - time.perf_counter()
        if d <= 0:
            return
        if d > 0.004:
            time.sleep(d - 0.003)


# ----------------------------------------------------------------------------------------------
# HUD capture + reading
# ----------------------------------------------------------------------------------------------

class Capture:
    """Desktop Duplication capture of the readout ROI (x, y, w, h in physical pixels).
    start()/stop() records every new frame with its perf_counter stamp; grab() returns one fresh frame."""

    def __init__(self, roi):
        import dxcam
        x, y, w, h = [int(v) for v in roi]
        self.region = (x, y, x + w, y + h)
        self.cam = dxcam.create(output_color="GRAY")
        self.frames: list[np.ndarray] = []
        self.stamps: list[float] = []
        self._run = False
        self._th = None

    def grab(self) -> np.ndarray:
        for _ in range(50):
            f = self.cam.grab(region=self.region)
            if f is not None:
                return f[:, :, 0] if f.ndim == 3 else f
            time.sleep(0.01)
        raise RuntimeError("no frame from the capture")

    def _loop(self):
        self.cam.start(region=self.region, target_fps=240, video_mode=False)
        try:
            while self._run:
                f = self.cam.get_latest_frame()
                t = time.perf_counter()
                if f is not None:
                    self.frames.append((f[:, :, 0] if f.ndim == 3 else f).copy())
                    self.stamps.append(t)
        finally:
            self.cam.stop()

    def start(self):
        self.frames, self.stamps = [], []
        self._run = True
        self._th = threading.Thread(target=self._loop, daemon=True)
        self._th.start()

    def stop(self):
        self._run = False
        if self._th:
            self._th.join(timeout=3)


class HudReader:
    """Grid-template reader (mc_grid, exact, ~17 ms) when templates exist, else the general OCR."""

    def __init__(self, layout_path: str, grid_templates: str | None = None):
        self.layout = mc_ocr.load_layout(layout_path)
        if grid_templates and os.path.exists(grid_templates):
            import mc_grid
            self.grid = mc_grid.GridReader(grid_templates)
            self.backend = None
        else:
            self.grid = None
            self.backend = mc_ocr.make_backend("rapidocr", self.layout)

    def read(self, gray: np.ndarray) -> dict:
        if self.grid is not None:
            return self.grid.read(gray)
        import cv2
        lines, _ = self.backend.read(cv2.cvtColor(gray, cv2.COLOR_GRAY2BGR))
        return mc_ocr.parse_lines(lines, self.layout)

    def text(self, gray: np.ndarray) -> str:
        if self.grid is not None:
            return " | ".join("%s: %s" % (k, self.grid.read_line(gray, k)) for k in ("pos", "ang", "vel"))
        import cv2
        return " | ".join(self.backend.read(cv2.cvtColor(gray, cv2.COLOR_GRAY2BGR))[0])


def mouse_dy(counts: int, chunk: int = 20) -> None:
    """Relative vertical mouse motion; + counts looks down (pitch increases)."""
    s = 1 if counts > 0 else -1
    left = abs(int(counts))
    while left > 0:
        c = min(chunk, left)
        u32.mouse_event(MOUSEEVENTF_MOVE, 0, s * c, 0, 0)
        left -= c
