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
    while [ ! -f ~/.config/pqcli/save.dat ]; do
        read -p "Create a character: press Enter to open pqcli and create a character; Ctrl+C to quit when don"
        pqcli

        if [ -f ~/.config/pqcli/save.dat ]
            echo "pqcli save file created"
        else
            echo "pqcli save file not created, try again."
        fi
    done
    echo "pqcli save file found"

    # Install and start the daemon
    mkdir -pv ~/.config/systemd/user/ && cp -v pqclid.service ~/.config/systemd/user/pqclid.service
    cp -v tmux-pq-supervisor ~/.local/bin/tmux-pq-supervisor

    sudo loginctl enable-linger "$USER"

    systemctl --user daemon-reload
    systemctl --user enable --now pqclid.service
else
    echo "Not a Linux machine, quitting..."
fi
