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
    echo "Task: Complete one bead using /work"

    echo "/work" | claude --dangerously-skip-permissions

    echo "=== Session complete ==="
    echo "Waiting 5 seconds before next iteration..."
    sleep 5
done
