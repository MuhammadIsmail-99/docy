from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, EmailStr
from app.services.cache import cache_service
from supabase import create_client, Client
from app.core.config import settings

router = APIRouter()

supabase: Client = create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_ROLE_KEY)

class EmailCheckRequest(BaseModel):
    email: EmailStr

@router.post("/check-email")
async def check_email(request: EmailCheckRequest):
    # Rule 6: Bloom filter check before hitting DB
    might_exist = cache_service.check_bloom(request.email)
    print(f"Bloom check for {request.email}: {might_exist}")
    
    if not might_exist:
        return {"exists": False, "message": "Email definitely does not exist in our system"}
    
    # If bloom filter says it might exist, we check the actual database
    try:
        response = supabase.table("profiles").select("id").eq("email", request.email.lower()).execute()
        exists = len(response.data) > 0
        print(f"Database check for {request.email}: {exists}")
        return {"exists": exists, "message": "Email check completed"}
    except Exception as e:
        print(f"Database error during email check: {e}")
        # Fallback to true if DB fails but bloom said yes
        return {"exists": True, "message": f"Possible hit, database check failed: {e}"}

@router.post("/sync-bloom")
async def sync_bloom():
    """Admin endpoint to rebuild the bloom filter from the profiles table"""
    try:
        # Note: This could be slow for millions of users, should be a background task
        # But for this project it's fine
        response = supabase.table("profiles").select("email").execute()
        emails = [r["email"] for r in response.data if r.get("email")]
        
        for email in emails:
            cache_service.add_to_bloom(email)
            
        return {"status": "success", "count": len(emails)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
