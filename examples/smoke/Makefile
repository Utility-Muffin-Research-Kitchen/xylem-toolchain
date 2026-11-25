# Runs inside the xylem toolchain image (make smoke at the top level).
BUILD := build
MODULES := sdl2 SDL2_image SDL2_ttf SDL2_mixer egl glesv2 gbm libdrm vulkan \
	wayland-client wayland-egl xkbcommon alsa libpulse libudev \
	libcrypt libcurl freetype2 harfbuzz inih libjpeg json-c openssl pixman-1 \
	libpng sqlite3 icu-uc zlib
CFLAGS := -O2 -mcpu=cortex-a55 -Wall -Wextra -Werror -I$(BUILD) $(shell pkg-config --cflags $(MODULES))
LDLIBS := $(shell pkg-config --libs $(MODULES))
SCANNER := $(shell pkg-config --variable=wayland_scanner wayland-scanner)
XDG_SHELL := $(shell pkg-config --variable=pkgdatadir wayland-protocols)/stable/xdg-shell/xdg-shell.xml
LIBPATH := $(SYSROOT)/lib:$(SYSROOT)/usr/lib:$(SYSROOT)/usr/lib/pulseaudio
VERIFY := /opt/xylem-toolchain/share/xylem-toolchain/verify-binary.sh

.PHONY: all check run clean

all: $(BUILD)/xylem-smoke $(BUILD)/xylem-smoke-cxx $(BUILD)/cmake/xylem-smoke-cmake

$(BUILD)/xdg-shell-client-protocol.h: | $(BUILD)
	$(SCANNER) client-header $(XDG_SHELL) $@

$(BUILD)/xdg-shell-protocol.c: | $(BUILD)
	$(SCANNER) private-code $(XDG_SHELL) $@

$(BUILD)/xylem-smoke: main.c $(BUILD)/xdg-shell-client-protocol.h $(BUILD)/xdg-shell-protocol.c
	$(CC) $(CFLAGS) -o $@ main.c $(BUILD)/xdg-shell-protocol.c $(LDLIBS)

$(BUILD)/xylem-smoke-cxx: cxx.cpp | $(BUILD)
	$(CXX) -O2 -mcpu=cortex-a55 -Wall -Wextra -Werror -std=c++17 -o $@ cxx.cpp \
		$(shell pkg-config --cflags --libs fmt) -pthread

# The CMake route: the image's Toolchain.cmake and SDL2's own CMake package
$(BUILD)/cmake/xylem-smoke-cmake: cmake/CMakeLists.txt cmake/main.c
	cmake -S cmake -B $(BUILD)/cmake -G Ninja
	cmake --build $(BUILD)/cmake

$(BUILD):
	mkdir -p $@

# What the binaries need from the device: the loader, the glibc symbol
# versions, and each NEEDED library
check: all
	$(VERIFY) $(BUILD)/xylem-smoke
	$(VERIFY) $(BUILD)/xylem-smoke-cxx
	$(VERIFY) $(BUILD)/cmake/xylem-smoke-cmake

# Run them here through the sysroot's own loader and libraries (the image is
# aarch64 on an arm64 host; on amd64 this needs qemu-user)
run: all
	$(SYSROOT)/lib/ld-linux-aarch64.so.1 --library-path $(LIBPATH) $(BUILD)/xylem-smoke
	$(SYSROOT)/lib/ld-linux-aarch64.so.1 --library-path $(LIBPATH) $(BUILD)/xylem-smoke-cxx
	$(SYSROOT)/lib/ld-linux-aarch64.so.1 --library-path $(LIBPATH) $(BUILD)/cmake/xylem-smoke-cmake

clean:
	rm -rf $(BUILD)
