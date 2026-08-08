FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       bc bison build-essential ca-certificates cpio device-tree-compiler \
       flex gcc-arm-linux-gnueabi git libelf-dev libncurses-dev libssl-dev \
       perl python3 rsync u-boot-tools xz-utils \
    && rm -rf /var/lib/apt/lists/*

COPY build.sh /usr/local/bin/rk3066-mainline-build

ENTRYPOINT ["sh", "/usr/local/bin/rk3066-mainline-build"]
