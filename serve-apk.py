import http.server
import socketserver
import os
import subprocess

PORT = 8080
DIRECTORY = "build/app/outputs/flutter-apk"

# Ensure the directory exists
if not os.path.exists(DIRECTORY):
    print(f"Error: Directory {DIRECTORY} does not exist. Did the APK build succeed?")
    exit(1)

# Try to open the firewall port (assuming Ubuntu/UFW)
try:
    print(f"Opening port {PORT} in UFW...")
    subprocess.run(["sudo", "ufw", "allow", f"{PORT}/tcp"], check=True)
    print("Port opened successfully.")
except Exception as e:
    print(f"Could not automatically configure firewall (might not be using UFW or requires password): {e}")

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

with socketserver.TCPServer(("", PORT), Handler) as httpd:
    print(f"\n✅ Serving APKs at http://0.0.0.0:{PORT}")
    print(f"👉 Download link: http://15.204.95.57:{PORT}/app-release.apk\n")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down server.")
