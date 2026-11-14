---
name: on
description: Turn Math Waiter on for this conversation
disable-model-invocation: true
allowed-tools: Bash(sh:*)
---

Math Waiter status: !`sh "${CLAUDE_PLUGIN_ROOT}/scripts/run.sh" status`

Math Waiter's hook has already applied the switch. Tell the user in one short sentence what the Math Waiter status says, and that the game opens with their next prompt. In Antigravity the line above stays unrun: there, the hook sends the status as a separate "Math Waiter status" message. If neither has the status, tell the user that Math Waiter's hook did not run, so nothing changed. Run no tools and do nothing else.
