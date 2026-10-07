#!/usr/bin/env bash
# Mint a Google Drive OAuth token on this headless Pi.
#
# Uses rclone's shared (already-published) OAuth client: no client_id or
# client_secret in rclone.conf, so no secret is ever passed on the command line
# or exposed in the process list.
#
# Run on the Pi. Forward the callback port from your workstation first:
#   ssh -N -L 53682:127.0.0.1:53682 rsukumar@192.168.4.125
set -euo pipefail

echo "Starting OAuth flow on 127.0.0.1:53682 ..."
echo

# The URL is printed below. Open it in a browser on a machine that can reach the
# forwarded port, sign in, and approve.
rclone authorize "drive" --auth-no-open-browser