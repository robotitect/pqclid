#!/bin/bash

OS="`uname`"

if [ "$OS" = "Linux" ]; then
    # Install tmux if not present
    if command -v tmux > /dev/null 2>&1 && command -v pipx > /dev/null 2>&1; then
        echo "tmux & pipx installed"
    else
        PACKAGES="tmux pipx"
        if [ -x "$(command -v apt-get)" ]; then
            sudo apt-get -y install $PACKAGES
        elif [ -x "$(command -v dnf)" ]; then
            sudo dnf install $PACKAGES
        elif [ -x "$(command -v pacman)" ]; then
            sudo pacman -S $PACKAGES
        elif [ -x "$(command -v yum)" ]; then
            sudo yum install $PACKAGES
        else
            echo "FAILED TO INSTALL PACKAGES: Package manager not found."
            echo "You must manually install:"
            echo $PACKAGES
        fi

        pipx ensurepath
    fi

    if command -v pqcli > /dev/null 2>&1; then
        echo "pqcli installed"
    else
        # Install pqcli latest version from GitHub
        pushd /tmp/
        git clone https://github.com/rr-/pq-cli.git
        cd pq-cli
        pipx install .
        popd
    fi

    # The user needs to create a character and start a save
    pqcli

    # Install and start the daemon
    sudo cp -i pqclid.service ~/.config/systemd/user/pqclid.service
    cp tmux-pq-supervisor ~/.local/bin/tmux-pq-supervisor

    sudo loginctl enable-linger "$USER"

    systemctl --user daemon-reload
    systemctl --user enable --now name.service
else
    echo "Not a Linux machine, quitting..."
fi
