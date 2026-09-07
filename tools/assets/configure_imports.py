#!/usr/bin/env python3
"""Patch Godot .import sidecars for material map channel roles."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2] / "assets" / "materials"

ALBEDO = {
    "process/hdr_as_srgb": "true",
    "mipmaps/generate": "true",
    "compress/normal_map": "0",
}
DATA = {
    "process/hdr_as_srgb": "false",
    "mipmaps/generate": "true",
    "compress/normal_map": "0",
}
NORMAL = {
    "process/hdr_as_srgb": "false",
    "mipmaps/generate": "true",
    "compress/normal_map": "1",
    "process/normal_map_invert_y": "false",
}


def _patch(path: Path, params: dict[str, str]) -> None:
    if not path.exists():
        return
    lines = path.read_text(encoding="utf-8").splitlines()
    out: list[str] = []
    in_params = False
    seen = set()
    for line in lines:
        if line.strip() == "[params]":
            in_params = True
            out.append(line)
            continue
        if in_params and line.startswith("["):
            for key, value in params.items():
                if key not in seen:
                    out.append(f"{key}={value}")
            in_params = False
        if in_params and "=" in line:
            key = line.split("=", 1)[0]
            if key in params:
                out.append(f"{key}={params[key]}")
                seen.add(key)
                continue
        out.append(line)
    if in_params:
        for key, value in params.items():
            if key not in seen:
                out.append(f"{key}={value}")
    path.write_text("\n".join(out) + "\n", encoding="utf-8")


def main() -> None:
    for sidecar in ROOT.rglob("*.png.import"):
        name = sidecar.name
        if name.startswith("albedo"):
            _patch(sidecar, ALBEDO)
        elif name.startswith("normal"):
            _patch(sidecar, NORMAL)
        else:
            _patch(sidecar, DATA)
    print(f"Configured imports under {ROOT}")


if __name__ == "__main__":
    main()
