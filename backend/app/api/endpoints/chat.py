from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import json
from supabase import create_client, Client
from app.core.config import settings
from app.services.gemini import gemini_service

router = APIRouter()
supabase: Client = create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_ROLE_KEY)

RED_FLAGS = [
    "chest pain", "severe bleeding", "can't breathe", "cannot breathe",
    "unconscious", "stroke", "heart attack", "seizure",
    "suicidal", "suicide", "overdose", "shortness of breath",
    "difficulty breathing", "unresponsive",
]

TRIAGE_PROMPT = (
    "You are an empathetic medical intake assistant for a Pakistani clinic.\n"
    "Patients may write in Urdu, English, or Roman Urdu — always match their language.\n"
    "Your ONLY job is to collect these 4 pieces of information, ONE question at a time:\n"
    "1. chief_complaint\n2. duration\n3. severity (1-10)\n4. contact (phone number)\n\n"
    "When ALL 4 are collected output EXACTLY:\n"
    "[INTAKE_COMPLETE]\n"
    '{\"chief_complaint\": \"...\", \"duration\": \"...\", \"severity\": \"...\", \"contact\": \"...\"}\n\n'
    "Rules: Never diagnose. Never recommend medications.\n"
    "End every health answer with: 'This is not medical advice.'"
)


class ChatRequest(BaseModel):
    conversation_id: str
    message: str
    doctor_id: str


class SoapRequest(BaseModel):
    conversation_id: str
    doctor_id: str
    triage_data: dict


class AppChatRequest(BaseModel):
    message: str
    history: list = []


@router.post("/ai-respond")
async def ai_respond(request: ChatRequest):
    try:
        conv_res = (
            supabase.table("conversations")
            .select("ai_active, triage_data, intake_complete, patient_id")
            .eq("id", request.conversation_id)
            .single()
            .execute()
        )
        conv = conv_res.data

        if not conv["ai_active"]:
            return {"response": None, "is_red_flag": False, "intake_complete": False}

        if conv["intake_complete"]:
            return {
                "response": "Your intake is complete! Tap below to book your appointment.",
                "is_red_flag": False,
                "intake_complete": True,
            }

        # Red flag fast path — no Gemini needed
        msg_lower = request.message.lower()
        for flag in RED_FLAGS:
            if flag in msg_lower:
                return {
                    "response": (
                        "Your symptoms need immediate attention. "
                        "Please go to the nearest emergency room or call 1122 right now."
                    ),
                    "is_red_flag": True,
                    "intake_complete": False,
                }

        msgs_res = (
            supabase.table("messages")
            .select("sender_role, content")
            .eq("conversation_id", request.conversation_id)
            .order("created_at", desc=False)
            .limit(12)
            .execute()
        )

        triage = conv.get("triage_data") or {}
        collected = [f"{k}: {v}" for k, v in triage.items() if v]
        context = f"Already collected: {', '.join(collected)}" if collected else "Nothing collected yet"

        history_str = "\n".join(
            f"{'Patient' if m['sender_role'] == 'patient' else 'Assistant'}: {m['content']}"
            for m in msgs_res.data
        )

        prompt = (
            f"{TRIAGE_PROMPT}\n\nTriage status: {context}\n\n"
            f"Conversation:\n{history_str}\nPatient: {request.message}\nAssistant:"
        )

        response_text = await gemini_service.generate_text(prompt)
        is_complete = "[INTAKE_COMPLETE]" in response_text
        display = response_text

        if is_complete:
            try:
                j_start = response_text.find("{")
                j_end = response_text.rfind("}") + 1
                triage_json = json.loads(response_text[j_start:j_end])
                supabase.table("conversations").update({
                    "intake_complete": True,
                    "triage_data": triage_json,
                }).eq("id", request.conversation_id).execute()
                display = response_text[:response_text.find("[INTAKE_COMPLETE]")].strip()
                if not display:
                    display = "Thank you! I have all the details I need. Tap below to book your appointment."
            except Exception:
                pass

        return {"response": display, "is_red_flag": False, "intake_complete": is_complete}

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/generate-soap")
async def generate_soap(request: SoapRequest):
    try:
        triage = request.triage_data

        doc_res = (
            supabase.table("doctors")
            .select("*, profiles(full_name, email)")
            .eq("id", request.doctor_id)
            .single()
            .execute()
        )

        conv_res = (
            supabase.table("conversations")
            .select("patient_id")
            .eq("id", request.conversation_id)
            .single()
            .execute()
        )
        patient_id = conv_res.data["patient_id"]

        pat_res = (
            supabase.table("profiles")
            .select("full_name, email")
            .eq("id", patient_id)
            .single()
            .execute()
        )
        patient_name = pat_res.data["full_name"]

        soap_prompt = (
            "Generate a concise clinical SOAP note based on this patient intake:\n"
            f"Chief Complaint: {triage.get('chief_complaint', 'N/A')}\n"
            f"Duration: {triage.get('duration', 'N/A')}\n"
            f"Severity: {triage.get('severity', 'N/A')}/10\n"
            f"Contact: {triage.get('contact', 'N/A')}\n\n"
            "Format:\nS (Subjective):\nO (Objective):\nA (Assessment):\nP (Plan):"
        )

        soap_note = await gemini_service.generate_text(soap_prompt)

        supabase.table("triage_briefs").insert({
            "conversation_id": request.conversation_id,
            "doctor_id": request.doctor_id,
            "patient_name": patient_name,
            "patient_contact": triage.get("contact", ""),
            "chief_complaint": triage.get("chief_complaint", ""),
            "duration": triage.get("duration", ""),
            "severity": str(triage.get("severity", "")),
            "soap_note": soap_note,
        }).execute()

        supabase.table("conversations").update({"intake_complete": True}).eq(
            "id", request.conversation_id
        ).execute()

        # Best-effort email notification to doctor
        try:
            from app.services.email_service import email_service
            doctor_data = doc_res.data
            doctor_email = doctor_data.get("profiles", {}).get("email")
            doctor_name = doctor_data.get("profiles", {}).get("full_name", "Doctor")
            if doctor_email:
                await email_service.notify_doctor(
                    to=doctor_email,
                    doctor_name=doctor_name,
                    patient_name=patient_name,
                    patient_contact=triage.get("contact", "N/A"),
                    soap_note=soap_note,
                )
        except Exception as email_err:
            print(f"Doctor email failed (non-critical): {email_err}")

        return {"status": "success", "soap_note": soap_note}

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/app-chatbot")
async def app_chatbot(request: AppChatRequest):
    try:
        from app.api.endpoints.ai import cached_specialties
        specs = cached_specialties or [
            "Cardiologist", "Dermatologist", "Orthopedic", "Neurologist",
            "Psychiatrist", "Gynecologist", "Pediatrician", "General Physician",
        ]

        history_str = "\n".join(
            f"{'User' if m.get('role') == 'user' else 'Assistant'}: {m.get('content', '')}"
            for m in request.history[-8:]
        )

        prompt = (
            "You are Smart Doctor Connect AI assistant for a Pakistani healthcare platform. "
            "Help patients find doctors and answer general health questions.\n"
            f"Available specializations: {', '.join(specs)}.\n"
            "Always end health answers with: 'This is general info only. Consult a qualified doctor.'\n"
            "Never diagnose. Never recommend medications by name.\n\n"
            f"{f'Previous conversation:{chr(10)}{history_str}{chr(10)}{chr(10)}' if history_str else ''}"
            f"User: {request.message}\nAssistant:"
        )

        response_text = await gemini_service.generate_text(prompt)
        return {"response": response_text}

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
