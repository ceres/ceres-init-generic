#!/bin/sh

TARGET_DIR?=/
BUILD_DIR?=$(@D)/ceres-init
OUTPUT_FILE?=$(TARGET_DIR)/boot/ceres-init.cpio.gz
MODULE_PATH?=$(TARGET_DIR)/lib/modules/$(shell ls $(TARGET_DIR)/lib/modules | tail -1)/kernel

define progress_out
	@echo "\033[1;33m*** $(1) ***\033[0m"
endef

all: build

build:
	$(call progress_out,Building ceres-init $(OUTPUT_FILE))
	mkdir -p $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)/bin $(BUILD_DIR)/dev $(BUILD_DIR)/etc
	mkdir -p $(BUILD_DIR)/lib64 $(BUILD_DIR)/mnt $(BUILD_DIR)/proc
	mkdir -p $(BUILD_DIR)/root $(BUILD_DIR)/sbin $(BUILD_DIR)/sys
	mkdir -p $(BUILD_DIR)/usr/bin $(BUILD_DIR)/usr/sbin $(BUILD_DIR)/lib

	mknod $(BUILD_DIR)/dev/console c 5 1 || true
	mknod $(BUILD_DIR)/dev/ram0 b 1 1 || true
	mknod $(BUILD_DIR)/dev/null c 1 3 || true
	mknod $(BUILD_DIR)/dev/tty1 c 4 1 || true
	mknod $(BUILD_DIR)/dev/tty2 c 4 2 || true

	cp -a $(TARGET_DIR)/bin/busybox $(BUILD_DIR)/bin/

	cat modules-generic | while read mod; do \
		find ${MODULE_PATH} -name $${mod}.ko | while read modpath; do \
			[ -d `dirname $(BUILD_DIR)/$${modpath}` ] || mkdir -p `dirname $(BUILD_DIR)/$${modpath}`; \
			[ -f $(BUILD_DIR)/$${modpath} ] || \
				( \
					cp -a $${modpath} $(BUILD_DIR)/$${modpath}; \
					echo "Imported `basename $${modpath}`"; \
					BUILD_DIR=$(BUILD_DIR) MODULE_PATH=$(MODULE_PATH) ./scripts/import-dependencies $${modpath}; \
				) \
		done; \
	done

	cp src/init $(BUILD_DIR)/init
	chmod +x $(BUILD_DIR)/init
	chmod +x $(BUILD_DIR)/bin/busybox

install: build
	$(call progress_out,Installing initramfs into $(OUTPUT_FILE))
	cd $(BUILD_DIR) && find . -print0 | cpio --null -ov --format=newc | gzip -9 > $(OUTPUT_FILE)
