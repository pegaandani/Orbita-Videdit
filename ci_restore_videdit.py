from __future__ import annotations

import base64
import hashlib
import shutil
import tarfile
from pathlib import Path

PARTS = Path("videdit_ci_parts")
ARCHIVE = Path("videdit_build_min.tar.xz")
OUT = Path("videdit_project")
EXPECTED_SHA256 = "80215bf9e018c2980fbc0dba7d210ba348025162ad05b96ef95c761d2da64c86"


def text(name: str) -> str:
    return (PARTS / name).read_text(encoding="utf-8").strip()


def hex_text(name: str) -> str:
    raw = bytes.fromhex(text(name))
    return raw.decode("ascii")


chunks: list[str] = []

# c00-c19 are complete chunks.
for i in range(20):
    chunks.append(text(f"c{i:02d}.b64"))

# c20-c23 were split during transport.
chunks.append(text("c20a.b64") + text("c20b1.b64") + text("c20b2.b64"))
for i in range(21, 24):
    chunks.append(text(f"c{i}a.b64") + text(f"c{i}b.b64"))

# c24 has two raw text pieces and four pieces transported as hexadecimal text.
c24 = text("c24a.b64")
c24 += text("c24b_00.b64") + text("c24b_01.b64")
c24 += hex_text("c24b_02_00.hex") + hex_text("c24b_02_01.hex")
c24 += hex_text("c24b_03_00.hex") + hex_text("c24b_03_01.hex")
chunks.append(c24)

# c25-c28 were split in halves.
for i in range(25, 29):
    chunks.append(text(f"c{i}a.b64") + text(f"c{i}b.b64"))

# c29-c32 were split into four transport pieces each.
for i in range(29, 33):
    chunks.append(
        text(f"c{i}a_0.b64")
        + text(f"c{i}a_1.b64")
        + text(f"c{i}b_0.b64")
        + text(f"c{i}b_1.b64")
    )

if len(chunks) != 33:
    raise SystemExit(f"Expected 33 chunks, got {len(chunks)}")

encoded = "".join(chunks)
try:
    payload = base64.b64decode(encoded, validate=True)
except Exception as exc:
    raise SystemExit(f"Base64 reconstruction failed: {exc}") from exc

actual_sha256 = hashlib.sha256(payload).hexdigest()
print(f"Reconstructed archive SHA256: {actual_sha256}")
if actual_sha256 != EXPECTED_SHA256:
    raise SystemExit(
        f"SHA256 mismatch: expected {EXPECTED_SHA256}, got {actual_sha256}"
    )

ARCHIVE.write_bytes(payload)

if OUT.exists():
    shutil.rmtree(OUT)
OUT.mkdir(parents=True)

with tarfile.open(ARCHIVE, mode="r:xz") as tf:
    root = OUT.resolve()
    for member in tf.getmembers():
        target = (OUT / member.name).resolve()
        if root != target and root not in target.parents:
            raise SystemExit(f"Unsafe archive path: {member.name}")
    tf.extractall(OUT)

required = [
    OUT / "pubspec.yaml",
    OUT / "lib",
    OUT / "android",
    OUT / "windows",
    OUT / "assets" / "orbita_app_icon_1024.png",
]
missing = [str(p) for p in required if not p.exists()]
if missing:
    raise SystemExit(f"Missing reconstructed project paths: {missing}")

print("Orbita Videdit v0.5.0 project restored and verified.")
