#!/bin/sh

set -e

MAX_RETRY=6
RETRY=0

# Read each line in
while IFS= read -r line; do
  # Only assess lines containing the URL, and print URL to output
  URL=$(printf '%s\n' "$line" | \
    grep 'Tunnel established at' | \
    grep -Eo '[^ ]*://[^ ]*' | \
    sed -e 's/^tcp/http/')
  if [[ "$URL" != "" ]]; then
    RETRY=0
    echo "$URL"
    continue
  fi
  # If a "waiting X seconds before reconnecting", then
  printf '%s\n' "$line" | grep -i "waiting.*before reconnecting" >&2 && \
    # Increment counter
    RETRY=$(( $RETRY + 1 )) && \
    # Check if we've exceeded max
    test $RETRY -ge $MAX_RETRY &&
    # Log error and exit
    echo "Disconnected for too long" >&2 && exit 1 || \
    # Otherwise continue
    true
done
