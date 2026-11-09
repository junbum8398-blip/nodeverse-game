#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
NODEVERSE Mini-Game Telemetry Mock Receiver Server
Implements receiver endpoint compliant with "NODEVERSE 팀공유 이벤트 파이프라인 연동규약서" (v3.0)
Endpoints:
  - POST /ingest/v1/events : Primary Kafka/Ingest schema endpoint
  - POST /api/minigame/record : Fallback REST endpoint
  - GET /health or GET / : Health check / ping test
Usage:
  python tools/mock_receiver_server.py [PORT]
"""

import sys
import io
import json
import socket
from datetime import datetime
from http.server import HTTPServer, BaseHTTPRequestHandler

# Force UTF-8 on Windows cmd/powershell
if hasattr(sys.stdout, 'buffer'):
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'buffer'):
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

DEFAULT_PORT = 8000

# ANSI color codes
CLR_RESET = "\033[0m"
CLR_BOLD = "\033[1m"
CLR_GREEN = "\033[92m"
CLR_CYAN = "\033[96m"
CLR_YELLOW = "\033[93m"
CLR_RED = "\033[91m"
CLR_MAGENTA = "\033[95m"
CLR_GRAY = "\033[90m"

def get_local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"

class TelemetryRequestHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        # Suppress default server log to avoid noise; we format our own logs
        pass

    def _send_json_response(self, status_code, data):
        body = json.dumps(data, ensure_ascii=False, indent=2).encode('utf-8')
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.end_headers()

    def do_GET(self):
        now_str = datetime.now().strftime("%H:%M:%S")
        print(f"{CLR_GRAY}[{now_str}]{CLR_RESET} {CLR_CYAN}[GET Ping/Health]{CLR_RESET} From {self.client_address[0]}:{self.client_address[1]} -> Path: {self.path}")
        
        resp = {
            "status": "healthy",
            "server": "NODEVERSE Telemetry Mock Receiver v3.0",
            "time": datetime.utcnow().isoformat() + "Z",
            "client_ip": self.client_address[0]
        }
        self._send_json_response(200, resp)

    def do_POST(self):
        now_str = datetime.now().strftime("%H:%M:%S")
        content_length = int(self.headers.get('Content-Length', 0))
        
        if content_length <= 0:
            self._send_json_response(400, {"error": "Empty body"})
            return
        
        raw_body = self.rfile.read(content_length).decode('utf-8', errors='replace')
        
        try:
            payload = json.loads(raw_body)
        except Exception as e:
            print(f"{CLR_RED}[{now_str}] JSON Parse Error: {e}{CLR_RESET}")
            self._send_json_response(400, {"error": "Invalid JSON format", "detail": str(e)})
            return

        batch_id = payload.get("batch_id", "unknown-batch")
        events = payload.get("events", [])
        
        # If single event format without batch wrapper
        if not events and isinstance(payload, dict) and "event_type" in payload:
            events = [payload]
            batch_id = "single-" + payload.get("event_id", "0")

        accepted_ids = []
        
        print(f"\n{CLR_GREEN}{'='*70}{CLR_RESET}")
        print(f"{CLR_BOLD}{CLR_GREEN}[RECV SUCCESS] {now_str} | Client: {self.client_address[0]} | Path: {self.path}{CLR_RESET}")
        print(f"[*] Batch ID: {CLR_YELLOW}{batch_id}{CLR_RESET} | Events Count: {len(events)}")
        
        for idx, ev in enumerate(events, 1):
            ev_id = ev.get("event_id", "")
            ev_type = ev.get("event_type", "unknown")
            task_id = ev.get("task_id", "")
            ctx = ev.get("context", {})
            player_id = ctx.get("player_id", "Unknown")
            accepted_ids.append(ev_id)
            
            # Format color by event type
            type_color = CLR_CYAN
            if "fail" in ev_type or "error" in ev_type:
                type_color = CLR_RED
            elif "succeed" in ev_type or "complete" in ev_type:
                type_color = CLR_GREEN
            elif "start" in ev_type:
                type_color = CLR_YELLOW

            print(f"  {CLR_BOLD}#{idx} [{type_color}{ev_type.upper()}{CLR_RESET}{CLR_BOLD}] Task: {CLR_YELLOW}{task_id}{CLR_RESET} | Player: {CLR_MAGENTA}{player_id}{CLR_RESET}")
            
            # Key details
            if "operation" in ev:
                print(f"     -> Operation: {ev.get('operation')} (Reason: {ev.get('failure_reason', 'none')})")
            if "state_after" in ev and ev["state_after"]:
                print(f"     -> State: {ev['state_after']}")
            if ctx.get("details"):
                print(f"     -> Context: {ctx.get('details')}")

        print(f"{CLR_GRAY}Raw JSON Preview: {raw_body[:250]}...{CLR_RESET}")
        print(f"{CLR_GREEN}{'='*70}{CLR_RESET}\n")
        sys.stdout.flush()

        # Response following spec v3.0
        response_data = {
            "status": "success",
            "batch_id": batch_id,
            "accepted_event_ids": accepted_ids,
            "count": len(accepted_ids),
            "received_at": datetime.utcnow().isoformat() + "Z"
        }
        self._send_json_response(200, response_data)

def run():
    port = DEFAULT_PORT
    if len(sys.argv) > 1:
        try:
            port = int(sys.argv[1])
        except ValueError:
            print(f"Invalid port: {sys.argv[1]}, using default {DEFAULT_PORT}")

    local_ip = get_local_ip()
    server_address = ('0.0.0.0', port)
    httpd = HTTPServer(server_address, TelemetryRequestHandler)
    
    print("\n" + "="*70)
    print("   NODEVERSE Mini-Game Telemetry Mock Receiver Server (Schema v3.0)")
    print("="*70)
    print(f"  > Local Loopback:   http://127.0.0.1:{port}/ingest/v1/events")
    print(f"  > Teammate LAN IP:  http://{local_ip}:{port}/ingest/v1/events")
    print(f"  > Health Check:     http://{local_ip}:{port}/health")
    print("-" * 70)
    print("  [INFO] Teammate configuration for Debug Panel (F6):")
    print(f"     - Server IP: {local_ip}")
    print(f"     - Port:      {port}")
    print(f"     - Path:      /ingest/v1/events")
    print("="*70)
    print("  Waiting for telemetry data... (Press Ctrl+C to quit)\n")
    sys.stdout.flush()

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nServer gracefully stopped.")
        httpd.server_close()

if __name__ == '__main__':
    run()
