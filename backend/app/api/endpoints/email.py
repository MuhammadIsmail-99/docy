from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime, timedelta
from supabase import create_client, Client
from app.core.config import settings
from app.services.email_service import email_service

router = APIRouter()
supabase: Client = create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_ROLE_KEY)


class AppointmentEmailRequest(BaseModel):
    appointment_id: str


class BulkReminderRequest(BaseModel):
    appointment_ids: List[str]


@router.post("/confirm-appointment")
async def confirm_appointment_email(request: AppointmentEmailRequest):
    try:
        app_res = (
            supabase.table("appointments")
            .select("*, profiles!patient_id(full_name, email)")
            .eq("id", request.appointment_id)
            .single()
            .execute()
        )
        appt = app_res.data

        doc_res = (
            supabase.table("doctors")
            .select("*, profiles(full_name)")
            .eq("id", appt["doctor_id"])
            .single()
            .execute()
        )

        patient_name = appt["profiles"]["full_name"]
        patient_email = appt["profiles"]["email"]
        doctor_name = doc_res.data["profiles"]["full_name"]
        appt_time = datetime.fromisoformat(appt["appointment_time"]).strftime("%A %b %d, %Y at %I:%M %p")

        await email_service.confirm_appointment(
            to=patient_email,
            patient_name=patient_name,
            doctor_name=doctor_name,
            appointment_time=appt_time,
            appt_type=appt.get("type", "online"),
            meet_link=appt.get("meet_link"),
        )
        return {"status": "sent"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/notify-doctor")
async def notify_doctor_email(request: AppointmentEmailRequest):
    """Called after SOAP note is generated — handled inside chat.py generate-soap."""
    return {"status": "handled_by_soap_endpoint"}


@router.post("/pre-reminder")
async def pre_reminder(request: BulkReminderRequest):
    """Called by pg_cron 24 hours before appointment."""
    sent = 0
    for appt_id in request.appointment_ids:
        try:
            app_res = (
                supabase.table("appointments")
                .select("*, profiles!patient_id(full_name, email), pre_reminder_sent")
                .eq("id", appt_id)
                .single()
                .execute()
            )
            appt = app_res.data
            if appt.get("pre_reminder_sent"):
                continue

            doc_res = (
                supabase.table("doctors")
                .select("profiles(full_name)")
                .eq("id", appt["doctor_id"])
                .single()
                .execute()
            )
            patient_email = appt["profiles"]["email"]
            patient_name = appt["profiles"]["full_name"]
            doctor_name = doc_res.data["profiles"]["full_name"]
            appt_time = datetime.fromisoformat(appt["appointment_time"]).strftime("%A %b %d at %I:%M %p")

            await email_service.pre_reminder(
                to=patient_email,
                patient_name=patient_name,
                doctor_name=doctor_name,
                appointment_time=appt_time,
            )
            supabase.table("appointments").update({"pre_reminder_sent": True}).eq("id", appt_id).execute()
            sent += 1
        except Exception as e:
            print(f"Pre-reminder failed for {appt_id}: {e}")

    return {"status": "ok", "sent": sent}


@router.post("/post-reminder")
async def post_reminder(request: BulkReminderRequest):
    """Called by pg_cron ~1 hour after appointment ends."""
    sent = 0
    for appt_id in request.appointment_ids:
        try:
            app_res = (
                supabase.table("appointments")
                .select("*, profiles!patient_id(full_name, email), post_reminder_sent")
                .eq("id", appt_id)
                .single()
                .execute()
            )
            appt = app_res.data
            if appt.get("post_reminder_sent"):
                continue

            doc_res = (
                supabase.table("doctors")
                .select("profiles(full_name)")
                .eq("id", appt["doctor_id"])
                .single()
                .execute()
            )
            patient_email = appt["profiles"]["email"]
            patient_name = appt["profiles"]["full_name"]
            doctor_name = doc_res.data["profiles"]["full_name"]

            await email_service.post_feedback(
                to=patient_email,
                patient_name=patient_name,
                doctor_name=doctor_name,
            )
            supabase.table("appointments").update({"post_reminder_sent": True}).eq("id", appt_id).execute()
            sent += 1
        except Exception as e:
            print(f"Post-reminder failed for {appt_id}: {e}")

    return {"status": "ok", "sent": sent}
