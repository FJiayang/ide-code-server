#!/bin/bash
# init-home.sh - Initialize /home/coder directory for volume mount compatibility
# This script ensures configuration files and directories exist when /home/coder is mounted externally

set -e

HOME_DIR="/home/coder"
CONFIG_TEMPLATES="/opt/dev-configs"

# Create necessary directories
echo "Creating directories..."
mkdir -p "$HOME_DIR/project"
mkdir -p "$HOME_DIR/.local/share/code-server"
mkdir -p "$HOME_DIR/.local/share/pnpm"
mkdir -p "$HOME_DIR/.local/share/gem/ruby/3.4.0/bin"
mkdir -p "$HOME_DIR/.m2/repository"
mkdir -p "$HOME_DIR/.config/pip"
mkdir -p "$HOME_DIR/.npm"
mkdir -p "$HOME_DIR/.cache/uv"
mkdir -p "$HOME_DIR/.cache/pip"
mkdir -p "$HOME_DIR/go"

# Initialize .bashrc if needed
BASHRC_FILE="$HOME_DIR/.bashrc"
if [ -f "$BASHRC_FILE" ]; then
    # Check if PATH restoration already exists
    if ! grep -q "# Restore Docker ENV PATH" "$BASHRC_FILE"; then
        echo "Appending PATH configuration to .bashrc..."
        cat "$CONFIG_TEMPLATES/bashrc-append.sh" >> "$BASHRC_FILE"
    fi
else
    echo "Creating .bashrc..."
    cp "$CONFIG_TEMPLATES/bashrc-append.sh" "$BASHRC_FILE"
fi

# Initialize .gemrc if not exists
GEMRC_FILE="$HOME_DIR/.gemrc"
if [ ! -f "$GEMRC_FILE" ]; then
    echo "Creating .gemrc..."
    cp "$CONFIG_TEMPLATES/gemrc" "$GEMRC_FILE"
fi

# Initialize Maven settings.xml if not exists
M2_SETTINGS="$HOME_DIR/.m2/settings.xml"
if [ ! -f "$M2_SETTINGS" ]; then
    echo "Creating Maven settings.xml..."
    cp "$CONFIG_TEMPLATES/m2-settings.xml" "$M2_SETTINGS"
fi

# Initialize pip config if not exists
PIP_CONF="$HOME_DIR/.config/pip/pip.conf"
if [ ! -f "$PIP_CONF" ]; then
    echo "Creating pip.conf..."
    cp "$CONFIG_TEMPLATES/pip.conf" "$PIP_CONF"
fi

# Set ownership for coder user (if running as root)
if [ "$(id -u)" = "0" ]; then
    echo "Setting ownership..."
    chown -R coder:coder "$HOME_DIR"
fi

echo "Initialization complete."
