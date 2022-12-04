#!/bin/bash
#
# Prepare the environment for building the full OrchanixOS system.
set -e
# Ensure we're running as root.
if [ $EUID -ne 0 ]; then
  echo "Error: Must be run as root." >&2
  exit 1
fi
# Setup the environment.
export ORCHANIXOS="$PWD"/orchanixos-rootfs
# Ensure stage1 has been run first.
if [ ! -e "$ORCHANIXOS"/sources/build-system.sh ]; then
  echo "Error: You must run stage1.sh first!" >&2
  exit 1
fi
# Ensure this is not resuming a failed build.
if [ -e "$ORCHANIXOS"/sources/.BUILD_HAS_STARTED ]; then
  echo "Error: The previous stage 2 build failed or was interrupted." >&2
  echo "Please use stage2-resume-failed.sh to attempt resuming it." >&2
  exit 1
fi
# Ensure the OrchanixOS environment is owned by root.
chown -R root:root "$ORCHANIXOS"
# Create pseudo-filesystem mount directories.
mkdir -p "$ORCHANIXOS"/{dev,proc,sys,run}
# Initialise /dev/console and /dev/null.
mknod -m 600 "$ORCHANIXOS"/dev/console c 5 1
mknod -m 666 "$ORCHANIXOS"/dev/null c 1 3
# Chroot into the OrchanixOS environment and start the stage 2 build.
utils/programs/orchanixos-chroot "$ORCHANIXOS" /sources/build-system.sh
# Finishing message.
echo
echo "Stage 2 build completed successfully."
echo "You must now run stage3.sh and pass a supported desktop environment as"
echo "an argument. See 'stage3/README' for more information."
