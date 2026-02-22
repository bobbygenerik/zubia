## 2026-02-22 - Parallelizing AI Pipeline
**Learning:** Python's `asyncio.gather` combined with `run_in_executor` is effective for parallelizing independent CPU-bound tasks (like translation/TTS) that release the GIL (via CTranslate2/ONNXRuntime).
**Action:** Look for sequential loops over independent items that involve IO or external computation and parallelize them.
