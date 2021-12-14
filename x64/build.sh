#!/bin/sh
# Made by fullpwn.
# Some files were copied from odysseyn1x.

# Exit if user isn't root
[ "$(id -u)" -ne 0 ] && {
    echo 'Please run as root'
    exit 1
}

# Change these variables to modify the version of checkra1n
# If the latest version of checkra1n (at build time) is desired, leave the variables empty
CHECKRA1N_AMD64='https://assets.checkra.in/downloads/linux/cli/x86_64/dac9968939ea6e6bfbdedeb41d7e2579c4711dc2c5083f91dced66ca397dc51d/checkra1n'
CHECKRA1N_I686='https://assets.checkra.in/downloads/linux/cli/i486/77779d897bf06021824de50f08497a76878c6d9e35db7a9c82545506ceae217e/checkra1n'

if [ -z "$CHECKRA1N_AMD64" ]; then
    CHECKRA1N_AMD64=$(curl "https://checkra.in/releases/" | grep -Po "https://assets.checkra.in/downloads/linux/cli/x86_64/[0-9a-f]*/checkra1n")
fi
if [ -z "$CHECKRA1N_I686" ]; then
    CHECKRA1N_I686=$(curl "https://checkra.in/releases/" | grep -Po "https://assets.checkra.in/downloads/linux/cli/i486/[0-9a-f]*/checkra1n")
fi


GREEN="$(tput setaf 2)"
BLUE="$(tput setaf 6)"
NORMAL="$(tput sgr0)"
cat << EOF
${GREEN}############################################${NORMAL}
${GREEN}#                                          #${NORMAL}
${GREEN}#  ${BLUE}Welcome to the infinity build script  ${GREEN}#${NORMAL}
${GREEN}#                                          #${NORMAL}
${GREEN}############################################${NORMAL}

EOF
# Ask for the version and architecture if variables are empty
while [ -z "$VERSION" ]; do
    printf 'Version: '
    read -r VERSION
done
until [ "$ARCH" = 'amd64' ] || [ "$ARCH" = 'i686' ]; do
    echo '1 amd64'
    echo '2 i686'
    printf 'Which architecture? amd64 (default) or i686 '
    read -r input_arch
    [ "$input_arch" = 1 ] && ARCH='amd64'
    [ "$input_arch" = 2 ] && ARCH='i686'
    [ -z "$input_arch" ] && ARCH='amd64'
done

# Delete old build
{
    umount work/chroot/proc
    umount work/chroot/sys
    umount work/chroot/dev
} > /dev/null 2>&1
rm -rf work/

set -e -u -v -x
start_time="$(date -u +%s)"

# Install dependencies to build odysseyn1x

apt-get install -y --no-install-recommends wget debootstrap grub-pc-bin \
    grub-efi-amd64-bin mtools squashfs-tools xorriso ca-certificates curl \
    libusb-1.0-0-dev gcc make gzip xz-utils unzip libc6-dev

if [ "$ARCH" = 'amd64' ]; then
    REPO_ARCH='amd64' # Debian's 64-bit repos are "amd64"
    KERNEL_ARCH='amd64' # Debian's 32-bit kernels are suffixed "amd64"
else
    # Install depencies to build odysseyn1x for i686
    dpkg --add-architecture i386
    apt-get update
    apt install -y --no-install-recommends libusb-1.0-0-dev:i386 gcc-multilib
    REPO_ARCH='i386' # Debian's 32-bit repos are "i386"
    KERNEL_ARCH='686' # Debian's 32-bit kernels are suffixed "-686"
fi

# Configure the base system
mkdir -p work/chroot work/iso/live work/iso/boot/grub
debootstrap --variant=minbase --arch="$REPO_ARCH" stable work/chroot 'http://deb.debian.org/debian/'
mount --bind /proc work/chroot/proc
mount --bind /sys work/chroot/sys
mount --bind /dev work/chroot/dev
cp /etc/resolv.conf work/chroot/etc
cat << EOF | chroot work/chroot /bin/bash
# Set debian frontend to noninteractive
export DEBIAN_FRONTEND=noninteractive

# Install requiered packages
apt-get install -y --no-install-recommends linux-image-$KERNEL_ARCH live-boot \
  systemd systemd-sysv usbmuxd libusbmuxd-tools openssh-client sshpass xz-utils whiptail
# Remove apt as it won't be usable anymore
apt purge apt -y --allow-remove-essential
EOF
# Change initramfs compression to xz
sed -i 's/COMPRESS=gzip/COMPRESS=xz/' work/chroot/etc/initramfs-tools/initramfs.conf
chroot work/chroot update-initramfs -u
(
    cd work/chroot
    # Empty some directories to make the system smaller
    rm -f etc/mtab \
        etc/fstab \
        etc/ssh/ssh_host* \
        root/.wget-hsts \
        root/.bash_history
    rm -rf var/log/* \
        var/cache/* \
        var/backups/* \
        var/lib/apt/* \
        var/lib/dpkg/* \
        usr/share/doc/* \
        usr/share/man/* \
        usr/share/info/* \
        usr/share/icons/* \
        usr/share/locale/* \
        usr/share/zoneinfo/* \
        usr/lib/modules/*
)

# Copy scripts
cp x64/scripts/* work/chroot/usr/bin/

(
    cd work/chroot/usr/bin/
    curl -L -O 'https://github.com/fullpwn/infinity/raw/main/x64/assets/checkra1n_old'
    chmod +x checkra1n_old
)

(
    cd work/chroot/root/
    # Download resources for Android Sandcastle
    curl -L -O 'https://github.com/fullpwn/infinity/raw/main/x64/assets/android-sandcastle.zip'
    unzip android-sandcastle.zip
    rm -f android-sandcastle.zip
    (
        cd android-sandcastle/
        rm -f iproxy ./*.dylib load-linux.mac ./*.sh README.txt
    )

    # Download resources for Linux Sandcastle
    curl -L -O 'https://assets.checkra.in/downloads/sandcastle/0175ae56bcba314268d786d1239535bca245a7b126d62a767e12de48fd20f470/linux-sandcastle.zip'
    unzip linux-sandcastle.zip
    rm -f linux-sandcastle.zip
    (
        cd linux-sandcastle/
        rm -f load-linux.mac README.txt
    )
)

(
    cd work/chroot/usr/bin/
    curl -L -O 'https://raw.githubusercontent.com/corellium/projectsandcastle/master/loader/load-linux.c'
    # Build load-linux.c and download checkra1n for the corresponding architecture
    if [ "$ARCH" = 'amd64' ]; then
        gcc load-linux.c -o load-linux -lusb-1.0
        curl -L -o checkra1n "$CHECKRA1N_AMD64"
    else
        gcc -m32 load-linux.c -o load-linux -lusb-1.0
        curl -L -o checkra1n "$CHECKRA1N_I686"
    fi
    rm -f load-linux.c
    chmod +x load-linux checkra1n
)

# Configure autologin
mkdir -p work/chroot/etc/systemd/system/getty@tty1.service.d
cat << EOF > work/chroot/etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --noissue --autologin root %I
Type=idle
EOF

# Configure grub
cat << "EOF" > work/iso/boot/grub/grub.cfg
insmod all_video
echo ''
echo '  _     ___ _     _ _      '
echo ' |_|___|  _|_|___|_| |_ _ _'
echo ' | |   |  _| |   | |  _| | |'
echo ' |_|_|_|_| |_|_|_|_|_| |_  |'
echo '                       |___|'
echo ''
echo '         By fullpwn.'
linux /boot/vmlinuz boot=live quiet
initrd /boot/initrd.img
boot
EOF

# Change hostname and configure .bashrc
echo 'infinity' > work/chroot/etc/hostname
echo "export INFINITY_VERSION='$VERSION'" > work/chroot/root/.bashrc
echo '/usr/bin/infinity_menu' >> work/chroot/root/.bashrc

rm -f work/chroot/etc/resolv.conf

# Build the ISO
umount work/chroot/proc
umount work/chroot/sys
umount work/chroot/dev
cp work/chroot/vmlinuz work/iso/boot
cp work/chroot/initrd.img work/iso/boot
mksquashfs work/chroot work/iso/live/filesystem.squashfs -noappend -e boot -comp xz -Xbcj x86 -Xdict-size 100%

## Creates output ISO dir (easier for GitHub Actions)
mkdir -p out
grub-mkrescue -o "out/infinity-$VERSION-$ARCH.iso" work/iso \
    --compress=xz \
    --fonts='' \
    --locales='' \
    --themes=''

end_time="$(date -u +%s)"
elapsed_time="$((end_time - start_time))"

# Stop echoing commands
set +x
echo "Built infinity-$VERSION-$ARCH in $((elapsed_time / 60)) minutes and $((elapsed_time % 60)) seconds."
