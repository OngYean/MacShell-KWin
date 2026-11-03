cmake_minimum_required(VERSION 3.16)
project(macshell_kwin_bridge VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core DBus Gui)
find_package(PkgConfig REQUIRED)
pkg_check_modules(KWAYLAND_CLIENT REQUIRED IMPORTED_TARGET KWaylandClient)
pkg_check_modules(WAYLAND_CLIENT REQUIRED IMPORTED_TARGET wayland-client)

add_executable(macshell-kwin-bridge main.cpp)
target_compile_definitions(macshell-kwin-bridge PRIVATE BRIDGE_VERSION="${PROJECT_VERSION}")
target_link_libraries(macshell-kwin-bridge PRIVATE
    Qt6::Core
    Qt6::DBus
    Qt6::Gui
    PkgConfig::KWAYLAND_CLIENT
    PkgConfig::WAYLAND_CLIENT
)

install(TARGETS macshell-kwin-bridge RUNTIME DESTINATION bin)
