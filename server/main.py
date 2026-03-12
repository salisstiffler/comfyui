from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from database import init_db
import routes.generation as generation
import routes.jobs as jobs
import routes.media as media
import routes.system as system

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize database
init_db()

# Include structured routers
app.include_router(generation.router)
app.include_router(jobs.router)
app.include_router(media.router)
app.include_router(system.router)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8100)
