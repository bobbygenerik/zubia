import sys
import unittest
from unittest.mock import MagicMock, patch
import numpy as np

# Mock faster_whisper before importing stt_service
mock_faster_whisper = MagicMock()
sys.modules["faster_whisper"] = mock_faster_whisper

# Mock WhisperModel specifically as it is imported directly
mock_whisper_model_class = MagicMock()
mock_faster_whisper.WhisperModel = mock_whisper_model_class

# Now we can import the module under test
from server.stt_service import transcribe

class TestSttService(unittest.TestCase):
    def setUp(self):
        # Reset mocks
        mock_whisper_model_class.reset_mock()

    @patch("server.stt_service.get_model")
    @patch("server.stt_service.wav_bytes_to_float32")
    def test_transcribe_success(self, mock_wav_to_float, mock_get_model):
        # Setup mocks
        mock_model_instance = MagicMock()
        mock_get_model.return_value = mock_model_instance

        # Mock audio data (1 second of random noise)
        sample_rate = 16000
        # Random audio to pass RMS check (> 0.005)
        # Using 0.5 constant is enough (RMS=0.5)
        audio = np.full(16000, 0.5, dtype=np.float32)
        mock_wav_to_float.return_value = (audio, sample_rate)

        # Mock transcribe result
        mock_segment = MagicMock()
        mock_segment.text = "Hello world"
        mock_info = MagicMock()
        mock_info.language = "en"
        mock_info.language_probability = 0.99

        mock_model_instance.transcribe.return_value = ([mock_segment], mock_info)

        # Execute
        result = transcribe(b"fake_wav_bytes")

        # Verify
        self.assertEqual(result["text"], "Hello world")
        self.assertEqual(result["language"], "en")
        self.assertEqual(result["confidence"], 0.99)
        mock_get_model.assert_called_once()
        mock_wav_to_float.assert_called_once_with(b"fake_wav_bytes")
        mock_model_instance.transcribe.assert_called_once()

    @patch("server.stt_service.get_model")
    @patch("server.stt_service.wav_bytes_to_float32")
    def test_transcribe_short_audio(self, mock_wav_to_float, mock_get_model):
        # Setup mocks
        mock_model_instance = MagicMock()
        mock_get_model.return_value = mock_model_instance

        # Short audio (0.1s)
        sample_rate = 16000
        audio = np.full(int(sample_rate * 0.1), 0.5, dtype=np.float32)
        mock_wav_to_float.return_value = (audio, sample_rate)

        # Execute
        result = transcribe(b"fake_wav_bytes")

        # Verify
        self.assertEqual(result["text"], "")
        mock_model_instance.transcribe.assert_not_called()

    @patch("server.stt_service.get_model")
    @patch("server.stt_service.wav_bytes_to_float32")
    def test_transcribe_silence(self, mock_wav_to_float, mock_get_model):
        # Setup mocks
        mock_model_instance = MagicMock()
        mock_get_model.return_value = mock_model_instance

        # Silent audio (1s of zeros)
        sample_rate = 16000
        audio = np.zeros(16000, dtype=np.float32)
        mock_wav_to_float.return_value = (audio, sample_rate)

        # Execute
        result = transcribe(b"fake_wav_bytes")

        # Verify
        self.assertEqual(result["text"], "")
        mock_model_instance.transcribe.assert_not_called()

    @patch("server.stt_service.get_model")
    @patch("server.stt_service.wav_bytes_to_float32")
    def test_transcribe_resample(self, mock_wav_to_float, mock_get_model):
        # Setup mocks
        mock_model_instance = MagicMock()
        mock_get_model.return_value = mock_model_instance

        # Audio with different sample rate (8000Hz, 1s)
        sample_rate = 8000
        audio = np.full(8000, 0.5, dtype=np.float32)
        mock_wav_to_float.return_value = (audio, sample_rate)

        mock_segment = MagicMock()
        mock_segment.text = "Resampled"
        mock_info = MagicMock()
        mock_info.language = "en"
        mock_info.language_probability = 0.9

        mock_model_instance.transcribe.return_value = ([mock_segment], mock_info)

        # Execute
        transcribe(b"fake_wav_bytes")

        # Verify
        # Check that transcribe was called with an array of length 16000 (resampled from 8000 * 1s)
        args, kwargs = mock_model_instance.transcribe.call_args
        passed_audio = args[0]
        self.assertEqual(len(passed_audio), 16000)

    @patch("server.stt_service.get_model")
    @patch("server.stt_service.wav_bytes_to_float32")
    def test_transcribe_exception(self, mock_wav_to_float, mock_get_model):
        # Setup mocks
        mock_model_instance = MagicMock()
        mock_get_model.return_value = mock_model_instance

        sample_rate = 16000
        audio = np.full(16000, 0.5, dtype=np.float32)
        mock_wav_to_float.return_value = (audio, sample_rate)

        # Mock exception
        mock_model_instance.transcribe.side_effect = Exception("Transcription error")

        # Execute
        result = transcribe(b"fake_wav_bytes")

        # Verify
        self.assertEqual(result["text"], "")
        self.assertEqual(result["confidence"], 0.0)
