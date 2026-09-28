# Turns Claude Code stream-json lines (read with jq -R) into readable log events.
# Used live by worker.sh (pod logs) and by claude-log (replaying a run's transcript).
#
# Args: $format  json | text | pretty
#       $worker  pod name
#       $ref     owner/repo#number being worked on
#       $root    worktree path, stripped from file paths to keep lines short

def oneline: gsub("\\s*\n\\s*"; " ⏎ ");
def trunc($n): if length > $n then .[0:$n] + "…" else . end;
def rel: if $root != "" then sub("^" + $root + "/?"; "") else . end;

def tool_detail:
  .name as $name | (.input // {}) as $in |
  if $name == "Bash" then ($in.command // "" | oneline | trunc(240))
  elif ($name | test("^(Read|Write|Edit|MultiEdit|NotebookEdit)$")) then ($in.file_path // $in.notebook_path // "" | rel)
  elif ($name | test("^(Grep|Glob)$")) then "\($in.pattern // "")" + (if $in.path then " in \($in.path | rel)" else "" end)
  elif $name == "WebFetch" then ($in.url // "")
  elif $name == "WebSearch" then ($in.query // "")
  elif ($name | test("^(Task|Agent)$")) then ($in.description // $in.prompt // "" | oneline | trunc(160))
  elif $name == "TodoWrite" then
    ($in.todos // []) as $t |
    "\([$t[] | select(.status == "completed")] | length)/\($t | length) done"
    + ([$t[] | select(.status == "in_progress") | .activeForm // .content][0] | if . then ", now: \(.)" else "" end)
  else ($in | tostring | trunc(160))
  end;

def result_text:
  if type == "array" then map(.text? // "") | join(" ") else tostring end | oneline | trunc(300);

# Stream-json line -> {event, tool?, msg}
def to_events:
  fromjson? |
  if .type == "system" and .subtype == "init" then
    {event: "session", msg: "session \(.session_id) started (model \(.model // "?"))"}
  elif .type == "assistant" then
    .message.content[]? |
    if .type == "text" and ((.text // "") | test("\\S")) then {event: "message", msg: (.text | oneline | trunc(600))}
    elif .type == "tool_use" then {event: "tool", tool: .name, msg: tool_detail}
    else empty end
  elif .type == "user" then
    .message.content[]? | select(type == "object" and .type == "tool_result" and .is_error == true)
    | {event: "tool_error", msg: (.content | result_text)}
  elif .type == "result" then
    {event: "result", msg: "\(.subtype // "?") after \(.num_turns // "?") turns in \((.duration_ms // 0) / 1000 | floor)s"}
  else empty end;

def icon:
  {session: "▶", message: "💬", tool: "🔧", tool_error: "❌", result: "🏁"}[.event] // "•";

to_events |
if $format == "json" then
  {ts: (now | todate), level: (if .event == "tool_error" then "warn" else "info" end),
   worker: $worker, ref: $ref, repo: ($ref | split("#")[0]), issue: ($ref | split("#")[1] // ""), source: "claude"} + .
elif $format == "text" then
  "\(now | todate) \($worker) \($ref) \(icon) \(if .tool then .tool + " " else "" end)\(.msg)"
else
  "\(icon) \(if .tool then .tool + " " else "" end)\(.msg)"
end
