import os
import json
import random
import time
import sqlite3
from typing import Optional
from fastapi import APIRouter, HTTPException, Header, UploadFile, File, Form, Body
from config import WORKFLOW_FILE, I2I_WORKFLOW_FILE, MUSIC_WORKFLOW_FILE, DB_FILE, NSFW_WORKFLOW_FILE, UNDRESS_WORKFLOW_FILE
from comfy_client import comfy_request

router = APIRouter(prefix="/api")

@router.post("/generate/undress")
async def generate_undress(
    image: str = Form(...),
    x_user_id: str = Header(default="guest")
):
    if not os.path.exists(UNDRESS_WORKFLOW_FILE):
        raise HTTPException(status_code=500, detail="Undress Workflow missing")
    
    with open(UNDRESS_WORKFLOW_FILE, "r", encoding="utf-8") as f:
        workflow = json.load(f)
    
    # EXACTLY ONE MODIFICATION: The input image filename
    if "8" in workflow:
        workflow["8"]["inputs"]["image"] = image
    
    # Seed is fixed in the JSON (17771612868412)
    final_seed = workflow.get("20", {}).get("inputs", {}).get("seed", 0)

    res = await comfy_request("POST", "/prompt", json_data={"prompt": workflow})
    if not res: raise HTTPException(status_code=500, detail="ComfyUI rejected task")
    
    pid = res["prompt_id"]
    params = json.dumps({"mode": "UNDRESS", "seed": final_seed, "image": image})
    conn = sqlite3.connect(DB_FILE)
    conn.execute("INSERT INTO jobs (prompt_id, prompt, status, timestamp, params, images, user_id, type) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                 (pid, "一键脱衣", "queued", time.time(), params, "[]", x_user_id.lower(), "image"))
    conn.commit()
    conn.close()
    return {"prompt_id": pid}

@router.post("/generate/nsfw")
async def generate_nsfw(
    image: str = Form(...),
    x_user_id: str = Header(default="guest")
):
    if not os.path.exists(NSFW_WORKFLOW_FILE):
        raise HTTPException(status_code=500, detail="NSFW Workflow missing")
    
    with open(NSFW_WORKFLOW_FILE, "r", encoding="utf-8") as f:
        workflow = json.load(f)
    
    # Mapping based on nsfw_image_edit.json structure
    # Node 8 is LoadImage
    if "8" in workflow: workflow["8"]["inputs"]["image"] = image
    
    # Get the seed from the workflow itself for database logging
    # Do NOT override the workflow's seed here
    final_seed = workflow["20"]["inputs"].get("seed", 0) if "20" in workflow else 0

    res = await comfy_request("POST", "/prompt", json_data={"prompt": workflow})
    if not res: raise HTTPException(status_code=500, detail="ComfyUI rejected task")
    
    pid = res["prompt_id"]
    params = json.dumps({"mode": "NSFW", "seed": final_seed, "image": image})
    conn = sqlite3.connect(DB_FILE)
    conn.execute("INSERT INTO jobs (prompt_id, prompt, status, timestamp, params, images, user_id, type) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                 (pid, "Remove clothing", "queued", time.time(), params, "[]", x_user_id.lower(), "image"))
    conn.commit()
    conn.close()
    return {"prompt_id": pid}

@router.post("/upload")
async def upload_image(file: UploadFile = File(...)):
    files = {"image": (file.filename, await file.read(), file.content_type)}
    res = await comfy_request("POST", "/upload/image", files=files, data={"overwrite": "true"})
    if res:
        return {"filename": res["name"]}
    raise HTTPException(status_code=500, detail="Upload failed")

@router.post("/generate/edit")
async def generate_edit(
    prompt: str = Form(...),
    image: str = Form(...),
    denoise: float = Form(1.0),
    steps: int = Form(4),
    seed: Optional[int] = Form(None),
    x_user_id: str = Header(default="guest")
):
    if not os.path.exists(I2I_WORKFLOW_FILE):
        raise HTTPException(status_code=500, detail="I2I Workflow missing")
    
    with open(I2I_WORKFLOW_FILE, "r", encoding="utf-8") as f:
        workflow = json.load(f)
    if "6" in workflow: workflow["6"]["inputs"]["text"] = prompt
    if "198" in workflow: workflow["198"]["inputs"]["image"] = image
    final_seed = seed or random.randint(1, 2**32 - 1)
    if "163" in workflow:
        workflow["163"]["inputs"]["seed"] = final_seed
        workflow["163"]["inputs"]["steps"] = steps
        workflow["163"]["inputs"]["denoise"] = denoise

    res = await comfy_request("POST", "/prompt", json_data={"prompt": workflow})
    if not res: raise HTTPException(status_code=500, detail="ComfyUI rejected task")
    pid = res["prompt_id"]
    params = json.dumps({"mode": "I2I", "seed": final_seed, "denoise": denoise, "image": image})
    conn = sqlite3.connect(DB_FILE)
    conn.execute("INSERT INTO jobs (prompt_id, prompt, status, timestamp, params, images, user_id, type) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                 (pid, prompt, "queued", time.time(), params, "[]", x_user_id.lower(), "image"))
    conn.commit()
    conn.close()
    return {"prompt_id": pid}

@router.post("/generate")
async def generate_image(req: dict = Body(...), x_user_id: str = Header(default="guest")):
    try:
        if not os.path.exists(WORKFLOW_FILE):
            raise HTTPException(status_code=500, detail="Workflow file missing")
        with open(WORKFLOW_FILE, "r", encoding="utf-8") as f:
            workflow = json.load(f)
        
        prompt = req.get("prompt", "")
        steps = req.get("steps", 8)
        cfg = req.get("cfg", 1.0)
        seed = req.get("seed") or random.randint(1, 2**32 - 1)
        sampler = req.get("sampler_name", "res_multistep")
        width = req.get("width", 1024)
        height = req.get("height", 1024)

        if "27" in workflow: workflow["27"]["inputs"]["text"] = prompt
        if "3" in workflow:
            workflow["3"]["inputs"]["seed"] = seed
            workflow["3"]["inputs"]["steps"] = steps
            workflow["3"]["inputs"]["cfg"] = cfg
            workflow["3"]["inputs"]["sampler_name"] = sampler
        if "13" in workflow:
            workflow["13"]["inputs"]["width"] = width
            workflow["13"]["inputs"]["height"] = height

        print(f"Workflow mapping done. Sending to ComfyUI...")
        res = await comfy_request("POST", "/prompt", json_data={"prompt": workflow})
        if not res or "prompt_id" not in res:
            print(f"ComfyUI Response Error: {res}")
            raise HTTPException(status_code=500, detail="ComfyUI rejected task or returned invalid response")
        
        pid = res["prompt_id"]
        print(f"Task accepted: {pid}")
        params = json.dumps({"seed": seed, "steps": steps, "cfg": cfg, "sampler": sampler, "width": width, "height": height})
        conn = sqlite3.connect(DB_FILE)
        conn.execute("INSERT INTO jobs (prompt_id, prompt, status, timestamp, params, images, user_id, type) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                     (pid, prompt, "queued", time.time(), params, "[]", x_user_id.lower(), "image"))
        conn.commit()
        conn.close()
        return {"prompt_id": pid}
    except Exception as e:
        print(f"Generate Error: {str(e)}")
        if isinstance(e, HTTPException): raise e
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/generate/music")
async def generate_music(req: dict = Body(...), x_user_id: str = Header(default="guest")):
    try:
        if not os.path.exists(MUSIC_WORKFLOW_FILE):
            raise HTTPException(status_code=500, detail="Music workflow file missing")
        with open(MUSIC_WORKFLOW_FILE, "r", encoding="utf-8") as f:
            workflow = json.load(f)
            
        prompt = req.get("prompt", "")
        lyrics = req.get("lyrics", "")
        seed = req.get("seed") or random.randint(1, 2**32 - 1)
        bpm = req.get("bpm", 120)
        duration = req.get("duration", 60)
        
        if "94" in workflow:
            workflow["94"]["inputs"]["tags"] = prompt
            workflow["94"]["inputs"]["lyrics"] = lyrics
            workflow["94"]["inputs"]["seed"] = seed
            workflow["94"]["inputs"]["bpm"] = bpm
            workflow["94"]["inputs"]["duration"] = duration
            
        print(f"Music Workflow mapping done. Sending to ComfyUI...")
        res = await comfy_request("POST", "/prompt", json_data={"prompt": workflow})
        if not res or "prompt_id" not in res:
            print(f"ComfyUI Response Error (Music): {res}")
            raise HTTPException(status_code=500, detail="ComfyUI rejected music task")
            
        pid = res["prompt_id"]
        print(f"Music Task accepted: {pid}")
        params = json.dumps({"seed": seed, "bpm": bpm, "duration": duration})
        conn = sqlite3.connect(DB_FILE)
        conn.execute("INSERT INTO jobs (prompt_id, prompt, status, timestamp, params, images, user_id, type) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                     (pid, prompt, "queued", time.time(), params, "[]", x_user_id.lower(), "music"))
        conn.commit()
        conn.close()
        return {"prompt_id": pid}
    except Exception as e:
        print(f"Generate Music Error: {str(e)}")
        if isinstance(e, HTTPException): raise e
        raise HTTPException(status_code=500, detail=str(e))
