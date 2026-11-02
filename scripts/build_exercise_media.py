#!/usr/bin/env python3
"""Bundle exercise demonstrations so the app never waits on the network.

Downloads each catalog GIF once (cached in build/exercise_gifs/), converts it
to a 360 px animated WebP and writes assets/exercises/media/<muscle>__<slug>.webp.
Run from the repository root after scripts/import_gym_gifs.mjs:

    python3 -m pip install pillow
    python3 scripts/build_exercise_media.py

Re-running skips finished files. Media rights: see
docs/EXERCISE_LIBRARY_MIGRATION.md.
"""

import io
import json
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from PIL import Image

CATALOG = Path("assets/exercises/catalog_v1.json")
CACHE = Path("build/exercise_gifs")
OUTPUT = Path("assets/exercises/media")
SIDE, QUALITY = 360, 55


def media_name(external_id: str) -> str:
    # Must match ExerciseMedia.assetFor in lib/widgets/exercise_media.dart.
    return external_id.replace("/", "__") + ".webp"


def fetch(url: str, cached: Path) -> bytes:
    if cached.exists():
        return cached.read_bytes()
    with urllib.request.urlopen(url, timeout=60) as response:
        data = response.read()
    cached.write_bytes(data)
    return data


def convert(data: bytes) -> bytes:
    source = Image.open(io.BytesIO(data))
    frames, durations = [], []
    for index in range(getattr(source, "n_frames", 1)):
        source.seek(index)
        frame = source.convert("RGBA")
        frame.thumbnail((SIDE, SIDE))
        frames.append(frame)
        durations.append(source.info.get("duration", 100))
    out = io.BytesIO()
    frames[0].save(out, "WEBP", save_all=True, append_images=frames[1:],
                   duration=durations, loop=0, quality=QUALITY, method=4)
    return out.getvalue()


def build(exercise: dict) -> tuple[str, int]:
    target = OUTPUT / media_name(exercise["externalId"])
    if not target.exists():
        cached = CACHE / media_name(exercise["externalId"]).replace(".webp", ".gif")
        target.write_bytes(convert(fetch(exercise["gifUrl"], cached)))
    return exercise["externalId"], target.stat().st_size


def main() -> int:
    exercises = json.loads(CATALOG.read_text())["exercises"]
    CACHE.mkdir(parents=True, exist_ok=True)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    failures, total = [], 0
    with ThreadPoolExecutor(max_workers=12) as pool:
        futures = {pool.submit(build, e): e["externalId"] for e in exercises}
        for done, future in enumerate(futures, 1):
            try:
                total += future.result()[1]
            except Exception as error:  # Report every failure, then exit 1.
                failures.append(f"{futures[future]}: {error}")
            if done % 100 == 0:
                print(f"{done}/{len(exercises)}", flush=True)
    print(f"{len(exercises) - len(failures)} files, {total / 1e6:.1f} MB "
          f"in {OUTPUT}")
    for failure in failures:
        print("FAILED", failure, file=sys.stderr)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
