#!/bin/bash
set -e

INSTALL_DIR="$HOME/bin"
HOOK_DIR="$HOME/.claude/monitor"
PLIST_DIR="$HOME/Library/LaunchAgents"
LABEL="com.user.claudepulse"
HOOK_PATH="$HOOK_DIR/hook.sh"

mkdir -p "$INSTALL_DIR" "$HOOK_DIR/waiting" "$PLIST_DIR"

# Compile
echo "Compiling..."
swiftc -O -o "$INSTALL_DIR/ClaudePulse" "$(dirname "$0")/ClaudePulse.swift"

# Install hook script
cp "$(dirname "$0")/hook.sh" "$HOOK_PATH"
chmod +x "$HOOK_PATH"

# LaunchAgent plist
cat > "$PLIST_DIR/$LABEL.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>Program</key>
    <string>$INSTALL_DIR/ClaudePulse</string>
    <key>RunAtLoad</key>
    <true/>
    <key>LimitLoadToSessionType</key>
    <string>Aqua</string>
</dict>
</plist>
EOF

# Load agent
launchctl unload "$PLIST_DIR/$LABEL.plist" 2>/dev/null || true
launchctl load "$PLIST_DIR/$LABEL.plist"

# Print hook config to add to ~/.claude/settings.json
cat <<MSG

ClaudePulse installed and running.

Add these hooks to ~/.claude/settings.json:

  "hooks": {
    "Notification": [{"matcher": "", "hooks": [{"type": "command", "command": "bash $HOOK_PATH notify"}]}],
    "UserPromptSubmit": [{"matcher": "", "hooks": [{"type": "command", "command": "bash $HOOK_PATH clear"}]}],
    "SessionEnd": [{"matcher": "", "hooks": [{"type": "command", "command": "bash $HOOK_PATH clear"}]}]
  }

MSG
