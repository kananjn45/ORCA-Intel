"""Loading and validating ORCA coastline / IMBL / MPA GIS datasets."""
from __future__ import annotations

from pathlib import Path
from typing import Dict

import geopandas as gpd

WGS84 = "EPSG:4326"


def load_vector(path: str | Path, *, layer: str | None = None) -> gpd.GeoDataFrame:
    """Load a vector dataset and normalize it to WGS84."""
    path = Path(path)
    if not path.exists():
        raise FileNotFoundError(f"GIS dataset not found: {path}")
    if path.stat().st_size == 0:
        raise ValueError(f"GIS dataset is empty: {path}")
    gdf = gpd.read_file(path, layer=layer) if layer else gpd.read_file(path)
    if gdf.empty:
        raise ValueError(f"GIS dataset contains no features: {path}")
    if gdf.crs is None:
        raise ValueError(f"GIS dataset has no CRS: {path}")
    return gdf.to_crs(WGS84)


def load_boundary_layers(data_dir: str | Path) -> Dict[str, gpd.GeoDataFrame]:
    """Load the standard ORCA boundary layers.

    Expected files are india_coastline.geojson, india_imbl.geojson and
    marine_protected_areas.geojson. Missing/empty files fail loudly instead of
    silently producing unsafe navigation results.
    """
    root = Path(data_dir)
    return {
        "coastline": load_vector(root / "india_coastline.geojson"),
        "imbl": load_vector(root / "india_imbl.geojson"),
        "mpa": load_vector(root / "marine_protected_areas.geojson"),
    }
