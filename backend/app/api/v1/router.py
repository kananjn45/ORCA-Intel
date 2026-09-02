from fastapi import APIRouter

from app.api.v1.endpoints import chat, geofence, marine_data, navigation, voice

api_router = APIRouter()

api_router.include_router(marine_data.router, prefix="/marine", tags=["Marine Data (Dev 3)"])
api_router.include_router(chat.router, prefix="/chat", tags=["Chat (Dev 2/4 - mocked by Dev 3)"])
api_router.include_router(navigation.router, prefix="/navigation", tags=["Navigation (Dev 1 - mocked by Dev 3)"])
api_router.include_router(geofence.router, prefix="/geofence", tags=["Geofence (Dev 1 - mocked by Dev 3)"])
api_router.include_router(voice.router, prefix="/voice", tags=["Voice (Dev 4 - mocked by Dev 3)"])