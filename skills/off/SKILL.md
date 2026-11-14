---
name: off
description: Turn Math Waiter off for this conversation, and close the game if it is open
disable-model-invocation: true
allowed-tools: Bash(sh:*)
---

Math Waiter status: !`sh "${CLAUDE_PLUGIN_ROOT}/scripts/run.sh" status`

Math Waiter's hook has already applied the switch. Tell the user in one short sentence what the Math Waiter status says, and that `/math-waiter:on` turns it back on. In Antigravity the line above stays unrun: there, the hook sends the status as a separate "Math Waiter status" message. If neither has the status, tell the user that Math Waiter's hook did not run, so nothing changed. Run no tools and do nothing else.
