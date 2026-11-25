# The published xylem toolchain image: the SDK from dist/ on the same Debian
# it was built on (docker/Dockerfile), since Buildroot's host tools link
# against the build host's glibc.
FROM debian@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251

ARG TARGETARCH

COPY scripts/apt-install-retry.sh /usr/local/bin/apt-install-retry.sh

RUN bash /usr/local/bin/apt-install-retry.sh \
    bash \
    ca-certificates \
    cmake \
    curl \
    file \
    git \
    make \
    ninja-build \
    patch \
    pkg-config \
    python3 \
    rsync \
    unzip \
    vim \
    wget \
    xz-utils

ENV TOOLCHAIN_DIR=/opt/xylem-toolchain
COPY dist/xylem-sdk-linux-${TARGETARCH}.tar.gz /tmp/xylem-sdk.tar.gz

RUN mkdir -p "${TOOLCHAIN_DIR}" \
    && tar -xzf /tmp/xylem-sdk.tar.gz -C "${TOOLCHAIN_DIR}" \
    && rm -f /tmp/xylem-sdk.tar.gz \
    && "${TOOLCHAIN_DIR}/relocate-sdk.sh"

ENV CROSS_TRIPLE=aarch64-buildroot-linux-gnu
ENV CROSS_ROOT=${TOOLCHAIN_DIR}
ENV SYSROOT=${TOOLCHAIN_DIR}/${CROSS_TRIPLE}/sysroot

ENV AS=${TOOLCHAIN_DIR}/bin/${CROSS_TRIPLE}-as \
    AR=${TOOLCHAIN_DIR}/bin/${CROSS_TRIPLE}-ar \
    CC=${TOOLCHAIN_DIR}/bin/${CROSS_TRIPLE}-gcc \
    CPP=${TOOLCHAIN_DIR}/bin/${CROSS_TRIPLE}-cpp \
    CXX=${TOOLCHAIN_DIR}/bin/${CROSS_TRIPLE}-g++ \
    LD=${TOOLCHAIN_DIR}/bin/${CROSS_TRIPLE}-ld \
    NM=${TOOLCHAIN_DIR}/bin/${CROSS_TRIPLE}-nm \
    OBJCOPY=${TOOLCHAIN_DIR}/bin/${CROSS_TRIPLE}-objcopy \
    RANLIB=${TOOLCHAIN_DIR}/bin/${CROSS_TRIPLE}-ranlib \
    STRIP=${TOOLCHAIN_DIR}/bin/${CROSS_TRIPLE}-strip \
    READELF=${TOOLCHAIN_DIR}/bin/${CROSS_TRIPLE}-readelf

# The SDK's bin first: its pkg-config is Buildroot's pkgconf wrapper, which
# looks in the sysroot, and wayland-scanner is the host build of the same
# Wayland the sysroot has
ENV PATH=${TOOLCHAIN_DIR}/bin:${PATH}
ENV CROSS_COMPILE=${CROSS_TRIPLE}-
ENV PREFIX=${SYSROOT}/usr
ENV ARCH=aarch64
ENV PKG_CONFIG_SYSROOT_DIR=${SYSROOT}
ENV PKG_CONFIG_PATH=${SYSROOT}/usr/lib/pkgconfig:${SYSROOT}/usr/share/pkgconfig
ENV CMAKE_TOOLCHAIN_FILE=${TOOLCHAIN_DIR}/Toolchain.cmake
# Which OS the binaries are for. No UNION_PLATFORM: one xylem SDK serves
# every RK356x board (MLP1, RG DS Plus); the board is the build's choice.
ENV UMRK_TARGET_OS=xylem
ENV PREFIX_LOCAL=/opt/umrk

COPY toolchain-aarch64.cmake ${TOOLCHAIN_DIR}/Toolchain.cmake
COPY xylem.ref scripts/sdk-manifest.sh scripts/verify-binary.sh ${TOOLCHAIN_DIR}/share/xylem-toolchain/

RUN mkdir -p "${PREFIX_LOCAL}/include" "${PREFIX_LOCAL}/lib"

VOLUME /root/workspace
WORKDIR /root/workspace
