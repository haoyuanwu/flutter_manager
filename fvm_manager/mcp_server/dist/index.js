import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema, } from "@modelcontextprotocol/sdk/types.js";
const port = Number(process.env.FLUTTER_MANAGER_PORT ?? "17891");
const host = process.env.FLUTTER_MANAGER_HOST ?? "127.0.0.1";
const token = process.env.FLUTTER_MANAGER_TOKEN ?? "";
const baseUrl = `http://${host}:${port}`;
const projectPathProperty = {
    type: "string",
    description: "Flutter project path. If omitted, the app uses the selected project.",
};
const deviceIdProperty = {
    type: "string",
    description: "Flutter device id, for example an Android device serial.",
};
const flavorProperty = {
    type: "string",
    description: "Android flavor to pass to flutter run, for example android or huawei.",
};
const openConsoleProperty = {
    type: "boolean",
    description: "Whether Flutter Manager should open the console window. Defaults to true for run/rerun.",
};
const tools = [
    {
        name: "flutter_manager_list_projects",
        description: "List Flutter projects managed by Flutter Manager.",
        inputSchema: {
            type: "object",
            properties: {},
        },
    },
    {
        name: "flutter_manager_get_current_project",
        description: "Get the currently selected Flutter project.",
        inputSchema: {
            type: "object",
            properties: {},
        },
    },
    {
        name: "flutter_manager_select_project",
        description: "Select a managed Flutter project by path.",
        inputSchema: {
            type: "object",
            properties: { projectPath: projectPathProperty },
            required: ["projectPath"],
        },
    },
    {
        name: "flutter_manager_list_devices",
        description: "List Flutter devices detected by Flutter Manager.",
        inputSchema: {
            type: "object",
            properties: { projectPath: projectPathProperty },
        },
    },
    {
        name: "flutter_manager_run",
        description: "Start Flutter run for a project.",
        inputSchema: {
            type: "object",
            properties: {
                projectPath: projectPathProperty,
                deviceId: deviceIdProperty,
                flavor: flavorProperty,
                openConsole: openConsoleProperty,
            },
        },
    },
    {
        name: "flutter_manager_rerun",
        description: "Stop the current Flutter run and start it again.",
        inputSchema: {
            type: "object",
            properties: {
                projectPath: projectPathProperty,
                deviceId: deviceIdProperty,
                flavor: flavorProperty,
                openConsole: openConsoleProperty,
            },
        },
    },
    {
        name: "flutter_manager_stop",
        description: "Stop a running task. Provide taskId, or projectPath to stop the first task for that project.",
        inputSchema: {
            type: "object",
            properties: {
                projectPath: projectPathProperty,
                taskId: {
                    type: "string",
                    description: "Optional task id returned by read_console.",
                },
            },
        },
    },
    {
        name: "flutter_manager_read_console",
        description: "Read the command console output and running tasks.",
        inputSchema: {
            type: "object",
            properties: { projectPath: projectPathProperty },
        },
    },
    {
        name: "flutter_manager_pub_get",
        description: "Run flutter pub get for a project.",
        inputSchema: {
            type: "object",
            properties: { projectPath: projectPathProperty },
        },
    },
    {
        name: "flutter_manager_clean",
        description: "Run flutter clean for a project.",
        inputSchema: {
            type: "object",
            properties: { projectPath: projectPathProperty },
        },
    },
    {
        name: "flutter_manager_build",
        description: "Start the app's configured build command for a project.",
        inputSchema: {
            type: "object",
            properties: { projectPath: projectPathProperty },
        },
    },
    {
        name: "flutter_manager_devtools",
        description: "Open Flutter DevTools for the current running project.",
        inputSchema: {
            type: "object",
            properties: { projectPath: projectPathProperty },
        },
    },
];
const toolMap = {
    flutter_manager_list_projects: "list_projects",
    flutter_manager_get_current_project: "get_current_project",
    flutter_manager_select_project: "select_project",
    flutter_manager_list_devices: "list_devices",
    flutter_manager_run: "run",
    flutter_manager_rerun: "rerun",
    flutter_manager_stop: "stop",
    flutter_manager_read_console: "read_console",
    flutter_manager_pub_get: "pub_get",
    flutter_manager_clean: "clean",
    flutter_manager_build: "build",
    flutter_manager_devtools: "devtools",
};
const server = new Server({
    name: "flutter-manager-mcp",
    version: "0.1.0",
}, {
    capabilities: {
        tools: {},
    },
});
server.setRequestHandler(ListToolsRequestSchema, async () => ({ tools }));
server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const tool = toolMap[request.params.name];
    if (!tool) {
        throw new Error(`Unknown tool: ${request.params.name}`);
    }
    const result = await callFlutterManager(tool, request.params.arguments ?? {});
    return {
        content: [
            {
                type: "text",
                text: JSON.stringify(result, null, 2),
            },
        ],
    };
});
async function callFlutterManager(tool, payload) {
    const response = await fetch(`${baseUrl}/tools/${tool}`, {
        method: "POST",
        headers: {
            "content-type": "application/json",
            ...(token ? { authorization: `Bearer ${token}` } : {}),
        },
        body: JSON.stringify(payload ?? {}),
    });
    const text = await response.text();
    let data;
    try {
        data = text ? JSON.parse(text) : {};
    }
    catch {
        data = { ok: false, error: text };
    }
    if (!response.ok) {
        throw new Error(typeof data === "object" && data !== null && "error" in data
            ? String(data.error)
            : `Flutter Manager HTTP ${response.status}`);
    }
    return data;
}
const transport = new StdioServerTransport();
await server.connect(transport);
