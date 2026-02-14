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
    # git (bootstrap)
    #######################################
    install_git() {
        if command -v git >/dev/null 2>&1; then
            log "git already installed"
            return
        fi

        log "Installing git..."

        case "$PM" in
            apt)
                sudo apt-get update
                sudo apt-get install -y git
                ;;
            dnf)
                sudo dnf install -y git
                ;;
            pacman)
                sudo pacman -S --noconfirm git
                ;;
            *)
                log "ERROR: git is required but no supported package manager found"
                exit 1
                ;;
        esac
    }

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
    # Ruby 3.2.4
    #######################################
    ruby_version_ok() {
        command -v ruby >/dev/null 2>&1 || return 1

        ver="$(ruby -v 2>/dev/null)"
        ver="${ver#ruby }"
        ver="${ver%%p*}"
        ver="${ver%% *}"

        IFS=. read -r major minor patch <<EOF
$ver
EOF

        [ "$major" -eq 3 ] && [ "$minor" -ge 2 ]
    }

    install_ruby() {
        #######################################
        # 1. Use system Ruby if compatible
        #######################################
        if command -v ruby >/dev/null 2>&1; then
            if ruby_version_ok; then
                log "Using system Ruby: $(ruby -v)"
                return
            else
                log "System Ruby present but incompatible: $(ruby -v)"
            fi
        else
            log "No system Ruby detected"
        fi

        #######################################
        # 2. Try installing from package manager
        #######################################
        log "Attempting to install Ruby from package manager"

        case "$PM" in
            apt)
                sudo apt-get update
                sudo apt-get install -y ruby-full
                ;;
            dnf)
                sudo dnf install -y ruby
                ;;
            pacman)
                sudo pacman -S --noconfirm ruby
                ;;
            *)
                log "Unknown package manager — skipping system install"
                ;;
        esac

        if command -v ruby >/dev/null 2>&1 && ruby_version_ok; then
            log "Using packaged Ruby: $(ruby -v)"
            return
        fi

        log "Packaged Ruby not compatible or not available"

        #######################################
        # 3. Install prebuilt Ruby 3.2.4
        #######################################
        RUBY_VERSION="3.2.4"
        PREFIX="$APP_DIR/ruby/$RUBY_VERSION"
        mkdir -p "$PREFIX"

        ARCH="$(uname -m)"
        OS="$(uname -s | tr '[:upper:]' '[:lower:]')"

        case "$ARCH" in
            x86_64) ARCH_TAG="x86_64" ;;
            aarch64|arm64) ARCH_TAG="aarch64" ;;
            armv7l) ARCH_TAG="armv7" ;;
            *)
                log "ERROR: unsupported architecture: $ARCH"
                exit 1
                ;;
        esac

        TMP="$(mktemp -d)"
        cd "$TMP"

        RUBY_URL="https://github.com/YOURORG/YOURREPO/releases/download/ruby-3.2.4/ruby-3.2.4-${OS}-${ARCH_TAG}.tar.gz"

        log "Downloading prebuilt Ruby from $RUBY_URL"
        curl -fL "$RUBY_URL" -o ruby.tar.gz

        tar -xzf ruby.tar.gz -C "$PREFIX"

        ln -sf "$PREFIX/bin/ruby" "$BIN_DIR/ruby"
        ln -sf "$PREFIX/bin/gem" "$BIN_DIR/gem"

        log "Installed bundled Ruby 3.2.4 for $OS-$ARCH_TAG"
    }

    install_pqclid() {
        pipx install git+https://github.com/rr-/pq-cli.git
        pipx ensurepath
    }

    #######################################
    # Run everything
    #######################################
    install_pipx
    install_tmux
    install_git
    install_curl
    install_ruby
    install_pqclid

    log "Installation complete"
    log "Add this to your shell config if needed:"
    log "export PATH=\"$BIN_DIR:\$PATH\""

    # The user needs to create a character and start a save
    echo "Create a character: press Enter to open pqcli and create a character; Ctrl+C to quit when done..."
    read _
    pqcli --no-colors

    # Install and start the daemon
    TMP="$(mktemp -d)"
    cd "$TMP"
    curl -fsSLO https://raw.githubusercontent.com/robotitect/pqclid/main/pqclid.service
    curl -fsSLO https://raw.githubusercontent.com/robotitect/pqclid/main/tmux-pq-supervisor
    chmod +x tmux-pq-supervisor
    mkdir -pv ~/.config/systemd/user/ && cp -v pqclid.service ~/.config/systemd/user/pqclid.service
    cp -v tmux-pq-supervisor ~/.local/bin/tmux-pq-supervisor

    sudo loginctl enable-linger "$USER"

    systemctl --user daemon-reload
    systemctl --user enable --now pqclid.service
else
    log "Not a Linux machine, quitting..."
fi
