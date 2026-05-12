from fastapi import APIRouter, HTTPException, BackgroundTasks, Depends
import json
from typing import List, Optional
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

# t22: Specialties Cache
cached_specialties = []

async def refresh_specialties_cache():
    global cached_specialties
    try:
        response = supabase.table("doctors").select("specialization").execute()
        specs = {r["specialization"] for r in response.data}
        cached_specialties = sorted(list(specs))
        print(f"Specialties cache refreshed: {cached_specialties}")
    except Exception as e:
        print(f"Failed to refresh specialties: {e}")

class SuggestRequest(BaseModel):
    query: str

class SearchRequest(BaseModel):
    query: str
    city: Optional[str] = None
    available_only: bool = False

@router.get("/specialties")
async def get_specialties():
    if not cached_specialties:
        await refresh_specialties_cache()
    return cached_specialties

@router.post("/suggest-specialties")
async def suggest_specialties(request: SuggestRequest):
    if not cached_specialties:
        await refresh_specialties_cache()
        
    prompt = f"""
    You are a medical triage assistant. Given a patient's search query and a list of available specializations, 
    return ONLY the 1-3 most relevant specializations from the list as a JSON array. No explanation.
    Include a one-sentence reasoning string for each match.
    
    Query: "{request.query}"
    Available Specializations: {cached_specialties}
    
    Output format: [{"specialty": "Orthopedic", "reason": "Back pain is typically managed by orthopedic specialists"}]
    """
    
    try:
        response = await gemini_service.generate_text(prompt)
        # Clean potential markdown from response
        clean_json = response.replace('```json', '').replace('```', '').strip()
        suggestions = json.loads(clean_json)
        return suggestions
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"AI Suggestion failed: {str(e)}")

@router.post("/search-doctors")
async def search_doctors(request: SearchRequest):
    try:
        # 1. Suggest specialties based on query
        suggestions = await suggest_specialties(SuggestRequest(query=request.query))
        
        # 2. Embed the query
        query_embedding = await gemini_service.get_embedding(request.query)
        
        results = []
        for suggestion in suggestions:
            specialty = suggestion["specialty"]
            
            # 3. Perform semantic search using pgvector
            # We use a raw RPC call or a specific supabase query if possible
            # Note: supabase-py doesn't support vector operators directly in a nice way yet
            # so we use a custom function we should have created in Phase 1
            
            # Assuming we have a function 'match_doctors' in Supabase:
            # CREATE OR REPLACE FUNCTION match_doctors(query_embedding vector(768), match_specialty text, match_city text, available_only boolean, match_threshold float, match_count int)
            # RETURNS TABLE (id uuid, full_name text, specialization text, city text, experience_years int, consultation_fee int, rating numeric, is_available boolean, similarity float) ...
            
            rpc_params = {
                "query_embedding": query_embedding,
                "match_specialty": specialty,
                "match_city": request.city,
                "available_only": request.available_only,
                "match_threshold": 0.5,
                "match_count": 5
            }
            
            # Execute RPC
            rpc_response = supabase.rpc("match_doctors", rpc_params).execute()
            
            # Enrich with profile data if needed, but match_doctors should return it
            results.append({
                "specialty": specialty,
                "reason": suggestion["reason"],
                "doctors": rpc_response.data
            })
            
        return results
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
