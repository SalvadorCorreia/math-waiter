# Math Waiter: agent guide

The agent integration for Math Waiter, a math game at https://mathwaiter.tech that opens while an AI coding agent works, steps aside when the agent needs input, and closes when it finishes. Shipped as a Claude Code plugin; this repo is public and open source.

## Map

| Path | What | Guide |
|---|---|---|
| `.claude-plugin/plugin.json` | Plugin manifest (`name: math-waiter`, `version`) | this file |
| `.claude-plugin/marketplace.json` | Lets users install from this repo (`/plugin marketplace add SalvadorCorreia/math-waiter`) | this file |
| `hooks/hooks.json` | `UserPromptSubmit` → start, `Notification` (`permission_prompt\|idle_prompt`) → pause, `Stop` and `StopFailure` → stop, `SessionEnd` → end; each runs `scripts/run.sh <action>` | this file |
| `commands/` | `/math-waiter:login` and `:profile` run `scripts/run.sh account|profile` (game window on the site's account or profile page). `:on`, `:off`, `:default on\|off` and `:status` only print `run.sh status`: the UserPromptSubmit hook applies each switch before the command runs | [scripts/AGENTS.md](scripts/AGENTS.md) |
| `scripts/` | OS dispatcher, per-OS start/pause/stop scripts, shared Firefox profile settings | [scripts/AGENTS.md](scripts/AGENTS.md) |
| `README.md` | User-facing install and platform notes | keep in sync with behavior changes |

## Rules

- **Public repo.** Only the agent integration lives here. The game itself is the website, built in a separate private repository with the server, paid features and business material; never add those here.
- **The hooks send nothing.** They open `https://mathwaiter.tech/play` in a browser window and move focus. Prompts, conversation and project files never leave the machine; keep it that way and keep the README's disclosure accurate.
- **Branding.** Never put "Claude" or "Anthropic" in product, plugin, marketplace or repo names (`claude plugin validate` rejects `claude-*` names, and it is a trademark risk). "for Claude Code" in descriptions is fine.
- **Commits.** Never add `Co-Authored-By`, "Generated with Claude Code" or any AI attribution to commits or PRs. Conventional Commits style (`feat:`, `fix:`, `chore:`, `refactor:`).
- **Hooks must be silent and fast.** `UserPromptSubmit` stdout is injected into the agent's context, so scripts print nothing; the game launches detached so the hook returns immediately (hook timeout is 15 s).
- **Average laptop, not one machine.** Changes must degrade gracefully on Windows, macOS and any Linux desktop; feature-detect tools instead of assuming them.
- **Branches.** Work on `dev`. Never push to `main` until the change is ready for users: a push triggers a webhook and the plugin directory scans that commit as a new version.
- **Releases.** Merge `dev` into `main` with a higher `version` in `.claude-plugin/plugin.json`. Marketplace users only receive an update when `version` changes.

## Check your work

```bash
claude plugin validate .                         # manifest, marketplace, hooks
sh scripts/run.sh start; sh scripts/run.sh pause; sh scripts/run.sh stop   # by hand
claude -p --plugin-dir . "say hi"                # real session: game opens, then closes
```

Only Linux can be tested on the maintainer's machine; say so when macOS or Windows changes are untested.
