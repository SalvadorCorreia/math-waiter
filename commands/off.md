---
description: Turn Math Waiter off for this conversation, and close the game if it is open
allowed-tools: Bash(sh:*)
---

!`sh "${CLAUDE_PLUGIN_ROOT}/scripts/run.sh" status`

Math Waiter's hook has applied the switch. Tell the user in one short sentence what the line above says, and that `/math-waiter:on` turns it back on. Do nothing else.
