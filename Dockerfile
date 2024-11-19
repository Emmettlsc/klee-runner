# Base image with Ubuntu 20.04
FROM ubuntu:20.04

# Avoid interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive

# Install necessary packages
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    clang-11 \
    llvm-11 \
    llvm-11-dev \
    llvm-11-tools \
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
    autopoint \
    libtool \
    libboost-all-dev \
    libtcmalloc-minimal4 \
    libgoogle-perftools-dev \
    libc6-dev \
    libncurses5-dev \
    libncursesw5-dev \
    bison \
    flex \
    curl \
    unzip

# Set LLVM variables
ENV LLVM_VERSION=11
ENV LLVM_DIR=/usr/lib/llvm-${LLVM_VERSION}
ENV LLVM_COMPILER=clang

# Update PATH and LD_LIBRARY_PATH
ENV PATH="${LLVM_DIR}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${LLVM_DIR}/lib:${LD_LIBRARY_PATH}"
ENV CC=clang-${LLVM_VERSION}
ENV CXX=clang++-${LLVM_VERSION}

# Install WLLVM
RUN pip3 install --upgrade wllvm

# Install STP solver
RUN git clone https://github.com/stp/stp.git /stp && \
    cd /stp && \
    mkdir build && cd build && \
    cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local \
             -DCMAKE_BUILD_TYPE=Release \
             -DENABLE_PYTHON_INTERFACE=OFF && \
    make -j$(nproc) && make install

# Install KLEE-uClibc
RUN git clone https://github.com/klee/klee-uclibc.git /klee-uclibc && \
    cd /klee-uclibc && \
    ./configure --make-llvm-lib && \
    make -j$(nproc)

# Install KLEE
RUN git clone https://github.com/klee/klee.git /klee && \
    cd /klee && \
    mkdir build && cd build && \
    cmake .. \
        -DENABLE_SOLVER_STP=ON \
        -DENABLE_POSIX_RUNTIME=ON \
        -DENABLE_KLEE_UCLIBC=ON \
        -DKLEE_UCLIBC_PATH=/klee-uclibc \
        -DLLVM_CONFIG_BINARY=${LLVM_DIR}/bin/llvm-config \
        -DENABLE_UNIT_TESTS=OFF \
        -DENABLE_SYSTEM_TESTS=OFF \
        -DCMAKE_BUILD_TYPE=Release && \
    make -j$(nproc) && make install

# Update PATH for KLEE
ENV PATH="/klee/build/bin:${PATH}"
ENV LD_LIBRARY_PATH="/klee/build/lib:${LD_LIBRARY_PATH}"

# Download and extract Coreutils 6.11
RUN wget http://ftp.gnu.org/gnu/coreutils/coreutils-6.11.tar.gz && \
    tar -xzf coreutils-6.11.tar.gz && \
    rm coreutils-6.11.tar.gz

# Build Coreutils with gcov (Step 1)
RUN cd /coreutils-6.11 && \
    mkdir obj-gcov && cd obj-gcov && \
    ../configure --disable-nls CFLAGS="-g -fprofile-arcs -ftest-coverage" && \
    make -j$(nproc) && \
    make -C src arch hostname

# Build Coreutils with LLVM (Step 3)
RUN cd /coreutils-6.11 && \
    mkdir obj-llvm && cd obj-llvm && \
    CC=wllvm ../configure --disable-nls CFLAGS="-g -O1 -Xclang -disable-llvm-passes -D__NO_STRING_INLINES -D_FORTIFY_SOURCE=0 -U__OPTIMIZE__" && \
    make -j$(nproc) && \
    make -C src arch hostname && \
    cd src && \
    find . -executable -type f | xargs -I '{}' extract-bc '{}'

# Set default command to run a shell
CMD ["/bin/bash"]
