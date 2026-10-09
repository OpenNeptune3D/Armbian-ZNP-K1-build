#!/bin/bash
# Usage: ./run.sh n4|n4plus
#   n4     - Neptune 4 / 4 Pro image (ZNP-K1 V1.x)
#   n4plus - Neptune 4 Plus / Max image (ZNP-K1 V2.0)
case "$1" in
	n4 | n4plus) ;;
	*)
		echo "Usage: $0 n4|n4plus" >&2
		exit 1
		;;
esac

./compile.sh BOARD=znp-k1 ZNP_K1_VARIANT="$1" BRANCH=current RELEASE=trixie BSPFREEZE=yes BUILD_MINIMAL=yes BUILD_DESKTOP=no KERNEL_CONFIGURE=no EXTRAWIFI=yes INSTALL_HEADERS=yes VENDOR=OpenNept4une CLEAN_LEVEL=cache COMPRESS_OUTPUTIMAGE=xz
