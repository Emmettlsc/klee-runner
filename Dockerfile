# Base image with Ubuntu
FROM ubuntu:20.04


ENV DEBIAN_FRONTEND=noninteractive
# Set timezone environment variables for non-interactive installation
RUN apt-get update && apt-get install -y \
    tzdata \
    build-essential \
    cmake \
    clang \
    llvm \
    llvm-dev \
    libz3-dev \
    libcap-dev \
    python3 \
    python3-pip \
    git \
    wget \
    zlib1g-dev \
    libsqlite3-dev \
    gcc \
    autoconf \
    automake \
    texinfo \
    gettext \
    kcachegrind \
    emacs \
    libboost-all-dev \
    libtcmalloc-minimal4 \
    libgoogle-perftools-dev \
    libc6-dev \
    linux-headers-generic && \
    ln -fs /usr/share/zoneinfo/Etc/UTC /etc/localtime && \
    dpkg-reconfigure --frontend noninteractive tzdata

# Install WLLVM for compiling to LLVM bitcode
RUN pip3 install --upgrade wllvm

# Set WLLVM environment variables
ENV LLVM_COMPILER=clang

# Install uclibc for KLEE
RUN git clone https://github.com/klee/klee-uclibc.git /klee-uclibc && \
    cd /klee-uclibc && \
    ./configure --make-llvm-lib && make -j$(nproc)

# Clone and build KLEE (separated for better caching)
RUN git clone https://github.com/klee/klee.git /klee
RUN cd /klee && \
    mkdir build && cd build && \
    cmake -DENABLE_SOLVERS=STP -DENABLE_POSIX_RUNTIME=ON -DENABLE_UNIT_TESTS=OFF -DENABLE_SYSTEM_TESTS=OFF -DKLEE_FORCE_64BIT=ON .. && \
    make -j$(nproc) VERBOSE=1 && make install

# Set environment variables for KLEE
ENV PATH="/klee/build/bin:$PATH"
ENV LD_LIBRARY_PATH="/klee/build/lib:$LD_LIBRARY_PATH"

# Clone GNU Coreutils 6.11
RUN git clone https://github.com/coreutils/coreutils.git /coreutils && \
    cd /coreutils && git checkout v6.11

# Set working directory to Coreutils
WORKDIR /coreutils
