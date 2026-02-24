import pytest
from pathlib import Path
from server.tts_service import _get_voice_path, VOICES_DIR, VOICE_MODELS

def test_get_voice_path_structure():
    """Test that _get_voice_path returns the expected 7-element tuple."""
    result = _get_voice_path("en")
    assert isinstance(result, tuple)
    assert len(result) == 7

    onnx_path, json_path, model_name, lang_short, lang_region, name, quality = result
    assert isinstance(onnx_path, Path)
    assert isinstance(json_path, Path)
    assert isinstance(model_name, str)
    assert isinstance(lang_short, str)
    assert isinstance(lang_region, str)
    assert isinstance(name, str)
    assert isinstance(quality, str)

@pytest.mark.parametrize("lang", ["en", "es", "fr"])
def test_get_voice_path_valid_languages(lang):
    """Test _get_voice_path with valid language codes."""
    expected_model = VOICE_MODELS[lang]
    onnx_path, json_path, model_name, lang_short, lang_region, name, quality = _get_voice_path(lang)

    assert model_name == expected_model
    assert onnx_path == VOICES_DIR / f"{expected_model}.onnx"
    assert json_path == VOICES_DIR / f"{expected_model}.onnx.json"

    # Verify components derived from model_name
    parts = expected_model.split("-")
    assert lang_region == parts[0]
    assert name == parts[1]
    assert quality == parts[2]
    assert lang_short == parts[0][:2]

def test_get_voice_path_invalid_language_fallback():
    """Test that _get_voice_path falls back to English for unknown languages."""
    # "xx" is not in VOICE_MODELS
    en_model = VOICE_MODELS["en"]
    onnx_path, json_path, model_name, lang_short, lang_region, name, quality = _get_voice_path("xx")

    assert model_name == en_model
    assert lang_short == "en"
    assert lang_region == "en_US"
