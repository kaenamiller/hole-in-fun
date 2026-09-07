#!/usr/bin/env python3
"""Deterministic procedural material map generator for package 04.

Generates seamless albedo, roughness, height and derived normal maps for
resort material families. Writes a manifest with seed, resolution, scale and
generator version. Runs edge seam checks and rejects maps with baked lighting.
"""

from __future__ import annotations

import hashlib
import json
import math
import struct
import sys
import zlib
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Dict, List, Tuple

import numpy as np

GENERATOR_VERSION = "1.0.0"
GLOBAL_SEED = 0x04_2026
OUTPUT_ROOT = Path(__file__).resolve().parents[2] / "assets" / "materials"
TRIM_SIZE = 1024
TRIM_ROWS = ("plaster", "timber", "roof")


def _hex_to_rgb(hex_color: str) -> Tuple[float, float, float]:
    h = hex_color.lstrip("#")
    return tuple(int(h[i : i + 2], 16) / 255.0 for i in (0, 2, 4))


@dataclass(frozen=True)
class FamilyDef:
    family_id: str
    palette_hex: str
    meters_per_repeat: float
    base_roughness: float
    resolution: int
    macro_amp: float
    fine_amp: float
    height_strength: float
    grain_axis: str = "both"  # both | x | radial


FAMILIES: Dict[str, FamilyDef] = {
    "fairway": FamilyDef("course.fairway", "#8cab4e", 2.0, 0.88, 512, 0.08, 0.025, 0.035),
    "rough": FamilyDef("course.rough", "#637f3d", 1.5, 0.92, 512, 0.10, 0.030, 0.040),
    "sand": FamilyDef("course.sand", "#dfcb9e", 0.8, 0.94, 512, 0.06, 0.040, 0.050),
    "gravel": FamilyDef("course.gravel", "#b18b60", 0.5, 0.90, 512, 0.07, 0.055, 0.070),
    "stone": FamilyDef("prop.stone", "#777b70", 1.2, 0.85, 512, 0.09, 0.035, 0.080),
    "plaster": FamilyDef("arch.plaster", "#e2d3ad", 1.8, 0.86, TRIM_SIZE // 3, 0.04, 0.018, 0.022),
    "bark": FamilyDef("prop.bark", "#4e3326", 0.6, 0.91, 512, 0.11, 0.030, 0.055, "x"),
    "timber": FamilyDef("arch.timber", "#8b5a3c", 1.4, 0.84, TRIM_SIZE // 3, 0.07, 0.022, 0.045, "x"),
    "roof": FamilyDef("arch.roof", "#75604a", 0.9, 0.89, TRIM_SIZE // 3, 0.05, 0.028, 0.035),
}


def _rng(seed: int) -> np.random.Generator:
    return np.random.default_rng(seed)


def _tileable_noise(rng: np.random.Generator, size: int, band_limit: int) -> np.ndarray:
    """Spectral synthesis on an integer torus — exact edge continuity."""
    y, x = np.mgrid[0:size, 0:size].astype(np.float64)
    out = np.zeros((size, size), dtype=np.float64)
    for ky in range(1, band_limit + 1):
        for kx in range(1, band_limit + 1):
            if kx + ky > band_limit + 2:
                continue
            phase = rng.random() * math.tau
            amp = 1.0 / float(kx + ky)
            angle = math.tau * (kx * x / size + ky * y / size) + phase
            out += amp * np.cos(angle)
    out -= out.mean()
    max_abs = float(np.max(np.abs(out)))
    if max_abs > 1e-8:
        out /= max_abs
    return out


def _family_noise(rng: np.random.Generator, size: int, macro: float, fine: float, axis: str) -> Tuple[np.ndarray, np.ndarray]:
    macro_n = _tileable_noise(rng, size, max(3, size // 128)) * macro
    fine_n = _tileable_noise(rng, size, max(8, size // 48)) * fine
    if axis == "x":
        _, x = np.mgrid[0:size, 0:size]
        streak = np.sin(x / size * math.tau * 6.0) * macro * 0.35
        macro_n += streak
    height = macro_n * 0.65 + fine_n * 0.35
    return macro_n + fine_n, height


def _height_to_normal(height: np.ndarray, strength: float) -> np.ndarray:
    h = height.astype(np.float64)
    dx = np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)
    dy = np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)
    nx = -dx * strength
    ny = -dy * strength
    nz = np.ones_like(nx)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    normal = np.stack([nx / length, ny / length, nz / length], axis=-1)
    normal = (normal * 0.5 + 0.5).clip(0.0, 1.0)
    return (normal * 255.0).astype(np.uint8)


def _albedo_from_noise(base_rgb: Tuple[float, float, float], noise: np.ndarray) -> np.ndarray:
    rgb = np.zeros((*noise.shape, 3), dtype=np.float64)
    for i, channel in enumerate(base_rgb):
        rgb[..., i] = np.clip(channel + noise, 0.0, 1.0)
    return (rgb * 255.0).astype(np.uint8)


def _roughness_map(base: float, height: np.ndarray, rng: np.random.Generator, size: int) -> np.ndarray:
    micro = _tileable_noise(rng, size, max(10, size // 40)) * 0.04
    variation = np.abs(height) * 0.18 + micro
    rough = np.clip(base + variation - 0.08, 0.05, 0.99)
    return (rough * 255.0).astype(np.uint8)


def _seam_score(image: np.ndarray) -> float:
    left = image[:, 0].astype(np.float64)
    right = image[:, -1].astype(np.float64)
    top = image[0, :].astype(np.float64)
    bottom = image[-1, :].astype(np.float64)
    lr = float(np.mean(np.abs(left - right)))
    tb = float(np.mean(np.abs(top - bottom)))
    return max(lr, tb)


def _lighting_baked_score(albedo: np.ndarray) -> float:
    rgb = albedo.astype(np.float64) / 255.0
    luma = 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]
    gy, gx = np.gradient(luma)
    grad = np.sqrt(gx * gx + gy * gy)
    return float(np.mean(grad))


def _write_png(path: Path, array: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if array.ndim == 2:
        h, w = array.shape
        mode = 0  # grayscale
        raw = b"".join(b"\x00" + array[y].astype(np.uint8).tobytes() for y in range(h))
    else:
        h, w, c = array.shape
        if c == 3:
            mode = 2
            rows = []
            for y in range(h):
                row = array[y].astype(np.uint8)
                rows.append(b"\x00" + row.tobytes())
            raw = b"".join(rows)
        else:
            raise ValueError(f"unsupported channel count {c}")

    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", w, h, 8, mode, 0, 0, 0)
    compressed = zlib.compress(raw, 9)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", compressed) + chunk(b"IEND", b"")
    path.write_bytes(png)


def _family_seed(name: str) -> int:
    digest = hashlib.sha256(f"{GLOBAL_SEED}:{name}".encode()).digest()
    return int.from_bytes(digest[:8], "little")


def generate_family(name: str, definition: FamilyDef) -> Dict:
    rng = _rng(_family_seed(name))
    size = definition.resolution
    noise, height = _family_noise(rng, size, definition.macro_amp, definition.fine_amp, definition.grain_axis)
    base = _hex_to_rgb(definition.palette_hex)
    albedo = _albedo_from_noise(base, noise)
    roughness = _roughness_map(definition.base_roughness, height, rng, size)
    normal = _height_to_normal(height, definition.height_strength * 4.0)
    height_u8 = ((height * 0.5 + 0.5).clip(0.0, 1.0) * 255.0).astype(np.uint8)

    seam = max(_seam_score(albedo), _seam_score(roughness), _seam_score(normal[..., 0]))
    lighting = _lighting_baked_score(albedo)
    if seam > 1.5:
        raise RuntimeError(f"{name}: seam score {seam:.2f} exceeds threshold")
    if lighting > 0.28:
        raise RuntimeError(f"{name}: albedo gradient {lighting:.3f} suggests baked lighting")

    out_dir = OUTPUT_ROOT / name
    _write_png(out_dir / "albedo.png", albedo)
    _write_png(out_dir / "roughness.png", roughness)
    _write_png(out_dir / "normal.png", normal)
    _write_png(out_dir / "height.png", height_u8)

    return {
        "id": definition.family_id,
        "folder": name,
        "resolution": size,
        "meters_per_repeat": definition.meters_per_repeat,
        "base_roughness": definition.base_roughness,
        "palette_hex": definition.palette_hex,
        "seam_score": round(seam, 4),
        "albedo_gradient": round(lighting, 4),
        "seed": _family_seed(name),
    }


def generate_trim_sheet() -> Dict:
    row_h = TRIM_SIZE // len(TRIM_ROWS)
    albedo = np.zeros((TRIM_SIZE, TRIM_SIZE, 3), dtype=np.uint8)
    roughness = np.zeros((TRIM_SIZE, TRIM_SIZE), dtype=np.uint8)
    normal = np.zeros((TRIM_SIZE, TRIM_SIZE, 3), dtype=np.uint8)
    height = np.zeros((TRIM_SIZE, TRIM_SIZE), dtype=np.uint8)
    regions: Dict[str, Dict] = {}

    for row, family_name in enumerate(TRIM_ROWS):
        definition = FAMILIES[family_name]
        y0 = row * row_h
        rng = _rng(_family_seed(family_name))
        noise, h = _family_noise(rng, row_h, definition.macro_amp, definition.fine_amp, definition.grain_axis)
        alb = _albedo_from_noise(_hex_to_rgb(definition.palette_hex), noise)
        rough = _roughness_map(definition.base_roughness, h, rng, row_h)
        norm = _height_to_normal(h, definition.height_strength * 4.0)
        ht = ((h * 0.5 + 0.5).clip(0.0, 1.0) * 255.0).astype(np.uint8)
        albedo[y0 : y0 + row_h, :] = np.tile(alb, (1, TRIM_SIZE // row_h + 1, 1))[:, :TRIM_SIZE, :]
        roughness[y0 : y0 + row_h, :] = np.tile(rough, (1, TRIM_SIZE // row_h + 1))[:, :TRIM_SIZE]
        normal[y0 : y0 + row_h, :] = np.tile(norm, (1, TRIM_SIZE // row_h + 1, 1))[:, :TRIM_SIZE, :]
        height[y0 : y0 + row_h, :] = np.tile(ht, (1, TRIM_SIZE // row_h + 1))[:, :TRIM_SIZE]
        regions[family_name] = {
            "id": definition.family_id,
            "uv_rect": [0.0, float(y0) / TRIM_SIZE, 1.0, float(row_h) / TRIM_SIZE],
            "meters_per_repeat": definition.meters_per_repeat,
        }

    trim_dir = OUTPUT_ROOT / "architecture_trim"
    _write_png(trim_dir / "albedo.png", albedo)
    _write_png(trim_dir / "roughness.png", roughness)
    _write_png(trim_dir / "normal.png", normal)
    _write_png(trim_dir / "height.png", height)

    seam = max(_seam_score(albedo), _seam_score(roughness))
    return {
        "resolution": TRIM_SIZE,
        "seam_score": round(seam, 4),
        "regions": regions,
    }


def main() -> int:
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    entries: List[Dict] = []
    for name, definition in FAMILIES.items():
        entries.append(generate_family(name, definition))
    trim = generate_trim_sheet()

    manifest = {
        "generator_version": GENERATOR_VERSION,
        "global_seed": GLOBAL_SEED,
        "families": entries,
        "architecture_trim": trim,
        "channels": {
            "albedo": "sRGB color",
            "roughness": "linear data (grayscale)",
            "normal": "linear tangent-space (+Y up, Compatibility)",
            "height": "linear displacement source",
        },
    }
    manifest_path = OUTPUT_ROOT / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    digest = hashlib.sha256(manifest_path.read_bytes()).hexdigest()
    print(f"Generated {len(entries)} material families -> {OUTPUT_ROOT}")
    print(f"manifest sha256: {digest}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
