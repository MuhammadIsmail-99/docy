from datetime import datetime, timedelta, time
from typing import Optional, Dict
from supabase import create_client, Client
from app.core.config import settings

class AppointmentService:
    def __init__(self):
        self.supabase: Client = create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_ROLE_KEY)

    async def get_earliest_slot(self, doctor_id: str) -> Optional[Dict[str, str]]:
        try:
            # 1. Fetch weekly availability
            avail_res = self.supabase.table("weekly_availability").select("*").eq("doctor_id", doctor_id).execute()
            availability = avail_res.data
            
            if not availability:
                return None

            # 2. Fetch existing appointments
            now = datetime.now()
            apps_res = self.supabase.table("appointments") \
                .select("appointment_time, duration_minutes") \
                .eq("doctor_id", doctor_id) \
                .gte("appointment_time", now.isoformat()) \
                .eq("status", "confirmed") \
                .execute()
            appointments = apps_res.data

            # 3. Find earliest slot
            for i in range(7):
                check_date = now + timedelta(days=i)
                day_of_week = (check_date.weekday() + 1) % 7
                
                day_avail = next((a for a in availability if a['day_of_week'] == day_of_week), None)
                if not day_avail:
                    continue

                start_t = time.fromisoformat(day_avail['start_time'])
                end_t = time.fromisoformat(day_avail['end_time'])
                slot_duration = day_avail['slot_duration_minutes'] or 30

                current_slot_dt = datetime.combine(check_date.date(), start_t)
                
                if i == 0:
                    if current_slot_dt < now + timedelta(minutes=30):
                        minutes = (now.minute // 30 + 1) * 30
                        current_slot_dt = now.replace(minute=0, second=0, microsecond=0) + timedelta(minutes=minutes)
                
                while current_slot_dt.time() <= (datetime.combine(check_date.date(), end_t) - timedelta(minutes=slot_duration)).time():
                    is_booked = False
                    for app in appointments:
                        app_start = datetime.fromisoformat(app['appointment_time'].replace('Z', '+00:00')).replace(tzinfo=None)
                        app_end = app_start + timedelta(minutes=app['duration_minutes'])
                        slot_end = current_slot_dt + timedelta(minutes=slot_duration)
                        if (current_slot_dt < app_end and slot_end > app_start):
                            is_booked = True
                            break
                    
                    if not is_booked:
                        label = "Today" if i == 0 else "Tomorrow" if i == 1 else current_slot_dt.strftime("%A")
                        return {
                            "earliest_slot": current_slot_dt.isoformat(),
                            "label": f"{label} {current_slot_dt.strftime('%I:%M %p')}"
                        }
                    current_slot_dt += timedelta(minutes=slot_duration)
            return None
        except Exception:
            return None

appointment_service = AppointmentService()
