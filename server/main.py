import os
import json
import random
import httpx
import sqlite3
import time
from typing import Optional, List
from fastapi import FastAPI, HTTPException, Header
from fastapi.responses import Response, FileResponse
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

COMFYUI_SERVER = os.environ.get("COMFYUI_SERVER", "host.docker.internal:8188")
WORKFLOW_FILE = os.path.join(os.path.dirname(__file__), "workflow_api.json")
MUSIC_WORKFLOW_FILE = os.path.join(os.path.dirname(__file__), "music_workflow.json")
MUSIC_WORKFLOW2_FILE = os.path.join(os.path.dirname(__file__), "music_workflow2.json")
DB_FILE = os.path.join(os.path.dirname(__file__), "jobs.db")

def init_db():
    conn = sqlite3.connect(DB_FILE)
    c = conn.cursor()
    c.execute('''CREATE TABLE IF NOT EXISTS jobs
                 (prompt_id TEXT PRIMARY KEY, prompt TEXT, status TEXT, 
                  timestamp REAL, params TEXT, images TEXT, user_id TEXT, 
                  completed_at REAL, type TEXT DEFAULT 'image', audio_files TEXT DEFAULT '[]')''')
    conn.commit()
    conn.close()

init_db()

class MusicGenerateRequest(BaseModel):
    tags: Optional[str] = None
    lyrics: Optional[str] = None
    prompt: Optional[str] = None
    bpm: int = 190
    duration: int = 120
    seed: Optional[int] = None

class GenerateRequest(BaseModel):
    prompt: str
    steps: Optional[int] = 8
    cfg: Optional[float] = 1.0
    seed: Optional[int] = None

async def comfy_request(method: str, path: str, json_data: dict = None):
    url = f"http://{COMFYUI_SERVER}{path}"
    async with httpx.AsyncClient(timeout=60.0) as client:
        try:
            if method.upper() == "GET": response = await client.get(url)
            else: response = await client.post(url, json=json_data)
            if response.status_code == 204 or not response.content: return None
            response.raise_for_status()
            return response.json()
        except Exception as e:
            print(f"Comfy Error: {str(e)}")
            return None

def update_db_status(prompt_id, status, images=None, audio=None):
    conn = sqlite3.connect(DB_FILE)
    c = conn.cursor()
    if status in ["completed", "failed"]:
        c.execute("UPDATE jobs SET status = ?, images = ?, audio_files = ?, completed_at = ? WHERE prompt_id = ?",
                  (status, json.dumps(images or []), json.dumps(audio or []), time.time(), prompt_id))
    else:
        c.execute("UPDATE jobs SET status = ? WHERE prompt_id = ?", (status, prompt_id))
    conn.commit()
    conn.close()

@app.get("/api/status/{prompt_id}")
async def get_status(prompt_id: str):
    # 1. Check History
    hist = await comfy_request("GET", f"/history/{prompt_id}")
    if hist and prompt_id in hist:
        job_data = hist[prompt_id]
        has_error = any(msg[0] == "execution_error" for msg in job_data.get("status", {}).get("messages", []))
        images, audio = [], []
        if "outputs" in job_data:
            for node_id, node_out in job_data["outputs"].items():
                if "images" in node_out:
                    images.extend([f"{i.get('subfolder','')}/{i['filename']}".lstrip('/') for i in node_out["images"]])
                if "audio" in node_out:
                    audio.extend([f"{a.get('subfolder','')}/{a['filename']}".lstrip('/') for a in node_out["audio"]])
        
        final_status = "completed" if (not has_error and (images or audio)) else "failed"
        update_db_status(prompt_id, final_status, images, audio)
        return {"status": final_status, "images": images, "audio_files": audio}

    # 2. Check Queue
    queue = await comfy_request("GET", "/queue")
    if queue:
        for item in queue.get("queue_running", []):
            if item[1] == prompt_id:
                update_db_status(prompt_id, "running")
                return {"status": "running", "progress": 0.5}
        for item in queue.get("queue_pending", []):
            if item[1] == prompt_id:
                update_db_status(prompt_id, "pending")
                return {"status": "pending"}

    # 3. Zombie Check
    conn = sqlite3.connect(DB_FILE)
    c = conn.cursor()
    c.execute("SELECT timestamp, status FROM jobs WHERE prompt_id = ?", (prompt_id,))
    row = c.fetchone()
    conn.close()
    if row and row[1] == "queued" and (time.time() - row[0] > 40):
        # If in DB as queued for > 40s but not in ComfyUI, mark as failed
        update_db_status(prompt_id, "failed")
        return {"status": "failed"}

    return {"status": "queued"}

@app.post("/api/generate/music")
async def generate_music(req: MusicGenerateRequest, x_user_id: str = Header(default="guest")):
    x_user_id = x_user_id.lower()
    is_simple = bool(req.prompt and not req.lyrics)
    workflow_path = MUSIC_WORKFLOW2_FILE if is_simple else MUSIC_WORKFLOW_FILE
    with open(workflow_path, "r", encoding="utf-8") as f:
        workflow = json.load(f)
    if "prompt" in workflow: workflow = workflow["prompt"]
    
    seed = req.seed or random.randint(1, 2**32 - 1)
    if is_simple:
        if "115" in workflow: workflow["115"]["inputs"]["prompt"] = req.prompt
        if "94" in workflow:
            workflow["94"]["inputs"]["bpm"] = req.bpm
            workflow["94"]["inputs"]["duration"] = req.duration
            workflow["94"]["inputs"]["seed"] = seed
    else:
        if "94" in workflow:
            workflow["94"]["inputs"]["tags"] = req.tags or ""
            workflow["94"]["inputs"]["lyrics"] = req.lyrics or ""
            workflow["94"]["inputs"]["seed"] = seed

    res = await comfy_request("POST", "/prompt", json_data={"prompt": workflow})
    if not res: raise HTTPException(status_code=500, detail="ComfyUI rejected task")
    
    pid = res["prompt_id"]
    params = json.dumps({"mode": "SIMPLE" if is_simple else "ADVANCED", "seed": seed})
    conn = sqlite3.connect(DB_FILE)
    conn.execute("INSERT INTO jobs (prompt_id, prompt, status, timestamp, params, images, audio_files, user_id, type) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                 (pid, (req.prompt or req.tags or "Music")[:100], "queued", time.time(), params, "[]", "[]", x_user_id, "music"))
    conn.commit()
    conn.close()
    return {"prompt_id": pid}

@app.post("/api/generate")
async def generate_image(req: GenerateRequest, x_user_id: str = Header(default="guest")):
    x_user_id = x_user_id.lower()
    with open(WORKFLOW_FILE, "r", encoding="utf-8") as f:
        workflow = json.load(f)
    if "prompt" in workflow: workflow = workflow["prompt"]
    seed = req.seed or random.randint(1, 2**63 - 1)
    if "27" in workflow: workflow["27"]["inputs"]["text"] = req.prompt
    if "3" in workflow: workflow["3"]["inputs"]["seed"] = seed
    res = await comfy_request("POST", "/prompt", json_data={"prompt": workflow})
    pid = res["prompt_id"]
    conn = sqlite3.connect(DB_FILE)
    conn.execute("INSERT INTO jobs (prompt_id, prompt, status, timestamp, params, images, user_id, type) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                 (pid, req.prompt, "queued", time.time(), "{}", "[]", x_user_id, "image"))
    conn.commit()
    conn.close()
    return {"prompt_id": pid}

@app.get("/api/jobs")
async def get_jobs(x_user_id: str = Header(default="guest")):
    conn = sqlite3.connect(DB_FILE); conn.row_factory = sqlite3.Row
    rows = conn.execute("SELECT * FROM jobs WHERE user_id = ? ORDER BY timestamp DESC LIMIT 50", (x_user_id.lower(),)).fetchall()
    conn.close()
    return [dict(r) for r in rows]

@app.get("/api/image/{filename:path}")
async def get_image(filename: str):
    p = filename.rsplit('/', 1); sub = p[0] if len(p)>1 else ""
    url = f"http://{COMFYUI_SERVER}/view?filename={p[-1]}&subfolder={sub}&type=output"
    async with httpx.AsyncClient() as c:
        r = await c.get(url)
        if r.status_code == 200: return Response(content=r.content, media_type="image/png")
    raise HTTPException(status_code=404)

@app.get("/api/audio/{filename:path}")
async def get_audio(filename: str):
    p = filename.rsplit('/', 1); sub = p[0] if len(p)>1 else ""
    url = f"http://{COMFYUI_SERVER}/view?filename={p[-1]}&subfolder={sub}&type=output"
    async with httpx.AsyncClient() as c:
        r = await c.get(url)
        if r.status_code == 200: return Response(content=r.content, media_type="audio/mpeg")
        # Fallback to audio/ subfolder
        r2 = await c.get(f"http://{COMFYUI_SERVER}/view?filename={p[-1]}&subfolder=audio&type=output")
        if r2.status_code == 200: return Response(content=r2.content, media_type="audio/mpeg")
    raise HTTPException(status_code=404)

@app.get("/api/health")
async def health():
    r = await comfy_request("GET", "/system_stats")
    return {"status": "online" if r else "offline"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8100)
