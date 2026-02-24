#!/bin/bash
DIR="$HOME/.claude/monitor/waiting"
mkdir -p "$DIR"
INPUT=$(cat)
SID=$(echo "$INPUT" | /usr/bin/python3 -c "import sys,json;print(json.load(sys.stdin)['session_id'])")
case "$1" in
  notify)
    CWD=$(echo "$INPUT" | /usr/bin/python3 -c "import sys,json;print(json.load(sys.stdin).get('cwd',''))")
    echo "$CWD" > "$DIR/$SID"
    ;;
  clear)
    rm -f "$DIR/$SID"
    ;;
esac
