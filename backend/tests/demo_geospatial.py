"""Visual Day 1/Day 2 demo for ORCA Dev 1.

Run from backend/:
    python tests/demo_geospatial.py

Or from repo root:
    python backend/tests/demo_geospatial.py

The demo uses synthetic polygons so it works before the real India coastline,
IMBL and MPA datasets are added to data/boundaries/.
It produces docs/geospatial_demo.png and backend/data/samples/geospatial_demo_route.geojson.
"""
from __future__ import annotations

import json
from pathlib import Path
import sys

_TESTS_DIR = Path(__file__).resolve().parent
_BACKEND_DIR = _TESTS_DIR.parent
_REPO_DIR = _BACKEND_DIR.parent

if str(_BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(_BACKEND_DIR))

import matplotlib.pyplot as plt
from matplotlib.patches import Polygon as MplPolygon
from shapely.geometry import Polygon

from app.geospatial.astar import astar, path_to_geojson
from app.geospatial.grid import MarineGrid, GridNode

OUTPUT_PNG = _REPO_DIR / "docs" / "geospatial_demo.png"
OUTPUT_GEOJSON = _BACKEND_DIR / "data" / "samples" / "geospatial_demo_route.geojson"


def main() -> None:
    # Small synthetic sea area: enough to see the algorithm clearly.
    min_lat, max_lat = 9.00, 9.20
    min_lon, max_lon = 79.00, 79.30
    grid = MarineGrid(min_lat, max_lat, min_lon, max_lon, resolution_deg=0.01)

    # Synthetic land/coastline and protected-area obstacle.
    land = Polygon([
        (79.00, 9.00), (79.00, 9.08), (79.12, 9.08),
        (79.14, 9.12), (79.12, 9.20), (79.00, 9.20)
    ])
    mpa = Polygon([
        (79.16, 9.07), (79.24, 9.07), (79.24, 9.15),
        (79.16, 9.15)
    ])

    grid.rasterize_obstacles(land, mpa)

    start = grid.coord_to_node(9.17, 79.15)
    goal = grid.coord_to_node(9.04, 79.27)
    path = astar(grid, start, goal)

    route_geojson = path_to_geojson(grid, path)
    OUTPUT_GEOJSON.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_GEOJSON.write_text(json.dumps(route_geojson, indent=2), encoding="utf-8")

    fig, ax = plt.subplots(figsize=(10, 7))

    # Draw every grid point lightly; blocked cells are overlaid below.
    xs, ys = [], []
    for row in range(grid.rows):
        for col in range(grid.cols):
            lat, lon = grid.node_to_coord(GridNode(row, col))
            xs.append(lon)
            ys.append(lat)
    ax.scatter(xs, ys, s=5, alpha=0.15, label="0.01° grid")

    blocked_x, blocked_y = [], []
    for node in grid.blocked:
        lat, lon = grid.node_to_coord(node)
        blocked_x.append(lon)
        blocked_y.append(lat)
    ax.scatter(blocked_x, blocked_y, s=20, marker="s", alpha=0.55, label="Blocked cells")

    # Draw the synthetic source polygons.
    for polygon, label in [(land, "Synthetic coastline/land"), (mpa, "Synthetic MPA")]:
        x, y = polygon.exterior.xy
        ax.plot(x, y, linewidth=2, label=label)
        ax.add_patch(MplPolygon(list(zip(x, y)), closed=True, alpha=0.12))

    route_coords = route_geojson["geometry"]["coordinates"]
    route_x = [p[0] for p in route_coords]
    route_y = [p[1] for p in route_coords]
    ax.plot(route_x, route_y, linewidth=3, label="A* route")

    start_lat, start_lon = grid.node_to_coord(start)
    goal_lat, goal_lon = grid.node_to_coord(goal)
    ax.scatter([start_lon], [start_lat], s=100, marker="o", label="Start")
    ax.scatter([goal_lon], [goal_lat], s=100, marker="X", label="Goal")
    ax.annotate("Start", (start_lon, start_lat), xytext=(6, 8), textcoords="offset points")
    ax.annotate("Goal", (goal_lon, goal_lat), xytext=(6, 8), textcoords="offset points")

    ax.set_title(f"ORCA Dev 1 — Day 2 A* Geospatial Demo ({len(path)} waypoints)")
    ax.set_xlabel("Longitude")
    ax.set_ylabel("Latitude")
    ax.grid(alpha=0.2)
    ax.legend(loc="best")
    fig.tight_layout()
    OUTPUT_PNG.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(OUTPUT_PNG, dpi=160)

    if "--no-show" in sys.argv or "-n" in sys.argv:
        plt.close(fig)
    else:
        plt.show()

    print(f"Route found: {len(path)} grid nodes")
    print(f"PNG saved to: {OUTPUT_PNG.resolve()}")
    print(f"GeoJSON saved to: {OUTPUT_GEOJSON.resolve()}")


if __name__ == "__main__":
    main()
