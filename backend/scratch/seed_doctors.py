import sys
import os
import asyncio
import random
from supabase import create_client, Client
import google.generativeai as genai

# Add parent directory to sys.path to import app modules
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app.core.config import settings

supabase: Client = create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_ROLE_KEY)
genai.configure(api_key=settings.GEMINI_API_KEY)

async def get_embedding(text):
    result = genai.embed_content(
        model="models/text-embedding-004",
        content=text,
        task_type="retrieval_document",
        title="Doctor Profile"
    )
    return result['embedding']

first_names = ["Ahmed", "Sara", "Usman", "Arlene", "Watson", "Zain", "Fatima", "Ali", "Hassan", "Ayesha", "Bilal", "Sana", "Kamran", "Mehak", "Hamza", "Dua", "Mustafa", "Noor", "Omar", "Hina"]
last_names = ["Hassan", "Khan", "Ali", "Mccoy", "Karistin", "Javed", "Ahmed", "Butt", "Sheikh", "Malik", "Iqbal", "Raza", "Latif", "Chaudhry"]
specialties = ["Cardiologist", "Dermatologist", "Gynecologist", "Pediatrician", "Orthopedic Surgeon", "General Physician", "Neurologist", "Psychiatrist", "Ophthalmologist", "ENT Specialist"]
cities = ["Lahore", "Karachi", "Islamabad", "Faisalabad", "Rawalpindi", "Multan"]

async def seed():
    print(f"Starting seed of 30 doctors...")
    for i in range(30):
        try:
            first = random.choice(first_names)
            last = random.choice(last_names)
            name = f"Dr. {first} {last}"
            email = f"dr.{first.lower()}.{last.lower()}.{i}@example.com"
            password = "password123"
            
            # 1. Create User in Auth
            user_res = supabase.auth.admin.create_user({
                "email": email,
                "password": password,
                "email_confirm": True,
                "user_metadata": {"full_name": name, "role": "doctor"}
            })
            user_id = user_res.user.id
            
            # 2. Insert into Profiles
            supabase.table("profiles").insert({
                "id": user_id,
                "full_name": name,
                "email": email,
                "role": "doctor"
            }).execute()
            
            # 3. Insert into Doctors
            spec = random.choice(specialties)
            city = random.choice(cities)
            fee = random.choice([1000, 1500, 2000, 2500, 3000, 5000])
            exp = random.randint(3, 25)
            bio = f"Experienced {spec} based in {city} with over {exp} years of practice. Dedicated to providing the best patient care and specialized treatments."
            
            embedding = await get_embedding(f"Doctor Name: {name}\nSpecialization: {spec}\nCity: {city}\nBio: {bio}\nExperience: {exp} years")
            
            supabase.table("doctors").insert({
                "id": user_id,
                "specialization": spec,
                "city": city,
                "consultation_type": "both",
                "experience_years": exp,
                "consultation_fee": fee,
                "bio": bio,
                "rating": round(random.uniform(3.5, 5.0), 1),
                "review_count": random.randint(10, 200),
                "verification_status": "verified",
                "is_available": True,
                "embedding": embedding
            }).execute()
            
            # 4. Add weekly availability
            for day in range(1, 6): # Mon-Fri
                supabase.table("weekly_availability").insert({
                    "doctor_id": user_id,
                    "day_of_week": day,
                    "start_time": "09:00:00",
                    "end_time": "17:00:00",
                    "slot_duration_minutes": 30
                }).execute()
                
            print(f"[{i+1}/30] Seeded: {name} ({spec})")
            await asyncio.sleep(0.5) # Small delay
            
        except Exception as e:
            print(f"Error seeding doctor {i}: {e}")

    print("Seeding completed!")

if __name__ == "__main__":
    asyncio.run(seed())
