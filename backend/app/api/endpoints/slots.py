from fastapi import APIRouter, HTTPException, Query
from datetime import datetime, timedelta, time
from supabase import create_client, Client
from app.core.config import settings
from app.services.appointments import appointment_service

router = APIRouter()
supabase: Client = create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_ROLE_KEY)


@router.get("/earliest")
async def get_earliest_slot(doctor_id: str = Query(...)):
    slot = await appointment_service.get_earliest_slot(doctor_id)
    if not slot:
        return {"label": "No slots available soon", "earliest_slot": None}
    return slot


@router.get("/available")
async def get_available_slots(
    doctor_id: str = Query(...),
    count: int = Query(default=3, ge=1, le=10),
):
    try:
        avail_res = supabase.table("weekly_availability").select("*").eq("doctor_id", doctor_id).execute()
        availability = avail_res.data
        if not availability:
            return []

        doc_res = supabase.table("doctors").select("consultation_type").eq("id", doctor_id).single().execute()
        consultation_type = doc_res.data.get("consultation_type", "both")

        now = datetime.now()
        apps_res = (
            supabase.table("appointments")
            .select("appointment_time, duration_minutes")
            .eq("doctor_id", doctor_id)
            .gte("appointment_time", now.isoformat())
            .lte("appointment_time", (now + timedelta(days=14)).isoformat())
            .in_("status", ["confirmed", "pending"])
            .execute()
        )
        booked = apps_res.data

        slots = []
        for day_offset in range(14):
            if len(slots) >= count:
                break
            check_date = now + timedelta(days=day_offset)
            dow = (check_date.weekday() + 1) % 7  # Monday=1 … Sunday=0

            day_avail = next((a for a in availability if a["day_of_week"] == dow), None)
            if not day_avail:
                continue

            start_t = time.fromisoformat(day_avail["start_time"])
            end_t = time.fromisoformat(day_avail["end_time"])
            duration = day_avail.get("slot_duration_minutes") or 30

            current = datetime.combine(check_date.date(), start_t)
            end_dt = datetime.combine(check_date.date(), end_t)

            # Skip past slots on today
            if day_offset == 0 and current < now + timedelta(minutes=30):
                minutes_past = int((now - current).total_seconds() / 60)
                skip = (minutes_past // duration + 1) * duration
                current = datetime.combine(check_date.date(), start_t) + timedelta(minutes=skip)

            while current + timedelta(minutes=duration) <= end_dt and len(slots) < count:
                slot_end = current + timedelta(minutes=duration)
                is_booked = any(
                    current < datetime.fromisoformat(a["appointment_time"].replace("Z", "")).replace(tzinfo=None)
                    + timedelta(minutes=a.get("duration_minutes", 30))
                    and slot_end
                    > datetime.fromisoformat(a["appointment_time"].replace("Z", "")).replace(tzinfo=None)
                    for a in booked
                )

                if not is_booked:
                    if day_offset == 0:
                        label_day = "Today"
                    elif day_offset == 1:
                        label_day = "Tomorrow"
                    else:
                        label_day = current.strftime("%A, %b %d")

                    slot_type = consultation_type if consultation_type != "both" else "online"
                    slots.append({
                        "datetime": current.isoformat(),
                        "label": f"{label_day} {current.strftime('%I:%M %p')}",
                        "type": slot_type,
                        "duration_minutes": duration,
                    })

                current += timedelta(minutes=duration)

        return slots

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
