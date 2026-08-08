FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       bc bison build-essential ca-certificates device-tree-compiler flex \
       gcc-arm-linux-gnueabi libelf-dev libncurses-dev libssl-dev perl \
       sharutils \
       python3 rsync \
    && rm -rf /var/lib/apt/lists/*

COPY build.sh /usr/local/bin/rk3066-linux3188-build
COPY build-components.sh /usr/local/bin/rk3066-linux3188-components
COPY compiler-gcc12.h /usr/share/rk3066-linux3188/compiler-gcc12.h

ENTRYPOINT ["sh", "/usr/local/bin/rk3066-linux3188-build"]
