# Loadstone — Engineering Assistant

A personal AI assistant for software engineers, built on Rails + Claude.
Chat with slash-command skills over Jira, GitHub, Slack, Confluence, and your
own codebase via Claude Code.

> Built as a personal productivity tool. Sharing the architecture here in case
> it's useful to others.

---

## What it does

**Daily rituals as slash commands.** Stop hand-rolling your morning triage
or weekly journal — let the assistant do the boring data-fetching:

- `/compass` — today's priorities ranked by OKR alignment with time-in-status
- `/journal` — weekly work journal from Jira + GitHub + OKRs
- `/blockers` — find and route blockers across the team board
- `/stakeholders [ticket]` — map stakeholders for a Jira ticket
- `/board-hygiene` — find duplicates, orphans, and broken hierarchy
- `/retro` — generate retrospective insights from the week's work
- `/prep [name]` — prepare context for a 1:1 meeting
- `/onboard [system]` — onboarding guide for new team members
- `/handover` — generate a leave handover doc
- `/deadcode [focus]` — find dead code, stale flags, cleanup targets
- `/duplicates` — find duplicate tickets across the board
- `/checkin` — daily team check-in post (your work only)
- `/planning-gap [team]` — compare a team's planning page to their Jira board

**Persistent scratchpad for ideas.** Capture an idea, expand it as a markdown
note, optionally trigger a deep investigation:

- Investigations dispatch to your local `claude` CLI (no API key needed if you
  have a Claude Code subscription) and can read your actual repos.
- Reports get appended to the idea's note body via "Distil into note", building
  a research log you can eventually lift into a Technical RFC.
- Investigation modes: Research / Plan / Compare / Spec shape the report.

---

## Architecture (one paragraph)

Rails 7.2 + PostgreSQL + Hotwire (Turbo + Stimulus). Skills are Ruby classes
in `app/services/skills/` that register themselves via `Skills::Registry` —
a single source of truth that drives the chat palette, sidebar labels, `/help`
output, and routing. Slash commands hit `AgentService` (Anthropic SDK,
in-process). Investigations dispatch to a background job (Solid Queue) that
shells out to `claude -p` for filesystem + MCP-tool-rich exploration. See
`ARCHITECTURE.md` for the full tour.

---

## Setup

You'll need: Ruby 3.4.x, PostgreSQL 14+, Node (for Tailwind), and either
an Anthropic API key OR a Claude Code subscription (for investigations).

```bash
# 1. Bundle + DB
bundle install
bin/rails db:prepare

# 2. Configure your tools
cp .env.example .env
# Edit .env — set ANTHROPIC_API_KEY, Jira/GitHub/etc. credentials.

# 3. Configure your team context (templates ship as *.example.yml)
cp config/loadstone/teams.example.yml         config/loadstone/teams.yml
cp config/loadstone/personas.example.yml      config/loadstone/personas.yml
cp config/loadstone/okrs.example.yml          config/loadstone/okrs.yml
cp config/loadstone/team_config.example.yml   config/loadstone/team_config.yml
cp config/loadstone/company_context.example.yml config/loadstone/company_context.yml
# Edit each file with your real team, OKRs, personas.

# 4. Start
script/dev.sh
```

Open `http://localhost:3000`.

---

## Adding your own skill

The registry pattern makes it cheap. New skill = one class file + one entry:

1. Create `app/services/skills/my_skill.rb`:

```ruby
module Skills
  class MySkill
    extend Skills::Base

    def self.command       = "/my-skill"
    def self.skill_name    = :my_skill
    def self.label         = "My Skill"
    def self.description   = "What it does in one line"
    def self.model         = :sonnet  # or :haiku

    def self.system_prompt
      <<~PROMPT
        You are Loadstone's <role>...

        ## Steps
        1. ...

        ## Output Format
        ...
      PROMPT
    end
  end
end
```

2. Add `Skills::MySkill` to `Skills::Registry::SKILL_CLASSES` in
   `app/services/skills/registry.rb`.

3. Add a router test in `test/services/skill_router_test.rb`.

That's it. Chat palette, `/help` output, sidebar label, conversation title rule
all derive from the registry — no other files need editing.

---

## License

Apache 2.0. See `LICENSE`.

---

## Acknowledgements

Built with [Claude](https://anthropic.com/claude), [Rails](https://rubyonrails.org/),
[Hotwire](https://hotwired.dev/), and [Tailwind CSS](https://tailwindcss.com/).
