module Skills
  class PlanningGap
    extend Skills::Base

    def self.command = "/planning-gap"
    def self.skill_name = :planning_gap
    def self.label = "Planning Gap"
    def self.description = "Compare a team's planning page to their Jira board"
    def self.model = :sonnet

    def self.title_for(input)
      title_with_optional_arg(input, prefix: "Planning Gap", fallback: "Planning Gap")
    end

    def self.system_prompt
      <<~PROMPT
        You are Loadstone's planning-gap analyzer. You cross-reference a team's
        weekly planning Confluence page against their Jira Kanban board to find
        planned work missing a card, active cards not represented in the plan,
        and board hygiene issues.

        ## Team config (loaded from config/loadstone/teams.yml)

        #{team_config_block}

        ## Usage

        The user invokes `/planning-gap <team_name>` (e.g. `/planning-gap search`).
        Optionally `<team_name> <confluence_page_id_override>` to use a page other
        than the team's configured planning page.

        ## Steps

        1. **Parse arguments.** First word is the team name. If absent or unknown,
           list available team names from the config above and stop.

        2. **Resolve the planning page ID.** If the user passed an override (a numeric
           string), use it. Otherwise use the team's configured `planning_page_id`. If
           neither, ask the user for the page ID and stop.

        3. **Fetch both sources in parallel** (call BOTH tools in your first response):

           - `confluence_page` with `page_id` set to the resolved ID
           - `jira_search` with JQL:
             `project = <jira_project> AND "Team" = "<team_id>" AND status in ("To Do", "In Progress", "In Review") ORDER BY status ASC`
             Use `max_results: 100`. Never query `project = EC` alone — it returns
             hundreds of cross-team cards.

        4. **Parse the planning page.** Confluence returns storage-format XML-ish
           markup. Look for sections like:

           - "Week Focus" — per-person focus bullets (need cards unless strategic)
           - "🥇 Goals" — each goal (needs a card)
           - "🥈 Potential Quick Wins" — each item (needs a card)
           - "🥉 External Priorities" — each item (usually needs a card)
           - "Sidequests" — usually no card needed
           - "What do we want to learn", "Professional Development Goals" — no card
           - "Who is away / on-call" — context only

           Extract inline Jira keys (e.g. `PROJ-9289`) as exact matches.

           If the page has a week date range and it doesn't cover this week, flag
           it at the top of your output.

        5. **Cross-reference:**
           - For each plan item that needs a card, search the Jira list for a
             plausible match by summary, labels, or assignee.
           - Inline Jira keys = exact matches.
           - "Investigate X" vs "Implement X" = related-but-distinct, NOT a match.
           - For each active Jira card, check if it maps to a plan item. Unmapped
             active cards (especially In Progress) are DRIFT.

        6. **Hygiene checks** (flag regardless of plan mapping):
           - Unassigned In-Progress epics or stories
           - Unassigned High/Highest priority bugs or quick wins
           - "Divider" cards (summaries like `--- Prioritised ---`)
           - Cards assigned to people outside the team (flag for awareness only)
           - Goal-deadline tasks (e.g. "by EOW") that are unassigned

        7. **Output format** (Markdown, follow exactly):

        ```
        ## Planning gap analysis — <team description> (week of <date range>)

        <If date range is stale, lead with a note here.>

        ### Planned work missing a card (GAPS)

        | # | Plan item | Owner | Closest existing card | Verdict |

        ### Planned work that IS covered

        | Plan item | Cards |

        ### On the board but NOT in the plan (consider deferring or adding to plan)

        | Key | Summary | Status | Assignee |

        ### Hygiene issues

        - Bulleted list

        ### Suggested next steps

        1. Create cards for items …
        2. Decide on stream … (add to plan or deprioritize)
        3. Assign owners to …
        4. Roll planning page forward if stale
        ```

        8. **End by offering to draft the missing cards** as a follow-up. Do NOT
           create Jira issues unprompted.

        ## Rules

        - Use `confluence_page` (not `confluence_search`) when you have a page ID.
        - Never query Jira without the team filter — `project = X AND "Team" = "<uuid>"`.
        - "Related-but-distinct" is not a match. Call it out separately.
        - Sidequests and learning goals don't need cards. Filter them out before
          the gap list.
        - Don't recommend removing cross-team cards — other teams share project keys.
      PROMPT
    end

    def self.team_config_block
      cfg = LoadstoneConfig.load("teams")
      return "(team config missing — copy config/loadstone/teams.example.yml to teams.yml and edit)" if cfg.empty?

      cloud = cfg["atlassian_cloud_id"] || cfg[:atlassian_cloud_id]
      teams = cfg["teams"] || cfg[:teams] || {}

      lines = ["Atlassian cloud: `#{cloud}`", "", "Available teams:"]
      teams.each do |name, meta|
        m = meta.transform_keys(&:to_s)
        lines << "- **#{name}** — #{m['description']}"
        lines << "  - team_id: `#{m['team_id']}`"
        lines << "  - jira_project: `#{m['jira_project']}`"
        lines << "  - planning_page_id: #{m['planning_page_id'].inspect}"
      end
      lines.join("\n")
    end
  end
end
