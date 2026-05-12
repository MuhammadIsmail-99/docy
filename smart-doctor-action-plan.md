# Smart Doctor Connect AI — Complete Action Plan
**Stack:** Next.js 14 (App Router) · FastAPI · Supabase · Gemini API · Resend · shadcn/ui

---


**t00** — Initialize Next.js 14 project with App Router
```bash
npx create-next-app@latest smart-doctor --typescript --tailwind --app --src-dir
```
Install core dependencies:
```bash
npm install @supabase/supabase-js @supabase/ssr shadcn-ui framer-motion resend lucide-react
npx shadcn-ui@latest init
```

**t01** — Initialize FastAPI project
```
/backend
  main.py
  routers/
    ai.py         # All Gemini routes
    slots.py      # Slot generation logic
    chat.py       # Chat AI logic
    email.py      # Resend email triggers
  services/
    gemini.py     # Gemini client wrapper
    triage.py     # Symptom extraction logic
    embeddings.py # pgvector embedding pipeline
  models/
    schemas.py    # Pydantic models
  requirements.txt
```
Install:
```bash
pip install fastapi uvicorn google-generativeai supabase python-dotenv pydantic resend
```

**t02** — Set up environment variables
Next.js `.env.local`:
```
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
NEXT_PUBLIC_FASTAPI_URL=http://localhost:8000
```
FastAPI `.env`:
```
SUPABASE_URL=
SUPABASE_SERVICE_ROLE_KEY=
GEMINI_API_KEY=
RESEND_API_KEY=
```

**t03** — Set up Supabase project
- Enable pgvector extension in Supabase SQL editor: `CREATE EXTENSION vector;`
- Enable Realtime on tables: `conversations`, `messages`, `appointments`, `triage_briefs`
- Enable pg_cron extension: `CREATE EXTENSION pg_cron;`
- Copy project URL and anon/service role keys to env files

**t04** — Set up Next.js route structure
```
/src/app
  /(public)
    page.tsx              # Landing page
    search/page.tsx       # Search results
    doctor/[id]/page.tsx  # Doctor profile
  /patient
    dashboard/page.tsx
    appointments/page.tsx
    chat/page.tsx
  /doctor
    dashboard/page.tsx
    profile/page.tsx
    appointments/page.tsx
    availability/page.tsx
    chat/[patientId]/page.tsx
  /admin
    page.tsx              # Approval queue
  /auth
    login/page.tsx
    register/page.tsx
    register-doctor/page.tsx
layout.tsx
```

**t05** — Set up FastAPI CORS and router structure
```python
# main.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers import ai, slots, chat, email

app = FastAPI()
app.add_middleware(CORSMiddleware, allow_origins=["http://localhost:3000"], ...)
app.include_router(ai.router, prefix="/ai")
app.include_router(slots.router, prefix="/slots")
app.include_router(chat.router, prefix="/chat")
app.include_router(email.router, prefix="/email")
```

---
## PHASE 1 — Database Schema

**t06** — Create `users` table (extends Supabase auth.users)
```sql
CREATE TABLE public.profiles (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  full_name TEXT NOT NULL,
  phone TEXT,
  role TEXT CHECK (role IN ('patient', 'doctor', 'admin')) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**t07** — Create `doctors` table
```sql
CREATE TABLE public.doctors (
  id UUID REFERENCES public.profiles(id) PRIMARY KEY,
  specialization TEXT NOT NULL,
  city TEXT NOT NULL,
  consultation_type TEXT CHECK (consultation_type IN ('online', 'physical', 'both')) NOT NULL,
  experience_years INTEGER,
  consultation_fee INTEGER,
  bio TEXT,
  profile_picture_url TEXT,
  rating DECIMAL(3,2) DEFAULT 0.00,
  review_count INTEGER DEFAULT 0,
  pmdc_number TEXT,
  verification_status TEXT CHECK (verification_status IN ('pending', 'verified', 'rejected')) DEFAULT 'pending',
  is_available BOOLEAN DEFAULT FALSE,
  embedding VECTOR(768),
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**t08** — Create `weekly_availability` table
```sql
CREATE TABLE public.weekly_availability (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  doctor_id UUID REFERENCES public.doctors(id) ON DELETE CASCADE,
  day_of_week INTEGER CHECK (day_of_week BETWEEN 0 AND 6), -- 0=Sunday
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  slot_duration_minutes INTEGER DEFAULT 30,
  UNIQUE(doctor_id, day_of_week)
);
```

**t09** — Create `appointments` table
```sql
CREATE TABLE public.appointments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID REFERENCES public.profiles(id),
  doctor_id UUID REFERENCES public.doctors(id),
  appointment_time TIMESTAMPTZ NOT NULL,
  duration_minutes INTEGER DEFAULT 30,
  type TEXT CHECK (type IN ('online', 'physical')),
  status TEXT CHECK (status IN ('pending', 'confirmed', 'cancelled', 'completed')) DEFAULT 'pending',
  chief_complaint TEXT,
  notes TEXT,
  meet_link TEXT,
  pre_reminder_sent BOOLEAN DEFAULT FALSE,
  post_reminder_sent BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**t10** — Create `conversations` and `messages` tables
```sql
CREATE TABLE public.conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID REFERENCES public.profiles(id),
  doctor_id UUID REFERENCES public.doctors(id),
  ai_active BOOLEAN DEFAULT TRUE,
  intake_complete BOOLEAN DEFAULT FALSE,
  triage_data JSONB,          -- stores extracted: name, contact, complaint, duration, severity
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID REFERENCES public.conversations(id) ON DELETE CASCADE,
  sender_role TEXT CHECK (sender_role IN ('patient', 'doctor', 'ai')),
  content TEXT NOT NULL,
  is_red_flag BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**t11** — Create `triage_briefs` table (Realtime enabled)
```sql
CREATE TABLE public.triage_briefs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID REFERENCES public.conversations(id),
  doctor_id UUID REFERENCES public.doctors(id),
  patient_name TEXT,
  patient_contact TEXT,
  chief_complaint TEXT,
  duration TEXT,
  severity TEXT,
  red_flags BOOLEAN DEFAULT FALSE,
  soap_note TEXT,
  status TEXT CHECK (status IN ('new', 'reviewed', 'dismissed')) DEFAULT 'new',
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**t12** — Set up Row Level Security (RLS) policies
```sql
-- Doctors can only read/write their own data
ALTER TABLE public.doctors ENABLE ROW LEVEL SECURITY;
CREATE POLICY "doctors_own_data" ON public.doctors
  FOR ALL USING (auth.uid() = id);

-- Patients can read all verified doctors
CREATE POLICY "patients_read_doctors" ON public.doctors
  FOR SELECT USING (verification_status = 'verified');

-- Messages: only conversation participants can read
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "conversation_participants" ON public.messages
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM conversations c
      WHERE c.id = conversation_id
      AND (c.patient_id = auth.uid() OR c.doctor_id = auth.uid())
    )
  );
```

---

## PHASE 2 — Authentication

**t13** — Build `/auth/login` page
- Email + password login form using shadcn `<Input>` and `<Button>`
- Supabase `signInWithPassword()`
- On success: check `profiles.role` → redirect to `/patient/dashboard` or `/doctor/dashboard` or `/admin`
- Error states: wrong password, unverified email

**t14** — Build `/auth/register` page (Patient)
- Fields: full name, email, phone, password
- On submit: `supabase.auth.signUp()` → insert into `profiles` with `role: 'patient'`
- Redirect to `/patient/dashboard`

**t15** — Build `/auth/register-doctor` page
- Fields: full name, email, phone, password, specialization, city, consultation type, experience, fee, bio, PMDC number, profile picture upload
- On submit:
  - `supabase.auth.signUp()`
  - Insert into `profiles` with `role: 'doctor'`
  - Insert into `doctors` with `verification_status: 'pending'`
  - Upload profile picture to Supabase Storage bucket `doctor-avatars`
- Show: "Your profile is under review. We'll notify you once approved."

**t16** — Build auth middleware (Next.js middleware.ts)
```typescript
// Protect /patient/*, /doctor/*, /admin/* routes
// Redirect unauthenticated users to /auth/login
// Redirect wrong-role users to their correct dashboard
// Admin route: check role === 'admin' only
```

---

## PHASE 3 — Doctor Profiles & Admin

**t17** — Build doctor seed script
```typescript
// scripts/seed-doctors.ts
// 10-12 fake verified doctors across specializations:
// Cardiologist, Dermatologist, Orthopedic, Neurologist,
// Psychiatrist, Gynecologist, Pediatrician, General Physician
// Cities: Lahore, Karachi, Islamabad, Rawalpindi
// Pre-populate: ratings (3.5–5.0), review counts, availability schedule
// Run embedding pipeline immediately after insert (call FastAPI /ai/embed-doctor)
```

**t18** — Build FastAPI embedding endpoint
```python
# POST /ai/embed-doctor
# Input: { doctor_id, specialization, city, bio, experience }
# Process: Concatenate fields into a rich text string
# Call Gemini text-embedding-004 model
# Store 768-dim vector in doctors.embedding column
# Run this for every doctor on insert (seed + registration)
```

**t19** — Build `/admin` page — Approval Queue
- Password-protected (hardcoded admin credentials for hackathon)
- Lists all doctors with `verification_status: 'pending'`
- Shows: name, specialization, city, PMDC number
- "Approve" button → updates `verification_status: 'verified'` + triggers embedding via FastAPI
- "Reject" button → updates `verification_status: 'rejected'`
- Simple table layout, no fancy UI needed

**t20** — Build `/doctor/profile` page — Edit Profile
- Pre-filled form with existing doctor data
- Editable fields: bio, fee, consultation type, profile picture
- Specialization and city locked after approval
- Save button → update `doctors` table + re-embed via FastAPI

**t21** — Build `/doctor/availability` page — Weekly Schedule
- 7-day grid (Sun–Sat)
- For each day: toggle active/inactive + time range picker (start time, end time)
- Slot duration selector: 15 / 30 / 45 / 60 minutes
- Save → upsert into `weekly_availability` table
- Live "Available Now" toggle at the top: updates `doctors.is_available` instantly

---

## PHASE 4 — Search & AI Suggestions

**t22** — Build specialties cache in FastAPI startup
```python
# On FastAPI startup event:
# Fetch all distinct specializations from doctors table
# Store in memory as a module-level variable
# Refresh every 30 minutes via background task
# Endpoint: GET /ai/specialties → returns cached list
```

**t23** — Build FastAPI Gemini specialty mapping endpoint
```python
# POST /ai/suggest-specialties
# Input: { query: "back pain", available_specialties: [...] }
# System prompt:
#   "You are a medical triage assistant. Given a patient's search query
#    and a list of available specializations, return ONLY the 1-3 most
#    relevant specializations as a JSON array. No explanation.
#    Include a one-sentence reasoning string for each match.
#    Example output: [{"specialty": "Orthopedic", "reason": "Back pain is typically managed by orthopedic specialists"}]"
# Return: JSON array of { specialty, reason }
```

**t24** — Build FastAPI pgvector semantic search endpoint
```python
# POST /ai/search-doctors
# Input: { query, specialties: [], city?: "", available_only: bool }
# Process:
#   1. Embed the search query using Gemini text-embedding-004
#   2. For each specialty returned from /suggest-specialties:
#      SELECT doctors.*, (embedding <=> query_vector) as similarity
#      FROM doctors
#      WHERE specialization = specialty
#        AND verification_status = 'verified'
#        AND (available_only = false OR is_available = true)
#      ORDER BY similarity ASC, rating DESC
#      LIMIT 3
#   3. Return grouped results: { specialty, reason, doctors: [...] }
```

**t25** — Build search bar component (persistent in navbar)
- Single text input with search icon
- On submit: POST to `/ai/search-doctors` via FastAPI
- Show loading skeleton while waiting
- Available Only toggle button (boolean state, passed to API)
- Lives in `<Navbar>` component rendered on all public + patient pages

**t26** — Build `/search` results page
- Receives query as URL param: `/search?q=back+pain&available=true`
- Grouped by specialty with heading: "Cardiologist — recommended because chest pain..."
- Per doctor card:
  - Profile picture (avatar fallback if none)
  - Name + specialization badge
  - City + consultation type (Online / Physical / Both)
  - Experience years
  - Consultation fee (PKR)
  - Star rating + review count
  - Green "Available Now" dot if `is_available: true`
  - "Earliest: Tomorrow 10am" (from waiting time estimate — see t50)
  - "Book Now" button → `/doctor/[id]`
- Empty state: "No doctors found. Try a different symptom or city."

---

## PHASE 5 — Doctor Profile Page

**t27** — Build `/doctor/[id]` public profile page
Sections:
1. Hero: photo, name, specialization, city, rating, fee, availability badge
2. About: bio, experience, consultation type
3. Weekly schedule display (read-only, shows available days/times)
4. "Book Now" button (fixed sticky bottom bar on mobile)
5. Chat widget popup (see t33)

**t28** — Build waiting time estimate display
```python
# GET /slots/earliest?doctor_id=xxx
# Query weekly_availability for doctor
# Query appointments for confirmed slots
# Find next available 30-min window from NOW
# Return: { earliest_slot: "2025-05-13T10:00:00", label: "Tomorrow 10:00 AM" }
```
Display this on both the doctor card (search results) and the doctor profile page.

---

## PHASE 6 — Chat System

**t29** — Build Supabase Realtime chat hook
```typescript
// hooks/useChat.ts
// Subscribe to messages WHERE conversation_id = currentConversation
// New message arrives → append to local state instantly
// Used by both patient chat widget and doctor dashboard chat
```

**t30** — Build FastAPI intake triage AI endpoint
```python
# POST /chat/ai-respond
# Input: { conversation_id, message, triage_data_so_far }
# Check: fetch conversation.ai_active — if FALSE, return null (doctor has taken over)
# System prompt:
#   "You are an empathetic medical intake assistant for a Pakistani clinic.
#    Patients may write in Urdu, English, or Roman Urdu — respond in the same language.
#    Your goal: extract chief_complaint, duration, severity (1-10), and contact number.
#    Ask ONE question at a time. Be warm and professional.
#    When all 4 fields are collected, output EXACTLY:
#    [INTAKE_COMPLETE] followed by a JSON object:
#    { chief_complaint, duration, severity, contact, patient_name }
#    NEVER provide medical diagnoses. Add: 'This is not medical advice.'"
# If message contains red flag keywords (chest pain, severe bleeding, can't breathe,
#   unconscious, stroke, heart attack) → return [RED_FLAG] immediately
# Stream response back to frontend
```

**t31** — Build red flag detection logic
```python
# Inside /chat/ai-respond, BEFORE calling Gemini:
# Check message against red flag keyword list
# If match: return special response immediately without LLM call (faster + safer)
# Response: "⚠️ Your symptoms may require immediate attention.
#            Please visit the nearest emergency room or call 1122 immediately.
#            Do not wait for an appointment."
# Set messages.is_red_flag = TRUE in database
# Do NOT proceed with booking flow
```

**t32** — Build SOAP note generation endpoint
```python
# POST /chat/generate-soap
# Triggered when [INTAKE_COMPLETE] is detected
# Input: { triage_data: { chief_complaint, duration, severity, contact } }
# Prompt Gemini to format as SOAP note:
#   Subjective: patient's complaint in their words
#   Objective: severity score, duration
#   Assessment: likely condition categories (NOT diagnosis)
#   Plan: recommended specialist type
# Store in triage_briefs table
# Trigger email to doctor (call /email/notify-doctor)
```

**t33** — Build per-doctor chat widget (patient-facing)
- Fixed bottom-right popup on `/doctor/[id]` page
- Trigger: appears after 8 seconds on page OR after scrolling past doctor info section
- Opening message: "👋 Hi! I'm the Smart Booking Assistant for Dr. [Name]. Tell me what brings you in today."
- Chat bubble UI: patient messages right-aligned, AI messages left-aligned
- Red flag response: shows red warning card with ER direction, chat ends
- On [INTAKE_COMPLETE]: show "✅ Your information has been received. Book your appointment below." + reveal booking CTA
- Doctor takeover: AI messages stop, doctor name appears as sender

**t34** — Build doctor dashboard chat view
- `/doctor/chat/[patientId]` page
- Shows full conversation history
- "Take Over" button → sets `conversations.ai_active = FALSE`
- Text input for doctor replies → inserts message with `sender_role: 'doctor'`
- "Hand Back to AI" button → sets `conversations.ai_active = TRUE`
- Unread badge on dashboard nav when new triage brief arrives

**t35** — Build app-wide chatbot (separate instance)
- Floating button bottom-right on ALL pages (except doctor chat page)
- Opens a drawer/modal
- Separate Gemini instance, separate system prompt:
  ```
  "You are the Smart Doctor Connect AI assistant.
   You help patients find doctors, understand specializations,
   learn about the platform, and answer general health questions.
   For general health questions, always end with:
   'This is general information only. Please consult a qualified doctor for medical advice.'
   You have access to these specializations available on the platform: [cached list].
   Never diagnose. Never recommend specific medications."
  ```
- Maintains conversation history in component state (not database)
- POST `/chat/app-chatbot` FastAPI endpoint

---

## PHASE 7 — Appointment Booking

**t36** — Build slot generation endpoint
```python
# GET /slots/available?doctor_id=xxx&count=3
# 1. Fetch doctor's weekly_availability
# 2. Fetch confirmed appointments for next 14 days
# 3. Generate all possible slots from weekly schedule
# 4. Remove already-booked slots
# 5. Remove slots in the past
# 6. Return next {count} available slots as array:
#    [{ slot_id, datetime, label: "Tomorrow, 10:00 AM", type: "online" }]
```

**t37** — Build booking flow component
Triggered from two entry points:
- "Book Now" button on doctor card / profile
- CTA revealed after chat intake completes

Flow:
1. **Slot selection screen**: Shows 3 AI-generated slots as selectable cards with date/time/type
2. **Pre-fill check**: If conversation exists → pre-fill patient info. If not → show inline mini-form (name, contact, chief complaint)
3. **Confirmation screen**: Summary card — doctor name, slot, type, fee, patient complaint
4. **Mock payment screen**: "PKR [fee] — Payment Pending" with a "Confirm Booking" button (no real gateway)
5. On confirm: POST to `/appointments` → status: `pending` (awaiting doctor approval)
6. **Status screen**: "⏳ Your booking request has been sent to Dr. [Name]. Awaiting confirmation." with Supabase Realtime listener — updates live when doctor approves

**t38** — Build doctor appointment approval on dashboard
- New appointment requests appear as cards in `/doctor/dashboard`
- Card shows: patient name, complaint, requested slot, type
- "Approve" button:
  - Updates `appointments.status = 'confirmed'`
  - Generates mock Google Meet link if online: `meet.google.com/mock-[random]`
  - Triggers confirmation email to patient via Resend
  - Patient's status screen updates live via Supabase Realtime
- "Decline" button:
  - Updates `appointments.status = 'cancelled'`
  - Patient gets notified

**t39** — Build Resend email service (FastAPI)
```python
# POST /email/notify-doctor
# Triggered: when triage brief is complete
# To: doctor's email
# Subject: "New Patient Inquiry — [Chief Complaint]"
# Body: SOAP note + patient contact + link to dashboard

# POST /email/confirm-appointment
# Triggered: when doctor approves
# To: patient's email
# Subject: "Appointment Confirmed with Dr. [Name]"
# Body: date/time, type, fee, meet link (if online), clinic address (if physical)
```

**t40** — Build pg_cron reminder jobs
```sql
-- Pre-appointment reminder: fires every hour, checks appointments in next 24h
SELECT cron.schedule(
  'pre-appointment-reminder',
  '0 * * * *',
  $$
  SELECT net.http_post(
    url := 'http://your-fastapi-url/email/pre-reminder',
    body := '{}',
    headers := '{"Content-Type": "application/json"}'
  )
  FROM appointments
  WHERE appointment_time BETWEEN NOW() + INTERVAL '23 hours'
    AND NOW() + INTERVAL '24 hours'
    AND status = 'confirmed'
    AND pre_reminder_sent = FALSE;
  $$
);

-- Post-appointment feedback: fires every hour, checks appointments 1h ago
SELECT cron.schedule(
  'post-appointment-feedback',
  '0 * * * *',
  $$
  SELECT net.http_post(...)
  FROM appointments
  WHERE appointment_time BETWEEN NOW() - INTERVAL '2 hours'
    AND NOW() - INTERVAL '1 hour'
    AND status = 'confirmed'
    AND post_reminder_sent = FALSE;
  $$
);
```

```python
# FastAPI handles the cron callbacks:
# POST /email/pre-reminder → send "Your appointment is tomorrow at [time]"
# POST /email/post-reminder → send "How was your visit? [Feedback link]"
# Both check appointment.status === 'confirmed' before sending
# Both set reminder_sent = TRUE after sending (prevents duplicates)
```

**t41** — Build patient appointments page `/patient/appointments`
- Lists all appointments with status badges: Pending / Confirmed / Cancelled / Completed
- Confirmed online appointments show Meet link
- Cancel button (only for Pending status, > 2 hours before slot)
- Reschedule button → re-opens slot selection with same doctor

---

## PHASE 8 — Extra AI Features

**t42** — Wire AI reasoning explanation into search results
- Modify `/ai/search-doctors` response to include `reason` field per specialty group
- Display as subtle italic text under each specialty heading:
  *"Based on your symptoms, we identified Orthopedic specialists as most relevant because back pain is commonly associated with musculoskeletal issues."*

**t43** — Build visible async confirmation status screen
- `/patient/booking/status/[appointmentId]` page
- Supabase Realtime listener on `appointments` table for this ID
- Status states with visual progression:
  1. ⏳ "Sent to Dr. [Name]" — pending
  2. ✅ "Confirmed! See details below" — confirmed (auto-updates without refresh)
  3. ❌ "Declined. Choose another slot?" — cancelled
- This is your **biggest demo moment** — show this updating live

**t44** — Build waiting time estimate on doctor cards
- Call `GET /slots/earliest?doctor_id=xxx` for each doctor in search results
- Display: "Earliest: Today 4pm" or "Earliest: Tomorrow 10am" on card
- Cache per doctor for 5 minutes to avoid N+1 API calls on search results

---

## PHASE 9 — UI & Design System

**t45** — Set up design tokens (globals.css)
Theme: Clean medical trust — dark navy + teal accent, not generic purple
```css
:root {
  --font-display: 'Space Grotesk', sans-serif;
  --font-body: 'Inter', sans-serif;
  --weight-light: 300;
  --weight-black: 900;

  --bg-primary: #0d1117;
  --bg-secondary: #161b22;
  --bg-card: #1c2333;
  --accent-1: #2dd4bf;      /* Teal — primary CTA */
  --accent-2: #f59e0b;      /* Amber — ratings */
  --accent-danger: #ef4444; /* Red — emergency/red flag */
  --accent-success: #22c55e;/* Green — available/confirmed */
  --text-primary: #f0f6fc;
  --text-secondary: #8b949e;

  --ease: cubic-bezier(0.16, 1, 0.3, 1);
}
```

**t46** — Build shared component library
- `<DoctorCard />` — used in search results and dashboard
- `<ChatWidget />` — per-doctor popup (reused in patient view)
- `<AppointmentCard />` — used in patient + doctor dashboards
- `<StatusBadge />` — pending / confirmed / cancelled / available
- `<Navbar />` — with search bar, role-aware nav links, auth state
- `<TriageBriefCard />` — doctor dashboard, shows SOAP note + approve/decline

**t47** — Add staggered page-load animations
```typescript
// Apply to: search results cards, dashboard cards, doctor profile sections
// Use Framer Motion variants with staggerChildren: 0.08
// Entrance: fadeInUp with 30px Y offset, 0.6s duration
```

**t48** — Mobile responsiveness
- Search results: single column on mobile, 2-col on tablet, 3-col on desktop
- Chat widget: full-screen on mobile, popup on desktop
- Doctor dashboard: collapsible sidebar on mobile
- Booking flow: full-screen modal on mobile

---

## PHASE 10 — Demo Prep & Polish

**t49** — Seed script final run
- Verify 10–12 doctors are seeded with embeddings
- Verify weekly schedules are set for all seeded doctors
- Verify is_available is true for at least 5 of them
- Verify ratings range from 3.5 to 5.0
- Test one full search: "chest pain" → should return Cardiologist group

**t50** — End-to-end demo flow test
Walk through the exact demo sequence judges will see:
1. Patient searches "back pain" → grouped results appear with AI reasoning
2. Patient clicks doctor → profile page loads, chat popup appears after 8s
3. Patient chats → AI collects intake → SOAP note generated
4. Patient selects slot → mock payment → status screen shows "Pending"
5. Open doctor dashboard in second tab → approve appointment
6. Patient status screen updates LIVE without refresh ← this is your wow moment
7. Confirmation email arrives in patient inbox

**t51** — Stress test red flag detection
- Type "chest pain" in chat → should immediately show ER redirect card
- Type "I can't breathe" → same
- Type "back pain" → should NOT trigger red flag, proceed normally

**t52** — Verify email delivery via Resend
- Test triage complete email to doctor
- Test appointment confirmation email to patient
- Test pre-appointment reminder manually
- Check Resend dashboard for delivery logs

**t53** — Build landing page `/`
Above the fold:
- Headline: "Find the Right Doctor. Instantly."
- Subline: "AI-powered doctor matching for Pakistan"
- Single search bar (same component as navbar) — center stage
- 3 stat cards: "25,000+ Doctors" / "40+ Specializations" / "AI-Powered Matching"

Below the fold:
- How it works: 3-step visual (Search → Chat → Book)
- Featured specializations grid
- CTA: "Are you a doctor? List your practice →"

**t54** — Prepare pitch demo script
Key talking points to surface during demo:
1. **The gap**: "Every Pakistani platform charges you first, then the doctor isn't there. We flip this."
2. **The differentiator**: Show the async confirmation status screen updating live
3. **The AI**: Show Gemini grouping search results by specialty with reasoning
4. **The safety**: Trigger red flag detection live — "chest pain" → ER redirect instantly
5. **The scale**: "Built on Supabase + FastAPI + Gemini — production-ready architecture"

---

## Task Summary by Phase

| Phase | Tasks | Description |
|-------|-------|-------------|
| 0 — Setup | t00–t05 | Project init, env, route structure |
| 1 — Schema | t06–t12 | All Supabase tables + RLS policies |
| 2 — Auth | t13–t16 | Login, patient register, doctor register, middleware |
| 3 — Doctor Profiles | t17–t21 | Seed, embed, admin approval, profile edit, availability |
| 4 — Search | t22–t26 | Specialty cache, Gemini mapping, pgvector search, UI |
| 5 — Doctor Profile Page | t27–t28 | Public profile, waiting time estimate |
| 6 — Chat System | t29–t35 | Realtime hook, triage AI, red flag, SOAP note, widgets, app chatbot |
| 7 — Booking | t36–t41 | Slot gen, booking flow, approval, emails, cron reminders, patient dashboard |
| 8 — Extra AI | t42–t44 | Reasoning display, live status screen, waiting time |
| 9 — UI/Design | t45–t48 | Design tokens, components, animations, mobile |
| 10 — Demo Prep | t49–t54 | Seed verify, E2E test, red flag test, email test, landing page, pitch |

**Total tasks: t00 → t54 (55 tasks)**
