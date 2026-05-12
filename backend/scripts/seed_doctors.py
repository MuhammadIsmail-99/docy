import asyncio
import httpx
from supabase import create_client, Client
import os
from dotenv import load_dotenv

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
FASTAPI_URL = os.getenv("FASTAPI_URL", "http://localhost:8000/api/v1")

supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

DOCTORS = [
    {
        "email": "cardio1@example.com",
        "full_name": "Dr. Ahmed Hassan",
        "specialization": "Cardiologist",
        "city": "Lahore",
        "consultation_type": "both",
        "experience_years": 12,
        "consultation_fee": 3000,
        "bio": "Experienced cardiologist specializing in heart failure, preventive cardiology, and cardiac rehabilitation. Fellowship trained at Aga Khan University.",
        "pmdc_number": "PMDC-12345",
        "rating": 4.8,
        "review_count": 150,
        "is_available": True,
        "availability": [
            {"day_of_week": 1, "start_time": "09:00:00", "end_time": "17:00:00"},
            {"day_of_week": 2, "start_time": "09:00:00", "end_time": "17:00:00"},
            {"day_of_week": 3, "start_time": "09:00:00", "end_time": "17:00:00"},
            {"day_of_week": 4, "start_time": "09:00:00", "end_time": "17:00:00"},
        ],
    },
    {
        "email": "derm1@example.com",
        "full_name": "Dr. Sara Khan",
        "specialization": "Dermatologist",
        "city": "Karachi",
        "consultation_type": "online",
        "experience_years": 8,
        "consultation_fee": 2000,
        "bio": "Expert in clinical and aesthetic dermatology with a focus on skin cancer screening, acne management, and dermatological surgery.",
        "pmdc_number": "PMDC-67890",
        "rating": 4.6,
        "review_count": 85,
        "is_available": True,
        "availability": [
            {"day_of_week": 1, "start_time": "10:00:00", "end_time": "18:00:00"},
            {"day_of_week": 3, "start_time": "10:00:00", "end_time": "18:00:00"},
            {"day_of_week": 5, "start_time": "10:00:00", "end_time": "16:00:00"},
        ],
    },
    {
        "email": "ortho1@example.com",
        "full_name": "Dr. Usman Ali",
        "specialization": "Orthopedic",
        "city": "Islamabad",
        "consultation_type": "physical",
        "experience_years": 15,
        "consultation_fee": 2500,
        "bio": "Specialist in joint replacement, sports medicine, and spine surgery. Over 2000 successful surgeries performed at Shifa International Hospital.",
        "pmdc_number": "PMDC-11223",
        "rating": 4.9,
        "review_count": 210,
        "is_available": True,
        "availability": [
            {"day_of_week": 1, "start_time": "08:00:00", "end_time": "14:00:00"},
            {"day_of_week": 2, "start_time": "08:00:00", "end_time": "14:00:00"},
            {"day_of_week": 4, "start_time": "08:00:00", "end_time": "14:00:00"},
            {"day_of_week": 6, "start_time": "09:00:00", "end_time": "13:00:00"},
        ],
    },
    {
        "email": "neuro1@example.com",
        "full_name": "Dr. Fatima Malik",
        "specialization": "Neurologist",
        "city": "Lahore",
        "consultation_type": "both",
        "experience_years": 10,
        "consultation_fee": 3500,
        "bio": "Neurologist specializing in migraine, epilepsy, stroke management, and neurodegenerative diseases. Trained at Mayo Hospital Lahore.",
        "pmdc_number": "PMDC-33445",
        "rating": 4.7,
        "review_count": 120,
        "is_available": True,
        "availability": [
            {"day_of_week": 1, "start_time": "09:00:00", "end_time": "15:00:00"},
            {"day_of_week": 2, "start_time": "09:00:00", "end_time": "15:00:00"},
            {"day_of_week": 3, "start_time": "09:00:00", "end_time": "15:00:00"},
        ],
    },
    {
        "email": "psych1@example.com",
        "full_name": "Dr. Bilal Siddiqui",
        "specialization": "Psychiatrist",
        "city": "Karachi",
        "consultation_type": "online",
        "experience_years": 7,
        "consultation_fee": 2500,
        "bio": "Psychiatrist focused on depression, anxiety disorders, PTSD, and addiction management. Provides confidential, judgment-free online consultations.",
        "pmdc_number": "PMDC-55667",
        "rating": 4.5,
        "review_count": 75,
        "is_available": True,
        "availability": [
            {"day_of_week": 1, "start_time": "14:00:00", "end_time": "20:00:00"},
            {"day_of_week": 3, "start_time": "14:00:00", "end_time": "20:00:00"},
            {"day_of_week": 5, "start_time": "14:00:00", "end_time": "20:00:00"},
        ],
    },
    {
        "email": "gyne1@example.com",
        "full_name": "Dr. Ayesha Raza",
        "specialization": "Gynecologist",
        "city": "Rawalpindi",
        "consultation_type": "both",
        "experience_years": 14,
        "consultation_fee": 2000,
        "bio": "Experienced gynecologist specializing in high-risk pregnancy, PCOS, endometriosis, and minimally invasive gynecological surgery.",
        "pmdc_number": "PMDC-77889",
        "rating": 4.9,
        "review_count": 300,
        "is_available": True,
        "availability": [
            {"day_of_week": 2, "start_time": "09:00:00", "end_time": "17:00:00"},
            {"day_of_week": 4, "start_time": "09:00:00", "end_time": "17:00:00"},
            {"day_of_week": 6, "start_time": "09:00:00", "end_time": "13:00:00"},
        ],
    },
    {
        "email": "peds1@example.com",
        "full_name": "Dr. Hamza Sheikh",
        "specialization": "Pediatrician",
        "city": "Lahore",
        "consultation_type": "both",
        "experience_years": 9,
        "consultation_fee": 1500,
        "bio": "Compassionate pediatrician with expertise in neonatal care, childhood development, vaccinations, and pediatric infectious diseases.",
        "pmdc_number": "PMDC-99001",
        "rating": 4.8,
        "review_count": 190,
        "is_available": True,
        "availability": [
            {"day_of_week": 1, "start_time": "08:00:00", "end_time": "16:00:00"},
            {"day_of_week": 2, "start_time": "08:00:00", "end_time": "16:00:00"},
            {"day_of_week": 3, "start_time": "08:00:00", "end_time": "16:00:00"},
            {"day_of_week": 4, "start_time": "08:00:00", "end_time": "16:00:00"},
            {"day_of_week": 5, "start_time": "08:00:00", "end_time": "16:00:00"},
        ],
    },
    {
        "email": "gp1@example.com",
        "full_name": "Dr. Zainab Chaudhry",
        "specialization": "General Physician",
        "city": "Islamabad",
        "consultation_type": "both",
        "experience_years": 6,
        "consultation_fee": 1000,
        "bio": "General physician providing comprehensive primary care, chronic disease management, preventive health, and acute illness treatment.",
        "pmdc_number": "PMDC-22334",
        "rating": 4.4,
        "review_count": 60,
        "is_available": True,
        "availability": [
            {"day_of_week": 1, "start_time": "09:00:00", "end_time": "18:00:00"},
            {"day_of_week": 2, "start_time": "09:00:00", "end_time": "18:00:00"},
            {"day_of_week": 3, "start_time": "09:00:00", "end_time": "18:00:00"},
            {"day_of_week": 4, "start_time": "09:00:00", "end_time": "18:00:00"},
            {"day_of_week": 5, "start_time": "09:00:00", "end_time": "18:00:00"},
        ],
    },
    {
        "email": "cardio2@example.com",
        "full_name": "Dr. Omar Farooq",
        "specialization": "Cardiologist",
        "city": "Karachi",
        "consultation_type": "online",
        "experience_years": 18,
        "consultation_fee": 4000,
        "bio": "Senior interventional cardiologist with expertise in angioplasty, cardiac imaging, and heart failure management. 20+ years at Liaquat National Hospital.",
        "pmdc_number": "PMDC-44556",
        "rating": 5.0,
        "review_count": 280,
        "is_available": False,
        "availability": [
            {"day_of_week": 1, "start_time": "15:00:00", "end_time": "19:00:00"},
            {"day_of_week": 4, "start_time": "15:00:00", "end_time": "19:00:00"},
        ],
    },
    {
        "email": "ortho2@example.com",
        "full_name": "Dr. Nadia Iqbal",
        "specialization": "Orthopedic",
        "city": "Karachi",
        "consultation_type": "both",
        "experience_years": 11,
        "consultation_fee": 2200,
        "bio": "Orthopedic surgeon specializing in pediatric orthopedics, fracture management, and arthroscopic procedures.",
        "pmdc_number": "PMDC-66778",
        "rating": 4.6,
        "review_count": 145,
        "is_available": True,
        "availability": [
            {"day_of_week": 2, "start_time": "08:00:00", "end_time": "14:00:00"},
            {"day_of_week": 3, "start_time": "08:00:00", "end_time": "14:00:00"},
            {"day_of_week": 6, "start_time": "10:00:00", "end_time": "14:00:00"},
        ],
    },
    {
        "email": "derm2@example.com",
        "full_name": "Dr. Tariq Mehmood",
        "specialization": "Dermatologist",
        "city": "Rawalpindi",
        "consultation_type": "physical",
        "experience_years": 5,
        "consultation_fee": 1500,
        "bio": "Dermatologist focused on hair loss treatment, vitiligo, eczema, and cosmetic dermatology procedures.",
        "pmdc_number": "PMDC-88990",
        "rating": 4.3,
        "review_count": 45,
        "is_available": True,
        "availability": [
            {"day_of_week": 1, "start_time": "11:00:00", "end_time": "17:00:00"},
            {"day_of_week": 3, "start_time": "11:00:00", "end_time": "17:00:00"},
            {"day_of_week": 5, "start_time": "11:00:00", "end_time": "17:00:00"},
        ],
    },
    {
        "email": "gp2@example.com",
        "full_name": "Dr. Sana Baig",
        "specialization": "General Physician",
        "city": "Lahore",
        "consultation_type": "online",
        "experience_years": 4,
        "consultation_fee": 800,
        "bio": "Young general physician offering teleconsultation for fever, infections, diabetes management, and general health queries.",
        "pmdc_number": "PMDC-10111",
        "rating": 4.2,
        "review_count": 30,
        "is_available": True,
        "availability": [
            {"day_of_week": 1, "start_time": "18:00:00", "end_time": "22:00:00"},
            {"day_of_week": 2, "start_time": "18:00:00", "end_time": "22:00:00"},
            {"day_of_week": 3, "start_time": "18:00:00", "end_time": "22:00:00"},
            {"day_of_week": 4, "start_time": "18:00:00", "end_time": "22:00:00"},
            {"day_of_week": 5, "start_time": "18:00:00", "end_time": "22:00:00"},
        ],
    },
]

USERS = [
    {"email": "testpatient@example.com", "full_name": "Test Patient", "password": "Password123!", "role": "patient"},
    {"email": "admin@example.com", "full_name": "Admin User", "password": "AdminPassword123!", "role": "admin"},
]


async def embed_doctor(doctor_id: str, doc: dict):
    async with httpx.AsyncClient(timeout=30) as client:
        try:
            await client.post(f"{FASTAPI_URL}/ai/embed-doctor", json={
                "doctor_id": doctor_id,
                "specialization": doc["specialization"],
                "city": doc["city"],
                "bio": doc["bio"],
                "experience_years": doc["experience_years"],
            })
            print(f"  ✓ Embedding stored for {doc['full_name']}")
        except Exception as e:
            print(f"  ✗ Embedding failed for {doc['full_name']}: {e}")


async def seed():
    print("=== Seeding Doctors ===")
    for doc in DOCTORS:
        print(f"Seeding {doc['full_name']}...")
        try:
            # Create auth user
            res = supabase.auth.admin.create_user({
                "email": doc["email"],
                "password": "Password123!",
                "email_confirm": True,
                "user_metadata": {"full_name": doc["full_name"], "role": "doctor"},
            })
            user_id = res.user.id

            # Upsert profile
            supabase.table("profiles").upsert({
                "id": user_id,
                "full_name": doc["full_name"],
                "email": doc["email"],
                "role": "doctor",
            }).execute()

            # Upsert doctor record
            supabase.table("doctors").upsert({
                "id": user_id,
                "specialization": doc["specialization"],
                "city": doc["city"],
                "consultation_type": doc["consultation_type"],
                "experience_years": doc["experience_years"],
                "consultation_fee": doc["consultation_fee"],
                "bio": doc["bio"],
                "pmdc_number": doc["pmdc_number"],
                "rating": doc["rating"],
                "review_count": doc["review_count"],
                "verification_status": "verified",
                "is_available": doc["is_available"],
            }).execute()

            # Upsert weekly availability
            for avail in doc.get("availability", []):
                supabase.table("weekly_availability").upsert({
                    "doctor_id": user_id,
                    "day_of_week": avail["day_of_week"],
                    "start_time": avail["start_time"],
                    "end_time": avail["end_time"],
                    "slot_duration_minutes": 30,
                }, on_conflict="doctor_id,day_of_week").execute()

            # Trigger embedding
            await embed_doctor(user_id, doc)

            print(f"  ✓ Done: {doc['full_name']}")
        except Exception as e:
            print(f"  ✗ Error seeding {doc['full_name']}: {e}")

    print("\n=== Seeding Test Users ===")
    for user in USERS:
        print(f"Seeding {user['role']}: {user['full_name']}...")
        try:
            res = supabase.auth.admin.create_user({
                "email": user["email"],
                "password": user["password"],
                "email_confirm": True,
                "user_metadata": {"full_name": user["full_name"], "role": user["role"]},
            })
            user_id = res.user.id
            supabase.table("profiles").upsert({
                "id": user_id,
                "full_name": user["full_name"],
                "email": user["email"],
                "role": user["role"],
            }).execute()
            print(f"  ✓ Done: {user['full_name']}")
        except Exception as e:
            print(f"  ✗ Error: {e}")

    print("\n✅ Seeding complete!")


if __name__ == "__main__":
    asyncio.run(seed())
