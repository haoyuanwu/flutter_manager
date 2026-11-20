#!/usr/bin/env python3
"""Call the local Flutter Manager HTTP bridge."""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Call Flutter Manager HTTP tools")
    parser.add_argument("--args-json", help="Additional tool arguments as JSON object")
    parser.add_argument("--args-file", help="Read tool arguments from a UTF-8 JSON file (preferred for credentials)")
    parser.add_argument("tool", help="Tool name, e.g. run, read_console, list_devices")
    parser.add_argument("--project", dest="project_path", help="Managed Flutter project path")
    parser.add_argument("--device-id", help="Flutter device id for run/rerun")
    parser.add_argument("--flavor", help="Android flavor for run/rerun")
    parser.add_argument("--task-id", help="Task id for stop")
    parser.add_argument("--open-console", action=argparse.BooleanOptionalAction, default=None)
    parser.add_argument("--tail", type=int, default=0, help="Print only the last N chars of log")
    parser.add_argument("--after-cursor", type=int, help="Runtime cursor for wait_for_runtime_change")
    parser.add_argument("--after-log-length", type=int, help="Previous console log length")
    parser.add_argument("--timeout-ms", type=int, help="Long-poll timeout in milliseconds")
    parser.add_argument("--host", default=os.environ.get("FLUTTER_MANAGER_HOST", "127.0.0.1"))
    parser.add_argument("--port", default=os.environ.get("FLUTTER_MANAGER_PORT", "17891"))
    parser.add_argument("--token", default=os.environ.get("FLUTTER_MANAGER_TOKEN", ""))
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    payload: dict[str, object] = {}
    try:
        if args.args_json and args.args_file:
            raise ValueError("Use only one of --args-json and --args-file")
        if args.args_file:
            with open(args.args_file, encoding="utf-8") as source:
                payload = json.load(source)
        elif args.args_json:
            payload = json.loads(args.args_json)
        if not isinstance(payload, dict):
            raise ValueError("Tool arguments must be a JSON object")
    except (OSError, ValueError) as error:
        print(str(error), file=sys.stderr)
        return 1
    if args.project_path:
        payload["projectPath"] = args.project_path
    if args.device_id:
        payload["deviceId"] = args.device_id
    if args.flavor:
        payload["flavor"] = args.flavor
    if args.task_id:
        payload["taskId"] = args.task_id
    if args.open_console is not None:
        payload["openConsole"] = args.open_console
    if args.tail:
        payload["tailChars"] = args.tail
    if args.after_cursor is not None:
        payload["afterCursor"] = args.after_cursor
    if args.after_log_length is not None:
        payload["afterLogLength"] = args.after_log_length
    if args.timeout_ms is not None:
        payload["timeoutMs"] = args.timeout_ms

    url = f"http://{args.host}:{args.port}/tools/{args.tool}"
    headers = {"Content-Type": "application/json"}
    if args.token:
        headers["Authorization"] = f"Bearer {args.token}"
    request = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers=headers,
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=max(40, (args.timeout_ms or 0) / 1000 + 10)) as response:
            data = json.load(response)
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", errors="replace")
        print(body or str(error), file=sys.stderr)
        return 1

    except (urllib.error.URLError, TimeoutError) as error:
        print(str(error), file=sys.stderr)
        return 1

    if args.tail and isinstance(data, dict) and isinstance(data.get("log"), str):
        data = {**data, "log": data["log"][-args.tail :]}
    print(json.dumps(data, ensure_ascii=False, indent=2))
    return 1 if isinstance(data, dict) and data.get("ok") is False else 0


if __name__ == "__main__":
    raise SystemExit(main())
