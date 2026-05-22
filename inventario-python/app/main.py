from fastapi import FastAPI
from app.database.connection import engine, Base

from app.models.state_model import State
from app.models.role_model import Role
from app.models.users_model import User  

Base.metadata.create_all(bind=engine)

from app.routes.users_routes import router as users_router  

app = FastAPI()
app.include_router(users_router)

@app.get("/")
def home():
    return {"mensaje": "API funcionando"}