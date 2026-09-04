"""Obstacle-aware A* pathfinding over a MarineGrid."""
from __future__ import annotations

import heapq
import math
from typing import Callable, Optional

from shapely.geometry import LineString

from .grid import MarineGrid, GridNode


def _octile_like(a: GridNode, b: GridNode) -> float:
    dr, dc = abs(a.row - b.row), abs(a.col - b.col)
    return math.sqrt(2) * min(dr, dc) + abs(dr - dc)


def astar(
    grid: MarineGrid,
    start: GridNode,
    goal: GridNode,
    *,
    cost_fn: Optional[Callable[[GridNode, GridNode], float]] = None,
) -> list[GridNode]:
    """Find a lowest-cost path; blocked cells are never traversed."""
    if not grid.in_bounds(start) or not grid.in_bounds(goal):
        raise ValueError("start or goal is outside grid")
    if grid.is_blocked(start) or grid.is_blocked(goal):
        raise ValueError("start or goal is blocked")
    if cost_fn is None:
        cost_fn = lambda _a, _b: 1.0

    open_heap: list[tuple[float, int, GridNode]] = []
    counter = 0
    heapq.heappush(open_heap, (_octile_like(start, goal), counter, start))
    came_from: dict[GridNode, GridNode] = {}
    g_score = {start: 0.0}
    closed: set[GridNode] = set()

    while open_heap:
        _, _, current = heapq.heappop(open_heap)
        if current in closed:
            continue
        if current == goal:
            path = [current]
            while current in came_from:
                current = came_from[current]
                path.append(current)
            return list(reversed(path))
        closed.add(current)

        for neighbor in grid.neighbors(current):
            if neighbor in closed:
                continue
            step_cost = float(cost_fn(current, neighbor))
            if not math.isfinite(step_cost) or step_cost < 0:
                continue
            tentative = g_score[current] + step_cost
            if tentative < g_score.get(neighbor, math.inf):
                came_from[neighbor] = current
                g_score[neighbor] = tentative
                counter += 1
                f = tentative + _octile_like(neighbor, goal)
                heapq.heappush(open_heap, (f, counter, neighbor))

    raise ValueError("No navigable path exists between start and goal")


def path_to_linestring(grid: MarineGrid, path: list[GridNode]) -> LineString:
    if not path:
        raise ValueError("path cannot be empty")
    return LineString([(lon, lat) for lat, lon in (grid.node_to_coord(n) for n in path)])


def path_to_geojson(grid: MarineGrid, path: list[GridNode]) -> dict:
    line = path_to_linestring(grid, path)
    return {
        "type": "Feature",
        "properties": {"geometry_type": "marine_astar_route", "waypoint_count": len(path)},
        "geometry": {"type": "LineString", "coordinates": [[x, y] for x, y in line.coords]},
    }
