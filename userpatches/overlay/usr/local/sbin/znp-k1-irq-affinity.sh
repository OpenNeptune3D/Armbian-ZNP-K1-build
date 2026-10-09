#!/bin/sh
# Override Armbian's rockchip64 IRQ tuning (armbian-hardware-optimization), which
# pins the eth0 IRQ to CPU3. Move it to CPU0 so network interrupts stay off the
# core shared with Klipper. Armbian's rps_cpus=7 (CPUs 0-2) already keeps receive
# soft-IRQ work off CPU3, and its USB/Mali placement (CPUs 1-2) is left as-is.

ETH_IRQ_CPU=0

for irq in $(awk -F: '/eth0/ {gsub(/ /, "", $1); print $1}' /proc/interrupts); do
	if echo "$ETH_IRQ_CPU" > "/proc/irq/$irq/smp_affinity_list" 2> /dev/null; then
		echo "eth0 IRQ $irq -> CPU $ETH_IRQ_CPU"
	fi
done

exit 0
