# Use a pre-built KLEE Docker image
FROM klee/klee:latest

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

CMD ["/bin/bash"]
