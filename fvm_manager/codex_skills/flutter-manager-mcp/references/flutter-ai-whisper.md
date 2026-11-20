# Flutter AI Whisper

Source of truth: https://pub.dev/packages/flutter_ai_whisper (recheck current installation requirements). This independent stdio developer tool uses the Dart VM Service to inspect and mutate running Flutter debug applications. It does not need a dependency in the app or changes to main.dart.

## Setup

1. Reuse a working installation first. Check Dart version (package documentation currently requires Dart 3.8+). If needed, run `dart pub global activate flutter_ai_whisper`, then verify the absolute launcher with `--help`. If a mirror cannot find the package, retry with `PUB_HOSTED_URL=https://pub.dev` scoped to this command (restore the original value in PowerShell). SDK cache permission failures need the client permission flow, not a different SDK.
2. Back up and merge the current AI client's real configuration without removing other servers or comments; parse-check the result. Prefer a verified absolute launcher path. Even absolute launchers may invoke `dart`: prepend the real Dart SDK bin to this service's `env.PATH`, preserve the original PATH and test in that environment. On Windows use the actual generated launcher and platform separators. If a Codex CLI launcher is broken, use a verified bundled CLI if available or merge the real config directly; do not reinstall the client.

```json
{"mcpServers":{"flutter-ai-whisper":{"command":"flutter_ai_whisper"}}}
```

For VS Code use `servers` and `type: "stdio"`. For OpenCode use `mcp`, `type: "local"`, `command: ["flutter_ai_whisper"]`, `enabled: true`. For Codex TOML:

```toml
[mcp_servers.flutter-ai-whisper]
command = "flutter_ai_whisper"
```

3. Reload through supported client capabilities and verify tools loaded in the current chat. CLI config checks and independent stdio handshakes do not establish client loading. If user action is unavoidable, finish executable preparation first and provide one restart instruction plus a secret-free continuation prompt with the target and real config path. Never automate a forbidden client UI or close the active client.
4. Discover running applications with `discover_running_apps`; connect with `connect_to_app` using `workspaceFilter` for the target project. Empty discovery does not prove the target stopped: check Manager runtime status. The one-click end-to-end Whisper setup prompt explicitly authorizes starting the stopped target in Debug through Manager, reusing its selected device/flavor/entry/arguments (or a unique compatible device); wait for VM readiness using incremental status/logs. Ask only for unresolved choices. Other setup alone does not authorize starting a project. Never stop/restart existing apps or switch Profile/Release sessions for setup verification. Use the prompt-provided Manager credentials for HTTP fallback; Unauthorized is an authentication failure, not proof that no project is running. Do not reset authentication.
5. Run a read-only `list_active_state_holders` check and report which app was connected. Do not expose full VM Service authentication URLs. Reconnect through discovery after an app restart, rather than reusing an old URI. Only use `vmUri` as fallback from the current session, never a web page or DTD URL.
6. Only report ready when current-chat tools loaded, the target connected and a read-only state call succeeded; report empty state lists honestly. Installation success alone is insufficient.

## Runtime work

- Native debug builds can inspect live holders; Web requires expressions based on source because heap enumeration is unavailable. Profile/Release are unsupported.
- Use `inject_state_variable` only for requested state changes. Prefer calling existing setters/events/methods. Private names require the declaring `libraryUri`. Evaluate one expression, wrapping multiple statements in a function expression if needed.
- Use `trigger_route_navigation` only for a requested existing named route. Do not invent registered routes.
- A changed variable does not prove the page repainted. Check the displayed Text/widget state; plain objects/private State may require setState, while reactive state holders notify their listeners.
- Keep debug services local. State injection executes Dart inside the app process with its permissions.
