all: sakura.bin rdk_rx62n.bin lcd_rx63n.bin

CROSS_COMPILE=rx-elf-
CC=$(CROSS_COMPILE)gcc
OBJCOPY=$(CROSS_COMPILE)objcopy
OBJDUMP=$(CROSS_COMPILE)objdump
SIZE=$(CROSS_COMPILE)size
CFLAGS += -Os -Wall -ffunction-sections -fdata-sections -Wl,--build-id=none -mlittle-endian-data
LDFLAGS = -Wl,--gc-sections -Wl,--gc-keep-exported
LDFLAGS += -Wl,--print-gc-sections
SYSROOT=/usr/rx-elf/sys-root

#BASE_LDSCRIPT=$(SYSROOT)/usr/lib/rx.ld
BASE_LDSCRIPT=/usr/rx-elf/lib/rx.ld

r5f562n8.ld: $(BASE_LDSCRIPT) Makefile
	@sed -e 's|\(RAM[^=]*=[ ]*[^,]*,[ ]*LENGTH[ ]*=[ ]*\).*$$|\10x00018000 /* 96 KB */|' \
	     -e 's|\(STACK[^=]*=[ ]*\)[^,]*\(,.*\)$$|\10x00018000\2|' \
	     -e 's|\(ROM[^=]*=[ ]*\)[^,]*\(,[ ]*LENGTH[ ]*=[ ]*\).*$$|\10xfff80000\20x0007ffd0 /* 512 KB */|' \
	     -e 's|^\(/\*.*This memory layout corresponds to the \).*\(\.[ ]*\*/\)$$|\1R5F562N8xxxx\2|' \
	     -e 's|^/\*.*ROM.*512 KB \*/$$||' \
	     -e 's|^/\*.*This is the largest RX6.*\*/$$||' \
	     $(BASE_LDSCRIPT) > $@

r5f563nb.ld: $(BASE_LDSCRIPT) Makefile
	@sed -e 's|\(ROM[^=]*=[ ]*\)[^,]*\(,[ ]*LENGTH[ ]*=[ ]*\).*$$|\10xfff00000\20x000fffd0 /* 1 MB */|' \
	     -e 's|^\(/\*.*This memory layout corresponds to the \).*\(\.[ ]*\*/\)$$|\1R5F563NBxxxx\2|' \
	     -e 's|^/\*.*ROM.*1 MB \*/$$||' \
	     -e 's|^/\*.*This is the largest RX6.*\*/$$||' \
	     $(BASE_LDSCRIPT) > $@

r5f563ne.ld: $(BASE_LDSCRIPT) Makefile
	@sed -e 's|\(ROM[^=]*=[ ]*\)[^,]*\(,[ ]*LENGTH[ ]*=[ ]*\).*$$|\10xffe00000\20x001fffd0 /* 2 MB */|' \
	     -e 's|^\(/\*.*This memory layout corresponds to the \).*\(\.[ ]*\*/\)$$|\1R5F563NExxxx\2|' \
	     -e 's|^/\*.*ROM.*2 MB \*/$$||' \
	     -e 's|^/\*.*This is the largest RX6.*\*/$$||' \
	     -e 's|\(.vectors[ ]*([^)]*)[ ]*:\)|.optionsettings (0xFFFFFF80) :\n  {\n    PROVIDE (__optionsettings = .);\n    LONG (0xffffffff);\n  }\n\n  \1|' \
	     $(BASE_LDSCRIPT) > $@

gr-sakura.ld: r5f563nb.ld Makefile
	@sed -e 's|\(ROM[^=]*=[ ]*\)[^,]*\(,[ ]*LENGTH[ ]*=[ ]*\).*$$|\10xfff00000\20x00070000 /* 448 KB */|' \
	     -e 's|\(.vectors\)[ ]*([^)]*)[ ]*:|\1 :|' \
	     -e 's|R5F563NBxxxx|GR-Sakura board (R5F563NBDDFP)|' \
	     r5f563nb.ld | \
	perl -0pe 's|(\(_start\)\;\s*})|$$1 > ROM|g' > $@

sakura.elf: main.c gr-sakura.ld Makefile
	$(CC) -T gr-sakura.ld $(CFLAGS) -DSAKURA $(LDFLAGS) -Wl,-Map,sakura.map -o $@ main.c

rdk_rx62n.elf: main.c r5f562n8.ld Makefile
	$(CC) -T r5f562n8.ld $(CFLAGS) -DRDK_RX62N $(LDFLAGS) -Wl,-Map,rdk_rx62n.map -o $@ main.c

lcd_rx63n.elf: main.c r5f563ne.ld Makefile
	$(CC) -T r5f563ne.ld $(CFLAGS) -DLCD_RX63N -mcpu=rx600 $(LDFLAGS) -Wl,-Map,lcd_rx63n.map -o $@ main.c

sakura.bin: sakura.elf Makefile
	$(OBJCOPY) -Obinary sakura.elf $@
	$(OBJDUMP) -S sakura.elf > sakura.lst
	$(SIZE) sakura.elf

rdk_rx62n.bin: rdk_rx62n.elf Makefile
	$(OBJCOPY) -Obinary rdk_rx62n.elf $@
	$(OBJDUMP) -S rdk_rx62n.elf > rdk_rx62n.lst
	$(SIZE) rdk_rx62n.elf

lcd_rx63n.bin: lcd_rx63n.elf Makefile
	$(OBJCOPY) -Obinary lcd_rx63n.elf $@
	$(OBJDUMP) -S lcd_rx63n.elf > lcd_rx63n.lst
	$(SIZE) lcd_rx63n.elf

test-sakura: sakura.bin
	cp sakura.bin /var/run/media/$(shell whoami)/GR-SAKURA/

test-rdk-rx62n: rdk_rx62n.bin
	JLinkExe -device R5F562N8 -if JTAG -speed 2000 -jtagconf -1,-1 -autoconnect 1 -CommanderScript rdk_rx62n.jlink

test-lcd-rx63n: lcd_rx63n.bin
	JLinkExe -device R5F563NE -if JTAG -speed 2000 -jtagconf -1,-1 -autoconnect 1 -CommanderScript lcd_rx63n.jlink

clean:
	-rm -f *.elf *.bin *.lst *.map
	-rm -f r5f563nb.ld r5f563ne.ld gr-sakura.ld r5f562n8.ld
