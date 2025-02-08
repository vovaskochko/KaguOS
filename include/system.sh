# We will store hw emulation files under tmp dir
export GLOBAL_HW_DIR="tmp"

# Disks and other devices should be stored inside this folder
export SYSTEM_HW_DIR="hw"

# RAM constants:
export GLOBAL_RAM_FILE="${GLOBAL_HW_DIR}/RAM.txt"
export GLOBAL_RAM_SIZE="400"

# Kernel constants:
export GLOBAL_BUILD_DIR="build"
export GLOBAL_KERNEL_DISK="${GLOBAL_BUILD_DIR}/kernel.disk"
export INFO_KERNEL_START=40
export KERNEL_START=41
