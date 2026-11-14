# Math Waiter: agent guide

The agent integration for Math Waiter, a math game at https://mathwaiter.tech that opens while an AI coding agent works, steps aside when the agent needs input, and closes when it finishes. Shipped as a Claude Code plugin and an Antigravity plugin (the `agy` CLI and the Antigravity app) from the same folder; this repo is public and open source.

## Map

| Path | What | Guide |
|---|---|---|
| `.claude-plugin/plugin.json` | Plugin manifest (`name: math-waiter`, `version`) | this file |
| `.antigravity-plugin/plugin.json` | Antigravity manifest; keep `version` and `description` in step with the Claude one. Its presence makes `agy plugin install` load the folder natively instead of converting the Claude plugin | this file |
| `.claude-plugin/marketplace.json` | Lets users install from this repo (`/plugin marketplace add SalvadorCorreia/math-waiter`) | this file |
| `hooks/hooks.json` | `UserPromptSubmit` → start, `Notification` (`permission_prompt\|idle_prompt`) → pause, `Stop` and `StopFailure` → stop, `SessionEnd` → end; each runs `scripts/run.sh <action>` | this file |
| `hooks.json` | Antigravity's hooks (it reads only this root file): `PreInvocation` → start, `PreToolUse` (`^ask_question$`) → pause, `Stop` → stop; each runs `scripts/antigravity.sh <action>`, or `scripts/windows/antigravity.ps1` where `cmd.exe` has no `sh` | [scripts/AGENTS.md](scripts/AGENTS.md) |
| `skills/` | Skills, shared by both agents (Antigravity loads no `commands/`). `/math-waiter:login` and `:profile` run `scripts/run.sh account|profile` (game window on the site's account or profile page). `:on`, `:off`, `:default on\|off` and `:status` only print `run.sh status`: the prompt hook applies each switch before the skill runs. Claude Code runs the skills' `` !`…` `` lines; Antigravity shows them unrun, so its hook does that work and sends the status as a message | [scripts/AGENTS.md](scripts/AGENTS.md) |
| `scripts/` | OS dispatcher, per-OS start/pause/stop scripts, shared Firefox profile settings | [scripts/AGENTS.md](scripts/AGENTS.md) |
| `README.md` | User-facing install and platform notes | keep in sync with behavior changes |

## Rules

- **Public repo.** Only the agent integration lives here. The game itself is the website, built in a separate private repository with the server, paid features and business material; never add those here.
- **The hooks send nothing.** They open `https://mathwaiter.tech/play` in a browser window and move focus. Prompts, conversation and project files never leave the machine; keep it that way and keep the README's disclosure accurate.
- **Branding.** Never put "Claude" or "Anthropic" in product, plugin, marketplace or repo names (`claude plugin validate` rejects `claude-*` names, and it is a trademark risk). "for Claude Code" in descriptions is fine.
- **Commits.** Never add `Co-Authored-By`, "Generated with Claude Code" or any AI attribution to commits or PRs. Conventional Commits style (`feat:`, `fix:`, `chore:`, `refactor:`).
- **Hooks must be silent and fast.** `UserPromptSubmit` stdout is injected into the agent's context, so scripts print nothing; the game launches detached so the hook returns immediately (hook timeout is 15 s). Antigravity reads a hook's stdout as its JSON reply, and a `PreToolUse` hook that prints no decision denies the tool, so `antigravity.sh` prints only replies.
- **Average laptop, not one machine.** Changes must degrade gracefully on Windows, macOS and any Linux desktop; feature-detect tools instead of assuming them.
- **Branches.** Work on `dev`. Never push to `main` until the change is ready for users: a push triggers a webhook and the plugin directory scans that commit as a new version.
- **Releases.** Merge `dev` into `main` with a higher `version` in `.claude-plugin/plugin.json` and `.antigravity-plugin/plugin.json`. Marketplace users only receive an update when `version` changes; Antigravity users update by running `agy plugin install` again.

## Check your work

```bash
claude plugin validate .                         # manifest, marketplace, hooks
sh scripts/run.sh start; sh scripts/run.sh pause; sh scripts/run.sh stop   # by hand
claude -p --plugin-dir . "say hi"                # real session: game opens, then closes
agy plugin validate .                            # Antigravity manifest, hooks.json, skills
agy plugin install "$PWD" && agy -p "say hi"     # real agy session (install copies the folder: reinstall after edits)
```

Only Linux can be tested on the maintainer's machine; say so when macOS or Windows changes are untested.
