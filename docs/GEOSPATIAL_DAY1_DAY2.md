# Dev 1 — Geospatial Day 1 & Day 2

## Scope

This implementation covers the independent Dev 1 foundation from the ORCA implementation plan:

- Day 1: GIS loading/validation, WGS84 normalization, Haversine/geodesic math, boundary proximity, point-in-polygon and lookahead primitives.
- Day 2: 0.01° marine grid, obstacle rasterization, A* route generation, and GeoJSON route output.

The engine is deliberately independent of Dev 2/3. It consumes local vector data and plain Python arguments, so the team can integrate it later through stable contracts.

## Data/API boundary

No live geospatial routing API is required for Day 1/2. The project specification calls for coastline/IMBL/MPA vector datasets and GeoPandas/Shapely processing. `GeoPandas.read_file()` supports local files and URLs, but this module intentionally fails on empty/missing datasets instead of inventing boundaries.

Expected files:

```text
backend/data/boundaries/
├── india_coastline.geojson
├── india_imbl.geojson
└── marine_protected_areas.geojson
```

The repository currently contains placeholder empty files, so replace them with the real datasets before running the loader.

## Install

From `backend/`:

```bash
python -m venv .venv
# macOS/Linux
source .venv/bin/activate
# Windows PowerShell
# .venv\Scripts\Activate.ps1

pip install -r requirements-geospatial.txt
```

If the team's main `requirements.txt` is later populated, merge these dependencies there rather than installing a second environment.

## Test

From `backend/`:

```bash
pytest -q tests/test_geospatial.py
```

Expected result: all tests pass.

The tests use synthetic polygons, so they do **not** require the real India datasets.

## Quick manual test

```python
from shapely.geometry import Polygon
from app.geospatial import MarineGrid, astar, calculate_lookahead

boundary = Polygon([(80.02, 9.8), (80.03, 9.8), (80.03, 10.2), (80.02, 10.2)])
result = calculate_lookahead(10, 80, 10, 90, boundary)
print(result.to_dict())

# Build a small route grid and block a vertical strip.
grid = MarineGrid(0, 0.1, 0, 0.1, 0.01)
grid.rasterize_obstacles(Polygon([(0.04, 0.04), (0.06, 0.04), (0.06, 0.06), (0.04, 0.06)]))
start = grid.coord_to_node(0.05, 0.01)
goal = grid.coord_to_node(0.05, 0.09)
path = astar(grid, start, goal)
print(path)
```

## Integration contract for Day 3

Dev 1 should expose these primitives to the other developers:

- `load_boundary_layers(data_dir)` → GeoDataFrames for coastline, IMBL and MPA.
- `boundary_proximity_km(lat, lon, geometry)` → numeric km distance.
- `point_inside(lat, lon, polygon)` → boolean.
- `calculate_lookahead(...)` → start/end/distance/bearing/intersection result.
- `MarineGrid(...)` + `rasterize_obstacles(...)` → blocked grid.
- `astar(...)` → ordered grid nodes.
- `path_to_geojson(...)` → GeoJSON Feature containing the route LineString.

For the safety-critical IMBL rule, downstream guardrails should use the distance result and independently reject routes that intersect prohibited polygons/buffers.

## Visual demo

From the `backend/` directory, after installing `requirements-geospatial.txt`:

```bash
python demo_geospatial.py
```

The demo deliberately uses small synthetic land and MPA polygons so it works before the approved production datasets are supplied. It:

1. Builds a 0.01-degree marine grid.
2. Rasterizes the synthetic land and MPA as blocked cells.
3. Runs A* from a start point to a goal point.
4. Displays the grid, blocked cells, obstacles, start, goal, and calculated route.
5. Writes `geospatial_demo.png` and `geospatial_demo_route.geojson` in `backend/`.

The visual demo is for development/testing only; it is not a map of the real India/Sri Lanka maritime boundary.
