# ERP Inventario Python

## Activar entorno virtual

```bash
.\.venv\Scripts\Activate
```

---

## Ejecutar proyecto

```bash
uvicorn app.main:app --reload
```

Swagger:
http://127.0.0.1:8000/docs

---

## Instalar dependencias

```bash
pip install fastapi uvicorn sqlalchemy psycopg2-binary pydantic python-dotenv alembic passlib bcrypt python-jose python-multipart email-validator
```

---

## Generar requirements.txt

```bash
pip freeze > requirements.txt
```

---

## Dependencias importantes

| Librería | Uso |
|---|---|
| FastAPI | API REST |
| SQLAlchemy | ORM |
| PostgreSQL | Base de datos |
| Alembic | Migraciones |
| Pydantic | Validaciones |
| JWT | Autenticación |
| dotenv | Variables entorno |

---

# Roadmap del Proyecto

## Etapa 1
- Conexión DB
- Modelos
- CRUD básico

## Etapa 2
- Autenticación JWT
- Usuarios/Roles

## Etapa 3
- Inventario
- Productos
- Categorías
- Proveedores

## Etapa 4
- Compras
- Ventas
- Kardex
- Movimientos

## Etapa 5
- Reportes
- Dashboard
- Exportación Excel/PDF