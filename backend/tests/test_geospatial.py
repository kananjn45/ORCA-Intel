import math

import pytest
from shapely.geometry import Polygon, Point

from app.geospatial.distance import haversine_km, initial_bearing_deg, destination_point, cross_track_distance_km
from app.geospatial.geofence import calculate_lookahead, lookahead_distance_km, boundary_proximity_km, point_inside
from app.geospatial.grid import MarineGrid
from app.geospatial.astar import astar, path_to_geojson


def test_haversine_one_degree_equator():
    assert 110.0 < haversine_km(0, 0, 0, 1) < 112.0


def test_bearing_north():
    assert initial_bearing_deg(0, 0, 1, 0) == pytest.approx(0, abs=0.01)


def test_destination_15_minutes_at_10_knots():
    lat, lon = destination_point(10, 80, lookahead_distance_km(10), 90)
    assert lat == pytest.approx(10, abs=0.02)
    assert lon > 80


def test_cross_track_distance():
    # Segment is along the equator; point is roughly 1 degree north.
    assert 110 < cross_track_distance_km((1, 5), (0, 0), (0, 10)) < 112


def test_point_in_polygon_is_boundary_inclusive():
    polygon = Polygon([(79, 10), (81, 10), (81, 12), (79, 12)])
    assert point_inside(11, 80, polygon)
    assert point_inside(10, 80, polygon)
    assert not point_inside(13, 80, polygon)


def test_boundary_proximity_uses_km_not_degrees():
    polygon = Polygon([(79, 10), (81, 10), (81, 12), (79, 12)])
    distance = boundary_proximity_km(13, 80, polygon)
    assert 110 < distance < 112


def test_lookahead_intersects_boundary():
    # Vertical-ish rectangle east of the vessel; eastbound track crosses it.
    boundary = Polygon([(80.02, 9.8), (80.03, 9.8), (80.03, 10.2), (80.02, 10.2)])
    result = calculate_lookahead(10, 80, 10, 90, boundary)
    assert result.intersects_boundary is True
    assert result.distance_km == pytest.approx(4.63, rel=0.01)


def test_grid_rasterization_and_astar_avoids_obstacle():
    grid = MarineGrid(0, 0.1, 0, 0.1, resolution_deg=0.01)
    obstacle = Polygon([(0.04, 0.04), (0.06, 0.04), (0.06, 0.06), (0.04, 0.06)])
    grid.rasterize_obstacles(obstacle)
    start = grid.coord_to_node(0.05, 0.01)
    goal = grid.coord_to_node(0.05, 0.09)
    path = astar(grid, start, goal)
    assert path
    assert all(not grid.is_blocked(n) for n in path)
    geojson = path_to_geojson(grid, path)
    assert geojson["geometry"]["type"] == "LineString"
