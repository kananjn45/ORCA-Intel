import asyncio
from datetime import datetime, timedelta
from typing import List, Dict, Any

try:
    from app.agents.state import AgentState
    from app.services.incois_pfz import get_pfz_features
    from app.geospatial.distance import haversine_km, initial_bearing_deg
except ImportError:
    from app.agents.state import AgentState
    from app.services.incois_pfz import get_pfz_features
    from app.geospatial.distance import haversine_km, initial_bearing_deg


def pfz_agent_node(state: AgentState) -> AgentState:
    """
    Extracts high-yield Potential Fishing Zones (PFZs) based on chlorophyll and SST fronts.
    Powered by Dev 3's INCOIS advisory service and satellite feature loader.
    Populates state['pfz_features'] and sets state['target_destination'].
    """
    vessel_lat = state.get("vessel_lat", 9.28)
    vessel_lon = state.get("vessel_lon", 79.31)

    features_out: List[Dict[str, Any]] = []

    try:
        try:
            loop = asyncio.get_event_loop()
        except RuntimeError:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)

        if loop.is_running():
            import concurrent.futures
            with concurrent.futures.ThreadPoolExecutor() as pool:
                pfz_list = pool.submit(asyncio.run, get_pfz_features(vessel_lat, vessel_lon, radius_km=50.0)).result()
        else:
            pfz_list = loop.run_until_complete(get_pfz_features(vessel_lat, vessel_lon, radius_km=50.0))

        for item in pfz_list:
            dist = round(haversine_km(vessel_lat, vessel_lon, item.centroid["lat"], item.centroid["lon"]), 2)
            bearing = round(initial_bearing_deg(vessel_lat, vessel_lon, item.centroid["lat"], item.centroid["lon"]), 1)
            features_out.append({
                "pfz_id": item.pfz_id,
                "sector_name": item.sector_name,
                "centroid": item.centroid,
                "distance_km": dist,
                "bearing_deg": bearing,
                "chlorophyll_mg_m3": item.chlorophyll_mg_m3,
                "sst_gradient_celsius": item.sst_gradient_celsius,
                "depth_m": item.depth_m,
                "valid_until": item.valid_until.isoformat() if hasattr(item.valid_until, "isoformat") else str(item.valid_until),
                "geojson_geometry": item.geojson_geometry,
                "source": item.source,
            })
    except Exception:
        # Fallback to rich Palk Bay / Gulf of Mannar sample zones
        features_out = [
            {
                "pfz_id": "PFZ-TN-2026-04",
                "sector_name": "Palk Bay East Front",
                "centroid": {"lat": 9.42, "lon": 79.55},
                "distance_km": 14.2,
                "bearing_deg": 65.0,
                "chlorophyll_mg_m3": 1.45,
                "sst_gradient_celsius": 0.85,
                "depth_m": 22.0,
                "valid_until": (datetime.utcnow() + timedelta(hours=18)).isoformat(),
                "geojson_geometry": {
                    "type": "Polygon",
                    "coordinates": [[[79.48, 9.38], [79.56, 9.38], [79.56, 9.46], [79.48, 9.46], [79.48, 9.38]]]
                },
                "source": "INCOIS-Fallback"
            }
        ]

    # Rank candidate zones: highest chlorophyll first
    features_out.sort(key=lambda x: x["chlorophyll_mg_m3"], reverse=True)
    state["pfz_features"] = features_out

    # Set the top-ranked zone as default target destination if none requested
    if not state.get("target_destination") and features_out:
        state["target_destination"] = features_out[0]["centroid"]

    return state
