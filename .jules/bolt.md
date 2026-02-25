## 2026-02-22 - Parallelizing AI Pipeline
**Learning:** Python's `asyncio.gather` combined with `run_in_executor` is effective for parallelizing independent CPU-bound tasks (like translation/TTS) that release the GIL (via CTranslate2/ONNXRuntime).
**Action:** Look for sequential loops over independent items that involve IO or external computation and parallelize them.

## 2026-02-23 - Caching AI Inference
**Learning:** Text-to-Speech (TTS) inference is computationally expensive but highly deterministic for a given text, language, and model. In a chat application, common phrases (greetings, affirmations) repeat frequently.
**Action:** Always consider memoization (LRU cache) for pure functions wrapping expensive AI model inference, especially when inputs are discrete text strings.
