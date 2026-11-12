#!/usr/bin/env bash
#
# install.sh - Build and install helper for macOS Dock Plasma 6 widget
# Compiles the native blur and application menu plugins and/or installs the plasmoid.
#

set -e

BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RED="\033[0;31m"
RESET="\033[0m"

info() {
    echo -e "${CYAN}${BOLD}[INFO]${RESET} $*"
}

success() {
    echo -e "${GREEN}${BOLD}[SUCCESS]${RESET} $*"
}

warn() {
    echo -e "${YELLOW}${BOLD}[WARNING]${RESET} $*"
}

error() {
    echo -e "${RED}${BOLD}[ERROR]${RESET} $*"
}

usage() {
    echo -e "${BOLD}Usage:${RESET} $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --plugin-only    Build & install only the native modules"
    echo "                   (Use only when the matching QML is already installed)"
    echo "  --uninstall      Remove installed files from the system"
    echo "  --help, -h       Show this help message"
    echo ""
}

PLUGIN_ONLY=0
UNINSTALL=0

for arg in "$@"; do
    case "$arg" in
        --plugin-only)
            PLUGIN_ONLY=1
            ;;
        --uninstall)
            UNINSTALL=1
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            error "Unknown option: $arg"
            usage
            exit 1
            ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo -e "${BOLD}=========================================${RESET}"
echo -e "${BOLD}   macOS Dock for KDE Plasma 6 (Build)   ${RESET}"
echo -e "${BOLD}=========================================${RESET}"
echo ""

# Handle uninstall
if [ "$UNINSTALL" -eq 1 ]; then
    info "Uninstalling..."

    if [ -f build/install_manifest.txt ]; then
        info "Removing installed files recorded in build/install_manifest.txt..."
        sudo xargs -d '\n' rm -f < build/install_manifest.txt
    else
        warn "build/install_manifest.txt not found. Cannot automatically determine installed files."
    fi

    USER_ICON_FILE="${HOME}/.local/share/icons/hicolor/256x256/apps/com.github.mattanis.macosdock.png"
    if [ -f "$USER_ICON_FILE" ]; then
        rm -f "$USER_ICON_FILE"
        info "Removed user icon."
    fi

    if [ -d build ]; then
        rm -rf build
        info "Cleaned build directory."
    fi

    success "Uninstall finished."
    exit 0
fi

# Check for required tools
for tool in cmake g++ make; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        error "Required tool '$tool' not found."
        echo "Please install build tools (cmake, C++ compiler) from your distribution's package manager."
        echo "See README.md for the dependency package list for your Linux distribution."
        exit 1
    fi
done

# A user-installed applet takes precedence over /usr/share. Update that copy
# too when installing the complete fork, rather than leaving stale QML active.
USER_APPLET="${XDG_DATA_HOME:-${HOME}/.local/share}/plasma/plasmoids/com.github.mattanis.macosdock"

CMAKE_ARGS=(
    "-DCMAKE_BUILD_TYPE=Release"
    "-DCMAKE_INSTALL_PREFIX=/usr"
    "-DBUILD_PLUGIN_ONLY=OFF"
    "-DBUILD_NATIVE_MENUS=ON"
)

if [ "$PLUGIN_ONLY" -eq 1 ]; then
    info "Building native plugins only (skipping plasmoid applet)..."
    CMAKE_ARGS+=("-DBUILD_PLUGIN_ONLY=ON")
else
    info "Building native plugins and plasmoid applet..."
fi

info "Configuring with CMake..."
if ! cmake -B build -S . "${CMAKE_ARGS[@]}"; then
    echo ""
    error "CMake configuration failed."
    echo "You may be missing required development headers (ECM, Qt6, KF6 WindowSystem/KIO/Service/I18n/Notifications, libplasma, plasma-activities-stats)."
    echo "Check README.md -> 'Build Dependencies' for your distribution's package command."
    exit 1
fi

info "Compiling..."
cmake --build build -j"$(nproc 2>/dev/null || echo 2)"

info "Installing to system (requires sudo)..."
sudo cmake --install build

if [ "$PLUGIN_ONLY" -eq 0 ] && [ -d "$USER_APPLET" ]; then
    info "Updating the user-installed applet that overrides the system copy..."
    # kpackagetool6 --upgrade rejects equal versions, including development
    # updates. Mirror the source files just as CMake does for the system copy.
    # Applet settings live in Plasma's configuration, outside this directory.
    cp -R contents "$USER_APPLET/"
    cp metadata.json "$USER_APPLET/"
fi

if [ "$PLUGIN_ONLY" -eq 0 ] && [ -f "assets/logo.png" ]; then
    USER_ICON_DIR="${HOME}/.local/share/icons/hicolor/256x256/apps"
    mkdir -p "$USER_ICON_DIR"
    cp "assets/logo.png" "${USER_ICON_DIR}/com.github.mattanis.macosdock.png"
    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        gtk-update-icon-cache -q -t -f "${HOME}/.local/share/icons/hicolor" 2>/dev/null || true
    fi
fi

success "Installation completed successfully!"
echo ""

# Prompt to restart Plasma Shell
if systemctl --user is-active --quiet plasma-plasmashell; then
    read -rp "Restart Plasma Shell now to load the changes? [y/N]: " choice
    case "$choice" in
        [yY][eE][sS]|[yY])
            info "Restarting plasma-plasmashell..."
            systemctl --user restart plasma-plasmashell
            success "Plasma Shell restarted."
            ;;
        *)
            info "You can restart Plasma later with: systemctl --user restart plasma-plasmashell"
            ;;
    esac
fi

echo ""
success "Done!"

