#!/bin/sh

sudo apt install tmux

cd /tmp/
git clone https://github.com/rr-/pq-cli.git
cd pq-cli
pip install --user .

sudo mv pqcli.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable pqcli
sudo systemctl start  pqcli
