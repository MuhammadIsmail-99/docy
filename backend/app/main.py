from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.router import api_router
from app.core.config import settings
from app.services.cache import cache_service
from supabase import create_client, Client

app = FastAPI(
    title="Smart Doctor Connect AI API",
    description="Backend for the Smart Doctor Connect AI platform",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router, prefix=settings.API_V1_STR)


@app.on_event("startup")
async def startup_event():
    supabase: Client = create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_ROLE_KEY)

    # Warm Bloom filter with existing emails
    try:
        response = supabase.table("profiles").select("email").execute()
        emails = [r["email"] for r in response.data if r.get("email")]
        for email in emails:
            cache_service.add_to_bloom(email)
        print(f"Bloom filter warmed with {len(emails)} emails.")
    except Exception as e:
        print(f"Failed to warm Bloom filter: {e}")

    # Warm specialties cache
    try:
        from app.api.endpoints.ai import refresh_specialties_cache
        await refresh_specialties_cache()
    except Exception as e:
        print(f"Failed to warm specialties cache: {e}")


@app.get("/")
async def root():
    return {"message": "Welcome to Smart Doctor Connect AI API"}


@app.get("/health")
async def health_check():
    return {"status": "healthy"}
