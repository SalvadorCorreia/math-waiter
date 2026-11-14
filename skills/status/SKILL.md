---
name: status
description: Show whether Math Waiter is on in this conversation and in new ones
disable-model-invocation: true
allowed-tools: Bash(sh:*)
---

Math Waiter status: !`sh "${CLAUDE_PLUGIN_ROOT}/scripts/run.sh" status`

Tell the user in one short sentence what the Math Waiter status says. Mention `/math-waiter:on`, `/math-waiter:off` and `/math-waiter:default on|off` only if they would change something. In Antigravity the line above stays unrun: there, the hook sends the status as a separate "Math Waiter status" message. If neither has the status, tell the user that Math Waiter's hook did not run, so nothing changed. Run no tools and do nothing else.
