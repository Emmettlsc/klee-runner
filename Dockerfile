# Use a pre-built KLEE Docker image
FROM klee/klee:latest

# Ensure root privileges for required commands
USER root

# Download and extract Coreutils 6.11
RUN wget http://ftp.gnu.org/gnu/coreutils/coreutils-6.11.tar.gz && \
    tar -xzf coreutils-6.11.tar.gz && \
    mv coreutils-6.11 /coreutils-6.11 && \
    rm coreutils-6.11.tar.gz

# Download and apply the patch for glibc-2.28 compatibility
RUN wget -O /coreutils-6.11-on-glibc-2.28.diff https://github.com/coreutils/coreutils/tree/master/scripts/build-older-versions/coreutils-6.11-on-glibc-2.28.diff && \
    cd /coreutils-6.11 && \
    patch -p1 < /coreutils-6.11-on-glibc-2.28.diff

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

# Switch back to the original user for security
USER klee

CMD ["/bin/bash"]
