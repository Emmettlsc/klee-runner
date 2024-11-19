# Use a pre-built KLEE Docker image
FROM klee/klee:latest

# Ensure root privileges for required commands
USER root

# Install dependencies for wllvm and git
RUN apt-get update && apt-get install -y \
    python3-pip \
    gawk \
    git && \
    pip3 install wllvm

# Set environment variables for wllvm
ENV LLVM_COMPILER=clang
ENV LLVM_CONFIG=$(which llvm-config)

# Build arguments for repository URL and branch
ARG REPO_URL=https://github.com/Emmettlsc/coreutils-klee-demo-bad.git
ARG REPO_BRANCH=main

# Clone your repository
RUN git clone --depth 1 --branch $REPO_BRANCH $REPO_URL /coreutils

# Build Coreutils with gcov (Step 1)
RUN cd /coreutils && \
    mkdir obj-gcov && cd obj-gcov && \
    FORCE_UNSAFE_CONFIGURE=1 ../configure --disable-nls \
    CFLAGS="-g -fprofile-arcs -ftest-coverage" && \
    make -j$(nproc)

# Build Coreutils with LLVM (Step 2)
RUN cd /coreutils && \
    mkdir obj-llvm && cd obj-llvm && \
    CC=wllvm FORCE_UNSAFE_CONFIGURE=1 ../configure --disable-nls \
    CFLAGS="-g -O1 -Xclang -disable-llvm-passes -D__NO_STRING_INLINES \
    -D_FORTIFY_SOURCE=0 -U__OPTIMIZE__" && \
    make -j$(nproc) && \
    cd src && \
    find . -executable -type f -exec extract-bc '{}' \;

# Switch back to the original user for security
USER klee

CMD ["/bin/bash"]
