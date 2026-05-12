-- Enable Extensions
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- t06: Create profiles table
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  full_name TEXT NOT NULL,
  email TEXT UNIQUE,
  phone TEXT,
  role TEXT CHECK (role IN ('patient', 'doctor', 'admin')) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- t07: Create doctors table
CREATE TABLE IF NOT EXISTS public.doctors (
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

-- t08: Create weekly_availability table
CREATE TABLE IF NOT EXISTS public.weekly_availability (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  doctor_id UUID REFERENCES public.doctors(id) ON DELETE CASCADE,
  day_of_week INTEGER CHECK (day_of_week BETWEEN 0 AND 6), -- 0=Sunday
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  slot_duration_minutes INTEGER DEFAULT 30,
  UNIQUE(doctor_id, day_of_week)
);

-- t09: Create appointments table
CREATE TABLE IF NOT EXISTS public.appointments (
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

-- t10: Create conversations and messages tables
CREATE TABLE IF NOT EXISTS public.conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID REFERENCES public.profiles(id),
  doctor_id UUID REFERENCES public.doctors(id),
  ai_active BOOLEAN DEFAULT TRUE,
  intake_complete BOOLEAN DEFAULT FALSE,
  triage_data JSONB,          -- stores extracted: name, contact, complaint, duration, severity
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID REFERENCES public.conversations(id) ON DELETE CASCADE,
  sender_role TEXT CHECK (sender_role IN ('patient', 'doctor', 'ai')),
  content TEXT NOT NULL,
  is_red_flag BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- t11: Create triage_briefs table
CREATE TABLE IF NOT EXISTS public.triage_briefs (
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

-- t12: Set up Row Level Security (RLS) policies
-- Profiles RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "profiles_read_own" ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "profiles_update_own" ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- Doctors RLS
ALTER TABLE public.doctors ENABLE ROW LEVEL SECURITY;
CREATE POLICY "doctors_own_data" ON public.doctors FOR ALL USING (auth.uid() = id);
CREATE POLICY "patients_read_doctors" ON public.doctors FOR SELECT USING (verification_status = 'verified');

-- Appointments RLS
ALTER TABLE public.appointments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "appointment_participants" ON public.appointments FOR ALL USING (patient_id = auth.uid() OR doctor_id = auth.uid());

-- Conversations RLS
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "conversation_participants" ON public.conversations FOR ALL USING (patient_id = auth.uid() OR doctor_id = auth.uid());

-- Messages RLS
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "message_access" ON public.messages FOR ALL USING (
    EXISTS (
      SELECT 1 FROM conversations c
      WHERE c.id = conversation_id
      AND (c.patient_id = auth.uid() OR c.doctor_id = auth.uid())
    )
);

-- Triage Briefs RLS
ALTER TABLE public.triage_briefs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "brief_access" ON public.triage_briefs FOR ALL USING (
    doctor_id = auth.uid() OR 
    EXISTS (
        SELECT 1 FROM conversations c 
        WHERE c.id = conversation_id AND c.patient_id = auth.uid()
    )
);
