import os
import json
import random
import httpx
from fastapi import FastAPI, HTTPException
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

class GenerateRequest(BaseModel):
    prompt: str

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
        except httpx.ConnectError:
            raise HTTPException(status_code=503, detail=f"Cannot reach ComfyUI at {COMFYUI_SERVER}. Is it running?")
        except httpx.HTTPStatusError as e:
            raise HTTPException(status_code=e.response.status_code, detail=f"ComfyUI returned error: {e.response.text}")
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Unexpected error: {str(e)}")

@app.post("/api/generate")
async def generate_image(req: GenerateRequest):
    if not os.path.exists(WORKFLOW_FILE):
        raise HTTPException(status_code=500, detail="Workflow file not found")
        
    with open(WORKFLOW_FILE, "r", encoding="utf-8") as f:
        workflow = json.load(f)
        
    # Inject user prompt into Node 27 (CLIPTextEncode)
    if "27" in workflow and "inputs" in workflow["27"]:
        workflow["27"]["inputs"]["text"] = req.prompt
    else:
         raise HTTPException(status_code=500, detail="Invalid workflow structure: cannot find text encode node")
         
    # Generate random seed for Node 3 (KSampler)
    if "3" in workflow and "inputs" in workflow["3"]:
        workflow["3"]["inputs"]["seed"] = random.randint(1, 2**63 - 1)
        
    result = await comfy_request("POST", "/prompt", json_data={"prompt": workflow})
    return {"prompt_id": result["prompt_id"], "status": "queued"}

@app.get("/api/status/{prompt_id}")
async def get_status(prompt_id: str):
    # Try history first
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
            return {"status": "completed", "images": images}
    except:
        pass

    # Check queue
    queue_data = await comfy_request("GET", "/queue")
    
    for q in queue_data.get("queue_running", []):
        if q[1] == prompt_id:
            # We can't easily get percentage without websockets, but we return a flag
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
