from fastapi import APIRouter, HTTPException, BackgroundTasks
from pydantic import BaseModel
from app.services.gemini import gemini_service
from supabase import create_client, Client
from app.core.config import settings

router = APIRouter()

supabase: Client = create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_ROLE_KEY)

class DoctorEmbedRequest(BaseModel):
    doctor_id: str
    specialization: str
    city: str
    bio: str
    experience_years: int

@router.post("/embed-doctor")
async def embed_doctor(request: DoctorEmbedRequest):
    try:
        # 1. Create a rich text string for embedding
        text_to_embed = f"Doctor ID: {request.doctor_id}\nSpecialization: {request.specialization}\nCity: {request.city}\nBio: {request.bio}\nExperience: {request.experience_years} years"
        
        # 2. Get embedding from Gemini
        embedding = await gemini_service.get_embedding(text_to_embed)
        
        # 3. Store embedding in Supabase
        supabase.table("doctors").update({
            "embedding": embedding
        }).eq("id", request.doctor_id).execute()
        
        return {"status": "success", "message": "Embedding stored successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
