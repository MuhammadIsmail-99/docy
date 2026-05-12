import asyncio
import google.generativeai as genai
from app.core.config import settings

class GeminiService:
    def __init__(self):
        genai.configure(api_key=settings.GEMINI_API_KEY)
        self.model = genai.GenerativeModel('gemini-1.5-flash')

    async def get_embedding(self, text: str):
        loop = asyncio.get_event_loop()
        result = await loop.run_in_executor(None, lambda: genai.embed_content(
            model="models/gemini-embedding-001",
            content=text,
            task_type="retrieval_document",
            title="Doctor Profile"
        ))
        return result['embedding']

    async def generate_text(self, prompt: str) -> str:
        response = await self.model.generate_content_async(prompt)
        return response.text

gemini_service = GeminiService()
