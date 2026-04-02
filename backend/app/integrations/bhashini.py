import logging
from typing import Optional

import httpx

from app.config import get_settings

logger = logging.getLogger("dairy_ai.integrations.bhashini")

SUPPORTED_LANGUAGES = [
    "hi", "ta", "te", "kn", "mr", "gu", "pa", "bn", "or", "ml", "en",
]

ULCA_PIPELINE_URL = "https://meity-auth.ulcacontrib.org/ulca/apis/v0/model/getModelsPipeline"
DHRUVA_API_BASE = "https://dhruva-api.bhashini.gov.in/services"


class BhashiniClient:
    """Integration with India's Bhashini (ULCA) language platform for STT, TTS, and Translation."""

    @staticmethod
    def get_supported_languages() -> list[str]:
        """Return list of supported language codes."""
        return list(SUPPORTED_LANGUAGES)

    @staticmethod
    async def _get_pipeline_config(
        task_type: str,
        source_lang: str,
        target_lang: Optional[str] = None,
    ) -> Optional[dict]:
        """Fetch pipeline configuration (service URL + model ID) from the ULCA pipeline API.

        Args:
            task_type: One of 'asr' (STT), 'tts', 'translation'.
            source_lang: Source language code (e.g. 'hi').
            target_lang: Target language code, required for translation.

        Returns:
            Dict with 'service_url' and 'model_id', or None on failure.
        """
        settings = get_settings()
        logger.info(
            "Fetching pipeline config: task=%s, source=%s, target=%s",
            task_type, source_lang, target_lang,
        )

        task_config: dict = {"taskType": task_type}
        config_inner: dict = {"language": {"sourceLanguage": source_lang}}
        if target_lang:
            config_inner["language"]["targetLanguage"] = target_lang
        task_config["config"] = config_inner

        payload = {
            "pipelineTasks": [task_config],
            "pipelineRequestConfig": {
                "pipelineId": "64392f96daac500b55c543cd",
            },
        }

        headers = {
            "Content-Type": "application/json",
            "userID": settings.BHASHINI_USER_ID,
            "ulcaApiKey": settings.BHASHINI_API_KEY,
        }

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(ULCA_PIPELINE_URL, headers=headers, json=payload)
                if response.status_code >= 400:
                    logger.error(
                        "Bhashini pipeline config error: status=%d, body=%s",
                        response.status_code, response.text,
                    )
                    return None

                data = response.json()
                pipeline_response = data.get("pipelineResponseConfig", [])
                if not pipeline_response:
                    logger.error("Empty pipelineResponseConfig in Bhashini response")
                    return None

                task_response = pipeline_response[0]
                config_list = task_response.get("config", [])
                if not config_list:
                    logger.error("Empty config list in pipeline response for task=%s", task_type)
                    return None

                model_config = config_list[0]
                service_url = model_config.get("serviceUrl", "")
                model_id = model_config.get("modelId", "")

                inference_key = data.get("pipelineInferenceAPIEndPoint", {}).get(
                    "inferenceApiKey", {},
                ).get("value", "")

                logger.info(
                    "Pipeline config resolved: task=%s, model_id=%s, service_url_present=%s",
                    task_type, model_id, bool(service_url),
                )
                return {
                    "service_url": service_url,
                    "model_id": model_id,
                    "inference_key": inference_key,
                }
        except Exception as e:
            logger.exception("Exception fetching Bhashini pipeline config: %s", e)
            return None

    @staticmethod
    async def translate(
        text: str,
        source_lang: str,
        target_lang: str,
    ) -> Optional[str]:
        """Translate text between supported Indian languages.

        Args:
            text: Input text to translate.
            source_lang: Source language code (e.g. 'hi').
            target_lang: Target language code (e.g. 'en').

        Returns:
            Translated text string, or None on failure.
        """
        logger.info(
            "Translate request: source=%s, target=%s, text_length=%d",
            source_lang, target_lang, len(text),
        )

        pipeline = await BhashiniClient._get_pipeline_config(
            "translation", source_lang, target_lang,
        )
        if not pipeline:
            return None

        payload = {
            "pipelineTasks": [
                {
                    "taskType": "translation",
                    "config": {
                        "language": {
                            "sourceLanguage": source_lang,
                            "targetLanguage": target_lang,
                        },
                        "serviceId": pipeline["model_id"],
                    },
                }
            ],
            "inputData": {
                "input": [{"source": text}],
            },
        }

        headers = {
            "Content-Type": "application/json",
            "Authorization": pipeline["inference_key"],
        }

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    pipeline["service_url"], headers=headers, json=payload,
                )
                if response.status_code >= 400:
                    logger.error(
                        "Bhashini translation error: status=%d, body=%s",
                        response.status_code, response.text,
                    )
                    return None

                data = response.json()
                output_list = data.get("pipelineResponse", [])
                if not output_list:
                    logger.error("Empty pipelineResponse from translation service")
                    return None

                output_items = output_list[0].get("output", [])
                if not output_items:
                    logger.error("Empty output in translation pipelineResponse")
                    return None

                translated = output_items[0].get("target", "")
                logger.info(
                    "Translation complete: source=%s, target=%s, output_length=%d",
                    source_lang, target_lang, len(translated),
                )
                return translated
        except Exception as e:
            logger.exception("Exception during Bhashini translation: %s", e)
            return None

    @staticmethod
    async def speech_to_text(
        audio_bytes: bytes,
        source_lang: str,
    ) -> Optional[str]:
        """Transcribe audio to text using Bhashini ASR.

        Args:
            audio_bytes: Raw audio bytes (WAV or similar format).
            source_lang: Language code of the spoken audio.

        Returns:
            Transcribed text string, or None on failure.
        """
        import base64

        logger.info(
            "STT request: source_lang=%s, audio_size=%d bytes",
            source_lang, len(audio_bytes),
        )

        pipeline = await BhashiniClient._get_pipeline_config("asr", source_lang)
        if not pipeline:
            return None

        audio_b64 = base64.b64encode(audio_bytes).decode("utf-8")

        payload = {
            "pipelineTasks": [
                {
                    "taskType": "asr",
                    "config": {
                        "language": {"sourceLanguage": source_lang},
                        "serviceId": pipeline["model_id"],
                        "audioFormat": "wav",
                        "samplingRate": 16000,
                    },
                }
            ],
            "inputData": {
                "audio": [{"audioContent": audio_b64}],
            },
        }

        headers = {
            "Content-Type": "application/json",
            "Authorization": pipeline["inference_key"],
        }

        try:
            async with httpx.AsyncClient(timeout=60.0) as client:
                response = await client.post(
                    pipeline["service_url"], headers=headers, json=payload,
                )
                if response.status_code >= 400:
                    logger.error(
                        "Bhashini ASR error: status=%d, body=%s",
                        response.status_code, response.text,
                    )
                    return None

                data = response.json()
                output_list = data.get("pipelineResponse", [])
                if not output_list:
                    logger.error("Empty pipelineResponse from ASR service")
                    return None

                output_items = output_list[0].get("output", [])
                if not output_items:
                    logger.error("Empty output in ASR pipelineResponse")
                    return None

                transcribed = output_items[0].get("source", "")
                logger.info(
                    "STT complete: source_lang=%s, transcribed_length=%d",
                    source_lang, len(transcribed),
                )
                return transcribed
        except Exception as e:
            logger.exception("Exception during Bhashini STT: %s", e)
            return None

    @staticmethod
    async def text_to_speech(
        text: str,
        target_lang: str,
        gender: str = "female",
    ) -> Optional[bytes]:
        """Convert text to speech audio using Bhashini TTS.

        Args:
            text: Text to synthesize.
            target_lang: Language code for synthesis.
            gender: Voice gender, 'female' or 'male'.

        Returns:
            Audio bytes (WAV format), or None on failure.
        """
        import base64

        logger.info(
            "TTS request: target_lang=%s, gender=%s, text_length=%d",
            target_lang, gender, len(text),
        )

        pipeline = await BhashiniClient._get_pipeline_config("tts", target_lang)
        if not pipeline:
            return None

        payload = {
            "pipelineTasks": [
                {
                    "taskType": "tts",
                    "config": {
                        "language": {"sourceLanguage": target_lang},
                        "serviceId": pipeline["model_id"],
                        "gender": gender,
                        "samplingRate": 22050,
                    },
                }
            ],
            "inputData": {
                "input": [{"source": text}],
            },
        }

        headers = {
            "Content-Type": "application/json",
            "Authorization": pipeline["inference_key"],
        }

        try:
            async with httpx.AsyncClient(timeout=60.0) as client:
                response = await client.post(
                    pipeline["service_url"], headers=headers, json=payload,
                )
                if response.status_code >= 400:
                    logger.error(
                        "Bhashini TTS error: status=%d, body=%s",
                        response.status_code, response.text,
                    )
                    return None

                data = response.json()
                output_list = data.get("pipelineResponse", [])
                if not output_list:
                    logger.error("Empty pipelineResponse from TTS service")
                    return None

                audio_list = output_list[0].get("audio", [])
                if not audio_list:
                    logger.error("Empty audio in TTS pipelineResponse")
                    return None

                audio_b64 = audio_list[0].get("audioContent", "")
                if not audio_b64:
                    logger.error("Empty audioContent in TTS response")
                    return None

                audio_bytes = base64.b64decode(audio_b64)
                logger.info(
                    "TTS complete: target_lang=%s, gender=%s, audio_size=%d bytes",
                    target_lang, gender, len(audio_bytes),
                )
                return audio_bytes
        except Exception as e:
            logger.exception("Exception during Bhashini TTS: %s", e)
            return None

    @staticmethod
    async def detect_language(text: str) -> Optional[str]:
        """Detect the language of the given text using Bhashini NLU pipeline.

        Args:
            text: Input text to identify.

        Returns:
            Detected language code (e.g. 'hi'), or None on failure.
        """
        settings = get_settings()
        logger.info("Language detection request: text_length=%d", len(text))

        payload = {
            "pipelineTasks": [
                {
                    "taskType": "txt-lang-detection",
                    "config": {
                        "language": {},
                    },
                }
            ],
            "pipelineRequestConfig": {
                "pipelineId": "64392f96daac500b55c543cd",
            },
        }

        headers = {
            "Content-Type": "application/json",
            "userID": settings.BHASHINI_USER_ID,
            "ulcaApiKey": settings.BHASHINI_API_KEY,
        }

        try:
            # Step 1: get pipeline config for language detection
            async with httpx.AsyncClient(timeout=30.0) as client:
                config_resp = await client.post(ULCA_PIPELINE_URL, headers=headers, json=payload)
                if config_resp.status_code >= 400:
                    logger.error(
                        "Bhashini lang-detect pipeline config error: status=%d, body=%s",
                        config_resp.status_code, config_resp.text,
                    )
                    return None

                config_data = config_resp.json()
                pipeline_response = config_data.get("pipelineResponseConfig", [])
                if not pipeline_response:
                    logger.error("Empty pipelineResponseConfig for lang detection")
                    return None

                config_list = pipeline_response[0].get("config", [])
                if not config_list:
                    logger.error("Empty config for lang detection")
                    return None

                service_url = config_list[0].get("serviceUrl", "")
                model_id = config_list[0].get("modelId", "")
                inference_key = config_data.get("pipelineInferenceAPIEndPoint", {}).get(
                    "inferenceApiKey", {},
                ).get("value", "")

                # Step 2: call the detection service
                detect_payload = {
                    "pipelineTasks": [
                        {
                            "taskType": "txt-lang-detection",
                            "config": {
                                "serviceId": model_id,
                            },
                        }
                    ],
                    "inputData": {
                        "input": [{"source": text}],
                    },
                }

                detect_headers = {
                    "Content-Type": "application/json",
                    "Authorization": inference_key,
                }

                detect_resp = await client.post(
                    service_url, headers=detect_headers, json=detect_payload,
                )
                if detect_resp.status_code >= 400:
                    logger.error(
                        "Bhashini lang detection error: status=%d, body=%s",
                        detect_resp.status_code, detect_resp.text,
                    )
                    return None

                detect_data = detect_resp.json()
                output_list = detect_data.get("pipelineResponse", [])
                if not output_list:
                    logger.error("Empty pipelineResponse from lang detection")
                    return None

                output_items = output_list[0].get("output", [])
                if not output_items:
                    logger.error("Empty output in lang detection response")
                    return None

                detected_lang = output_items[0].get("langPrediction", [{}])[0].get(
                    "langCode", "",
                )
                logger.info("Language detected: %s for text_length=%d", detected_lang, len(text))
                return detected_lang if detected_lang else None
        except Exception as e:
            logger.exception("Exception during Bhashini language detection: %s", e)
            return None
