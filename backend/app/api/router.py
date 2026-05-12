from fastapi import APIRouter
from app.api.endpoints import ai, auth, appointments, chat, slots, email

api_router = APIRouter()
api_router.include_router(ai.router, prefix="/ai", tags=["ai"])
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(appointments.router, prefix="/appointments", tags=["appointments"])
api_router.include_router(chat.router, prefix="/chat", tags=["chat"])
api_router.include_router(slots.router, prefix="/slots", tags=["slots"])
api_router.include_router(email.router, prefix="/email", tags=["email"])
