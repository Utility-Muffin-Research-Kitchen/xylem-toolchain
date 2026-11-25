#include <SDL.h>
#include <EGL/egl.h>
#include <vulkan/vulkan.h>
#include <wayland-client.h>
#include <stdio.h>

int main(void)
{
	SDL_version v;
	uint32_t vk = 0;
	SDL_GetVersion(&v);
	vkEnumerateInstanceVersion(&vk);
	printf("cmake: SDL2 %d.%d.%d, Vulkan %u.%u, eglGetDisplay %p, wl_display_connect %p\n",
		v.major, v.minor, v.patch, VK_API_VERSION_MAJOR(vk), VK_API_VERSION_MINOR(vk),
		(void *)eglGetDisplay, (void *)wl_display_connect);
	return 0;
}
