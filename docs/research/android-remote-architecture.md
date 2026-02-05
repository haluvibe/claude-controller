# Android Remote Control Architecture Research

## Executive Summary

This document analyzes network architecture and security options for controlling a Mac Mini running Claude CLI from an Android phone over the internet. The goal is to extend the existing ClaudeController system (currently iPad-only via local Bonjour/TCP) to support remote Android access.

**Recommended Architecture**: Tailscale + SSH + tmux, with the existing MCP bridge extended to accept authenticated connections over the Tailscale network.

---

## 1. Current Architecture Analysis

### Existing System Components

```
+------------------+     Bonjour/TCP      +------------------+
|   iPad App       | <------------------> |   macOS App      |
| (TrackpadCtrl)   |     Port 9847        | (ClaudeCtrl)     |
+------------------+                      +------------------+
                                                   |
                                                   | HTTP localhost:19847
                                                   v
                                          +------------------+
                                          |   MCP Server     |
                                          | (Node.js stdio)  |
                                          +------------------+
                                                   |
                                                   | MCP protocol
                                                   v
                                          +------------------+
                                          |   Claude Code    |
                                          +------------------+
```

### Key Observations

1. **iPad communication**: Uses a custom binary protocol over TCP port 9847, discovered via Bonjour (`_claudecontrol._tcp.`)
2. **MCP bridge**: HTTP server on port 19847 accepts JSON commands and forwards to iPad
3. **No authentication**: Current system trusts local network - any device can connect
4. **No encryption**: TCP traffic is unencrypted (acceptable on trusted local network)
5. **Stateful connections**: TCP connection maintained for real-time input forwarding

### What Works Well

- Bonjour discovery eliminates configuration
- Low-latency TCP for mouse/keyboard input
- MCP integration allows Claude to control iPad feedback
- Permission request flow blocks until iPad responds

---

## 2. Network Connectivity Options

### 2.1 Tailscale (Recommended)

**What it is**: Mesh VPN built on WireGuard, managed via central coordination servers.

**How it works**:
- Each device runs Tailscale client and gets a stable IP (100.x.y.z)
- NAT traversal handled automatically (DERP relays as fallback)
- Traffic is end-to-end encrypted with WireGuard

**Pros**:
- Zero configuration once set up
- Works through NAT, firewalls, cellular
- Excellent NAT traversal (uses STUN/ICE-like mechanisms)
- Free tier supports 100 devices, 3 users
- MagicDNS provides hostname resolution
- ACL support for fine-grained access control

**Cons**:
- [Battery drain issues on Android](https://github.com/tailscale/tailscale/issues/17547) when offline
- Depends on Tailscale coordination servers (though traffic is direct)
- Keep-alive packets consume battery on mobile

**Battery Impact on Android**:
- Generally acceptable when online (~1-5% additional drain)
- Problematic when phone has no internet (CPU spin bug)
- Recommendation: Use Android's VPN always-on with caution, or toggle manually

**Setup Complexity**: Low (5-10 minutes per device)

### 2.2 ZeroTier

**What it is**: Similar to Tailscale but with custom protocol, more networking features.

**Pros**:
- Self-hostable (moon servers)
- Layer 2 Ethernet emulation
- More configuration options
- Cross-platform including IoT

**Cons**:
- More complex setup than Tailscale
- Custom protocol (not WireGuard)
- Smaller community

**Verdict**: Tailscale is simpler for this use case. ZeroTier only if self-hosting required.

### 2.3 Cloudflare Tunnel

**What it is**: Outbound-only tunnel that exposes services via Cloudflare's edge network.

**How it works**:
- `cloudflared` daemon on Mac creates outbound connection to Cloudflare
- Cloudflare assigns a hostname (e.g., `claude.yourdomain.com`)
- Requests route through Cloudflare's network to your origin
- Supports Zero Trust authentication (Google, GitHub, etc.)

**Pros**:
- No open ports on home network
- Free, unlimited bandwidth
- Built-in DDoS protection
- Zero Trust authentication (very strong)
- Works from any internet connection

**Cons**:
- Requires domain hosted on Cloudflare
- Added latency through Cloudflare's network (~20-50ms)
- No UDP support (problematic for some protocols)
- All traffic visible to Cloudflare

**Best for**: Exposing web services, not low-latency input control.

### 2.4 Raw WireGuard

**What it is**: Direct WireGuard VPN without Tailscale management layer.

**Pros**:
- Most efficient (kernel-level on supported platforms)
- Full control over configuration
- No third-party coordination servers
- [Better battery life than Tailscale](https://news.ycombinator.com/item?id=33650956) in some cases

**Cons**:
- Manual key exchange and configuration
- Must handle NAT traversal yourself (port forwarding or relay)
- No automatic peer discovery

**Best for**: Advanced users who want maximum control and efficiency.

### 2.5 ngrok

**What it is**: Quick tunneling for development/testing.

**Pros**:
- Single command setup
- Free tier available

**Cons**:
- Not designed for always-on
- Rate limits on free tier
- URL changes on restart (free tier)
- All traffic through ngrok servers

**Best for**: Quick testing only, not production.

### Recommendation Matrix

| Criteria | Tailscale | ZeroTier | CF Tunnel | WireGuard | ngrok |
|----------|-----------|----------|-----------|-----------|-------|
| Setup ease | +++++ | +++ | ++++ | ++ | +++++ |
| Battery (mobile) | +++ | +++ | N/A | ++++ | N/A |
| Latency | ++++ | ++++ | +++ | +++++ | ++ |
| Security | ++++ | ++++ | +++++ | ++++ | +++ |
| Self-hostable | Partial | Yes | No | Yes | No |
| Cost | Free tier | Free tier | Free | Free | Limited |

**Winner: Tailscale** - Best balance of simplicity, security, and performance for this use case.

---

## 3. Mac Mini Server Component Options

### 3.1 Option A: SSH + tmux (Simplest)

**Architecture**:
```
Android App --> SSH (via Tailscale) --> Mac Mini
                                         |
                                         v
                                    tmux session
                                         |
                                         v
                                    claude -p "..."
```

**How it works**:
1. Android connects via SSH to Mac (using Tailscale IP)
2. Attach to persistent tmux session
3. Run Claude CLI commands directly

**Pros**:
- Zero custom server code needed
- Works today with standard tools
- tmux preserves session on disconnect
- Full shell access for debugging

**Cons**:
- Limited UI (terminal only)
- No structured API for app integration
- Harder to build rich mobile UI

**Process management**: tmux handles session persistence. Add to `~/.bashrc`:
```bash
# Auto-attach to claude session
if [[ -z "$TMUX" ]] && [[ "$SSH_CONNECTION" != "" ]]; then
    tmux attach -t claude 2>/dev/null || tmux new -s claude
fi
```

### 3.2 Option B: Extend MCP Bridge (Recommended for Rich UI)

**Architecture**:
```
Android App --> HTTPS (via Tailscale) --> MCP Bridge (extended)
                                              |
              +-------------------------------+
              |                               |
              v                               v
         Existing iPad          Claude CLI subprocess
         functionality          (managed sessions)
```

**Changes needed**:
1. Add authentication to MCP bridge (token-based)
2. Add Claude CLI session management endpoints
3. Add WebSocket support for streaming output
4. Bind to Tailscale IP (not just localhost)

**New endpoints**:
```
POST /claude/session/start    - Start new Claude session
POST /claude/session/send     - Send message to session
GET  /claude/session/output   - Stream output (SSE/WebSocket)
POST /claude/session/stop     - Terminate session
GET  /claude/sessions         - List active sessions
```

**Pros**:
- Reuses existing infrastructure
- Structured API for mobile app
- Can support both iPad and Android
- Full control over Claude interaction

**Cons**:
- Development effort required
- Must handle process lifecycle

### 3.3 Option C: WebSocket Server (Best for Real-time)

**Architecture**:
```
Android App <---> WebSocket (via Tailscale) <---> WS Server
                                                      |
                                                      v
                                               Claude CLI
                                               (pty.js)
```

**How it works**:
1. Node.js server creates pseudo-terminal for Claude
2. WebSocket streams stdin/stdout bidirectionally
3. Full terminal emulation on mobile

**Implementation sketch**:
```javascript
import { WebSocketServer } from 'ws';
import pty from 'node-pty';

const wss = new WebSocketServer({ port: 8080 });

wss.on('connection', (ws, req) => {
    // Authenticate first
    const token = req.headers['authorization'];
    if (!validateToken(token)) {
        ws.close(4001, 'Unauthorized');
        return;
    }

    const shell = pty.spawn('claude', ['-p'], {
        name: 'xterm-256color',
        cols: 80,
        rows: 24
    });

    shell.on('data', data => ws.send(data));
    ws.on('message', data => shell.write(data));
    ws.on('close', () => shell.kill());
});
```

**Pros**:
- Real-time bidirectional communication
- Full terminal experience
- Low latency

**Cons**:
- More complex than HTTP
- Must handle reconnection logic
- Need terminal emulation on client

### 3.4 Option D: VS Code Remote-style Architecture

**How VS Code does it**:
1. Client requests server start via lightweight "tunnel" connection
2. Server installs/updates itself on remote
3. Creates SSH port tunnel or uses Microsoft dev tunnels
4. All extension code runs on server, UI renders locally

**Applicable pattern**:
- "Server" component that manages Claude sessions
- Client only handles UI rendering
- Server sends structured updates (not raw terminal)

**This is essentially Option B with more structure**.

### Recommendation

**For MVP**: Option A (SSH + tmux) - Works immediately, no development

**For Production**: Option B (Extended MCP Bridge) - Structured API, better UX

---

## 4. Security Architecture

### 4.1 Authentication Flow

**Recommended: Tailscale + Pre-shared Token**

```
1. SETUP (one-time):
   - Generate secure token on Mac: openssl rand -hex 32
   - Store in ~/.claude-controller/auth.json
   - Add to Android app settings manually

2. CONNECTION:
   Android               Tailscale Network              Mac Mini
      |                        |                           |
      |---[Connect to Tailscale]-->                        |
      |                        |                           |
      |---[HTTPS + Bearer token]---------------------->    |
      |                        |                   [Validate token]
      |<--[200 OK + session ID]-----------------------     |
      |                        |                           |
      |---[Subsequent requests with session]--->           |
```

**Why not OAuth?**: Overkill for single-user system. Pre-shared token is simpler and equally secure when combined with Tailscale network isolation.

### 4.2 Authorization (Command Restrictions)

**Recommended: Allowlist approach**

```json
{
  "allowed_operations": [
    "claude.session.start",
    "claude.session.send",
    "claude.session.output",
    "claude.session.stop",
    "ipad.notify",
    "ipad.options",
    "status"
  ],
  "denied_operations": [
    "system.*",
    "shell.*"
  ]
}
```

**No arbitrary shell access** - Only Claude CLI and predefined operations.

### 4.3 Encryption in Transit

**Layers**:
1. **Tailscale/WireGuard**: All traffic encrypted at network level
2. **TLS (optional)**: HTTPS on top for defense in depth

**Recommendation**: Tailscale encryption is sufficient. Adding TLS useful if paranoid or if exposing to non-Tailscale networks later.

### 4.4 Rate Limiting

```javascript
const rateLimit = {
    windowMs: 60 * 1000,  // 1 minute
    maxRequests: 60,      // 60 requests per minute
    maxSessions: 3,       // Max concurrent Claude sessions
    maxMessageLength: 10000  // Characters per message
};
```

### 4.5 Audit Logging

```javascript
const auditLog = {
    timestamp: new Date().toISOString(),
    client_ip: req.ip,
    action: "claude.session.send",
    session_id: "abc123",
    message_preview: message.substring(0, 100),
    success: true
};
```

Store in rotating log files, retain for 30 days.

---

## 5. Existing Solutions to Learn From

### 5.1 VS Code Remote

**Key insights**:
- [Two-phase connection](https://code.visualstudio.com/docs/remote/troubleshooting): First to install server, second for work
- Server installs itself, reducing client complexity
- Port forwarding for additional services
- [Dev tunnels](https://code.visualstudio.com/docs/remote/tunnels) as alternative to SSH

**Applicable**: Install/update server component automatically on first connect.

### 5.2 GitHub Codespaces

**Key insights**:
- [VM-based compute](https://docs.github.com/en/codespaces/getting-started/deep-dive) with persistent storage
- Browser and VS Code clients
- [GitHub CLI `gh codespace ssh`](https://docs.github.com/en/codespaces/developing-in-a-codespace/using-github-codespaces-with-github-cli) for terminal access
- No native mobile app (feature requests exist)

**Applicable**: CLI-based access pattern (`gh codespace ssh` = `ssh claude-mac`)

### 5.3 Replit Mobile

**Key insights**:
- [WebSocket-based communication](https://blog.replit.com/eval) for real-time sync
- [Local-first features](https://blog.replit.com/mobile-app) for offline/spotty connections
- Custom input controls ("joystick" for cursor navigation)
- [Distributed WebSocket rate limiting](https://blog.replit.com/websocket-rate-limiting) via Redis

**Applicable**: WebSocket for streaming, optimistic UI updates.

### 5.4 Mosh + tmux Pattern

**Key insights**:
- [Mosh handles network roaming](https://mosh.org/) via UDP
- [tmux persists sessions](https://dev.to/idoko/persistent-ssh-sessions-with-tmux-25dm) across disconnects
- [Combined workflow](https://kareemf.com/on-agentic-coding-from-anywhere) for mobile coding

**Applicable**: Session persistence strategy for Claude.

---

## 6. Extending Existing Architecture

### 6.1 Minimal Changes (SSH approach)

**No code changes needed!**

```bash
# On Mac Mini
brew install tailscale
sudo tailscale up

# Note the Tailscale IP (e.g., 100.64.0.1)

# On Android
# Install Tailscale from Play Store
# Sign in with same account
# SSH to Mac's Tailscale IP
```

**Android app options**:
- [Termux](https://termux.dev/) + SSH
- [Blink Shell](https://blink.sh/) (iOS, but shows the pattern)
- JuiceSSH or similar

### 6.2 Extending MCP Bridge

**Changes to `MCPBridgeServer.swift`**:

1. **Bind to all interfaces** (currently localhost only):
```swift
// Change from:
listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)

// To (bind to Tailscale interface):
let endpoint = NWEndpoint.hostPort(host: "0.0.0.0", port: NWEndpoint.Port(rawValue: port)!)
```

2. **Add authentication middleware**:
```swift
private func authenticateRequest(_ request: String) -> Bool {
    // Extract Authorization header
    // Validate against stored token
}
```

3. **Add Claude session management**:
```swift
private var claudeSessions: [String: Process] = [:]

case ("POST", "/claude/start"):
    let sessionId = startClaudeSession()
    sendResponse(connection, status: "200 OK", body: ["sessionId": sessionId])
```

### 6.3 Alternative: Separate Remote Server

**New component**: `ClaudeRemoteServer` (Node.js or Swift)

```
                      Tailscale Network
                            |
+------------------+        |        +------------------+
|   Android App    | <------+------> | ClaudeRemoteServer|
+------------------+                 +------------------+
                                             |
                                     +-------+-------+
                                     |               |
                                     v               v
                              +----------+    +------------+
                              | Claude   |    | MCP Bridge |
                              | Sessions |    | (existing) |
                              +----------+    +------------+
```

**Benefits**:
- Separate concerns from existing system
- Can be developed/tested independently
- Doesn't risk breaking iPad functionality

---

## 7. Recommended Architecture

### Final Recommendation: Tailscale + Extended MCP Bridge

```
+------------------+                              +------------------+
|   Android App    |                              |   iPad App       |
| (new, Kotlin)    |                              | (existing)       |
+------------------+                              +------------------+
         |                                                 |
         | HTTPS + Auth Token                              | TCP (raw)
         | (via Tailscale)                                 | (local only)
         |                                                 |
         v                                                 v
+------------------------------------------------------------------------+
|                        Mac Mini                                          |
|  +------------------------------------------------------------------+   |
|  |                    MCP Bridge (Extended)                          |   |
|  |  - Port 19847 (localhost for MCP)                                |   |
|  |  - Port 19848 (Tailscale IP for Android, authenticated)          |   |
|  +------------------------------------------------------------------+   |
|         |                              |                                 |
|         v                              v                                 |
|  +---------------+              +---------------+                        |
|  | Claude CLI    |              | iPad Comms    |                        |
|  | Sessions      |              | (existing)    |                        |
|  +---------------+              +---------------+                        |
|         |                                                               |
|         v                                                               |
|  +---------------+                                                      |
|  | Claude Code   |                                                      |
|  +---------------+                                                      |
+------------------------------------------------------------------------+
```

### Implementation Phases

**Phase 1: SSH MVP (1 day)**
- Install Tailscale on Mac and Android
- Use existing SSH + tmux for access
- Validate workflow, measure latency

**Phase 2: API Server (1 week)**
- Extend MCP bridge with authentication
- Add Claude session management endpoints
- Test from Android via curl/Postman

**Phase 3: Android App (2-3 weeks)**
- Native Kotlin app with:
  - Tailscale status indicator
  - Claude chat interface
  - Session management
  - Push notifications (via FCM)

**Phase 4: Polish (1 week)**
- Error handling and reconnection
- Offline message queue
- Usage analytics

### Security Checklist

- [ ] Tailscale ACLs restrict access to Mac Mini only
- [ ] Pre-shared authentication token (32+ bytes)
- [ ] Rate limiting on all endpoints
- [ ] Audit logging enabled
- [ ] No arbitrary shell execution
- [ ] Session timeout (30 minutes idle)
- [ ] Token rotation mechanism

---

## 8. Quick Start Commands

### Tailscale Setup

```bash
# Mac Mini
brew install tailscale
sudo tailscale up --accept-routes
tailscale ip  # Note this IP

# Android
# Install from Play Store, sign in with same account
```

### SSH Test

```bash
# From Android (Termux)
pkg install openssh
ssh user@100.x.y.z  # Tailscale IP

# Start Claude in tmux
tmux new -s claude
claude -p "Hello from Android"
```

### MCP Bridge Test

```bash
# From Android
curl -X POST http://100.x.y.z:19847/status
# Should fail (not exposed yet)

# After extending to bind to Tailscale:
curl -H "Authorization: Bearer <token>" \
     -X POST http://100.x.y.z:19848/status
```

---

## Sources

### Network Solutions
- [Tailscale vs ZeroTier](https://tailscale.com/compare/zerotier)
- [Cloudflare Tunnel Setup Guide](https://eastondev.com/blog/en/posts/dev/20251130-cloudflare-tunnel-guide/)
- [Tailscale Android Battery Issues](https://github.com/tailscale/tailscale/issues/17547)
- [WireGuard Battery Impact](https://primevpndefender.com/does-wireguard-vpn-drain-battery/)

### Remote Development
- [VS Code Remote SSH](https://code.visualstudio.com/docs/remote/ssh)
- [VS Code Remote Tunnels](https://code.visualstudio.com/docs/remote/tunnels)
- [GitHub Codespaces CLI](https://docs.github.com/en/codespaces/developing-in-a-codespace/using-github-codespaces-with-github-cli)

### Session Persistence
- [Mosh Mobile Shell](https://mosh.org/)
- [Persistent SSH with tmux](https://dev.to/idoko/persistent-ssh-sessions-with-tmux-25dm)
- [Agentic Coding from Anywhere](https://kareemf.com/on-agentic-coding-from-anywhere)

### Architecture Patterns
- [Replit Mobile App Architecture](https://blog.replit.com/mobile-app)
- [Replit WebSocket Architecture](https://blog.replit.com/eval)
- [Replit Rate Limiting](https://blog.replit.com/websocket-rate-limiting)
