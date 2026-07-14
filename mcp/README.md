# Driving processFNIRS2 from an MCP client

This folder lets an AI coding agent (Claude Code, Claude Desktop, VS Code /
Copilot, Codex) drive processFNIRS2 through the **official MATLAB MCP Server**
from MathWorks. The MCP server is generic — it starts MATLAB and runs code — so
the value added here is a curated **tool card** (`TOOL_CARD.md`) that teaches the
agent the correct pf2 idioms, plus ready-to-paste client configuration.

> This is the "MATLAB as the MCP server" path. Publishing individual pf2
> functions as typed MCP tools (via MATLAB Production Server) is a second,
> larger effort not covered here.

---

## 1. Install the MATLAB MCP Server

Prerequisites: MATLAB R2021a or later on the system `PATH` (this repo targets
R2025b).

**macOS (Apple Silicon):**

```bash
curl -L -o ~/bin/matlab-mcp-server \
  https://github.com/matlab/matlab-mcp-server/releases/latest/download/matlab-mcp-server-macos-arm64
chmod +x ~/bin/matlab-mcp-server
```

macOS (Intel) uses the `...-macos-x64` asset.

**Windows (x64):** download `matlab-mcp-server-windows-x64.exe` from the
[releases page](https://github.com/matlab/matlab-mcp-server/releases/latest) and
save it somewhere stable, e.g. `%USERPROFILE%\bin\matlab-mcp-server-windows-x64.exe`.
No `chmod` step is needed. In PowerShell:

```powershell
mkdir $env:USERPROFILE\bin -Force
Invoke-WebRequest -Uri "https://github.com/matlab/matlab-mcp-server/releases/latest/download/matlab-mcp-server-windows-x64.exe" `
  -OutFile "$env:USERPROFILE\bin\matlab-mcp-server-windows-x64.exe"
```

**Linux (x64):** download `matlab-mcp-server-linux-x64` from the releases page and
`chmod +x` it.

Alternatively, on any platform with Go installed, build from source:
`go install github.com/matlab/matlab-mcp-server/cmd/matlab-mcp-server@latest`.

> **Path conventions used below.** Examples show macOS/Linux paths
> (`~/bin/matlab-mcp-server`, `/Applications/MATLAB_R2025b.app`). On Windows,
> substitute the `.exe` binary path (e.g.
> `C:\Users\YOU\bin\matlab-mcp-server-windows-x64.exe`) and the MATLAB install
> root (e.g. `C:\Program Files\MATLAB\R2025b`). In JSON files, Windows paths
> must escape backslashes (`C:\\Users\\YOU\\...`).

## 2. Register it with your client

**Claude Code** (run once, from anywhere):

```bash
# macOS / Linux
claude mcp add --transport stdio matlab -- \
  ~/bin/matlab-mcp-server \
  --matlab-root /Applications/MATLAB_R2025b.app \
  --matlab-display-mode=nodesktop
```

```powershell
# Windows (PowerShell) — one line
claude mcp add --transport stdio matlab -- "C:\Users\YOU\bin\matlab-mcp-server-windows-x64.exe" --matlab-root "C:\Program Files\MATLAB\R2025b" --matlab-display-mode=nodesktop
```

**VS Code / Copilot** — copy [`mcp.example.json`](mcp.example.json) to
`.vscode/mcp.json` and fix the binary + MATLAB paths (the file carries both a
macOS/Linux and a Windows entry — keep the one for your OS).

**Claude Desktop** — install the `matlab-mcp-server.mcpb` bundle from the
releases page (Settings → Extensions → Install Extension), then configure the
MATLAB root there.

**Codex** (run once):

```bash
# macOS / Linux
codex mcp add matlab -- \
  ~/bin/matlab-mcp-server \
  --matlab-root /Applications/MATLAB_R2025b.app \
  --matlab-display-mode=nodesktop
```

```powershell
# Windows (PowerShell) — one line
codex mcp add matlab -- "C:\Users\YOU\bin\matlab-mcp-server-windows-x64.exe" --matlab-root "C:\Program Files\MATLAB\R2025b" --matlab-display-mode=nodesktop
```

On Windows, also add `env_vars = ["WINDIR"]` to the server's entry in
`config.toml` (required for MATLAB to launch).

**LM Studio** (v0.3.17+) — MCP servers are defined in an `mcp.json` that uses
Cursor's `mcpServers` notation. In the app, open the **Program** tab in the
right sidebar → **Install → Edit mcp.json**, then add:

```json
{
  "mcpServers": {
    "matlab": {
      "command": "/Users/YOU/bin/matlab-mcp-server",
      "args": [
        "--matlab-root", "/Applications/MATLAB_R2025b.app",
        "--matlab-display-mode=nodesktop",
        "--disable-telemetry=true"
      ]
    }
  }
}
```

On Windows, use the `.exe` and escaped paths:

```json
{
  "mcpServers": {
    "matlab": {
      "command": "C:\\Users\\YOU\\bin\\matlab-mcp-server-windows-x64.exe",
      "args": [
        "--matlab-root", "C:\\Program Files\\MATLAB\\R2025b",
        "--matlab-display-mode=nodesktop",
        "--disable-telemetry=true"
      ]
    }
  }
}
```

Saving the file reloads the server automatically. Note the key is `mcpServers`
here, versus `servers` in the VS Code format above.

Useful server flags: `--initialize-matlab-on-startup=true` (warm start),
`--matlab-session-mode=existing` (attach to a MATLAB you already have open),
`--disable-telemetry=true`.

## 3. Point the agent at pf2

The MATLAB MCP Server exposes these tools:

| Tool | Purpose |
|------|---------|
| `detect_matlab_toolboxes` | Report MATLAB + toolbox versions |
| `check_matlab_code` | Static analysis (lint) of a `.m` file |
| `evaluate_matlab_code` | Run a MATLAB code string |
| `run_matlab_file` | Run a `.m` script |
| `run_matlab_test_file` | Run a `matlab.unittest` file |

Before a session, make sure the agent has read [`TOOL_CARD.md`](TOOL_CARD.md) —
it carries the canonical import → process → blocks → export recipes, the
headless/GUI rules, and the "gotchas" that keep generated code correct. For
full API detail, the agent can use MATLAB `help` (e.g. `help processFNIRS2`)
and the `docs/` reference.

## Notes / gotchas

- **Add pf2 to the path first.** The agent's first `evaluate_matlab_code` call
  in a fresh session should `cd` to this repo (or `addpath(genpath(...))`) so
  `pf2.*` resolves.
- **Suppress the GUI.** Any call that captures an output (`out = processFNIRS2(data)`)
  runs headless; a bare `processFNIRS2(data)` opens the GUI and will block the
  MCP session. See the tool card.
- **3D renders** must use the `'savePath'` option, not `figure('Visible','off')`
  + `saveas` — the latter is unreliable headless.
- **Long jobs**: `evaluate_matlab_code` is synchronous. For batch processing of
  many subjects, have the agent write a `.m` script and use `run_matlab_file`.
