import logging
import httpx
from app.config import get_settings

logger = logging.getLogger("dairy_ai.services.llm")


class LLMService:
    SYSTEM_PROMPT = (
        "You are DairyAI, an expert dairy farming assistant. You help Indian "
        "dairy farmers with cattle health, feeding, breeding, and farm management. "
        "Respond in the same language the farmer uses. Be practical and specific. "
        "If the issue seems serious, recommend consulting a vet through our platform."
    )

    @staticmethod
    async def chat(farmer_id: str, message: str, context: str | None = None) -> str:
        logger.info(f"LLM chat called | farmer_id={farmer_id}, message_length={len(message)}")
        logger.debug(f"User message: {message[:200]}{'...' if len(message) > 200 else ''}")
        if context:
            logger.debug(f"Context provided: {context[:200]}{'...' if len(context) > 200 else ''}")

        settings = get_settings()

        if not settings.LLM_API_URL or not settings.LLM_MODEL:
            logger.warning("LLM service not configured — LLM_API_URL or LLM_MODEL is missing")
            return (
                "I'm DairyAI, your dairy farming assistant. "
                "I can help with cattle health, feeding, breeding, and farm management. "
                "LLM service is not configured yet — please set LLM_API_URL and LLM_MODEL."
            )

        logger.debug(f"LLM config | api_url={settings.LLM_API_URL}, model={settings.LLM_MODEL}")

        messages = [{"role": "system", "content": LLMService.SYSTEM_PROMPT}]
        if context:
            messages.append({"role": "system", "content": f"Context: {context}"})
        messages.append({"role": "user", "content": message})
        logger.debug(f"Sending {len(messages)} messages to LLM | model={settings.LLM_MODEL}")

        try:
            logger.debug(f"Making HTTP POST to {settings.LLM_API_URL}/chat/completions")
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
                reply = data["choices"][0]["message"]["content"]
                logger.info(f"LLM response received | farmer_id={farmer_id}, response_length={len(reply)}, status={response.status_code}")
                logger.debug(f"LLM reply: {reply[:200]}{'...' if len(reply) > 200 else ''}")
                return reply
        except httpx.TimeoutException as e:
            logger.error(f"LLM request timed out | farmer_id={farmer_id}, timeout=30s, error={e}")
            return f"I'm sorry, I couldn't process your request right now. Error: {str(e)}"
        except httpx.HTTPStatusError as e:
            logger.error(f"LLM API returned error | farmer_id={farmer_id}, status={e.response.status_code}, error={e}")
            return f"I'm sorry, I couldn't process your request right now. Error: {str(e)}"
        except Exception as e:
            logger.error(f"Unexpected error in LLM chat | farmer_id={farmer_id}, error_type={type(e).__name__}, error={e}")
            return f"I'm sorry, I couldn't process your request right now. Error: {str(e)}"
