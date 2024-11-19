# Base image with Ubuntu
FROM ubuntu:20.04

# Avoid interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive
ENV LLVM_COMPILER=clang

# Set timezone and install necessary packages
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

# Clone and build uClibc for KLEE
RUN git clone https://github.com/klee/klee-uclibc.git /klee-uclibc && \
    cd /klee-uclibc && \
    ./configure --make-llvm-lib && make -j$(nproc)

RUN apt-get install -y llvm-12 llvm-12-dev clang-12
ENV LLVM_CONFIG=/usr/bin/llvm-config-12
ENV PATH="/usr/lib/llvm-12/bin:$PATH"

# Clone and build KLEE
RUN git clone https://github.com/klee/klee.git /klee
RUN cd /klee && \
    mkdir build && cd build && \
    cmake -DENABLE_SOLVERS=STP -DENABLE_POSIX_RUNTIME=ON -DENABLE_UNIT_TESTS=OFF -DENABLE_SYSTEM_TESTS=OFF -DKLEE_FORCE_64BIT=ON .. && \
    make -j$(nproc) VERBOSE=1 && make install

# Add KLEE binaries to PATH
ENV PATH="/klee/build/bin:$PATH"
ENV LD_LIBRARY_PATH="/klee/build/lib:$LD_LIBRARY_PATH"

# Clone GNU Coreutils 6.11
RUN git clone https://github.com/coreutils/coreutils.git /coreutils && \
    cd /coreutils && git checkout v6.11

# Build Coreutils with gcov (Step 1)
RUN cd /coreutils && \
    autoreconf -fiv && \   # Generate the configure script
    mkdir obj-gcov && cd obj-gcov && \
    ../configure --disable-nls CFLAGS="-g -fprofile-arcs -ftest-coverage" && \
    make && \
    make -C src arch hostname

# Build Coreutils with LLVM (Step 3)
RUN mkdir obj-llvm && cd obj-llvm && \
    CC=wllvm ../configure --disable-nls CFLAGS="-g -O1 -Xclang -disable-llvm-passes -D__NO_STRING_INLINES -D_FORTIFY_SOURCE=0 -U__OPTIMIZE__" && \
    make && \
    make -C src arch hostname && \
    cd src && \
    find . -executable -type f | xargs -I '{}' extract-bc '{}'

# Set default command to run a shell
CMD ["/bin/bash"]
