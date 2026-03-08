import subprocess
import os
import sys
from fastapi import FastAPI
import uvicorn
import socket

app = FastAPI()

# 配置路径
COMFYUI_BAT_PATH = r"D:\ComfyUI_windows_portable\run_nvidia_gpu.bat"
COMFYUI_DIR = r"D:\ComfyUI_windows_portable"

@app.post("/launch")
async def launch():
    print(f"\n[SIGNAL] Received wake-up call from Docker...")
    
    if not os.path.exists(COMFYUI_BAT_PATH):
        error_msg = f"Path not found: {COMFYUI_BAT_PATH}"
        print(f"[ERROR] {error_msg}")
        return {"status": "Error", "message": error_msg}

    try:
        print(f"[ACTION] Executing: {COMFYUI_BAT_PATH}")
        # 使用 Popen 启动并脱离父进程
        subprocess.Popen(
            [COMFYUI_BAT_PATH],
            cwd=COMFYUI_DIR,
            creationflags=subprocess.CREATE_NEW_CONSOLE,
            shell=True
        )
        return {"status": "Launching", "message": "ComfyUI is starting in a new window."}
    except Exception as e:
        print(f"[ERROR] Failed to launch: {str(e)}")
        return {"status": "Error", "message": str(e)}

@app.get("/ping")
async def ping():
    return {"status": "alive"}

if __name__ == "__main__":
    # 获取本机IP方便调试
    hostname = socket.gethostname()
    local_ip = socket.gethostbyname(hostname)
    
    print("="*40)
    print("   ComfyProMax - HOST BRIDGE SERVICE   ")
    print("="*40)
    print(f"Target: {COMFYUI_BAT_PATH}")
    print(f"Bridge IP for Docker: host.docker.internal")
    print(f"Status: Waiting for commands...")
    print("="*40)
    
    uvicorn.run(app, host="0.0.0.0", port=8189, log_level="error")
