#!/bin/bash
# Usage: ./run.sh n4|n4plus|n4-v1.4|n4plus-v2.3
#   n4          - Neptune 4 / 4 Pro image (ZNP-K1 V1.x)
#   n4plus      - Neptune 4 Plus / Max image (ZNP-K1 V2.0)
#   n4-v1.4     - Neptune 4 / 4 Pro USB-C toolhead image (ZNP-K1 V1.4)
#   n4plus-v2.3 - Neptune 4 Plus / Max USB-C toolhead image (ZNP-K1 V2.3)
# See ZNP-K1.md for building every release image and testing them.
case "$1" in
	n4 | n4plus | n4-v1.4 | n4plus-v2.3) ;;
	*)
		echo "Usage: $0 n4|n4plus|n4-v1.4|n4plus-v2.3" >&2
		exit 1
		;;
esac

./compile.sh BOARD=znp-k1 ZNP_K1_VARIANT="$1" BRANCH=current RELEASE=trixie BSPFREEZE=yes BUILD_MINIMAL=yes BUILD_DESKTOP=no KERNEL_CONFIGURE=no EXTRAWIFI=yes NETWORKING_STACK=network-manager INSTALL_HEADERS=yes VENDOR=OpenNept4une CLEAN_LEVEL=cache COMPRESS_OUTPUTIMAGE=xz
