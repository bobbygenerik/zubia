"""
Translation service using Argos Translate.
Translates text between supported language pairs offline using CTranslate2.
"""

import logging
import argostranslate.package
import argostranslate.translate

logger = logging.getLogger("voxbridge.translate")

# Track which packages we've already installed
_installed_pairs: set[tuple[str, str]] = set()
_initialized = False

# Supported languages with their full names and Argos codes
SUPPORTED_LANGUAGES = {
    "en": "English",
    "es": "Spanish",
    "fr": "French",
    "de": "German",
    "zh": "Chinese",
    "ja": "Japanese",
    "ar": "Arabic",
    "pt": "Portuguese",
    "ru": "Russian",
    "ko": "Korean",
}


def _ensure_initialized():
    """Make sure the Argos package index is up to date."""
    global _initialized
    if not _initialized:
        logger.info("Updating Argos Translate package index...")
        argostranslate.package.update_package_index()
        _initialized = True
        logger.info("Argos Translate index updated.")


def _ensure_package_installed(from_lang: str, to_lang: str):
    """Download and install the translation package for a language pair if needed."""
    pair = (from_lang, to_lang)
    if pair in _installed_pairs:
        return

    _ensure_initialized()

    # Check if already installed
    installed = argostranslate.translate.get_installed_languages()
    from_installed = None
    to_installed = None
    for lang in installed:
        if lang.code == from_lang:
            from_installed = lang
        if lang.code == to_lang:
            to_installed = lang

    if from_installed and to_installed:
        # Check if translation exists between them
        translation = from_installed.get_translation(to_installed)
        if translation:
            _installed_pairs.add(pair)
            logger.info(f"Translation pair {from_lang}->{to_lang} already installed.")
            return

    # Need to download and install the package
    available = argostranslate.package.get_available_packages()
    pkg = next(
        (p for p in available
         if p.from_code == from_lang and p.to_code == to_lang),
        None
    )

    if pkg is None:
        # Try via English as a pivot language
        logger.warning(
            f"No direct package for {from_lang}->{to_lang}. "
            f"Will use English as pivot."
        )
        if from_lang != "en":
            _ensure_package_installed(from_lang, "en")
        if to_lang != "en":
            _ensure_package_installed("en", to_lang)
        _installed_pairs.add(pair)
        return

    logger.info(f"Downloading translation package {from_lang}->{to_lang}...")
    download_path = pkg.download()
    argostranslate.package.install_from_path(download_path)
    _installed_pairs.add(pair)
    logger.info(f"Translation package {from_lang}->{to_lang} installed.")


def translate(text: str, from_lang: str, to_lang: str) -> str:
    """
    Translate text from one language to another.

    Uses direct translation if available, otherwise falls back to
    pivot translation through English.

    Args:
        text: The text to translate
        from_lang: Source language code (e.g., 'en')
        to_lang: Target language code (e.g., 'es')

    Returns:
        Translated text string
    """
    if not text or not text.strip():
        return ""

    if from_lang == to_lang:
        return text

    _ensure_package_installed(from_lang, to_lang)

    try:
        translated = argostranslate.translate.translate(text, from_lang, to_lang)
        logger.debug(f"Translated [{from_lang}->{to_lang}]: '{text}' -> '{translated}'")
        return translated
    except Exception as e:
        logger.error(f"Translation failed ({from_lang}->{to_lang}): {e}")
        # Fallback: try pivot through English
        if from_lang != "en" and to_lang != "en":
            try:
                english = argostranslate.translate.translate(text, from_lang, "en")
                result = argostranslate.translate.translate(english, "en", to_lang)
                return result
            except Exception as e2:
                logger.error(f"Pivot translation also failed: {e2}")
        return text  # Return original text as last resort


def get_supported_languages() -> dict[str, str]:
    """Return dict of supported language codes to names."""
    return SUPPORTED_LANGUAGES.copy()


