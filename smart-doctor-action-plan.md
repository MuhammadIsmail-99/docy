# Smart Doctor Connect AI — Complete Action Plan (Flutter)
**Stack:** Flutter · FastAPI · Supabase · Gemini API · Gmail SMTP

---

## PHASE 0 — Project Setup

**t00** — Initialize Flutter project
```bash
flutter create smart_doctor_connect
cd smart_doctor_connect
```
Add dependencies to `pubspec.yaml`:
```yaml
dependencies:
  flutter:
    sdk: flutter

  # Supabase
  supabase_flutter: ^2.5.0

  # State management
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

  # Navigation
  go_router: ^13.2.0

  # HTTP client (FastAPI calls)
  dio: ^5.4.3

  # UI
  google_fonts: ^6.2.1
  flutter_animate: ^4.5.0
  cached_network_image: ^3.3.1
  shimmer: ^3.0.0

  # Chat UI
  flutter_chat_ui: ^1.6.15
  flutter_chat_types: ^3.6.2

  # Forms & utilities
  flutter_form_builder: ^9.3.0
  form_builder_validators: ^10.0.1
  intl: ^0.19.0
  shared_preferences: ^2.2.3
  image_picker: ^1.1.2
  timeago: ^3.6.1

  # Misc
  equatable: ^2.0.5
  uuid: ^4.4.0
  url_launcher: ^6.2.6
```
```bash
flutter pub get
```

**t01** — Initialize FastAPI project
```
/backend
  main.py
  routers/
    ai.py           # Gemini specialty mapping + embeddings
    slots.py        # Slot generation logic
    chat.py         # Chat AI triage + app chatbot
    email.py        # Gmail SMTP email triggers
  services/
    gemini.py       # Gemini client wrapper
    triage.py       # Symptom extraction + SOAP note
    embeddings.py   # pgvector embedding pipeline
    smtp.py         # Gmail SMTP service
  models/
    schemas.py      # Pydantic models
  .env
  requirements.txt
```
Install:
```bash
pip install fastapi uvicorn google-generativeai supabase \
  python-dotenv pydantic aiosmtplib email-validator
```

**t02** — Set up environment variables

FastAPI `.env`:
```
SUPABASE_URL=
SUPABASE_SERVICE_ROLE_KEY=
GEMINI_API_KEY=
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your.gmail@gmail.com
SMTP_PASSWORD=your-16-char-app-password
SMTP_SENDER_NAME=Smart Doctor Connect
```

Flutter — create `lib/core/config/app_config.dart`:
```dart
class AppConfig {
  static const supabaseUrl = 'YOUR_SUPABASE_URL';
  static const supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
  static const fastApiUrl = 'http://10.0.2.2:8000'; // Android emulator localhost
  // Use your machine's IP for physical device: 'http://192.168.x.x:8000'
}
```

**t03** — Set up Supabase project
- Enable pgvector: `CREATE EXTENSION vector;`
- Enable Realtime on: `conversations`, `messages`, `appointments`, `triage_briefs`
- Enable pg_cron: `CREATE EXTENSION pg_cron;`
- Enable Storage bucket: `doctor-avatars` (public read, auth write)

**t04** — Initialize Supabase in Flutter
```dart
// lib/main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  runApp(
    ProviderScope(child: SmartDoctorApp()),
  );
}
```

**t05** — Set up FastAPI CORS and router structure
```python
# main.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers import ai, slots, chat, email

app = FastAPI()
app.add_middleware(
  CORSMiddleware,
  allow_origins=["*"],  # Restrict in production
  allow_methods=["*"],
  allow_headers=["*"],
)
app.include_router(ai.router, prefix="/ai")
app.include_router(slots.router, prefix="/slots")
app.include_router(chat.router, prefix="/chat")
app.include_router(email.router, prefix="/email")
```

**t06** — Set up Flutter folder structure
```
lib/
  core/
    config/
      app_config.dart
      router.dart           # GoRouter setup
      theme.dart            # App theme + design tokens
    services/
      supabase_service.dart
      api_service.dart      # Dio wrapper for FastAPI
    providers/
      auth_provider.dart
  features/
    auth/
      screens/
      widgets/
      providers/
    search/
      screens/
      widgets/
      providers/
    doctor_profile/
      screens/
      widgets/
      providers/
    chat/
      screens/
      widgets/
      providers/
    booking/
      screens/
      widgets/
      providers/
    patient_dashboard/
    doctor_dashboard/
    admin/
  shared/
    widgets/
      doctor_card.dart
      appointment_card.dart
      status_badge.dart
      chat_widget.dart
      triage_brief_card.dart
    models/
      doctor.dart
      appointment.dart
      message.dart
      conversation.dart
      triage_brief.dart
```

---

## PHASE 1 — Database Schema

**t07** — Create `profiles` table
```sql
CREATE TABLE public.profiles (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  full_name TEXT NOT NULL,
  phone TEXT,
  role TEXT CHECK (role IN ('patient', 'doctor', 'admin')) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, role)
  VALUES (NEW.id, NEW.raw_user_meta_data->>'full_name',
          NEW.raw_user_meta_data->>'role');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

**t08** — Create `doctors` table
```sql
CREATE TABLE public.doctors (
  id UUID REFERENCES public.profiles(id) PRIMARY KEY,
  specialization TEXT NOT NULL,
  city TEXT NOT NULL,
  consultation_type TEXT CHECK (
    consultation_type IN ('online', 'physical', 'both')
  ) NOT NULL,
  experience_years INTEGER,
  consultation_fee INTEGER,
  bio TEXT,
  profile_picture_url TEXT,
  rating DECIMAL(3,2) DEFAULT 0.00,
  review_count INTEGER DEFAULT 0,
  pmdc_number TEXT,
  verification_status TEXT CHECK (
    verification_status IN ('pending', 'verified', 'rejected')
  ) DEFAULT 'pending',
  is_available BOOLEAN DEFAULT FALSE,
  embedding VECTOR(768),
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**t09** — Create `weekly_availability` table
```sql
CREATE TABLE public.weekly_availability (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  doctor_id UUID REFERENCES public.doctors(id) ON DELETE CASCADE,
  day_of_week INTEGER CHECK (day_of_week BETWEEN 0 AND 6),
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  slot_duration_minutes INTEGER DEFAULT 30,
  UNIQUE(doctor_id, day_of_week)
);
```

**t10** — Create `appointments` table
```sql
CREATE TABLE public.appointments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID REFERENCES public.profiles(id),
  doctor_id UUID REFERENCES public.doctors(id),
  appointment_time TIMESTAMPTZ NOT NULL,
  duration_minutes INTEGER DEFAULT 30,
  type TEXT CHECK (type IN ('online', 'physical')),
  status TEXT CHECK (
    status IN ('pending', 'confirmed', 'cancelled', 'completed')
  ) DEFAULT 'pending',
  chief_complaint TEXT,
  notes TEXT,
  meet_link TEXT,
  pre_reminder_sent BOOLEAN DEFAULT FALSE,
  post_reminder_sent BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**t11** — Create `conversations` and `messages` tables
```sql
CREATE TABLE public.conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID REFERENCES public.profiles(id),
  doctor_id UUID REFERENCES public.doctors(id),
  ai_active BOOLEAN DEFAULT TRUE,
  intake_complete BOOLEAN DEFAULT FALSE,
  triage_data JSONB,
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

**t12** — Create `triage_briefs` table
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
  status TEXT CHECK (
    status IN ('new', 'reviewed', 'dismissed')
  ) DEFAULT 'new',
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**t13** — Set up RLS policies
```sql
ALTER TABLE public.doctors ENABLE ROW LEVEL SECURITY;

-- Patients can read all verified doctors
CREATE POLICY "patients_read_verified_doctors"
  ON public.doctors FOR SELECT
  USING (verification_status = 'verified');

-- Doctors manage their own profile
CREATE POLICY "doctors_manage_own_profile"
  ON public.doctors FOR ALL
  USING (auth.uid() = id);

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "conversation_participants_only"
  ON public.messages FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM conversations c
      WHERE c.id = conversation_id
      AND (c.patient_id = auth.uid() OR c.doctor_id = auth.uid())
    )
  );
```

---

## PHASE 2 — Authentication

**t14** — Create Dart models
```dart
// lib/shared/models/doctor.dart
class Doctor {
  final String id;
  final String fullName;
  final String specialization;
  final String city;
  final String consultationType;
  final int? experienceYears;
  final int? consultationFee;
  final String? bio;
  final String? profilePictureUrl;
  final double rating;
  final int reviewCount;
  final bool isAvailable;
  final String verificationStatus;
  // fromJson, toJson
}

// lib/shared/models/appointment.dart
// lib/shared/models/message.dart
// lib/shared/models/conversation.dart
// lib/shared/models/triage_brief.dart
```

**t15** — Build auth provider (Riverpod)
```dart
// lib/features/auth/providers/auth_provider.dart
@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  User? build() => Supabase.instance.client.auth.currentUser;

  Future<void> signIn(String email, String password) async {
    final res = await Supabase.instance.client.auth
      .signInWithPassword(email: email, password: password);
    state = res.user;
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
    state = null;
  }
}

// Role provider — fetches from profiles table
@riverpod
Future<String> userRole(UserRoleRef ref) async {
  final user = ref.watch(authNotifierProvider);
  if (user == null) return 'guest';
  final data = await Supabase.instance.client
    .from('profiles')
    .select('role')
    .eq('id', user.id)
    .single();
  return data['role'] as String;
}
```

**t16** — Build GoRouter with role-based guards
```dart
// lib/core/config/router.dart
final router = GoRouter(
  redirect: (context, state) async {
    final user = Supabase.instance.client.auth.currentUser;
    final isAuth = user != null;
    final isAuthRoute = state.matchedLocation.startsWith('/auth');

    if (!isAuth && !isAuthRoute) return '/auth/login';
    if (isAuth && isAuthRoute) {
      // Fetch role and redirect accordingly
      final role = await getUserRole(user.id);
      if (role == 'doctor') return '/doctor/dashboard';
      if (role == 'admin') return '/admin';
      return '/patient/dashboard';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/search', builder: (_, state) =>
      SearchScreen(query: state.uri.queryParameters['q'] ?? '')),
    GoRoute(path: '/doctor/:id', builder: (_, state) =>
      DoctorProfileScreen(doctorId: state.pathParameters['id']!)),
    GoRoute(path: '/auth/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/auth/register', builder: (_, __) => const PatientRegisterScreen()),
    GoRoute(path: '/auth/register-doctor', builder: (_, __) => const DoctorRegisterScreen()),
    ShellRoute(
      builder: (_, __, child) => PatientShell(child: child),
      routes: [
        GoRoute(path: '/patient/dashboard', builder: (_, __) => const PatientDashboard()),
        GoRoute(path: '/patient/appointments', builder: (_, __) => const PatientAppointments()),
        GoRoute(path: '/patient/booking/status/:id', builder: (_, state) =>
          BookingStatusScreen(appointmentId: state.pathParameters['id']!)),
      ],
    ),
    ShellRoute(
      builder: (_, __, child) => DoctorShell(child: child),
      routes: [
        GoRoute(path: '/doctor/dashboard', builder: (_, __) => const DoctorDashboard()),
        GoRoute(path: '/doctor/availability', builder: (_, __) => const AvailabilityScreen()),
        GoRoute(path: '/doctor/chat/:patientId', builder: (_, state) =>
          DoctorChatScreen(patientId: state.pathParameters['patientId']!)),
      ],
    ),
    GoRoute(path: '/admin', builder: (_, __) => const AdminScreen()),
  ],
);
```

**t17** — Build Login screen
```dart
// lib/features/auth/screens/login_screen.dart
// Fields: email, password
// supabase.auth.signInWithPassword()
// On success: GoRouter redirects via role guard
// Error states: wrong password, email not confirmed
// Link to /auth/register and /auth/register-doctor
```

**t18** — Build Patient Register screen
```dart
// Fields: full name, email, phone, password
// supabase.auth.signUp(data: {'full_name': name, 'role': 'patient'})
// Trigger auto-creates profile via DB trigger (t07)
// Redirect to /patient/dashboard
```

**t19** — Build Doctor Register screen
```dart
// Fields: full name, email, phone, password,
//         specialization (dropdown), city (dropdown),
//         consultation type (radio), experience years,
//         consultation fee, bio, PMDC number,
//         profile picture (image_picker)
// On submit:
//   1. supabase.auth.signUp(data: {'full_name': name, 'role': 'doctor'})
//   2. Upload image to storage bucket 'doctor-avatars'
//   3. Insert into doctors table with verification_status: 'pending'
//   4. Show: "Profile submitted. Awaiting admin approval."
```

---

## PHASE 3 — Doctor Profiles & Admin

**t20** — Build doctor seed script
```python
# backend/scripts/seed_doctors.py
# 10-12 fake verified doctors:
# Specializations: Cardiologist, Dermatologist, Orthopedic,
#   Neurologist, Psychiatrist, Gynecologist, Pediatrician, GP
# Cities: Lahore, Karachi, Islamabad, Rawalpindi
# Pre-populate: ratings (3.5–5.0), review counts
# Weekly availability for each
# After insert: call /ai/embed-doctor for each
# Run: python scripts/seed_doctors.py
```

**t21** — Build FastAPI embedding endpoint
```python
# POST /ai/embed-doctor
# Input: { doctor_id, specialization, city, bio, experience_years }
# Concatenate: f"{specialization} doctor in {city}. {bio}. {experience_years} years experience"
# Call Gemini text-embedding-004
# Store 768-dim vector in doctors.embedding
# Called from seed script + admin approval flow
```

**t22** — Build Admin screen (Flutter)
```dart
// lib/features/admin/screens/admin_screen.dart
// Password-protected: hardcoded PIN screen before showing queue
// Fetches all doctors WHERE verification_status = 'pending'
// ListView of pending doctor cards showing:
//   name, specialization, city, PMDC number
// "Approve" button:
//   UPDATE doctors SET verification_status = 'verified'
//   POST /ai/embed-doctor (triggers embedding)
// "Reject" button:
//   UPDATE doctors SET verification_status = 'rejected'
```

**t23** — Build Doctor availability screen
```dart
// lib/features/doctor_dashboard/screens/availability_screen.dart
// 7-day grid widget (Sun–Sat)
// Each day: toggle on/off + TimeRangePicker (start/end)
// Slot duration selector: 15 / 30 / 45 / 60 min
// Save → upsert into weekly_availability
// "Available Now" toggle at top → UPDATE doctors.is_available
```

---

## PHASE 4 — Search & AI Suggestions

**t24** — Build FastAPI specialties cache
```python
# On FastAPI startup:
SPECIALTIES_CACHE = []

@app.on_event("startup")
async def cache_specialties():
    global SPECIALTIES_CACHE
    result = supabase.from_("doctors") \
        .select("specialization") \
        .eq("verification_status", "verified") \
        .execute()
    SPECIALTIES_CACHE = list(set(
        d["specialization"] for d in result.data
    ))

# GET /ai/specialties → returns SPECIALTIES_CACHE
```

**t25** — Build FastAPI Gemini specialty mapping
```python
# POST /ai/suggest-specialties
# Input: { query: str }
# System prompt:
#   "You are a medical triage assistant. Given a patient search query
#    and available specializations, return ONLY a JSON array of the
#    1-3 most relevant matches.
#    Format: [{"specialty": "...", "reason": "one sentence why"}]
#    Available specializations: {SPECIALTIES_CACHE}
#    Return raw JSON only. No markdown. No explanation."
# Return: List[{specialty, reason}]
```

**t26** — Build FastAPI pgvector semantic search
```python
# POST /ai/search-doctors
# Input: { query, city?: str, available_only: bool }
# 1. Call /ai/suggest-specialties → get specialty list
# 2. Embed query using Gemini text-embedding-004
# 3. For each specialty:
#    SELECT *, (embedding <=> query_vec) AS similarity
#    FROM doctors
#    WHERE specialization = specialty
#      AND verification_status = 'verified'
#      AND (NOT available_only OR is_available = TRUE)
#      AND (city IS NULL OR city = input_city)
#    ORDER BY similarity ASC, rating DESC
#    LIMIT 3
# 4. Return: [{specialty, reason, doctors: [...]}]
```

**t27** — Build Search screen (Flutter)
```dart
// lib/features/search/screens/search_screen.dart

// SearchBar widget at top (also in HomeScreen)
// "Available Only" toggle chip
// On search: POST /ai/search-doctors via Dio
// Loading: shimmer skeleton cards
// Results: ListView of specialty groups
//   Each group has a header: "Cardiologist"
//   Italic subtitle: reason from Gemini
//   3 DoctorCard widgets below

// DoctorCard shows:
//   - CachedNetworkImage avatar
//   - Name + specialization badge
//   - City + consultation type chips
//   - Experience + fee
//   - Star rating row
//   - Green dot "Available Now" if is_available
//   - "Earliest: Tomorrow 10am" (from /slots/earliest)
//   - "Book Now" ElevatedButton → /doctor/:id
```

---

## PHASE 5 — Doctor Profile Screen

**t28** — Build Doctor Profile screen
```dart
// lib/features/doctor_profile/screens/doctor_profile_screen.dart
// Sections:
// 1. Hero: Avatar, name, specialty, city, rating, fee, availability badge
// 2. About: bio, experience, consultation type chips
// 3. Weekly schedule: read-only day/time grid
// 4. Sticky bottom bar: "Book Now" + "Chat with Assistant" buttons

// Chat widget trigger:
//   Use a Timer(Duration(seconds: 8), showChatWidget)
//   OR ScrollController listener — show after scrolling 300px
//   Animated slide-up bottom sheet
```

**t29** — Build waiting time estimate
```python
# GET /slots/earliest?doctor_id=xxx
# Query weekly_availability for doctor
# Query confirmed appointments for next 14 days
# Find next available window from NOW()
# Return: { datetime: "...", label: "Tomorrow 10:00 AM" }
```
Display on both DoctorCard and DoctorProfileScreen.

---

## PHASE 6 — Chat System

**t30** — Build Supabase Realtime chat stream
```dart
// lib/features/chat/providers/chat_provider.dart
@riverpod
Stream<List<Message>> chatMessages(
    ChatMessagesRef ref, String conversationId) {
  return Supabase.instance.client
    .from('messages')
    .stream(primaryKey: ['id'])
    .eq('conversation_id', conversationId)
    .order('created_at')
    .map((data) => data.map(Message.fromJson).toList());
}
```

**t31** — Build FastAPI AI triage endpoint
```python
# POST /chat/ai-respond
# Input: { conversation_id, message, triage_data_so_far }
# 1. Check conversations.ai_active — if FALSE return null
# 2. Check red flag keywords BEFORE calling Gemini (faster + safer):
#    RED_FLAGS = ["chest pain", "severe bleeding", "can't breathe",
#                 "unconscious", "stroke", "heart attack", "سینے میں درد"]
#    If match → return RED_FLAG response immediately
# 3. System prompt:
#    "You are an empathetic medical intake assistant for a Pakistani clinic.
#     Patients write in Urdu, English, or Roman Urdu — match their language.
#     Collect ONE at a time: chief_complaint, duration, severity (1-10), contact.
#     When all 4 collected, output EXACTLY:
#     [INTAKE_COMPLETE]
#     {"chief_complaint":...,"duration":...,"severity":...,"contact":...}
#     Never diagnose. Always add: 'یہ طبی مشورہ نہیں ہے / This is not medical advice.'"
# 4. Stream response
# 5. If [INTAKE_COMPLETE] detected → trigger SOAP note generation + email
```

**t32** — Build SOAP note + email trigger
```python
# POST /chat/generate-soap
# Input: { triage_data, doctor_id, conversation_id }
# Prompt Gemini to format as SOAP note
# INSERT into triage_briefs
# UPDATE conversations SET intake_complete = TRUE
# POST /email/notify-doctor (send Gmail SMTP email)
```

**t33** — Build Gmail SMTP service (FastAPI)
```python
# services/smtp.py
import aiosmtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

async def send_email(to: str, subject: str, html_body: str):
    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = f"{settings.SMTP_SENDER_NAME} <{settings.SMTP_USERNAME}>"
    msg["To"] = to
    msg.attach(MIMEText(html_body, "html"))

    await aiosmtplib.send(
        msg,
        hostname=settings.SMTP_HOST,
        port=settings.SMTP_PORT,
        username=settings.SMTP_USERNAME,
        password=settings.SMTP_PASSWORD,
        start_tls=True,
    )

# Email templates:
# notify_doctor_email(doctor_name, soap_note, patient_contact, dashboard_link)
# confirm_appointment_email(patient_name, doctor_name, datetime, type, meet_link)
# pre_reminder_email(patient_name, doctor_name, datetime)
# post_feedback_email(patient_name, doctor_name)
```

**t34** — Build per-doctor chat widget (Flutter)
```dart
// lib/features/chat/widgets/chat_bottom_sheet.dart
// Shown as DraggableScrollableSheet from bottom of DoctorProfileScreen

// Opening message: "👋 Hi! I'm the Smart Booking Assistant
//                   for Dr. [Name]. What brings you in today?"

// Message list: uses flutter_chat_ui package
//   Patient messages: right-aligned, teal bubble
//   AI messages: left-aligned, dark bubble
//   Sender label: "AI Assistant" or doctor name

// Input row: TextField + Send button

// On send:
//   1. Insert message into DB (sender_role: 'patient')
//   2. POST /chat/ai-respond via Dio
//   3. Insert AI response into DB (sender_role: 'ai')

// Red flag state: Replace chat with RedFlagCard widget
//   Red warning card: "⚠️ Your symptoms need immediate attention.
//                      Please go to the nearest ER or call 1122."
//   Chat input disabled

// On [INTAKE_COMPLETE]: Show booking CTA card at bottom of chat:
//   "✅ Info received! Tap below to book your appointment."
//   ElevatedButton → triggers booking flow
```

**t35** — Build doctor dashboard chat screen
```dart
// lib/features/doctor_dashboard/screens/doctor_chat_screen.dart
// Full-screen chat using flutter_chat_ui
// "Take Over" FloatingActionButton
//   → UPDATE conversations SET ai_active = FALSE
//   → Shows "You are now responding as Dr. [Name]"
// "Hand Back to AI" button (appears after takeover)
//   → UPDATE conversations SET ai_active = TRUE
// Doctor replies insert with sender_role: 'doctor'
```

**t36** — Build app-wide chatbot (Flutter)
```dart
// lib/shared/widgets/app_chatbot_fab.dart
// FloatingActionButton on all screens except doctor chat
// Taps open a Modal Bottom Sheet with chat interface

// Separate Riverpod provider for app chatbot state
// Separate FastAPI endpoint: POST /chat/app-chatbot
// System prompt:
//   "You are Smart Doctor Connect AI assistant. Help patients
//    find doctors and answer general health questions.
//    Available specializations: {cached list}.
//    Always end health answers with:
//    'This is general info only. Consult a qualified doctor.'
//    Never diagnose. Never recommend medications by name."

// Conversation history in provider state (not database)
```

---

## PHASE 7 — Appointment Booking

**t37** — Build slot generation endpoint
```python
# GET /slots/available?doctor_id=xxx&count=3
# 1. Fetch doctor's weekly_availability
# 2. Fetch confirmed appointments (next 14 days)
# 3. Generate all possible slots from weekly schedule
# 4. Remove booked + past slots
# 5. Return next {count} slots:
#    [{ slot_id, datetime, label: "Tomorrow, 10:00 AM", type }]
```

**t38** — Build booking flow screens (Flutter)
```dart
// Multi-step flow using PageView or Navigator stack

// Step 1: SlotSelectionScreen
//   GET /slots/available?doctor_id=xxx&count=3
//   3 slot cards (date, time, online/physical badge)
//   Patient taps to select

// Step 2: PatientInfoScreen
//   Check: does conversation exist for this patient+doctor?
//   If YES: pre-fill name, contact, complaint from triage_data
//           show pre-filled fields with edit option
//   If NO: show inline form (name, contact, chief complaint)

// Step 3: ConfirmationScreen
//   Summary card: doctor, slot, type, fee, complaint
//   "Proceed to Payment" button

// Step 4: MockPaymentScreen
//   Card UI showing: "PKR [fee] — Payment Pending"
//   Fake card number field (disabled, shows **** **** **** ****)
//   "Confirm Booking" button
//   On confirm: POST to /appointments with status: 'pending'

// Step 5: BookingStatusScreen ← your demo wow moment
//   Supabase Realtime listener on appointment row
//   Animated status progression:
//   ⏳ Pending → "Sent to Dr. [Name]. Awaiting confirmation..."
//   ✅ Confirmed → "Booking Confirmed!" + appointment details + meet link
//   ❌ Cancelled → "Declined. Would you like to choose another slot?"
//   Updates LIVE without pull-to-refresh
```

**t39** — Build doctor appointment approval (Flutter dashboard)
```dart
// lib/features/doctor_dashboard/screens/doctor_dashboard.dart
// Supabase Realtime stream on appointments WHERE doctor_id = currentUser
//   AND status = 'pending'
// New requests appear as AppointmentCard widgets
// Card shows: patient name, complaint, requested slot, type
// "Approve" button:
//   UPDATE appointments SET status = 'confirmed', meet_link = mock_link
//   POST /email/confirm-appointment
// "Decline" button:
//   UPDATE appointments SET status = 'cancelled'
// Badge counter on bottom nav icon for pending count
```

**t40** — Build pg_cron reminder jobs
```sql
-- Pre-appointment reminder (runs every hour)
SELECT cron.schedule(
  'pre-appointment-reminder', '0 * * * *',
  $$
  SELECT net.http_post(
    url := 'http://your-fastapi-url/email/pre-reminder',
    body := json_build_object(
      'appointment_ids',
      ARRAY(
        SELECT id FROM appointments
        WHERE appointment_time BETWEEN NOW() + INTERVAL '23 hours'
          AND NOW() + INTERVAL '24 hours'
          AND status = 'confirmed'
          AND pre_reminder_sent = FALSE
      )
    )::text,
    headers := '{"Content-Type":"application/json"}'::jsonb
  );
  $$
);

-- Post-appointment feedback (runs every hour)
SELECT cron.schedule(
  'post-appointment-feedback', '0 * * * *',
  $$
  SELECT net.http_post(
    url := 'http://your-fastapi-url/email/post-reminder',
    body := json_build_object(
      'appointment_ids',
      ARRAY(
        SELECT id FROM appointments
        WHERE appointment_time BETWEEN NOW() - INTERVAL '2 hours'
          AND NOW() - INTERVAL '1 hour'
          AND status = 'confirmed'
          AND post_reminder_sent = FALSE
      )
    )::text,
    headers := '{"Content-Type":"application/json"}'::jsonb
  );
  $$
);
```

**t41** — Build patient appointments screen
```dart
// lib/features/patient_dashboard/screens/patient_appointments.dart
// Tabbed view: Upcoming | Past | Cancelled
// AppointmentCard per appointment:
//   Doctor name, specialty, datetime, status badge
//   Confirmed online: "Join Meeting" button → url_launcher
//   Pending: "Cancel" button (if > 2 hours before slot)
//   Cancelled pending slot: "Reschedule" → re-opens SlotSelectionScreen
```

---

## PHASE 8 — Extra AI Features

**t42** — Wire AI reasoning into search results
```dart
// SearchScreen already receives {specialty, reason, doctors} from API
// Display reason as italic subtitle under each specialty group header
// Example: "Based on 'back pain', we suggest Orthopedic specialists
//           as musculoskeletal issues are the most likely cause."
```

**t43** — Build live async confirmation status screen
```dart
// lib/features/booking/screens/booking_status_screen.dart
// This is your BIGGEST demo moment — show this live

// Supabase Realtime on single appointment row:
final appointmentStream = supabase
  .from('appointments')
  .stream(primaryKey: ['id'])
  .eq('id', appointmentId);

// Animated status widget:
// 1. ⏳ Pulsing clock icon → "Sent to Dr. [Name]..."
// 2. ✅ Checkmark animation (flutter_animate) → "Confirmed!"
//       Shows: date/time, type, meet link if online
// 3. ❌ X animation → "Declined" + "Try Another Slot" button

// Open doctor dashboard in split screen during demo
// Tap Approve → watch patient screen update INSTANTLY
```

**t44** — Waiting time on doctor cards
```dart
// In SearchScreen: after loading doctors, fire parallel
// GET /slots/earliest?doctor_id=xxx for each doctor
// Use FutureProvider per doctor_id
// Display: "Earliest: Today 4pm" on DoctorCard
// Cache in provider state for 5 min — no re-fetching on scroll
```

---

## PHASE 9 — UI Design System (Flutter)

**t45** — Set up theme in `lib/core/config/theme.dart`
```dart
// Medical trust theme: dark navy + teal
// Google Fonts: Space Grotesk (display) + Inter (body)

ThemeData appTheme = ThemeData(
  colorScheme: ColorScheme.dark(
    primary: Color(0xFF2DD4BF),      // Teal — primary CTA
    secondary: Color(0xFFF59E0B),    // Amber — ratings
    error: Color(0xFFEF4444),        // Red — emergency
    surface: Color(0xFF1C2333),      // Card background
    background: Color(0xFF0D1117),   // App background
  ),
  textTheme: GoogleFonts.spaceGroteskTextTheme().copyWith(
    displayLarge: TextStyle(fontWeight: FontWeight.w900,
                            letterSpacing: -1.5),
    bodyMedium: GoogleFonts.inter(fontWeight: FontWeight.w300),
  ),
  cardTheme: CardTheme(
    color: Color(0xFF1C2333),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: Color(0xFF2DD4BF).withOpacity(0.2)),
    ),
  ),
);
```

**t46** — Build shared widget library
```dart
// DoctorCard — search results + dashboard
// AppointmentCard — patient + doctor dashboards
// StatusBadge — pending/confirmed/cancelled/available
// TriageBriefCard — doctor dashboard SOAP note card
// RedFlagCard — emergency warning in chat
// SlotCard — selectable time slot in booking flow
// ShimmerCard — loading skeleton for search results
```

**t47** — Add animations via flutter_animate
```dart
// Page transitions: FadeTransition via GoRouter
// Cards on search results: staggered fade+slide
//   .animate(delay: Duration(milliseconds: index * 80))
//   .fadeIn(duration: 400.ms)
//   .slideY(begin: 0.3, end: 0)

// BookingStatusScreen:
//   Confirmed: .animate().scale().then().shimmer()
//   Pending: pulsing opacity animation

// Chat messages: slide in from bottom on new message
```

**t48** — Build Home screen
```dart
// lib/features/home/screens/home_screen.dart
// Hero section:
//   "Find the Right Doctor. Instantly."
//   "AI-powered matching for Pakistan"
//   SearchBar — center stage, autofocus on tap
// Stats row: "25,000+ Doctors" / "40+ Specialties" / "AI Matching"
// How it works: 3-step horizontal stepper
//   Search → Chat → Book
// Specializations grid: tap any → searches that specialty
// Bottom CTA: "Are you a doctor? Join us →" → /auth/register-doctor
```

---

## PHASE 10 — Demo Prep & Polish

**t49** — Final seed script run
- Verify 10–12 doctors seeded with embeddings stored
- Verify weekly schedules set for all seeded doctors
- Verify `is_available = TRUE` for at least 5 doctors
- Verify ratings range 3.5–5.0
- Test search: "chest pain" → Cardiologist group appears

**t50** — End-to-end demo flow test
Exact sequence to rehearse:
1. Open app → Home screen loads
2. Search "back pain" → grouped results with AI reasoning subtitle
3. Tap doctor → profile loads, wait 8s → chat popup slides up
4. Chat: type "I have severe back pain for 3 days, severity 8/10"
5. AI collects intake → SOAP note generates → booking CTA appears
6. Tap Book → select slot → mock payment → status screen: "⏳ Pending"
7. Open doctor dashboard (second device or simulator)
8. Tap "Approve" → patient screen updates to "✅ Confirmed" LIVE
9. Check Gmail inbox — confirmation email delivered

**t51** — Red flag stress test
- Type "chest pain" in chat → ER redirect card appears, no booking
- Type "I can't breathe" → same
- Type "heart attack" → same
- Type "back pain" → normal intake flow, no false positive

**t52** — Email delivery test
- Manually trigger `/email/notify-doctor` → check Gmail inbox
- Manually trigger `/email/confirm-appointment` → check Gmail inbox
- Trigger pre-reminder manually → verify `pre_reminder_sent` flips to TRUE
- Verify no duplicate emails on second trigger (guard check works)

**t53** — Build pitch talking points (rehearse these)
1. **The gap**: "Oladoc charges patients first, guarantees nothing. We flip it — AI triages, doctor confirms, THEN patient pays."
2. **The differentiator**: Live demo of status screen updating in real time
3. **The AI**: Show Gemini grouping search by specialty with visible reasoning
4. **The safety**: Type "chest pain" live — instant ER redirect
5. **The stack**: "Production-ready — Flutter + FastAPI + Supabase + Gemini"

---

## Task Summary by Phase

| Phase | Tasks | Description |
|-------|-------|-------------|
| 0 — Setup | t00–t06 | Flutter init, FastAPI init, env, Supabase init, folder structure |
| 1 — Schema | t07–t13 | All tables + RLS + DB trigger |
| 2 — Auth | t14–t19 | Models, Riverpod auth, GoRouter, login, register screens |
| 3 — Doctor Profiles | t20–t23 | Seed script, embeddings, admin screen, availability screen |
| 4 — Search | t24–t27 | Specialty cache, Gemini mapping, pgvector, search UI |
| 5 — Doctor Profile | t28–t29 | Profile screen, waiting time estimate |
| 6 — Chat | t30–t36 | Realtime stream, triage AI, red flag, SOAP, chat widget, app chatbot |
| 7 — Booking | t37–t41 | Slot gen, booking flow, approval, Gmail emails, cron, appointments screen |
| 8 — Extra AI | t42–t44 | Reasoning display, live status screen, waiting time cards |
| 9 — UI/Design | t45–t48 | Theme, shared widgets, animations, home screen |
| 10 — Demo Prep | t49–t53 | Seed verify, E2E test, red flag test, email test, pitch |

**Total: t00 → t53 (54 tasks)**

---

## Key Flutter-Specific Notes

| Topic | Decision |
|-------|----------|
| State management | Riverpod (flutter_riverpod + riverpod_annotation) |
| Navigation | GoRouter with role-based redirect guards |
| HTTP client | Dio (interceptors for auth token injection) |
| Realtime | Supabase Flutter SDK `.stream()` — not polling |
| Chat UI | flutter_chat_ui package (saves 2–3 hours vs custom) |
| Animations | flutter_animate (declarative, chainable) |
| Images | cached_network_image (handles Supabase Storage URLs) |
| Target platform | Android primary (faster to demo on physical device), iOS if time allows |
| Physical device testing | Use machine IP in AppConfig.fastApiUrl, not localhost |