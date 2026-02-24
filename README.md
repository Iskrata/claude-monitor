# Claude Monitor

Lightweight macOS menubar app showing Claude Code session status.

**Display:** `active⚡waiting` — active sessions (CPU > 3%) and sessions waiting for your approval.

## How it works

- **Active**: detected via `ps` CPU usage (Claude streams at 8-30% CPU)
- **Waiting**: detected via Claude Code [hooks](https://docs.anthropic.com/en/docs/claude-code/hooks) — a `Notification` hook writes to `~/.claude/monitor/waiting/`, cleared on `UserPromptSubmit` or `SessionEnd`

Click the menubar item to see project names grouped by state.

## Install

```bash
git clone https://github.com/Iskrata/claude-monitor.git
cd claude-monitor
bash install.sh
```

Then add hooks to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Notification": [{"matcher": "", "hooks": [{"type": "command", "command": "bash ~/.claude/monitor/hook.sh notify"}]}],
    "UserPromptSubmit": [{"matcher": "", "hooks": [{"type": "command", "command": "bash ~/.claude/monitor/hook.sh clear"}]}],
    "SessionEnd": [{"matcher": "", "hooks": [{"type": "command", "command": "bash ~/.claude/monitor/hook.sh clear"}]}]
  }
}
```

## Requirements

- macOS
- Swift compiler (ships with Xcode CLI tools)
- Claude Code CLI
