# Hooks API Quick Reference

## Event List (22 Events)

### Full Handler Support (command, http, prompt, agent)
`PermissionRequest` | `PostToolUse` | `PostToolUseFailure` | `PreToolUse` | `Stop` | `SubagentStop` | `TaskCompleted` | `UserPromptSubmit`

### Command-Only Events
`ConfigChange` | `Elicitation` | `ElicitationResult` | `InstructionsLoaded` | `Notification` | `PostCompact` | `PreCompact` | `SessionEnd` | `SessionStart` | `SubagentStart` | `TeammateIdle` | `WorktreeCreate` | `WorktreeRemove`

## Lifecycle
`SessionStart -> UserPromptSubmit -> PreToolUse -> PermissionRequest -> [Tool] -> PostToolUse -> Stop -> SessionEnd`

## stdin: Common Fields
`session_id`, `transcript_path`, `cwd`, `permission_mode`, `hook_event_name`

### Per-Event Extra Fields

| Event | Extra stdin Fields |
|-------|-------------------|
| PreToolUse | `tool_name`, `tool_input`, `tool_use_id` |
| PostToolUse | `tool_name`, `tool_input`, `tool_response`, `tool_use_id` |
| PostToolUseFailure | `tool_name`, `tool_input` + error fields |
| SubagentStart | `agent_id`, `agent_type` |
| PreCompact | `trigger` ("manual"/"auto"), `custom_instructions` |
| Stop / SubagentStop | `stop_hook_active` (Boolean) |

### Environment Variables
- `CLAUDE_PROJECT_DIR` -- project root path
- `CLAUDE_CODE_REMOTE` -- "true" in web environments
- `CLAUDE_ENV_FILE` -- SessionStart only: path for persistent env vars

## Exit Codes

| Code | Meaning | stdout Behavior |
|------|---------|----------------|
| 0 | Success | stdout -> User transcript. **Exception:** SessionStart + UserPromptSubmit: stdout -> Claude context |
| 2 | Blocking error | stderr -> delivered to Claude as error message |
| other | Non-blocking | stderr -> User in verbose mode, execution continues |

## JSON Output (exit 0)

**Context Injection** (SessionStart/UserPromptSubmit): `{ "hookSpecificOutput": { "additionalContext": "..." } }` -- plain-text stdout also works.

**PreToolUse**: `permissionDecision`: "allow"|"deny"|"ask", `updatedInput`: modify tool input (invisible to Claude), `additionalContext`: inject context.

**Stop**: `{ "decision": "block", "reason": "..." }` -- CRITICAL: check `stop_hook_active` first, exit 0 if true (loop prevention).

## Timeouts

| Type | Default |
|------|---------|
| Command hook | 600s (since v2.1.3) |
| Prompt hook | 30s |
| Agent hook | 60s |
| Custom | `"timeout": <seconds>` per hook |

## Handler Types

| Type | Use Case |
|------|----------|
| command | Deterministic checks -- 90% of use cases |
| http | External services; blocking only via 2xx + JSON |
| prompt | Judgment needed, no file access |
| agent | Verification needing codebase access (expensive: own API calls) |

## Matcher Syntax
```
"Bash"              exact (case-sensitive)
"Write|Edit"        OR
"*" or ""           match all
"Bash(npm test*)"   argument pattern
"mcp__memory__.*"   MCP regex
```

## Blocking Behavior
**Blocking:** PreToolUse, PermissionRequest, UserPromptSubmit, Stop, SubagentStop, TaskCompleted, SessionStart
**Async:** Notification. Any hook: `"async": true` makes it non-blocking.
Multiple hooks per event run in parallel. Identical commands deduplicated.

## Agent Frontmatter Hooks
Agents can register hooks in YAML frontmatter under `hooks:` key with `matcher:` + `type: command`.
Note: Stop hooks in agent frontmatter auto-convert to SubagentStop. Skills cannot register hooks.
