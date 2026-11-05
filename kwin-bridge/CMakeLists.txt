cmake_minimum_required(VERSION 3.16)
project(macshell_kwin_bridge VERSION 0.2.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core DBus Gui)
find_package(PkgConfig REQUIRED)
pkg_check_modules(KWAYLAND_CLIENT REQUIRED IMPORTED_TARGET KWaylandClient)
pkg_check_modules(WAYLAND_CLIENT REQUIRED IMPORTED_TARGET wayland-client)
pkg_check_modules(WAYLAND_PROTOCOLS REQUIRED wayland-protocols)
pkg_check_modules(WLR_PROTOCOLS REQUIRED wlr-protocols)
pkg_get_variable(WAYLAND_PROTOCOLS_DIR wayland-protocols pkgdatadir)
pkg_get_variable(WLR_PROTOCOLS_DIR wlr-protocols pkgdatadir)
find_program(WAYLAND_SCANNER wayland-scanner REQUIRED)

# wlr-layer-shell (the minimize-target anchors in main.cpp); its get_popup refers to xdg_popup, so xdg-shell's interface
# code is linked too
set(protocol_sources)
foreach(protocol "${WLR_PROTOCOLS_DIR}/unstable/wlr-layer-shell-unstable-v1.xml" "${WAYLAND_PROTOCOLS_DIR}/stable/xdg-shell/xdg-shell.xml")
    get_filename_component(base "${protocol}" NAME_WE)
    add_custom_command(
        OUTPUT "${base}-client-protocol.h" "${base}-protocol.c"
        COMMAND "${WAYLAND_SCANNER}" client-header "${protocol}" "${base}-client-protocol.h"
        COMMAND "${WAYLAND_SCANNER}" private-code "${protocol}" "${base}-protocol.c"
        DEPENDS "${protocol}"
        VERBATIM)
    list(APPEND protocol_sources "${CMAKE_CURRENT_BINARY_DIR}/${base}-client-protocol.h" "${CMAKE_CURRENT_BINARY_DIR}/${base}-protocol.c")
endforeach()

add_executable(macshell-kwin-bridge main.cpp ${protocol_sources})
target_include_directories(macshell-kwin-bridge PRIVATE "${CMAKE_CURRENT_BINARY_DIR}")
target_compile_definitions(macshell-kwin-bridge PRIVATE BRIDGE_VERSION="${PROJECT_VERSION}")
target_link_libraries(macshell-kwin-bridge PRIVATE
    Qt6::Core
    Qt6::DBus
    Qt6::Gui
    PkgConfig::KWAYLAND_CLIENT
    PkgConfig::WAYLAND_CLIENT
)

install(TARGETS macshell-kwin-bridge RUNTIME DESTINATION bin)
