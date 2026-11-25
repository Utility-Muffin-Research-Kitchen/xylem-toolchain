# The CMake route Leaf's emulator builds take: the image's toolchain file,
# SDL2's own CMake package, pkg-config, and CMake's Vulkan and EGL finders.
cmake_minimum_required(VERSION 3.20)
project(xylem_smoke_cmake C)

find_package(SDL2 CONFIG REQUIRED)
find_package(Vulkan REQUIRED)
find_package(PkgConfig REQUIRED)
pkg_check_modules(WAYLAND REQUIRED IMPORTED_TARGET wayland-client wayland-egl egl glesv2)

add_executable(xylem-smoke-cmake main.c)
target_link_libraries(xylem-smoke-cmake PRIVATE SDL2::SDL2 Vulkan::Vulkan PkgConfig::WAYLAND)
