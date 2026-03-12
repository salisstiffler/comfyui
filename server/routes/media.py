import httpx
from fastapi import APIRouter, HTTPException
from fastapi.responses import Response

from config import COMFYUI_SERVER

router = APIRouter(prefix="/api")

@router.get("/image/{filename:path}")
async def get_image(filename: str):
    p = filename.rsplit('/', 1); sub = p[0] if len(p)>1 else ""
    url = f"http://{COMFYUI_SERVER}/view?filename={p[-1]}&subfolder={sub}&type=output"
    async with httpx.AsyncClient() as c:
        r = await c.get(url)
        if r.status_code == 200: return Response(content=r.content, media_type="image/png")
    raise HTTPException(status_code=404)

@router.get("/audio/{filename:path}")
async def get_audio(filename: str):
    p = filename.rsplit('/', 1); sub = p[0] if len(p)>1 else ""
    url = f"http://{COMFYUI_SERVER}/view?filename={p[-1]}&subfolder={sub}&type=output"
    async with httpx.AsyncClient() as c:
        r = await c.get(url)
        if r.status_code == 200: return Response(content=r.content, media_type="audio/mpeg")
    raise HTTPException(status_code=404)
