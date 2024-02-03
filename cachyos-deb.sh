#!/bin/bash
# Description: Script to compile a custom Linux kernel and package it into a .deb file for CachyOS
# Maintainer: Laio O. Seman <laio@iee.org>

# Initialize variables to store user choices
_cachyos_config="yes"
_cpusched_config="cachyos"
_llvm_lto_config="none"
_tick_rate_config="500"
_numa_config=""
_nr_cpus_config=""
_hugepage_config=""
_lru_config=""
_o3_optimization_config="yes"
_performance_governor_config=""

_cpusched_selection="none"
_llvm_lto_selection="none"
_tick_rate="500"
_numa="none"
_nr_cpus="32"
_bbr3="yes"
_march="native"

# Check if GCC is installed
check_gcc() {
    if ! [ -x "$(command -v gcc)" ]; then
        # Display error message if GCC is not installed
        echo "Error: GCC is not installed. Please install GCC and try again." >&2
        exit 1
    fi
}

# Original function used in the CachyOS mainline
init_script() {
    # Call the function before running the rest of the script
    check_gcc

    # Get CPU type from GCC and convert to uppercase
    MARCH=$(gcc -Q -march=native --help=target | grep -m1 march= | awk '{print toupper($2)}')

    # Check for specific CPU types and set MARCH variable accordingly
    case $MARCH in
    ZNVER1) MARCH="ZEN" ;;
    ZNVER2) MARCH="ZEN2" ;;
    ZNVER3) MARCH="ZEN3" ;;
    ZNVER4) MARCH="ZEN4" ;;
    BDVER1) MARCH="BULLDOZER" ;;
    BDVER2) MARCH="PILEDRIVER" ;;
    BDVER3) MARCH="STEAMROLLER" ;;
    BDVER4) MARCH="EXCAVATOR" ;;
    BTVER1) MARCH="BOBCAT" ;;
    BTVER2) MARCH="JAGUAR" ;;
    AMDFAM10) MARCH="MK10" ;;
    K8-SSE3) MARCH="K8SSE3" ;;
    BONNELL) MARCH="ATOM" ;;
    GOLDMONT-PLUS) MARCH="GOLDMONTPLUS" ;;
    SKYLAKE-AVX512) MARCH="SKYLAKEX" ;;
    MIVYBRIDGE)
        scripts/config --disable CONFIG_AGP_AMD64
        scripts/config --disable CONFIG_MICROCODE_AMD
        MARCH="MIVYBRIDGE"
        ;;
    ICELAKE-CLIENT) MARCH="ICELAKE" ;;
    esac

    # Add "M" prefix to MARCH variable
    MARCH2=M${MARCH}

    # show whiptail screen for the found CPU and ask if it is correct
    whiptail --title "CPU Architecture" --yesno "Detected CPU (MARCH) : ${MARCH2}\nIs this correct?" 10 60
    if [ $? -eq 1 ]; then
        # if not correct, ask for the CPU type
        MARCH2=$(whiptail --title "CPU Architecture" --inputbox "Enter CPU type (MARCH):" 10 60 "$MARCH2" 3>&1 1>&2 2>&3)
    fi

    # Display detected CPU and apply optimization
    echo "----------------------------------"
    echo "| APPLYING AUTO-CPU-OPTIMIZATION |"
    echo "----------------------------------"
    echo "[*] DETECTED CPU (MARCH) : ${MARCH2}"

    # define _march as MARCH2
    _march=$MARCH2
}

export NEWT_COLORS='
    root=white,blue
    border=black,lightgray
    window=black,lightgray
    shadow=black,gray
    title=black,lightgray
    button=black,cyan
    actbutton=white,blue
    checkbox=black,lightgray
    actcheckbox=black,cyan
    entry=black,lightgray
    label=black,lightgray
    listbox=black,lightgray
    actlistbox=black,cyan
    textbox=black,lightgray
    acttextbox=black,cyan
    helpline=white,blue
    roottext=black,lightgray
'

configure_cachyos() {
    local cachyos_status=$([ "$_cachyos_config" = "CACHYOS" ] && echo "ON" || echo "OFF")
    local selection

    whiptail --title "CachyOS Configuration" --checklist \
        "Select optimizations to enable:" 20 78 1 \
        "CachyOS" "" $cachyos_status \
        3>&1 1>&2 2>&3

    if [[ "$selection" == *"CachyOS"* ]]; then
        _cachyos_config="CACHYOS"
    else
        _cachyos_config="none"
    fi
}

# Function to configure CPU scheduler
configure_cpusched() {
    # Show radiolist and capture user selection
    _cpusched_selection=$(whiptail --title "CPU Scheduler Configuration" --radiolist \
        "Choose CPU Scheduler (use space to select):" 15 60 3 \
        "cachyos" "Enable CachyOS CPU scheduler" $([ "$_cpusched_selection" = "cachyos" ] && echo "ON" || echo "OFF") \
        "pds" "Enable PDS CPU scheduler" $([ "$_cpusched_selection" = "pds" ] && echo "ON" || echo "OFF") \
        "none" "Do not configure CPU scheduler" $([ "$_cpusched_selection" = "none" ] && echo "ON" || echo "OFF") \
        3>&1 1>&2 2>&3)
}

# Function to configure LLVM LTO
configure_llvm_lto() {
    _llvm_lto_selection=$(whiptail --title "LLVM LTO Configuration" --radiolist \
        "Choose LLVM LTO (use space to select):" 15 60 3 \
        "thin" "Enable LLVM LTO Thin" $([ "$_llvm_lto_selection" = "thin" ] && echo "ON" || echo "OFF") \
        "full" "Enable LLVM LTO Full" $([ "$_llvm_lto_selection" = "full" ] && echo "ON" || echo "OFF") \
        "none" "Do not configure LLVM LTO" $([ "$_llvm_lto_selection" = "none" ] && echo "ON" || echo "OFF") \
        3>&1 1>&2 2>&3)
}

# Function to configure tick rate for 100|250|500|600|750|1000)
configure_tick_rate() {
    _tick_rate=$(whiptail --title "Tick Rate Configuration" --radiolist \
        "Choose Tick Rate (use space to select):" 15 60 3 \
        "100" "100 Hz" $([ "$_tick_rate" = "100" ] && echo "ON" || echo "OFF") \
        "250" "250 Hz" $([ "$_tick_rate" = "250" ] && echo "ON" || echo "OFF") \
        "500" "500 Hz" $([ "$_tick_rate" = "500" ] && echo "ON" || echo "OFF") \
        "600" "600 Hz" $([ "$_tick_rate" = "600" ] && echo "ON" || echo "OFF") \
        "750" "750 Hz" $([ "$_tick_rate" = "750" ] && echo "ON" || echo "OFF") \
        "1000" "1000 Hz" $([ "$_tick_rate" = "1000" ] && echo "ON" || echo "OFF") \
        3>&1 1>&2 2>&3)

}

# Function to configure NR_CPUS
configure_nr_cpus() {
    _nr_cpus=$(whiptail --title "NR_CPUS Configuration" --inputbox "Enter NR_CPUS value:" 10 60 "$_nr_cpus" 3>&1 1>&2 2>&3)
}

# Function to configure Hugepages
configure_hugepages() {
    _hugepage=$(whiptail --title "Hugepages Configuration" --radiolist \
        "Choose Hugepages (use space to select):" 15 60 3 \
        "always" "Always use hugepages" $([ "$_hugepage" = "always" ] && echo "ON" || echo "OFF") \
        "madvise" "Use hugepages with madvise" $([ "$_hugepage" = "madvise" ] && echo "ON" || echo "OFF") \
        "no" "Do not configure Hugepages" $([ "$_hugepage" = "no" ] && echo "ON" || echo "OFF") \
        3>&1 1>&2 2>&3)
}

# Function to configure LRU
configure_lru() {
    _lru_config=$(whiptail --title "LRU Configuration" --radiolist \
        "Choose LRU (use space to select):" 15 60 3 \
        "standard" "Standard LRU" $([ "$_lru_config" = "standard" ] && echo "ON" || echo "OFF") \
        "stats" "LRU with stats" $([ "$_lru_config" = "stats" ] && echo "ON" || echo "OFF") \
        "none" "Do not configure LRU" $([ "$_lru_config" = "none" ] && echo "ON" || echo "OFF") \
        3>&1 1>&2 2>&3)
}

# Function to configure tick type
configure_tick_type() {
    _tick_type=$(whiptail --title "Tick Type Configuration" --radiolist \
        "Choose Tick Type (use space to select):" 15 60 3 \
        "periodic" "Periodic tick" $([ "$_tick_type" = "periodic" ] && echo "ON" || echo "OFF") \
        "nohz_full" "Full dynticks" $([ "$_tick_type" = "nohz_full" ] && echo "ON" || echo "OFF") \
        "nohz_idle" "Idle dynticks" $([ "$_tick_type" = "nohz_idle" ] && echo "ON" || echo "OFF") \
        3>&1 1>&2 2>&3)
}

configure_preempt_type() {
    _preempt_type=$(whiptail --title "Preempt Type Configuration" --radiolist \
        "Choose Preempt Type (use space to select):" 15 60 3 \
        "voluntary" "Voluntary Preemption" $([ "$_preempt_type" = "voluntary" ] && echo "ON" || echo "OFF") \
        "preempt" "Preemptible Kernel" $([ "$_preempt_type" = "preempt" ] && echo "ON" || echo "OFF") \
        "none" "Do not configure Preempt Type" $([ "$_preempt_type" = "none" ] && echo "ON" || echo "OFF") \
        3>&1 1>&2 2>&3)
}

configure_system_optimizations() {
    # Initialize status of each optimization
    local o3_status=$([ "$_o3_optimization" = "yes" ] && echo "ON" || echo "OFF")
    local os_status=$([ "$_os_optimization" = "yes" ] && echo "ON" || echo "OFF")
    local performance_status=$([ "$_performance_governor" = "yes" ] && echo "ON" || echo "OFF")
    local bbr3_status=$([ "$_bbr3" = "yes" ] && echo "ON" || echo "OFF")
    local vma_status=$([ "$_vma" = "yes" ] && echo "ON" || echo "OFF")
    local damon_status=$([ "$_damon" = "yes" ] && echo "ON" || echo "OFF")
    local numa_status=$([ "$_numa" = "enable" ] && echo "ON" || echo "OFF")

    # Display checklist
    local selection
    selection=$(whiptail --title "System Optimizations Configuration" --checklist \
        "Select optimizations to enable:" 20 78 6 \
        "O3 Optimization" "" $o3_status \
        "OS Optimization" "" $os_status \
        "Performance Governor" "" $performance_status \
        "TCP BBR3" "" $bbr3_status \
        "VMA" "" $vma_status \
        "DAMON" "" $damon_status \
        "NUMA" "" $numa_status \
        3>&1 1>&2 2>&3)

    # Update configurations based on the selection
    if [[ "$selection" == *"O3 Optimization"* ]]; then
        _o3_optimization="yes"
        _os_optimization="no" # Disable OS Optimization if O3 Optimization is selected
    else
        _o3_optimization="no"
    fi

    if [[ "$selection" == *"OS Optimization"* ]]; then
        _os_optimization="yes"
        _o3_optimization="no" # Disable O3 Optimization if OS Optimization is selected
    else
        _os_optimization="no"
    fi

    [[ "$selection" == *"Performance Governor"* ]] && _performance_governor="yes" || _performance_governor="no"
    [[ "$selection" == *"TCP BBR3"* ]] && _bbr3="yes" || _bbr3="no"
    [[ "$selection" == *"VMA"* ]] && _vma="yes" || _vma="no"
    [[ "$selection" == *"DAMON"* ]] && _damon="yes" || _damon="no"
    [[ "$selection" == *"NUMA"* ]] && _numa="enable" || _numa="disable"
}

choose_kernel_option() {

    # show kernel version to the user in a box and ask to confirm
    whiptail --title "Kernel Version" --msgbox "The latest kernel version is $_kv" 8 78

}

debing() {
    #!/bin/bash
    # Description: Script to compile a custom Linux kernel and package it into a .deb file for CachyOS
    # Maintainer: Laio O. Seman <laio@iee.org>

    KERNEL_VERSION=$(make kernelversion)
    ARCH=$(dpkg --print-architecture)

    # Kernel package variables
    KERNEL_PKG_NAME=custom-kernel-${KERNEL_VERSION}
    KERNEL_PKG_VERSION=${KERNEL_VERSION}-1
    KERNEL_PKG_DIR=${KERNEL_PKG_NAME}-${KERNEL_PKG_VERSION}

    # Headers package variables
    HEADERS_PKG_NAME=custom-kernel-headers-${KERNEL_VERSION}
    HEADERS_PKG_VERSION=${KERNEL_VERSION}-1
    HEADERS_PKG_DIR=${HEADERS_PKG_NAME}-${HEADERS_PKG_VERSION}

    # Function to create kernel package
    package_kernel() {
        # Create directory structure for kernel package
        mkdir -p ${KERNEL_PKG_DIR}/DEBIAN
        mkdir -p ${KERNEL_PKG_DIR}/boot
        mkdir -p ${KERNEL_PKG_DIR}/lib/modules/${KERNEL_VERSION}
        mkdir -p ${KERNEL_PKG_DIR}/usr/share/doc/${KERNEL_PKG_NAME}

        # Create control file for kernel package
        cat >${KERNEL_PKG_DIR}/DEBIAN/control <<EOF
Package: ${KERNEL_PKG_NAME}
Version: ${KERNEL_PKG_VERSION}
Section: kernel
Priority: optional
Architecture: ${ARCH}
Maintainer: CachyOs
Description: Custom compiled Linux Kernel
 Custom compiled Linux Kernel ${KERNEL_VERSION}
EOF

        # Copy the compiled kernel and modules
        cp arch/x86/boot/bzImage ${KERNEL_PKG_DIR}/boot/vmlinuz-${KERNEL_VERSION}
        cp -a /tmp/kernel-modules/lib/modules/${KERNEL_VERSION}/* ${KERNEL_PKG_DIR}/lib/modules/${KERNEL_VERSION}/
        cp System.map ${KERNEL_PKG_DIR}/boot/System.map-${KERNEL_VERSION}
        cp .config ${KERNEL_PKG_DIR}/boot/config-${KERNEL_VERSION}

        # Package the kernel
        fakeroot dpkg-deb --build ${KERNEL_PKG_DIR}

        # Clean up kernel package directory
        rm -rf ${KERNEL_PKG_DIR}
    }

    # Function to create headers package
    package_headers() {
        # Create directory structure for headers package
        mkdir -p ${HEADERS_PKG_DIR}/DEBIAN
        mkdir -p ${HEADERS_PKG_DIR}/usr/src/linux-headers-${KERNEL_VERSION}

        # Create control file for headers package
        cat >${HEADERS_PKG_DIR}/DEBIAN/control <<EOF
Package: ${HEADERS_PKG_NAME}
Version: ${HEADERS_PKG_VERSION}
Section: kernel
Priority: optional
Architecture: ${ARCH}
Maintainer: CachyOs
Description: Headers for custom compiled Linux Kernel ${KERNEL_VERSION}
EOF

        # Copy the kernel headers
        cp -r /usr/src/linux-headers-${KERNEL_VERSION}/* ${HEADERS_PKG_DIR}/usr/src/linux-headers-${KERNEL_VERSION}/

        # Package the headers
        fakeroot dpkg-deb --build ${HEADERS_PKG_DIR}

        # Clean up headers package directory
        rm -rf ${HEADERS_PKG_DIR}
    }

    # Compile the kernel and modules
    make -j$(nproc)
    mkdir -p /tmp/kernel-modules
    make modules_install INSTALL_MOD_PATH=/tmp/kernel-modules

    # Package the kernel
    package_kernel

    # Package the headers
    package_headers
}

_kv_url=$(curl -s https://www.kernel.org | grep -A 1 'id="latest_link"' | awk 'NR==2' | grep -oP 'href="\K[^"]+')

# extract only the version number
_kv_name=$(echo $_kv_url | grep -oP 'linux-\K[^"]+')
# remove the .tar.xz extension
_kv_name=$(basename $_kv_name .tar.xz)
do_things() {

    # define _major as the first two digits of the kernel version
    _major=$(echo $_kv_name | grep -oP '^\K[^\.]+')
    
    # middle number 
    _mid=$(echo $_kv_name | grep -oP '^\d+\.\K[^\.]+')

    # download kernel to linux.tar.xz
    wget -c $_kv_url -O linux.tar.xz
    # extract kernel
    tar -xf linux.tar.xz
    # enter kernel directory

    cd linux-$_kv_name

    # get cachyos .config
    wget -c https://raw.githubusercontent.com/CachyOS/linux-cachyos/master/linux-cachyos/config -O .config

    local _patchsource="https://raw.githubusercontent.com/cachyos/kernel-patches/master/${_major}.${_mid}"

    # create empty source array of patches
    declare -a patches=()

    # Apply CachyOS configuration
    if [ "$_cachyos_config" == "CACHYOS" ]; then
        scripts/config -e CACHYOS
        patches+=("${_patchsource}/all/0001-cachyos-base-all.patch")
    fi

    ## List of CachyOS schedulers
    case "$_cpusched_config" in
    cachyos) # CachyOS Scheduler (BORE + SCHED-EXT)
        source+=("${_patchsource}/sched/0001-sched-ext.patch"
            "${_patchsource}/sched/0001-bore-cachy.patch") ;;
    bore) ## BORE Scheduler
        source+=("${_patchsource}/sched/0001-bore-cachy.patch") ;;
    rt) ## EEVDF with RT patches
        source+=("${_patchsource}/misc/0001-rt.patch"
            linux-cachyos-rt.install) ;;
    rt-bore) ## RT with BORE Scheduler
        source+=("${_patchsource}/misc/0001-rt.patch"
            "${_patchsource}/sched/0001-bore-cachy-rt.patch"
            linux-cachyos-rt.install) ;;
    hardened) ## Hardened Patches with BORE Scheduler
        source+=("${_patchsource}/sched/0001-bore-cachy.patch"
            "${_patchsource}/misc/0001-hardened.patch") ;;
    sched-ext) ## SCHED-EXT
        source+=("${_patchsource}/sched/0001-sched-ext.patch") ;;
    esac

    # download and apply patches on source
    for i in "${source[@]}"; do
        echo "Downloading and applying $i"
        wget -c $i
        patch -p1 <$(basename $i)
    done

    # set architecture
    scripts/config -k --disable CONFIG_GENERIC_CPU
    scripts/config -k --enable CONFIG_${MARCH2}

    case "$_cpusched_config" in
    cachyos) scripts/config -e SCHED_BORE -e SCHED_CLASS_EXT ;;
    bore | hardened) scripts/config -e SCHED_BORE ;;
    eevdf) ;;
    rt) scripts/config -e PREEMPT_COUNT -e PREEMPTION -d PREEMPT_VOLUNTARY -d PREEMPT -d PREEMPT_NONE -e PREEMPT_RT -d PREEMPT_DYNAMIC -d PREEMPT_BUILD ;;
    rt-bore) scripts/config -e SCHED_BORE -e PREEMPT_COUNT -e PREEMPTION -d PREEMPT_VOLUNTARY -d PREEMPT -d PREEMPT_NONE -e PREEMPT_RT -d PREEMPT_DYNAMIC -d PREEMPT_BUILD ;;
    sched-ext) scripts/config -e SCHED_CLASS_EXT ;;
    esac

    # Apply LLVM LTO configuration
    case "$_llvm_lto_config" in
    thin) scripts/config -e LTO_CLANG_THIN ;;
    full) scripts/config -e LTO_CLANG_FULL ;;
    none) scripts/config -d LTO_CLANG_THIN -d LTO_CLANG_FULL ;;
    esac

    # Apply tick rate configuration
    case "$_HZ_ticks" in
    100 | 250 | 500 | 600 | 750 | 1000)
        scripts/config -d HZ_300 -e "HZ_${_HZ_ticks}" --set-val HZ "${_HZ_ticks}"
        ;;
    300)
        scripts/config -e HZ_300 --set-val HZ 300
        ;;
    esac

    # Apply NUMA configuration
    case "$_numa" in
    enable) scripts/config -e NUMA ;;
    disable) scripts/config -d NUMA ;;
    none) ;; # Do nothing for 'none'
    esac

    # Apply Hugepages configuration
    case "$_hugepage" in
    always) scripts/config -d TRANSPARENT_HUGEPAGE_MADVISE -e TRANSPARENT_HUGEPAGE_ALWAYS ;;
    madvise) scripts/config -d TRANSPARENT_HUGEPAGE_ALWAYS -e TRANSPARENT_HUGEPAGE_MADVISE ;;
    no) ;; # Do nothing for 'no'
    esac

    # setting nr_cpus
    scripts/config --set-val NR_CPUS "$_nr_cpus"

    # Apply LRU configuration
    case "$_lru_config" in
    standard) scripts/config -e LRU_GEN -e LRU_GEN_ENABLED -d LRU_GEN_STATS ;;
    stats) scripts/config -e LRU_GEN -e LRU_GEN_ENABLED -e LRU_GEN_STATS ;;
    none) scripts/config -d LRU_GEN ;;
    esac

    # Apply O3 optimization
    if [ "$_o3_optimization" == "yes" ]; then
        scripts/config -d CC_OPTIMIZE_FOR_PERFORMANCE -e CC_OPTIMIZE_FOR_PERFORMANCE_O3
    fi

    # Apply performance governor
    if [ "$_performance_governor" == "yes" ]; then
        scripts/config -d CPU_FREQ_DEFAULT_GOV_SCHEDUTIL -e CPU_FREQ_DEFAULT_GOV_PERFORMANCE
    fi

    echo "Configurations applied."

    # Make the kernel calling debing
    debing

}




# call init script
# display warning message saying this is a beta version

whiptail --title "CachyOS Kernel Configuration" --msgbox "This is a beta version of the CachyOS Kernel Configuration script. Use at your own risk." 8 78

# say that the user will lose the ability to use secure boot and ask for confirmation
whiptail --title "Secure Boot Warning" --yesno "This script will disable secure boot. Do you want to continue?" 8 78

init_script

# Main menu
while :; do

    CHOICE=$(whiptail --title "Kernel Configuration Menu" --menu "Choose an option" 25 78 16 \
        "0" "Choose Kernel Version ($_kv_name)" \
        "1" "Configure CachyOS" \
        "2" "Configure CPU Scheduler" \
        "3" "Configure LLVM LTO" \
        "4" "Configure Tick Rate" \
        "5" "Configure NR_CPUS" \
        "6" "Configure Tick Type" \
        "7" "Configure Preempt Type" \
        "8" "Configure LRU" \
        "9" "Configure Hugepages" \
        "10" "Configure System Optimizations" \
        "11" "COMPILE KERNEL" \
        "12" "Exit" 3>&1 1>&2 2>&3)

    exitstatus=$?
    if [ $exitstatus = 255 ]; then
        # Exit the script if the user presses Esc
        break
    fi

    case $CHOICE in
    0) choose_kernel_option ;;
    1) configure_cachyos ;;
    2) configure_cpusched ;;
    3) configure_llvm_lto ;;
    4) configure_tick_rate ;;
    5) configure_nr_cpus ;;
    6) configure_tick_type ;;
    7) configure_preempt_type ;;
    8) configure_lru ;;
    9) configure_hugepages ;;
    10) configure_system_optimizations ;;
    11) do_things ;;
    12 | q) break ;;
    *) echo "Invalid Option" ;;
    esac
done