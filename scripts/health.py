#!/usr/bin/env python3
"""
Ghost Tunnel — HTTP Health Check Server
Responds to GET / and GET /health with status 200
"""
import http.server
import json
import os
import subprocess
import time

PORT = int(os.environ.get("PORT", 8080))
START_TIME = time.time()


class HealthHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path in ("/", "/health", "/healthz"):
            self._serve_health()
        elif self.path == "/status":
            self._serve_status()
        else:
            self._serve_404()

    def _serve_health(self):
        body = b"OK"
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _serve_status(self):
        uptime = int(time.time() - START_TIME)
        # Count active bore tunnels
        try:
            result = subprocess.run(
                ["pgrep", "-c", "bore"], capture_output=True, text=True
            )
            bore_count = int(result.stdout.strip()) if result.returncode == 0 else 0
        except Exception:
            bore_count = 0

        payload = {
            "status": "ok",
            "service": "Ghost Tunnel",
            "version": "1.0.0",
            "uptime_seconds": uptime,
            "bore_tunnels": bore_count,
            "ports": os.environ.get("PORTS", "22"),
            "bore_server": os.environ.get("BORE_SERVER", "bore.pub"),
        }
        body = json.dumps(payload, indent=2).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _serve_404(self):
        body = b"Not Found"
        self.send_response(404)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        # Suppress access logs (reduce noise)
        pass


if __name__ == "__main__":
    server = http.server.HTTPServer(("0.0.0.0", PORT), HealthHandler)
    print(f"[Ghost Tunnel] Health server listening on :{PORT}", flush=True)
    server.serve_forever()
