#!/bin/sh
# Hook entry point for Antigravity (the agy CLI and the Antigravity app), wired up in ../hooks.json.
# Antigravity has no UserPromptSubmit, Notification or SessionEnd events, so this maps the events it
# has onto run.sh's actions, which were written for Claude Code:
#   start  PreInvocation: the first model call of a turn starts the game; later ones refresh the mark
#   pause  PreToolUse on ask_question: the agent asks the player something
#   stop   Stop: the turn is over
# Usage: antigravity.sh start|pause|stop, with Antigravity's hook JSON on stdin.
# Antigravity reads stdout as the hook's JSON reply, so only replies are printed.

DIR="$(cd "$(dirname "$0")" && pwd)"
INPUT=$(cat)

# run.sh reads Claude Code's field names: session_id, and prompt for the switch commands.
# The field names are matched with their quotes, which the escaped quotes inside a prompt never have.
run() {
    printf '%s' "$INPUT" \
        | sed -e 's/"conversationId"/"session_id"/' -e 's/"lastUserInput"/"prompt"/' \
        | MATH_WAITER_AGENT=antigravity sh "$DIR/run.sh" "$1" > /dev/null 2>&1
}

# Adds a line for the agent before its model call. The texts are ours, but stay valid JSON anyway.
tell_agent() {
    printf '{"injectSteps":[{"ephemeralMessage":"%s"}]}\n' "$(printf '%s' "$1" | tr -d '"\\\n')"
}

case "$1" in
    start)
        # invocationNum counts the model calls of a turn from 0; protojson may omit a 0.
        if printf '%s' "$INPUT" | grep -q -E '"invocationNum" *: *[1-9]'; then
            run refresh
            exit 0
        fi
        run start
        # The plugin's skills (../antigravity/skills) cannot run commands the way Claude Code's
        # commands do, so their work happens here and the agent is told the result.
        COMMAND=$(printf '%s' "$INPUT" | grep -o -E '"lastUserInput" *: *"/math-waiter:[a-z]+' | sed 's/.*://' | head -n 1)
        case "$COMMAND" in
            on | off | default | status)
                tell_agent "Math Waiter status: $(sh "$DIR/run.sh" status < /dev/null)" ;;
            login)
                sh "$DIR/run.sh" account < /dev/null > /dev/null 2>&1
                tell_agent "Math Waiter status: the game window is now open on its account screen." ;;
            profile)
                sh "$DIR/run.sh" profile < /dev/null > /dev/null 2>&1
                tell_agent "Math Waiter status: the game window is now open on the profile page." ;;
        esac
        ;;
    pause)
        # A PreToolUse hook must decide: no reply denies the tool. The matcher in hooks.json only
        # sends ask_question, which needs no permission; anything else gets the normal prompt.
        if printf '%s' "$INPUT" | grep -q -E '"name" *: *"ask_question"'; then
            printf '{"decision":"allow"}\n'
            run pause
        else
            printf '{"decision":"ask"}\n'
        fi
        ;;
    stop)
        run stop ;;
esac
exit 0
