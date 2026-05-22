from app.repositories.usuario_repository import UsuarioRepository
from app.schemas.usuario_schema import UsuarioCreate
from app.models.usuario_model import Usuario

class UsuarioService:
    def __init__(self, repo: UsuarioRepository):
        self.repo = repo

    def crear_usuario(self, datos: UsuarioCreate) -> Usuario:
        # Aquí va lógica de negocio: validaciones, encriptación, etc.
        existente = self.repo.obtener_por_correo(datos.correo)
        if existente:
            raise ValueError("El correo ya está registrado")

        nuevo = Usuario(
            nombre=datos.nombre,
            correo=datos.correo,
            password=datos.password  # aquí iría el hash
        )
        return self.repo.crear(nuevo)