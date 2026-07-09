#!/usr/bin/env python3
"""Cut springboard/launch-transition dead time out of the demo tour video.

The CI tour terminates and relaunches the app between segments, which
records seconds of home screen and black launch frames. App content in
dark mode sits in a narrow brightness band; the springboard wallpaper is
far brighter and launch transitions are near-black, so a mean-brightness
gate separates them cleanly.

Usage: trim-demo.py <video.mp4>   (rewrites the file in place)
Exits 0 without touching the file when the cut looks unsafe.
"""

import sys
import tempfile
from fractions import Fraction
from pathlib import Path

import av

KEEP_MIN, KEEP_MAX = 8, 60   # mean-brightness band for app content
PAD = 2                      # widen each cut to hide fade edges
FPS = 15


def classify(path):
    keep = []
    with av.open(str(path)) as container:
        for frame in container.decode(video=0):
            img = frame.to_ndarray(format="rgb24")[::8, ::8]
            m = float(img.mean())
            keep.append(KEEP_MIN <= m <= KEEP_MAX)
    bad = [not k for k in keep]
    widened = bad[:]
    for i, b in enumerate(bad):
        if b:
            for j in range(max(0, i - PAD), min(len(bad), i + PAD + 1)):
                widened[j] = True
    return [not w for w in widened]


def main():
    src = Path(sys.argv[1])
    keep = classify(src)
    kept = sum(keep)
    # Refuse implausible cuts: a broken threshold must not eat the video.
    if kept < len(keep) * 0.4 or kept < FPS * 10:
        print(f"trim-demo: keeping raw video ({kept}/{len(keep)} frames would remain)")
        return

    tmp = Path(tempfile.mkstemp(suffix=".mp4", dir=src.parent)[1])
    with av.open(str(src)) as inp, av.open(str(tmp), "w") as out:
        vs = inp.streams.video[0]
        ostream = out.add_stream("h264", rate=Fraction(FPS, 1))
        ostream.width, ostream.height = vs.width, vs.height
        ostream.pix_fmt = "yuv420p"
        ostream.options = {"crf": "23", "preset": "medium"}
        ostream.codec_context.time_base = Fraction(1, FPS)
        count = 0
        for i, frame in enumerate(inp.decode(video=0)):
            if not keep[i]:
                continue
            new = frame.reformat(format="yuv420p")
            new.pts = count
            new.time_base = Fraction(1, FPS)
            count += 1
            out.mux(ostream.encode(new))
        out.mux(ostream.encode(None))
    tmp.replace(src)
    print(f"trim-demo: {len(keep)} -> {kept} frames ({kept / FPS:.0f}s)")


if __name__ == "__main__":
    main()
