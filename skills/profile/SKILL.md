---
name: profile
description: Open the Math Waiter window on your profile, to change your name, avatar, sound or difficulty
disable-model-invocation: true
allowed-tools: Bash(sh:*)
---

!`sh "${CLAUDE_PLUGIN_ROOT}/scripts/run.sh" profile`

The Math Waiter game window is now open on the profile page (in Antigravity, the plugin's hook opened it). Tell the user, in one short sentence, that they can change their name, avatar, colour, sound and difficulty there, and that the window stays open until their next prompt finishes. Run no tools and do nothing else.
