#!/usr/bin/env python3
import functools
import http.server
import mimetypes
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "build" / "web"
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8000

mimetypes.add_type("application/wasm", ".wasm")


class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()


print(f"Serving {ROOT} at http://localhost:{PORT}")
http.server.ThreadingHTTPServer(
    ("", PORT), functools.partial(Handler, directory=str(ROOT))
).serve_forever()
