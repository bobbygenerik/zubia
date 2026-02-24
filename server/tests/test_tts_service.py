import unittest
from unittest.mock import patch, MagicMock, mock_open
import sys
from pathlib import Path
import os
import urllib.error

# Mock dependencies before import
sys.modules["piper"] = MagicMock()
sys.modules["numpy"] = MagicMock()

# Now import the module
# Adjust sys.path to include the project root
sys.path.append(os.getcwd())
from server import tts_service

class TestTTSDownload(unittest.TestCase):
    @patch("server.tts_service.shutil.copyfileobj")
    @patch("server.tts_service.urllib.request.urlopen")
    @patch("builtins.open", new_callable=mock_open)
    @patch("server.tts_service.VOICES_DIR")
    def test_download_voice_en(self, mock_voices_dir, mock_file_open, mock_urlopen, mock_copyfileobj):
        # Setup mocks for VOICES_DIR
        def side_effect(arg):
            m = MagicMock()
            m.exists.return_value = False
            m.__str__.return_value = f"/tmp/voices/{arg}"
            m.name = arg
            m.unlink.return_value = None
            return m

        mock_voices_dir.__truediv__.side_effect = side_effect

        # Setup mock for urlopen response
        mock_response = MagicMock()
        mock_urlopen.return_value.__enter__.return_value = mock_response

        # Call the function
        # Using "en" which maps to "en_US-lessac-medium"
        result = tts_service._download_voice("en")

        # Verify urlopen calls
        self.assertEqual(mock_urlopen.call_count, 2)

        # Check first call (ONNX)
        args_onnx, kwargs_onnx = mock_urlopen.call_args_list[0]
        url_onnx = args_onnx[0]
        self.assertIn("en_US-lessac-medium.onnx", url_onnx)
        self.assertEqual(kwargs_onnx["timeout"], 120)

        # Check second call (JSON)
        args_json, kwargs_json = mock_urlopen.call_args_list[1]
        url_json = args_json[0]
        self.assertIn("en_US-lessac-medium.onnx.json", url_json)
        self.assertEqual(kwargs_json["timeout"], 30)

        # Verify file open calls
        self.assertEqual(mock_file_open.call_count, 2)

        # args of first call
        args1, _ = mock_file_open.call_args_list[0]
        self.assertEqual(args1[0].name, "en_US-lessac-medium.onnx")

        # args of second call
        args2, _ = mock_file_open.call_args_list[1]
        self.assertEqual(args2[0].name, "en_US-lessac-medium.onnx.json")

        # Verify copyfileobj
        self.assertEqual(mock_copyfileobj.call_count, 2)


    @patch("server.tts_service.shutil.copyfileobj")
    @patch("server.tts_service.urllib.request.urlopen")
    @patch("builtins.open", new_callable=mock_open)
    @patch("server.tts_service.VOICES_DIR")
    def test_download_fallback(self, mock_voices_dir, mock_file_open, mock_urlopen, mock_copyfileobj):
        # Setup mocks for VOICES_DIR
        def side_effect(arg):
            m = MagicMock()
            m.exists.return_value = False
            m.__str__.return_value = f"/tmp/voices/{arg}"
            m.name = arg
            m.unlink.return_value = None
            return m

        mock_voices_dir.__truediv__.side_effect = side_effect

        # Simulate URLError for the first call (Spanish)
        # The first call fails. The code catches it, cleans up, and calls _download_voice("en").

        success_cm = MagicMock()
        success_cm.__enter__.return_value = MagicMock()

        mock_urlopen.side_effect = [
            urllib.error.URLError("Network error"), # ES ONNX fails
            success_cm, # EN ONNX succeeds
            success_cm  # EN JSON succeeds
        ]

        # Call for Spanish
        result = tts_service._download_voice("es")

        # Verify calls
        # 1. ES ONNX
        args1, _ = mock_urlopen.call_args_list[0]
        self.assertIn("es_ES-sharvard-medium.onnx", args1[0])

        # 2. EN ONNX (fallback)
        args2, _ = mock_urlopen.call_args_list[1]
        self.assertIn("en_US-lessac-medium.onnx", args2[0])

        # 3. EN JSON (fallback)
        args3, _ = mock_urlopen.call_args_list[2]
        self.assertIn("en_US-lessac-medium.onnx.json", args3[0])

if __name__ == "__main__":
    unittest.main()
