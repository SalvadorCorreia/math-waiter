---
description: Choose whether Math Waiter starts on or off in new conversations
argument-hint: on | off
allowed-tools: Bash(sh:*)
---

!`sh "${CLAUDE_PLUGIN_ROOT}/scripts/run.sh" status`

Math Waiter's hook has applied the setting, if one was given. The user typed: "$ARGUMENTS". If that is not `on` or `off`, tell them to run `/math-waiter:default on` or `/math-waiter:default off`. Otherwise tell them in one short sentence what the line above says. Conversations they switched with `/math-waiter:on` or `/math-waiter:off` keep their choice. Do nothing else.
