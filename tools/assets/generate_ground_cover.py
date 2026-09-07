#!/usr/bin/env python3
"""Deterministic ground-cover meshes for package 08.

Generates small tuft/reed/shrub/flower/litter/stone GLTF variants with near/far
LODs under assets/ground_cover/. Runtime loads via GroundCoverAssets.
"""

from __future__ import annotations

import base64
import json
import math
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Sequence, Tuple

ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "assets" / "ground_cover"
GENERATOR_VERSION = "1.0.0"
GLOBAL_SEED = 0x080026

FAMILIES = ("rough_tuft", "bank_reed", "shrub", "flower", "leaf_litter", "small_stone")
LODS = ("near", "far")

LOD_THRESHOLDS = {"near_end": 95.0, "far_begin": 82.0, "far_end": 420.0}


@dataclass
class Rng:
    state: int

    def next_u01(self) -> float:
        self.state = (self.state * 1664525 + 1013904223) & 0xFFFFFFFF
        return self.state / 4294967296.0


@dataclass
class SurfaceData:
    positions: List[float] = field(default_factory=list)
    normals: List[float] = field(default_factory=list)
    colors: List[float] = field(default_factory=list)
    uvs: List[float] = field(default_factory=list)
    indices: List[int] = field(default_factory=list)

    def triangle_count(self) -> int:
        return len(self.indices) // 3

    def append_mesh(
        self,
        positions: Sequence[float],
        normals: Sequence[float],
        colors: Sequence[float],
        uvs: Sequence[float],
        indices: Sequence[int],
    ) -> None:
        base = len(self.positions) // 3
        self.positions.extend(positions)
        self.normals.extend(normals)
        self.colors.extend(colors)
        self.uvs.extend(uvs)
        self.indices.extend([i + base for i in indices])


def family_seed(family: str, variant: int) -> int:
    base = {"rough_tuft": 801, "bank_reed": 802, "shrub": 803, "flower": 804, "leaf_litter": 805, "small_stone": 806}
    return GLOBAL_SEED + base.get(family, 800) + variant * 97


def add_box(surface: SurfaceData, size: Tuple[float, float, float], center: Tuple[float, float, float], color: Tuple[float, float, float, float]) -> None:
    sx, sy, sz = size
    cx, cy, cz = center
    hx, hy, hz = sx * 0.5, sy * 0.5, sz * 0.5
    corners = [
        (-hx, -hy, -hz),
        (hx, -hy, -hz),
        (hx, hy, -hz),
        (-hx, hy, -hz),
        (-hx, -hy, hz),
        (hx, -hy, hz),
        (hx, hy, hz),
        (-hx, hy, hz),
    ]
    faces = [
        (0, 1, 2, 3, (0, 0, -1)),
        (4, 7, 6, 5, (0, 0, 1)),
        (0, 4, 5, 1, (0, -1, 0)),
        (2, 6, 7, 3, (0, 1, 0)),
        (0, 3, 7, 4, (-1, 0, 0)),
        (1, 5, 6, 2, (1, 0, 0)),
    ]
    for a, b, c, d, normal in faces:
        base = len(surface.positions) // 3
        for corner_idx in (a, b, c, d):
            x, y, z = corners[corner_idx]
            surface.positions.extend([cx + x, cy + y, cz + z])
            surface.normals.extend(list(normal))
            surface.colors.extend(list(color))
            surface.uvs.extend([0.5, 0.5])
        surface.indices.extend([base, base + 1, base + 2, base, base + 2, base + 3])


def add_blade(surface: SurfaceData, height: float, angle: float, color: Tuple[float, float, float, float], width: float = 0.05) -> None:
    ca, sa = math.cos(angle), math.sin(angle)
    dx, dz = ca * width * 0.5, sa * width * 0.5
    verts = [(-dx, 0, -dz), (dx, 0, dz), (dx * 0.4, height, dz * 0.4), (-dx * 0.4, height, -dz * 0.4)]
    normal = (sa, 0.2, -ca)
    ln = math.sqrt(normal[0] ** 2 + normal[1] ** 2 + normal[2] ** 2) or 1.0
    normal = tuple(v / ln for v in normal)
    base = len(surface.positions) // 3
    for i, (x, y, z) in enumerate(verts):
        surface.positions.extend([x, y, z])
        surface.normals.extend(normal)
        surface.colors.extend(list(color))
        surface.uvs.extend([float(i) / 3.0, y / max(height, 0.01)])
    surface.indices.extend([base, base + 1, base + 2, base, base + 2, base + 3])


def generate_mesh(family: str, variant: int, lod: str) -> SurfaceData:
    rng = Rng(family_seed(family, variant) + (11 if lod == "far" else 0))
    surface = SurfaceData()
    detail = 1.0 if lod == "near" else 0.55
    if family == "rough_tuft":
        grass = (0.45, 0.56, 0.28, 0.92)
        count = int(7 * detail) + 3
        for i in range(count):
            angle = rng.next_u01() * math.tau
            add_blade(surface, 0.35 + rng.next_u01() * 0.25, angle, grass)
    elif family == "bank_reed":
        reed = (0.52, 0.58, 0.34, 0.88)
        count = int(5 * detail) + 2
        for i in range(count):
            angle = rng.next_u01() * math.tau
            add_blade(surface, 0.55 + rng.next_u01() * 0.35, angle, reed, 0.04)
    elif family == "shrub":
        leaf = (0.28, 0.42, 0.22, 0.95)
        blobs = 2 if lod == "far" else 4
        for i in range(blobs):
            r = 0.18 + rng.next_u01() * 0.12
            add_box(surface, (r * 2, r * 1.2, r * 2), (rng.next_u01() * 0.2 - 0.1, r * 0.5, rng.next_u01() * 0.2 - 0.1), leaf)
    elif family == "flower":
        stem = (0.35, 0.48, 0.22, 0.9)
        petals = [(0.86, 0.42, 0.55, 1.0), (0.92, 0.78, 0.28, 1.0), (0.55, 0.62, 0.92, 1.0)]
        add_blade(surface, 0.22, 0.0, stem, 0.03)
        for i in range(3 if lod == "near" else 1):
            col = petals[i % 3]
            add_box(surface, (0.12, 0.08, 0.12), (0.0, 0.24 + i * 0.03, 0.0), col)
    elif family == "leaf_litter":
        litter = (0.42, 0.34, 0.22, 0.75)
        count = int(6 * detail) + 2
        for i in range(count):
            add_box(
                surface,
                (0.14 + rng.next_u01() * 0.08, 0.02, 0.1 + rng.next_u01() * 0.06),
                (rng.next_u01() * 0.35 - 0.17, 0.01, rng.next_u01() * 0.35 - 0.17),
                litter,
            )
    elif family == "small_stone":
        stone = (0.46, 0.48, 0.42, 1.0)
        count = 1 if lod == "far" else 2
        for i in range(count):
            sx = 0.12 + rng.next_u01() * 0.16
            sy = sx * (0.45 + rng.next_u01() * 0.25)
            add_box(surface, (sx, sy, sx * 0.9), (rng.next_u01() * 0.12, sy * 0.5, rng.next_u01() * 0.12), stone)
    return surface


def write_gltf(path: Path, surface: SurfaceData) -> None:
    accessors: List[dict] = []
    buffer_views: List[dict] = []
    buffer_chunks: List[bytes] = []
    byte_offset = 0

    def add_accessor(data: bytes, comp_type: int, count: int, type_name: str, target: int | None = None) -> int:
        nonlocal byte_offset
        buffer_views.append({"buffer": 0, "byteOffset": byte_offset, "byteLength": len(data), **({"target": target} if target else {})})
        accessors.append({"bufferView": len(buffer_views) - 1, "componentType": comp_type, "count": count, "type": type_name})
        buffer_chunks.append(data)
        byte_offset += len(data)
        return len(accessors) - 1

    def pack_f32(values: Sequence[float]) -> bytes:
        return b"".join(struct_pack("<f", v) for v in values)

    def struct_pack(fmt: str, value: float) -> bytes:
        import struct

        return struct.pack(fmt, value)

    pos = add_accessor(pack_f32(surface.positions), 5126, len(surface.positions) // 3, "VEC3", 34962)
    norm = add_accessor(pack_f32(surface.normals), 5126, len(surface.normals) // 3, "VEC3", 34962)
    color = add_accessor(pack_f32(surface.colors), 5126, len(surface.colors) // 4, "VEC4", 34962)
    uv = add_accessor(pack_f32(surface.uvs), 5126, len(surface.uvs) // 2, "VEC2", 34962)
    index_bytes = b"".join(struct_pack("<H", i) for i in surface.indices)
    idx = add_accessor(index_bytes, 5123, len(surface.indices), "SCALAR", 34963)
    buffer_bytes = b"".join(buffer_chunks)
    gltf = {
        "asset": {"version": "2.0", "generator": f"hole-in-fun-ground-cover/{GENERATOR_VERSION}"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"mesh": 0, "name": "cover"}],
        "meshes": [
            {
                "name": "cover",
                "primitives": [
                    {
                        "attributes": {"POSITION": pos, "NORMAL": norm, "COLOR_0": color, "TEXCOORD_0": uv},
                        "indices": idx,
                        "mode": 4,
                    }
                ],
            }
        ],
        "accessors": accessors,
        "bufferViews": buffer_views,
        "buffers": [{"byteLength": len(buffer_bytes), "uri": "data:application/octet-stream;base64," + base64.b64encode(buffer_bytes).decode("ascii")}],
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(gltf, separators=(",", ":")))


def write_import_sidecar(path: Path) -> None:
    rel = path.relative_to(ROOT).as_posix()
    path.with_suffix(path.suffix + ".import").write_text(
        f"""[remap]

importer="scene"
type="PackedScene"
uid="uid://gc{abs(hash(str(path))) % 10**8}"

[deps]

source_file="res://{rel}"

[params]

nodes/root_type=""
nodes/root_name=""
"""
    )


def generate_all() -> dict:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    variants: List[dict] = []
    for family in FAMILIES:
        variant_count = 2 if family in ("rough_tuft", "shrub", "small_stone") else 1
        for variant in range(variant_count):
            stats: Dict[str, dict] = {}
            for lod in LODS:
                mesh = generate_mesh(family, variant, lod)
                rel = OUT_DIR / f"{family}_v{variant}_{lod}.gltf"
                write_gltf(rel, mesh)
                write_import_sidecar(rel)
                stats[lod] = {"triangles": mesh.triangle_count(), "seed": family_seed(family, variant)}
            variants.append(
                {
                    "family": family,
                    "variant": variant,
                    "seed": family_seed(family, variant),
                    "paths": {lod: f"ground_cover/{family}_v{variant}_{lod}.gltf" for lod in LODS},
                    "stats": stats,
                }
            )
    manifest = {
        "generator_version": GENERATOR_VERSION,
        "global_seed": GLOBAL_SEED,
        "lod_thresholds": LOD_THRESHOLDS,
        "materials": {
            "foliage_families": ["rough_tuft", "bank_reed", "shrub", "flower"],
            "stone_families": ["small_stone"],
            "litter_material": "course.rough",
        },
        "variants": variants,
    }
    (OUT_DIR / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return manifest


def main() -> None:
    manifest = generate_all()
    print(f"Generated {len(manifest['variants'])} ground-cover variants under {OUT_DIR}")


if __name__ == "__main__":
    main()
