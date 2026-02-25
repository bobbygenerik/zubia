import unittest
from unittest.mock import patch, MagicMock, mock_open
import sys
import os
import urllib.error

# Add the server directory to sys.path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

import tts_service

class TestTTSDownload(unittest.TestCase):
    @patch('tts_service.urllib.request.urlopen')
    @patch('builtins.open', new_callable=mock_open)
    @patch('tts_service.Path.exists')
    def test_urllib_called(self, mock_exists, mock_file, mock_urlopen):
        # Arrange
        mock_exists.return_value = False # Simulate file not existing

        # Mock response context manager
        mock_response = MagicMock()
        # Side effect for TWO file downloads: (chunk1, chunk2, empty) * 2
        mock_response.read.side_effect = [b'chunk1', b'chunk2', b'', b'chunk1', b'chunk2', b'']
        mock_urlopen.return_value.__enter__.return_value = mock_response

        # Act
        tts_service.preload_voices(["en"])

        # Assert
        # Verify urlopen was called twice (onnx and json)
        self.assertEqual(mock_urlopen.call_count, 2)

        # Verify URLs
        calls = mock_urlopen.call_args_list
        onnx_call_args = calls[0]
        json_call_args = calls[1]

        self.assertIn('.onnx', onnx_call_args[0][0])
        self.assertIn('.onnx.json', json_call_args[0][0])

        # Verify file writing
        # open should be called twice for writing
        self.assertEqual(mock_file.call_count, 2)
        handle = mock_file()
        # Verify write was called with chunks
        handle.write.assert_any_call(b'chunk1')
        handle.write.assert_any_call(b'chunk2')

    @patch('tts_service.urllib.request.urlopen')
    @patch('tts_service.Path.exists')
    @patch('tts_service.Path.unlink')
    def test_download_failure_cleanup(self, mock_unlink, mock_exists, mock_urlopen):
        # Arrange
        mock_exists.return_value = False
        mock_urlopen.side_effect = urllib.error.URLError("Network error")

        # Act
        # preload_voices catches exceptions and logs warning, but we want to verify unlink is called
        # inside _download_voice before it re-raises (which is caught by preload_voices)
        tts_service.preload_voices(["en"])

        # Assert
        # unlink should be called to clean up partial downloads (onnx and json)
        self.assertTrue(mock_unlink.called)
        # It attempts to unlink both onnx and json paths
        self.assertGreaterEqual(mock_unlink.call_count, 2)

if __name__ == '__main__':
    unittest.main()
