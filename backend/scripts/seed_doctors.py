import asyncio
from supabase import create_client, Client
import os
from dotenv import load_dotenv

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

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
        "bio": "Experienced cardiologist specializing in heart failure and preventive cardiology.",
        "pmdc_number": "PMDC-12345",
        "rating": 4.8,
        "review_count": 150
    },
    {
        "email": "derm1@example.com",
        "full_name": "Dr. Sara Khan",
        "specialization": "Dermatologist",
        "city": "Karachi",
        "consultation_type": "online",
        "experience_years": 8,
        "consultation_fee": 2000,
        "bio": "Expert in clinical and aesthetic dermatology with a focus on skin cancer screening.",
        "pmdc_number": "PMDC-67890",
        "rating": 4.6,
        "review_count": 85
    },
    {
        "email": "ortho1@example.com",
        "full_name": "Dr. Usman Ali",
        "specialization": "Orthopedic",
        "city": "Islamabad",
        "consultation_type": "physical",
        "experience_years": 15,
        "consultation_fee": 2500,
        "bio": "Specialist in joint replacement and sports medicine.",
        "pmdc_number": "PMDC-11223",
        "rating": 4.9,
        "review_count": 210
    }
]

USERS = [
    {
        "email": "testpatient@example.com",
        "full_name": "Test Patient",
        "password": "Password123!",
        "role": "patient"
    },
    {
        "email": "admin@example.com",
        "full_name": "Admin User",
        "password": "AdminPassword123!",
        "role": "admin"
    }
]

async def seed():
    # Seed Doctors
    for doc in DOCTORS:
        print(f"Seeding doctor: {doc['full_name']}...")
        try:
            res = supabase.auth.admin.create_user({
                "email": doc["email"],
                "password": "Password123!",
                "email_confirm": True,
                "user_metadata": {"full_name": doc["full_name"], "role": "doctor"}
            })
            user_id = res.user.id
            
            supabase.table("profiles").upsert({
                "id": user_id,
                "full_name": doc["full_name"],
                "email": doc["email"],
                "role": "doctor"
            }).execute()
            
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
                "is_available": True
            }).execute()
            print(f"Successfully seeded doctor: {doc['full_name']}")
        except Exception as e:
            print(f"Error seeding doctor {doc['full_name']}: {e}")

    # Seed Patients and Admins
    for user in USERS:
        print(f"Seeding {user['role']}: {user['full_name']}...")
        try:
            res = supabase.auth.admin.create_user({
                "email": user["email"],
                "password": user["password"],
                "email_confirm": True,
                "user_metadata": {"full_name": user["full_name"], "role": user["role"]}
            })
            user_id = res.user.id
            
            supabase.table("profiles").upsert({
                "id": user_id,
                "full_name": user["full_name"],
                "email": user["email"],
                "role": user["role"]
            }).execute()
            print(f"Successfully seeded {user['role']}: {user['full_name']}")
        except Exception as e:
            print(f"Error seeding {user['role']} {user['full_name']}: {e}")

if __name__ == "__main__":
    asyncio.run(seed())
