#!/usr/bin/env python3
"""Deterministic builder for the OP12 FOD Color Fix flashable ZIP.

Reads the version from module/module.prop and produces
dist/OP12-FOD-Color-Fix-<version>.zip plus a .sha256 file next to it.
The archive uses a fixed timestamp and fixed permissions so the same
source tree always yields the same bytes.
"""

from pathlib import Path
import hashlib
import zipfile

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "module"
DIST = ROOT / "dist"

FILES = [
    "module.prop",
    "customize.sh",
    "service.sh",
    "skip_mount",
    "README.md",
    "CHANGELOG.md",
    "LICENSE",
]

FIXED_TIME = (2026, 7, 15, 12, 0, 0)


def read_prop(key: str) -> str:
    for line in (MODULE / "module.prop").read_text(encoding="utf-8").splitlines():
        if line.startswith(key + "="):
            return line.split("=", 1)[1].strip()
    raise KeyError(f"{key} not found in module.prop")


def main() -> None:
    version = read_prop("version")
    out = DIST / f"OP12-FOD-Color-Fix-{version}.zip"
    sha = out.with_suffix(out.suffix + ".sha256")

    DIST.mkdir(parents=True, exist_ok=True)
    if out.exists():
        out.unlink()

    # Stored (uncompressed) on purpose: the DEFLATE byte stream depends on the
    # host zlib version, so compression would make the ZIP differ between
    # machines. Storing files verbatim keeps the build byte-for-byte
    # reproducible anywhere. The module is a few KB, so size is irrelevant.
    with zipfile.ZipFile(out, "w", compression=zipfile.ZIP_STORED) as zf:
        for rel in FILES:
            data = (MODULE / rel).read_bytes()
            info = zipfile.ZipInfo(rel, date_time=FIXED_TIME)
            info.create_system = 3
            mode = 0o755 if rel.endswith(".sh") else 0o644
            info.external_attr = (mode & 0xFFFF) << 16
            info.compress_type = zipfile.ZIP_STORED
            zf.writestr(info, data)

    digest = hashlib.sha256(out.read_bytes()).hexdigest()
    sha.write_text(f"{digest}  {out.name}\n", encoding="utf-8")
    print(out)
    print(digest)


if __name__ == "__main__":
    main()
