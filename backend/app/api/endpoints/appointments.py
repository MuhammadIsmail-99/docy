from fastapi import APIRouter, HTTPException, Query
from typing import Optional, List, Dict
from datetime import datetime, timedelta, time
from pydantic import BaseModel
from supabase import create_client, Client
from app.core.config import settings
from app.services.appointments import appointment_service

router = APIRouter()
supabase: Client = create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_ROLE_KEY)

class EarliestSlotResponse(BaseModel):
    earliest_slot: str
    label: str

@router.get("/slots/earliest", response_model=EarliestSlotResponse)
async def get_earliest_slot(doctor_id: str = Query(..., description="The ID of the doctor")):
    slot_info = await appointment_service.get_earliest_slot(doctor_id)
    if not slot_info:
        raise HTTPException(status_code=404, detail="No available slots found in the next 7 days")
    return slot_info
