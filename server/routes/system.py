from fastapi import APIRouter
from comfy_client import comfy_request

router = APIRouter(prefix="/api")

@router.get("/health")
async def health():
    stats = await comfy_request("GET", "/system_stats")
    if stats:
        return {
            "status": "online",
            "devices": stats.get("devices", []),
            "vram": stats.get("vram", {}),
            "ram": stats.get("ram", {})
        }
    return {"status": "offline"}
