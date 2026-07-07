---
name: flutter-manager-mcp
description: Control the user's local Flutter Manager desktop app through its MCP server or localhost HTTP bridge. Use when the user asks Codex to operate managed Flutter projects from Flutter Manager, including listing projects/devices, selecting a project, running or rerunning Flutter on a device, stopping commands, reading the App console, opening DevTools, pub get, clean, or build through Flutter Manager MCP.
---

# Flutter Manager MCP

Use this skill to control the local Flutter Manager app instead of manually running Flutter commands, especially when the user expects App-managed consoles, project aliases, device selection, or MCP behavior.

## Preferred workflow

1. Use `mcp__flutter_manager` tools when they are available.
2. If a needed MCP tool is not loaded, use `tool_search` for `flutter_manager`.
3. If the active MCP schemas are stale or missing a parameter, call the App HTTP bridge with `scripts/call_flutter_manager.py`.
4. Read the App console after starting long commands; report whether the command is still running, succeeded, or failed.

## Common operations

- List projects: `flutter_manager_list_projects`
- Select project: `flutter_manager_select_project`
- List devices: `flutter_manager_list_devices`
- Run: `flutter_manager_run`
- Rerun: `flutter_manager_rerun`
- Stop: `flutter_manager_stop`
- Read console: `flutter_manager_read_console`
- Maintenance/build: `flutter_manager_pub_get`, `flutter_manager_clean`, `flutter_manager_build`, `flutter_manager_devtools`

When running a project:

- Prefer a managed project path from `list_projects`, not a guessed path.
- Prefer the user's named alias/display name when choosing projects.
- For Android real devices, use the device id from `list_devices`.
- For flavored Android projects, pass a flavor if the MCP schema supports it; otherwise use the HTTP script fallback.
- For the user's “念糖” project, the known managed path is `/Users/why/Documents/Project/waqu-shell`, Android device id recently used was `cd90370e`, and debug flavor that worked was `android`. Reconfirm devices before using this stale device id.

## HTTP bridge fallback

The Flutter Manager app exposes a local HTTP bridge at `127.0.0.1:<port>` when MCP service is enabled in the app. Default port is `17891`. Authentication uses `Authorization: Bearer <token>`.

Use the helper:

```bash
python3 /path/to/flutter-manager-mcp/scripts/call_flutter_manager.py run \
  --project "/path/to/project" \
  --device-id "device-id" \
  --flavor "android"
```

Read a concise console tail:

```bash
python3 /path/to/flutter-manager-mcp/scripts/call_flutter_manager.py read_console \
  --project "/path/to/project" \
  --tail 4000
```

The helper reads `FLUTTER_MANAGER_PORT`, `FLUTTER_MANAGER_HOST`, and `FLUTTER_MANAGER_TOKEN` from the environment. If the token is not in the environment, inspect the active Codex MCP config or ask the user for the token; do not hard-code private tokens into the skill.

## Console expectations

If the user asks “why didn’t the App console pop up?”, check whether the command was started through Flutter Manager/MCP. Direct terminal commands such as `fvm flutter run ...` bypass the app’s console-window lifecycle.

After starting `run` or `rerun`, poll `read_console` until one of these appears:

- running: task exists and logs are still updating;
- success: “A Dart VM Service” or active Flutter logs appear;
- failure: “BUILD FAILED”, “Error:”, “Gradle task ... failed”, or the task list becomes empty with an error.

Keep final answers short: say which project, device, flavor, and current result.
