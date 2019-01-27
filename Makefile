#!/bin/sh

TARGET_DIR?=/
BUILD_DIR?=$(@D)/ceres-init
OUTPUT_DIR?=$(TARGET_DIR)/boot
OUTPUT_FILE?=ceres-init.cpio.gz
MODULE_PATH?=$(TARGET_DIR)/lib/modules/$(shell ls $(TARGET_DIR)/lib/modules | tail -1)/kernel

define progress_out
	@echo "\033[1;33m*** $(1) ***\033[0m"
endef

all: build

build:
	$(call progress_out,Building $(OUTPUT_FILE) in $(BUILD_DIR))
	mkdir -p $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)/bin $(BUILD_DIR)/dev $(BUILD_DIR)/etc
	mkdir -p $(BUILD_DIR)/lib64 $(BUILD_DIR)/mnt $(BUILD_DIR)/proc
	mkdir -p $(BUILD_DIR)/root $(BUILD_DIR)/sbin $(BUILD_DIR)/sys
	mkdir -p $(BUILD_DIR)/usr/bin $(BUILD_DIR)/usr/sbin $(BUILD_DIR)/lib

	cp -a $(TARGET_DIR)/bin/busybox $(BUILD_DIR)/bin/
	cp -La ~/yggdrasil-go/yggdrasil $(BUILD_DIR)/bin/
	cp -La $(TARGET_DIR)/usr/bin/unshare $(BUILD_DIR)/usr/bin/
	cp -La $(TARGET_DIR)/usr/bin/nsenter $(BUILD_DIR)/usr/bin/
	cp -ar $(TARGET_DIR)/lib/libc.so $(BUILD_DIR)/lib/
	cp -ar $(TARGET_DIR)/lib/*musl*.so* $(BUILD_DIR)/lib/
	cp $(@D)/src/init $(BUILD_DIR)/init
	cp $(@D)/src/cinit $(BUILD_DIR)/cinit

	chmod +x $(BUILD_DIR)/init
	chmod +x $(BUILD_DIR)/cinit
	chmod +x $(BUILD_DIR)/bin/busybox
	chmod -s $(BUILD_DIR)/bin/busybox

	sudo mknod $(BUILD_DIR)/dev/console c 5 1 || true
	sudo mknod $(BUILD_DIR)/dev/ram0 b 1 1 || true
	sudo mknod $(BUILD_DIR)/dev/null c 1 3 || true
	sudo mknod $(BUILD_DIR)/dev/tty1 c 4 1 || true
	sudo mknod $(BUILD_DIR)/dev/tty2 c 4 2 || true

	cat modules-generic | while read mod; do \
		find ${MODULE_PATH} -name $${mod}.ko | while read modpath; do \
			[ -d `dirname $(BUILD_DIR)/$${modpath}` ] || mkdir -p `dirname $(BUILD_DIR)/$${modpath}`; \
			[ -f $(BUILD_DIR)/$${modpath} ] || \
				( \
					cp -a $${modpath} $(BUILD_DIR)/$${modpath}; \
					echo "Imported `basename $${modpath}`"; \
					BUILD_DIR=$(BUILD_DIR) MODULE_PATH=$(MODULE_PATH) $(@D)/scripts/import-dependencies $${modpath}; \
				) \
		done; \
	done

install: build
	$(call progress_out,Installing $(OUTPUT_FILE) into $(OUTPUT_DIR))
	if [ ! -d $(OUTPUT_DIR) ]; then \
		mkdir -p $(OUTPUT_DIR); \
	fi
	cd $(BUILD_DIR) && find . -print0 | cpio --null -ov --format=newc | gzip -9 > $(OUTPUT_DIR)/$(OUTPUT_FILE)
