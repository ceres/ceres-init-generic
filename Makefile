#!/bin/sh

BUILDDIR?=/tmp/ceres-init-build
OUTPUTFILE?=/tmp/ceres-init.cpio.gz
MODULEPATH?=/lib/modules/$(shell ls /lib/modules | tail -1)/kernel

define progress_out
	@echo "\033[1;33m*** $(1) ***\033[0m"
endef

all: build

build:
	$(call progress_out,Building ceres-init $(OUTPUTFILE))
	mkdir -p $(BUILDDIR)
	mkdir -p $(BUILDDIR)/bin $(BUILDDIR)/dev $(BUILDDIR)/etc
	mkdir -p $(BUILDDIR)/lib64 $(BUILDDIR)/mnt $(BUILDDIR)/proc
	mkdir -p $(BUILDDIR)/root $(BUILDDIR)/sbin $(BUILDDIR)/sys
	mkdir -p $(BUILDDIR)/usr/bin $(BUILDDIR)/usr/sbin $(BUILDDIR)/lib

	mknod $(BUILDDIR)/dev/console c 5 1 || true
	mknod $(BUILDDIR)/dev/ram0 b 1 1 || true
	mknod $(BUILDDIR)/dev/null c 1 3 || true
	mknod $(BUILDDIR)/dev/tty1 c 4 1 || true
	mknod $(BUILDDIR)/dev/tty2 c 4 2 || true

	cp -a /bin/busybox $(BUILDDIR)/bin/

	cat modules-generic | while read mod; do \
		find ${MODULEPATH} -name $${mod}.ko | while read modpath; do \
			[ -d `dirname $(BUILDDIR)/$${modpath}` ] || mkdir -p `dirname $(BUILDDIR)/$${modpath}`; \
			[ -f $(BUILDDIR)/$${modpath} ] || \
				( \
					cp -a $${modpath} $(BUILDDIR)/$${modpath}; \
					echo "Imported `basename $${modpath}`"; \
					BUILDDIR=$(BUILDDIR) MODULEPATH=$(MODULEPATH) ./scripts/import-dependencies $${modpath}; \
				) \
		done; \
	done

	cp src/init $(BUILDDIR)/init
	chmod +x $(BUILDDIR)/init
	chmod +x $(BUILDDIR)/bin/busybox
	cd $(BUILDDIR) && find . -print0 | cpio --null -ov --format=newc | gzip -9 > $(OUTPUTFILE)
	rm -rf $(BUILDDIR)

install: build
	$(call progress_out,Installing $(OUTPUTFILE) into $(STAGINGDIR)/boot/)
	cp $(OUTPUTFILE) /boot/
