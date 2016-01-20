Spike Hardware
==============

This project provides hardware peripherals to spike, the RISC-V ISA
simulator.

To build it:

    git clone git://github.com/cambridgehackers/fpgamake
    git clone git://github.com/cambridgehackers/buildcache
    git clone git://github.com/cambridgehackers/connectal

    cd connectal/tests/spikehw
    make build.vc707g2 test-spikehw.vc707g2

To test it, assuming connectal is installed:

    cd connectal/tests/spikehw
    ./test-spikehw.vc707g2

You should see output like the following:

    jamey@bdbm07:~/connectal/tests/spikehw$ ./test-spikehw.vc707g2
    buffer /home/jamey/connectal/tests/spikehw/vc707g2/bin/connectal.so
    fpgajtag: elf input file, len 1459190 class 2
    fpgajtag: unzip input file, len 1040655
    fpgajtag: Digilent:Digilent Adept USB Device:210203860922; bcd:700
    count 2/3 cortex -1 dcount 2 trail 0
    STATUS 00500018 done 0 release_done 0 eos 10 startup_state 4
    STATUS 00500018 done 0 release_done 0 eos 10 startup_state 4
    STATUS 0002107a done 0 release_done 0 eos 10 startup_state 0
    fpgajtag: Starting to send file
    fpgajtag: Done sending file
    fpgajtag: bypass already programmed ae
    STATUS 0002107a done 0 release_done 0 eos 10 startup_state 0
    Running /usr/bin/pciescan.sh
    + PATH=/home/jamey/work/build/tools/bin:/home/jamey/work/vendor/android-ndk-r10e:/home/jamey/work/build/tools/bin:/home/jamey/work/vendor/android-ndk-r10e:/home/jamey/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/scratch/Xilinx/Vivado/2015.4/bin:/scratch/bluespec/Bluespec-2015.05.beta1/bin:/scratch/android-ndk-r10e:/home/jamey/bin:/sbin
    ++ lspci -d 1be7:c100
    ++ sed -e 's/ .*//'
    + BLUEDEVICE=03:00.0
    + '[' 03:00.0 '!=' '' ']'
    + sh -c 'echo 1 >/sys/bus/pci/devices/0000:03:00.0/remove'
    + sleep 1
    + rmmod pcieportal
    + sleep 1
    + sh -c 'echo 1 >/sys/bus/pci/rescan'
    + sleep 1
    subprocess pid 16080 completed status=0 0
    [initPortalHardwareOnce:256] fd 6 len 0
    [checkSignature:154] read status from '/dev/connectal' was only 0 bytes long
    [dmaManagerOnce:44]
    axi eth status mmcm_locked=1 irq=0 intr sources=0
    word 0000 of boot ROM 00001137 (expected 00001137)
    word 0004 of boot ROM 010000ef (expected 010000ef)
    word 0008 of boot ROM 20000513 (expected 20000513)
    word 000c of boot ROM 00050067 (expected 00050067)
    word 0010 of boot ROM 0000006f (expected 0000006f)
    word 0014 of boot ROM 040007b7 (expected 040007b7)
    word 0018 of boot ROM 40078793 (expected 40078793)
    word 001c of boot ROM fc0005b7 (expected fc0005b7)
    AXI Ethernet Identification 09000000 (expected 09000000)
    SpikeHw::writeFlash offset=55 value=98
    Query flash 51.52.59 QRY (expected QRY)

The last five lines are the actual test output.

If the first word of the boot ROM is 0, then it is because bootromx4.hex is missing.

Linux Kernel
------------

The corresponding RISC-V Linux kernel is available here:
    git clone git://github.com/cambridgehackers/cambridgehackers/riscv-linux-4.1.y linux
    cd linux

    ## configure the kernel
    make ARCH=riscv riscv64_spikehw_defconfig

    ## build the kernel
    make ARCH=riscv

    ## build the device tree .dtb files
    make ARCH=riscv dtbs