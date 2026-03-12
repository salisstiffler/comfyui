import httpx
from config import COMFYUI_SERVER

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
            print(f"Comfy Connection Error to {url}: {str(e)}")
            return None
