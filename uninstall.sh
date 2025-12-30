#!/bin/bash
systemctl --user stop pqclid.service

tmux -S "$HOME/.tmux_socket" kill-session -t name 2>/dev/null || true

systemctl --user disable pqclid.service

rm -v ~/.config/systemd/user/pqclid.service

systemctl --user daemon-reload
systemctl --user reset-failed

rm -f -v "$HOME/.tmux_socket"
rm -f -v "$HOME/.local/bin/tmux-pq-supervisor"
