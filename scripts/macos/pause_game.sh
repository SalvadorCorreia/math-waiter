#!/bin/bash
# Claude needs input: hand focus back to Claude. The game pauses itself on blur.

source "$(dirname "$0")/common.sh"

restore_focus
exit 0
