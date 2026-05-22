from sqlalchemy.orm import Session
from app.models.users_model import Usuario

class UsuarioRepository:
    def __init__(self, db: Session):
        self.db = db

    def crear(self, usuario: Usuario) -> Usuario:
        self.db.add(usuario)
        self.db.commit()
        self.db.refresh(usuario)
        return usuario

    def obtener_por_correo(self, correo: str) -> Usuario | None:
        return self.db.query(Usuario).filter(Usuario.correo == correo).first()

    def obtener_todos(self) -> list[Usuario]:
        return self.db.query(Usuario).all()