import resend
from app.core.config import settings


class EmailService:
    def __init__(self):
        resend.api_key = settings.RESEND_API_KEY

    async def send(self, to: str, subject: str, html: str):
        if not settings.RESEND_API_KEY:
            print(f"[EMAIL SKIPPED — RESEND_API_KEY not set] To: {to} | Subject: {subject}")
            return
        try:
            resend.Emails.send({
                "from": "Smart Doctor Connect <noreply@smartdoctorconnect.ai>",
                "to": [to],
                "subject": subject,
                "html": html,
            })
        except Exception as e:
            print(f"Email send failed: {e}")

    async def notify_doctor(self, to: str, doctor_name: str, patient_name: str,
                            patient_contact: str, soap_note: str):
        html = f"""
        <div style="font-family:sans-serif;max-width:600px;margin:auto">
          <h2 style="color:#1B3C40">New Patient Triage — Smart Doctor Connect</h2>
          <p>Hello Dr. {doctor_name},</p>
          <p>A patient has completed their intake form through the Smart Doctor Connect AI assistant.</p>
          <table style="border-collapse:collapse;width:100%">
            <tr><td style="padding:8px;font-weight:bold">Patient</td><td style="padding:8px">{patient_name}</td></tr>
            <tr style="background:#f8f9fb"><td style="padding:8px;font-weight:bold">Contact</td><td style="padding:8px">{patient_contact}</td></tr>
          </table>
          <h3 style="color:#1B3C40;margin-top:24px">SOAP Note</h3>
          <pre style="background:#f8f9fb;padding:16px;border-radius:8px;white-space:pre-wrap">{soap_note}</pre>
          <p style="color:#888;font-size:12px">Please review and approve or decline the appointment request in your dashboard.</p>
        </div>
        """
        await self.send(to, f"New Patient Intake: {patient_name}", html)

    async def confirm_appointment(self, to: str, patient_name: str, doctor_name: str,
                                   appointment_time: str, appt_type: str, meet_link: str | None):
        link_html = f'<p><a href="{meet_link}" style="color:#1B3C40">Join Meeting</a></p>' if meet_link else ""
        html = f"""
        <div style="font-family:sans-serif;max-width:600px;margin:auto">
          <h2 style="color:#1B3C40">Appointment Confirmed ✅</h2>
          <p>Hello {patient_name},</p>
          <p>Your appointment with <strong>Dr. {doctor_name}</strong> has been confirmed.</p>
          <table style="border-collapse:collapse;width:100%">
            <tr><td style="padding:8px;font-weight:bold">Date & Time</td><td style="padding:8px">{appointment_time}</td></tr>
            <tr style="background:#f8f9fb"><td style="padding:8px;font-weight:bold">Type</td><td style="padding:8px">{appt_type.title()}</td></tr>
          </table>
          {link_html}
          <p style="color:#888;font-size:12px">Smart Doctor Connect AI</p>
        </div>
        """
        await self.send(to, f"Appointment Confirmed with Dr. {doctor_name}", html)

    async def pre_reminder(self, to: str, patient_name: str, doctor_name: str, appointment_time: str):
        html = f"""
        <div style="font-family:sans-serif;max-width:600px;margin:auto">
          <h2 style="color:#1B3C40">Appointment Reminder 🔔</h2>
          <p>Hello {patient_name},</p>
          <p>This is a reminder that your appointment with <strong>Dr. {doctor_name}</strong> is in 24 hours.</p>
          <p><strong>Time:</strong> {appointment_time}</p>
          <p style="color:#888;font-size:12px">Smart Doctor Connect AI</p>
        </div>
        """
        await self.send(to, f"Reminder: Appointment with Dr. {doctor_name} Tomorrow", html)

    async def post_feedback(self, to: str, patient_name: str, doctor_name: str):
        html = f"""
        <div style="font-family:sans-serif;max-width:600px;margin:auto">
          <h2 style="color:#1B3C40">How was your visit? ⭐</h2>
          <p>Hello {patient_name},</p>
          <p>We hope your appointment with <strong>Dr. {doctor_name}</strong> went well.</p>
          <p>Your feedback helps other patients find the right doctor.</p>
          <p style="color:#888;font-size:12px">Smart Doctor Connect AI</p>
        </div>
        """
        await self.send(to, f"Rate your visit with Dr. {doctor_name}", html)


email_service = EmailService()
