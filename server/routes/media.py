import httpx
from fastapi import APIRouter, HTTPException
from fastapi.responses import Response

from config import COMFYUI_SERVER

router = APIRouter(prefix="/api")

@router.get("/image/{filename:path}")
async def get_image(filename: str):
    p = filename.rsplit('/', 1); 
    sub = p[0] if len(p)>1 else ""
    fname = p[-1]
    
    # ComfyUI image type detection
    img_type = "temp" if "temp" in fname.lower() else "output"
    
    async with httpx.AsyncClient() as c:
        # Try primary type first
        url = f"http://{COMFYUI_SERVER}/view?filename={fname}&subfolder={sub}&type={img_type}"
        r = await c.get(url)
        if r.status_code == 200: 
            return Response(content=r.content, media_type="image/png")
            
        # Fallback to other type if 404
        other_type = "output" if img_type == "temp" else "temp"
        url_fb = f"http://{COMFYUI_SERVER}/view?filename={fname}&subfolder={sub}&type={other_type}"
        r_fb = await c.get(url_fb)
        if r_fb.status_code == 200:
            return Response(content=r_fb.content, media_type="image/png")

    raise HTTPException(status_code=404)

@router.get("/audio/{filename:path}")
async def get_audio(filename: str):
    p = filename.rsplit('/', 1); sub = p[0] if len(p)>1 else ""
    url = f"http://{COMFYUI_SERVER}/view?filename={p[-1]}&subfolder={sub}&type=output"
    async with httpx.AsyncClient() as c:
        r = await c.get(url)
        if r.status_code == 200: return Response(content=r.content, media_type="audio/mpeg")
    raise HTTPException(status_code=404)
