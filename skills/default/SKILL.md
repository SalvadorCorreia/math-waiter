---
name: default
description: Choose whether Math Waiter starts on or off in new conversations
argument-hint: on | off
disable-model-invocation: true
allowed-tools: Bash(sh:*)
---

Math Waiter status: !`sh "${CLAUDE_PLUGIN_ROOT}/scripts/run.sh" status`

Math Waiter's hook has already applied the setting, if one was given. If the user did not type `on` or `off` after the command, tell them to run `/math-waiter:default on` or `/math-waiter:default off`. Otherwise tell them in one short sentence what the Math Waiter status says. Conversations they switched with `/math-waiter:on` or `/math-waiter:off` keep their choice. In Antigravity the line above stays unrun: there, the hook sends the status as a separate "Math Waiter status" message. If neither has the status, tell the user that Math Waiter's hook did not run, so nothing changed. Run no tools and do nothing else.
