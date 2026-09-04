"""2-D geographic grid construction for marine A* routing."""
from __future__ import annotations

from dataclasses import dataclass
from math import ceil
from typing import Callable, Iterable

from shapely.geometry import Point

from .distance import haversine_km

@dataclass(frozen=True, order=True)
class GridNode:
    row: int
    col: int


class MarineGrid:
    """Regular lon/lat grid with land/MPA obstacle rasterization.

    The default 0.01 degree spacing matches the project specification. This is
    a geographic approximation; production routing should use a projected or
    geodesic-aware grid if accuracy requirements become stricter.
    """

    def __init__(self, min_lat: float, max_lat: float, min_lon: float, max_lon: float, resolution_deg: float = 0.01):
        if resolution_deg <= 0:
            raise ValueError("resolution_deg must be positive")
        if min_lat >= max_lat or min_lon >= max_lon:
            raise ValueError("invalid bounding box")
        self.min_lat, self.max_lat = min_lat, max_lat
        self.min_lon, self.max_lon = min_lon, max_lon
        self.resolution_deg = resolution_deg
        self.rows = int(ceil((max_lat - min_lat) / resolution_deg)) + 1
        self.cols = int(ceil((max_lon - min_lon) / resolution_deg)) + 1
        self.blocked: set[GridNode] = set()

    def node_to_coord(self, node: GridNode) -> tuple[float, float]:
        return (self.min_lat + node.row * self.resolution_deg, self.min_lon + node.col * self.resolution_deg)

    def coord_to_node(self, lat: float, lon: float) -> GridNode:
        row = round((lat - self.min_lat) / self.resolution_deg)
        col = round((lon - self.min_lon) / self.resolution_deg)
        node = GridNode(row, col)
        if not self.in_bounds(node):
            raise ValueError("coordinate lies outside grid")
        return node

    def in_bounds(self, node: GridNode) -> bool:
        return 0 <= node.row < self.rows and 0 <= node.col < self.cols

    def neighbors(self, node: GridNode, diagonal: bool = True) -> Iterable[GridNode]:
        offsets = [(-1, 0), (1, 0), (0, -1), (0, 1)]
        if diagonal:
            offsets += [(-1, -1), (-1, 1), (1, -1), (1, 1)]
        for dr, dc in offsets:
            candidate = GridNode(node.row + dr, node.col + dc)
            if self.in_bounds(candidate) and candidate not in self.blocked:
                yield candidate

    def rasterize_obstacles(self, *geometries, predicate: str = "covers") -> set[GridNode]:
        """Mark grid cells whose centre lies on/inside supplied geometries."""
        for geometry in geometries:
            if geometry is None or geometry.is_empty:
                continue
            for r in range(self.rows):
                for c in range(self.cols):
                    node = GridNode(r, c)
                    if node in self.blocked:
                        continue
                    lat, lon = self.node_to_coord(node)
                    point = Point(lon, lat)
                    hit = geometry.covers(point) if predicate == "covers" else geometry.intersects(point)
                    if hit:
                        self.blocked.add(node)
        return self.blocked

    def is_blocked(self, node: GridNode) -> bool:
        return node in self.blocked

    def unblock(self, node: GridNode) -> None:
        """Ensure start/goal nodes are traversable even if near coastline borders."""
        self.blocked.discard(node)

    def step_distance_km(self, a: GridNode, b: GridNode) -> float:
        return haversine_km(*self.node_to_coord(a), *self.node_to_coord(b))

    def path_length_km(self, path: list[GridNode]) -> float:
        """Compute the total geodesic distance along a path of grid nodes."""
        total = 0.0
        for i in range(len(path) - 1):
            total += self.step_distance_km(path[i], path[i + 1])
        return total
