#!/bin/sh

if [ "$os" = "Linux"]; then
    # Install tmux if not present
    packagesNeeded=(tmux)
    if [ -x "$(command -v apk)" ]; then
        sudo apk add --no-cache "${packagesNeeded[@]}"
    elif [ -x "$(command -v apt-get)" ]; then
        sudo apt-get install "${packagesNeeded[@]}"
    elif [ -x "$(command -v dnf)" ]; then
        sudo dnf install "${packagesNeeded[@]}"
    elif [ -x "$(command -v zypper)" ]; then
        sudo zypper install "${packagesNeeded[@]}"
    else
        echo "FAILED TO INSTALL PACKAGE: Package manager not found. You must manually install: "${packagesNeeded[@]}"">&2;
    fi

    # Install pqcli latest version from GitHub
    cd /tmp/
    git clone https://github.com/rr-/pq-cli.git
    cd pq-cli
    pip install --user .

    # Install and start the daemon
    sudo mv pqcli.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable pqcli
    sudo systemctl start pqcli

else
    echo "Not a Linux machine, quitting..."
fi