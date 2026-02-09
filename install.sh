#!/usr/bin/env bash

OS="`uname`"

if [ "$OS" = "Linux" ]; then
    set -euo pipefail

    APP_NAME="pqclid"
    APP_DIR="$HOME/.local/$APP_NAME"
    BIN_DIR="$APP_DIR/bin"
    RUBY_VERSION="3.4.7"

    mkdir -p "$APP_DIR" "$BIN_DIR"

    log() {
        echo "[$APP_NAME] $*" | tee -a "$APP_DIR/install.log"
    }

    command_exists() {
        command -v "$1" >/dev/null 2>&1
    }

    detect_pm() {
        if command_exists apt-get; then echo "apt"
            elif command_exists dnf; then echo "dnf"
            elif command_exists pacman; then echo "pacman"
            else echo "unknown"
        fi
    }

    PM="$(detect_pm)"

    log "Detected package manager: $PM"

    #######################################
    # curl (bootstrap)
    #######################################
    install_curl() {
        if command_exists curl; then
            log "curl already installed"
            return
        fi

        log "Installing curl"

        case "$PM" in
            apt)
                sudo apt-get update
                sudo apt-get install -y curl
                ;;
            dnf)
                sudo dnf install -y curl
                ;;
            pacman)
                sudo pacman -S --noconfirm curl
                ;;
            *)
                log "ERROR: curl is required but no supported package manager found"
                exit 1
                ;;
        esac
    }

    #######################################
    # pipx
    #######################################
    install_pipx() {
        if command_exists pipx; then
            log "pipx already installed"
            return
        fi

        log "Installing pipx"

        case "$PM" in
            apt)
                sudo apt-get update
                sudo apt-get install -y pipx
                ;;
            dnf)
                sudo dnf install -y pipx
                ;;
            pacman)
                sudo pacman -S --noconfirm python-pipx
                ;;
            *)
                log "Falling back to user install of pipx"
                python3 -m pip install --user pipx
                ;;
        esac

        pipx ensurepath || true
    }

    #######################################
    # tmux
    #######################################
    install_tmux() {
        if command_exists tmux; then
            log "tmux already installed: $(tmux -V)"
            return
        fi

        log "Installing tmux"

        case "$PM" in
            apt)
            sudo apt-get update
            sudo apt-get install -y tmux
            ;;
            dnf)
            sudo dnf install -y tmux
            ;;
            pacman)
            sudo pacman -S --noconfirm tmux
            ;;
            *)
            log "ERROR: tmux not found and no supported package manager"
            log "Please install tmux manually"
            exit 1
            ;;
        esac
    }

    #######################################
    # Ruby 3.4.7 (local, app-scoped)
    #######################################
    install_ruby() {
        if [ -x "$BIN_DIR/ruby" ]; then
            log "Ruby already installed locally"
            return
        fi

        log "Installing Ruby $RUBY_VERSION locally"

        # Build deps
        case "$PM" in
            apt)
            sudo apt-get install -y \
                build-essential libssl-dev libreadline-dev zlib1g-dev \
                libyaml-dev libffi-dev libgdbm-dev
            ;;
            dnf)
            sudo dnf install -y \
                gcc make openssl-devel readline-devel zlib-devel \
                libyaml-devel libffi-devel gdbm-devel
            ;;
            pacman)
            sudo pacman -S --noconfirm \
                base-devel openssl readline zlib libyaml libffi gdbm
            ;;
            *)
            log "WARNING: unknown package manager, Ruby build may fail"
            ;;
        esac

        TMP="$(mktemp -d)"
        cd "$TMP"

        log "Downloading ruby-build"
        curl -fsSL https://github.com/rbenv/ruby-build/archive/refs/tags/v20260121.tar.gz | tar xz
        cd ruby-build-master
        PREFIX="$APP_DIR/ruby/$RUBY_VERSION"
        ./bin/ruby-build "$RUBY_VERSION" "$PREFIX"

        ln -s "$PREFIX/bin/ruby" "$BIN_DIR/ruby"
        ln -s "$PREFIX/bin/gem" "$BIN_DIR/gem"

        log "Ruby installed at $PREFIX"
    }

    #######################################
    # Run everything
    #######################################
    install_pipx
    install_tmux
    install_curl
    install_ruby

    log "Installation complete"
    log "Add this to your shell config if needed:"
    log "export PATH=\"$BIN_DIR:\$PATH\""

    # The user needs to create a character and start a save
    while [ ! -f ~/.config/pqcli/save.dat ]; do
        read -p "Create a character: press Enter to open pqcli and create a character; Ctrl+C to quit when done..."
        pqcli

        if [ -f ~/.config/pqcli/save.dat ]; then
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
