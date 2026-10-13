#!/usr/bin/env bash
set -e
. "$(dirname "$0")/drive.sh"
sleep 1.5
t "Share bill" 1 2
t "Send PDF bill" 1 5
t "Print" 1 12                            # wait for the preview to render
key 4; sleep 2
t "Share bill" 1 2
sleep 3                                   # WhatsApp option
key 4; sleep 1.5
