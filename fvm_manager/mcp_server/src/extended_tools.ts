import type { Tool } from "@modelcontextprotocol/sdk/types.js";

export const extendedTools: Tool[] = [
  {
    "name": "flutter_manager_get_capabilities",
    "description": "Inspect available actions and host packaging support.",
    "inputSchema": {
      "type": "object",
      "properties": {},
      "required": [],
      "additionalProperties": false
    }
  },
  {
    "name": "flutter_manager_get_operation",
    "description": "Read operation status: running/success/failed, progress, result or error.",
    "inputSchema": {
      "type": "object",
      "properties": {
        "operationId": {
          "type": "string"
        }
      },
      "required": [
        "operationId"
      ],
      "additionalProperties": false
    }
  },
  {
    "name": "flutter_manager_list_operations",
    "description": "List recent MCP operations (maximum 100).",
    "inputSchema": {
      "type": "object",
      "properties": {},
      "required": [],
      "additionalProperties": false
    }
  },
  {
    "name": "flutter_manager_get_project_config",
    "description": "Read project configuration with secrets masked.",
    "inputSchema": {
      "type": "object",
      "properties": {
        "projectPath": {
          "type": "string",
          "description": "Managed project path; defaults to selected project."
        }
      },
      "required": [],
      "additionalProperties": false
    }
  },
  {
    "name": "flutter_manager_configure_project",
    "description": "Persist project build/run, distribution and custom workflow settings. Merge nested configs; secret values are never returned.",
    "inputSchema": {
      "type": "object",
      "properties": {
        "projectPath": {
          "type": "string",
          "description": "Managed project path; defaults to selected project."
        },
        "target": {
          "type": "string",
          "enum": [
            "apk",
            "appbundle",
            "ios",
            "macos",
            "windows"
          ]
        },
        "mode": {
          "type": "string",
          "enum": [
            "debug",
            "profile",
            "release"
          ]
        },
        "flavors": {
          "type": "array",
          "items": {
            "type": "string"
          }
        },
        "cleanBeforeBuild": {
          "type": "boolean"
        },
        "androidTargetPlatform": {
          "type": "string"
        },
        "deviceId": {
          "type": [
            "string",
            "null"
          ]
        },
        "runMode": {
          "type": "string",
          "enum": [
            "debug",
            "release"
          ]
        },
        "pgyer": {
          "type": "object",
          "properties": {
            "apiKey": {
              "type": "string"
            },
            "installType": {
              "type": "string",
              "enum": [
                "public",
                "password",
                "invite"
              ]
            },
            "installPassword": {
              "type": "string"
            },
            "updateDescription": {
              "type": "string"
            }
          },
          "additionalProperties": false
        },
        "fir": {
          "type": "object",
          "properties": {
            "apiToken": {
              "type": "string"
            },
            "appName": {
              "type": "string"
            },
            "bundleId": {
              "type": "string"
            },
            "changelog": {
              "type": "string"
            }
          },
          "additionalProperties": false
        },
        "bugly": {
          "type": "object",
          "properties": {
            "enabled": {
              "type": "boolean"
            },
            "jarPath": {
              "type": "string"
            },
            "appId": {
              "type": "string"
            },
            "appKey": {
              "type": "string"
            },
            "bundleId": {
              "type": "string"
            },
            "version": {
              "type": "string"
            },
            "buildNo": {
              "type": "string"
            }
          },
          "additionalProperties": false
        },
        "useCustomCommands": {
          "type": "boolean"
        },
        "customCommandCode": {
          "type": "string"
        }
      },
      "required": [],
      "additionalProperties": false
    }
  },
  {
    "name": "flutter_manager_scan_artifacts",
    "description": "List actual build artifacts and paths for packaging, signing or distribution.",
    "inputSchema": {
      "type": "object",
      "properties": {
        "projectPath": {
          "type": "string",
          "description": "Managed project path; defaults to selected project."
        }
      },
      "required": [],
      "additionalProperties": false
    }
  },
  {
    "name": "flutter_manager_build_history",
    "description": "Read project build sessions and recorded artifacts.",
    "inputSchema": {
      "type": "object",
      "properties": {
        "projectPath": {
          "type": "string",
          "description": "Managed project path; defaults to selected project."
        }
      },
      "required": [],
      "additionalProperties": false
    }
  },
  {
    "name": "flutter_manager_package_macos",
    "description": "Generate DMG from existing Release app. macOS host only. Returns operationId; poll get_operation.",
    "inputSchema": {
      "type": "object",
      "properties": {
        "projectPath": {
          "type": "string",
          "description": "Managed project path; defaults to selected project."
        },
        "architectures": {
          "type": "array",
          "minItems": 1,
          "items": {
            "type": "string",
            "enum": [
              "arm64",
              "x86_64"
            ]
          }
        }
      },
      "required": [
        "architectures"
      ],
      "additionalProperties": false
    }
  },
  {
    "name": "flutter_manager_package_windows",
    "description": "Generate Inno Setup installer from existing Windows Release build. Windows host only. No interactive compiler dialog.",
    "inputSchema": {
      "type": "object",
      "properties": {
        "projectPath": {
          "type": "string",
          "description": "Managed project path; defaults to selected project."
        },
        "innoCompilerPath": {
          "type": "string"
        }
      },
      "required": [],
      "additionalProperties": false
    }
  },
  {
    "name": "flutter_manager_upload_pgyer",
    "description": "Upload an explicitly selected APK/IPA using saved pgyer configuration. Only on user request to distribute. Poll operation for downloadUrl; do not blindly retry.",
    "inputSchema": {
      "type": "object",
      "properties": {
        "projectPath": {
          "type": "string",
          "description": "Managed project path; defaults to selected project."
        },
        "filePath": {
          "type": "string"
        }
      },
      "required": [
        "filePath"
      ],
      "additionalProperties": false
    }
  },
  {
    "name": "flutter_manager_upload_fir",
    "description": "Upload an explicitly selected APK/IPA using saved fir configuration. Only on user request to distribute. Poll operation for downloadUrl; do not blindly retry.",
    "inputSchema": {
      "type": "object",
      "properties": {
        "projectPath": {
          "type": "string",
          "description": "Managed project path; defaults to selected project."
        },
        "filePath": {
          "type": "string"
        }
      },
      "required": [
        "filePath"
      ],
      "additionalProperties": false
    }
  },
  {
    "name": "flutter_manager_upload_bugly",
    "description": "Upload existing Bugly symbols for specified flavor.",
    "inputSchema": {
      "type": "object",
      "properties": {
        "projectPath": {
          "type": "string",
          "description": "Managed project path; defaults to selected project."
        },
        "flavor": {
          "type": "string"
        }
      },
      "required": [
        "flavor"
      ],
      "additionalProperties": false
    }
  },
  {
    "name": "flutter_manager_update_version",
    "description": "Update project pubspec/Android build version; does not create a GitHub release.",
    "inputSchema": {
      "type": "object",
      "properties": {
        "projectPath": {
          "type": "string",
          "description": "Managed project path; defaults to selected project."
        },
        "version": {
          "type": "string"
        },
        "buildNo": {
          "type": "string"
        }
      },
      "required": [
        "version",
        "buildNo"
      ],
      "additionalProperties": false
    }
  },
  {
    "name": "flutter_manager_custom_workflow",
    "description": "Execute saved custom build workflow; executes configured external commands. Requires user intent to run that workflow.",
    "inputSchema": {
      "type": "object",
      "properties": {
        "projectPath": {
          "type": "string",
          "description": "Managed project path; defaults to selected project."
        }
      },
      "required": [],
      "additionalProperties": false
    }
  },
  {
    "name": "flutter_manager_list_android_devices",
    "description": "List Android install devices and online status.",
    "inputSchema": {
      "type": "object",
      "properties": {},
      "required": [],
      "additionalProperties": false
    }
  },
  {
    "name": "flutter_manager_install_apk",
    "description": "Install APK on an explicitly selected online Android device.",
    "inputSchema": {
      "type": "object",
      "properties": {
        "filePath": {
          "type": "string"
        },
        "deviceId": {
          "type": "string"
        }
      },
      "required": [
        "filePath",
        "deviceId"
      ],
      "additionalProperties": false
    }
  },
  {
    "name": "flutter_manager_sign_apk",
    "description": "Sign one APK to output directory using saved or provided keystore settings. Keeps source; returns signed outputPath.",
    "inputSchema": {
      "type": "object",
      "properties": {
        "filePath": {
          "type": "string"
        },
        "jksPath": {
          "type": "string"
        },
        "password": {
          "type": "string"
        },
        "keyAlias": {
          "type": "string"
        },
        "outputDirectory": {
          "type": "string"
        },
        "outputName": {
          "type": "string"
        }
      },
      "required": [
        "filePath"
      ],
      "additionalProperties": false
    }
  },
  {
    "name": "flutter_manager_signing_info",
    "description": "Read certificate fingerprints from APK or JKS.",
    "inputSchema": {
      "type": "object",
      "properties": {
        "filePath": {
          "type": "string"
        },
        "password": {
          "type": "string"
        }
      },
      "required": [
        "filePath"
      ],
      "additionalProperties": false
    }
  },
  {
    "name": "flutter_manager_project_action",
    "description": "Manage projects: add existing path, remove record (not source), refresh, rename alias, tags, SDK, clear build directory. Deletion/cleanup only when requested.",
    "inputSchema": {
      "type": "object",
      "properties": {
        "projectPath": {
          "type": "string",
          "description": "Managed project path; defaults to selected project."
        },
        "action": {
          "type": "string",
          "enum": [
            "add",
            "remove",
            "refresh",
            "rename",
            "tags",
            "sdk",
            "clear_build"
          ]
        },
        "alias": {
          "type": "string"
        },
        "tags": {
          "type": "array",
          "items": {
            "type": "string"
          }
        },
        "version": {
          "type": "string"
        }
      },
      "required": [
        "action"
      ],
      "additionalProperties": false
    }
  },
  {
    "name": "flutter_manager_sdk_action",
    "description": "Manage Flutter/FVM SDKs: install, update, remove, global version, cache or system PATH. Do not mutate SDKs without user intent.",
    "inputSchema": {
      "type": "object",
      "properties": {
        "action": {
          "type": "string",
          "enum": [
            "refresh",
            "install_fvm",
            "update_fvm",
            "install",
            "set_global",
            "remove",
            "cache_size",
            "clear_unused_cache",
            "open_fvm",
            "open_global",
            "system_path",
            "cancel_download"
          ]
        },
        "version": {
          "type": "string"
        },
        "pathType": {
          "type": "string",
          "enum": [
            "default",
            "version",
            "custom"
          ]
        },
        "versionOrPath": {
          "type": "string"
        }
      },
      "required": [
        "action"
      ],
      "additionalProperties": false
    }
  },
  {
    "name": "flutter_manager_get_environment",
    "description": "Read installed SDKs, release versions and mirror selection.",
    "inputSchema": {
      "type": "object",
      "properties": {},
      "required": [],
      "additionalProperties": false
    }
  },
  {
    "name": "flutter_manager_environment_action",
    "description": "Run environment diagnostics or configure/test mirrors.",
    "inputSchema": {
      "type": "object",
      "properties": {
        "action": {
          "type": "string",
          "enum": [
            "set_mirror",
            "test_mirror",
            "test_all",
            "fastest_mirror",
            "diagnose"
          ]
        },
        "mirrorId": {
          "type": "string"
        }
      },
      "required": [
        "action"
      ],
      "additionalProperties": false
    }
  },
  {
    "name": "flutter_manager_file_action",
    "description": "Open project/build directories, IDEs, or reveal artifact file.",
    "inputSchema": {
      "type": "object",
      "properties": {
        "projectPath": {
          "type": "string",
          "description": "Managed project path; defaults to selected project."
        },
        "action": {
          "type": "string",
          "enum": [
            "project_folder",
            "build_folder",
            "vscode",
            "android_studio",
            "android_project",
            "ios_project",
            "macos_project",
            "windows_project",
            "reveal"
          ]
        },
        "filePath": {
          "type": "string"
        }
      },
      "required": [
        "action"
      ],
      "additionalProperties": false
    }
  },
  {
    "name": "flutter_manager_console_action",
    "description": "Open/clear project console, select or close console tab.",
    "inputSchema": {
      "type": "object",
      "properties": {
        "projectPath": {
          "type": "string",
          "description": "Managed project path; defaults to selected project."
        },
        "action": {
          "type": "string",
          "enum": [
            "open",
            "clear",
            "select",
            "close"
          ]
        },
        "tabId": {
          "type": "string"
        }
      },
      "required": [
        "action"
      ],
      "additionalProperties": false
    }
  },
  {
    "name": "flutter_manager_dependencies",
    "description": "Read pubspec or apply additions/removals and run Pub Get. New production dependencies require user approval.",
    "inputSchema": {
      "type": "object",
      "properties": {
        "projectPath": {
          "type": "string",
          "description": "Managed project path; defaults to selected project."
        },
        "additions": {
          "type": "array",
          "items": {
            "type": "object",
            "properties": {
              "name": {
                "type": "string"
              },
              "constraint": {
                "type": "string"
              },
              "development": {
                "type": "boolean"
              }
            },
            "required": [
              "name",
              "constraint"
            ],
            "additionalProperties": false
          }
        },
        "removals": {
          "type": "array",
          "items": {
            "type": "string"
          }
        }
      },
      "required": [],
      "additionalProperties": false
    }
  },
  {
    "name": "flutter_manager_create_project",
    "description": "Create and register a Flutter project in a new directory.",
    "inputSchema": {
      "type": "object",
      "properties": {
        "name": {
          "type": "string"
        },
        "parentDirectory": {
          "type": "string"
        },
        "directoryName": {
          "type": "string"
        },
        "organization": {
          "type": "string"
        },
        "sdkDirectory": {
          "type": "string"
        },
        "sdkVersion": {
          "type": "string"
        },
        "platforms": {
          "type": "array",
          "items": {
            "type": "string"
          }
        },
        "template": {
          "type": "string",
          "enum": [
            "app",
            "module",
            "package",
            "plugin",
            "packageFfi",
            "pluginFfi"
          ]
        }
      },
      "required": [
        "name",
        "parentDirectory",
        "directoryName"
      ],
      "additionalProperties": false
    }
  },
  {
    "name": "flutter_manager_parse_log",
    "description": "Read/decrypt a selected log file, returning at most 1000 lines.",
    "inputSchema": {
      "type": "object",
      "properties": {
        "filePath": {
          "type": "string"
        },
        "isEncrypted": {
          "type": "boolean"
        }
      },
      "required": [
        "filePath"
      ],
      "additionalProperties": false
    }
  },
  {
    "name": "flutter_manager_settings",
    "description": "Update console settings, global distribution credentials or compiler path. Credentials are write-only.",
    "inputSchema": {
      "type": "object",
      "properties": {
        "autoOpenConsoleWindow": {
          "type": "boolean"
        },
        "showMainWindowConsole": {
          "type": "boolean"
        },
        "showConsoleQuickCommands": {
          "type": "boolean"
        },
        "buildOpensConsoleWindow": {
          "type": "boolean"
        },
        "pgyerApiKey": {
          "type": "string"
        },
        "firApiToken": {
          "type": "string"
        },
        "innoCompilerPath": {
          "type": "string"
        }
      },
      "required": [],
      "additionalProperties": false
    }
  }
];
