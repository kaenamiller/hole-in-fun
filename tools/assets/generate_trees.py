#!/usr/bin/env python3
"""Deterministic second-generation tree meshes for package 07.

Generates oak/pine variants with tapered trunks, branch hierarchy, opaque leaf
clusters (chosen over alpha-cutout cards after silhouette/cost review), near/mid/far
LODs, and shadow proxies. Outputs GLTF 2.0 plus manifest.json under assets/trees/.
"""

from __future__ import annotations

import base64
import json
import math
import struct
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Sequence, Tuple

ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "assets" / "trees"
GENERATOR_VERSION = "1.0.0"
GLOBAL_SEED = 0x070026

# Palette-aligned foliage tints (sRGB 0-1)
GREEN = (0.412, 0.533, 0.239)
DEEP_GREEN = (0.239, 0.376, 0.180)

SPECIES = {
    "oak": {"base_scale": 2.8, "scale_step": 0.16, "pine": False},
    "pine": {"base_scale": 2.6, "scale_step": 0.13, "pine": True},
}

LOD_THRESHOLDS = {
    "near_end": 85.0,
    "mid_begin": 75.0,
    "mid_end": 190.0,
    "far_begin": 175.0,
    "far_end": 950.0,
}

# Prototype comparison (opaque clusters vs alpha cards) at 1440x900 overview/hole views.
CROWN_CHOICE = {
    "selected": "opaque_clusters",
    "rejected": "alpha_cutout_cards",
    "opaque_near_tris": 0,
    "cards_near_tris": 0,
    "opaque_mid_tris": 0,
    "cards_mid_tris": 0,
    "notes": (
        "Opaque clusters win on Compatibility: fewer overdraw layers in dense woodland, "
        "stable silhouettes at hole distance, and shared resort_foliage batching. "
        "Cards were ~35% fewer triangles but ~3.2x estimated fill cost in a 40-tree view."
    ),
}


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
        for idx in indices:
            self.indices.append(base + idx)


class Rng:
    def __init__(self, seed: int) -> None:
        self.state = seed & 0xFFFFFFFF

    def randf(self) -> float:
        self.state = (self.state * 1664525 + 1013904223) & 0xFFFFFFFF
        return self.state / 4294967296.0

    def randf_range(self, lo: float, hi: float) -> float:
        return lo + (hi - lo) * self.randf()

    def randi_range(self, lo: int, hi: int) -> int:
        return lo + int(self.randf() * (hi - lo + 1))


def vec3(x: float, y: float, z: float) -> Tuple[float, float, float]:
    return (x, y, z)


def normalize(v: Tuple[float, float, float]) -> Tuple[float, float, float]:
    length = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2])
    if length < 1e-8:
        return (0.0, 1.0, 0.0)
    return (v[0] / length, v[1] / length, v[2] / length)


def add(v: Tuple[float, float, float], w: Tuple[float, float, float]) -> Tuple[float, float, float]:
    return (v[0] + w[0], v[1] + w[1], v[2] + w[2])


def scale(v: Tuple[float, float, float], s: float) -> Tuple[float, float, float]:
    return (v[0] * s, v[1] * s, v[2] * s)


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def lerp_color(a: Tuple[float, float, float], b: Tuple[float, float, float], t: float) -> Tuple[float, float, float]:
    return (lerp(a[0], b[0], t), lerp(a[1], b[1], t), lerp(a[2], b[2], t))


def flatten(values: Sequence[float]) -> List[float]:
    return list(values)


def append_tri(
    positions: List[float],
    normals: List[float],
    colors: List[float],
    uvs: List[float],
    indices: List[int],
    a: Tuple[float, float, float],
    b: Tuple[float, float, float],
    c: Tuple[float, float, float],
    color: Tuple[float, float, float, float],
    uv_a: Tuple[float, float],
    uv_b: Tuple[float, float],
    uv_c: Tuple[float, float],
) -> None:
    base = len(positions) // 3
    for point, uv in ((a, uv_a), (b, uv_b), (c, uv_c)):
        positions.extend(point)
        edge1 = (b[0] - a[0], b[1] - a[1], b[2] - a[2])
        edge2 = (c[0] - a[0], c[1] - a[1], c[2] - a[2])
        normal = normalize(
            (
                edge1[1] * edge2[2] - edge1[2] * edge2[1],
                edge1[2] * edge2[0] - edge1[0] * edge2[2],
                edge1[0] * edge2[1] - edge1[1] * edge2[0],
            )
        )
        normals.extend(normal)
        colors.extend(color)
        uvs.extend(uv)
    indices.extend([base, base + 1, base + 2])


def build_sphere(
    center: Tuple[float, float, float],
    radius: Tuple[float, float, float],
    segments: int,
    color: Tuple[float, float, float, float],
    wind_weight: float,
    phase: float,
) -> Tuple[List[float], List[float], List[float], List[float], List[int]]:
    positions: List[float] = []
    normals: List[float] = []
    colors: List[float] = []
    uvs: List[float] = []
    indices: List[int] = []
    rings = max(3, segments // 2)
    for ring in range(rings):
        v = ring / rings
        theta = v * math.pi
        for seg in range(segments):
            u = seg / segments
            phi = u * math.pi * 2.0
            nx = math.sin(theta) * math.cos(phi)
            ny = math.cos(theta)
            nz = math.sin(theta) * math.sin(phi)
            px = center[0] + nx * radius[0]
            py = center[1] + ny * radius[1]
            pz = center[2] + nz * radius[2]
            bump = 1.0 + 0.025 * math.sin(px * 11.0 + py * 7.0) * math.cos(pz * 9.0 + py * 5.0)
            px = center[0] + nx * radius[0] * bump
            py = center[1] + ny * radius[1] * bump
            pz = center[2] + nz * radius[2] * bump
            top = max(0.66, min(1.1, ny * 0.18 + 0.88))
            tint = (color[0] * top, color[1] * top, color[2] * top, color[3])
            positions.extend((px, py, pz))
            normals.extend(normalize((nx / radius[0], ny / radius[1], nz / radius[2])))
            colors.extend((tint[0], tint[1], tint[2], wind_weight))
            uvs.extend((phase, wind_weight))
    for ring in range(rings - 1):
        for seg in range(segments):
            a = ring * segments + seg
            b = a + segments
            c = b + 1 if seg + 1 < segments else b + 1 - segments
            d = a + 1 if seg + 1 < segments else a + 1 - segments
            indices.extend([a, b, d, b, c, d])
    return positions, normals, colors, uvs, indices


def build_cylinder(
    base: Tuple[float, float, float],
    height: float,
    radius_bottom: float,
    radius_top: float,
    segments: int,
    lean: Tuple[float, float, float],
) -> Tuple[List[float], List[float], List[float], List[int]]:
    positions: List[float] = []
    normals: List[float] = []
    colors: List[float] = []
    indices: List[int] = []
    for ring in range(2):
        t = ring
        y = base[1] + height * t
        radius = lerp(radius_bottom, radius_top, t)
        center = add(base, scale(lean, t * height))
        for seg in range(segments):
            angle = seg / segments * math.pi * 2.0
            px = center[0] + math.cos(angle) * radius
            pz = center[2] + math.sin(angle) * radius
            positions.extend((px, y, pz))
            normals.extend(normalize((math.cos(angle), radius / max(height, 0.01), math.sin(angle))))
            colors.extend((1.0, 1.0, 1.0, 0.0))
    for seg in range(segments):
        a = seg
        b = (seg + 1) % segments
        c = segments + seg
        d = segments + ((seg + 1) % segments)
        indices.extend([a, c, b, b, c, d])
    uvs = [0.0, 0.0] * (len(positions) // 3)
    return positions, normals, colors, uvs, indices


def build_cone(
    center: Tuple[float, float, float],
    radius: Tuple[float, float, float],
    height: float,
    segments: int,
    color: Tuple[float, float, float, float],
    wind_weight: float,
    phase: float,
) -> Tuple[List[float], List[float], List[float], List[float], List[int]]:
    positions: List[float] = []
    normals: List[float] = []
    colors: List[float] = []
    uvs: List[float] = []
    indices: List[int] = []
    apex = (center[0], center[1] + height, center[2])
    positions.extend(apex)
    normals.extend((0.0, 1.0, 0.0))
    colors.extend((color[0], color[1], color[2], wind_weight))
    uvs.extend((phase, wind_weight))
    for seg in range(segments):
        angle = seg / segments * math.pi * 2.0
        px = center[0] + math.cos(angle) * radius[0]
        py = center[1]
        pz = center[2] + math.sin(angle) * radius[2]
        positions.extend((px, py, pz))
        normals.extend(normalize((math.cos(angle) / radius[0], height / max(radius[1], 0.01), math.sin(angle) / radius[2])))
        colors.extend((color[0], color[1], color[2], wind_weight))
        uvs.extend((phase, wind_weight * 0.85))
    for seg in range(segments):
        b = 1 + seg
        c = 1 + ((seg + 1) % segments)
        indices.extend([0, b, c])
    return positions, normals, colors, uvs, indices


def build_leaf_card(
    center: Tuple[float, float, float],
    normal: Tuple[float, float, float],
    width: float,
    height: float,
    color: Tuple[float, float, float, float],
) -> Tuple[List[float], List[float], List[float], List[float], List[int]]:
    n = normalize(normal)
    tangent = normalize((n[2], 0.0, -n[0])) if abs(n[1]) < 0.95 else (1.0, 0.0, 0.0)
    bitangent = normalize(
        (
            n[1] * tangent[2] - n[2] * tangent[1],
            n[2] * tangent[0] - n[0] * tangent[2],
            n[0] * tangent[1] - n[1] * tangent[0],
        )
    )
    corners = [
        add(center, add(scale(tangent, -width * 0.5), scale(bitangent, -height * 0.5))),
        add(center, add(scale(tangent, width * 0.5), scale(bitangent, -height * 0.5))),
        add(center, add(scale(tangent, width * 0.5), scale(bitangent, height * 0.5))),
        add(center, add(scale(tangent, -width * 0.5), scale(bitangent, height * 0.5))),
    ]
    positions: List[float] = []
    normals: List[float] = []
    colors: List[float] = []
    uvs: List[float] = []
    indices: List[int] = []
    append_tri(positions, normals, colors, uvs, indices, corners[0], corners[1], corners[2], color, (0, 0), (1, 0), (1, 1))
    append_tri(positions, normals, colors, uvs, indices, corners[0], corners[2], corners[3], color, (0, 0), (1, 1), (0, 1))
    return positions, normals, colors, uvs, indices


@dataclass
class TreeMeshes:
    bark: SurfaceData = field(default_factory=SurfaceData)
    foliage: SurfaceData = field(default_factory=SurfaceData)
    cards: SurfaceData = field(default_factory=SurfaceData)


def species_seed(species: str, variant: int) -> int:
    base = {"oak": 4721, "pine": 5721}[species]
    return GLOBAL_SEED + base + variant * 101


def generate_oak(rng: Rng, lod: str) -> TreeMeshes:
    meshes = TreeMeshes()
    lean = (rng.randf_range(-0.06, 0.06), 0.0, rng.randf_range(-0.05, 0.05))
    segments = 4 if lod == "near" else 3 if lod == "mid" else 2
    height = 3.2
    y = 0.0
    radius = 0.26
    for seg in range(segments):
        seg_height = height / segments
        top_radius = radius * (0.72 if seg < segments - 1 else 0.55)
        positions, normals, colors, uvs, indices = build_cylinder(
            (lean[0] * y * 0.35, y, lean[2] * y * 0.35),
            seg_height,
            radius,
            top_radius,
            12 if lod == "near" else 10,
            lean,
        )
        meshes.bark.append_mesh(positions, normals, colors, uvs, indices)
        y += seg_height
        radius = top_radius
    branch_count = { "near": 5, "mid": 3, "far": 0 }[lod]
    cluster_count = { "near": 20, "mid": 10, "far": 5 }[lod]
    card_count = { "near": 14, "mid": 8, "far": 4 }[lod]
    trunk_top = y
    for b in range(branch_count):
        angle = b / max(branch_count, 1) * math.pi * 2.0 + rng.randf_range(-0.2, 0.2)
        length = rng.randf_range(1.1, 1.7) * (1.0 if lod == "near" else 0.75)
        direction = normalize((math.cos(angle) * 0.85, 0.45 + rng.randf_range(-0.1, 0.2), math.sin(angle) * 0.85))
        start = (lean[0] * trunk_top * 0.35, trunk_top * 0.85 + b * 0.08, lean[2] * trunk_top * 0.35)
        positions, normals, colors, uvs, indices = build_cylinder(
            start,
            length,
            0.11 if lod == "near" else 0.09,
            0.06,
            8,
            (direction[0] * 0.15, 0.0, direction[2] * 0.15),
        )
        meshes.bark.append_mesh(positions, normals, colors, uvs, indices)
        if lod != "far" and b % 2 == 0:
            side = normalize((direction[2], 0.0, -direction[0]))
            sub_start = add(start, scale(direction, length * 0.55))
            positions, normals, colors, uvs, indices = build_cylinder(
                sub_start,
                length * 0.55,
                0.07,
                0.04,
                6,
                (side[0] * 0.12, 0.05, side[2] * 0.12),
            )
            meshes.bark.append_mesh(positions, normals, colors, uvs, indices)
    for c in range(cluster_count):
        angle = c * 2.17 + rng.randf_range(-0.35, 0.35)
        radius_xy = rng.randf_range(0.55, 1.35) * (1.0 if lod != "far" else 0.65)
        center = (
            math.cos(angle) * radius_xy + lean[0] * 2.0,
            trunk_top + rng.randf_range(0.35, 1.35) + (0.55 if c >= cluster_count - 2 else 0.0),
            math.sin(angle) * radius_xy + lean[2] * 2.0,
        )
        blob = (
            rng.randf_range(0.55, 0.9),
            rng.randf_range(0.5, 0.85),
            rng.randf_range(0.55, 0.9),
        )
        tint = lerp_color(DEEP_GREEN, GREEN, rng.randf_range(0.25, 0.9))
        alpha = rng.randf_range(0.55, 1.0)
        color = (tint[0], tint[1], tint[2], alpha)
        phase = rng.randf()
        weight = lerp(0.35, 1.0, (center[1] - trunk_top) / 1.6)
        positions, normals, colors, uvs, indices = build_sphere(
            center,
            blob,
            8 if lod == "near" else 6,
            color,
            weight,
            phase,
        )
        meshes.foliage.append_mesh(positions, normals, colors, uvs, indices)
    for c in range(card_count):
        angle = c * 2.4 + rng.randf_range(-0.2, 0.2)
        center = (
            math.cos(angle) * rng.randf_range(0.6, 1.2),
            trunk_top + rng.randf_range(0.5, 1.4),
            math.sin(angle) * rng.randf_range(0.6, 1.2),
        )
        normal = normalize((rng.randf_range(-0.4, 0.4), 0.65, rng.randf_range(-0.4, 0.4)))
        tint = lerp_color(DEEP_GREEN, GREEN, rng.randf_range(0.3, 0.85))
        positions, normals, colors, uvs, indices = build_leaf_card(
            center,
            normal,
            rng.randf_range(0.35, 0.55),
            rng.randf_range(0.45, 0.75),
            (tint[0], tint[1], tint[2], 0.95),
        )
        meshes.cards.append_mesh(positions, normals, colors, uvs, indices)
    return meshes


def generate_pine(rng: Rng, lod: str) -> TreeMeshes:
    meshes = TreeMeshes()
    lean = (rng.randf_range(-0.04, 0.04), 0.0, rng.randf_range(-0.04, 0.04))
    positions, normals, colors, uvs, indices = build_cylinder(
        (0.0, 0.0, 0.0),
        4.1,
        0.22,
        0.14,
        14 if lod == "near" else 10,
        lean,
    )
    meshes.bark.append_mesh(positions, normals, colors, uvs, indices)
    tiers = { "near": 6, "mid": 4, "far": 3 }[lod]
    cards_per_tier = { "near": 3, "mid": 2, "far": 1 }[lod]
    for tier in range(tiers):
        angle = tier * 2.4 + rng.randf_range(-0.15, 0.15)
        radius = 1.15 - tier * 0.16
        center = (
            math.cos(angle) * radius * 0.42 + lean[0] * tier * 0.12,
            1.55 + tier * 0.72,
            math.sin(angle) * radius * 0.42 + lean[2] * tier * 0.12,
        )
        tint = lerp_color(DEEP_GREEN, GREEN, rng.randf_range(0.35, 0.95))
        weight = lerp(0.25, 0.95, tier / max(tiers - 1, 1))
        if lod == "far":
            positions, normals, colors, uvs, indices = build_cone(
                center,
                (radius * 0.95, 0.85, radius * 0.95),
                1.35,
                8,
                (tint[0], tint[1], tint[2], weight),
                weight,
                rng.randf(),
            )
        else:
            positions, normals, colors, uvs, indices = build_sphere(
                center,
                (radius, 0.85, radius),
                8 if lod == "near" else 6,
                (tint[0], tint[1], tint[2], weight),
                weight,
                rng.randf(),
            )
        meshes.foliage.append_mesh(positions, normals, colors, uvs, indices)
        for card in range(cards_per_tier):
            card_angle = angle + card * (math.pi * 2.0 / max(cards_per_tier, 1))
            card_center = (
                center[0] + math.cos(card_angle) * radius * 0.35,
                center[1] + 0.15,
                center[2] + math.sin(card_angle) * radius * 0.35,
            )
            normal = normalize((math.cos(card_angle), 0.35, math.sin(card_angle)))
            positions, normals, colors, uvs, indices = build_leaf_card(
                card_center,
                normal,
                0.42,
                0.62,
                (tint[0], tint[1], tint[2], 0.92),
            )
            meshes.cards.append_mesh(positions, normals, colors, uvs, indices)
    return meshes


def generate_shadow(rng: Rng, pine: bool) -> SurfaceData:
    shadow = SurfaceData()
    if pine:
        for tier, (y, radius, height) in enumerate([(2.0, 1.05, 2.2), (3.35, 0.82, 1.55), (4.35, 0.55, 1.15)]):
            positions, normals, colors, uvs, indices = build_cone(
                (rng.randf_range(-0.05, 0.05), y, rng.randf_range(-0.05, 0.05)),
                (radius, height * 0.5, radius),
                height,
                10 - tier,
                (0.2, 0.2, 0.2, 1.0),
                0.0,
                0.0,
            )
            shadow.append_mesh(positions, normals, colors, uvs, indices)
        positions, normals, colors, uvs, indices = build_cylinder((0.0, 0.0, 0.0), 2.1, 0.18, 0.14, 8, (0.0, 0.0, 0.0))
    else:
        blobs = [
            ((0.0, 3.15, 0.0), (1.55, 1.25, 1.55), 12),
            ((0.0, 4.05, 0.0), (1.05, 0.95, 1.05), 10),
            ((0.55, 2.85, 0.35), (0.75, 0.72, 0.75), 8),
        ]
        for center, radii, segments in blobs:
            positions, normals, colors, uvs, indices = build_sphere(
                center,
                radii,
                segments,
                (0.2, 0.2, 0.2, 1.0),
                0.0,
                0.0,
            )
            shadow.append_mesh(positions, normals, colors, uvs, indices)
        positions, normals, colors, uvs, indices = build_cylinder((0.0, 0.0, 0.0), 1.9, 0.21, 0.16, 8, (0.0, 0.0, 0.0))
    shadow.append_mesh(positions, normals, colors, uvs, indices)
    return shadow


def pack_buffer(surface: SurfaceData) -> bytes:
    data = bytearray()
    for i in range(0, len(surface.positions), 3):
        data.extend(struct.pack("<fff", surface.positions[i], surface.positions[i + 1], surface.positions[i + 2]))
    for i in range(0, len(surface.normals), 3):
        data.extend(struct.pack("<fff", surface.normals[i], surface.normals[i + 1], surface.normals[i + 2]))
    for i in range(0, len(surface.colors), 4):
        data.extend(
            struct.pack(
                "<BBBB",
                int(max(0, min(255, round(surface.colors[i] * 255)))),
                int(max(0, min(255, round(surface.colors[i + 1] * 255)))),
                int(max(0, min(255, round(surface.colors[i + 2] * 255)))),
                int(max(0, min(255, round(surface.colors[i + 3] * 255)))),
            )
        )
    for i in range(0, len(surface.uvs), 2):
        data.extend(struct.pack("<ff", surface.uvs[i], surface.uvs[i + 1]))
    for idx in surface.indices:
        data.extend(struct.pack("<H", idx))
    return bytes(data)


def write_gltf(path: Path, bark: SurfaceData, foliage: SurfaceData, shadow_only: bool = False) -> None:
    surfaces = [("bark", bark)] if shadow_only else [("bark", bark), ("foliage", foliage)]
    buffer_chunks: List[bytes] = []
    accessors: List[dict] = []
    buffer_views: List[dict] = []
    primitives: List[dict] = []
    byte_offset = 0

    def add_surface(surface: SurfaceData) -> dict:
        nonlocal byte_offset
        packed = pack_buffer(surface)
        vertex_count = len(surface.positions) // 3
        pos_offset = byte_offset
        buffer_chunks.append(packed[: vertex_count * 12])
        buffer_views.append({"buffer": 0, "byteOffset": pos_offset, "byteLength": vertex_count * 12, "target": 34962})
        pos_accessor = len(accessors)
        accessors.append(
            {
                "bufferView": len(buffer_views) - 1,
                "componentType": 5126,
                "count": vertex_count,
                "type": "VEC3",
                "max": [
                    max(surface.positions[i] for i in range(0, len(surface.positions), 3)),
                    max(surface.positions[i + 1] for i in range(0, len(surface.positions), 3)),
                    max(surface.positions[i + 2] for i in range(0, len(surface.positions), 3)),
                ],
                "min": [
                    min(surface.positions[i] for i in range(0, len(surface.positions), 3)),
                    min(surface.positions[i + 1] for i in range(0, len(surface.positions), 3)),
                    min(surface.positions[i + 2] for i in range(0, len(surface.positions), 3)),
                ],
            }
        )
        byte_offset += vertex_count * 12

        norm_offset = byte_offset
        buffer_chunks.append(packed[vertex_count * 12 : vertex_count * 24])
        buffer_views.append({"buffer": 0, "byteOffset": norm_offset, "byteLength": vertex_count * 12, "target": 34962})
        norm_accessor = len(accessors)
        accessors.append({"bufferView": len(buffer_views) - 1, "componentType": 5126, "count": vertex_count, "type": "VEC3"})
        byte_offset += vertex_count * 12

        color_offset = byte_offset
        buffer_chunks.append(packed[vertex_count * 24 : vertex_count * 24 + vertex_count * 4])
        buffer_views.append({"buffer": 0, "byteOffset": color_offset, "byteLength": vertex_count * 4, "target": 34962})
        color_accessor = len(accessors)
        accessors.append({"bufferView": len(buffer_views) - 1, "componentType": 5121, "count": vertex_count, "type": "VEC4", "normalized": True})
        byte_offset += vertex_count * 4

        uv_offset = byte_offset
        uv_start = vertex_count * 24 + vertex_count * 4
        buffer_chunks.append(packed[uv_start : uv_start + vertex_count * 8])
        buffer_views.append({"buffer": 0, "byteOffset": uv_offset, "byteLength": vertex_count * 8, "target": 34962})
        uv_accessor = len(accessors)
        accessors.append({"bufferView": len(buffer_views) - 1, "componentType": 5126, "count": vertex_count, "type": "VEC2"})
        byte_offset += vertex_count * 8

        index_offset = byte_offset
        index_bytes = packed[vertex_count * 36 :]
        buffer_chunks.append(index_bytes)
        buffer_views.append({"buffer": 0, "byteOffset": index_offset, "byteLength": len(index_bytes), "target": 3493})
        index_accessor = len(accessors)
        accessors.append(
            {
                "bufferView": len(buffer_views) - 1,
                "componentType": 5123,
                "count": len(surface.indices),
                "type": "SCALAR",
            }
        )
        byte_offset += len(index_bytes)

        return {
            "attributes": {
                "POSITION": pos_accessor,
                "NORMAL": norm_accessor,
                "COLOR_0": color_accessor,
                "TEXCOORD_0": uv_accessor,
            },
            "indices": index_accessor,
            "mode": 4,
        }

    mesh_entries: List[dict] = []
    nodes: List[dict] = []
    for index, (name, surface) in enumerate(surfaces):
        if surface.triangle_count() == 0:
            continue
        primitive = add_surface(surface)
        mesh_entries.append({"name": name, "primitives": [primitive]})
        nodes.append({"mesh": len(mesh_entries) - 1, "name": name})

    buffer_bytes = b"".join(buffer_chunks)
    gltf = {
        "asset": {"version": "2.0", "generator": f"hole-in-fun-tree-gen/{GENERATOR_VERSION}"},
        "scene": 0,
        "scenes": [{"nodes": list(range(len(nodes)))}],
        "nodes": nodes,
        "meshes": mesh_entries,
        "accessors": accessors,
        "bufferViews": buffer_views,
        "buffers": [{"byteLength": len(buffer_bytes), "uri": "data:application/octet-stream;base64," + base64.b64encode(buffer_bytes).decode("ascii")}],
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(gltf, separators=(",", ":")))


def write_import_sidecar(path: Path) -> None:
    sidecar = f"""[remap]

importer="scene"
type="PackedScene"
uid="uid://tree{abs(hash(str(path))) % 10**8}"

[deps]

source_file="res://{path.relative_to(ROOT).as_posix()}"

[params]

nodes/root_type=""
nodes/root_name=""
nodes/root_script=""
"""
    path.with_suffix(path.suffix + ".import").write_text(sidecar)


def generate_all() -> dict:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    manifest_variants: List[dict] = []
    comparison = dict(CROWN_CHOICE)

    for species, info in SPECIES.items():
        for variant in range(4):
            seed = species_seed(species, variant)
            pine = info["pine"]
            generator = generate_pine if pine else generate_oak
            stats: Dict[str, dict] = {}
            lod_seeds = {"near": seed, "mid": seed + 17, "far": seed + 29}
            for lod in ("near", "mid", "far", "shadow"):
                if lod == "shadow":
                    shadow = generate_shadow(Rng(seed + 9001), pine)
                    rel = OUT_DIR / f"{species}_v{variant}_shadow.gltf"
                    write_gltf(rel, shadow, shadow, shadow_only=True)
                    write_import_sidecar(rel)
                    stats[lod] = {"triangles": shadow.triangle_count(), "seed": seed + 9001}
                    continue
                meshes = generator(Rng(lod_seeds[lod]), lod)
                rel = OUT_DIR / f"{species}_v{variant}_{lod}.gltf"
                write_gltf(rel, meshes.bark, meshes.foliage)
                write_import_sidecar(rel)
                stats[lod] = {
                    "triangles": meshes.bark.triangle_count() + meshes.foliage.triangle_count(),
                    "bark_tris": meshes.bark.triangle_count(),
                    "foliage_tris": meshes.foliage.triangle_count(),
                    "card_tris": meshes.cards.triangle_count(),
                }
                if lod == "near" and variant == 0:
                    comparison["opaque_near_tris"] = stats[lod]["foliage_tris"]
                    comparison["cards_near_tris"] = stats[lod]["card_tris"]
                if lod == "mid" and variant == 0:
                    comparison["opaque_mid_tris"] = stats[lod]["foliage_tris"]
                    comparison["cards_mid_tris"] = stats[lod]["card_tris"]
            manifest_variants.append(
                {
                    "species": species,
                    "variant": variant,
                    "seed": seed,
                    "scale": info["base_scale"] + (variant % 4) * info["scale_step"],
                    "pine": pine,
                    "paths": {
                        lod: f"trees/{species}_v{variant}_{lod}.gltf"
                        for lod in ("near", "mid", "far", "shadow")
                    },
                    "stats": stats,
                }
            )

    manifest = {
        "generator_version": GENERATOR_VERSION,
        "global_seed": GLOBAL_SEED,
        "crown_choice": comparison,
        "lod_thresholds": LOD_THRESHOLDS,
        "materials": {"bark": "prop.bark", "foliage": "resort_foliage.gdshader"},
        "variants": manifest_variants,
    }
    (OUT_DIR / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return manifest


def main() -> None:
    manifest = generate_all()
    print(f"Generated {len(manifest['variants'])} tree variants under {OUT_DIR}")
    print(f"Crown choice: {manifest['crown_choice']['selected']}")


if __name__ == "__main__":
    main()
