#!/bin/sh
# lock-wallpaper.sh <picture>: gives KDE's lock screen MacShell's wallpaper while MacLock is KDE's lock screen
# (MacBar.qml runs it whenever the wallpaper changes). KDE draws its own lock wallpaper under the lock screen's QML,
# and that picture showed for a moment before MacLock's had loaded. Written the way plasma-apply-wallpaperimage
# writes the desktop's. Nothing is written otherwise: the picture set in System Settings → Screen Locking is the user's.
[ -f "$1" ] || exit 0
# plasmashellrc names the shell package before the variable does (handoff/18)
shell=$(kreadconfig6 --file plasmashellrc --group Shell --key ShellPackage 2>/dev/null)
[ "${shell:-${PLASMA_DEFAULT_SHELL:-}}" = com.macshell.lock ] || exit 0
kwriteconfig6 --file kscreenlockerrc --group Greeter --key WallpaperPlugin org.kde.image
kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General --key Image "file://$1"
