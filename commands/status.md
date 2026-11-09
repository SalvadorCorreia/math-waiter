---
description: Show whether Math Waiter is on in this conversation and in new ones
allowed-tools: Bash(sh:*)
---

!`sh "${CLAUDE_PLUGIN_ROOT}/scripts/run.sh" status`

Tell the user in one short sentence what the line above says. Mention `/math-waiter:on`, `/math-waiter:off` and `/math-waiter:default on|off` only if they would change something. Do nothing else.
