# Installs MacShell for KDE Plasma outside Nix: the Quickshell configuration, the launchers, the KWin bridge, the systemd
# user units, Dolphin's service menu and the lock-screen package. install.sh (in a Plasma session) and
# packaging/arch/PKGBUILD run it; by hand:
#   cmake -S . -B build -DCMAKE_INSTALL_PREFIX=/usr/local && cmake --build build && sudo cmake --install build
# The Nix packages (flake.nix) do not use this file. What it installs is also install.sh's uninstall list (kde_files):
# nix/test-install.sh fails when the two disagree.
cmake_minimum_required(VERSION 3.16)
file(STRINGS MacShell/VERSION MACSHELL_VERSION LIMIT_COUNT 1)
project(macshell VERSION ${MACSHELL_VERSION} LANGUAGES NONE)

option(MACSHELL_BRIDGE "Build and install macshell-kwin-bridge (off when it is packaged separately)" ON)
if(MACSHELL_BRIDGE)
    add_subdirectory(kwin-bridge)
endif()

# share/macshell/shell, not share/macshell: with the prefix ~/.local that is where upstream's Hyprland installer keeps
# its backups and tools
install(DIRECTORY MacShell/ DESTINATION share/macshell/shell USE_SOURCE_PERMISSIONS PATTERN "__pycache__" EXCLUDE)
install(PROGRAMS nix/macshell.sh DESTINATION bin RENAME macshell)
install(PROGRAMS nix/macshell-session.sh DESTINATION bin RENAME macshell-session)

# share/systemd/user is on the user manager's search path for every prefix it knows (~/.local, /usr/local, /usr)
foreach(unit macshell.service macshell-fallback.service)
    configure_file(packaging/systemd/${unit}.in ${unit} @ONLY)
    install(FILES "${CMAKE_CURRENT_BINARY_DIR}/${unit}" DESTINATION share/systemd/user)
endforeach()

# Dolphin's "Pin to MacShell Dock". Executable: KDE runs a service menu outside the system directories only then
file(READ nix/macshell-pin-folder.desktop menu)
string(REPLACE "Exec=macshell " "Exec=${CMAKE_INSTALL_PREFIX}/bin/macshell " menu "${menu}")
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/macshell-pin-folder.desktop" "${menu}")
install(PROGRAMS "${CMAKE_CURRENT_BINARY_DIR}/macshell-pin-folder.desktop" DESTINATION share/kio/servicemenus)

# MacLock as a lock-screen package for KDE's screen locker; unused until PLASMA_DEFAULT_SHELL names it (README)
add_custom_target(macshell-lock ALL
    COMMAND sh "${CMAKE_CURRENT_SOURCE_DIR}/MacLock/kde/build.sh" "${CMAKE_CURRENT_BINARY_DIR}/lock" VERBATIM)
install(DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/lock/com.macshell.lock" DESTINATION share/plasma/shells)
