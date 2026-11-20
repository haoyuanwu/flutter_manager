import http.server
import json
from pathlib import Path
import subprocess
import sys
import threading
import unittest

HELPER = Path(__file__).resolve().parents[2] / 'codex_skills/flutter-manager-mcp/scripts/call_flutter_manager.py'

class McpHelperTest(unittest.TestCase):
    def test_json_arguments_reach_bridge_and_api_errors_fail(self):
        received = []
        class Handler(http.server.BaseHTTPRequestHandler):
            def do_POST(self):
                received.append((self.path, json.loads(self.rfile.read(int(self.headers['Content-Length'])))))
                self.send_response(200)
                self.end_headers()
                self.wfile.write(json.dumps({'ok': self.path != '/tools/fail', 'operationId': 'mcp-1'}).encode())
            def log_message(self, *_):
                pass
        server = http.server.HTTPServer(('127.0.0.1', 0), Handler)
        worker = threading.Thread(target=server.serve_forever, daemon=True)
        worker.start()
        try:
            base = [sys.executable, str(HELPER), '--host', '127.0.0.1', '--port', str(server.server_port), '--token', '']
            result = subprocess.run(base + ['build', '--project', '/demo', '--args-json', '{"mode":"release","flavors":["prod"]}'], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(received[0], ('/tools/build', {'projectPath':'/demo','mode':'release','flavors':['prod']}))
            self.assertEqual(json.loads(result.stdout)['operationId'], 'mcp-1')
            self.assertNotEqual(subprocess.run(base + ['fail'], capture_output=True).returncode, 0)
            self.assertNotEqual(subprocess.run(base + ['build', '--args-json', '[]'], capture_output=True).returncode, 0)
        finally:
            server.shutdown()
            server.server_close()
            worker.join()

if __name__ == '__main__':
    unittest.main()
