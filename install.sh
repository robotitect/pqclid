#!/bin/sh

if [ "$os" = "Linux"]; then
    # Install tmux if not present
    if command -v tmux > /dev/null 2>&1; then
        echo "tmux installed"
    else
        packagesNeeded=(tmux)
        if [ -x "$(command -v apk)" ]; then
            sudo apk add --no-cache "${packagesNeeded[@]}"
        elif [ -x "$(command -v apt-get)" ]; then
            sudo apt-get install "${packagesNeeded[@]}"
        elif [ -x "$(command -v dnf)" ]; then
            sudo dnf install "${packagesNeeded[@]}"
        elif [ -x "$(command -v zypper)" ]; then
            sudo zypper install "${packagesNeeded[@]}"
        elif [ -x "$(command -v pacman)" ]; then
            sudo pacman -S tmux
        elif [ -x "$(command -v yum)" ]; then
            sudo yum install tmux
        else
            echo "FAILED TO INSTALL PACKAGE: Package manager not found."
            echo "You must manually install: "${packagesNeeded[@]}""
        fi
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