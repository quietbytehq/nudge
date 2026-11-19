#!/bin/sh
# Starts Nudge full screen.
cd "$(dirname "$0")" && exec "$HOME/.local/bin/godot" --path . --fullscreen
