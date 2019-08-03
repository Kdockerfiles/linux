RELEASE ?=
KERNEL_DEFCONFIG ?= rockchip_linux_defconfig

KERNEL_VERSION ?= $(shell $(KERNEL_MAKE) -s kernelversion)
KERNEL_RELEASE ?= $(shell $(KERNEL_MAKE) -s kernelrelease)

KERNEL_MAKE ?= make \
	ARCH=arm64 \
	CROSS_COMPILE="ccache aarch64-linux-gnu-"

.config: arch/arm64/configs/$(KERNEL_DEFCONFIG)
	$(KERNEL_MAKE) $(KERNEL_DEFCONFIG)

.PHONY: .scmversion
.scmversion:
ifneq (,$(RELEASE))
	@echo "-$(RELEASE)-ayufan-g$$(git rev-parse --short HEAD)" > .scmversion
else
	@echo "-dev" > .scmversion
endif

.PHONY: info
info: .config .scmversion
	@echo $(KERNEL_RELEASE)

.PHONY: kernel-menuconfig
kernel-menuconfig:
	$(KERNEL_MAKE) $(KERNEL_DEFCONFIG)
	$(KERNEL_MAKE) menuconfig
	$(KERNEL_MAKE) savedefconfig
	mv $(O)/defconfig arch/arm64/configs/$(KERNEL_DEFCONFIG)

.PHONY: kernel-image
kernel-image: .config .scmversion
	$(KERNEL_MAKE) Image dtbs -j$$(nproc)

.PHONY: kernel-all
kernel-all: .config .scmversion
	$(KERNEL_MAKE) Image modules dtbs -j$$(nproc)
	$(KERNEL_MAKE) modules_install INSTALL_MOD_PATH=out_modules
	$(KERNEL_MAKE) dtbs_install INSTALL_DTBS_PATH=out_dtbs

.PHONY: kernel-update-dts
kernel-update-dts: .config .scmversion
	$(KERNEL_MAKE) dtbs -j$$(nproc)
	rsync --partial --checksum --include="*.dtb" -rv arch/arm64/boot/dts/rockchip root@$(REMOTE_HOST):$(REMOTE_DIR)/boot/dtbs/$(KERNEL_RELEASE)

.PHONY: kernel-update
kernel-update-image: .scmversion
	rsync --partial --checksum -rv arch/arm64/boot/Image root@$(REMOTE_HOST):$(REMOTE_DIR)/boot/vmlinuz-$(KERNEL_RELEASE)
	rsync --partial --checksum --include="*.dtb" -rv arch/arm64/boot/dts/rockchip root@$(REMOTE_HOST):$(REMOTE_DIR)/boot/dtbs/$(KERNEL_RELEASE)
	rsync --partial --checksum -av out/linux_modules/lib/modules/$(KERNEL_RELEASE) root@$(REMOTE_HOST):$(REMOTE_DIR)/lib/modules/$(KERNEL_RELEASE)
