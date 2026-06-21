#!/bin/bash
# Keep macOS awake while an agent turn is active.

set -u

STATE_ROOT="${AGENT_CAFFEINATE_ROOT:-${TMPDIR:-/tmp}/agent-caffeinate}"
ACTIVE_DIR="$STATE_ROOT/active"
INACTIVE_DIR="$STATE_ROOT/inactive"
RELEASED_LOCK_DIR="$STATE_ROOT/released-locks"
LOCK_DIR="$STATE_ROOT/lock"
PID_FILE="$STATE_ROOT/caffeinate.pid"
WATCHER_PID_FILE="$STATE_ROOT/watcher.pid"
FLAGS="${AGENT_CAFFEINATE_FLAGS:--dis}"
WATCH_INTERVAL_SECONDS="${AGENT_CAFFEINATE_WATCH_INTERVAL_SECONDS:-30}"
STALE_AFTER_SECONDS="${AGENT_CAFFEINATE_STALE_AFTER_SECONDS:-172800}"

timestamp() {
  date +%s
}

ensure_dirs() {
  mkdir -p "$ACTIVE_DIR" "$INACTIVE_DIR" "$RELEASED_LOCK_DIR" 2>/dev/null || true
}

file_mtime() {
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0
}

read_key() {
  awk -F= -v key="$1" '$1 == key { print substr($0, length(key) + 2); exit }' "$2" 2>/dev/null
}

is_live_pid() {
  case "${1:-}" in
    ""|*[!0-9]*)
      return 1
      ;;
  esac

  kill -0 "$1" 2>/dev/null
}

is_caffeinate_pid() {
  is_live_pid "${1:-}" || return 1

  local command_name
  command_name="$(ps -o comm= -p "$1" 2>/dev/null | awk '{ print $1 }')"
  [ "${command_name##*/}" = "caffeinate" ]
}

release_lock() {
  if [ -d "$LOCK_DIR" ] && [ "$(read_key pid "$LOCK_DIR/owner" 2>/dev/null)" = "$$" ]; then
    mv "$LOCK_DIR" "$RELEASED_LOCK_DIR/lock.$(timestamp).$$" 2>/dev/null || true
  fi
}

acquire_lock() {
  ensure_dirs

  local attempts owner_pid lock_mtime lock_age
  attempts=0

  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    owner_pid="$(read_key pid "$LOCK_DIR/owner" 2>/dev/null || true)"

    if [ -n "$owner_pid" ] && ! is_live_pid "$owner_pid"; then
      mv "$LOCK_DIR" "$RELEASED_LOCK_DIR/stale-lock.$(timestamp).$$" 2>/dev/null || true
      continue
    fi

    if [ -z "$owner_pid" ]; then
      lock_mtime="$(file_mtime "$LOCK_DIR")"
      lock_age=$(($(timestamp) - lock_mtime))
      if [ "$lock_age" -gt 10 ]; then
        mv "$LOCK_DIR" "$RELEASED_LOCK_DIR/stale-empty-lock.$(timestamp).$$" 2>/dev/null || true
        continue
      fi
    fi

    attempts=$((attempts + 1))
    if [ "$attempts" -ge 50 ]; then
      exit 0
    fi

    sleep 0.1
  done

  printf 'pid=%s\ncreated_at=%s\n' "$$" "$(timestamp)" > "$LOCK_DIR/owner"
  trap release_lock EXIT INT TERM
}

json_get() {
  local input query
  input="$1"
  query="$2"

  if ! command -v jq >/dev/null 2>&1; then
    return 0
  fi

  printf '%s' "$input" | jq -r "$query // empty" 2>/dev/null
}

normalize_event() {
  case "$1" in
    UserPromptSubmit|user_prompt_submit|user-prompt-submit)
      echo "UserPromptSubmit"
      ;;
    Stop|stop)
      echo "Stop"
      ;;
    *)
      echo "$1"
      ;;
  esac
}

find_agent_pid() {
  local pid command_name command_line base
  pid="$PPID"

  while [ -n "$pid" ] && [ "$pid" != "1" ]; do
    command_name="$(ps -o comm= -p "$pid" 2>/dev/null | awk '{ print $1 }')"
    command_line="$(ps -o command= -p "$pid" 2>/dev/null)"
    base="${command_name##*/}"

    case "$base" in
      codex|claude)
        echo "$pid"
        return 0
        ;;
    esac

    case "$command_line" in
      codex|codex\ *|*/codex|*/codex\ *|claude|claude\ *|*/claude|*/claude\ *)
        echo "$pid"
        return 0
        ;;
    esac

    pid="$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')"
  done
}

detect_harness() {
  local pid command_name command_line base
  pid="${1:-}"

  if [ -n "$pid" ]; then
    command_name="$(ps -o comm= -p "$pid" 2>/dev/null | awk '{ print $1 }')"
    command_line="$(ps -o command= -p "$pid" 2>/dev/null)"
    base="${command_name##*/}"

    case "$base:$command_line" in
      codex:*|*:codex|*:codex\ *|*:*/codex|*:*/codex\ *)
        echo "codex"
        return 0
        ;;
      claude:*|*:claude|*:claude\ *|*:*/claude|*:*/claude\ *)
        echo "claude"
        return 0
        ;;
    esac
  fi

  echo "agent"
}

token_hash() {
  printf '%s' "$1" | shasum -a 256 | awk '{ print $1 }'
}

marker_path_for_input() {
  local input agent_pid harness session_id cwd transcript token_source
  input="$1"
  agent_pid="$2"
  harness="$3"

  session_id="$(json_get "$input" '.session_id // .sessionId // .session.id // .conversation_id // .conversationId')"
  cwd="$(json_get "$input" '.cwd // .workspace // .workspaceRoot')"
  transcript="$(json_get "$input" '.transcript_path // .transcriptPath')"

  if [ -n "$session_id" ]; then
    token_source="$harness:session:$session_id"
  elif [ -n "$transcript" ]; then
    token_source="$harness:transcript:$transcript"
  elif [ -n "$agent_pid" ]; then
    token_source="$harness:pid:$agent_pid"
  else
    token_source="$harness:cwd:$cwd"
  fi

  printf '%s/%s\n' "$ACTIVE_DIR" "$(token_hash "$token_source")"
}

move_marker_inactive() {
  local marker name
  marker="$1"

  [ -f "$marker" ] || return 0

  name="$(basename "$marker")"
  mv "$marker" "$INACTIVE_DIR/$name.$(timestamp).$$" 2>/dev/null || true
}

cleanup_stale_markers() {
  local marker agent_pid now mtime age
  now="$(timestamp)"

  for marker in "$ACTIVE_DIR"/*; do
    [ -f "$marker" ] || continue

    agent_pid="$(read_key agent_pid "$marker" || true)"
    if [ -n "$agent_pid" ]; then
      is_live_pid "$agent_pid" || move_marker_inactive "$marker"
      continue
    fi

    mtime="$(file_mtime "$marker")"
    age=$((now - mtime))
    if [ "$age" -gt "$STALE_AFTER_SECONDS" ]; then
      move_marker_inactive "$marker"
    fi
  done
}

active_marker_count() {
  local marker count
  count=0

  for marker in "$ACTIVE_DIR"/*; do
    [ -f "$marker" ] || continue
    count=$((count + 1))
  done

  echo "$count"
}

ensure_caffeinate() {
  local pid

  if [ -f "$PID_FILE" ]; then
    pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if is_caffeinate_pid "$pid"; then
      return 0
    fi

    mv "$PID_FILE" "$INACTIVE_DIR/caffeinate.pid.stale.$(timestamp).$$" 2>/dev/null || true
  fi

  # shellcheck disable=SC2086
  /usr/bin/caffeinate $FLAGS >/dev/null 2>&1 &
  printf '%s\n' "$!" > "$PID_FILE"
}

stop_caffeinate_if_idle() {
  local pid

  [ "$(active_marker_count)" -eq 0 ] || return 0
  [ -f "$PID_FILE" ] || return 0

  pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  if is_caffeinate_pid "$pid"; then
    kill "$pid" 2>/dev/null || true
  fi

  mv "$PID_FILE" "$INACTIVE_DIR/caffeinate.pid.stopped.$(timestamp).$$" 2>/dev/null || true
}

is_watcher_pid() {
  local command_line

  is_live_pid "${1:-}" || return 1
  command_line="$(ps -o command= -p "$1" 2>/dev/null)"

  case "$command_line" in
    *"caffeinate.sh --watch"*)
      return 0
      ;;
  esac

  return 1
}

ensure_watcher() {
  local pid

  if [ -f "$WATCHER_PID_FILE" ]; then
    pid="$(cat "$WATCHER_PID_FILE" 2>/dev/null || true)"
    if is_watcher_pid "$pid"; then
      return 0
    fi

    mv "$WATCHER_PID_FILE" "$INACTIVE_DIR/watcher.pid.stale.$(timestamp).$$" 2>/dev/null || true
  fi

  "$0" --watch >/dev/null 2>&1 &
  printf '%s\n' "$!" > "$WATCHER_PID_FILE"
}

watch() {
  ensure_dirs

  while true; do
    acquire_lock
    cleanup_stale_markers

    if [ "$(active_marker_count)" -gt 0 ]; then
      ensure_caffeinate
      release_lock
      sleep "$WATCH_INTERVAL_SECONDS"
      continue
    fi

    stop_caffeinate_if_idle
    release_lock
    exit 0
  done
}

handle_hook() {
  local input raw_event hook_event agent_pid harness marker cwd
  input="$(cat)"
  raw_event="$(json_get "$input" '.hook_event_name // .hookEvent // .hook_event // .event // .type')"
  hook_event="$(normalize_event "$raw_event")"

  [ -n "$hook_event" ] || exit 0

  ensure_dirs
  agent_pid="$(find_agent_pid || true)"
  harness="$(detect_harness "$agent_pid")"
  marker="$(marker_path_for_input "$input" "$agent_pid" "$harness")"
  cwd="$(json_get "$input" '.cwd // .workspace // .workspaceRoot')"

  acquire_lock

  case "$hook_event" in
    UserPromptSubmit)
      {
        printf 'event=%s\n' "$hook_event"
        printf 'created_at=%s\n' "$(timestamp)"
        printf 'agent_pid=%s\n' "$agent_pid"
        printf 'harness=%s\n' "$harness"
        printf 'cwd=%s\n' "$cwd"
      } > "$marker"

      cleanup_stale_markers
      ensure_caffeinate
      ensure_watcher
      ;;
    Stop)
      move_marker_inactive "$marker"
      cleanup_stale_markers
      stop_caffeinate_if_idle
      ;;
  esac
}

case "${1:-}" in
  --watch)
    watch
    ;;
  *)
    handle_hook
    ;;
esac

exit 0
