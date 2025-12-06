#!/bin/sh

# Install tmux if not present
sudo apt install tmux -y

# Install pqcli latest version from GitHub
cd /tmp/
git clone https://github.com/rr-/pq-cli.git
cd pq-cli
pip install --user .

# Install and start the daemon
sudo mv pqcli.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable pqcli
sudo systemctl start  pqcli
