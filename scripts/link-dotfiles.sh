#!/usr/bin/env bash
set -euo pipefail

cd "$HOME/linux/dotfiles" || exit

for file in .[!.]*; do
    case "$file" in
        .i3.conf)
            dest="$HOME/.config/i3/config"
            ;;
        .i3status.conf)
            dest="$HOME/.config/i3status/config"
            ;;
        *)
            dest="$HOME/$file"
            ;;
    esac

    mkdir -p "$(dirname "$dest")"
    rm -f "$dest"
    ln -s "$PWD/$file" "$dest"
done
