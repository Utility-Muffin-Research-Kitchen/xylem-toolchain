SHELL := /bin/bash

TOOLCHAIN_NAME := xylem-toolchain
IMAGE_REPO ?= ghcr.io/utility-muffin-research-kitchen
IMAGE_NAME ?= $(IMAGE_REPO)/$(TOOLCHAIN_NAME)
IMAGE_TAG ?= local
LOCAL_IMAGE := $(IMAGE_NAME):$(IMAGE_TAG)

SDK_ARCH ?= $(shell scripts/host-arch.sh)
BUILDER_IMAGE ?= $(TOOLCHAIN_NAME)-builder
SDK_VOLUME ?= $(TOOLCHAIN_NAME)-sdk-$(SDK_ARCH)
WORKSPACE_ROOT ?= $(abspath ..)

include xylem.ref

BUILDER_RUN := docker run --rm --platform linux/$(SDK_ARCH) \
	-e SDK_ARCH=$(SDK_ARCH) \
	-v "$(CURDIR)":/src:ro \
	-v $(SDK_VOLUME):/work \
	$(BUILDER_IMAGE)

.PHONY: builder volume sdk-config sdk sdk-make copy-sdk image shell manifest \
	smoke smoke-leaf check-xylem clean clean-sdk-volume help

builder:
	docker build -q --platform linux/$(SDK_ARCH) -t $(BUILDER_IMAGE) docker

# Created owned by root; the build runs as uid 1000
volume:
	docker volume create $(SDK_VOLUME) >/dev/null
	docker run --rm -v $(SDK_VOLUME):/work --user root $(BUILDER_IMAGE) chown 1000:1000 /work

# Merge xylem's toolchain lines with Leaf's library set and check the result
sdk-config: builder volume
	$(BUILDER_RUN) sh /src/scripts/build-sdk.sh config

# The SDK tarball for linux/$(SDK_ARCH), into dist/
sdk: builder volume
	$(BUILDER_RUN) sh /src/scripts/build-sdk.sh
	$(MAKE) copy-sdk

# Any Buildroot target in the configured tree: make sdk-make T="sdl2-rebuild"
sdk-make: builder volume
	$(BUILDER_RUN) sh /src/scripts/build-sdk.sh $(T)

copy-sdk:
	mkdir -p dist
	docker run --rm -v $(SDK_VOLUME):/work -v "$(CURDIR)/dist":/out --user root $(BUILDER_IMAGE) sh -c '\
		set -e; for f in xylem-sdk-linux-$(SDK_ARCH).tar.gz xylem-sdk-linux-$(SDK_ARCH).txt; do \
		cp /work/dist/$$f /out/$$f.part; chown $(shell id -u):$(shell id -g) /out/$$f.part; mv /out/$$f.part /out/$$f; done'
	@ls -l dist

image:
	@test -f dist/xylem-sdk-linux-$(SDK_ARCH).tar.gz || { echo "no SDK in dist/: run make sdk first" >&2; exit 1; }
	docker build --platform linux/$(SDK_ARCH) -t $(LOCAL_IMAGE) .
	@docker image inspect --format 'image $(LOCAL_IMAGE) is {{.Id}}' $(LOCAL_IMAGE)

shell:
	docker run -it --rm -v "$(WORKSPACE_ROOT)":/workspace -w /workspace $(LOCAL_IMAGE) bash

# What the image's SDK contains, from inside the image
manifest:
	docker run --rm $(LOCAL_IMAGE) sh /opt/xylem-toolchain/share/xylem-toolchain/sdk-manifest.sh /opt/xylem-toolchain

# Link a program against every library in the set, and check what it needs
smoke:
	docker run --rm -v "$(CURDIR)":/src -w /src/examples/smoke $(LOCAL_IMAGE) make clean all check

# Build Catastrophe's examples and Jawaka's mlp1 build from clean exports
# of the sibling checkouts (see scripts/smoke-leaf.sh)
smoke-leaf:
	WORKSPACE_ROOT="$(WORKSPACE_ROOT)" scripts/smoke-leaf.sh

# Compare configs/xylem-base.fragment with xylem's defconfig at XYLEM_REF
# (needs gh with access to the private xylem repository)
check-xylem:
	scripts/check-xylem.sh $(XYLEM_REF)

clean:
	rm -rf dist examples/smoke/build

clean-sdk-volume:
	docker volume rm $(SDK_VOLUME) || true

help:
	@echo "xylem toolchain targets"
	@echo ""
	@echo "  make sdk-config   Merge and check the Buildroot config only"
	@echo "  make sdk          Build the SDK tarball for linux/$(SDK_ARCH) into dist/"
	@echo "  make image        Build $(LOCAL_IMAGE) from dist/"
	@echo "  make smoke        Link the smoke program against every library"
	@echo "  make smoke-leaf   Build Catastrophe and Jawaka (mlp1) against the image"
	@echo "  make manifest     Print the image's versions"
	@echo "  make shell        A shell in the image, the workspace at /workspace"
	@echo "  make check-xylem  Compare the toolchain lines with xylem at $(XYLEM_REF)"
	@echo "  make clean-sdk-volume"
	@echo "                    Remove the build volume $(SDK_VOLUME)"
