# Flutter Manager MCP API v2

All names below have prefix `flutter_manager_`. Tool schemas returned by tools/list are authoritative. Call get_capabilities for host support. No tool invocation during setup implies permission to publish or delete data.

## Asynchronous operations

Mutations return `{accepted:true, operationId, status:"running"}`. Poll get_operation with operationId. Only status=success proves successful completion. Cancelled jobs do not prove successful completion. Failed jobs expose error; completed jobs expose result. A single mutation runs at a time, with at most 100 retained job records per App process; restarting the App clears them. Do not retry a lost upload blindly. get_operation includes live packaging/upload/download progress where available. stop controls Flutter processes, not arbitrary uploads or packaging; cancel_download requests SDK download cancellation.

## Tools

| Tool | Parameters | Purpose |
| --- | --- | --- |
| get_capabilities |  | Inspect available actions and host packaging support. |
| get_operation | operationId (required) | Read operation status: running/success/failed, progress, result or error. |
| list_operations |  | List recent MCP operations (maximum 100). |
| get_project_config | projectPath | Read project configuration with secrets masked. |
| configure_project | projectPath; target: apk, appbundle, ios, macos, windows; mode: debug, profile, release; flavors; cleanBeforeBuild; androidTargetPlatform; deviceId; runMode: debug, release; pgyer; fir; bugly; useCustomCommands; customCommandCode | Persist project build/run, distribution and custom workflow settings. Merge nested configs; secret values are never returned. |
| scan_artifacts | projectPath | List actual build artifacts and paths for packaging, signing or distribution. |
| build_history | projectPath | Read project build sessions and recorded artifacts. |
| package_macos | projectPath; architectures (required) | Generate DMG from existing Release app. macOS host only. Returns operationId; poll get_operation. |
| package_windows | projectPath; innoCompilerPath | Generate Inno Setup installer from existing Windows Release build. Windows host only. No interactive compiler dialog. |
| upload_pgyer | projectPath; filePath (required) | Upload an explicitly selected APK/IPA using saved pgyer configuration. Only on user request to distribute. Poll operation for downloadUrl; do not blindly retry. |
| upload_fir | projectPath; filePath (required) | Upload an explicitly selected APK/IPA using saved fir configuration. Only on user request to distribute. Poll operation for downloadUrl; do not blindly retry. |
| upload_bugly | projectPath; flavor (required) | Upload existing Bugly symbols for specified flavor. |
| update_version | projectPath; version (required); buildNo (required) | Update project pubspec/Android build version; does not create a GitHub release. |
| custom_workflow | projectPath | Execute saved custom build workflow; executes configured external commands. Requires user intent to run that workflow. |
| list_android_devices |  | List Android install devices and online status. |
| install_apk | filePath (required); deviceId (required) | Install APK on an explicitly selected online Android device. |
| sign_apk | filePath (required); jksPath; password; keyAlias; outputDirectory; outputName | Sign one APK to output directory using saved or provided keystore settings. Keeps source; returns signed outputPath. |
| signing_info | filePath (required); password | Read certificate fingerprints from APK or JKS. |
| project_action | projectPath; action (required): add, remove, refresh, rename, tags, sdk, clear_build; alias; tags; version | Manage projects: add existing path, remove record (not source), refresh, rename alias, tags, SDK, clear build directory. Deletion/cleanup only when requested. |
| sdk_action | action (required): refresh, install_fvm, update_fvm, install, set_global, remove, cache_size, clear_unused_cache, open_fvm, open_global, system_path, cancel_download; version; pathType: default, version, custom; versionOrPath | Manage Flutter/FVM SDKs: install, update, remove, global version, cache or system PATH. Do not mutate SDKs without user intent. |
| get_environment |  | Read installed SDKs, release versions and mirror selection. |
| environment_action | action (required): set_mirror, test_mirror, test_all, fastest_mirror, diagnose; mirrorId | Run environment diagnostics or configure/test mirrors. |
| file_action | projectPath; action (required): project_folder, build_folder, vscode, android_studio, android_project, ios_project, macos_project, windows_project, reveal; filePath | Open project/build directories, IDEs, or reveal artifact file. |
| console_action | projectPath; action (required): open, clear, select, close; tabId | Open/clear project console, select or close console tab. |
| dependencies | projectPath; additions; removals | Read pubspec or apply additions/removals and run Pub Get. New production dependencies require user approval. |
| create_project | name (required); parentDirectory (required); directoryName (required); organization; sdkDirectory; sdkVersion; platforms; template: app, module, package, plugin, packageFfi, pluginFfi | Create and register a Flutter project in a new directory. |
| parse_log | filePath (required); isEncrypted | Read/decrypt a selected log file, returning at most 1000 lines. |
| settings | autoOpenConsoleWindow; showMainWindowConsole; showConsoleQuickCommands; buildOpensConsoleWindow; pgyerApiKey; firApiToken; innoCompilerPath | Update console settings, global distribution credentials or compiler path. Credentials are write-only. |

`build` also accepts projectPath, target (apk/appbundle/ios/macos/windows), mode (debug/profile/release), flavors (array), cleanBeforeBuild, androidTargetPlatform. Omitted values use saved settings. run/rerun support deviceId/flavor/openConsole; get_runtime_status/read_console and wait_for_runtime_change monitor running Flutter commands.

## End-to-end build and upload

1. Read get_project_config (credentials masked), choose explicit settings, build and wait for success.
2. scan_artifacts; use package_macos/package_windows for existing desktop Release outputs or sign_apk for an Android package when requested.
3. Upload an explicit final filePath using upload_pgyer/upload_fir only when requested. Poll the returned operationId; return result.downloadUrl. Bugly symbols use upload_bugly with flavor or saved build integration.
4. Never interpret accepted or a non-running Flutter task as upload success. After an interrupted client request inspect list_operations before deciding whether to retry.

## HTTP helper

Use `scripts/call_flutter_manager.py <command> --project <path> --args-file <payload.json>`. The helper also accepts --args-json for non-sensitive arguments. HTTP endpoint names omit the flutter_manager_ prefix. It returns nonzero for transport/API failures; a running operation is not a completed workflow.

Do not retrieve credentials in readable config responses: masked values are indicators, not reusable credentials. Configure only fields supplied by the user; omitted nested credential fields remain unchanged. Do not send `[configured]` back as a credential.
