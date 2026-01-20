#!/bin/bash

# Ralph loop - automated bead worker
# Runs Claude Code to complete one bead at a time

while true; do
    echo "=== Checking for available beads ==="

    if ! bd ready | grep -q .; then
        echo "No remaining beads. Exiting."
        exit 0
    fi

    echo "=== Starting new Claude Code session ==="

    claude --dangerously-skip-permissions --print --verbose --output-format stream-json -p "$(cat prompt.md)" | jq --unbuffered -r '
  if .type == "assistant" then
    (.message.content[]? |
      if .type == "text" then .text
      elif .type == "tool_use" then "→ \(.name): \(.input.command // .input.description // "...")"
      else empty end)
  elif .type == "user" and .tool_use_result.stdout then
    .tool_use_result.stdout | split("\n")[0:3] | join("\n")
  elif .type == "result" then
    "=== Done ==="
  else empty end
'

    echo "=== Session complete ==="
    echo "Waiting 3 seconds before next iteration..."
    sleep 3
done
