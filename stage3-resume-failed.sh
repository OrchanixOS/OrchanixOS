#!/bin/bash
#
# Prepare the environment for building a desktop environment.
set -e
# Ensure we're running as root.
if [ $EUID -ne 0 ]; then
  echo "Error: Must be run as root." >&2
  exit 1
fi
# Setup the environment.
export ORCHANIXOS="$PWD"/orchanixos-rootfs
# Ensure stage1 has been run first.
if [ ! -d "$ORCHANIXOS" ]; then
  echo "Error: You must run stage1.sh and stage2.sh first!" >&2
  exit 1
fi
# Ensure the specified desktop environment is valid.
if [ -z "$1" ]; then
  echo "Error: Specify the desktop environment ('stage3/README' for info)." >&2
  exit 1
fi
if [ ! -d "stage3/$1" ]; then
  echo "Error: '$1' is not a valid or supported desktop environment." >&2
  echo "The desktop environment must have a directory in 'stage3/'." >&2
  echo "Alternatively, pass 'nodesktop' if you want a core only build." >&2
  echo "See 'stage3/README' for more information." >&2
  exit 1
fi
if [ ! -e "stage3/$1/stage3-$1.sh" ]; then
  echo "Stage 3 directory for '$1' was found, but there is no Stage 3" >&2
  echo "build script inside it." >&2
  exit 1
fi
# Important verification message.
if [ "$2" != "CONFIRM_STAGE3_RESUME=YES" ]; then
  echo "Please edit 'orchanixos-rootfs/sources/build-stage3.sh' as root and" >&2
  echo "remove lines 18 up to where your build failed. Otherwise, it will" >&2
  echo "try to rebuild the whole system from the start, which WILL cause" >&2
  echo "issues if the system is already part-built." >&2
  echo -e "\nOnce you've done that, re-run this script like this:" >&2
  echo -e "\n$0 $1 CONFIRM_STAGE3_RESUME=YES" >&2
  exit 1
fi
# Put Stage 3 files into the system.
echo "Trying to resume Stage 3 build for '$1'..."
# Re-enter the chroot and continue the build.
utils/programs/orchanixos-chroot "$ORCHANIXOS" /sources/build-stage3.sh
# Put in finalize.sh and finish the build.
echo "Finalizing the build..."
cp finalize.sh "$ORCHANIXOS"/sources
utils/programs/orchanixos-chroot "$ORCHANIXOS" /sources/finalize.sh
# Install preupgrade and postupgrade.
cp utils/{pre,post}upgrade "$ORCHANIXOS"/tmp
# Strip executables and libraries to free up space.
printf "Stripping binaries and libraries... "
find "$ORCHANIXOS"/usr/{bin,lib,libexec,sbin} -type f -not -name \*.a -and -not -name \*.o -and -not -name \*.mod -and -not -name \*.module -exec strip --strip-unneeded {} ';' &> /dev/null || true
find "$ORCHANIXOS"/usr/lib -type f -name \*.a -or -name \*.o -or -name \*.mod -or -name \*.module -exec strip --strip-debug {} ';' &>/dev/null || true
echo "Done!"
# Finish the OrchanixOS system.
outfile="orchanixos-$(cat utils/orchanixos-release)-rootfs-x86_64-$1.tar"
printf "Creating $outfile... "
cd "$ORCHANIXOS"
tar -cpf ../"$outfile" *
cd ..
echo "Done!"
echo "Compressing $outfile with XZ (using $(nproc) threads)..."
xz -v --threads=$(nproc) "$outfile"
echo "Successfully created $outfile.xz."
printf "SHA256 checksum for this build: "
sha256sum $outfile.xz | sed "s/  $outfile.xz//"
# Clean up.
rm -rf "$ORCHANIXOS"
# Finishing message.
echo
echo "We know it took time, but the build has finally finished successfully!"
echo "If you want to create a Live ISO file for your build, check out the"
echo "scripts at <https://github.com/OrchanixOS/livecd-installer>."
