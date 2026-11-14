---
name: login
description: Open the Math Waiter window on its sign-in screen, to sign in, create an account or change your profile
disable-model-invocation: true
allowed-tools: Bash(sh:*)
---

!`sh "${CLAUDE_PLUGIN_ROOT}/scripts/run.sh" account`

The Math Waiter game window is now open on its account screen (in Antigravity, the plugin's hook opened it). Tell the user, in one short sentence, that they can sign in with Google or email there, or create an account, and that the window stays open until their next prompt finishes. Run no tools and do nothing else.
