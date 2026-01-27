#!/usr/bin/env node

/**
 * Claude Controller MCP Server
 *
 * Provides tools for Claude to interact with:
 * - iPad trackpad controller
 * - Macro keyboard (option selection)
 * - Text input and notifications
 * - Future extensibility
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  Tool,
} from "@modelcontextprotocol/sdk/types.js";
import * as http from "http";

// Configuration
const MACOS_APP_PORT = 19847;
const MACOS_APP_HOST = "localhost";

// Tool definitions
const tools: Tool[] = [
  // ============ MACRO KEYBOARD ============
  {
    name: "send_options_to_ipad",
    description: `Send numbered options to the iPad for quick selection via the macro keyboard.
When you present the user with numbered choices (like "1. Yes  2. No  3. Skip"),
call this tool to display them as tappable buttons on the iPad.
The user can tap a button and it will type the number + Enter for them.`,
    inputSchema: {
      type: "object",
      properties: {
        options: {
          type: "array",
          description: "Array of options to display",
          items: {
            type: "object",
            properties: {
              number: { type: "number", description: "Option number (1, 2, 3, etc.)" },
              text: { type: "string", description: "Option label text" }
            },
            required: ["number", "text"]
          }
        },
        needsAttention: {
          type: "boolean",
          description: "If true, plays a chime and haptic to alert the user",
          default: true
        }
      },
      required: ["options"]
    }
  },
  {
    name: "clear_ipad_options",
    description: "Clear the macro option buttons from the iPad display",
    inputSchema: {
      type: "object",
      properties: {}
    }
  },

  // ============ NOTIFICATIONS ============
  {
    name: "notify_ipad",
    description: "Send a notification/alert to the iPad with optional sound and haptic feedback. Use this to get the user's attention.",
    inputSchema: {
      type: "object",
      properties: {
        message: {
          type: "string",
          description: "Message to display"
        },
        playSound: {
          type: "boolean",
          description: "Play alert sound",
          default: true
        },
        haptic: {
          type: "boolean",
          description: "Trigger haptic feedback",
          default: true
        }
      },
      required: ["message"]
    }
  },

  // ============ STATUS ============
  {
    name: "get_connection_status",
    description: "Check if the iPad is connected to the Mac controller app",
    inputSchema: {
      type: "object",
      properties: {}
    }
  }
];

// Helper to send requests to the macOS app
async function sendToMacApp(endpoint: string, data: object): Promise<{ success: boolean; data?: any; error?: string }> {
  return new Promise((resolve) => {
    const postData = JSON.stringify(data);

    const options = {
      hostname: MACOS_APP_HOST,
      port: MACOS_APP_PORT,
      path: endpoint,
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Content-Length": Buffer.byteLength(postData)
      },
      timeout: 5000
    };

    const req = http.request(options, (res) => {
      let body = "";
      res.on("data", (chunk) => body += chunk);
      res.on("end", () => {
        try {
          const json = JSON.parse(body);
          resolve({ success: true, data: json });
        } catch {
          resolve({ success: true, data: body });
        }
      });
    });

    req.on("error", (err) => {
      resolve({ success: false, error: `Failed to connect to ClaudeController app: ${err.message}. Is the app running?` });
    });

    req.on("timeout", () => {
      req.destroy();
      resolve({ success: false, error: "Connection to ClaudeController app timed out" });
    });

    req.write(postData);
    req.end();
  });
}

// Tool handlers
async function handleTool(name: string, args: Record<string, unknown>): Promise<string> {
  switch (name) {
    case "send_options_to_ipad": {
      const options = args.options as Array<{ number: number; text: string }>;
      const needsAttention = args.needsAttention !== false;

      const result = await sendToMacApp("/macro-options", {
        options,
        needsAttention
      });

      if (result.success) {
        return `Sent ${options.length} options to iPad. User can tap to select.`;
      }
      return result.error || "Failed to send options";
    }

    case "clear_ipad_options": {
      const result = await sendToMacApp("/macro-clear", {});
      return result.success ? "Cleared options from iPad" : (result.error || "Failed to clear");
    }

    case "notify_ipad": {
      const result = await sendToMacApp("/notify", {
        message: args.message,
        playSound: args.playSound !== false,
        haptic: args.haptic !== false
      });
      return result.success ? "Notification sent to iPad" : (result.error || "Failed to send notification");
    }

    case "get_connection_status": {
      const result = await sendToMacApp("/status", {});
      if (result.success && result.data) {
        const status = result.data;
        if (status.connected) {
          return `iPad connected: ${status.deviceName || "Unknown device"}`;
        }
        return "iPad not connected";
      }
      return result.error || "Could not get status";
    }

    default:
      return `Unknown tool: ${name}`;
  }
}

// Create and run server
async function main() {
  const server = new Server(
    {
      name: "claude-controller",
      version: "1.0.0"
    },
    {
      capabilities: {
        tools: {}
      }
    }
  );

  // List tools
  server.setRequestHandler(ListToolsRequestSchema, async () => ({
    tools
  }));

  // Handle tool calls
  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const { name, arguments: args } = request.params;

    try {
      const result = await handleTool(name, args || {});
      return {
        content: [{ type: "text", text: result }]
      };
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      return {
        content: [{ type: "text", text: `Error: ${message}` }],
        isError: true
      };
    }
  });

  // Connect via stdio
  const transport = new StdioServerTransport();
  await server.connect(transport);

  console.error("Claude Controller MCP server running");
}

main().catch(console.error);
