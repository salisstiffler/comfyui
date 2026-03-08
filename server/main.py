import os
import json
import random
import httpx
import sqlite3
import time
from typing import Optional, List
from fastapi import FastAPI, HTTPException, Header
from fastapi.responses import Response
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
DB_FILE = os.path.join(os.path.dirname(__file__), "jobs.db")

# Initialize DB
def init_db():
    conn = sqlite3.connect(DB_FILE)
    c = conn.cursor()
    # Ensure table exists first
    c.execute('''CREATE TABLE IF NOT EXISTS jobs
                 (prompt_id TEXT PRIMARY KEY, prompt TEXT, status TEXT, 
                  timestamp REAL, params TEXT, images TEXT, user_id TEXT, completed_at REAL)''')
    
    # Migration: Check for user_id and completed_at (for older databases)
    cursor = c.execute("PRAGMA table_info(jobs)")
    columns = [row[1] for row in cursor.fetchall()]
    
    if "user_id" not in columns:
        c.execute("ALTER TABLE jobs ADD COLUMN user_id TEXT DEFAULT 'guest'")
    if "completed_at" not in columns:
        c.execute("ALTER TABLE jobs ADD COLUMN completed_at REAL")
        
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

class Job(BaseModel):
    prompt_id: str
    prompt: str
    status: str
    timestamp: float
    params: dict
    images: List[str]
    completed_at: Optional[float] = None

HOST_BRIDGE_URL = "http://host.docker.internal:8189"

@app.post("/api/wake")
async def wake_engine():
    async with httpx.AsyncClient(timeout=5.0) as client:
        try:
            response = await client.post(f"{HOST_BRIDGE_URL}/launch")
            return response.json()
        except Exception as e:
            raise HTTPException(status_code=503, detail="Host bridge not responding. Is host_bridge.py running?")

async def comfy_request(method: str, path: str, json_data: dict = None, params: dict = None):
    url = f"http://{COMFYUI_SERVER}{path}"
    async with httpx.AsyncClient(timeout=10.0) as client:
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
            # Engine is likely offline
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
    if not os.path.exists(WORKFLOW_FILE):
        raise HTTPException(status_code=500, detail="Workflow file not found")
        
    with open(WORKFLOW_FILE, "r", encoding="utf-8") as f:
        workflow = json.load(f)
        
    # Inject user prompt into Node 27 (CLIPTextEncode)
    if "27" in workflow and "inputs" in workflow["27"]:
        workflow["27"]["inputs"]["text"] = req.prompt
    else:
         raise HTTPException(status_code=500, detail="Invalid workflow structure: cannot find text encode node")
         
    # Handle Seed
    seed_val = req.seed if req.seed is not None else random.randint(1, 2**63 - 1)
    
    # Inject Params into Node 3 (KSampler)
    if "3" in workflow and "inputs" in workflow["3"]:
        workflow["3"]["inputs"]["seed"] = seed_val
        workflow["3"]["inputs"]["steps"] = req.steps
        workflow["3"]["inputs"]["cfg"] = req.cfg
        workflow["3"]["inputs"]["sampler_name"] = req.sampler_name
        
    # Inject Dimensions/Batch into Node 13 (EmptySD3LatentImage)
    if "13" in workflow and "inputs" in workflow["13"]:
        workflow["13"]["inputs"]["width"] = req.width
        workflow["13"]["inputs"]["height"] = req.height
        workflow["13"]["inputs"]["batch_size"] = req.batch_size
        
    result = await comfy_request("POST", "/prompt", json_data={"prompt": workflow})
    pid = result["prompt_id"]
    
    # Save to DB
    params_json = json.dumps({
        "steps": req.steps, 
        "cfg": req.cfg, 
        "seed": seed_val, 
        "sampler": req.sampler_name,
        "width": req.width,
        "height": req.height,
        "batch_size": req.batch_size
    })
    
    conn = sqlite3.connect(DB_FILE)
    c = conn.cursor()
    c.execute("INSERT INTO jobs (prompt_id, prompt, status, timestamp, params, images, user_id) VALUES (?, ?, ?, ?, ?, ?, ?)",
              (pid, req.prompt, "queued", time.time(), params_json, "[]", x_user_id))
    conn.commit()
    conn.close()
    
    return {"prompt_id": pid, "status": "queued"}

@app.get("/api/jobs")
async def get_jobs(x_user_id: str = Header("guest")):
    conn = sqlite3.connect(DB_FILE)
    conn.row_factory = sqlite3.Row
    c = conn.cursor()
    c.execute("SELECT * FROM jobs WHERE user_id=? ORDER BY timestamp DESC LIMIT 50", (x_user_id,))
    rows = c.fetchall()
    conn.close()
    
    jobs = []
    for r in rows:
        jobs.append({
            "prompt_id": r["prompt_id"],
            "prompt": r["prompt"],
            "status": r["status"],
            "timestamp": r["timestamp"],
            "completed_at": r["completed_at"],
            "params": json.loads(r["params"]),
            "images": json.loads(r["images"])
        })
    return jobs

@app.get("/api/status/{prompt_id}")
async def get_status(prompt_id: str):
    # Check DB first for completion
    conn = sqlite3.connect(DB_FILE)
    c = conn.cursor()
    c.execute("SELECT status, images, completed_at FROM jobs WHERE prompt_id=?", (prompt_id,))
    row = c.fetchone()
    conn.close()
    
    if row and row[0] == "completed":
        return {"status": "completed", "images": json.loads(row[1]), "completed_at": row[2]}

    # Ask ComfyUI
    try:
        history = await comfy_request("GET", f"/history/{prompt_id}")
        if prompt_id in history:
            task_data = history[prompt_id]
            outputs = task_data.get("outputs", {})
            images = []
            for node_id, node_output in outputs.items():
                if "images" in node_output:
                    for img in node_output["images"]:
                        images.append(img["filename"])
            
            comp_time = time.time()
            # Update DB
            conn = sqlite3.connect(DB_FILE)
            c = conn.cursor()
            c.execute("UPDATE jobs SET status=?, images=?, completed_at=? WHERE prompt_id=?", 
                      ("completed", json.dumps(images), comp_time, prompt_id))
            conn.commit()
            conn.close()
            
            return {"status": "completed", "images": images, "completed_at": comp_time}
    except:
        pass

    # Check queue
    queue_data = await comfy_request("GET", "/queue")
    
    for q in queue_data.get("queue_running", []):
        if q[1] == prompt_id:
            # Update DB to running
            conn = sqlite3.connect(DB_FILE)
            c = conn.cursor()
            c.execute("UPDATE jobs SET status=? WHERE prompt_id=?", ("running", prompt_id))
            conn.commit()
            conn.close()
            return {"status": "running", "progress": 0.5}
            
    for q in queue_data.get("queue_pending", []):
        if q[1] == prompt_id:
            return {"status": "pending"}
            
    return {"status": "unknown"}

@app.delete("/api/queue/{prompt_id}")
async def cancel_task(prompt_id: str):
    # Interrupt current
    await comfy_request("POST", "/interrupt")
    # Clean queue
    url = f"http://{COMFYUI_SERVER}/queue"
    async with httpx.AsyncClient() as client:
        await client.post(url, json={"delete": [prompt_id]})
    
    conn = sqlite3.connect(DB_FILE)
    c = conn.cursor()
    c.execute("UPDATE jobs SET status=? WHERE prompt_id=?", ("cancelled", prompt_id))
    conn.commit()
    conn.close()
    
    return {"status": "cancelled", "prompt_id": prompt_id}

@app.get("/api/image/{filename}")
async def get_image(filename: str):
    url = f"http://{COMFYUI_SERVER}/view"
    params = {"filename": filename, "type": "output"}
    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(url, params=params)
            response.raise_for_status()
            return Response(content=response.content, media_type="image/png")
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Failed to fetch image: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
