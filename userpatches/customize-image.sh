#!/bin/bash
#
# Armbian runs this INSIDE the target image (chroot), after armbian-firmware
# and the kernel are installed and before the image file is created.
# Args: $1=RELEASE $2=LINUXFAMILY $3=BOARD $4=BUILD_DESKTOP $5=ARCH
#
# - Paths are image paths: /etc here is the image's /etc. ($SDCARD is a
#   build-host variable and must not be used in this script.)
# - userpatches/overlay on the host is bind-mounted read-only at /tmp/overlay.
# - A non-zero exit aborts the build. Steps that must succeed use `|| exit 1`;
#   everything else only logs through the ERR trap below.
# - The user account (mks) does not exist yet: it is created at first boot.
#   Per-user setup (KAMP, KIAUH, Fluidd DB) stays in
#   OpenNept4une/img-config/base_image_configuration.sh.
#
# Build with NETWORKING_STACK=network-manager so Armbian sets up
# NetworkManager + netplan itself (minimal builds default to systemd-networkd).

handle_error() {
    echo "Error occurred in script at line: $1"
}
trap 'handle_error $LINENO' ERR

export DEBIAN_FRONTEND=noninteractive

# The board DTBs come from the linux-dtb package. The one that boots is set by
# fdtfile= in /boot/armbianEnv.txt (chosen per image by ZNP_K1_VARIANT, see
# config/boards/znp-k1.conf for the list of variants).

# Copy SPI & GPIO group permission rules files to the rules.d folder
cp /tmp/overlay/etc/udev/rules.d/*.rules /etc/udev/rules.d/

# Install IRQ affinity override (moves eth0 IRQ off the Klipper core, CPU3)
install -m 0755 /tmp/overlay/usr/local/sbin/znp-k1-irq-affinity.sh /usr/local/sbin/
install -m 0644 /tmp/overlay/etc/systemd/system/znp-k1-irq-affinity.service /etc/systemd/system/
systemctl enable znp-k1-irq-affinity.service

# Copy flag file
cp /tmp/overlay/boot/.OpenNept4une.txt /boot/

# Load the rk805 PMIC pinctrl driver at boot (mainboard power LEDs)
echo "pinctrl-rk805" > /etc/modules-load.d/rk805.conf

# Update package list and install packages. A failure here would produce an
# image with missing packages, so stop the build instead.
apt-get update || exit 1

apt-get install -y \
    git \
    python3-numpy \
    python3-matplotlib \
    python3-venv \
    virtualenv \
    python-dev-is-python3 \
    libffi-dev \
    build-essential \
    libncurses-dev \
    libusb-dev \
    avrdude \
    gcc-avr \
    binutils-avr \
    avr-libc \
    stm32flash \
    libnewlib-arm-none-eabi \
    gcc-arm-none-eabi \
    binutils-arm-none-eabi \
    libusb-1.0-0-dev \
    pkg-config \
    python3 \
    python3-virtualenv \
    liblmdb-dev \
    libopenjp2-7 \
    libsodium-dev \
    zlib1g-dev \
    libjpeg-dev \
    packagekit \
    wireless-tools \
    network-manager \
    curl \
    wget \
    nginx \
    crudini \
    bsdutils \
    findutils \
    v4l-utils \
    libevent-dev \
    libbsd-dev \
    unzip \
    dfu-util \
    libusb-1.0-doc \
    setserial \
    python3-pip \
    libopenblas-dev \
    libatlas3-base \
    jq \
    zip \
    cmake \
    || exit 1
# Last block, by who needs it (preinstalled so first setup doesn't download them):
#   unzip, dfu-util        KIAUH (checked before every component install)
#   libusb-1.0-doc         Klipper: KIAUH installs "libusb-1.0", which apt treats
#                          as a regex matching -0, -0-dev and -doc
#   setserial              display_connector
#   python3-pip            mobileraker_companion
#   libopenblas-dev, libatlas3-base  OpenNept4une rpi-mcu-install.sh (ADXL)
#   jq, zip                OpenNept4une github-issue-debug.sh
#   cmake                  OpenNept4une webcam-setup.sh (mjpg-streamer build)

# Create gpio and spi groups if they don't exist (for led control v.1.1+ & ADXL SPI)
getent group gpio >/dev/null || groupadd gpio
getent group spiusers >/dev/null || groupadd spiusers

# Put the user created at first boot into gpio + spiusers automatically.
# armbian-firstlogin creates the user with `adduser`, which honours these.
# (It adds dialout, sudo, video, etc. itself.)
ADDUSER_CONF=/etc/adduser.conf
sed -i -E '/^#?[[:space:]]*(ADD_EXTRA_GROUPS|EXTRA_GROUPS)=/d; /^# OpenNept4une: groups for new users$/d' "$ADDUSER_CONF"
printf '\n# OpenNept4une: groups for new users\nADD_EXTRA_GROUPS=1\nEXTRA_GROUPS="users gpio spiusers"\n' >> "$ADDUSER_CONF"

# Kernel args: merge net.ifnames=0 (eth0/wlan0 names) into extraargs without
# creating a second extraargs= line (U-Boot keeps only the last one).
ARMBIAN_ENV=/boot/armbianEnv.txt
touch "$ARMBIAN_ENV"
if grep -q '^extraargs=' "$ARMBIAN_ENV"; then
    if grep -qE '^extraargs=(.*[[:space:]])?net\.ifnames=0([[:space:]]|$)' "$ARMBIAN_ENV"; then
        echo "extraargs already contains net.ifnames=0"
    else
        sed -i -E 's/^extraargs=(.*)$/extraargs=\1 net.ifnames=0/; s/^extraargs= /extraargs=/' "$ARMBIAN_ENV"
        echo "Added net.ifnames=0 to existing extraargs in $ARMBIAN_ENV"
    fi
else
    echo "extraargs=net.ifnames=0" >> "$ARMBIAN_ENV"
    echo "Added extraargs=net.ifnames=0 to $ARMBIAN_ENV"
fi

# ---------------------------------------------------------------------------
# Trim firmware for hardware the ZNP-K1 (RK3328) can't have (~270 MB):
#   - Qualcomm SoC firmware (phones/laptops)
#   - PCIe/M.2 Wi-Fi (RK3328 has no PCIe)
#   - Onboard SDIO Wi-Fi modules from other boards (ZNP-K1 SDIO slot is disabled)
#   - Video codec firmware for NXP/Amlogic chips
# USB Wi-Fi/Bluetooth firmware is KEPT (rtw88/89, rtlwifi, rtl_bt, mediatek,
# rt*.bin, mt7*.bin, aic8800, ath10k, qca, brcm) and so is
# regulatory.db (including updates/regulatory.db, which the kernel loads first).
#
# armbian-firmware is installed before this script runs and is not reinstalled
# afterwards. The dpkg path-exclude file stops a later upgrade of the package
# from putting the files back. Both /lib and /usr/lib forms are listed in case
# a future package moves its files to /usr/lib.
# ---------------------------------------------------------------------------
FW=/lib/firmware
FW_DROP_DIRS="qcom ath11k ath12k updates/ath11k intel rkwifi ap6210 ap6212 ap6275p cypress uwe5621ds uwe5622 vpu video imx meson"
FW_DROP_FILES="iwlwifi-* fw_bcm4* wcnmodem.bin wifi_2355b001_1ant.ini"
FW_EXCL=/etc/dpkg/dpkg.cfg.d/opennept4une-firmware-trim

fw_before=$(du -sm "$FW" 2>/dev/null | cut -f1)
mkdir -p /etc/dpkg/dpkg.cfg.d
echo "# Firmware for hardware the ZNP-K1 can't have (see customize-image.sh)" > "$FW_EXCL"
for d in $FW_DROP_DIRS; do
    rm -rf "${FW:?}/$d"
    printf 'path-exclude=/lib/firmware/%s/*\npath-exclude=/usr/lib/firmware/%s/*\n' "$d" "$d" >> "$FW_EXCL"
done
for f in $FW_DROP_FILES; do
    rm -f "${FW:?}"/$f    # unquoted on purpose: $f may be a glob
    printf 'path-exclude=/lib/firmware/%s\npath-exclude=/usr/lib/firmware/%s\n' "$f" "$f" >> "$FW_EXCL"
done
fw_after=$(du -sm "$FW" 2>/dev/null | cut -f1)
echo "Firmware trimmed: ${fw_before:-?} MB -> ${fw_after:-?} MB"

# ---------------------------------------------------------------------------
# Add open-source firmware for Atheros AR9271 / AR7010 USB Wi-Fi dongles
# (TP-Link TL-WN722N v1 and many cheap "150 Mbps" sticks). The kernel's
# ath9k_htc driver needs it but armbian-firmware doesn't ship it. ~120 KB.
#
# Uses userpatches/overlay/lib/firmware/ath9k_htc/<file> if present (offline
# builds), otherwise downloads it from a pinned linux-firmware release.
# Either way the sha256 must match. A failure only prints a warning and never
# aborts the build.
# ---------------------------------------------------------------------------
ATH9K_TAG=20261019
ATH9K_URL="https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain/ath9k_htc"
ATH9K_DIR=/lib/firmware/ath9k_htc
ATH9K_OVERLAY=/tmp/overlay/lib/firmware/ath9k_htc
mkdir -p "$ATH9K_DIR"
while read -r sum name; do
    [[ -n "$name" ]] || continue
    dest="$ATH9K_DIR/$name"
    if [[ -f "$ATH9K_OVERLAY/$name" ]]; then
        cp "$ATH9K_OVERLAY/$name" "$dest.tmp"
    else
        curl -fsSL --retry 3 --max-time 60 -o "$dest.tmp" "$ATH9K_URL/$name?h=$ATH9K_TAG"
    fi
    if [[ -f "$dest.tmp" ]] && echo "$sum  $dest.tmp" | sha256sum -c --quiet - >/dev/null 2>&1; then
        mv "$dest.tmp" "$dest"
        chmod 0644 "$dest"
        echo "Installed $dest"
    else
        rm -f "$dest.tmp"
        echo "WARNING: could not install $name (download or checksum failed). AR9271/AR7010 dongles won't work."
    fi
done <<'ATH9K_SUMS'
78f7d592a95b419a02fde7440f30c606fc31a871cf0ce150ced40d4857173eb0  htc_9271-1.4.0.fw
737850aaf66ca13f82e0f5ca5e758f606f840c2f23c291350ab916bbf88e6f75  htc_7010-1.4.0.fw
ATH9K_SUMS

# Armbian aborts the build if this script exits non-zero, so end on success.
exit 0
