import json
import time
import sqlite3
import asyncio
from fastapi import APIRouter, Header

from config import DB_FILE
from comfy_client import comfy_request
from database import get_db_connection

router = APIRouter(prefix="/api")

async def _sync_job_status(prompt_id: str, conn: sqlite3.Connection):
    """Internal helper to sync a single job status from ComfyUI."""
    hist = await comfy_request("GET", f"/history/{prompt_id}")
    if hist and prompt_id in hist:
        job_data = hist[prompt_id]
        has_error = any(msg[0] == "execution_error" for msg in job_data.get("status", {}).get("messages", []))
        images, audio = [], []
        
        outputs = job_data.get("outputs", {})
        for node_id, node_out in outputs.items():
            if "images" in node_out:
                images.extend([f"{i.get('subfolder','')}/{i['filename']}".lstrip('/') for i in node_out["images"]])
            if "audio" in node_out:
                for a in node_out.get("audio", []):
                    audio.append(f"{a.get('subfolder','')}/{a['filename']}".lstrip('/'))
        
        final_status = "completed" if (images or audio) else ("failed" if has_error else "completed")
        # Update shared connection
        conn.execute("UPDATE jobs SET status = ?, images = ?, audio_files = ?, completed_at = ? WHERE prompt_id = ?",
                  (final_status, json.dumps(images), json.dumps(audio), time.time(), prompt_id))
        return {"status": final_status, "images": images, "audio_files": audio, "progress": 1.0}
    return None

@router.get("/status/{prompt_id}")
async def get_status(prompt_id: str):
    conn = get_db_connection()
    try:
        # Check History
        res = await _sync_job_status(prompt_id, conn)
        if res:
            conn.commit()
            return res
        # Check Queue
        queue = await comfy_request("GET", "/queue")
        if queue:
            for item in queue.get("queue_running", []):
                if item[1] == prompt_id: return {"status": "running", "progress": 0.5}
            for i, item in enumerate(queue.get("queue_pending", [])):
                if item[1] == prompt_id: return {"status": "pending", "progress": 0.0, "position": i}
        return {"status": "queued", "progress": 0.0}
    finally:
        conn.close()

@router.get("/jobs")
async def get_jobs(x_user_id: str = Header(default="guest")):
    conn = get_db_connection()
    rows = conn.execute("SELECT * FROM jobs WHERE user_id = ? ORDER BY timestamp DESC LIMIT 50", (x_user_id.lower(),)).fetchall()
    jobs = [dict(r) for r in rows]
    
    active_jobs = [j for j in jobs if j["status"] in ["queued", "running", "pending"]]
    if active_jobs:
        queue = await comfy_request("GET", "/queue")
        running_ids = {item[1]: True for item in queue.get("queue_running", [])} if queue else {}
        pending_ids = {item[1]: i for i, item in enumerate(queue.get("queue_pending", []))} if queue else {}
        
        need_sync = []
        for j in active_jobs:
            pid = j["prompt_id"]
            if pid in running_ids:
                j["status"] = "running"
                j["progress"] = 0.5
            elif pid in pending_ids:
                j["status"] = "pending"
                j["progress"] = 0.0
            else:
                need_sync.append(j)
        
        if need_sync:
            # Parallel sync for missing jobs
            sync_tasks = [(_sync_job_status(j["prompt_id"], conn), j) for j in need_sync]
            if sync_tasks:
                results = await asyncio.gather(*[t[0] for t in sync_tasks])
                any_updated = False
                for i, res in enumerate(results):
                    if res:
                        sync_tasks[i][1].update(res)
                        any_updated = True
                if any_updated:
                    conn.commit()
    
    conn.close()
    return jobs

@router.delete("/jobs/{prompt_id}")
async def cancel_job(prompt_id: str):
    await comfy_request("POST", "/interrupt")
    await comfy_request("POST", "/queue", json_data={"delete": [prompt_id]})
    conn = get_db_connection()
    conn.execute("DELETE FROM jobs WHERE prompt_id = ?", (prompt_id,))
    conn.commit()
    conn.close()
    return {"status": "deleted"}
