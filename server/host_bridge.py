import subprocess
import os
from fastapi import FastAPI
import uvicorn

app = FastAPI()

# 你提供的路径
COMFYUI_BAT_PATH = r"D:\ComfyUI_windows_portable\run_nvidia_gpu.bat"
COMFYUI_DIR = r"D:\ComfyUI_windows_portable"

@app.post("/launch")
async def launch():
    try:
        # 使用 Popen 异步启动，不阻塞桥接脚本
        subprocess.Popen(
            [COMFYUI_BAT_PATH],
            cwd=COMFYUI_DIR,
            creationflags=subprocess.CREATE_NEW_CONSOLE # 在新窗口打开，方便你观察日志
        )
        return {"status": "Launching", "message": "ComfyUI engine is starting..."}
    except Exception as e:
        return {"status": "Error", "message": str(e)}

if __name__ == "__main__":
    print(f"--- ComfyProMax Host Bridge ---")
    print(f"Waiting for wake-up signals from Docker...")
    uvicorn.run(app, host="0.0.0.0", port=8189)
