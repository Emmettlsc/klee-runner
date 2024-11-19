# Use a pre-built KLEE Docker image
FROM klee/klee:latest

# Ensure root privileges for required commands
USER root

# Install dependencies for wllvm
RUN apt-get update && apt-get install -y \
    python3-pip \
    gawk && \
    pip3 install wllvm

# Set environment variables for wllvm
ENV LLVM_COMPILER=clang
ENV LLVM_CONFIG=/usr/lib/llvm-11/bin/llvm-config

# Download and extract Coreutils 8.32
RUN wget http://ftp.gnu.org/gnu/coreutils/coreutils-8.32.tar.gz && \
    tar -xzf coreutils-8.32.tar.gz && \
    mv coreutils-8.32 /coreutils-8.32 && \
    rm coreutils-8.32.tar.gz

# Build Coreutils with gcov (Step 1)
RUN cd /coreutils-8.32 && \
    mkdir obj-gcov && cd obj-gcov && \
    FORCE_UNSAFE_CONFIGURE=1 ../configure --disable-nls CFLAGS="-g -fprofile-arcs -ftest-coverage" && \
    make -j$(nproc)

# Build Coreutils with LLVM (Step 3)
RUN cd /coreutils-8.32 && \
    mkdir obj-llvm && cd obj-llvm && \
    CC=wllvm FORCE_UNSAFE_CONFIGURE=1 ../configure --disable-nls CFLAGS="-g -O1 -Xclang -disable-llvm-passes -D__NO_STRING_INLINES -D_FORTIFY_SOURCE=0 -U__OPTIMIZE__" && \
    make -j$(nproc) && \
    cd src && \
    find . -executable -type f | xargs -I '{}' extract-bc '{}'

# Switch back to the original user for security
USER klee

CMD ["/bin/bash"]
