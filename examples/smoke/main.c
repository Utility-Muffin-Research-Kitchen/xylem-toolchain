/*
 * Links against every C library in the xylem SDK and calls each one, so the
 * binary NEEDs them all. Run on a xylem device, or on any aarch64 Linux
 * through the SDK's own loader (make run, below), it prints each library's
 * version and exercises the few that can work without hardware.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <SDL2/SDL.h>
#include <SDL2/SDL_image.h>
#include <SDL2/SDL_mixer.h>
#include <SDL2/SDL_ttf.h>
#include <SDL2/SDL_syswm.h>

#include <EGL/egl.h>
#include <GLES2/gl2.h>
#include <gbm.h>
#include <xf86drm.h>
#include <vulkan/vulkan.h>

#include <wayland-client.h>
#include <wayland-egl.h>
#include <xkbcommon/xkbcommon.h>

#include <alsa/asoundlib.h>
#include <pulse/pulseaudio.h>
#include <libudev.h>

#include <crypt.h>
#include <curl/curl.h>
#include <ft2build.h>
#include FT_FREETYPE_H
#include <hb.h>
#include <ini.h>
#include <jpeglib.h>
#include <json-c/json.h>
#include <openssl/crypto.h>
#include <pixman.h>
#include <png.h>
#include <sqlite3.h>
#include <unicode/uversion.h>
#include <zlib.h>

#include "xdg-shell-client-protocol.h"

static int failures;

static void check(const char *what, int ok)
{
	printf("%-10s %s\n", what, ok ? "ok" : "FAILED");
	if (!ok)
		failures++;
}

static int on_ini_line(void *user, const char *section, const char *name, const char *value)
{
	(void)section;
	if (strcmp(name, "answer") == 0)
		*(int *)user = atoi(value);
	return 1;
}

int main(void)
{
	SDL_version sdl;
	SDL_GetVersion(&sdl);
	printf("SDL2       %d.%d.%d\n", sdl.major, sdl.minor, sdl.patch);
	const SDL_version *v = IMG_Linked_Version();
	printf("SDL2_image %d.%d.%d\n", v->major, v->minor, v->patch);
	v = TTF_Linked_Version();
	printf("SDL2_ttf   %d.%d.%d\n", v->major, v->minor, v->patch);
	v = Mix_Linked_Version();
	printf("SDL2_mixer %d.%d.%d\n", v->major, v->minor, v->patch);
#ifdef SDL_VIDEO_DRIVER_WAYLAND
	/* The Wayland half of SDL_syswm.h, which PPSSPP needed by hand on stock */
	SDL_SysWMinfo wm;
	SDL_VERSION(&wm.version);
	printf("SDL2 wm    wayland surface field at offset %zu\n",
		(size_t)((char *)&wm.info.wl.surface - (char *)&wm));
#else
#error "SDL2 in the SDK has no Wayland video driver"
#endif
	printf("SDL2 video:");
	for (int i = 0; i < SDL_GetNumVideoDrivers(); i++)
		printf(" %s", SDL_GetVideoDriver(i));
	printf("\nSDL2 audio:");
	for (int i = 0; i < SDL_GetNumAudioDrivers(); i++)
		printf(" %s", SDL_GetAudioDriver(i));
	printf("\n");

	/* Interfaces only: there is no GPU here, and the device's are the blob's */
	printf("EGL        eglGetProcAddress %p\n", (void *)eglGetProcAddress);
	printf("GLESv2     glGetString %p\n", (void *)glGetString);
	printf("gbm        gbm_create_device %p\n", (void *)gbm_create_device);
	printf("libdrm     drmAvailable %d\n", drmAvailable());
	uint32_t vk = 0;
	if (vkEnumerateInstanceVersion(&vk) == VK_SUCCESS)
		printf("Vulkan     loader %u.%u.%u\n", VK_API_VERSION_MAJOR(vk),
			VK_API_VERSION_MINOR(vk), VK_API_VERSION_PATCH(vk));
	printf("wayland    wl_display_connect %p, wl_egl_window_create %p, xdg_wm_base %s\n",
		(void *)wl_display_connect, (void *)wl_egl_window_create, xdg_wm_base_interface.name);

	struct xkb_context *xkb = xkb_context_new(XKB_CONTEXT_NO_DEFAULT_INCLUDES);
	check("xkbcommon", xkb != NULL);
	xkb_context_unref(xkb);

	printf("ALSA       %s\n", snd_asoundlib_version());
	printf("PulseAudio %s\n", pa_get_library_version());
	struct udev *udev = udev_new();
	check("libudev", udev != NULL);
	udev_unref(udev);

	sqlite3 *db = NULL;
	char **rows = NULL;
	int nrow = 0, ncol = 0;
	int ok = sqlite3_open(":memory:", &db) == SQLITE_OK &&
		sqlite3_get_table(db, "select json_extract('{\"a\":42}', '$.a')", &rows, &nrow, &ncol, NULL) == SQLITE_OK &&
		nrow == 1 && strcmp(rows[1], "42") == 0;
	printf("SQLite     %s\n", sqlite3_libversion());
	check("sqlite json", ok);
	sqlite3_free_table(rows);
	sqlite3_close(db);

	struct json_object *obj = json_tokener_parse("{\"leaf\": true}");
	printf("json-c     %s\n", json_c_version());
	check("json-c", obj && json_object_get_boolean(json_object_object_get(obj, "leaf")));
	json_object_put(obj);

	curl_version_info_data *curl = curl_version_info(CURLVERSION_NOW);
	printf("libcurl    %s, %s\n", curl->version, curl->ssl_version ? curl->ssl_version : "no TLS");
	check("curl tls", curl->ssl_version != NULL && (curl->features & CURL_VERSION_SSL));
	printf("OpenSSL    %s\n", OpenSSL_version(OPENSSL_VERSION));

	const char *hash = crypt("leaf", "$6$xylemsdk$");
	check("crypt sha512", hash && strncmp(hash, "$6$xylemsdk$", 12) == 0);

	FT_Library ft;
	int ft_major = 0, ft_minor = 0, ft_patch = 0;
	if (FT_Init_FreeType(&ft) == 0) {
		FT_Library_Version(ft, &ft_major, &ft_minor, &ft_patch);
		FT_Done_FreeType(ft);
	}
	printf("FreeType   %d.%d.%d\n", ft_major, ft_minor, ft_patch);
	printf("HarfBuzz   %s\n", hb_version_string());
	printf("libpng     %s\n", png_get_libpng_ver(NULL));
	struct jpeg_error_mgr jerr;
	jpeg_std_error(&jerr);
	printf("libjpeg    API %d\n", JPEG_LIB_VERSION);
	printf("pixman     %s\n", pixman_version_string());
	UVersionInfo icu;
	char icu_s[U_MAX_VERSION_STRING_LENGTH];
	u_getVersion(icu);
	u_versionToString(icu, icu_s);
	printf("ICU        %s\n", icu_s);

	int answer = 0;
	ini_parse_string("[leaf]\nanswer = 42\n", on_ini_line, &answer);
	check("inih", answer == 42);

	unsigned char packed[64], unpacked[64];
	uLongf packed_len = sizeof(packed), unpacked_len = sizeof(unpacked);
	const char *text = "xylem xylem xylem xylem";
	ok = compress(packed, &packed_len, (const unsigned char *)text, strlen(text) + 1) == Z_OK &&
		uncompress(unpacked, &unpacked_len, packed, packed_len) == Z_OK &&
		strcmp((char *)unpacked, text) == 0;
	printf("zlib       %s\n", zlibVersion());
	check("zlib", ok);

	printf("%s\n", failures ? "smoke: FAILED" : "smoke: all ok");
	return failures ? 1 : 0;
}
