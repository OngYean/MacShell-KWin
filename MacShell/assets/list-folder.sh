#!/bin/sh
# list-folder.sh <dir> [max]: what a folder pinned to the Dock shows when it is clicked (MacDock.qml, DockFolders.js).
# Prints "mime type<TAB>name" for the newest <max> children, newest first, hidden files left out. The type is
# inode/directory for a folder and empty when `file` is not installed (the Dock then shows a generic icon).
cd "$1" 2>/dev/null || exit 0
# shellcheck disable=SC2012 # ls -t is the portable "newest first"; a name with a newline in it is listed wrongly, nothing more
ls -t 2>/dev/null | head -n "${2:-15}" | while IFS= read -r f; do
    if [ -d "$f" ]; then m=inode/directory; else m=$(file -bL --mime-type -- "$f" 2>/dev/null); fi
    printf '%s\t%s\n' "$m" "$f"
done
