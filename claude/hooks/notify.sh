#!/bin/bash
# Claude Code hook: send desktop notification via Ghostty OSC 777
# Receives JSON on stdin with session context

INPUT=$(cat)

HOOK_EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // "unknown"')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
PROJECT_NAME=$(basename "${CWD:-unknown}")

case "$HOOK_EVENT" in
  Stop)
    MESSAGE="Finished working"
    ;;
  Notification)
    MESSAGE="Waiting for permission"
    ;;
  *)
    MESSAGE="$HOOK_EVENT"
    ;;
esac

# Walk up process tree to find an ancestor with a real TTY
PID=$$
TTY=""
while [ "$PID" != "1" ] && [ -n "$PID" ]; do
  T=$(ps -o tty= -p "$PID" 2>/dev/null | tr -d ' ')
  if [ -n "$T" ] && [ "$T" != "??" ] && [ -e "/dev/$T" ]; then
    TTY="/dev/$T"
    break
  fi
  PID=$(ps -o ppid= -p "$PID" 2>/dev/null | tr -d ' ')
done

if [ -z "$TTY" ]; then
  exit 0
fi

# Send OSC 777 desktop notification + bell to the Ghostty terminal
printf '\033]777;notify;%s;%s\007' "$PROJECT_NAME" "$MESSAGE" > "$TTY"
printf '\a' > "$TTY"

exit 0
