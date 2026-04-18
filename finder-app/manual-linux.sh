#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.

set -e
set -u

OUTDIR=/tmp/aeld
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.15.163
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-none-linux-gnu-

# -------------------------------
# Handle outdir argument
# -------------------------------
if [ $# -lt 1 ]
then
    echo "Using default directory ${OUTDIR} for output"
else
    OUTDIR=$1
    echo "Using passed directory ${OUTDIR} for output"
fi

mkdir -p ${OUTDIR}

# -------------------------------
# Clone Linux kernel if missing
# -------------------------------
cd "$OUTDIR"
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
    git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi

# -------------------------------
# Build the kernel
# -------------------------------
if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}

    echo "Building kernel..."
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} mrproper
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig
    make -j4 ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} all
fi

echo "Adding the Image in outdir"
cp ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ${OUTDIR}

# -------------------------------
# Create rootfs
# -------------------------------
echo "Creating the staging directory for the root filesystem"
cd "$OUTDIR"
if [ -d "${OUTDIR}/rootfs" ]
then
    echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
    sudo rm -rf ${OUTDIR}/rootfs
fi

mkdir -p rootfs
cd rootfs
mkdir -p bin dev etc home lib lib64 proc sbin sys tmp usr var
mkdir -p usr/bin usr/lib usr/sbin

# -------------------------------
# Build BusyBox
# -------------------------------
cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]
then
    git clone git://busybox.net/busybox.git
    cd busybox
    git checkout ${BUSYBOX_VERSION}

    make distclean
    make defconfig
else
    cd busybox
fi

echo "Building and installing BusyBox..."
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE}
make CONFIG_PREFIX=${OUTDIR}/rootfs ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} install

# -------------------------------
# Library dependencies
# -------------------------------
echo "Library dependencies"
cd ${OUTDIR}/rootfs
${CROSS_COMPILE}readelf -a bin/busybox | grep "program interpreter"
${CROSS_COMPILE}readelf -a bin/busybox | grep "Shared library"

SYSROOT=$(${CROSS_COMPILE}gcc --print-sysroot)

echo "Copying library dependencies..."
cp -a ${SYSROOT}/lib/ld-linux-aarch64.so.1 lib/
cp -a ${SYSROOT}/lib64/libm.so.6 lib64/
cp -a ${SYSROOT}/lib64/libresolv.so.2 lib64/
cp -a ${SYSROOT}/lib64/libc.so.6 lib64/

# -------------------------------
# Device nodes
# -------------------------------
echo "Creating device nodes..."
sudo mknod -m 666 dev/null c 1 3
sudo mknod -m 600 dev/console c 5 1

# -------------------------------
# Build writer (cross-compile)
# -------------------------------
echo "Building writer utility..."
cd ${FINDER_APP_DIR}
make clean
make CROSS_COMPILE=${CROSS_COMPILE}

cp writer ${OUTDIR}/rootfs/home/

# -------------------------------
# Copy finder scripts
# -------------------------------
echo "Copying finder scripts..."
cp finder.sh ${OUTDIR}/rootfs/home/
cp finder-test.sh ${OUTDIR}/rootfs/home/
cp conf/username.txt ${OUTDIR}/rootfs/home/
cp conf/assignment.txt ${OUTDIR}/rootfs/home/
cp autorun-qemu.sh ${OUTDIR}/rootfs/home/
cp ${FINDER_APP_DIR}/../conf/username.txt ${OUTDIR}/rootfs/home/

# Fix finder-test.sh path
sed -i 's|\.\./conf/assignment.txt|assignment.txt|g' ${OUTDIR}/rootfs/home/finder-test.sh

# -------------------------------
# Set ownership
# -------------------------------
echo "Setting ownership..."
sudo chown -R root:root ${OUTDIR}/rootfs

# -------------------------------
# Create initramfs
# -------------------------------
echo "Creating initramfs..."
cd ${OUTDIR}/rootfs
find . | cpio -H newc -ov --owner root:root > ${OUTDIR}/initramfs.cpio
gzip -f ${OUTDIR}/initramfs.cpio

echo "Build complete."
