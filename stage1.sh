#!/bin/bash
#
# Build the environment which will be used to build the full OS later.
set -e
# Disabling hashing is useful so the newly built tools are detected.
set +h
# Ensure retrieve-sources.sh has been run first.
if [ ! -d sources ]; then
  echo "Error: You must run retrieve-sources.sh first!" >&2
  exit 1
fi
# Starting message.
echo "Starting Stage 1 Build..."
# Setup the environment.
ORCHANIXOS="$PWD"/orchanixos-rootfs
PATH="$ORCHANIXOS"/tools/bin:$PATH
SRC="$ORCHANIXOS"/sources
export ORCHANIXOS ORCHANIXOS_TARGET PATH SRC
# Build in parallel using all available CPU cores.
export MAKEFLAGS="-j$(nproc)"
# Compiler flags for OrchanixOS. We prefer to optimise for size.
CFLAGS="-O2 -pipe"
CXXFLAGS="-O2 -pipe"
CPPFLAGS=""
LDFLAGS=""
export CFLAGS CXXFLAGS CPPFLAGS LDFLAGS
# Add versioning file:
. package-versions.conf
# Setup the basic filesystem structure.
mkdir -p "$ORCHANIXOS"/{etc,var}
mkdir -p "$ORCHANIXOS"/usr/{bin,lib,sbin}
# Ensure the filesystem structure is unified.
ln -sf usr/bin "$ORCHANIXOS"/bin
ln -sf usr/lib "$ORCHANIXOS"/lib
ln -sf usr/sbin "$ORCHANIXOS"/sbin
ln -sf lib "$ORCHANIXOS"/usr/lib64
ln -sf usr/lib "$ORCHANIXOS"/lib64
# Directory where source tarballs will be placed while building.
# Temporary toolchain directory.
mkdir "$ORCHANIXOS"/tools
# Move sources into the temporary environment.
mv sources "$SRC"
# Copy patches into the temporary environment.
mkdir -p "$SRC"/patches
cp patches/* "$SRC"/patches
# Copy patches into the temporary environment.
mkdir -p "$SRC"/logo
cp logo/* "$SRC"/logo
# Copy systemd units into the temporary environment.
cp -r utils/systemd-units "$SRC"
# Change to the sources directory.
cd "$SRC"
# Binutils (Initial build for bootstrapping).
tar -xf binutils-${binutils}
cd binutils-${binutils}
mkdir build; cd build
../configure --prefix="$ORCHANIXOS"/tools --with-sysroot="$ORCHANIXOS" --target=x86_64-stage1-linux-gnu --with-pkgversion="OrchanixOS Binutils ${binutils}" --enable-relro --disable-gprofng --disable-nls --disable-werror
make
make -j1 install
cd ../..
rm -rf binutils-${binutils}
# GCC (Initial build for bootstrapping).
tar -xf gcc-${gcc}.tar.xz
cd gcc-${gcc}
mkdir -p gmp mpfr mpc isl
tar -xf ../gmp-${gmp}.tar.xz -C gmp --strip-components=1
tar -xf ../mpfr-${mpfr}.tar.xz -C mpfr --strip-components=1
tar -xf ../mpc-${mpc}.tar.gz -C mpc --strip-components=1
tar -xf ../isl-${isl}.tar.xz -C isl --strip-components=1
sed -i '/m64=/s/lib64/lib/' gcc/config/i386/t-linux64
mkdir build; cd build
../configure --prefix="$ORCHANIXOS"/tools --target=x86_64-stage1-linux-gnu --enable-languages=c,c++ --with-pkgversion="OrchanixOS GCC ${gcc}" --with-glibc-version=2.36 --with-sysroot="$ORCHANIXOS" --with-newlib --without-headers --enable-default-ssp --enable-linker-build-id --disable-decimal-float --disable-libatomic --disable-libgomp --disable-libquadmath --disable-libssp --disable-libstdcxx --disable-libvtv --disable-multilib --disable-nls --disable-shared --disable-threads
make
make install
cat ../gcc/{limitx,glimits,limity}.h > "$ORCHANIXOS"/tools/lib/gcc/x86_64-stage1-linux-gnu/${gcc}/install-tools/include/limits.h
cd ../..
rm -rf gcc-${gcc}
# Linux API Headers.
tar -xf linux-${linux}.tar.xz
cd linux-${linux}
make headers
find usr/include -name '.*' -delete
rm -f usr/include/Makefile
cp -r usr/include "$ORCHANIXOS"/usr
cd ..
rm -rf linux-${linux}
# Glibc
tar -xf glibc-${glibc}.tar.xz
cd glibc-2.36
patch -Np1 -i ../patches/glibc-${glibc}-multiplefixes.patch
mkdir build; cd build
echo "rootsbindir=/usr/sbin" > configparms
../configure --prefix=/usr --host=x86_64-stage1-linux-gnu --build=$(../scripts/config.guess) --enable-kernel=3.2 --disable-default-pie --with-headers="$ORCHANIXOS"/usr/include libc_cv_slibdir=/usr/lib
make
make DESTDIR="$ORCHANIXOS" install
ln -sf ld-linux-x86-64.so.2 "$ORCHANIXOS"/usr/lib/ld-lsb-x86-64.so.3
sed '/RTLDLIST=/s@/usr@@g' -i "$ORCHANIXOS"/usr/bin/ldd
"$ORCHANIXOS"/tools/libexec/gcc/x86_64-stage1-linux-gnu/$(x86_64-stage1-linux-gnu-gcc -dumpversion)/install-tools/mkheaders
cd ../..
rm -rf glibc-${glibc}
# libstdc++ from GCC (Could not be built with bootstrap GCC).
tar -xf gcc-${gcc}.tar.xz
cd gcc-${gcc}
mkdir build; cd build
../libstdc++-v3/configure --prefix=/usr --host=x86_64-stage1-linux-gnu --build=$(../config.guess) --disable-multilib --disable-nls --disable-libstdcxx-pch --with-gxx-include-dir=/tools/x86_64-stage1-linux-gnu/include/c++/$(x86_64-stage1-linux-gnu-gcc -dumpversion)
make
make DESTDIR="$ORCHANIXOS" install
cd ../..
rm -rf gcc-${gcc}
# Ncurses.
tar -xf ncurses-${ncurses}.tar.gz
cd ncurses-${ncurses}
sed -i 's/mawk//' configure
mkdir build; cd build
../configure
make -C include
make -C progs tic
cd ..
./configure --prefix=/usr --host=x86_64-stage1-linux-gnu --build=$(./config.guess) --mandir=/usr/share/man --with-cxx-shared --with-manpage-format=normal --with-shared --without-ada --without-debug --without-normal --enable-widec --disable-stripping
make
make DESTDIR="$ORCHANIXOS" TIC_PATH=$(pwd)/build/progs/tic install
echo "INPUT(-lncursesw)" > "$ORCHANIXOS"/usr/lib/libncurses.so
cd ..
rm -rf ncurses-${ncurses}
# Bash.
tar -xf bash-${bash}.tar.gz
cd bash-${bash}
patch -Np0 -i ../patches/bash-${bash}-upstreamfix.patch
./configure --prefix=/usr --host=x86_64-stage1-linux-gnu --build=$(support/config.guess) --without-bash-malloc
make
make DESTDIR="$ORCHANIXOS" install
ln -sf bash "$ORCHANIXOS"/bin/sh
cd ..
rm -rf bash-${bash}
# Binutils (For stage 2, built using our new bootstrap toolchain).
tar -xf binutils-${binutils}.tar.xz
cd binutils-${binutils}
sed -i '6009s/$add_dir//' ltmain.sh
mkdir build; cd build
../configure --prefix=/usr --host=x86_64-stage1-linux-gnu --build=$(../config.guess) --with-pkgversion="OrchanixOS Binutils ${binutils}" --enable-relro --enable-shared --disable-gprofng --disable-nls --disable-werror
make
make -j1 DESTDIR="$ORCHANIXOS" install
cd ../..
rm -rf binutils-${binutils}
# GCC (For stage 2, built using our new bootstrap toolchain).
tar -xf gcc-${gcc}.tar.xz
cd gcc-${gcc}
mkdir -p gmp mpfr mpc isl
tar -xf ../gmp-${gmp}.tar.xz -C gmp --strip-components=1
tar -xf ../mpfr-${mpfr}.tar.xz -C mpfr --strip-components=1
tar -xf ../mpc-${mpc}.tar.gz -C mpc --strip-components=1
tar -xf ../isl-${isl}.tar.xz -C isl --strip-components=1
sed -i '/m64=/s/lib64/lib/' gcc/config/i386/t-linux64
sed -i '/thread_header =/s/@.*@/gthr-posix.h/' libgcc/Makefile.in libstdc++-v3/include/Makefile.in
mkdir build; cd build
../configure --prefix=/usr --host=x86_64-stage1-linux-gnu --build=$(../config.guess) --target=x86_64-stage1-linux-gnu LDFLAGS_FOR_TARGET=-L"$PWD/x86_64-stage1-linux-gnu/libgcc" --with-build-sysroot="$ORCHANIXOS" --enable-languages=c,c++ --with-pkgversion="OrchanixOS GCC ${gcc}" --enable-default-ssp --enable-initfini-array --enable-linker-build-id --disable-nls --disable-multilib --disable-decimal-float --disable-libatomic --disable-libgomp --disable-libquadmath --disable-libssp --disable-libvtv
make
make DESTDIR="$ORCHANIXOS" install
ln -sf gcc "$ORCHANIXOS"/usr/bin/cc
cd ../..
rm -rf gcc-${gcc}
# Install upgrade-toolset to provide basic utilities for the start of stage 2.
mv "${ORCHANIXOS}"/usr/bin/bash{,.save}
tar -xf upgrade-toolset-20221015-x86_64.tar.xz -C "$ORCHANIXOS"/usr/bin --strip-components=1
mv "${ORCHANIXOS}"/usr/bin/bash{.save,}
rm -f "$ORCHANIXOS"/usr/bin/LICENSE*
cd ../..
# Remove bootstrap toolchain directory.
rm -rf "$ORCHANIXOS"/tools
# Remove temporary system documentation.
rm -rf "$ORCHANIXOS"/usr/share/{info,man,doc}/*
# Copy extra utilities and configuration files into the environment.
cp -r utils/etc/* "$ORCHANIXOS"/etc
cp utils/orchanixos-release "$ORCHANIXOS"/etc
cp utils/programs/{adduser,orchanixos-chroot,mkinitramfs,mklocales,set-default-tar} "$ORCHANIXOS"/usr/sbin
cp utils/programs/{un,}zman "$ORCHANIXOS"/usr/bin
cp utils/programs/orchanixos-release.c "$SRC"
cp -r utils/build-configs/* "$SRC"
cp -r logo/* "$SRC"
cp -r utils/extra-package-licenses "$SRC"
cp -r backgrounds "$SRC"
cp -r utils/man "$SRC"
cp LICENSE "$SRC"
cp build-system.sh build.env "$SRC"
echo -e "\nThe Stage 1 bootstrap system was built successfully."
echo "To build the full OrchanixOS system, now run './stage2.sh' AS ROOT."
