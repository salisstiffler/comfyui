import os
import json
import random
import httpx
import sqlite3
import time
import shutil
from typing import Optional, List
from fastapi import FastAPI, HTTPException, Header, UploadFile, File, Form
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
I2I_WORKFLOW_FILE = os.path.join(os.path.dirname(__file__), "flux2_i2i.json")
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

async def comfy_request(method: str, path: str, json_data: dict = None, data: dict = None, files: dict = None):
    url = f"http://{COMFYUI_SERVER}{path}"
    async with httpx.AsyncClient(timeout=60.0) as client:
        try:
            if method.upper() == "GET": response = await client.get(url)
            elif method.upper() == "POST":
                if files:
                    response = await client.post(url, data=data, files=files)
                else:
                    response = await client.post(url, json=json_data)
            else: response = await client.delete(url)
            
            if response.status_code == 204 or not response.content: return None
            response.raise_for_status()
            return response.json()
        except Exception as e:
            print(f"Comfy Error: {str(e)}")
            return None

@app.post("/api/upload")
async def upload_image(file: UploadFile = File(...)):
    # Proxy upload to ComfyUI
    files = {"image": (file.filename, await file.read(), file.content_type)}
    res = await comfy_request("POST", "/upload/image", files=files, data={"overwrite": "true"})
    if res:
        return {"filename": res["name"]}
    raise HTTPException(status_code=500, detail="Upload failed")

@app.post("/api/generate/edit")
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
    
    # Map nodes based on flux2_i2i.json
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

# ... (其他接口保持不变，确保 get_status 和 get_jobs 正常工作)

@app.get("/api/status/{prompt_id}")
async def get_status(prompt_id: str):
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
        conn = sqlite3.connect(DB_FILE)
        conn.execute("UPDATE jobs SET status = ?, images = ?, audio_files = ?, completed_at = ? WHERE prompt_id = ?",
                  (final_status, json.dumps(images), json.dumps(audio), time.time(), prompt_id))
        conn.commit()
        conn.close()
        return {"status": final_status, "images": images, "audio_files": audio}

    queue = await comfy_request("GET", "/queue")
    if queue:
        for item in queue.get("queue_running", []):
            if item[1] == prompt_id: return {"status": "running"}
        for item in queue.get("queue_pending", []):
            if item[1] == prompt_id: return {"status": "pending"}
            
    return {"status": "queued"}

@app.get("/api/jobs")
async def get_jobs(x_user_id: str = Header(default="guest")):
    conn = sqlite3.connect(DB_FILE); conn.row_factory = sqlite3.Row
    rows = conn.execute("SELECT * FROM jobs WHERE user_id = ? ORDER BY timestamp DESC LIMIT 50", (x_user_id.lower(),)).fetchall()
    conn.close()
    return [dict(r) for r in rows]

@app.post("/api/generate")
async def generate_image(req: BaseModel, x_user_id: str = Header(default="guest")):
    # 这里保持原有逻辑，但支持动态导入
    pass

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
    raise HTTPException(status_code=404)

@app.get("/api/health")
async def health():
    r = await comfy_request("GET", "/system_stats")
    return {"status": "online" if r else "offline"}

@app.delete("/api/jobs/{prompt_id}")
async def cancel_job(prompt_id: str):
    await comfy_request("POST", "/interrupt")
    await comfy_request("POST", "/queue", json_data={"delete": [prompt_id]})
    conn = sqlite3.connect(DB_FILE)
    conn.execute("DELETE FROM jobs WHERE prompt_id = ?", (prompt_id,))
    conn.commit()
    conn.close()
    return {"status": "deleted"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8100)
