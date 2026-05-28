# Porting Features Between Private and Public Repos

This repo is the public, sanitized version of Loadstone. The original
development happens in a private working copy with real org-specific config.
This doc is the checklist for porting features between the two.

## When you add a feature in the private repo

1. **Get it working end-to-end** with your real configs.
2. **Decide if it belongs in public.** Some features are personal/org-specific
   and should stay private.
3. **For features that belong in public:**

   a. Copy the new/modified code files (most files are identical — no
      sanitization needed).

   b. For each file, run the sanitization checklist below.

   c. Run `grep -rln "<your-org-name>\|<your-team-uuids>\|<real-emails>"`
      in the public repo. Should return zero matches.

   d. Run `script/test.sh` (or equivalent). Tests should pass.

   e. Commit with a clean message that doesn't reference any internal
      tickets/projects/people.

## Sanitization checklist (per file you copy over)

### Code files (`*.rb`, `*.erb`, `*.js`)

- [ ] Search for your company name. Replace with generic
      placeholder or remove.
- [ ] Search for product names (e.g. specific repos, services, tools).
      Replace with placeholder (e.g. "your-monolith", "your-frontend").
- [ ] Search for team names. Generally OK to leave "Search Platform" as the
      example team name, but anything more specific should be generalized.
- [ ] Search for hardcoded URLs (e.g. `your-org.atlassian.net`). Should be
      env vars or use the JIRA_HOST pattern.
- [ ] Search for ticket key prefixes (e.g. "PROJ-1234"). Comments and examples
      should use generic placeholders like "PROJ-1234".

### Skill prompts (`app/services/skills/*.rb`)

- [ ] Strip org-specific team references from `system_prompt` text.
- [ ] Use "your team" / "the team" instead of a specific team name.
- [ ] Don't hardcode OKR themes from your real OKRs — let `okrs.yml` drive that.

### Config files

- [ ] Real config (`config/loadstone/*.yml`) is gitignored. Don't commit it.
- [ ] When the feature needs a new config key, add it to the `.example.yml`
      template with placeholder values.

### Test fixtures (`test/fixtures/*.yml`)

- [ ] No real names, emails, ticket keys, or product references.
- [ ] Use placeholder personas (Alice, Bob, etc.).
- [ ] Use generic ticket keys like "PROJ-1234".

### Docs (`docs/`)

- [ ] **Don't port `docs/superpowers/specs/` or `docs/superpowers/plans/`**
      from private to public. These contain real investigation reports with
      proprietary info. Public repo gets its own minimal docs (README,
      ARCHITECTURE, PORTING).

## When porting goes wrong

If you accidentally commit org-specific content to the public repo:

1. **Don't push yet.** Or if pushed, you'll need a more aggressive fix.
2. Before push: `git reset --soft HEAD~N` to back out the problematic commits.
   Re-stage and re-commit after sanitizing.
3. After push: `git filter-repo --replace-text` or BFG can scrub specific
   strings from history. Force-push (this is one of the few cases where
   force-push to a personal repo is justified).
4. Rotate any credentials that may have leaked.

## Tools that help

- `grep -rli "<sensitive-string>"` is your friend before any commit.
- A `pre-commit` hook that runs grep against a denylist is worth considering
  once the porting pattern is stable.
