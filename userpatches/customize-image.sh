#!/bin/bash

# NOTE: If you want to transfer files between chroot and host
# userpatches/overlay directory on host is bind-mounted to /tmp/overlay in chroot
# The SD card's root path is accessible via $SDCARD variable.

# Function to handle errors
handle_error() {
    echo "Error occurred in script at line: $1"
}

# Trap errors
trap 'handle_error $LINENO' ERR

# Copy DTB files to the boot partition by default this is for v.1.0 boards 
# Although it does copy all dtb variants that can be renamed / replace the current 
# /boot/dtb/rockchip/rk3328-roc-cc.dtb
cp /tmp/overlay/boot/dtb/rockchip/*.dtb $SDCARD/boot/dtb/rockchip/

# Copy SPI & GPIO group permission rules files to the rules.d folder
cp /tmp/overlay/etc/udev/rules.d/*.rules $SDCARD/etc/udev/rules.d/

# Copy flag file
cp /tmp/overlay/boot/.OpenNept4une.txt

# Update package list and install packages
apt-get update

apt-get install -y \
    janus \
    git \
    python3-numpy \
    python3-matplotlib \
    libatlas-base-dev \
    python3.11-venv \
    virtualenv \
    python-dev \
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
    libusb-1.0 \
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
    curl \
    wget \
    nginx \
    crudini \
    bsdutils \
    findutils \
    v4l-utils \
    build-essential \
    libevent-dev \
    libjpeg-dev \
    libbsd-dev
	
# Create gpio and spi groups if they don't exist (for led control v.1.1+ & ADXL SPI
sudo groupadd gpio || true
sudo groupadd spiusers || true

# Add cron job to run sync command every 10 minutes as printers are typically powercut instead of shut down.
CRON_ENTRY="*/10 * * * * /bin/sync"
(crontab -l 2>/dev/null | grep -qF "$CRON_ENTRY") || (crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -

# Add extraargs to armbianEnv.txt if not exists - makes net interface naming start from 0
FILE_PATH="/boot/armbianEnv.txt"
LINE_TO_ADD="extraargs=net.ifnames=0"
if grep -q "$LINE_TO_ADD" "$FILE_PATH"; then
    echo "The line '$LINE_TO_ADD' already exists in $FILE_PATH."
else
    echo "$LINE_TO_ADD" | sudo tee -a "$FILE_PATH" > /dev/null
    echo "Added '$LINE_TO_ADD' to $FILE_PATH."
fi
