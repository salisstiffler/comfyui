import os

COMFYUI_SERVER = os.environ.get("COMFYUI_SERVER", "127.0.0.1:8188")
WORKFLOW_FILE = os.path.join(os.path.dirname(__file__), "workflow_api.json")
I2I_WORKFLOW_FILE = os.path.join(os.path.dirname(__file__), "flux2_i2i.json")
MUSIC_WORKFLOW_FILE = os.path.join(os.path.dirname(__file__), "music_workflow.json")
MUSIC_WORKFLOW2_FILE = os.path.join(os.path.dirname(__file__), "music_workflow2.json")
NSFW_WORKFLOW_FILE = os.path.join(os.path.dirname(__file__), "nsfw_workflow.json")
DB_FILE = os.path.join(os.path.dirname(__file__), "jobs.db")
