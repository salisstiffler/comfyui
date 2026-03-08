import os
import json
import random
import httpx
import sqlite3
import time
from typing import Optional, List
from fastapi import FastAPI, HTTPException, Header
from fastapi.responses import Response, FileResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import asyncio

app = FastAPI(title="ComfyUI AI Tool API")

# Allow CORS for Flutter client
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

COMFYUI_SERVER = os.environ.get("COMFYUI_SERVER", "host.docker.internal:8188")
WORKFLOW_FILE = os.path.join(os.path.dirname(__file__), "workflow_api.json")
MUSIC_WORKFLOW_FILE = os.path.join(os.path.dirname(__file__), "music_workflow.json")
DB_FILE = os.path.join(os.path.dirname(__file__), "jobs.db")

# Initialize DB
def init_db():
    conn = sqlite3.connect(DB_FILE)
    c = conn.cursor()
    # Ensure table exists first
    c.execute('''CREATE TABLE IF NOT EXISTS jobs
                 (prompt_id TEXT PRIMARY KEY, prompt TEXT, status TEXT, 
                  timestamp REAL, params TEXT, images TEXT, user_id TEXT, 
                  completed_at REAL, type TEXT DEFAULT 'image', audio_files TEXT DEFAULT '[]')''')
    
    # Migration: Check for columns
    cursor = c.execute("PRAGMA table_info(jobs)")
    columns = [row[1] for row in cursor.fetchall()]
    
    if "user_id" not in columns:
        c.execute("ALTER TABLE jobs ADD COLUMN user_id TEXT DEFAULT 'guest'")
    if "completed_at" not in columns:
        c.execute("ALTER TABLE jobs ADD COLUMN completed_at REAL")
    if "type" not in columns:
        c.execute("ALTER TABLE jobs ADD COLUMN type TEXT DEFAULT 'image'")
    if "audio_files" not in columns:
        c.execute("ALTER TABLE jobs ADD COLUMN audio_files TEXT DEFAULT '[]'")
        
    conn.commit()
    conn.close()

init_db()

class GenerateRequest(BaseModel):
    prompt: str
    steps: Optional[int] = 8
    cfg: Optional[float] = 1.0
    seed: Optional[int] = None
    sampler_name: Optional[str] = "res_multistep"
    batch_size: Optional[int] = 1
    width: Optional[int] = 1024
    height: Optional[int] = 1024

class MusicGenerateRequest(BaseModel):
    tags: str
    lyrics: str
    bpm: int = 190
    duration: int = 120
    seed: Optional[int] = None
    steps: int = 8
    cfg: float = 2.0

async def comfy_request(method: str, path: str, json_data: dict = None, params: dict = None):
    url = f"http://{COMFYUI_SERVER}{path}"
    async with httpx.AsyncClient(timeout=15.0) as client: # Increased timeout for audio
        try:
            if method.upper() == "GET":
                response = await client.get(url, params=params)
            elif method.upper() == "POST":
                response = await client.post(url, json=json_data)
            elif method.upper() == "DELETE":
                response = await client.delete(url, params=params)
            else:
                raise ValueError(f"Unsupported method: {method}")

            response.raise_for_status()
            return response.json() if response.status_code != 204 else None
        except (httpx.ConnectError, httpx.TimeoutException):
            raise HTTPException(
                status_code=503, 
                detail={"error": "ENGINE_OFFLINE", "message": "ComfyUI is not responding. Please wake the engine."}
            )
        except httpx.HTTPStatusError as e:
            raise HTTPException(status_code=e.response.status_code, detail=f"ComfyUI returned error: {e.response.text}")
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Unexpected error: {str(e)}")

@app.post("/api/generate")
async def generate_image(req: GenerateRequest, x_user_id: str = Header("guest")):
    x_user_id = x_user_id.lower()
    if not os.path.exists(WORKFLOW_FILE):
        raise HTTPException(status_code=500, detail="Workflow file not found")
        
    with open(WORKFLOW_FILE, "r", encoding="utf-8") as f:
        workflow = json.load(f)
        
    if "27" in workflow: workflow["27"]["inputs"]["text"] = req.prompt
    seed_val = req.seed if req.seed is not None else random.randint(1, 2**63 - 1)
    if "3" in workflow:
        workflow["3"]["inputs"]["seed"] = seed_val
        workflow["3"]["inputs"]["steps"] = req.steps
        workflow["3"]["inputs"]["cfg"] = req.cfg
        workflow["3"]["inputs"]["sampler_name"] = req.sampler_name
    if "13" in workflow:
        workflow["13"]["inputs"]["width"] = req.width
        workflow["13"]["inputs"]["height"] = req.height
        workflow["13"]["inputs"]["batch_size"] = req.batch_size
        
    result = await comfy_request("POST", "/prompt", json_data={"prompt": workflow})
    pid = result["prompt_id"]
    
    params_json = json.dumps({"steps": req.steps, "cfg": req.cfg, "seed": seed_val, "width": req.width, "height": req.height})
    conn = sqlite3.connect(DB_FILE)
    c = conn.cursor()
    c.execute("INSERT INTO jobs (prompt_id, prompt, status, timestamp, params, images, user_id, type) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
              (pid, req.prompt, "queued", time.time(), params_json, "[]", x_user_id, "image"))
    conn.commit()
    conn.close()
    return {"prompt_id": pid, "status": "queued"}

@app.post("/api/generate/music")
async def generate_music(req: MusicGenerateRequest, x_user_id: str = Header("guest")):
    x_user_id = x_user_id.lower()
    if not os.path.exists(MUSIC_WORKFLOW_FILE):
        raise HTTPException(status_code=500, detail=f"Music workflow not found at {MUSIC_WORKFLOW_FILE}")
        
    with open(MUSIC_WORKFLOW_FILE, "r", encoding="utf-8") as f:
        workflow = json.load(f)
        
    seed_val = req.seed if req.seed is not None else random.randint(1, 2**32 - 1)
    
    # Node 94: TextEncodeAceStepAudio1.5
    if "94" in workflow:
        workflow["94"]["inputs"]["tags"] = req.tags
        workflow["94"]["inputs"]["lyrics"] = req.lyrics
        workflow["94"]["inputs"]["bpm"] = req.bpm
        workflow["94"]["inputs"]["duration"] = req.duration
        workflow["94"]["inputs"]["seed"] = seed_val
        workflow["94"]["inputs"]["cfg_scale"] = req.cfg  # Critical guidance scale
    
    # Node 98: Empty Ace Step 1.5 Latent Audio
    if "98" in workflow: workflow["98"]["inputs"]["seconds"] = req.duration
    
    # Node 3: KSampler
    if "3" in workflow:
        workflow["3"]["inputs"]["steps"] = req.steps
        workflow["3"]["inputs"]["seed"] = seed_val
        workflow["3"]["inputs"]["cfg"] = 1.0  # Sampler CFG must be 1.0 for this model

    result = await comfy_request("POST", "/prompt", json_data={"prompt": workflow})
    pid = result["prompt_id"]
    
    params_json = json.dumps({"tags": req.tags, "bpm": req.bpm, "duration": req.duration, "seed": seed_val})
    conn = sqlite3.connect(DB_FILE)
    c = conn.cursor()
    c.execute("INSERT INTO jobs (prompt_id, prompt, status, timestamp, params, images, audio_files, user_id, type) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
              (pid, req.tags[:100], "queued", time.time(), params_json, "[]", "[]", x_user_id, "music"))
    conn.commit()
    conn.close()
    return {"prompt_id": pid, "status": "queued"}

@app.get("/api/jobs")
async def get_jobs(x_user_id: str = Header("guest")):
    x_user_id = x_user_id.lower()
    conn = sqlite3.connect(DB_FILE)
    conn.row_factory = sqlite3.Row
    c = conn.cursor()
    c.execute("SELECT * FROM jobs WHERE user_id=? ORDER BY timestamp DESC LIMIT 50", (x_user_id,))
    rows = c.fetchall()
    conn.close()
    
    return [{
        "prompt_id": r["prompt_id"], "prompt": r["prompt"], "status": r["status"],
        "timestamp": r["timestamp"], "completed_at": r["completed_at"],
        "params": json.loads(r["params"]), "images": json.loads(r["images"]),
        "audio_files": json.loads(r["audio_files"]) if "audio_files" in r.keys() else [],
        "type": r["type"] if "type" in r.keys() else "image"
    } for r in rows]

@app.get("/api/status/{prompt_id}")
async def get_status(prompt_id: str):
    conn = sqlite3.connect(DB_FILE)
    c = conn.cursor()
    c.execute("SELECT status, images, audio_files, completed_at, type FROM jobs WHERE prompt_id=?", (prompt_id,))
    row = c.fetchone()
    conn.close()
    
    if row and row[0] == "completed":
        return {"status": "completed", "images": json.loads(row[1]), "audio_files": json.loads(row[2]), "completed_at": row[3], "type": row[4]}

    try:
        history = await comfy_request("GET", f"/history/{prompt_id}")
        if prompt_id in history:
            task_data = history[prompt_id]
            outputs = task_data.get("outputs", {})
            images = []
            audio_files = []
            for node_id, node_output in outputs.items():
                if "images" in node_output:
                    for img in node_output["images"]:
                        fname = img["filename"]
                        if img.get("subfolder"):
                            fname = f"{img['subfolder']}/{fname}"
                        images.append(fname)
                if "audio" in node_output:
                    for aud in node_output["audio"]:
                        fname = aud["filename"]
                        if aud.get("subfolder"):
                            fname = f"{aud['subfolder']}/{fname}"
                        audio_files.append(fname)
            
            comp_time = time.time()
            conn = sqlite3.connect(DB_FILE)
            c = conn.cursor()
            c.execute("UPDATE jobs SET status=?, images=?, audio_files=?, completed_at=? WHERE prompt_id=?", 
                      ("completed", json.dumps(images), json.dumps(audio_files), comp_time, prompt_id))
            conn.commit()
            conn.close()
            return {"status": "completed", "images": images, "audio_files": audio_files, "completed_at": comp_time}
    except: pass

    queue_data = await comfy_request("GET", "/queue")
    for q in queue_data.get("queue_running", []):
        if q[1] == prompt_id:
            conn = sqlite3.connect(DB_FILE); c = conn.cursor()
            c.execute("UPDATE jobs SET status=? WHERE prompt_id=?", ("running", prompt_id))
            conn.commit(); conn.close()
            return {"status": "running", "progress": 0.5}
    for q in queue_data.get("queue_pending", []):
        if q[1] == prompt_id: return {"status": "pending"}
    return {"status": "unknown"}

@app.get("/api/audio/{filename:path}")
async def get_audio(filename: str):
    url = f"http://{COMFYUI_SERVER}/view"
    
    # Split subfolder if present
    subfolder = ""
    if "/" in filename:
        parts = filename.rsplit("/", 1)
        subfolder = parts[0]
        base_name = parts[1]
    else:
        base_name = filename
        
    params = {"filename": base_name, "subfolder": subfolder, "type": "output"}
    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(url, params=params)
            if response.status_code != 200:
                print(f"FAILED to fetch audio from ComfyUI: {response.status_code} - {response.text}")
            response.raise_for_status()
            return Response(content=response.content, media_type="audio/mpeg")
        except Exception as e:
            print(f"AUDIO_PROXY_ERROR: {str(e)}")
            raise HTTPException(status_code=500, detail=f"Failed to fetch audio: {str(e)}")

@app.get("/api/image/{filename:path}")
async def get_image(filename: str):
    url = f"http://{COMFYUI_SERVER}/view"
    
    # Split subfolder if present
    subfolder = ""
    if "/" in filename:
        parts = filename.rsplit("/", 1)
        subfolder = parts[0]
        base_name = parts[1]
    else:
        base_name = filename
        
    params = {"filename": base_name, "subfolder": subfolder, "type": "output"}
    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(url, params=params)
            response.raise_for_status()
            return Response(content=response.content, media_type="image/png")
        except Exception as e:
            print(f"IMAGE_PROXY_ERROR: {str(e)}")
            raise HTTPException(status_code=500, detail=f"Failed to fetch image: {str(e)}")

@app.delete("/api/queue/{prompt_id}")
async def cancel_task(prompt_id: str):
    await comfy_request("POST", "/interrupt")
    async with httpx.AsyncClient() as client:
        await client.post(f"http://{COMFYUI_SERVER}/queue", json={"delete": [prompt_id]})
    conn = sqlite3.connect(DB_FILE); c = conn.cursor()
    c.execute("UPDATE jobs SET status=? WHERE prompt_id=?", ("cancelled", prompt_id))
    conn.commit(); conn.close()
    return {"status": "cancelled", "prompt_id": prompt_id}

@app.get("/api/health")
async def health_check():
    try:
        await comfy_request("GET", "/queue")
        return {"status": "online", "engine": "ComfyUI"}
    except: raise HTTPException(status_code=503, detail="ComfyUI Core is offline")

@app.post("/api/wake")
async def wake_engine():
    async with httpx.AsyncClient(timeout=5.0) as client:
        try:
            response = await client.post(f"{HOST_BRIDGE_URL}/launch")
            return response.json()
        except: raise HTTPException(status_code=503, detail="Host bridge not responding")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
