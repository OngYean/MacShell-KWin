cmake_minimum_required(VERSION 3.16)
project(macshell_kwin_backend_probe VERSION 0.2.0 LANGUAGES CXX)

include(CTest)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(Qt6 REQUIRED COMPONENTS Core DBus Gui)
find_package(PkgConfig REQUIRED)
pkg_check_modules(KWAYLAND_CLIENT REQUIRED IMPORTED_TARGET KWaylandClient)
pkg_check_modules(WAYLAND_CLIENT REQUIRED IMPORTED_TARGET wayland-client)

add_executable(macshell-kwin-backend-probe main.cpp)
target_link_libraries(macshell-kwin-backend-probe PRIVATE
    Qt6::Core
    Qt6::DBus
    Qt6::Gui
    PkgConfig::KWAYLAND_CLIENT
    PkgConfig::WAYLAND_CLIENT
)

install(TARGETS macshell-kwin-backend-probe RUNTIME DESTINATION bin)

if(BUILD_TESTING)
    add_executable(macshell-kwin-menu-label-test menu-label-test.cpp)
    target_link_libraries(macshell-kwin-menu-label-test PRIVATE Qt6::Core)
    add_test(NAME dbusmenu-label-normalization COMMAND macshell-kwin-menu-label-test)
endif()
