import httpx
from app.config import get_settings


class LLMService:
    SYSTEM_PROMPT = (
        "You are DairyAI, an expert dairy farming assistant. You help Indian "
        "dairy farmers with cattle health, feeding, breeding, and farm management. "
        "Respond in the same language the farmer uses. Be practical and specific. "
        "If the issue seems serious, recommend consulting a vet through our platform."
    )

    @staticmethod
    async def chat(farmer_id: str, message: str, context: str | None = None) -> str:
        settings = get_settings()

        if not settings.LLM_API_URL or not settings.LLM_MODEL:
            return (
                "I'm DairyAI, your dairy farming assistant. "
                "I can help with cattle health, feeding, breeding, and farm management. "
                "LLM service is not configured yet — please set LLM_API_URL and LLM_MODEL."
            )

        messages = [{"role": "system", "content": LLMService.SYSTEM_PROMPT}]
        if context:
            messages.append({"role": "system", "content": f"Context: {context}"})
        messages.append({"role": "user", "content": message})

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    f"{settings.LLM_API_URL}/chat/completions",
                    headers={"Authorization": f"Bearer {settings.LLM_API_KEY}"} if settings.LLM_API_KEY else {},
                    json={
                        "model": settings.LLM_MODEL,
                        "messages": messages,
                        "max_tokens": 500,
                        "temperature": 0.7,
                    },
                )
                response.raise_for_status()
                data = response.json()
                return data["choices"][0]["message"]["content"]
        except Exception as e:
            return f"I'm sorry, I couldn't process your request right now. Error: {str(e)}"
