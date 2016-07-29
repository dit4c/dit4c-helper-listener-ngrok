#!/bin/sh

set -e

# Read each line in
while IFS= read -r line; do
  # Only assess lines containing the URL, and print URL to output
  printf '%s\n' "$line" | grep 'Tunnel established at' | grep -Eo '[^ ]*://[^ ]*' | sed -e 's/^tcp/http/'
done
