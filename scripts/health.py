#!/usr/bin/env python3
"""
Ghost Tunnel — Health Check HTTP Server v3.0
Listens on $PORT (default 8080).
Endpoints:
  GET /health  → JSON status (200 OK)
  GET /status  → detailed JSON with tunnel and process info
  GET /         → plain text alive check
"""

import http.server
import json
import os
import subprocess
import time

PORT = int(os.environ.get("PORT", 8080))
START_TIME = time.time()


def _count_procs(name: str) -> int:
    try:
        result = subprocess.run(
            ["pgrep", "-c", name],
            capture_output=True,
            text=True,
            timeout=5,
        )
        return int(result.stdout.strip()) if result.returncode == 0 else 0
    except Exception:
        return 0


def _supervisor_status() -> dict:
    try:
        result = subprocess.run(
            ["supervisorctl", "-c", "/etc/supervisor/supervisord.conf", "status"],
            capture_output=True,
            text=True,
            timeout=10,
        )
        services = {}
        for line in result.stdout.splitlines():
            parts = line.split()
            if len(parts) >= 2:
                services[parts[0]] = parts[1]
        return services
    except Exception:
        return {}


class HealthHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path in ("/health", "/health/"):
            self._serve_health()
        elif self.path in ("/status", "/status/"):
            self._serve_status()
        elif self.path == "/":
            self._serve_root()
        else:
            self._serve_404()

    def _serve_root(self):
        body = b"Ghost Tunnel OK\n"
        self._respond(200, "text/plain", body)

    def _serve_health(self):
        payload = {
            "status": "ok",
            "service": "Ghost Tunnel",
            "version": "3.0.0",
            "uptime_seconds": int(time.time() - START_TIME),
        }
        self._respond(200, "application/json", json.dumps(payload).encode())

    def _serve_status(self):
        uptime = int(time.time() - START_TIME)
        payload = {
            "status": "ok",
            "service": "Ghost Tunnel",
            "version": "3.0.0",
            "uptime_seconds": uptime,
            "bore_tunnels": _count_procs("bore"),
            "sshd_procs": _count_procs("sshd"),
            "ports": os.environ.get("PORTS", "22"),
            "bore_server": os.environ.get("BORE_SERVER", "bore.pub"),
            "supervisor": _supervisor_status(),
        }
        self._respond(200, "application/json", json.dumps(payload, indent=2).encode())

    def _serve_404(self):
        self._respond(404, "text/plain", b"Not Found\n")

    def _respond(self, code: int, content_type: str, body: bytes):
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        # Suppress noisy access logs; health checks fire every 30s
        pass


if __name__ == "__main__":
    server = http.server.HTTPServer(("0.0.0.0", PORT), HealthHandler)
    print(f"[Ghost Tunnel] Health server listening on :{PORT}", flush=True)
    server.serve_forever()
