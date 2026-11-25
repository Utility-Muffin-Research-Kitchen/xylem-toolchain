# The SDK build host: the same Debian xylem builds on (xylem docker/Dockerfile),
# pinned by the same digest, with what Buildroot asks of a host. Buildroot
# builds its own cross-compiler and host tools from source; they link against
# this Debian's glibc (2.36), so the published image (../Dockerfile) starts
# from the same digest.
FROM debian@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251

RUN apt-get update && apt-get install -y --no-install-recommends \
        bc bison build-essential ca-certificates cpio file flex git \
        libncurses-dev libssl-dev patch perl python3 rsync unzip wget \
        bzip2 gzip xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Buildroot's host packages refuse to configure as root
RUN useradd -m -u 1000 builder
USER builder
WORKDIR /work
