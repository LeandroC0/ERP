from app.services.usuario_service import UsuarioService
from app.repositories.usuario_repository import UsuarioRepository
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session


from app.database.db import get_db
from app.schemas.usuario_schema import UsuarioCreate, UsuarioResponse
from app.services.usuario_service import crear_usuario

router = APIRouter(
    prefix="/usuarios",
    tags=["Usuarios"]
)


@router.post("/", response_model=UsuarioResponse)
def crear(usuario: UsuarioCreate, db: Session = Depends(get_db)):
    repo = UsuarioRepository(db)
    service = UsuarioService(repo)
    return service.crear_usuario(usuario)