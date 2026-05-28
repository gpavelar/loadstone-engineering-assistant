# Architecture

A quick tour of how Loadstone fits together. Read this if you're going to extend it.

## The three things Loadstone does

1. **Chat with slash-command skills** (`/conversations`). Slash commands are
   Ruby classes that produce a system prompt, get routed through `AgentService`
   (Anthropic SDK, in-process), and return a streamed response.
2. **Persistent scratchpad for ideas** (`/ideas`). Markdown notes that
   accumulate findings over time.
3. **On-demand Claude Code investigations**. A scratchpad idea can dispatch a
   background job that shells out to `claude -p`, gives it filesystem + MCP
   tool access, and writes a structured report back.

## The Skills Registry — single source of truth

`Skills::Registry` (`app/services/skills/registry.rb`) is the one place that
knows what skills exist. Every other consumer derives from it:

```
┌──────────────────────────┐
│ Skills::Registry         │  ← edit ONLY here when adding a skill
│   SKILL_CLASSES = [...]  │
└────────────┬─────────────┘
             │
   ┌─────────┼─────────┬─────────────┬─────────────┬──────────────────┐
   ▼         ▼         ▼             ▼             ▼                  ▼
SkillRouter Conversation Skills::Help chat_ctrl    welcome tile      Skills::General
.route      labels +     .help_text   palette      grid              prompt
            title rule                (Stimulus    (in conv          (slash-cmd
                                       value)      index)            section)
```

Each skill class `extend Skills::Base` and provides class methods: `command`,
`skill_name`, `label`, `description`, `model`, `system_prompt`, optionally
`title_for(input)`. See `app/services/skills/compass.rb` for the canonical
example.

**Adding a skill = one new class file + one line in `SKILL_CLASSES`.** No other
files need updating — UI surfaces, routing, conversation titles, /help, and the
welcome grid all derive from the registry.

## Two agent execution paths

| Path | When | How |
|---|---|---|
| **In-process** (`AgentService`) | Every chat slash command | Anthropic SDK call, model routed by skill (`:sonnet` or `:haiku`). Tools defined in `AgentService#tool_definitions`. |
| **Subprocess** (`ClaudeCodeRunner`) | Idea investigations | Background job (`RunInvestigationJob`) shells out to `claude -p` with `CLAUDE_WORKDIR` pointing at your repos directory. Claude Code brings its own MCP tools, filesystem, skills. |

The subprocess path requires `claude` CLI on your PATH and an authenticated
Claude Code subscription (no API key needed). The in-process path always
needs `ANTHROPIC_API_KEY`.

## Distil into note body

Investigations are reports. To turn a report into accumulated knowledge in the
idea's note, click **Distil into note**:

1. `Skills::DistilInvestigation` (a service, not a slash-command skill) sends
   only the investigation report (not the existing note body) to Haiku with a
   system prompt that asks for a structured Findings section.
2. The section is appended to `idea.body` via `Idea#append_to_body!`.
3. A `[Full investigation →]` link is appended in Ruby (deterministic — not
   trusted to the LLM).

The note body never gets sent into distillation prompts, so context stays small
no matter how many findings accumulate.

## Investigation modes

`Skills::InvestigationModes` defines four templates: Research / Plan / Compare /
Spec. Picking a mode pre-fills the steering text AND appends a system-prompt
suffix that asks the agent to structure the report a specific way (e.g. Spec
mode → Problem / Goals / Non-goals / Approaches / Decision / Open Questions —
RFC-ready).

Mode is persisted on the investigation row and displayed as a small purple tag
on the summary.

## Data model

```
users 1───* conversations 1───* messages
  │
  └───* ideas 1───* investigations
                       │
                       └───? conversation (the generated report lives here)
```

- `Idea` has a markdown `body`, soft-archive via `archived_at`.
- `Investigation` has a status machine (`queued` → `running` → `done`|`failed`),
  optional `mode`, optional `prompt` (steering), `distilled_at` timestamp,
  optional FK to `Conversation` (containing the report).
- The split between `Investigation` (metadata + lifecycle) and `Conversation`
  (the actual report content) is intentional — it lets "Continue as chat" on a
  completed investigation be trivial: just navigate to the linked conversation
  and the existing chat streaming flow takes over.

## UI / frontend

Hotwire (Turbo + Stimulus). The investigation row uses Turbo Streams in two
modes:

1. **Push** — `RunInvestigationJob` broadcasts to `idea_<id>` on status change.
   Catches connected clients in real time.
2. **Poll** — A Stimulus controller attached to `queued`/`running` rows polls
   the show endpoint every 5s. The polled response is a Turbo Stream that
   re-renders the summary row. Catches clients that disconnected during long
   runs. Polling pauses when the tab is backgrounded; stops automatically when
   the row reaches a terminal status (because the new partial drops the
   `data-controller` attribute).

## Background jobs

Solid Queue (Rails 7.2 default). Runs in-process via `bin/jobs` alongside the
web server. No Redis. Single Solid Queue worker is plenty for personal use.

## Tools available to chat skills

Defined in `AgentService#tool_definitions`. Each maps to a class in
`app/services/tools/`:

- `jira_search`, `jira_issue`, `jira_board_issues` — Jira REST API
- `github_prs` — GitHub PRs for a user
- `slack_channel`, `slack_thread` — Slack
- `confluence_search`, `confluence_page` — Confluence v1 + v2
- `buildkite_builds` — CI status
- `lookup_persona`, `search_expertise`, `get_team_config` — local YAML
- `get_okrs` — local YAML

All HTTP tools use env-var credentials. Local YAML tools fall back to
`config/loadstone/*.example.yml` when the real `.yml` isn't present
(via `LoadstoneConfig.load`).
