#!/bin/sh
# Installs Deadline Countdown for the current user (no root needed):
#   ~/.local/share/deadline-countdown   app files
#   ~/.local/bin/deadline-countdown     command
#   app menu entry + icon
set -e
here="$(cd "$(dirname "$0")" && pwd)"
dest="$HOME/.local/share/deadline-countdown"
rm -rf "$dest"
mkdir -p "$dest" "$HOME/.local/bin" "$HOME/.local/share/applications" "$HOME/.local/share/icons/hicolor/256x256/apps"
cp -R "$here/bundle/." "$dest/"
ln -sf "$dest/deadlines" "$HOME/.local/bin/deadline-countdown"
cp "$here/deadline-countdown.png" "$HOME/.local/share/icons/hicolor/256x256/apps/deadline-countdown.png"
sed "s|@EXEC@|$dest/deadlines|" "$here/deadline-countdown.desktop" > "$HOME/.local/share/applications/deadline-countdown.desktop"
command -v update-desktop-database >/dev/null && update-desktop-database "$HOME/.local/share/applications" || true
echo "Installed. Open \"Deadline Countdown\" from your app menu, or run: deadline-countdown"
