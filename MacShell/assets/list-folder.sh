#!/bin/sh
# list-folder.sh <dir> [max]: what a folder pinned to the Dock shows when it is clicked (MacDock.qml, DockFolders.js).
# Prints "mime type<TAB>name" for the newest <max> children, newest first, hidden files left out. The type is
# inode/directory for a folder and empty when `file` is not installed (the Dock then shows a generic icon).
cd "$1" 2>/dev/null || exit 0
# shellcheck disable=SC2012 # ls -t is the portable "newest first"; a name with a newline in it is listed wrongly, nothing more
ls -t 2>/dev/null | head -n "${2:-15}" | {
    set --
    while IFS= read -r f; do set -- "$@" "$f"; done
    [ $# -gt 0 ] || exit 0
    # one `file` for all of them, a line each in the same order: one process per child was most of the stack's delay
    file -bL --mime-type -- "$@" 2>/dev/null | for f; do
        IFS= read -r m || m=
        [ -d "$f" ] && m=inode/directory
        printf '%s\t%s\n' "$m" "$f"
    done
}
